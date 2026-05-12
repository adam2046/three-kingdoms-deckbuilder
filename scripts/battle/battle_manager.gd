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
signal awaiting_dodge(enemy_name: String, damage: int)  # Player can respond with 閃
signal dodge_response_received()  # Internal: player responded

# -- Enums --
enum Phase { JUDGMENT, DRAW, PLAY, DISCARD, END }

# -- State --
var turn_number: int = 1
var current_phase: Phase = Phase.JUDGMENT
var player_hp: int
var player_max_hp: int
var energy: int = 1          # "殺" limit per turn
var energy_used: int = 0
var wine_active: bool = false   # Next 殺 deals +1 damage
var hand_size_limit: int     # = player_hp normally
var attack_limit_reached: bool = false  # for 呂布 無雙
var block: int = 0            # Damage absorption (from 無懈可擊)
var dodge_used_this_attack: bool = false  # Track if player used 閃 this attack

# -- References --
var player_hero: HeroData
var deck: Array[CardData] = []
var hand: Array[CardData] = []
var discard_pile: Array[CardData] = []
var judgment_zone: Array[CardData] = []  # Delayed strategies pending judgment
var equipment_slots: Dictionary = {}     # weapon, armor, horse_plus, horse_minus
var follower: Follower = null            # Max 1 ally
var map_manager = null            # Roguelike progression (MapManager)

# -- Skill state --
var skill_used_this_turn: Dictionary = {}  # e.g. {"zhiheng": true}
var xu_chu_luoyi_active: bool = false      # 許褚 裸衣 toggle state
var xiahou_yuan_extra_slash: bool = false   # 夏侯淵 疾行: extra slash per turn

# -- Enemies --
var enemies: Array = []       # Array of EnemyData/Node references

# ============================================================
#  HERO SKILL SYSTEM
# ============================================================

## Skill hooks — called at specific points in the battle flow.
## Each checks player_hero.id and dispatches to the right implementation.

func _on_damage_taken(amount: int, source = null) -> void:
	## Called after the player takes damage. Hero skills can react.
	match player_hero.id:
		"cao_cao":
			_skill_jianxiong(source)
		"sim_yi":
			_skill_fankui(source)
		"xiahou_dun":
			_skill_ganglie(source)
		"guo_jia":
			_skill_tiandu()
		"xiao_qiao":
			_skill_tianxiang(amount, source)

func _can_substitute(card: CardData, as_sub_type: CardData.SubType) -> bool:
	## Check if a card can be played as a different sub-type.
	## Used by skills like 龍膽 (殺↔閃), 武聖 (red→殺), 傾國 (black→閃), 國色 (♦→樂不思蜀)
	match player_hero.id:
		"zhao_yun":
			return _skill_longdan_check(card, as_sub_type)
		"guan_yu":
			return _skill_wusheng_check(card, as_sub_type)
		"zhen_ji":
			return _skill_qingguo_check(card, as_sub_type)
		"da_qiao":
			return _skill_guose_check(card, as_sub_type)
	return false


func _get_substitute_card(card: CardData, as_sub_type: CardData.SubType) -> CardData:
	## Return a copy of the card treated as the substitute type.
	## Doesn't modify the original — caller decides whether to use it.
	var sub := card.duplicate()
	sub.sub_type = as_sub_type
	match as_sub_type:
		CardData.SubType.SLASH:
			sub.damage = 1
			sub.name_zh = "殺"
		CardData.SubType.DODGE:
			sub.block = 1
			sub.name_zh = "閃"
		CardData.SubType.LE_BUSI:
			sub.name_zh = "樂不思蜀"
	return sub


func _has_active_skill() -> bool:
	## Returns true if the hero has a skill the player can activate now.
	match player_hero.id:
		"sun_quan":
			return not skill_used_this_turn.get("zhiheng", false) and not hand.is_empty()
		"huang_gai":
			return not skill_used_this_turn.get("kurou", false) and player_hp > 1
		"liu_bei":
			return not skill_used_this_turn.get("rende", false) and hand.size() >= 2 and player_hp < player_max_hp
		"zhou_yu":
			return not skill_used_this_turn.get("fanjian", false) and not enemies.is_empty()
		"lv_meng":
			return not skill_used_this_turn.get("keji", false)
		"gan_ning":
			return not equipment_slots.is_empty() and _get_first_alive_enemy() != null
		"xu_chu":
			return true  # 裸衣 is a toggle, always available
		"zhang_jiao":
			return not skill_used_this_turn.get("leiji", false) and _get_first_alive_enemy() != null
		"zhuge_liang":
			return not skill_used_this_turn.get("guanxing", false) and not deck.is_empty()
		"diao_chan":
			return enemies.size() >= 2 and not skill_used_this_turn.get("lijian", false)
	return false


