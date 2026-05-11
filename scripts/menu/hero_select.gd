extends Control
## Hero Select Screen — pick a hero before starting a run.
## Shows faction tabs (Wei/Shu/Wu/Qun) with hero cards.

signal hero_selected(hero_id: String)

const HERO_DATA := {
	"liu_bei": {"name": "劉備", "faction": "SHU", "hp": 4, "skill": "仁德: give cards to heal", "archetype": "SUPPORT"},
	"guan_yu": {"name": "關羽", "faction": "SHU", "hp": 4, "skill": "武聖: red cards → 殺", "archetype": "ATTACK"},
	"zhang_fei": {"name": "張飛", "faction": "SHU", "hp": 4, "skill": "咆哮: unlimited 殺", "archetype": "ATTACK"},
	"zhuge_liang": {"name": "諸葛亮", "faction": "SHU", "hp": 3, "skill": "觀星: see top 5, reorder", "archetype": "CONTROL"},
	"zhao_yun": {"name": "趙雲", "faction": "SHU", "hp": 4, "skill": "龍膽: 殺↔閃", "archetype": "BALANCED"},
	"cao_cao": {"name": "曹操", "faction": "WEI", "hp": 4, "skill": "奸雄: take damage → gain card", "archetype": "CONTROL"},
	"sim_yi": {"name": "司馬懿", "faction": "WEI", "hp": 3, "skill": "反饋: take damage → steal enemy card", "archetype": "CONTROL"},
	"xiahou_dun": {"name": "夏侯惇", "faction": "WEI", "hp": 4, "skill": "剛烈: take damage → deal 1 back", "archetype": "ATTACK"},
	"zhen_ji": {"name": "甄姬", "faction": "WEI", "hp": 3, "skill": "傾國: black cards → 閃", "archetype": "DEFENSE"},
	"guo_jia": {"name": "郭嘉", "faction": "WEI", "hp": 3, "skill": "天妒: draw 2 when damaged", "archetype": "SUPPORT"},
	"sun_quan": {"name": "孫權", "faction": "WU", "hp": 4, "skill": "制衡: discard N, draw N", "archetype": "BALANCED"},
	"zhou_yu": {"name": "周瑜", "faction": "WU", "hp": 3, "skill": "反間: guess suit or take 1 dmg", "archetype": "CONTROL"},
	"lu_xun": {"name": "陸遜", "faction": "WU", "hp": 3, "skill": "連營: last card → draw 2", "archetype": "CONTROL"},
	"huang_gai": {"name": "黃蓋", "faction": "WU", "hp": 4, "skill": "苦肉: lose 1 HP → draw 2", "archetype": "ATTACK"},
	"da_qiao": {"name": "大喬", "faction": "WU", "hp": 3, "skill": "國色: diamond cards → 樂", "archetype": "CONTROL"},
	"lv_bu": {"name": "呂布", "faction": "QUN", "hp": 4, "skill": "無雙: 殺+決鬥 dmg+1", "archetype": "ATTACK"},
	"diao_chan": {"name": "貂蟬", "faction": "QUN", "hp": 3, "skill": "離間: force 2 enemies to duel", "archetype": "CONTROL"},
	"huang_zhong": {"name": "黃忠", "faction": "SHU", "hp": 4, "skill": "烈弓: hand≥HP → 殺 dmg+1", "archetype": "ATTACK"},
	"ma_chao": {"name": "馬超", "faction": "SHU", "hp": 4, "skill": "鐵騎: red judgment → dmg+1", "archetype": "ATTACK"},
	"huang_yueying": {"name": "黃月英", "faction": "SHU", "hp": 3, "skill": "集智: play strategy → draw 1", "archetype": "CONTROL"},
	"xiahou_yuan": {"name": "夏侯淵", "faction": "WEI", "hp": 4, "skill": "疾行: 2 殺/turn", "archetype": "ATTACK"},
	"xu_chu": {"name": "許褚", "faction": "WEI", "hp": 4, "skill": "裸衣: 殺 dmg+1, self-dmg 1", "archetype": "ATTACK"},
	"lv_meng": {"name": "呂蒙", "faction": "WU", "hp": 4, "skill": "克己: skip discard → draw 1", "archetype": "CONTROL"},
	"gan_ning": {"name": "甘寧", "faction": "WU", "hp": 4, "skill": "奇襲: discard equip → deal 2 dmg", "archetype": "ATTACK"},
	"xiao_qiao": {"name": "小喬", "faction": "WU", "hp": 3, "skill": "天香: red suit → negate dmg", "archetype": "SUPPORT"},
	"zhang_jiao": {"name": "張角", "faction": "QUN", "hp": 3, "skill": "雷擊: spade judgment → 2 lightning dmg", "archetype": "CONTROL"},
}

