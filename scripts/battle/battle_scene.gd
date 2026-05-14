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
@onready var defeat_overlay: Control = $UI/DefeatOverlay
@onready var defeat_stats: Label = $UI/DefeatOverlay/DefeatStats
@onready var menu_btn: Button = $UI/DefeatOverlay/MenuBtn

var reward_active: bool = false  # Blocks battle interaction while choosing reward
var dodge_response_active: bool = false  # Blocks normal play during enemy attack response
var dodge_count_needed: int = 1
var dodge_count_played: int = 0


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
	
	# Semi-transparent background ensures RewardOverlay receives/block clicks properly
	# (fully transparent Controls may not participate in input routing)
	var reward_bg := ColorRect.new()
	reward_bg.color = Color(0.1, 0.1, 0.15, 0.85)
	reward_bg.anchors_preset = Control.PRESET_FULL_RECT
	reward_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_overlay.add_child(reward_bg)
	# Move background to the back so cards are on top
	reward_overlay.move_child(reward_bg, 0)

	# Set up roguelike progression
	battle_manager.map_manager = map_manager
	map_manager.node_changed.connect(_on_node_changed)
	map_manager.gold_changed.connect(_on_gold_changed)
	map_manager.run_ended.connect(_on_run_ended)
	menu_btn.pressed.connect(_on_return_to_menu)
	
	# Load test hero BEFORE starting run (run triggers first battle)
	_load_test_hero(PlayerData.chosen_hero_id)  # Hero chosen on select screen
	
	# Initialize run state (HP, deck) — persists across all battles in this run
	battle_manager.initialize_run()
	
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
		"huang_yueying":
			hero.name_zh = "黃月英"
			hero.max_hp = 3
			hero.faction = HeroData.Faction.SHU
			hero.archetype = HeroData.Archetype.CONTROL
			hero.skill_1_name_zh = "集智"
			hero.skill_1_desc_zh = "strategy → draw 1"
			hero.starting_deck = _create_starter_deck_balanced()
		"xiahou_yuan":
			hero.name_zh = "夏侯淵"
			hero.max_hp = 4
			hero.faction = HeroData.Faction.WEI
			hero.archetype = HeroData.Archetype.ATTACK
			hero.skill_1_name_zh = "疾行"
			hero.skill_1_desc_zh = "2 殺 per turn"
			hero.starting_deck = _create_starter_deck_attack()
		"lv_meng":
			hero.name_zh = "呂蒙"
			hero.max_hp = 4
			hero.faction = HeroData.Faction.WU
			hero.archetype = HeroData.Archetype.BALANCED
			hero.skill_1_name_zh = "克己"
			hero.skill_1_desc_zh = "skip discard, draw 1"
			hero.starting_deck = _create_starter_deck_balanced()
		"gan_ning":
			hero.name_zh = "甘寧"
			hero.max_hp = 4
			hero.faction = HeroData.Faction.WU
			hero.archetype = HeroData.Archetype.ATTACK
			hero.skill_1_name_zh = "奇襲"
			hero.skill_1_desc_zh = "discard equipment → 2 dmg"
			hero.starting_deck = _create_starter_deck_attack()
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
	## Balanced starter: uses CardLibrary for consistent card data.
	var deck: Array[CardData] = []
	var card_ids := [
		"slash_S_7", "slash_H_10", "slash_C_4", "slash_D_8",
		"dodge_H_2", "dodge_D_6", "dodge_D_11",
		"peach_H_4", "wine_S_3",
		"dismantle_S_3", "steal_S_4", "draw2_H_7",
		"duel_S_1", "barbarian_S_7", "peach_garden_H_1",
		"negate_C_12", "weapon_H_5",
	]
	for cid in card_ids:
		var card := CardLibrary.get_card(cid)
		if card:
			deck.append(card)
		else:
			# Fallback: create from old factory if library doesn't have the ID
			card = _create_test_card(cid)
			if card:
				deck.append(card)
	return deck


func _create_starter_deck_attack() -> Array[CardData]:
	## Attack-type starter: 5 殺, 2 閃, 1 桃, 1 酒, 1 決鬥 = 10 cards
	var deck: Array[CardData] = []
	var card_ids := [
		"slash_S_7", "slash_H_10", "slash_C_4", "slash_D_8", "slash_C_5",
		"dodge_H_2", "dodge_D_6",
		"peach_H_4", "wine_S_3",
		"duel_S_1",
	]
	for cid in card_ids:
		var card := CardLibrary.get_card(cid)
		if card:
			deck.append(card)
		else:
			card = _create_test_card(cid)
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
	# Equipment display
	var equip_text := ""
	for slot in ["weapon", "armor", "horse_plus", "horse_minus"]:
		if battle_manager.equipment_slots.has(slot):
			var card: CardData = battle_manager.equipment_slots[slot]
			var slot_icon := {"weapon": "⚔️", "armor": "🛡️", "horse_plus": "🐴+", "horse_minus": "🐴-"}
			equip_text += " %s%s" % [slot_icon.get(slot, ""), card.name_zh]
	if equip_text != "":
		energy_label.text += equip_text
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


