extends Node
class_name BattleManager

## BattleManager — orchestrates the 三國殺 turn structure.
##
## Turn phases:
##   1. Judgment Phase  — resolve delayed strategies (樂不思蜀, 閃電, 兵糧寸斷)
##   2. Draw Phase       — draw 2 cards (modified by hero skills like 英姿)
##   3. Play Phase       — play cards, use skills, attack enemies
##   4. Discard Phase    — discard down to HP limit
##   5. End Phase        — cleanup, trigger end-of-turn effects (閉月)

# -- Signals --
signal turn_started(turn_number: int)
signal phase_changed(phase: Phase)
signal battle_ended(victory: bool)

# -- Enums --
enum Phase { JUDGMENT, DRAW, PLAY, DISCARD, END }

# -- State --
var turn_number: int = 1
var current_phase: Phase = Phase.JUDGMENT
var player_hp: int
var player_max_hp: int
var energy: int = 1          # "殺" limit per turn
var energy_used: int = 0
var hand_size_limit: int     # = player_hp normally
var attack_limit_reached: bool = false  # for 呂布 無雙

# -- References --
var player_hero: HeroData
var deck: Array[CardData] = []
var hand: Array[CardData] = []
var discard_pile: Array[CardData] = []
var judgment_zone: Array[CardData] = []  # Delayed strategies pending judgment
var equipment_slots: Dictionary = {}     # weapon, armor, horse_plus, horse_minus
var follower: Follower = null            # Max 1 ally

# -- Enemies --
var enemies: Array = []       # Array of EnemyData/Node references


func _ready() -> void:
    initialize_battle()


func initialize_battle() -> void:
    ## Called once at battle start. Loads hero, shuffles deck, draws opening hand.
    player_hp = player_hero.max_hp
    player_max_hp = player_hero.max_hp
    hand_size_limit = player_hp
    
    # Load starting deck and shuffle
    deck = player_hero.starting_deck.duplicate()
    shuffle_deck()
    
    # Draw 4 cards (standard 三國殺 opening hand)
    draw_cards(4)
    
    # Set up follower if hero starts with one
    _setup_follower()
    
    start_turn()


func start_turn() -> void:
    turn_started.emit(turn_number)
    _advance_phase(Phase.JUDGMENT)


func end_turn() -> void:
    _advance_phase(Phase.END)
    await _resolve_end_phase()
    turn_number += 1
    start_turn()


# ============================================================
#  PHASE HANDLERS
# ============================================================

func _advance_phase(new_phase: Phase) -> void:
    current_phase = new_phase
    phase_changed.emit(new_phase)
    
    match new_phase:
        Phase.JUDGMENT:
            await _resolve_judgment_phase()
            _advance_phase(Phase.DRAW)
        Phase.DRAW:
            await _resolve_draw_phase()
            _advance_phase(Phase.PLAY)
        Phase.PLAY:
            pass  # Player controls this phase — UI-driven, no auto-advance
        Phase.DISCARD:
            pass  # Player resolves discard, then calls end_turn()
        Phase.END:
            pass  # Handled in end_turn()


func _resolve_judgment_phase() -> void:
    ## Process delayed strategy cards in judgment zone.
    ## Each card is judged: flip top deck, check suit/number.
    for card in judgment_zone.duplicate():
        var judged := draw_top_card()
        if judged == null:
            break
        
        var effective := _apply_judgment(card, judged)
        if effective:
            # Card takes effect — apply its consequence
            _apply_delayed_effect(card)
        else:
            # Pass the judgment card to the next target (or discard)
            discard_card(card)
        
        judgment_zone.erase(card)


func _resolve_draw_phase() -> void:
    ## Draw 2 cards. Hero skills (e.g. 周瑜 英姿) may modify this.
    var draw_amount := 2
    # TODO: Apply hero skill modifiers (英姿 +1, 突襲 replaces draw entirely)
    draw_cards(draw_amount)


func _resolve_end_phase() -> void:
    ## Trigger end-of-turn effects (e.g. 閉月 draws 1 card).
    # TODO: Apply hero-specific end-phase effects
    energy_used = 0
    attack_limit_reached = false
    hand_size_limit = player_hp  # Reset (may be modified by 克己)


# ============================================================
#  CARD OPERATIONS
# ============================================================

func draw_cards(count: int) -> void:
    for i in range(count):
        if deck.is_empty():
            _reshuffle_discard()
        if not deck.is_empty():
            var card := deck.pop_back()
            hand.append(card)


func draw_top_card() -> CardData:
    ## Draw exactly 1 card from top of deck. Returns null if deck empty.
    if deck.is_empty():
        _reshuffle_discard()
    if deck.is_empty():
        return null
    var card := deck.pop_back()
    return card