func _get_active_skill_name() -> String:
	## Returns the skill name for UI display.
	match player_hero.id:
		"sun_quan": return "zhiheng"
		"huang_gai": return "kurou"
		"liu_bei": return "rende"
		"zhou_yu": return "fanjian"
		"lv_meng": return "keji"
		"gan_ning": return "qixi"
		"xu_chu": return "luoyi"
		"zhang_jiao": return "leiji"
		"zhuge_liang": return "guanxing"
		"diao_chan": return "lijian"
		_: return ""


func _activate_skill(skill_name: String) -> bool:
	## Activate a hero's active skill. Returns true if successful.
	match skill_name:
		"zhiheng":
			return _skill_zhiheng()
		"kurou":
			return _skill_kurou()
		"rende":
			return _skill_rende()
		"fanjian":
			return _skill_fanjian()
		"keji":
			return _skill_keji()
		"qixi":
			return _skill_qixi()
		"luoyi":
			return _skill_luoyi()
		"leiji":
			return _skill_leiji()
		"guanxing":
			return _skill_guanxing()
		"lijian":
			return _skill_lijian()
	return false


# --- Individual skill implementations ---

func _skill_jianxiong(source = null) -> void:
	## 曹操 奸雄: when damaged, gain a copy of the attacker's last used card.
	## For now: draw 1 extra card as compensation.
	draw_cards(1)


func _skill_longdan_check(card: CardData, as_sub_type: CardData.SubType) -> bool:
	## 趙雲 龍膽: 殺 can be used as 閃, 閃 can be used as 殺.
	if card.sub_type == CardData.SubType.SLASH and as_sub_type == CardData.SubType.DODGE:
		return true
	if card.sub_type == CardData.SubType.DODGE and as_sub_type == CardData.SubType.SLASH:
		return true
	return false


func _skill_wusheng_check(card: CardData, as_sub_type: CardData.SubType) -> bool:
	## 關羽 武聖: Red cards (♡/♢) can be used as 殺.
	if as_sub_type == CardData.SubType.SLASH and card.is_red():
		return true
	return false


func _skill_fankui(source = null) -> void:
	## 司馬懿 反饋: take damage → steal 1 card (draw 1 in PvE)
	draw_cards(1)
	print("[反饋] Draw 1 card after taking damage")


func _skill_ganglie(source = null) -> void:
	## 夏侯惇 剛烈: take damage → deal 1 back to source
	if source and source is EnemyData and source.is_alive():
		source.take_damage(1)
		print("[剛烈] Deal 1 damage back to %s" % source.name_zh)
		_check_victory()
	elif not enemies.is_empty():
		for e in enemies:
			if e.is_alive():
				e.take_damage(1)
				print("[剛烈] Deal 1 damage to %s" % e.name_zh)
				_check_victory()
				break


func _skill_tiandu() -> void:
	## 郭嘉 天妒: draw 2 cards when damaged
	draw_cards(2)
	print("[天妒] Draw 2 cards after taking damage")


func _skill_tianxiang(amount: int, source = null) -> void:
	## 小喬 天香: when damaged, if any red card in hand, negate the damage
	for card in hand:
		if card.is_red():
			hand.erase(card)
			discard_pile.append(card)
			player_hp += amount  # Undo the damage
			print("[天香] Red card %s%s negates %d damage" % [card.suit_symbol(), card.name_zh, amount])
			return
	print("[天香] No red card in hand — cannot negate")


func _skill_qingguo_check(card: CardData, as_sub_type: CardData.SubType) -> bool:
	## 甄姬 傾國: black cards (♠/♣) can be used as 閃
	if as_sub_type == CardData.SubType.DODGE and card.is_black():
		return true
	return false


func _skill_guose_check(card: CardData, as_sub_type: CardData.SubType) -> bool:
	## 大喬 國色: diamond (♢) cards can be used as 樂不思蜀
	if as_sub_type == CardData.SubType.LE_BUSI and card.suit == CardData.Suit.DIAMOND:
		return true
	return false


func _skill_zhiheng() -> bool:
	## 孫權 制衡: discard any number of cards, draw that many. Once per turn.
	if skill_used_this_turn.get("zhiheng", false):
		return false
	if hand.is_empty():
		return false
	# Discard all hand, draw equal amount
	var count := hand.size()
	for card in hand.duplicate():
		discard_card(card)
	draw_cards(count)
	skill_used_this_turn["zhiheng"] = true
	return true