var _follower_label: Label = null
var _follower_hp_label: Label = null
var _follower_desc_label: Label = null

func _refresh_follower() -> void:
	var f := battle_manager.follower
	if f and f.is_alive():
		follower_display.visible = true
		# Lazy-init follower UI labels inside the FollowerDisplay Control
		if _follower_label == null:
			_follower_label = Label.new()
			_follower_label.add_theme_font_size_override("font_size", 14)
			_follower_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			follower_display.add_child(_follower_label)
			_follower_hp_label = Label.new()
			_follower_hp_label.add_theme_font_size_override("font_size", 12)
			_follower_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			follower_display.add_child(_follower_hp_label)
			_follower_desc_label = Label.new()
			_follower_desc_label.add_theme_font_size_override("font_size", 10)
			_follower_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_follower_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			follower_display.add_child(_follower_desc_label)
		_follower_label.text = "🤝 %s" % f.name_zh
		_follower_hp_label.text = "HP: %d/%d" % [f.hp, f.max_hp]
		var block_str := " 🔰護衛" if f.can_block else ""
		_follower_hp_label.text += block_str
		_follower_desc_label.text = f.passive_desc
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
	## Clicking the same selected card again cancels the selection.

	# During dodge response: only 閃 is playable
	if dodge_response_active:
		if card.sub_type == CardData.SubType.DODGE:
			dodge_count_played += 1
			battle_manager.use_dodge(card)
			_refresh_hand()
			if dodge_count_played >= dodge_count_needed:
				battle_manager.resolve_dodge()
			else:
				phase_label.text = "還需要 %d 張閃..." % (dodge_count_needed - dodge_count_played)
		return

	if reward_active or shop_active or battle_manager.current_phase != BattleManager.Phase.PLAY:
		return

	# If clicking the same card that's already selected — cancel selection
	if selected_card == card:
		print("[UI] Canceling card selection")
		selected_card = null
		for child in hand_container.get_children():
			if child is CardNode:
				child.highlight(false)
		return

	# If clicking a different card while one is selected — cancel previous selection first
	if selected_card != null:
		print("[UI] Previous selection canceled — choosing new card")
		selected_card = null
		for child in hand_container.get_children():
			if child is CardNode:
				child.highlight(false)

	var needs_target := _card_needs_target(card)

	if needs_target:
		# Block selection if 殺 limit reached (unless 張飛 咆哮 or 諸葛連弩)
		if card.sub_type == CardData.SubType.SLASH and battle_manager.player_hero.id != "zhang_fei" and not battle_manager._has_crossbow() and battle_manager.energy_used >= battle_manager.energy:
			print("[Blocked] 殺 limit reached (%d/%d)" % [battle_manager.energy_used, battle_manager.energy])
			return
		selected_card = card
		print("[UI] Selected card for targeting: ", card.name_zh)
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
		# Record run as victory for meta-progression
		MetaData.record_run(true, map_manager.run_data.current_zone + 1)
		MetaData.save()
		print("Run recorded: %d wins / %d runs, %d spirit points" % [MetaData.total_wins, MetaData.total_runs, MetaData.spirit_points])
		_show_card_rewards()
	else:
		print("DEFEAT... Run over.")
		# Record run result for meta-progression
		MetaData.record_run(false, map_manager.run_data.current_zone + 1)
		var zone_name: String = map_manager.get_current_zone().name_zh if map_manager.get_current_zone() else "?"
		defeat_stats.text = "%s\n獲得 %d 靈" % [zone_name, MetaData.spirit_points]
		defeat_overlay.visible = true
		end_turn_btn.visible = false
		skill_btn.visible = false


func _on_return_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


func _on_run_ended(victory: bool) -> void:
	## Handle end of run (all zones cleared or final boss defeated).
	# Victory: show congratulations, record run
	if victory:
		print("RUN COMPLETE! All zones cleared!")
		MetaData.record_run(true, map_manager.run_data.current_zone + 1)
		MetaData.save()
		# Show victory overlay
		reward_overlay.visible = true
		reward_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		reward_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reward_title.text = "🎉 通關! 金幣: %d | 靈: %d" % [map_manager.get_gold(), MetaData.spirit_points]
		# Clear any children in reward container
		for child in reward_container.get_children():
			reward_container.remove_child(child)
			child.queue_free()
		end_turn_btn.visible = false
		skill_btn.visible = false


