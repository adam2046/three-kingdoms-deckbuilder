extends Control
class_name BattleScene

## BattleScene — the main gameplay screen.
## Contains: hand area, player HP/energy, enemy display, judgment zone, end turn button.

@onready var battle_manager: BattleManager = $BattleManager
@onready var hand_container: HBoxContainer = $UI/HandContainer
@onready var energy_label: Label = $UI/TopBar/EnergyLabel
@onready var hp_label: Label = $UI/TopBar/HPLabel
@onready var phase_label: Label = $UI/TopBar/PhaseLabel
@onready var deck_label: Label = $UI/DeckInfo/DeckLabel
@onready var discard_label: Label = $UI/DeckInfo/DiscardLabel
@onready var end_turn_btn: Button = $UI/EndTurnBtn
@onready var enemy_container: HBoxContainer = $EnemyArea/EnemyContainer
@onready var judgment_display: Control = $UI/JudgmentZone
@onready var follower_display: Control = $UI/FollowerDisplay


func _ready() -> void:
    # Connect signals
    battle_manager.turn_started.connect(_on_turn_started)
    battle_manager.phase_changed.connect(_on_phase_changed)
    battle_manager.battle_ended.connect(_on_battle_ended)
    end_turn_btn.pressed.connect(_on_end_turn_pressed)
    
    # Load test hero for prototyping
    _load_test_hero()
    battle_manager.initialize_battle()
    _refresh_ui()


func _load_test_hero() -> void:
    ## Load a test hero for prototyping. Start with 趙雲 (balanced, easy).
    var hero := HeroData.new()
    hero.id = "zhao_yun"
    hero.name_zh = "趙雲"
    hero.name_en = "Zhao Yun"
    hero.title_zh = "一身是膽"
    hero.faction = HeroData.Faction.SHU
    hero.archetype = HeroData.Archetype.BALANCED
    hero.max_hp = 4
    hero.skill_1_name_zh = "龍膽"
    hero.skill_1_desc_zh = "你可以將「殺」當作「閃」使用或打出；你可以將「閃」當作「殺」使用或打出。"
    
    # Starting deck: 4 殺, 3 閃, 1 桃, 1 酒, 1 過河拆橋 (BALANCED archetype)
    hero.starting_deck = _create_starter_deck_balanced()
    
    battle_manager.player_hero = hero


func _create_starter_deck_balanced() -> Array[CardData]:
    var deck: Array[CardData] = []
    var card_ids := [
        "slash_spade_7", "slash_heart_10", "slash_club_4", "slash_diamond_8",
        "dodge_heart_2", "dodge_diamond_6", "dodge_diamond_J",
        "peach_heart_4", "wine_spade_3", "dismantle_spade_3",
    ]
    for cid in card_ids:
        var card := _create_test_card(cid)
        if card:
            deck.append(card)
    return deck


func _create_test_card(card_id: String) -> CardData:
    ## Quick test card factory. Full library will be in resources/cards/.
    var card := CardData.new()
    card.id = card_id
    var parts := card_id.split("_")
    if parts.size() < 3:
        return null
    
    match parts[0]:
        "slash":
            card.card_type = CardData.CardType.BASIC
            card.sub_type = CardData.SubType.SLASH
            card.name_zh = "殺"
            card.damage = 1
        "dodge":
            card.card_type = CardData.CardType.BASIC
            card.sub_type = CardData.SubType.DODGE
            card.name_zh = "閃"
            card.block = 1
        "peach":
            card.card_type = CardData.CardType.BASIC
            card.sub_type = CardData.SubType.PEACH
            card.name_zh = "桃"
            card.heal = 1
        "wine":
            card.card_type = CardData.CardType.BASIC
            card.sub_type = CardData.SubType.WINE
            card.name_zh = "酒"
        "dismantle":
            card.card_type = CardData.CardType.STRATEGY
            card.sub_type = CardData.SubType.DISMANTLE
            card.name_zh = "過河拆橋"
            card.discard_count = 1
        _:
            card.name_zh = "?"
    
    # Parse suit
    match parts[1] if parts.size() > 1 else "":
        "spade": card.suit = CardData.Suit.SPADE
        "heart": card.suit = CardData.Suit.HEART
        "club": card.suit = CardData.Suit.CLUB
        "diamond": card.suit = CardData.Suit.DIAMOND
    
    # Parse number
    if parts.size() > 2:
        var num_str := parts[2]
        match num_str:
            "A": card.number = 1; card.number_display = "A"
            "J": card.number = 11; card.number_display = "J"
            "Q": card.number = 12; card.number_display = "Q"
            "K": card.number = 13; card.number_display = "K"
            _:
                var n := num_str.to_int()
                if n > 0:
                    card.number = n
                    card.number_display = num_str
    
    return card


# ============================================================
#  UI UPDATES
# ============================================================

func _refresh_ui() -> void:
    _refresh_hand()
    _refresh_stats()
    _refresh_enemies()
    _refresh_follower()


func _refresh_hand() -> void:
    ## Clear and rebuild hand display using CardNode components.
    for child in hand_container.get_children():
        child.queue_free()
    
    for card in battle_manager.hand:
        var card_node = _create_card_node(card)
        hand_container.add_child(card_node)