func _skill_kurou() -> bool:
	## 黃蓋 苦肉: lose 1 HP → draw 2 cards. Once per turn.
	if skill_used_this_turn.get("kurou", false):
		return false
	if player_hp <= 1:
		return false
	player_hp -= 1
	draw_cards(2)
	skill_used_this_turn["kurou"] = true
	print("[苦肉] Lose 1 HP, draw 2 cards (HP: %d/%d)" % [player_hp, player_max_hp])
	return true


func _skill_rende() -> bool:
	## 劉備 仁德: give 2 cards → heal 1 HP. Once per turn.
	if skill_used_this_turn.get("rende", false):
		return false
	if hand.size() < 2:
		return false
	if player_hp >= player_max_hp:
		return false
	var to_discard := hand.slice(0, 2)
	for card in to_discard:
		hand.erase(card)
		discard_pile.append(card)
	player_hp = min(player_hp + 1, player_max_hp)
	skill_used_this_turn["rende"] = true
	print("[仁德] Discard 2, heal 1 HP (HP: %d/%d)" % [player_hp, player_max_hp])
	return true


func _skill_fanjian() -> bool:
	## 周瑜 反間: enemy guesses a suit — wrong guess = 2 damage. PvE: 50% chance.
	if skill_used_this_turn.get("fanjian", false):
		return false
	if enemies.is_empty():
		return false
	skill_used_this_turn["fanjian"] = true
	var target := _get_first_alive_enemy()
	if target and randi() % 2 == 0:
		target.take_damage(2)
		print("[反間] %s guessed wrong! 2 damage" % target.name_zh)
		_check_victory()
	else:
		print("[反間] %s guessed correctly — no damage" % (target.name_zh if target else "?"))
	return true


func _skill_keji() -> bool:
	## 呂蒙 克己: skip discard phase this turn → draw 1 card
	if skill_used_this_turn.get("keji", false):
		return false
	hand_size_limit = 9999  # Effectively skip discard
	draw_cards(1)
	skill_used_this_turn["keji"] = true
	print("[克己] Skip discard this turn, draw 1 card")
	return true


func _skill_qixi() -> bool:
	## 甘寧 奇襲: discard equipped card → deal 2 damage to enemy
	if equipment_slots.is_empty():
		return false
	var target := _get_first_alive_enemy()
	if not target:
		return false
	var slot_key: String = equipment_slots.keys()[0]
	var unequipped: CardData = equipment_slots[slot_key]
	equipment_slots.erase(slot_key)
	discard_pile.append(unequipped)
	target.take_damage(2)
	print("[奇襲] Discard %s, deal 2 damage to %s" % [unequipped.name_zh, target.name_zh])
	_check_victory()
	return true


func _skill_leiji() -> bool:
	## 張角 雷擊: judgment check — if spade, deal 2 lightning damage to enemy
	if skill_used_this_turn.get("leiji", false):
		return false
	var target := _get_first_alive_enemy()
	if not target:
		return false
	skill_used_this_turn["leiji"] = true
	var judged := draw_top_card()
	if judged and judged.suit == CardData.Suit.SPADE:
		target.take_damage(2)
		print("[雷擊] Spade judgment → 2 lightning damage to %s" % target.name_zh)
		discard_pile.append(judged)
		_check_victory()
	else:
		var info: String = "%s%d" % [judged.suit_symbol(), judged.number] if judged else "empty deck"
		print("[雷擊] Judgment %s — no spade, no damage" % info)
		if judged:
			discard_pile.append(judged)
	return true


func _skill_luoyi() -> bool:
	## 許褚 裸衣: toggle — 殺 deals +1 damage but you take 1 self-damage
	xu_chu_luoyi_active = not xu_chu_luoyi_active
	print("[裸衣] %s" % ("ON — 殺 dmg+1, self-dmg 1" if xu_chu_luoyi_active else "OFF"))
	return true


func _skill_guanxing() -> bool:
	## 諸葛亮 觀星: see top 5 cards of deck, reorder them. Simplified: draw 3.
	if skill_used_this_turn.get("guanxing", false):
		return false
	if deck.is_empty():
		return false
	skill_used_this_turn["guanxing"] = true
	var drawn: int = 0
	for i in range(min(3, deck.size())):
		if not deck.is_empty():
			var card: CardData = deck.pop_back()
			hand.append(card)
			drawn += 1
	print("[觀星] Drew %d cards — choose wisely" % drawn)
	return true


func _skill_lijian() -> bool:
	## 貂蟬 離間: force 2 enemies to duel each other — each takes 1 damage.
	if skill_used_this_turn.get("lijian", false):
		return false
	if enemies.size() < 2:
		return false
	skill_used_this_turn["lijian"] = true
	var alive_enemies := enemies.filter(func(e): return e.is_alive())
	if alive_enemies.size() < 2:
		return false
	# First two alive enemies duel
	alive_enemies[0].take_damage(1)
	alive_enemies[1].take_damage(1)
	print("[離間] %s and %s duel each other — each takes 1 damage!" % [alive_enemies[0].name_zh, alive_enemies[1].name_zh])
	# Check if any died
	enemies = enemies.filter(func(e): return e.is_alive())
	if enemies.is_empty():
		_award_victory_gold()
		battle_ended.emit(true)
	return true