func _on_awaiting_dodge(enemy_name: String, damage: int) -> void:
	## Enemy is attacking — enable dodge response mode.
	dodge_response_active = true
	dodge_count_played = 0
	dodge_count_needed = 2 if battle_manager._current_attacker_requires_double() else 1
	phase_label.text = "%s 攻擊! 傷害 %d — 出閃? (%d/%d)" % [enemy_name, damage, dodge_count_played, dodge_count_needed]
	end_turn_btn.text = "承受傷害"
	end_turn_btn.visible = true
	_refresh_hand()  # Refresh so player can click 閃 cards


func _on_dodge_resolved() -> void:
	## Player responded to enemy attack — reset mode.
	dodge_response_active = false
	end_turn_btn.text = "結束回合"
	# Don't force visible=false — let _on_phase_changed decide based on current phase
	# Instead, sync with current phase immediately
	if battle_manager.current_phase == BattleManager.Phase.PLAY:
		end_turn_btn.visible = true
	else:
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
			_show_campfire()
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
			skill_btn.text = _get_skill_label(battle_manager.player_hero.id)
	else:
		skill_btn.visible = false


func _get_skill_label(hero_id: String) -> String:
	## Return the Chinese skill name for the hero's active skill button.
	match hero_id:
		"sun_quan": return "制衡"
		"huang_gai": return "苦肉"
		"liu_bei": return "仁德"
		"zhou_yu": return "反間"
		"lv_meng": return "克己"
		"gan_ning": return "奇襲"
		"xu_chu": return "裸衣"
		"zhang_jiao": return "雷擊"
		"zhuge_liang": return "觀星"
		"diao_chan": return "離間"
		_: return "技能"


func _on_skill_pressed() -> void:
	var skill_name := battle_manager._get_active_skill_name()
	if skill_name != "":
		battle_manager._activate_skill(skill_name)
	_refresh_ui()


var map_screen: Control = null

func _show_map_screen() -> void:
	## Show map screen overlay, wait for player to press Continue.
	map_screen = load("res://scenes/map/map_screen.tscn").instantiate()
	add_child(map_screen)
	# Wait one frame for @onready vars to initialize
	await get_tree().process_frame
	map_screen.show_map(map_manager)
	map_screen.continue_pressed.connect(_on_map_continue)
	# Hide battle controls
	end_turn_btn.visible = false
	skill_btn.visible = false

func _on_map_continue() -> void:
	## Player pressed Continue on map screen — advance to next node.
	if map_screen:
		map_screen.queue_free()
		map_screen = null
	map_manager.advance_to_next_node()


# ============================================================
#  CARD REWARD SYSTEM
# ============================================================

var _reward_cards: Array = []  # Current reward card choices





func _show_card_rewards() -> void:
	## Display 3 card choices after battle victory.

	# RE-ENTRANCY GUARD
	if reward_active:
		return

	# ========================================
	# CRITICAL: RESET mouse_filter FIRST
	# PASS (1) = default for HBoxContainer = SILENTLY DROPS CLICKS
	# ========================================
	reward_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	reward_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	reward_active = true
	_reward_cards = _generate_reward_cards(3)

	# Clear previous reward cards — remove_child FIRST, then queue_free
	for child in reward_container.get_children():
		reward_container.remove_child(child)
		child.queue_free()

	# Show the overlay
	reward_overlay.visible = true
	reward_title.text = "選擇獎勵卡牌"

	# Create CardNode for each reward — wrapped in VBoxContainer (same pattern as shop)
	for card in _reward_cards:
		var vbox := VBoxContainer.new()
		# CRITICAL: VBoxContainer DEFAULT = PASS (1), which SILENTLY DROPS click events
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var card_node = CardNode.new()
		card_node.setup(card)
		card_node.card_clicked.connect(_on_reward_card_selected)
		vbox.add_child(card_node)
		reward_container.add_child(vbox)

# Hide battle UI (and EnemyArea — overlaps overlay card positions)
	$EnemyArea.visible = false
	end_turn_btn.visible = false
	skill_btn.visible = false


func _on_reward_card_selected(card: CardData) -> void:
	## Player clicked a reward card — add it to the deck and advance.
	battle_manager.deck.append(card)
	_hide_card_rewards()


func _hide_card_rewards() -> void:
	## Hide reward overlay and advance to next map node.
	reward_overlay.visible = false
	reward_active = false

	# Restore EnemyArea visibility
	$EnemyArea.visible = true

	# Clear reward cards — remove_child FIRST, then queue_free
	for child in reward_container.get_children():
		reward_container.remove_child(child)
		child.queue_free()
	_reward_cards.clear()

	# Advance to next map node
	map_manager.advance_to_next_node()


