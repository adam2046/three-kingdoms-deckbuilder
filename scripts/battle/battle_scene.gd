extends Control
class_name BattleScene

## BattleScene — the main gameplay screen.
## Contains: hand area, player HP/energy, enemy display, judgment zone, end turn button.
## Now integrated with MapManager for roguelike progression.

@onready var battle_manager: BattleManager = $BattleManager
@onready var map_manager = $MapManager
@onready var hand_container: HBoxContainer = $UI/HandContainer
@onready var energy_label: Label = $UI/TopBar/EnergyLabel
@onready var hp_label: Label = $UI/TopBar/HPLabel
@onready var hero_label: Label = $UI/TopBar/HeroLabel
@onready var phase_label: Label = $UI/TopBar/PhaseLabel
@onready var zone_label: Label = $UI/TopBar/ZoneLabel
@onready var gold_label: Label = $UI/TopBar/GoldLabel
@onready var deck_label: Label = $UI/DeckInfo/DeckLabel
@onready var discard_label: Label = $UI/DeckInfo/DiscardLabel
@onready var end_turn_btn: Button = $UI/EndTurnBtn
@onready var skill_btn: Button = $UI/SkillBtn
@onready var enemy_container: HBoxContainer = $EnemyArea/EnemyContainer
@onready var judgment_display: Control = $UI/JudgmentZone
@onready var follower_display: Control = $UI/FollowerDisplay
@onready var reward_overlay: Control = $UI/RewardOverlay
@onready var reward_container: HBoxContainer = $UI/RewardOverlay/RewardContainer
@onready var reward_title: Label = $UI/RewardOverlay/RewardTitle

var reward_active: bool = false  # Blocks battle interaction while choosing reward
var dodge_response_active: bool = false  # Blocks normal play during enemy attack response


func _ready() -> void:
	# Connect signals
	battle_manager.turn_started.connect(_on_turn_started)
	battle_manager.phase_changed.connect(_on_phase_changed)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.awaiting_dodge.connect(_on_awaiting_dodge)
	battle_manager.dodge_response_received.connect(_on_dodge_resolved)
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	skill_btn.pressed.connect(_on_skill_pressed)
	skill_btn.visible = false
	
	# Set up roguelike progression
	battle_manager.map_manager = map_manager
	map_manager.node_changed.connect(_on_node_changed)
	map_manager.gold_changed.connect(_on_gold_changed)
	
	# Load test hero BEFORE starting run (run triggers first battle)
	_load_test_hero(PlayerData.chosen_hero_id)  # Hero chosen on select screen
	
	# Now start the roguelike run — triggers _on_node_changed → _start_battle
	map_manager.start_run()