func _get_first_alive_enemy() -> EnemyData:
	## Helper: get the first alive enemy, or null.
	for e in enemies:
		if e.is_alive():
			return e
	return null


func _ready() -> void:
	pass  # Battle is initialized externally after hero is loaded


func initialize_run() -> void:
	## Called ONCE at the start of a new run. Resets HP to full, loads starting deck.
	player_hp = player_hero.max_hp
	player_max_hp = player_hero.max_hp
	
	# Load starting deck for the entire run
	deck = player_hero.starting_deck.duplicate()
	discard_pile.clear()


func initialize_battle() -> void:
	## Called at each battle start. Preserves HP/deck from previous battle.
	## If first battle of run (deck empty), fall back to starting deck.
	if deck.is_empty() and discard_pile.is_empty():
		deck = player_hero.starting_deck.duplicate()
	
	hand_size_limit = player_hp
	
	# Shuffle remaining deck + discard pile together
	_reshuffle_discard()
	shuffle_deck()
	
	# Draw 4 cards (standard 三國殺 opening hand)
	draw_cards(4)
	
	# Reset per-battle state
	energy_used = 0
	block = 0
	wine_active = false
	attack_limit_reached = false
	skill_used_this_turn.clear()
	xu_chu_luoyi_active = false
	xiahou_yuan_extra_slash = false
	
	# Set up follower if hero starts with one
	_setup_follower()
	
	# Spawn enemy for this node
	_spawn_test_enemy()
	
	start_turn()


func start_turn() -> void:
	# Reset per-turn state
	energy_used = 0
	attack_limit_reached = false
	skill_used_this_turn.clear()
	wine_active = false  # Wine buff expires if not used
	dodge_used_this_attack = false
	# horse_plus: +1 block per turn (defense horse)
	if equipment_slots.has("horse_plus"):
		block += 1
		print("[+1馬] Gained 1 block from %s (total: %d)" % [equipment_slots["horse_plus"].name_zh, block])
	turn_started.emit(turn_number)
	_advance_phase(Phase.JUDGMENT)

func end_turn() -> void:
	_advance_phase(Phase.END)
	await _resolve_end_phase()
	
	# Enemy turns happen between player turns
	await _execute_enemy_turns()
	
	# Check if any enemies remain
	if enemies.is_empty() or _all_enemies_dead():
		_award_victory_gold()
		battle_ended.emit(true)
		return
	
	turn_number += 1
	start_turn()


func _execute_enemy_turns() -> void:
	## Each enemy takes its action.
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		
		match enemy.current_intent:
			EnemyData.Intent.ATTACK:
				_enemy_attack(enemy)
			EnemyData.Intent.DEFEND:
				enemy.heal(enemy.intent_value)
			EnemyData.Intent.BUFF:
				enemy.intent_value += 1
			EnemyData.Intent.SKILL:
				_enemy_skill(enemy)
		
		# Set next intent
		enemy.current_intent = enemy.next_intent(turn_number + 1)
		enemy.intent_value = 1 if enemy.current_intent != EnemyData.Intent.SKILL else 2
	
	# Remove dead enemies
	enemies = enemies.filter(func(e): return e.is_alive())

func _enemy_attack(enemy: EnemyData) -> void:
	## Enemy attacks — player can respond with 閃 to block.
	var blocked := false
	if follower and follower.is_alive() and follower.can_block:
		follower.take_damage(enemy.intent_value)
		blocked = true
	
	if not blocked:
		# Check if player has 閃 in hand — if so, offer response
		if _has_dodge_in_hand():
			dodge_used_this_attack = false
			awaiting_dodge.emit(enemy.name_zh, enemy.intent_value)
			await dodge_response_received  # Pause until player responds
			blocked = dodge_used_this_attack
		
		if not blocked:
			take_damage(enemy.intent_value)

func _has_dodge_in_hand() -> bool:
	for card in hand:
		if card.sub_type == CardData.SubType.DODGE:
			return true
	return false

func _has_crossbow() -> bool:
	## Check if 諸葛連弩 is equipped.
	if equipment_slots.has("weapon"):
		var wp = equipment_slots["weapon"]
		if wp.id == "zhuge_crossbow":
			return true
	return false