func _generate_reward_cards(count: int) -> Array:
	## Generate random cards for reward selection using the full 108-card library.
	return CardLibrary.get_random_rewards(count)


# ============================================================
#  CAMPFIRE SYSTEM
# ============================================================

var campfire_active: bool = false

func _show_campfire() -> void:
	## Show campfire choices: Rest (heal 30% HP) or Upgrade (pick a card to upgrade).
	if campfire_active:
		return

	# Mouse filter fix: same as shop
	reward_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	reward_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	campfire_active = true

	# Clear previous overlay contents
	for child in reward_container.get_children():
		reward_container.remove_child(child)
		child.queue_free()

	reward_overlay.visible = true
	reward_title.text = "🔥 營火 — 休息或升級?"

	# Hide battle UI
	$EnemyArea.visible = false
	end_turn_btn.visible = false
	skill_btn.visible = false

	# -- Rest button --
	var rest_btn := Button.new()
	rest_btn.custom_minimum_size = Vector2(180, 120)
	var heal_preview: int = max(1, ceil(battle_manager.player_max_hp * 0.3))
	rest_btn.text = "休息\n回復 %d HP\n(%d/%d → %d/%d)" % [
		heal_preview,
		battle_manager.player_hp, battle_manager.player_max_hp,
		min(battle_manager.player_hp + heal_preview, battle_manager.player_max_hp),
		battle_manager.player_max_hp
	]
	rest_btn.tooltip_text = "回復30%最大體力值"
	# Warm orange style
	var rest_style := StyleBoxFlat.new()
	rest_style.bg_color = Color(0.4, 0.25, 0.1, 0.9)
	rest_style.border_color = Color(0.9, 0.6, 0.2)
	rest_style.border_width_top = 3
	rest_style.border_width_bottom = 3
	rest_style.border_width_left = 3
	rest_style.border_width_right = 3
	rest_style.corner_radius_top_left = 10
	rest_style.corner_radius_top_right = 10
	rest_style.corner_radius_bottom_left = 10
	rest_style.corner_radius_bottom_right = 10
	rest_btn.add_theme_stylebox_override("normal", rest_style)
	var rest_hover := StyleBoxFlat.new()
	rest_hover.bg_color = Color(0.5, 0.35, 0.15, 0.95)
	rest_hover.border_color = Color(1.0, 0.7, 0.3)
	rest_hover.border_width_top = 3
	rest_hover.border_width_bottom = 3
	rest_hover.border_width_left = 3
	rest_hover.border_width_right = 3
	rest_hover.corner_radius_top_left = 10
	rest_hover.corner_radius_top_right = 10
	rest_hover.corner_radius_bottom_left = 10
	rest_hover.corner_radius_bottom_right = 10
	rest_btn.add_theme_stylebox_override("hover", rest_hover)
	rest_btn.add_theme_font_size_override("font_size", 14)
	rest_btn.pressed.connect(_on_campfire_rest)
	reward_container.add_child(rest_btn)

	# -- Upgrade button --
	var upgrade_btn := Button.new()
	upgrade_btn.custom_minimum_size = Vector2(180, 120)
	upgrade_btn.text = "升級\n選擇一張牌升級"
	upgrade_btn.tooltip_text = "選擇手牌中的一張牌進行升級"
	var up_style := StyleBoxFlat.new()
	up_style.bg_color = Color(0.1, 0.2, 0.4, 0.9)
	up_style.border_color = Color(0.3, 0.6, 0.9)
	up_style.border_width_top = 3
	up_style.border_width_bottom = 3
	up_style.border_width_left = 3
	up_style.border_width_right = 3
	up_style.corner_radius_top_left = 10
	up_style.corner_radius_top_right = 10
	up_style.corner_radius_bottom_left = 10
	up_style.corner_radius_bottom_right = 10
	upgrade_btn.add_theme_stylebox_override("normal", up_style)
	var up_hover := StyleBoxFlat.new()
	up_hover.bg_color = Color(0.15, 0.3, 0.5, 0.95)
	up_hover.border_color = Color(0.5, 0.8, 1.0)
	up_hover.border_width_top = 3
	up_hover.border_width_bottom = 3
	up_hover.border_width_left = 3
	up_hover.border_width_right = 3
	up_hover.corner_radius_top_left = 10
	up_hover.corner_radius_top_right = 10
	up_hover.corner_radius_bottom_left = 10
	up_hover.corner_radius_bottom_right = 10
	upgrade_btn.add_theme_stylebox_override("hover", up_hover)
	upgrade_btn.add_theme_font_size_override("font_size", 14)
	upgrade_btn.pressed.connect(_on_campfire_upgrade)
	reward_container.add_child(upgrade_btn)