func _load_test_hero(hero_id: String = "zhao_yun") -> void:
	var hero := HeroData.new()
	hero.id = hero_id
	
	match hero_id:
		"zhao_yun":
			hero.name_zh = "趙雲"
			hero.max_hp = 4
			hero.faction = HeroData.Faction.SHU
			hero.archetype = HeroData.Archetype.BALANCED
			hero.skill_1_name_zh = "龍膽"
			hero.skill_1_desc_zh = "殺可當閃，閃可當殺"
			hero.starting_deck = _create_starter_deck_balanced()
		"cao_cao":
			hero.name_zh = "曹操"
			hero.max_hp = 4
			hero.faction = HeroData.Faction.WEI
			hero.archetype = HeroData.Archetype.BALANCED
			hero.skill_1_name_zh = "奸雄"
			hero.skill_1_desc_zh = "受傷後摸1張牌"
			hero.starting_deck = _create_starter_deck_balanced()
		"sun_quan":
			hero.name_zh = "孫權"
			hero.max_hp = 4
			hero.faction = HeroData.Faction.WU
			hero.archetype = HeroData.Archetype.BALANCED
			hero.skill_1_name_zh = "制衡"
			hero.skill_1_desc_zh = "棄全部手牌，摸等量牌（每回1次）"
			hero.starting_deck = _create_starter_deck_balanced()
		"guan_yu":
			hero.name_zh = "關羽"
			hero.max_hp = 4
			hero.faction = HeroData.Faction.SHU
			hero.archetype = HeroData.Archetype.ATTACK
			hero.skill_1_name_zh = "武聖"
			hero.skill_1_desc_zh = "紅色牌可當作殺使用"
			hero.starting_deck = _create_starter_deck_attack()
		"zhang_fei":
			hero.name_zh = "張飛"
			hero.max_hp = 4
			hero.faction = HeroData.Faction.SHU
			hero.archetype = HeroData.Archetype.ATTACK
			hero.skill_1_name_zh = "咆哮"
			hero.skill_1_desc_zh = "出殺無次數限制"
			hero.starting_deck = _create_starter_deck_attack()
		"lv_bu":
			hero.name_zh = "呂布"
			hero.max_hp = 4
			hero.faction = HeroData.Faction.QUN
			hero.archetype = HeroData.Archetype.ATTACK
			hero.skill_1_name_zh = "無雙"
			hero.skill_1_desc_zh = "殺傷害+1，決鬥傷害+1"
			hero.starting_deck = _create_starter_deck_attack()
		"ma_chao":
			hero.name_zh = "馬超"
			hero.max_hp = 4
			hero.faction = HeroData.Faction.SHU
			hero.archetype = HeroData.Archetype.ATTACK
			hero.skill_1_name_zh = "馬術"
			hero.skill_1_desc_zh = "攻擊距離-1（鎖定技）"
			hero.skill_2_name_zh = "鐵騎"
			hero.skill_2_desc_zh = "使用殺後判定：紅牌則傷害+1"
			hero.starting_deck = _create_starter_deck_attack()
		"huang_zhong":
			hero.name_zh = "黃忠"
			hero.max_hp = 4
			hero.faction = HeroData.Faction.SHU
			hero.archetype = HeroData.Archetype.ATTACK
			hero.skill_1_name_zh = "烈弓"
			hero.skill_1_desc_zh = "手牌數≥目標體力值時，殺傷害+1"
			hero.starting_deck = _create_starter_deck_attack()
		"liu_bei":
			hero.name_zh = "劉備"
			hero.max_hp = 4
			hero.faction = HeroData.Faction.SHU
			hero.archetype = HeroData.Archetype.SUPPORT
			hero.skill_1_name_zh = "仁德"
			hero.skill_1_desc_zh = "give cards to heal"
			hero.starting_deck = _create_starter_deck_balanced()
		"zhuge_liang":
			hero.name_zh = "諸葛亮"
			hero.max_hp = 3
			hero.faction = HeroData.Faction.SHU
			hero.archetype = HeroData.Archetype.CONTROL
			hero.skill_1_name_zh = "觀星"
			hero.skill_1_desc_zh = "see top 5, reorder"
			hero.starting_deck = _create_starter_deck_balanced()
		"sim_yi":
			hero.name_zh = "司馬懿"
			hero.max_hp = 3
			hero.faction = HeroData.Faction.WEI
			hero.archetype = HeroData.Archetype.CONTROL
			hero.skill_1_name_zh = "反饋"
			hero.skill_1_desc_zh = "take damage → steal enemy card"
			hero.starting_deck = _create_starter_deck_balanced()
		"xiahou_dun":
			hero.name_zh = "夏侯惇"
			hero.max_hp = 4
			hero.faction = HeroData.Faction.WEI
			hero.archetype = HeroData.Archetype.ATTACK
			hero.skill_1_name_zh = "剛烈"
			hero.skill_1_desc_zh = "take damage → deal 1 back"
			hero.starting_deck = _create_starter_deck_attack()
		"zhen_ji":
			hero.name_zh = "甄姬"
			hero.max_hp = 3
			hero.faction = HeroData.Faction.WEI
			hero.archetype = HeroData.Archetype.DEFENSE
			hero.skill_1_name_zh = "傾國"
			hero.skill_1_desc_zh = "black cards → 閃"
			hero.starting_deck = _create_starter_deck_balanced()
		"guo_jia":
			hero.name_zh = "郭嘉"
			hero.max_hp = 3
			hero.faction = HeroData.Faction.WEI
			hero.archetype = HeroData.Archetype.SUPPORT
			hero.skill_1_name_zh = "天妒"
			hero.skill_1_desc_zh = "draw 2 when damaged"
			hero.starting_deck = _create_starter_deck_balanced()
		"zhou_yu":
			hero.name_zh = "周瑜"
			hero.max_hp = 3
			hero.faction = HeroData.Faction.WU
			hero.archetype = HeroData.Archetype.CONTROL
			hero.skill_1_name_zh = "反間"
			hero.skill_1_desc_zh = "guess suit or take 1 dmg"
			hero.starting_deck = _create_starter_deck_balanced()
		"lu_xun":
			hero.name_zh = "陸遜"
			hero.max_hp = 3
			hero.faction = HeroData.Faction.WU
			hero.archetype = HeroData.Archetype.CONTROL
			hero.skill_1_name_zh = "連營"
			hero.skill_1_desc_zh = "last card → draw 2"
			hero.starting_deck = _create_starter_deck_balanced()
		"huang_gai":
			hero.name_zh = "黃蓋"
			hero.max_hp = 4
			hero.faction = HeroData.Faction.WU
			hero.archetype = HeroData.Archetype.ATTACK
			hero.skill_1_name_zh = "苦肉"
			hero.skill_1_desc_zh = "lose 1 HP → draw 2"
			hero.starting_deck = _create_starter_deck_attack()
		"da_qiao":
			hero.name_zh = "大喬"
			hero.max_hp = 3
			hero.faction = HeroData.Faction.WU
			hero.archetype = HeroData.Archetype.CONTROL
			hero.skill_1_name_zh = "國色"
			hero.skill_1_desc_zh = "diamond cards → 樂"
			hero.starting_deck = _create_starter_deck_balanced()
		"diao_chan":
			hero.name_zh = "貂蟬"
			hero.max_hp = 3
			hero.faction = HeroData.Faction.QUN
			hero.archetype = HeroData.Archetype.CONTROL
			hero.skill_1_name_zh = "離間"
			hero.skill_1_desc_zh = "force 2 enemies to duel"
			hero.starting_deck = _create_starter_deck_balanced()
		_:
			# Fallback: treat unknown heroes as balanced
			hero.name_zh = hero_id
			hero.max_hp = 4
			hero.faction = HeroData.Faction.SHU
			hero.archetype = HeroData.Archetype.BALANCED
			hero.skill_1_name_zh = "—"
			hero.skill_1_desc_zh = ""
			hero.starting_deck = _create_starter_deck_balanced()
	
	battle_manager.player_hero = hero