func use_dodge(card: CardData) -> bool:
	## Player uses a 閃 to block the current enemy attack.
	## Does NOT emit dodge_response_received — caller (UI) decides when to resolve.
	if card.sub_type != CardData.SubType.DODGE:
		return false
	if not hand.has(card):
		return false
	hand.erase(card)
	discard_pile.append(card)
	dodge_used_this_attack = true
	print("[Dodge] %s blocks the attack!" % card.name_zh)
	return true


func resolve_dodge() -> void:
	## Called by UI when enough 閃 cards have been played (for 無雙 double-dodge).
	dodge_response_received.emit()


func _current_attacker_requires_double() -> bool:
	## Check if the current attacking enemy has 無雙.
	for enemy in enemies:
		if enemy.requires_double_dodge and enemy.current_intent == EnemyData.Intent.ATTACK:
			return true
	return false

func skip_dodge() -> void:
	## Player chooses not to block — take full damage.
	dodge_used_this_attack = false
	dodge_response_received.emit()

func _enemy_skill(enemy: EnemyData) -> void:
	take_damage(enemy.intent_value + 1)

func _all_enemies_dead() -> bool:
	for e in enemies:
		if e.is_alive():
			return false
	return true

func _check_victory() -> bool:
	## Check if all enemies are dead. If yes, emit victory and return true.
	## Call this after any player action that could kill the last enemy.
	enemies = enemies.filter(func(e): return e.is_alive())
	if enemies.is_empty():
		_award_victory_gold()
		battle_ended.emit(true)
		return true
	return false

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
	# 周瑜 英姿: draw 1 extra card during draw phase
	if player_hero.id == "zhou_yu":
		draw_amount += 1
		print("[英姿] Draw +1 (total: %d)" % draw_amount)
	draw_cards(draw_amount)


func _resolve_end_phase() -> void:
	## Trigger end-of-turn effects and reset per-turn state.
	energy_used = 0
	wine_active = false
	attack_limit_reached = false
	block = 0
	skill_used_this_turn.clear()
	hand_size_limit = player_hp  # Reset (may be modified by 克己)
	
	# 陸遜 連營: if hand is empty at end of turn, draw 2
	if player_hero.id == "lu_xun" and hand.is_empty():
		draw_cards(2)
		print("[連營] Empty hand → draw 2 cards")
	
	# 許褚 裸衣 reset for next turn
	xu_chu_luoyi_active = false

# ============================================================
#  CARD OPERATIONS
# ============================================================

func draw_cards(count: int) -> void:
	for i in range(count):
		if deck.is_empty():
			_reshuffle_discard()
		if not deck.is_empty():
			var card: CardData = deck.pop_back()
			hand.append(card)

func draw_top_card() -> CardData:
	## Draw exactly 1 card from top of deck. Returns null if deck empty.
	if deck.is_empty():
		_reshuffle_discard()
	if deck.is_empty():
		return null
	var card: CardData = deck.pop_back()
	return card