func _on_campfire_rest() -> void:
	## Player chose Rest at campfire — heal 30% of max HP.
	var heal_amount: int = max(1, ceil(battle_manager.player_max_hp * 0.3))
	var old_hp: int = battle_manager.player_hp
	battle_manager.player_hp = min(battle_manager.player_hp + heal_amount, battle_manager.player_max_hp)
	var actual_heal: int = battle_manager.player_hp - old_hp
	print("[Campfire] Rest: healed %d HP (now %d/%d)" % [actual_heal, battle_manager.player_hp, battle_manager.player_max_hp])

	_hide_campfire()
	map_manager.advance_to_next_node()


func _on_campfire_upgrade() -> void:
	## Player chose Upgrade at campfire — show all deck cards for selection.
	# Clear the rest/upgrade buttons
	for child in reward_container.get_children():
		reward_container.remove_child(child)
		child.queue_free()

	reward_title.text = "🔥 升級 — 選擇一張牌"

	if battle_manager.deck.is_empty():
		reward_title.text = "🔥 牌組為空，無法升級"
		await get_tree().create_timer(1.0).timeout
		_hide_campfire()
		map_manager.advance_to_next_node()
		return

	# Show each deck card as a clickable button
	for i: int in range(battle_manager.deck.size()):
		var card: CardData = battle_manager.deck[i]
		var already_upgraded: bool = card.name_zh.ends_with("+")

		var card_btn := Button.new()
		card_btn.custom_minimum_size = Vector2(120, 80)

		if already_upgraded:
			card_btn.text = "%s\n(已升級)" % card.name_zh
			card_btn.disabled = true
			var dis_style := StyleBoxFlat.new()
			dis_style.bg_color = Color(0.15, 0.15, 0.15, 0.6)
			dis_style.border_color = Color(0.3, 0.3, 0.3)
			dis_style.border_width_top = 2
			dis_style.border_width_bottom = 2
			dis_style.border_width_left = 2
			dis_style.border_width_right = 2
			dis_style.corner_radius_top_left = 8
			dis_style.corner_radius_top_right = 8
			dis_style.corner_radius_bottom_left = 8
			dis_style.corner_radius_bottom_right = 8
			card_btn.add_theme_stylebox_override("normal", dis_style)
		else:
			# Build a preview of what the upgrade does
			var up_card: CardData = battle_manager.get_upgraded_card(card)
			var preview: String = card.name_zh
			if up_card and up_card != card:
				if up_card.damage > card.damage:
					preview += "\n攻擊 %d→%d" % [card.damage, up_card.damage]
				if up_card.block > card.block:
					preview += "\n防禦 %d→%d" % [card.block, up_card.block]
				if up_card.heal > card.heal:
					preview += "\n回復 %d→%d" % [card.heal, up_card.heal]
				if up_card.draw_count > card.draw_count:
					preview += "\n摸牌 %d→%d" % [card.draw_count, up_card.draw_count]
			card_btn.text = "升級\n%s" % preview

			var card_style := StyleBoxFlat.new()
			card_style.bg_color = Color(0.12, 0.15, 0.25, 0.9)
			card_style.border_color = Color(0.4, 0.6, 0.9)
			card_style.border_width_top = 2
			card_style.border_width_bottom = 2
			card_style.border_width_left = 2
			card_style.border_width_right = 2
			card_style.corner_radius_top_left = 8
			card_style.corner_radius_top_right = 8
			card_style.corner_radius_bottom_left = 8
			card_style.corner_radius_bottom_right = 8
			card_btn.add_theme_stylebox_override("normal", card_style)
			var card_hover := StyleBoxFlat.new()
			card_hover.bg_color = Color(0.2, 0.3, 0.5, 0.95)
			card_hover.border_color = Color(0.6, 0.8, 1.0)
			card_hover.border_width_top = 2
			card_hover.border_width_bottom = 2
			card_hover.border_width_left = 2
			card_hover.border_width_right = 2
			card_hover.corner_radius_top_left = 8
			card_hover.corner_radius_top_right = 8
			card_hover.corner_radius_bottom_left = 8
			card_hover.corner_radius_bottom_right = 8
			card_btn.add_theme_stylebox_override("hover", card_hover)
			card_btn.add_theme_font_size_override("font_size", 12)
			card_btn.pressed.connect(_on_campfire_card_selected.bind(i))

		reward_container.add_child(card_btn)

	# Add a "Skip" button at the end
	var skip_btn := Button.new()
	skip_btn.custom_minimum_size = Vector2(120, 80)
	skip_btn.text = "跳過"
	skip_btn.tooltip_text = "不升級，繼續前進"
	var skip_style := StyleBoxFlat.new()
	skip_style.bg_color = Color(0.2, 0.1, 0.1, 0.8)
	skip_style.border_color = Color(0.5, 0.3, 0.3)
	skip_style.border_width_top = 2
	skip_style.border_width_bottom = 2
	skip_style.border_width_left = 2
	skip_style.border_width_right = 2
	skip_style.corner_radius_top_left = 8
	skip_style.corner_radius_top_right = 8
	skip_style.corner_radius_bottom_left = 8
	skip_style.corner_radius_bottom_right = 8
	skip_btn.add_theme_stylebox_override("normal", skip_style)
	skip_btn.pressed.connect(_on_campfire_skip)
	reward_container.add_child(skip_btn)