var current_faction: String = "ALL"
var hero_buttons: Array[Button] = []

@onready var title_label: Label = $TitleLabel
@onready var faction_container: HBoxContainer = $FactionBar
@onready var hero_grid: GridContainer = $HeroGrid
@onready var info_panel: VBoxContainer = $InfoPanel
@onready var confirm_btn: Button = $ConfirmBtn

var selected_hero_id: String = ""

func _ready() -> void:
	_build_faction_tabs()
	_show_heroes("ALL")
	confirm_btn.disabled = true
	confirm_btn.pressed.connect(_on_confirm)

func _build_faction_tabs() -> void:
	var factions := ["ALL", "SHU", "WEI", "WU", "QUN"]
	var colors := {
		"ALL": Color.WHITE,
		"SHU": Color.GREEN,
		"WEI": Color.BLUE,
		"WU": Color.RED,
		"QUN": Color.YELLOW,
	}
	for faction in factions:
		var btn := Button.new()
		btn.text = faction
		btn.add_theme_color_override("font_color", colors[faction])
		btn.pressed.connect(_on_faction_tab.bind(faction))
		faction_container.add_child(btn)

func _on_faction_tab(faction: String) -> void:
	current_faction = faction
	_show_heroes(faction)

func _show_heroes(faction: String) -> void:
	# Clear existing
	for child in hero_grid.get_children():
		child.queue_free()
	hero_buttons.clear()
	
	var count := 0
	for hero_id in HERO_DATA:
		var data: Dictionary = HERO_DATA[hero_id]
		if faction != "ALL" and data["faction"] != faction:
			continue
		var btn := Button.new()
		btn.text = "%s\n%s" % [data["name"], data["skill"].split(":")[0]]
		btn.custom_minimum_size = Vector2(140, 80)
		btn.pressed.connect(_on_hero_selected.bind(hero_id))
		hero_grid.add_child(btn)
		hero_buttons.append(btn)
		count += 1
	
	# Update title
	title_label.text = "選擇英雄 (%d)" % count

func _on_hero_selected(hero_id: String) -> void:
	selected_hero_id = hero_id
	var data: Dictionary = HERO_DATA[hero_id]
	
	# Update info panel
	for child in info_panel.get_children():
		child.queue_free()
	
	var name_label := Label.new()
	name_label.text = data["name"]
	name_label.add_theme_font_size_override("font_size", 24)
	info_panel.add_child(name_label)
	
	var faction_label := Label.new()
	faction_label.text = "陣營: %s" % data["faction"]
	info_panel.add_child(faction_label)
	
	var hp_label := Label.new()
	hp_label.text = "體力: %d" % data["hp"]
	info_panel.add_child(hp_label)
	
	var skill_label := Label.new()
	skill_label.text = "技能: %s" % data["skill"]
	skill_label.add_theme_font_size_override("font_size", 14)
	info_panel.add_child(skill_label)
	
	var arch_label := Label.new()
	arch_label.text = "類型: %s" % data["archetype"]
	info_panel.add_child(arch_label)
	
	confirm_btn.disabled = false

func _on_confirm() -> void:
	if selected_hero_id != "":
		hero_selected.emit(selected_hero_id)
		# Store hero choice and transition to battle
		PlayerData.chosen_hero_id = selected_hero_id
		get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")