func play_card(card: CardData, target = null) -> bool:
	## Attempt to play a card from hand. Returns true if successful.
	if not hand.has(card):
		return false
	
	# Check if this card type is playable in current phase
	if current_phase != Phase.PLAY:
		return false
	
	# Check hero skill substitution (龍膽, 武聖, 傾國, 國色, etc.)
	# Auto-substitute DODGE → SLASH (normally unplayable on your turn)
	var effective_card: CardData = card
	if card.card_type == CardData.CardType.BASIC and card.sub_type == CardData.SubType.DODGE:
		if _can_substitute(card, CardData.SubType.SLASH):
			effective_card = _get_substitute_card(card, CardData.SubType.SLASH)
			match player_hero.id:
				"zhao_yun": print("[龍膽] %s used as 殺" % card.name_zh)
				"guan_yu": print("[武聖] %s%s used as 殺" % [card.suit_symbol(), card.name_zh])
				_: print("[Sub] %s used as 殺" % card.name_zh)
	# 國色: diamond cards → 樂不思蜀
	elif player_hero.id == "da_qiao" and card.suit == CardData.Suit.DIAMOND and card.card_type != CardData.CardType.DELAY_STRATEGY:
		if _can_substitute(card, CardData.SubType.LE_BUSI):
			effective_card = _get_substitute_card(card, CardData.SubType.LE_BUSI)
			print("[國色] %s%s used as 樂不思蜀" % [card.suit_symbol(), card.name_zh])
	# 傾國: black cards → 閃 (in response to enemy attack, handled via use_dodge)
	
	# Handle card by effective type
	match effective_card.card_type:
		CardData.CardType.BASIC:
			match effective_card.sub_type:
				CardData.SubType.SLASH:
					# 殺 limit: normally 1/turn, but 張飛 咆哮/諸葛連弩/夏侯淵 疾行
					var slash_limit: int = energy
					if player_hero.id == "xiahou_yuan":
						slash_limit = 2  # 疾行: can play 2 殺 per turn
					if player_hero.id != "zhang_fei" and not _has_crossbow() and energy_used >= slash_limit:
						return false  # "殺" limit reached
					# Deal damage to target (with wine bonus)
					var dmg: int = effective_card.damage
					if wine_active:
						dmg += 1
						wine_active = false
					# Hero skill damage modifiers
					match player_hero.id:
						"lv_bu":
							dmg += 1  # 無雙: overwhelming force
						"huang_zhong":
							if target and target is EnemyData and hand.size() >= target.current_hp:
								dmg += 1
								print("[烈弓] Bonus damage! Hand %d >= enemy HP %d" % [hand.size(), target.current_hp])
						"ma_chao":
							# 鐵騎: judgment check — if red, +1 damage
							var judged := draw_top_card()
							if judged and judged.is_red():
								dmg += 1
								print("[鐵騎] Red judgment → dmg+1")
							if judged:
								discard_pile.append(judged)
						"xu_chu":
							if xu_chu_luoyi_active:
								dmg += 1  # 裸衣: bonus damage
								print("[裸衣] 殺 damage +1!")
					# 許褚 裸衣 self-damage: take 1 damage after 殺 connects
					if player_hero.id == "xu_chu" and xu_chu_luoyi_active:
						take_damage(1)
						print("[裸衣] Self-damage 1")
					# Equipment: weapon effects
					if equipment_slots.has("weapon"):
						var weapon_card: CardData = equipment_slots["weapon"]
						# 青釭劍 (Qinggang Sword): ignores enemy armor, +2 damage
						if weapon_card.name_zh == "青釭劍":
							dmg += 2
							print("[青釭劍] Ignores armor, +2 damage")
						# 青龍偃月刀 (Green Dragon Blade): if target survives, draw 1
						elif weapon_card.name_zh == "青龍偃月刀":
							dmg += 1
							print("[Weapon] +1 damage from %s" % weapon_card.name_zh)
						else:
							dmg += 1
							print("[Weapon] +1 damage from %s" % weapon_card.name_zh)
					# horse_minus (赤兔 etc.): +1 attack damage
					if equipment_slots.has("horse_minus"):
						dmg += 1
						print("[-1馬] +1 damage from %s" % equipment_slots["horse_minus"].name_zh)
					# Deal damage to target
					if target and target is EnemyData:
						target.take_damage(dmg)
						print("Dealt %d damage to %s (HP: %d/%d)" % [dmg, target.name_zh, target.current_hp, target.max_hp])
						if _check_victory():
							# Victory detected — clean up and return early
							hand.erase(card)
							discard_pile.append(card)
							return true
						# 青龍偃月刀 bonus: if target survived, draw 1
						if equipment_slots.has("weapon") and equipment_slots["weapon"].name_zh == "青龍偃月刀" and target.is_alive():
							draw_cards(1)
							print("[青龍偃月刀] Target survived → draw 1")
					energy_used += 1
				CardData.SubType.DODGE:
					return false  # Can only be played in response to 殺
				CardData.SubType.PEACH:
					player_hp = min(player_hp + effective_card.heal, player_max_hp)
				CardData.SubType.WINE:
					if player_hp <= 0:
						# Self-rescue when dying
						player_hp = 1
					else:
						# Boost next 殺
						wine_active = true
		CardData.CardType.STRATEGY:
			_resolve_strategy(effective_card, target)
			# 黃月英 集智: play strategy card → draw 1
			if player_hero.id == "huang_yueying":
				draw_cards(1)
				print("[集智] Strategy played → draw 1")
		CardData.CardType.EQUIPMENT:
			_equip_card(effective_card)
		CardData.CardType.DELAY_STRATEGY:
			_place_in_judgment(effective_card, target)
	
	hand.erase(card)  # Remove the original card
	discard_pile.append(card)
	return true