func _on_campfire_card_selected(index: int) -> void:
	## Player selected a card to upgrade at campfire.
	var success: bool = battle_manager.upgrade_specific_card(index)
	if success:
		var card: CardData = battle_manager.deck[index]
		phase_label.text = "🔥 升級: %s" % card.name_zh
	else:
		phase_label.text = "🔥 無法升級此牌"
	_refresh_ui()

	_hide_campfire()
	map_manager.advance_to_next_node()


func _on_campfire_skip() -> void:
	## Player skipped the upgrade.
	print("[Campfire] Skipped upgrade")
	_hide_campfire()
	map_manager.advance_to_next_node()


func _hide_campfire() -> void:
	## Hide campfire overlay and restore battle UI.
	reward_overlay.visible = false
	campfire_active = false

	$EnemyArea.visible = true

	# Clear overlay children
	for child in reward_container.get_children():
		reward_container.remove_child(child)
		child.queue_free()


# ============================================================
#  SHOP SYSTEM
# ============================================================

const SHOP_CARD_PRICE: int = 5
var shop_active: bool = false
var _shop_follower: Follower = null  # Follower offered in shop (null = follower already owned or not offered)

func _show_shop() -> void:
	## Display shop: 2 cards for purchase + 1 follower (if player doesn't already have one).

	# RE-ENTRANCY GUARD
	if shop_active:
		return

	# ========================================
	# CRITICAL: RESET mouse_filter FIRST, BEFORE ANY OTHER OPERATIONS
	# ========================================
	# The value 1 (PASS) is EXTREMELY DANGEROUS in Godot 4:
	# - MouseMotion events ARE received (hover works)
	# - MouseButton events are SILENTLY DROPPED (clicks don't work)
	reward_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	reward_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	shop_active = true
	_reward_cards = _generate_reward_cards(2)

	# Offer a random follower type if player doesn't already have one
	_shop_follower = null
	if battle_manager.follower == null or not battle_manager.follower.is_alive():
		var follower_types: Array[Follower.FollowerType] = [
			Follower.FollowerType.VOLUNTEER,
			Follower.FollowerType.GUARDIAN,
			Follower.FollowerType.SCOUT,
			Follower.FollowerType.MEDIC,
		]
		# Strategist is rarer — 30% chance to include it in the pool
		if randi() % 100 < 30:
			follower_types.append(Follower.FollowerType.STRATEGIST)
		_shop_follower = Follower.create(follower_types[randi() % follower_types.size()])

	# Clear previous shop items
	for child in reward_container.get_children():
		reward_container.remove_child(child)
		child.queue_free()

	# Show overlay with shop styling
	var gold: int = map_manager.get_gold()
	reward_overlay.visible = true
	reward_title.text = "商店 — 金幣: %d" % gold

	# Create card nodes with price labels
	for card in _reward_cards:
		var vbox := VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	# Add follower offer panel
	if _shop_follower != null:
		var follower_cost := Follower.get_cost(_shop_follower.follower_type)
		# Use a Button as root so clicks are reliable (Panel+Button overlay fails in Godot 4)
		var fbtn := Button.new()
		fbtn.custom_minimum_size = Vector2(130, 150)
		fbtn.mouse_filter = Control.MOUSE_FILTER_STOP
		fbtn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		# Green-tinted style
		var normal_style := StyleBoxFlat.new()
		normal_style.bg_color = Color(0.15, 0.25, 0.15, 0.9)
		normal_style.border_color = Color(0.4, 0.8, 0.4)
		normal_style.border_width_top = 2
		normal_style.border_width_bottom = 2
		normal_style.border_width_left = 2
		normal_style.border_width_right = 2
		normal_style.corner_radius_top_left = 8
		normal_style.corner_radius_top_right = 8
		normal_style.corner_radius_bottom_left = 8
		normal_style.corner_radius_bottom_right = 8
		fbtn.add_theme_stylebox_override("normal", normal_style)
		var hover_style := StyleBoxFlat.new()
		hover_style.bg_color = Color(0.2, 0.35, 0.2, 0.95)
		hover_style.border_color = Color(0.5, 0.9, 0.5)
		hover_style.border_width_top = 2
		hover_style.border_width_bottom = 2
		hover_style.border_width_left = 2
		hover_style.border_width_right = 2
		hover_style.corner_radius_top_left = 8
		hover_style.corner_radius_top_right = 8
		hover_style.corner_radius_bottom_left = 8
		hover_style.corner_radius_bottom_right = 8
		fbtn.add_theme_stylebox_override("hover", hover_style)
		# Connect click BEFORE adding children (bind follower type)
		fbtn.pressed.connect(_on_shop_follower_bought.bind(_shop_follower.follower_type))

		var fvbox := VBoxContainer.new()
		# CRITICAL: VBoxContainer default = PASS (1), which SILENTLY DROPS click events
		fvbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fbtn.add_child(fvbox)

		var name_lbl := Label.new()
		name_lbl.text = "🤝 %s" % _shop_follower.name_zh
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 14)
		fvbox.add_child(name_lbl)

		var hp_lbl := Label.new()
		hp_lbl.text = "HP: %d  ATK: %d" % [_shop_follower.max_hp, _shop_follower.attack_power]
		hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_lbl.add_theme_font_size_override("font_size", 12)
		fvbox.add_child(hp_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = _shop_follower.passive_desc
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 11)
		fvbox.add_child(desc_lbl)

		var cost_lbl := Label.new()
		cost_lbl.text = "%d 金" % follower_cost
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_font_size_override("font_size", 16)
		fvbox.add_child(cost_lbl)

		reward_container.add_child(fbtn)

	# Hide battle UI (and EnemyArea — same overlap issue as reward cards)
	$EnemyArea.visible = false
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


