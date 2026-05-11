extends Control
class_name MapScreen

## MapScreen — visual roguelike map between nodes.
## Shows current zone, node path, player position.

@onready var zone_label: Label = $ZoneLabel
@onready var node_container: HBoxContainer = $NodePath/NodeContainer
@onready var continue_btn: Button = $ContinueBtn
@onready var progress_label: Label = $InfoPanel/ProgressLabel
@onready var boss_label: Label = $InfoPanel/BossLabel

signal continue_pressed()

func _ready() -> void:
	continue_btn.pressed.connect(_on_continue)

func show_map(mgr: MapManager) -> void:
	## Populate the map from MapManager state.
	var zone = mgr.get_current_zone()
	zone_label.text = zone.name_zh
	progress_label.text = "節點 %d/%d" % [mgr.run_data.current_node + 1, zone.nodes.size()]
	boss_label.text = "首領：%s" % _get_boss_display_name(zone.boss_id)
	_render_nodes(mgr)

func _get_boss_display_name(boss_id: String) -> String:
	match boss_id:
		"zhang_jiao": return "張角"
		"lv_bu": return "呂布"
		"cao_cao": return "曹操"
		"zhuge_liang": return "諸葛亮"
		"sim_yi": return "司馬懿"
	return boss_id

const NODE_ICONS := {
	MapData.NodeType.START: "🏁",
	MapData.NodeType.BATTLE: "⚔️",
	MapData.NodeType.CAMPFIRE: "🔥",
	MapData.NodeType.ELITE: "💀",
	MapData.NodeType.BOSS: "👹",
	MapData.NodeType.SHOP: "🛒",
	MapData.NodeType.EVENT: "❓",
}

const NODE_LABELS := {
	MapData.NodeType.START: "起點",
	MapData.NodeType.BATTLE: "戰鬥",
	MapData.NodeType.CAMPFIRE: "營火",
	MapData.NodeType.ELITE: "精英",
	MapData.NodeType.BOSS: "首領",
	MapData.NodeType.SHOP: "商店",
	MapData.NodeType.EVENT: "事件",
}

func _render_nodes(mgr: MapManager) -> void:
	for child in node_container.get_children():
		child.queue_free()

	var zone = mgr.get_current_zone()
	var current_idx = mgr.run_data.current_node

	for i in range(zone.nodes.size()):
		var node_def = zone.nodes[i]
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(130, 120)

		var vbox := VBoxContainer.new()
		panel.add_child(vbox)

		# Node type label
		var type_label := Label.new()
		type_label.text = NODE_LABELS.get(node_def.type, "?")
		type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		type_label.add_theme_font_size_override("font_size", 13)
		vbox.add_child(type_label)

		# Icon
		var icon_label := Label.new()
		icon_label.text = NODE_ICONS.get(node_def.type, "?")
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", 36)
		vbox.add_child(icon_label)

		# Name
		var name_label := Label.new()
		name_label.text = node_def.label_zh
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 11)
		vbox.add_child(name_label)

		# Style by state
		var style := StyleBoxFlat.new()
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3

		if i < current_idx:
			# Completed
			style.bg_color = Color(0.15, 0.15, 0.15, 0.7)
			style.border_color = Color.GRAY
		elif i == current_idx:
			# Current
			style.bg_color = Color(0.2, 0.15, 0.05, 0.9)
			style.border_color = Color.GOLD
		else:
			# Upcoming
			style.bg_color = Color(0.1, 0.08, 0.06, 0.6)
			style.border_color = Color(0.3, 0.3, 0.3, 0.5)

		panel.add_theme_stylebox_override("panel", style)
		node_container.add_child(panel)

	# Arrows between nodes
	if zone.nodes.size() > 1:
		for i in range(zone.nodes.size() - 1):
			var arrow := Label.new()
			arrow.text = "→"
			arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			arrow.add_theme_font_size_override("font_size", 24)
			node_container.add_child(arrow)
			# Move arrow to position between panels
			var insert_pos = i * 2 + 1
			node_container.move_child(arrow, insert_pos)

func _on_continue() -> void:
	continue_pressed.emit()