func _resolve_strategy(card: CardData, target) -> void:
	## Execute strategy card effects. Target may be null for self-cast / AoE cards.
	match card.sub_type:
		CardData.SubType.DISMANTLE:
			# 過河拆橋: Target discards 1 card (PvE adaptation: deal 1 damage)
			if target and target is EnemyData and target.is_alive():
				target.take_damage(1)
				print("[過河拆橋] %s loses 1 HP (discard adapted for PvE)" % target.name_zh)
				_check_victory()
		CardData.SubType.STEAL:
			# 順手牽羊: Steal 1 card from target (PvE adaptation: draw 1 card)
			draw_cards(1)
			print("[順手牽羊] Draw 1 card (steal adapted for PvE)")
		CardData.SubType.DRAW2:
			# 無中生有: Draw 2 cards
			draw_cards(2)
			print("[無中生有] Draw 2 cards")
		CardData.SubType.DUEL:
			# 決鬥: Force target into a duel — take 1 damage if they can't fight back
			# PvE: deal 2 damage (simulates the back-and-forth of a duel)
			if target and target is EnemyData and target.is_alive():
				var duel_dmg: int = 2
				if player_hero.id == "lv_bu":
					duel_dmg += 1  # 無雙: overwhelming duel
				target.take_damage(duel_dmg)
				print("[決鬥] %s takes %d duel damage (HP: %d/%d)" % [target.name_zh, duel_dmg, target.current_hp, target.max_hp])
				_check_victory()
		CardData.SubType.BARBARIAN:
			# 南蠻入侵: All enemies must play 殺 or take 1 damage
			_aoe_damage(1)
			print("[南蠻入侵] All enemies take 1 damage")
		CardData.SubType.VOLLEY:
			# 萬箭齊發: All enemies must play 閃 or take 1 damage
			# Rarer card (only 1 in deck) — deals 2 AoE damage
			_aoe_damage(2)
			print("[萬箭齊發] All enemies take 2 damage")
		CardData.SubType.PEACH_GARDEN:
			# 桃園結義: Heal all characters for 1
			player_hp = min(player_hp + 1, player_max_hp)
			if follower and follower.is_alive():
				follower.heal(1)
			for enemy in enemies:
				if enemy.is_alive():
					enemy.heal(1)
			print("[桃園結義] All characters heal 1 HP")
		CardData.SubType.HARVEST:
			# 五穀豐登: Reveal N cards, players take turns picking
			# PvE simplification: draw cards equal to number of enemies (min 2)
			var harvest_count: int = max(2, enemies.size())
			draw_cards(harvest_count)
			print("[五穀豐登] Draw %d cards" % harvest_count)
		CardData.SubType.NEGATE:
			# 無懈可擊: Cancel another strategy card
			# PvE adaptation: gain block that absorbs next incoming damage
			block += 2
			print("[無懈可擊] Gain 2 block (total: %d)" % block)


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

func _award_victory_gold() -> void:
	## Award gold based on node type. Bosses and elites give more.
	if not map_manager:
		return
	var amount := 10  # Default battle reward
	var node_def = map_manager.get_current_node()
	if node_def:
		match node_def.type:
			3: amount = 20   # ELITE
			4: amount = 30   # BOSS
	map_manager.add_gold(amount)
	print("[Gold] +%d (total: %d)" % [amount, map_manager.get_gold()])


func upgrade_random_card() -> bool:
	## Pick a random card from the deck and upgrade it.
	## Returns true if an upgrade happened.
	if deck.is_empty():
		print("[Upgrade] Deck is empty — nothing to upgrade")
		return false
	
	var index: int = randi() % deck.size()
	var old_card: CardData = deck[index]
	var upgraded := _create_upgraded_card(old_card)
	
	if upgraded == null or upgraded == old_card:
		print("[Upgrade] %s has no upgrade variant" % old_card.name_zh)
		return false
	
	deck[index] = upgraded
	print("[Upgrade] %s → %s (damage:%d heal:%d block:%d)" % [
		old_card.name_zh, upgraded.name_zh,
		upgraded.damage, upgraded.heal, upgraded.block
	])
	return true


func _create_upgraded_card(card: CardData) -> CardData:
	## Return an upgraded copy of the card. Returns original if no upgrade defined.
	var up := card.duplicate()
	var changed := false
	
	match card.sub_type:
		CardData.SubType.SLASH:
			up.damage += 1
			up.name_zh = card.name_zh + "+"
			changed = true
		CardData.SubType.DODGE:
			up.block += 1
			up.name_zh = card.name_zh + "+"
			changed = true
		CardData.SubType.PEACH:
			up.heal += 1
			up.name_zh = card.name_zh + "+"
			changed = true
		CardData.SubType.WINE:
			up.damage += 1
			up.name_zh = card.name_zh + "+"
			changed = true
		CardData.SubType.DISMANTLE:
			up.discard_count += 1
			up.name_zh = card.name_zh + "+"
			changed = true
		CardData.SubType.STEAL:
			up.draw_count = 2
			up.name_zh = card.name_zh + "+"
			changed = true
		CardData.SubType.DRAW2:
			up.draw_count = 3
			up.name_zh = card.name_zh + "+"
			changed = true
		CardData.SubType.DUEL:
			up.damage += 1
			up.name_zh = card.name_zh + "+"
			changed = true
		CardData.SubType.BARBARIAN:
			up.damage += 1
			up.name_zh = card.name_zh + "+"
			changed = true
		CardData.SubType.VOLLEY:
			up.damage += 1
			up.name_zh = card.name_zh + "+"
			changed = true
		CardData.SubType.PEACH_GARDEN:
			up.heal += 1
			up.name_zh = card.name_zh + "+"
			changed = true
		CardData.SubType.HARVEST:
			up.draw_count = card.draw_count + 1
			up.name_zh = card.name_zh + "+"
			changed = true
		CardData.SubType.NEGATE:
			up.block = 3
			up.name_zh = card.name_zh + "+"
			changed = true
		CardData.SubType.WEAPON:
			up.attack_range += 1
			up.name_zh = card.name_zh + "+"
			changed = true
		CardData.SubType.ARMOR:
			up.block += 1
			up.name_zh = card.name_zh + "+"
			changed = true
	
	if changed:
		up.rarity = CardData.Rarity.RARE
		up.id = card.id + "+"
		return up
	return card


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