func _on_shop_follower_bought(follower_type: int) -> void:
	## Player bought a follower from the shop.
	if _shop_follower == null:
		return
	var cost := Follower.get_cost(follower_type as Follower.FollowerType)
	if not map_manager.run_data.spend_gold(cost):
		print("[Shop] Not enough gold for follower!")
		return
	
	battle_manager.follower = Follower.create(follower_type as Follower.FollowerType)
	print("[Shop] Recruited %s for %d gold (remaining: %d)" % [battle_manager.follower.name_zh, cost, map_manager.get_gold()])
	reward_title.text = "商店 — 金幣: %d  (招募 %s!)" % [map_manager.get_gold(), battle_manager.follower.name_zh]
	_shop_follower = null
	
	# Refresh gold display
	if gold_label:
		gold_label.text = "💰 %d" % map_manager.get_gold()
	
	# Auto-close after purchase
	await get_tree().create_timer(0.5).timeout
	_hide_shop()


func _hide_shop() -> void:
	## Hide shop overlay and advance to next node.
	reward_overlay.visible = false
	shop_active = false
	_shop_follower = null

	# Restore EnemyArea visibility
	$EnemyArea.visible = true

	# Clear nodes - use remove_child FIRST, then queue_free
	for child in reward_container.get_children():
		reward_container.remove_child(child)
		child.queue_free()
	_reward_cards.clear()

	# Advance to next node
	map_manager.advance_to_next_node()


# ============================================================
#  EVENT SYSTEM
# ============================================================

func _resolve_event() -> void:
	## Pick a random event and apply its effect.
	## Interactive events (with choices) call _show_event_choices and return early —
	## advance_to_next_node is called from the choice callback instead.
	var events := [
		"_event_borrow_arrows",
		"_event_three_visits",
		"_event_empty_city",
		"_event_wine_discussion",
		"_event_peach_garden_oath",
		"_event_wine_slash",
		"_event_recruit_ally",
	]
	var event_name: String = events[randi() % events.size()]
	call(event_name)


func _event_borrow_arrows() -> void:
	## 草船借箭: 50% gain 2 cards, 50% lose 5 gold
	if randi() % 2 == 0:
		battle_manager.draw_cards(2)
		phase_label.text = "草船借箭: 獲得2張牌!"
	else:
		map_manager.run_data.spend_gold(5)
		phase_label.text = "草船借箭: 失去5金幣..."
	print("[Event] 草船借箭: %s" % phase_label.text)
	map_manager.advance_to_next_node()


func _event_three_visits() -> void:
	## 三顧茅廬: Gain a random follower if you don't have one
	if battle_manager.follower and battle_manager.follower.is_alive():
		phase_label.text = "三顧茅廬: 已有隨從, 無事發生"
	else:
		# Pick a random non-strategist follower (strategist is shop-only)
		var types: Array[Follower.FollowerType] = [Follower.FollowerType.VOLUNTEER, Follower.FollowerType.GUARDIAN, Follower.FollowerType.SCOUT, Follower.FollowerType.MEDIC]
		battle_manager.follower = Follower.create(types[randi() % types.size()])
		phase_label.text = "三顧茅廬: 獲得%s!" % battle_manager.follower.name_zh
	print("[Event] 三顧茅廬")
	map_manager.advance_to_next_node()