func play_card(card: CardData, target = null) -> bool:
    ## Attempt to play a card from hand. Returns true if successful.
    if not hand.has(card):
        return false
    
    # Check if this card type is playable in current phase
    if current_phase != Phase.PLAY:
        return false
    
    # Handle card by type
    match card.card_type:
        CardData.CardType.BASIC:
            match card.sub_type:
                CardData.SubType.SLASH:
                    if energy_used >= energy:
                        return false  # "殺" limit reached (unless 張飛 咆哮)
                    # TODO: Apply damage to target, check 閃 response
                    energy_used += 1
                CardData.SubType.DODGE:
                    pass  # Played in response, not proactively
                CardData.SubType.PEACH:
                    player_hp = min(player_hp + card.heal, player_max_hp)
                CardData.SubType.WINE:
                    # Next 殺 this turn deals +1 damage; or self-rescue at 0 HP
                    pass
        CardData.CardType.STRATEGY:
            _resolve_strategy(card, target)
        CardData.CardType.EQUIPMENT:
            _equip_card(card)
        CardData.CardType.DELAY_STRATEGY:
            _place_in_judgment(card, target)
    
    hand.erase(card)
    discard_pile.append(card)
    return true


func _resolve_strategy(card: CardData, target) -> void:
    match card.sub_type:
        CardData.SubType.DISMANTLE:
            # TODO: Target discards 1 card
            pass
        CardData.SubType.STEAL:
            # TODO: Steal 1 card from target
            pass
        CardData.SubType.DRAW2:
            draw_cards(2)
            discard_card(card)  # 無中生有 goes to discard immediately
        CardData.SubType.DUEL:
            # TODO: Target must play 殺 or take 1 damage
            pass
        CardData.SubType.BARBARIAN:
            # TODO: All enemies must play 殺 or take 1 damage
            pass
        CardData.SubType.VOLLEY:
            # TODO: All enemies must play 閃 or take 1 damage
            pass
        CardData.SubType.PEACH_GARDEN:
            # TODO: Heal all characters for 1
            pass
        CardData.SubType.HARVEST:
            # TODO: Reveal N cards, players take turns picking
            pass
        CardData.SubType.NEGATE:
            # TODO: Cancel another strategy card
            pass


func _equip_card(card: CardData) -> void:
    var slot := ""
    match card.sub_type:
        CardData.SubType.WEAPON: slot = "weapon"
        CardData.SubType.ARMOR: slot = "armor"
        CardData.SubType.HORSE_PLUS: slot = "horse_plus"
        CardData.SubType.HORSE_MINUS: slot = "horse_minus"
    
    if slot.is_empty():
        return
    
    # Unequip existing item in slot (if any)
    if equipment_slots.has(slot):
        discard_pile.append(equipment_slots[slot])
    
    equipment_slots[slot] = card


func _place_in_judgment(card: CardData, target) -> void:
    ## Place a delayed strategy card into the target's judgment zone.
    judgment_zone.append(card)


func _apply_judgment(delay_card: CardData, judged_card: CardData) -> bool:
    ## Returns true if the delayed strategy takes effect.
    match delay_card.sub_type:
        CardData.SubType.LE_BUSI:
            # Effective if judged card is NOT ♡
            return judged_card.suit != CardData.Suit.HEART
        CardData.SubType.LIGHTNING:
            # Effective if ♠2-9 (3 damage!)
            return judged_card.suit == CardData.Suit.SPADE and judged_card.number >= 2 and judged_card.number <= 9
        CardData.SubType.BING_LIANG:
            # Effective if judged card is NOT ♣
            return judged_card.suit != CardData.Suit.CLUB
    return false


func _apply_delayed_effect(card: CardData) -> void:
    match card.sub_type:
        CardData.SubType.LE_BUSI:
            # Skip play phase this turn
            pass
        CardData.SubType.LIGHTNING:
            # Take 3 lightning damage
            take_damage(3)
        CardData.SubType.BING_LIANG:
            # Skip draw phase next turn
            pass


# ============================================================
#  UTILITY
# ============================================================

func shuffle_deck() -> void:
    deck.shuffle()


func _reshuffle_discard() -> void:
    if discard_pile.is_empty():
        return
    deck = discard_pile.duplicate()
    discard_pile.clear()
    shuffle_deck()


func discard_card(card: CardData) -> void:
    if hand.has(card):
        hand.erase(card)
    discard_pile.append(card)


func take_damage(amount: int) -> void:
    player_hp = max(0, player_hp - amount)
    if player_hp <= 0:
        # TODO: Check for 桃 rescue opportunity
        battle_ended.emit(false)


func _setup_follower() -> void:
    ## Check if hero archetype is SUPPORT — they may start with a follower.
    if player_hero.archetype == HeroData.Archetype.SUPPORT:
        # Check starting deck for 招募義勇兵 card
        for card in hand:
            if card.id == "recruit_volunteer":
                follower = Follower.new()
                follower.hp = 3
                follower.max_hp = 3
                follower.name_zh = "義勇兵"
                follower.passive_desc = "每回合對隨機敵方造成 1 點傷害"
                hand.erase(card)
                discard_pile.append(card)
                break