func _create_card_node(card: CardData):
    ## Create a CardNode instance. Returns untyped to avoid parse errors in headless.
    var node = CardNode.new()
    node.setup(card)
    node.card_clicked.connect(_on_card_played)
    return node


func _refresh_stats() -> void:
    hp_label.text = "HP: %d/%d" % [battle_manager.player_hp, battle_manager.player_max_hp]
    energy_label.text = "殺: %d/%d" % [battle_manager.energy_used, battle_manager.energy]
    deck_label.text = "牌庫: %d" % battle_manager.deck.size()
    discard_label.text = "棄牌: %d" % battle_manager.discard_pile.size()


func _refresh_enemies() -> void:
    for child in enemy_container.get_children():
        child.queue_free()
    
    for enemy in battle_manager.enemies:
        var enemy_node := _create_enemy_node(enemy)
        enemy_container.add_child(enemy_node)


func _create_enemy_node(enemy: EnemyData) -> Panel:
    var panel := Panel.new()
    panel.custom_minimum_size = Vector2(160, 200)
    
    var vbox := VBoxContainer.new()
    panel.add_child(vbox)
    
    var name_label := Label.new()
    name_label.text = enemy.name_zh
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(name_label)
    
    var hp_label := Label.new()
    hp_label.text = "HP: %d/%d" % [enemy.current_hp, enemy.max_hp]
    hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hp_label.name = "HPLabel"
    vbox.add_child(hp_label)
    
    var intent_label := Label.new()
    var intent_names := ["⚔️攻擊", "🛡防禦", "⬆️強化", "✨技能"]
    intent_label.text = intent_names[enemy.current_intent]
    intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    intent_label.name = "IntentLabel"
    vbox.add_child(intent_label)
    
    # Style
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.3, 0.1, 0.1, 0.8)
    style.border_color = Color.RED
    style.border_width_left = 2
    style.border_width_right = 2
    style.border_width_top = 2
    style.border_width_bottom = 2
    style.corner_radius_top_left = 10
    style.corner_radius_top_right = 10
    style.corner_radius_bottom_left = 10
    style.corner_radius_bottom_right = 10
    panel.add_theme_stylebox_override("panel", style)
    
    # Click to target
    panel.gui_input.connect(_on_enemy_clicked.bind(enemy))
    
    return panel


func _refresh_follower() -> void:
    var f := battle_manager.follower
    if f and f.is_alive():
        follower_display.visible = true
        # TODO: Update follower labels
    else:
        follower_display.visible = false


# ============================================================
#  SIGNAL HANDLERS
# ============================================================

func _on_turn_started(turn: int) -> void:
    print("=== Turn %d ===" % turn)
    _refresh_ui()


func _on_phase_changed(phase: BattleManager.Phase) -> void:
    var names := ["判定", "摸牌", "出牌", "棄牌", "結束"]
    phase_label.text = names[phase]
    
    if phase == BattleManager.Phase.PLAY:
        end_turn_btn.visible = true
    else:
        end_turn_btn.visible = false


var selected_card: CardData = null  # Card currently selected for targeting


func _card_needs_target(card: CardData) -> bool:
    match card.card_type:
        CardData.CardType.BASIC:
            return card.sub_type == CardData.SubType.SLASH
        CardData.CardType.STRATEGY:
            return card.sub_type in [CardData.SubType.DISMANTLE, CardData.SubType.STEAL, CardData.SubType.DUEL]
        _:
            return false


func _on_card_played(card: CardData) -> void:
    ## Player clicks a card. If needs target, select and wait for enemy click.
    ## If no target (peach, draw2), play immediately.
    if battle_manager.current_phase != BattleManager.Phase.PLAY:
        return
    
    var needs_target := _card_needs_target(card)
    
    if needs_target:
        selected_card = card
        for child in hand_container.get_children():
            if child is CardNode and child.card_data == card:
                child.highlight(true)
    else:
        if battle_manager.play_card(card):
            _refresh_ui()


func _on_enemy_clicked(event: InputEvent, enemy: EnemyData) -> void:
    if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
        return
    if selected_card == null:
        return
    
    battle_manager.play_card(selected_card, enemy)
    
    selected_card = null
    for child in hand_container.get_children():
        if child is CardNode:
            child.highlight(false)
    
    _refresh_ui()


func _on_end_turn_pressed() -> void:
    ## Player clicks "End Turn" — move to discard phase, then enemies act.
    if battle_manager.current_phase != BattleManager.Phase.PLAY:
        return
    
    # Auto-discard excess cards
    battle_manager._advance_phase(BattleManager.Phase.DISCARD)
    _auto_discard()
    
    # End turn — this triggers enemy turns + next player turn
    battle_manager.end_turn()
    _refresh_ui()


func _auto_discard() -> void:
    ## Discard excess cards (hand > HP). Simple: discard from right.
    while battle_manager.hand.size() > battle_manager.player_hp:
        var card: CardData = battle_manager.hand.back()
        battle_manager.discard_card(card)


func _on_battle_ended(victory: bool) -> void:
    if victory:
        print("VICTORY!")
    else:
        print("DEFEAT...")