func _event_empty_city() -> void:
	## 空城計: Heal 50% max HP
	var heal_amount: int = max(1, ceil(battle_manager.player_max_hp * 0.5))
	battle_manager.player_hp = min(battle_manager.player_hp + heal_amount, battle_manager.player_max_hp)
	phase_label.text = "空城計: 回復 %d 體力!" % heal_amount
	print("[Event] 空城計: healed %d" % heal_amount)
	map_manager.advance_to_next_node()


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
	map_manager.advance_to_next_node()


func _event_peach_garden_oath() -> void:
	## 桃園結義: Full heal + gain 1 桃
	battle_manager.player_hp = battle_manager.player_max_hp
	var peach := _create_test_card("peach_heart_Q")
	if peach:
		battle_manager.deck.append(peach)
	phase_label.text = "桃園結義: 完全回復! +1桃"
	print("[Event] 桃園結義: full heal")
	map_manager.advance_to_next_node()


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
	map_manager.advance_to_next_node()


# -- Interactive event: recruit ally with choice --

var _event_choices_made: int = 0

func _event_recruit_ally() -> void:
	## 招募義士: Interactive event — choose between 2 follower types.
	## If player already has a follower, offer gold instead.
	if battle_manager.follower and battle_manager.follower.is_alive():
		# Already have a follower — give gold instead
		map_manager.add_gold(15)
		phase_label.text = "招募義士: 已有隨從, 獲得15金幣"
		print("[Event] 招募義士: already have follower, +15 gold")
		map_manager.advance_to_next_node()
		return

	# Pick 2 random follower types to offer as choices
	var all_types: Array[Follower.FollowerType] = [
		Follower.FollowerType.VOLUNTEER,
		Follower.FollowerType.GUARDIAN,
		Follower.FollowerType.SCOUT,
		Follower.FollowerType.MEDIC,
	]
	all_types.shuffle()
	var choice_a_type: Follower.FollowerType = all_types[0]
	var choice_b_type: Follower.FollowerType = all_types[1]
	_event_choices_made = 0

	# Use reward overlay to show event choices
	reward_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	reward_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_overlay.visible = true
	reward_title.text = "招募義士 — 選擇一位隨從"

	# Clear container
	for child in reward_container.get_children():
		reward_container.remove_child(child)
		child.queue_free()

	# Create choice panels for each follower type
	for f_type in [choice_a_type, choice_b_type]:
		var f := Follower.create(f_type)
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(160, 160)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.2, 0.3, 0.9)
		style.border_color = Color(0.5, 0.7, 1.0)
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_width_left = 2
		style.border_width_right = 2
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		panel.add_theme_stylebox_override("panel", style)

		var fvbox := VBoxContainer.new()
		fvbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(fvbox)

		var name_lbl := Label.new()
		name_lbl.text = "🤝 %s" % f.name_zh
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 15)
		fvbox.add_child(name_lbl)

		var hp_lbl := Label.new()
		hp_lbl.text = "HP: %d  ATK: %d" % [f.max_hp, f.attack_power]
		hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_lbl.add_theme_font_size_override("font_size", 12)
		fvbox.add_child(hp_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = f.passive_desc
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 11)
		fvbox.add_child(desc_lbl)

		# Clickable button overlay
		var btn := Button.new()
		btn.text = "選擇"
		btn.flat = false
		btn.anchors_preset = Control.PRESET_BOTTOM_WIDE
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(_on_event_ally_chosen.bind(f_type))
		fvbox.add_child(btn)

		reward_container.add_child(panel)

	# Hide battle UI during event choice
	$EnemyArea.visible = false
	end_turn_btn.visible = false
	skill_btn.visible = false


func _on_event_ally_chosen(follower_type: int) -> void:
	## Player chose a follower from the recruit event.
	var f := Follower.create(follower_type as Follower.FollowerType)
	battle_manager.follower = f
	phase_label.text = "招募義士: 獲得%s!" % f.name_zh
	print("[Event] 招募義士: recruited %s" % f.name_zh)

	# Hide event overlay
	reward_overlay.visible = false
	$EnemyArea.visible = true
	end_turn_btn.visible = true
	_refresh_ui()

	# Clear reward container
	for child in reward_container.get_children():
		reward_container.remove_child(child)
		child.queue_free()

	map_manager.advance_to_next_node()