func _create_starter_deck_balanced() -> Array[CardData]:
	var deck: Array[CardData] = []
	var card_ids := [
		"slash_spade_7", "slash_heart_10", "slash_club_4", "slash_diamond_8",
		"dodge_heart_2", "dodge_diamond_6", "dodge_diamond_J",
		"peach_heart_4", "wine_spade_3",
		"dismantle_spade_3", "steal_spade_4", "draw2_club_7",
		"duel_spade_A", "barbarian_spade_7", "peach_garden_heart_A",
		"negate_club_Q", "weapon_spade_A",
	]
	for cid in card_ids:
		var card := _create_test_card(cid)
		if card:
			deck.append(card)
	return deck


func _create_starter_deck_attack() -> Array[CardData]:
	## Attack-type starter: 5 殺, 2 閃, 1 桃, 1 酒, 1 決鬥 = 10 cards
	var deck: Array[CardData] = []
	var card_ids := [
		"slash_spade_7", "slash_heart_10", "slash_club_4", "slash_diamond_8", "slash_club_5",
		"dodge_heart_2", "dodge_diamond_6",
		"peach_heart_4", "wine_spade_3",
		"duel_spade_A",
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
		"steal":
			card.card_type = CardData.CardType.STRATEGY
			card.sub_type = CardData.SubType.STEAL
			card.name_zh = "順手牽羊"
		"draw2":
			card.card_type = CardData.CardType.STRATEGY
			card.sub_type = CardData.SubType.DRAW2
			card.name_zh = "無中生有"
			card.draw_count = 2
		"duel":
			card.card_type = CardData.CardType.STRATEGY
			card.sub_type = CardData.SubType.DUEL
			card.name_zh = "決鬥"
			card.damage = 2
		"barbarian":
			card.card_type = CardData.CardType.STRATEGY
			card.sub_type = CardData.SubType.BARBARIAN
			card.name_zh = "南蠻入侵"
			card.damage = 1
		"volley":
			card.card_type = CardData.CardType.STRATEGY
			card.sub_type = CardData.SubType.VOLLEY
			card.name_zh = "萬箭齊發"
			card.damage = 2
		"peach_garden":
			card.card_type = CardData.CardType.STRATEGY
			card.sub_type = CardData.SubType.PEACH_GARDEN
			card.name_zh = "桃園結義"
			card.heal = 1
		"harvest":
			card.card_type = CardData.CardType.STRATEGY
			card.sub_type = CardData.SubType.HARVEST
			card.name_zh = "五穀豐登"
		"negate":
			card.card_type = CardData.CardType.STRATEGY
			card.sub_type = CardData.SubType.NEGATE
			card.name_zh = "無懈可擊"
		"weapon":
			card.card_type = CardData.CardType.EQUIPMENT
			card.sub_type = CardData.SubType.WEAPON
			card.name_zh = "武器"
			card.attack_range = 1
		"armor":
			card.card_type = CardData.CardType.EQUIPMENT
			card.sub_type = CardData.SubType.ARMOR
			card.name_zh = "防具"
			card.block = 1
		"crossbow":
			card.card_type = CardData.CardType.EQUIPMENT
			card.sub_type = CardData.SubType.WEAPON
			card.name_zh = "諸葛連弩"
			card.attack_range = 1
			card.id = "zhuge_crossbow"
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
	_refresh_skill_button()


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
	hero_label.text = battle_manager.player_hero.name_zh
	hp_label.text = "HP: %d/%d" % [battle_manager.player_hp, battle_manager.player_max_hp]
	energy_label.text = "殺: %d/%d" % [battle_manager.energy_used, battle_manager.energy]
	if battle_manager.wine_active:
		energy_label.text += "  🍶"
	if battle_manager.block > 0:
		energy_label.text += "  🛡%d" % battle_manager.block
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
			if card.sub_type == CardData.SubType.SLASH:
				return true
			# 龍膽: 閃 can be used as 殺 — needs target
			if card.sub_type == CardData.SubType.DODGE and battle_manager._can_substitute(card, CardData.SubType.SLASH):
				return true
			return false
		CardData.CardType.STRATEGY:
			return card.sub_type in [CardData.SubType.DISMANTLE, CardData.SubType.STEAL, CardData.SubType.DUEL]
		_:
			return false


func _on_card_played(card: CardData) -> void:
	## Player clicks a card. If needs target, select and wait for enemy click.
	## If no target (peach, draw2), play immediately.
	
	# During dodge response: only 閃 is playable
	if dodge_response_active:
		if card.sub_type == CardData.SubType.DODGE:
			battle_manager.use_dodge(card)
			_refresh_hand()
		return
	
	if reward_active or shop_active or battle_manager.current_phase != BattleManager.Phase.PLAY:
		return
	
	var needs_target := _card_needs_target(card)
	
	if needs_target:
		# Block selection if 殺 limit reached (unless 張飛 咆哮 or 諸葛連弩)
		if card.sub_type == CardData.SubType.SLASH and battle_manager.player_hero.id != "zhang_fei" and not battle_manager._has_crossbow() and battle_manager.energy_used >= battle_manager.energy:
			print("[Blocked] 殺 limit reached (%d/%d)" % [battle_manager.energy_used, battle_manager.energy])
			return
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
	if battle_manager.current_phase != BattleManager.Phase.PLAY:
		return
	
	var success := battle_manager.play_card(selected_card, enemy)
	
	if success:
		selected_card = null
		for child in hand_container.get_children():
			if child is CardNode:
				child.highlight(false)
		_refresh_ui()
	else:
		# Play failed (energy exhausted, invalid target, etc.)
		# Clear highlight so player can see it didn't work
		for child in hand_container.get_children():
			if child is CardNode and child.card_data == selected_card:
				child.highlight(false)
		selected_card = null
		print("[Play Failed] Card not played — check energy/target")


func _on_end_turn_pressed() -> void:
	## Player clicks "End Turn" or "Take Damage" during dodge response.
	if dodge_response_active:
		battle_manager.skip_dodge()
		return
	
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
		print("VICTORY! Gold: %d" % map_manager.get_gold())
		_show_card_rewards()
	else:
		print("DEFEAT... Run over.")
		# TODO: Show defeat screen, offer restart


func _on_awaiting_dodge(enemy_name: String, damage: int) -> void:
	## Enemy is attacking — enable dodge response mode.
	dodge_response_active = true
	phase_label.text = "%s 攻擊! 傷害 %d — 出閃?" % [enemy_name, damage]
	end_turn_btn.text = "承受傷害"
	end_turn_btn.visible = true
	_refresh_hand()  # Refresh so player can click 閃 cards


func _on_dodge_resolved() -> void:
	## Player responded to enemy attack — reset mode.
	dodge_response_active = false
	end_turn_btn.text = "結束回合"
	end_turn_btn.visible = false
	_refresh_ui()


func _start_battle() -> void:
	## Initialize a new battle using the current map node's enemies.
	battle_manager.initialize_battle()
	_refresh_ui()


func _on_node_changed(node_type: int, node_index: int) -> void:
	## Called when the map advances to a new node.
	var type_names := ["起點", "戰鬥", "營火", "精英", "首領", "商店", "事件"]
	var type_str: String = type_names[node_type] if node_type < type_names.size() else "?"
	
	if zone_label:
		zone_label.text = "%s — %s" % [map_manager.get_current_zone().name_zh, type_str]
	
	match node_type:
		1, 3, 4:  # BATTLE=1, ELITE=3, BOSS=4
			# Only auto-start battles. Campfire/shop/event are handled separately.
			_start_battle()
		2:  # CAMPFIRE=2
			# Heal 20% max HP (rounded up) + upgrade 1 random card
			var heal_amount: int = max(1, ceil(battle_manager.player_max_hp * 0.2))
			battle_manager.player_hp = min(battle_manager.player_hp + heal_amount, battle_manager.player_max_hp)
			print("[Campfire] Healed %d HP (now %d/%d)" % [heal_amount, battle_manager.player_hp, battle_manager.player_max_hp])
			battle_manager.upgrade_random_card()
			map_manager.advance_to_next_node()
		5:  # SHOP=5
			_show_shop()  # Player interacts, then advance is called from shop handlers
		6:  # EVENT=6
			_resolve_event()
		_:
			map_manager.advance_to_next_node()  # Skip unsupported nodes for now


func _on_gold_changed(gold: int) -> void:
	if gold_label:
		gold_label.text = "💰 %d" % gold


func _refresh_skill_button() -> void:
	if battle_manager.current_phase == BattleManager.Phase.PLAY:
		skill_btn.visible = battle_manager._has_active_skill()
		if skill_btn.visible:
			match battle_manager.player_hero.id:
				"sun_quan":
					skill_btn.text = "制衡"
	else:
		skill_btn.visible = false


func _on_skill_pressed() -> void:
	match battle_manager.player_hero.id:
		"sun_quan":
			battle_manager._activate_skill("zhiheng")
	_refresh_ui()


# ============================================================
#  CARD REWARD SYSTEM
# ============================================================

var _reward_cards: Array = []  # Current reward card choices


func _show_card_rewards() -> void:
	## Display 3 card choices after battle victory.
	reward_active = true
	_reward_cards = _generate_reward_cards(3)
	
	# Clear previous reward cards
	for child in reward_container.get_children():
		child.queue_free()
	
	# Show the overlay
	reward_overlay.visible = true
	reward_title.text = "選擇獎勵卡牌"
	
	# Create CardNode for each reward
	for card in _reward_cards:
		var card_node = CardNode.new()
		card_node.setup(card)
		card_node.card_clicked.connect(_on_reward_card_selected)
		reward_container.add_child(card_node)
	
	# Hide battle UI elements
	end_turn_btn.visible = false
	skill_btn.visible = false


func _on_reward_card_selected(card: CardData) -> void:
	## Player clicked a reward card — add it to the deck and advance.
	battle_manager.deck.append(card)
	print("[Reward] Added %s to deck" % card.name_zh)
	_hide_card_rewards()


func _hide_card_rewards() -> void:
	## Hide reward overlay and advance to next map node.
	reward_overlay.visible = false
	reward_active = false
	
	# Clear reward cards
	for child in reward_container.get_children():
		child.queue_free()
	_reward_cards.clear()
	
	# Advance to next node
	map_manager.advance_to_next_node()


func _generate_reward_cards(count: int) -> Array:
	## Generate random cards for reward selection.
	var pool: Array = []
	
	# Card templates for the reward pool
	var templates := [
		{"id": "slash_spade_A", "type": "slash", "suit": "spade", "num": "A"},
		{"id": "slash_heart_K", "type": "slash", "suit": "heart", "num": "K"},
		{"id": "slash_club_5", "type": "slash", "suit": "club", "num": "5"},
		{"id": "slash_diamond_Q", "type": "slash", "suit": "diamond", "num": "Q"},
		{"id": "dodge_heart_A", "type": "dodge", "suit": "heart", "num": "A"},
		{"id": "dodge_diamond_K", "type": "dodge", "suit": "diamond", "num": "K"},
		{"id": "dodge_diamond_3", "type": "dodge", "suit": "diamond", "num": "3"},
		{"id": "peach_heart_Q", "type": "peach", "suit": "heart", "num": "Q"},
		{"id": "peach_heart_3", "type": "peach", "suit": "heart", "num": "3"},
		{"id": "wine_spade_9", "type": "wine", "suit": "spade", "num": "9"},
		{"id": "wine_club_3", "type": "wine", "suit": "club", "num": "3"},
		{"id": "dismantle_heart_3", "type": "dismantle", "suit": "heart", "num": "3"},
		{"id": "dismantle_spade_Q", "type": "dismantle", "suit": "spade", "num": "Q"},
		{"id": "steal_diamond_3", "type": "steal", "suit": "diamond", "num": "3"},
		{"id": "steal_spade_J", "type": "steal", "suit": "spade", "num": "J"},
		{"id": "draw2_club_8", "type": "draw2", "suit": "club", "num": "8"},
		{"id": "draw2_club_J", "type": "draw2", "suit": "club", "num": "J"},
		{"id": "duel_spade_A", "type": "duel", "suit": "spade", "num": "A"},
		{"id": "duel_club_A", "type": "duel", "suit": "club", "num": "A"},
		{"id": "barbarian_spade_K", "type": "barbarian", "suit": "spade", "num": "K"},
		{"id": "barbarian_club_7", "type": "barbarian", "suit": "club", "num": "7"},
		{"id": "volley_heart_A", "type": "volley", "suit": "heart", "num": "A"},
		{"id": "peach_garden_heart_A", "type": "peach_garden", "suit": "heart", "num": "A"},
		{"id": "harvest_heart_3", "type": "harvest", "suit": "heart", "num": "3"},
		{"id": "harvest_heart_4", "type": "harvest", "suit": "heart", "num": "4"},
		{"id": "negate_spade_J", "type": "negate", "suit": "spade", "num": "J"},
		{"id": "negate_club_Q", "type": "negate", "suit": "club", "num": "Q"},
		{"id": "negate_diamond_K", "type": "negate", "suit": "diamond", "num": "K"},
		{"id": "weapon_spade_A", "type": "weapon", "suit": "spade", "num": "A"},
		{"id": "armor_spade_2", "type": "armor", "suit": "spade", "num": "2"},
		{"id": "crossbow_spade_A", "type": "crossbow", "suit": "spade", "num": "A"},
	]
	
	templates.shuffle()
	for i in range(min(count, templates.size())):
		var tmpl = templates[i]
		var card = _create_test_card(tmpl["id"])
		if card:
			pool.append(card)
	
	return pool


# ============================================================
#  SHOP SYSTEM
# ============================================================

const SHOP_CARD_PRICE: int = 5
var shop_active: bool = false


func _show_shop() -> void:
	## Display shop with 3 cards for purchase.
	shop_active = true
	_reward_cards = _generate_reward_cards(3)
	
	# Clear previous cards
	for child in reward_container.get_children():
		child.queue_free()
	
	# Show overlay with shop styling
	reward_overlay.visible = true
	reward_title.text = "商店 — 金幣: %d  (每張 %d 金)" % [map_manager.get_gold(), SHOP_CARD_PRICE]
	
	# Create card nodes with price labels
	for card in _reward_cards:
		var vbox := VBoxContainer.new()
		var card_node = CardNode.new()
		card_node.setup(card)
		card_node.card_clicked.connect(_on_shop_card_bought)
		vbox.add_child(card_node)
		
		var price_label := Label.new()
		price_label.text = "%d 金" % SHOP_CARD_PRICE
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.add_theme_font_size_override("font_size", 16)
		vbox.add_child(price_label)
		
		reward_container.add_child(vbox)
	
	# Hide battle UI
	end_turn_btn.visible = false
	skill_btn.visible = false


func _on_shop_card_bought(card: CardData) -> void:
	## Player clicked a shop card — buy it if enough gold.
	if not map_manager.run_data.spend_gold(SHOP_CARD_PRICE):
		print("[Shop] Not enough gold!")
		return
	
	battle_manager.deck.append(card)
	print("[Shop] Bought %s for %d gold (remaining: %d)" % [card.name_zh, SHOP_CARD_PRICE, map_manager.get_gold()])
	reward_title.text = "商店 — 金幣: %d  (已購買 %s!)" % [map_manager.get_gold(), card.name_zh]
	
	# Refresh gold display
	if gold_label:
		gold_label.text = "💰 %d" % map_manager.get_gold()
	
	# Auto-close after purchase (one item per shop for MVP)
	await get_tree().create_timer(0.5).timeout
	_hide_shop()


func _hide_shop() -> void:
	## Hide shop overlay and advance to next node.
	reward_overlay.visible = false
	shop_active = false
	
	for child in reward_container.get_children():
		child.queue_free()
	_reward_cards.clear()
	
	map_manager.advance_to_next_node()


# ============================================================
#  EVENT SYSTEM
# ============================================================

func _resolve_event() -> void:
	## Pick a random event and apply its effect.
	var events := [
		"_event_borrow_arrows",
		"_event_three_visits",
		"_event_empty_city",
		"_event_wine_discussion",
		"_event_peach_garden_oath",
		"_event_wine_slash",
	]
	var event_name: String = events[randi() % events.size()]
	call(event_name)
	map_manager.advance_to_next_node()


func _event_borrow_arrows() -> void:
	## 草船借箭: 50% gain 2 cards, 50% lose 5 gold
	if randi() % 2 == 0:
		battle_manager.draw_cards(2)
		phase_label.text = "草船借箭: 獲得2張牌!"
	else:
		map_manager.run_data.spend_gold(5)
		phase_label.text = "草船借箭: 失去5金幣..."
	print("[Event] 草船借箭: %s" % phase_label.text)


func _event_three_visits() -> void:
	## 三顧茅廬: Gain a follower if you don't have one
	if battle_manager.follower and battle_manager.follower.is_alive():
		phase_label.text = "三顧茅廬: 已有隨從, 無事發生"
	else:
		var f = Follower.new()
		f.name_zh = "義勇兵"
		f.hp = 3
		f.max_hp = 3
		f.passive_desc = "每回合對隨機敵方造成1點傷害"
		f.can_block = false
		battle_manager.follower = f
		phase_label.text = "三顧茅廬: 獲得義勇兵!"
	print("[Event] 三顧茅廬")


func _event_empty_city() -> void:
	## 空城計: Heal 50% max HP
	var heal_amount: int = max(1, ceil(battle_manager.player_max_hp * 0.5))
	battle_manager.player_hp = min(battle_manager.player_hp + heal_amount, battle_manager.player_max_hp)
	phase_label.text = "空城計: 回復 %d 體力!" % heal_amount
	print("[Event] 空城計: healed %d" % heal_amount)


func _event_wine_discussion() -> void:
	## 煮酒論英雄: Random buff/debuff
	if randi() % 2 == 0:
		battle_manager.player_max_hp += 1
		battle_manager.player_hp += 1
		phase_label.text = "煮酒論英雄: 體力上限+1!"
	else:
		battle_manager.player_max_hp = max(1, battle_manager.player_max_hp - 1)
		phase_label.text = "煮酒論英雄: 體力上限-1..."
	print("[Event] 煮酒論英雄: max HP now %d" % battle_manager.player_max_hp)


func _event_peach_garden_oath() -> void:
	## 桃園結義: Full heal + gain 1 桃
	battle_manager.player_hp = battle_manager.player_max_hp
	var peach := _create_test_card("peach_heart_Q")
	if peach:
		battle_manager.deck.append(peach)
	phase_label.text = "桃園結義: 完全回復! +1桃"
	print("[Event] 桃園結義: full heal")


func _event_wine_slash() -> void:
	## 溫酒斬華雄: If have 酒 in hand, gain 10 gold. Otherwise gain 1 酒.
	var has_wine := false
	for card in battle_manager.hand:
		if card.sub_type == CardData.SubType.WINE:
			has_wine = true
			break
	if has_wine:
		map_manager.add_gold(10)
		phase_label.text = "溫酒斬華雄: 有酒! 獲得10金幣"
	else:
		var wine := _create_test_card("wine_spade_3")
		if wine:
			battle_manager.deck.append(wine)
		phase_label.text = "溫酒斬華雄: 獲得1張酒"
	print("[Event] 溫酒斬華雄")