func _aoe_damage(amount: int) -> void:
	## Deal damage to all alive enemies. Remove dead enemies after.
	for enemy in enemies.duplicate():
		if enemy.is_alive():
			enemy.take_damage(amount)
	_check_victory()

func take_damage(amount: int) -> void:
	## Apply damage to player, reduced by block and armor first.
	var effective: int = amount
	if block > 0:
		var absorbed: int = min(amount, block)
		block -= absorbed
		effective -= absorbed
		print("[Block] Absorbed %d damage, %d block remaining" % [absorbed, block])
	# Armor effects
	if equipment_slots.has("armor") and effective > 0:
		var armor_card: CardData = equipment_slots["armor"]
		# 八卦陣 (Bagua Shield): 50% chance to negate damage entirely
		if armor_card.id.begins_with("armor_BA") or armor_card.name_zh == "八卦陣":
			if randi() % 2 == 0:
				effective = 0
				print("[八卦陣] Dodged attack completely!")
			else:
				effective -= 1
				print("[Armor] %s reduced damage by 1" % armor_card.name_zh)
		# 仁王盾 (Renwang Shield): negate damage from black-suit attacks
		elif armor_card.name_zh == "仁王盾":
			# In PvE, 50% chance to negate (simplified from the original "black attacks" rule)
			if randi() % 2 == 0:
				effective = 0
				print("[仁王盾] Blocked attack!")
			else:
				effective -= 1
				print("[Armor] %s reduced damage by 1" % armor_card.name_zh)
		else:
			# Default armor: -1 damage
			effective -= 1
			print("[Armor] %s reduced damage by 1" % armor_card.name_zh)
	# Check for 青釭劍 (Qinggang Sword) — ignores armor (no effect here since armor already applied)
	# horse_plus: already accounted for — gives +1 block at start of turn
	player_hp = max(0, player_hp - effective)
	_on_damage_taken(effective)  # Trigger hero skill reactions (e.g. 奸雄, 反饋, 剛烈)
	if player_hp <= 0:
		# 桃 self-rescue: check if player has 桃 in hand
		var rescued := false
		for card in hand:
			if card.sub_type == CardData.SubType.PEACH:
				hand.erase(card)
				discard_pile.append(card)
				player_hp = 1
				print("[Rescue] 桃 played at 0 HP → restored to 1 HP")
				rescued = true
				break
		if not rescued:
			# Check 天香 (小喬) — auto-negate if red card in hand
			if player_hero.id == "xiao_qiao":
				for card in hand:
					if card.is_red():
						hand.erase(card)
						discard_pile.append(card)
						player_hp = 1
						print("[天香] Red card discarded → restored to 1 HP")
						rescued = true
						break
			if not rescued:
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


func _spawn_test_enemy() -> void:
	## Spawn enemy from MapManager if available, otherwise create test enemy.
	if map_manager:
		var enemy = map_manager.get_enemy_for_current_node()
		enemy.current_intent = enemy.intent_pattern[0]
		enemy.intent_value = map_manager._get_intent_value(enemy.current_intent, enemy.id)
		enemies.append(enemy)
	else:
		# Fallback: hardcoded test enemy (legacy mode)
		var enemy := EnemyData.new()
		enemy.id = "yellow_turban_soldier"
		enemy.name_zh = "黃巾兵"
		enemy.name_en = "Yellow Turban Soldier"
		enemy.max_hp = 5
		enemy.initialize()
		enemy.current_intent = EnemyData.Intent.ATTACK
		enemy.intent_value = 1
		enemy.intent_pattern = [EnemyData.Intent.ATTACK, EnemyData.Intent.ATTACK, EnemyData.Intent.DEFEND]
		enemies.append(enemy)