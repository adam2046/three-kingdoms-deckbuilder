# Map Screen + Meta-Progression + Zone 2 Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.
> **Godot version:** 4.6.2 (GDScript, tabs only for indentation)
> **Project:** ~/Projects/game1-three-kingdoms

**Goal:** Build the visual map screen, meta-progression system (hero unlocks, card unlocks, relics), and Zone 2 (Hu Lao Gate) — in that dependency order.

**Architecture:** Map screen is a separate Godot scene navigated to from battle victory. Meta-progression is a data layer (RunData expansion + unlock definitions). Zone 2 follows the existing zone_1() pattern in MapData. Each feature runs `--check-only` + hero sweep after completion.

**Design source:** Obsidian vault — Game 1.md §Roguelike 結構, §元進度, §區域設計

---

## PART 1: Map Screen UI

**Goal:** A visual map showing the current zone's node sequence. Player sees their position, upcoming nodes, and can navigate (auto-advancing to the next unreached node). Integrates with the existing battle-scene → victory → advance flow.

**Current state:** MapManager and MapData exist. Node advancement is automatic (signals fire, next node activates). No visual map exists — the zone_label in the battle UI shows minimal info. Shop/campfire/event overlays reuse the RewardOverlay in battle_scene.gd.

**Architecture:** New scene `scenes/map/map_screen.tscn` with script `scripts/map/map_screen.gd`. Shown BETWEEN nodes (after battle victory, before next node starts). The map screen reads MapManager state and renders a horizontal node path. Player clicks "Continue" to advance to the next node.

### Task M1: Create map screen scene and script skeleton

**Objective:** Create the map screen .tscn with a Control root, MapScreen script attached, and basic label showing zone name.

**Files:**
- Create: `scenes/map/map_screen.tscn`
- Create: `scripts/map/map_screen.gd`

**Step 1: Write map_screen.gd skeleton**

```gdscript
extends Control
class_name MapScreen

## MapScreen — visual roguelike map between nodes.
## Shows current zone, node path, player position.

@onready var zone_label: Label = $ZoneLabel
@onready var node_container: HBoxContainer = $NodePath/NodeContainer
@onready var continue_btn: Button = $ContinueBtn
@onready var map_manager: MapManager = $MapManager

signal continue_pressed()

func _ready() -> void:
	continue_btn.pressed.connect(_on_continue)

func show_map(mgr: MapManager) -> void:
	## Populate the map from MapManager state.
	map_manager = mgr
	zone_label.text = mgr.get_current_zone().name_zh
	_render_nodes()

func _render_nodes() -> void:
	pass  # Will fill in Task M2

func _on_continue() -> void:
	continue_pressed.emit()
```

**Step 2: Write map_screen.tscn**

```
[gd_scene load_steps=2 format=3 uid="uid://map_screen"]

[ext_resource type="Script" path="res://scripts/map/map_screen.gd" id="1_script"]

[node name="MapScreen" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_script")

[node name="Background" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0.08, 0.06, 0.04, 1.0)

[node name="ZoneLabel" type="Label" parent="."]
layout_mode = 1
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
offset_left = -200.0
offset_top = 40.0
offset_right = 200.0
offset_bottom = 90.0
text = "黃巾之亂"
horizontal_alignment = 1
theme_override_font_sizes/font_size = 32

[node name="NodePath" type="Control" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -800.0
offset_top = -60.0
offset_right = 800.0
offset_bottom = 60.0

[node name="NodeContainer" type="HBoxContainer" parent="NodePath"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
alignment = 1

[node name="ContinueBtn" type="Button" parent="."]
layout_mode = 1
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
offset_left = -80.0
offset_top = 700.0
offset_right = 80.0
offset_bottom = 760.0
text = "繼續前進 ▶"

[node name="MapManager" type="Node" parent="."]
```

**Step 3: Verify**

```bash
cd ~/Projects/game1-three-kingdoms
godot --headless --quit --check-only
```

Expected: No ERROR lines.

---

### Task M2: Render node path with icons and position indicator

**Objective:** Populate `_render_nodes()` to show all nodes in the current zone as a horizontal row of styled panels. Completed nodes show dimmed + checkmark. Current node highlighted. Future nodes shown with type icon.

**Files:**
- Modify: `scripts/map/map_screen.gd` — `_render_nodes()`

**Step 1: Replace `_render_nodes()` with full implementation**

```gdscript
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

func _render_nodes() -> void:
	for child in node_container.get_children():
		child.queue_free()

	var zone = map_manager.get_current_zone()
	var current_idx = map_manager.run_data.current_node

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

	# Arrow between nodes (except last)
	if zone.nodes.size() > 1:
		for i in range(zone.nodes.size() - 1):
			var arrow := Label.new()
			arrow.text = "→"
			arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			arrow.add_theme_font_size_override("font_size", 24)
			# Insert arrows between panels: after each panel
			var insert_pos = i * 2 + 1
			if insert_pos < node_container.get_child_count():
				node_container.move_child(arrow, insert_pos)
			else:
				node_container.add_child(arrow)
```

**Step 2: Verify**

```bash
godot --headless --quit --check-only
```

Expected: No errors.

---

### Task M3: Wire map screen into the game flow

**Objective:** Show the map screen between nodes instead of silently advancing. After a node completes (battle victory, campfire heal, shop purchase, event), the player sees the map screen and clicks "Continue".

**Files:**
- Modify: `scripts/battle/battle_scene.gd` — `_on_battle_ended()`, `_hide_card_rewards()`, `_hide_shop()`, `_resolve_event()`, campfire handling
- Modify: `scenes/battle/battle.tscn` — add MapScreen as child (or use separate scene)
- New entry in: `project.godot` (if using change_scene)

**Step 1: Add `_on_map_continue()` handler to battle_scene.gd**

Add to battle_scene.gd (after `_on_gold_changed`):

```gdscript
var map_screen: Control = null

func _show_map_screen() -> void:
	## Show map screen overlay, wait for player to press Continue.
	map_screen = load("res://scenes/map/map_screen.tscn").instantiate()
	map_screen.show_map(map_manager)
	map_screen.continue_pressed.connect(_on_map_continue)
	add_child(map_screen)
	# Hide battle controls
	end_turn_btn.visible = false
	skill_btn.visible = false

func _on_map_continue() -> void:
	## Player pressed Continue on map screen — advance to next node.
	if map_screen:
		map_screen.queue_free()
		map_screen = null
	map_manager.advance_to_next_node()
```

**Step 2: Replace direct `map_manager.advance_to_next_node()` calls with `_show_map_screen()`**

In `battle_scene.gd`, replace these calls:

- Line 647 (campfire): `map_manager.advance_to_next_node()` → `_show_map_screen()`
- Line 718 (hide rewards): `map_manager.advance_to_next_node()` → `_show_map_screen()`
- Line 851 (hide shop): `map_manager.advance_to_next_node()` → `_show_map_screen()`
- Line 870 (resolve event): `map_manager.advance_to_next_node()` → `_show_map_screen()`

**Step 3: Verify**

```bash
godot --headless --quit --check-only
python3 scripts/tests/hero_sweep.py --quick
```

Expected: No parse errors, 3/3 heroes pass.

---

### Task M4: Zone info panel and styling polish

**Objective:** Add zone-themed info to the map screen: zone description, boss name, and progress counter (e.g. "Node 3/7").

**Files:**
- Modify: `scripts/map/map_screen.gd` — add info panel
- Modify: `scenes/map/map_screen.tscn` — add labels

**Step 1: Add InfoPanel labels to .tscn**

Add these nodes to `map_screen.tscn` under the root:

```
[node name="InfoPanel" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 1
anchor_left = 1.0
anchor_right = 1.0
offset_left = -300.0
offset_top = 40.0
offset_right = -20.0
offset_bottom = 200.0
alignment = 2

[node name="ProgressLabel" type="Label" parent="InfoPanel"]
text = "節點 3/7"
horizontal_alignment = 2

[node name="BossLabel" type="Label" parent="InfoPanel"]
text = "首領：張角"
horizontal_alignment = 2
```

**Step 2: Update `show_map()` to populate info**

```gdscript
@onready var progress_label: Label = $InfoPanel/ProgressLabel
@onready var boss_label: Label = $InfoPanel/BossLabel

func show_map(mgr: MapManager) -> void:
	map_manager = mgr
	var zone = mgr.get_current_zone()
	zone_label.text = zone.name_zh
	progress_label.text = "節點 %d/%d" % [mgr.run_data.current_node + 1, zone.nodes.size()]
	boss_label.text = "首領：%s" % _get_boss_display_name(zone.boss_id)
	_render_nodes()

func _get_boss_display_name(boss_id: String) -> String:
	match boss_id:
		"zhang_jiao": return "張角"
		"lv_bu": return "呂布"
		"cao_cao": return "曹操"
		"zhuge_liang": return "諸葛亮"
		"sim_yi": return "司馬懿"
	return boss_id
```

**Step 3: Verify**

```bash
godot --headless --quit --check-only
python3 scripts/tests/hero_sweep.py --quick
```

Expected: No parse errors, 3/3 pass.

---

## PART 2: Meta-Progression

**Goal:** A system that persists across runs: hero unlocking, card pool expansion, and relics. Player earns meta-currency (experience/spirit points) from completed runs, spent on permanent upgrades.

**Current state:** Zero meta-progression. RunData is per-run only. No save file. No unlocks. All 19 heroes always available in hero_select.

**Architecture:**
- `MetaData` singleton (autoload) — persists across runs, saves to disk
- `UnlockData` resource — defines unlock conditions and costs
- Meta-screen scene — spend points between runs
- Integrate with PlayerData to restrict hero_select to unlocked heroes

### Task M5: Create MetaData autoload with save/load

**Objective:** A singleton that tracks permanent player progress: unlocked hero IDs, unlocked card IDs, relic collection, meta-currency. Survives between game sessions via a JSON save file.

**Files:**
- Create: `scripts/data/meta_data.gd`
- Modify: `project.godot` — add autoload entry

**Step 1: Write meta_data.gd**

```gdscript
extends Node
## MetaData — permanent player progression across runs.
## Autoload singleton, saves to user://meta_save.json

# -- Unlocks --
var unlocked_heroes: Array[String] = ["zhao_yun", "cao_cao", "sun_quan"]  # Starters
var unlocked_cards: Array[String] = []    # Card IDs available in reward/shop pools
var relics: Array[String] = []            # Owned relic IDs (passive bonuses)

# -- Currency --
var spirit_points: int = 0  # Earned from runs, spent on unlocks

# -- Run history --
var total_runs: int = 0
var total_wins: int = 0
var highest_zone: int = 0

# -- Save/Load --
const SAVE_PATH := "user://meta_save.json"

func save() -> void:
	var data := {
		"unlocked_heroes": unlocked_heroes,
		"unlocked_cards": unlocked_cards,
		"relics": relics,
		"spirit_points": spirit_points,
		"total_runs": total_runs,
		"total_wins": total_wins,
		"highest_zone": highest_zone,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))

func load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err == OK:
		var data: Dictionary = json.get_data()
		unlocked_heroes.assign(data.get("unlocked_heroes", unlocked_heroes))
		unlocked_cards.assign(data.get("unlocked_cards", unlocked_cards))
		relics.assign(data.get("relics", relics))
		spirit_points = data.get("spirit_points", 0)
		total_runs = data.get("total_runs", 0)
		total_wins = data.get("total_wins", 0)
		highest_zone = data.get("highest_zone", 0)

func add_spirit_points(amount: int) -> void:
	spirit_points += amount

func spend_spirit_points(amount: int) -> bool:
	if spirit_points >= amount:
		spirit_points -= amount
		return true
	return false

func unlock_hero(hero_id: String) -> void:
	if hero_id not in unlocked_heroes:
		unlocked_heroes.append(hero_id)

func is_hero_unlocked(hero_id: String) -> bool:
	return hero_id in unlocked_heroes

func record_run(won: bool, zone_reached: int) -> void:
	total_runs += 1
	if won:
		total_wins += 1
	highest_zone = max(highest_zone, zone_reached)
	# Award spirit points
	var points := zone_reached * 10
	if won:
		points += 50  # Victory bonus
	add_spirit_points(points)
	save()
```

**Step 2: Register autoload in project.godot**

Add to `project.godot` under `[autoload]`:

```ini
MetaData="*res://scripts/data/meta_data.gd"
```

**Step 3: Verify**

```bash
godot --headless --quit --check-only
```

Expected: No errors.

---

### Task M6: Hero unlock definitions and hero_select integration

**Objective:** Define unlock conditions for non-starter heroes. Modify hero_select to only show unlocked heroes. Add unlock cost display for locked heroes.

**Files:**
- Create: `scripts/data/unlock_data.gd` — hero unlock definitions
- Modify: `scripts/menu/hero_select.gd` — filter by MetaData, show locked state

**Step 1: Write unlock_data.gd**

```gdscript
extends Resource
class_name UnlockData

## UnlockData — defines hero and card unlock conditions.

# Hero unlock definitions
# Cost in spirit_points. -1 = locked behind achievement (not purchasable)
const HERO_UNLOCKS := {
	"guan_yu": {"cost": 100, "desc_zh": "使用趙雲通關區域 1"},
	"zhang_fei": {"cost": 100, "desc_zh": "使用關羽通關區域 1"},
	"zhuge_liang": {"cost": 200, "desc_zh": "累積通關 5 次"},
	"liu_bei": {"cost": 150, "desc_zh": "擁有任意隨從通關"},
	"ma_chao": {"cost": 100, "desc_zh": "使用騎兵裝備通關"},
	"huang_zhong": {"cost": 100, "desc_zh": "使用「殺」造成累積 50 點傷害"},
	"sim_yi": {"cost": 200, "desc_zh": "通關區域 2"},
	"xiahou_dun": {"cost": 100, "desc_zh": "累積承受 30 點傷害"},
	"zhen_ji": {"cost": 150, "desc_zh": "使用判定相關效果 10 次"},
	"guo_jia": {"cost": 150, "desc_zh": "使用錦囊牌 20 次"},
	"zhou_yu": {"cost": 150, "desc_zh": "使用「決鬥」擊敗 5 名敵方"},
	"lu_xun": {"cost": 200, "desc_zh": "通關區域 3"},
	"huang_gai": {"cost": 100, "desc_zh": "使用「酒」強化後的「殺」擊敗敵方 5 次"},
	"da_qiao": {"cost": 150, "desc_zh": "使用「樂不思蜀」5 次"},
	"lv_bu": {"cost": 300, "desc_zh": "通關區域 2 首領（呂布）"},
	"diao_chan": {"cost": 200, "desc_zh": "使用「決鬥」累積 10 次"},
}

static func get_cost(hero_id: String) -> int:
	return HERO_UNLOCKS.get(hero_id, {}).get("cost", 100)

static func get_desc(hero_id: String) -> String:
	return HERO_UNLOCKS.get(hero_id, {}).get("desc_zh", "?")

static func is_starter(hero_id: String) -> bool:
	return hero_id in ["zhao_yun", "cao_cao", "sun_quan"]
```

**Step 2: Modify hero_select.gd to filter by unlocks**

In `_show_heroes()`, add unlock filtering after line 75:

```gdscript
# Filter: only show unlocked heroes
if not UnlockData.is_starter(hero_id) and not MetaData.is_hero_unlocked(hero_id):
	continue  # Skip locked heroes
```

**Step 3: Add locked hero display (greyed out, shows cost)**

In `_show_heroes()`, add locked heroes as dimmed buttons:

```gdscript
# After unlocked heroes, show locked heroes (greyed out) with cost
for hero_id in HERO_DATA:
	var data: Dictionary = HERO_DATA[hero_id]
	if faction != "ALL" and data["faction"] != faction:
		continue
	if UnlockData.is_starter(hero_id) or MetaData.is_hero_unlocked(hero_id):
		continue  # Already shown above
	
	var btn := Button.new()
	btn.text = "%s\n🔒 %d 靈" % [data["name"], UnlockData.get_cost(hero_id)]
	btn.custom_minimum_size = Vector2(140, 80)
	btn.disabled = true
	btn.modulate = Color(0.4, 0.4, 0.4, 1.0)
	btn.pressed.connect(_on_locked_hero_clicked.bind(hero_id))
	hero_grid.add_child(btn)
	hero_buttons.append(btn)
	count += 1
```

**Step 4: Verify**

```bash
godot --headless --quit --check-only
python3 scripts/tests/hero_sweep.py
```

Expected: No errors, 19/19 pass (unlocked heroes still work).

---

### Task M7: Defeat screen and run-end summary

**Objective:** When the player dies, show a defeat screen with stats (zone reached, spirit points earned) and a "Return to Menu" button. This is where meta-progression rewards are calculated.

**Files:**
- Modify: `scripts/battle/battle_scene.gd` — `_on_battle_ended()` defeat path
- New: defeat overlay in `scenes/battle/battle.tscn` (or reuse RewardOverlay)

**Step 1: Add defeat overlay to battle.tscn**

Add to `UI` node (similar to RewardOverlay):

```
[node name="DefeatOverlay" type="Control" parent="UI"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
visible = false

[node name="DefeatTitle" type="Label" parent="UI/DefeatOverlay"]
layout_mode = 1
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
offset_left = -200.0
offset_top = 200.0
offset_right = 200.0
offset_bottom = 260.0
text = "敗北"
horizontal_alignment = 1
theme_override_font_sizes/font_size = 48
theme_override_colors/font_color = Color(1.0, 0.2, 0.2, 1.0)

[node name="DefeatStats" type="Label" parent="UI/DefeatOverlay"]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -200.0
offset_top = -60.0
offset_right = 200.0
offset_bottom = 60.0
text = "區域 1 節點 3\\n獲得 30 靈"
horizontal_alignment = 1

[node name="MenuBtn" type="Button" parent="UI/DefeatOverlay"]
layout_mode = 1
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
offset_left = -80.0
offset_top = 650.0
offset_right = 80.0
offset_bottom = 710.0
text = "返回主菜單"
```

**Step 2: Update battle_scene.gd defeat handler and references**

Add onready:
```gdscript
@onready var defeat_overlay: Control = $UI/DefeatOverlay
@onready var defeat_stats: Label = $UI/DefeatOverlay/DefeatStats
@onready var menu_btn: Button = $UI/DefeatOverlay/MenuBtn
```

In `_ready()`, add:
```gdscript
menu_btn.pressed.connect(_on_return_to_menu)
```

Replace the defeat block in `_on_battle_ended()`:
```gdscript
if victory:
	print("VICTORY! Gold: %d" % map_manager.get_gold())
	_show_card_rewards()
else:
	print("DEFEAT... Run over.")
	# Record run result for meta-progression
	MetaData.record_run(false, map_manager.run_data.current_zone)
	var points := MetaData.spirit_points
	defeat_stats.text = "區域 %d\n獲得 %d 靈" % [map_manager.run_data.current_zone + 1, points]
	defeat_overlay.visible = true
	end_turn_btn.visible = false
	skill_btn.visible = false
```

Add handler:
```gdscript
func _on_return_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
```

**Step 3: Verify**

```bash
godot --headless --quit --check-only
```

Expected: No parse errors.

---

### Task M8: Victory meta-progression reward

**Objective:** On run victory, record the run and award spirit points. Show the reward on a victory summary screen.

**Files:**
- Modify: `scripts/battle/battle_scene.gd` — `_on_battle_ended()` victory path

**Step 1: Add victory recording**

After the `_show_card_rewards()` call in `_on_battle_ended()`:

```gdscript
# Record run as victory
MetaData.record_run(true, map_manager.run_data.current_zone + 1)
MetaData.save()
print("Run recorded: %d wins / %d runs, %d spirit points" % [MetaData.total_wins, MetaData.total_runs, MetaData.spirit_points])
```

**Step 2: Verify**

```bash
godot --headless --quit --check-only
```

Expected: No errors.

---

## PART 3: Zone 2 — Hu Lao Gate

**Goal:** A second zone with new enemies and boss (呂布). Follows the existing `zone_1()` pattern in MapData.

**Design source:** Game 1.md §區域設計 — "虎牢關: 董卓軍, Boss 呂布（無雙：需雙閃雙殺）"

### Task Z1: Add Zone 2 enemy definitions

**Objective:** Create at least 2 new enemy types for Zone 2: 董卓兵 (basic) and 虎牢守將 (elite). Add boss 呂布.

**Files:**
- Modify: `scripts/map/map_manager.gd` — `_create_enemy_for_id()`

**Step 1: Add new enemies to _create_enemy_for_id() in map_manager.gd**

Add these match branches after the existing `zhang_jiao` block:

```gdscript
"dong_zhuo_soldier":
	enemy.id = "dong_zhuo_soldier"
	enemy.name_zh = "董卓兵"
	enemy.name_en = "Dong Zhuo Soldier"
	enemy.max_hp = 6
	enemy.intent_pattern = [0, 0, 2]  # ATTACK, ATTACK, DEFEND
"hu_lao_guard":
	enemy.id = "hu_lao_guard"
	enemy.name_zh = "虎牢守將"
	enemy.name_en = "Hu Lao Guard"
	enemy.max_hp = 9
	enemy.intent_pattern = [0, 2, 3, 0]  # ATTACK, BUFF, SKILL, ATTACK
"lv_bu":
	enemy.id = "lv_bu"
	enemy.name_zh = "呂布"
	enemy.name_en = "Lu Bu"
	enemy.max_hp = 18
	enemy.intent_pattern = [0, 0, 3, 0, 2]  # ATTACK, ATTACK, SKILL, ATTACK, BUFF
```

**Step 2: Add intent values for new enemies in _get_intent_value()**

```gdscript
"dong_zhuo_soldier":
	return 2 if intent == 0 else 1
"hu_lao_guard":
	return 3 if intent == 0 else (2 if intent == 3 else 1)
"lv_bu":
	return 2 if intent == 0 else (3 if intent == 3 else 2)
```

**Step 3: Verify**

```bash
godot --headless --quit --check-only
```

Expected: No errors.

---

### Task Z2: Define Zone 2 in MapData

**Objective:** Add `zone_2()` static function with a 7-node sequence: Start → Battle → Shop → Campfire → Elite → Event → Boss (呂布).

**Files:**
- Modify: `scripts/data/map_data.gd` — add `zone_2()` and update `all_zones()`

**Step 1: Add zone_2()**

After `zone_1()`:

```gdscript
## Zone 2: 虎牢關 (Hu Lao Gate)
static func zone_2() -> ZoneDef:
	var nodes: Array = []
	nodes.append(NodeDef.new(NodeType.START, "虎牢關", "Hu Lao Gate"))
	nodes.append(NodeDef.new(NodeType.BATTLE, "遭遇戰", "Skirmish", ["dong_zhuo_soldier"]))
	nodes.append(NodeDef.new(NodeType.SHOP, "商店", "Shop"))
	nodes.append(NodeDef.new(NodeType.CAMPFIRE, "營火", "Campfire"))
	nodes.append(NodeDef.new(NodeType.ELITE, "虎牢守將", "Hu Lao Guardian", ["hu_lao_guard"]))
	nodes.append(NodeDef.new(NodeType.EVENT, "事件", "Event"))
	nodes.append(NodeDef.new(NodeType.BOSS, "呂布", "Lu Bu", ["lv_bu"]))
	return ZoneDef.new("zone_2", "虎牢關", "Hu Lao Gate", nodes, "lv_bu")
```

**Step 2: Update all_zones()**

```gdscript
static func all_zones() -> Array[ZoneDef]:
	return [zone_1(), zone_2()]
```

**Step 3: Verify**

```bash
godot --headless --quit --check-only
python3 scripts/tests/hero_sweep.py
```

Expected: No errors, 19/19 pass (Zone 1 still works; Zone 2 not reached in headless test but compiles).

---

### Task Z3: 呂布 boss skill — 無雙 (requires double dodge/slash)

**Objective:** Implement 呂布's special mechanic: when 呂布 attacks, player needs 2 閃 cards to block. When player uses 決鬥 on 呂布, 呂布 requires player to play 2 殺.

**Files:**
- Modify: `scripts/battle/battle_manager.gd` — enemy attack and duel logic
- Modify: `scripts/battle/battle_scene.gd` — dodge response for double-dodge

**Step 1: Add 無雙 flag to EnemyData**

In `scripts/data/enemy_data.gd`, add:

```gdscript
var requires_double_dodge: bool = false  # 無雙: 殺 needs 2 閃 to block
```

**Step 2: Set flag in _create_enemy_for_id()**

In `map_manager.gd`, for lv_bu:

```gdscript
"lv_bu":
	# ... existing setup ...
	enemy.requires_double_dodge = true
```

**Step 3: Handle double dodge in dodge response flow**

In `battle_scene.gd`, modify `_on_awaiting_dodge` and `_on_card_played` (dodge path):

When lv_bu attacks and player plays 1 閃, the dodge isn't complete — need a second 閃:

```gdscript
var dodge_count_needed: int = 1
var dodge_count_played: int = 0

func _on_awaiting_dodge(enemy_name: String, damage: int) -> void:
	dodge_response_active = true
	dodge_count_played = 0
	dodge_count_needed = 2 if battle_manager._current_attacker_requires_double() else 1
	phase_label.text = "%s 攻擊! 傷害 %d — 出閃? (%d/%d)" % [enemy_name, damage, dodge_count_played, dodge_count_needed]
	end_turn_btn.text = "承受傷害"
	end_turn_btn.visible = true
	_refresh_hand()

func _on_card_played(card: CardData) -> void:
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
	# ... rest of existing code ...
```

Add to BattleManager:
```gdscript
func _current_attacker_requires_double() -> bool:
	# Check if current attacker (boss) has 無雙
	for enemy in enemies:
		if enemy.requires_double_dodge and enemy.current_intent == EnemyData.Intent.ATTACK:
			return true
	return false
```

**Step 4: Verify**

```bash
godot --headless --quit --check-only
python3 scripts/tests/hero_sweep.py
```

Expected: No errors, 3/3 pass.

---

## Execution Order & Dependencies

```
M1 → M2 → M3 → M4     (Map Screen — can be tested incrementally)
       ↓
M5 → M6 → M7 → M8     (Meta-Progression — depends on M3 for flow hooks)
       ↓
Z1 → Z2 → Z3          (Zone 2 — depends on M5 for enemy factory + boss skill)
```

**After each task:** Run `godot --headless --quit --check-only`. After map/meta tasks that touch hero init or enums: run `python3 scripts/tests/hero_sweep.py --quick`.

**After each part (M4, M8, Z3):** Run full hero sweep + update GitHub board.

## Files Created/Modified Summary

| Phase | New Files | Modified Files |
|-------|-----------|----------------|
| Map Screen | `scenes/map/map_screen.tscn`, `scripts/map/map_screen.gd` | `scripts/battle/battle_scene.gd`, `scenes/battle/battle.tscn` |
| Meta | `scripts/data/meta_data.gd`, `scripts/data/unlock_data.gd` | `project.godot`, `scripts/menu/hero_select.gd`, `scripts/battle/battle_scene.gd`, `scenes/battle/battle.tscn` |
| Zone 2 | — | `scripts/map/map_manager.gd`, `scripts/data/map_data.gd`, `scripts/data/enemy_data.gd`, `scripts/battle/battle_manager.gd`, `scripts/battle/battle_scene.gd` |

## Verification Checklist (After Full Implementation)

- [ ] `godot --headless --quit --check-only` — zero ERROR lines
- [ ] `python3 scripts/tests/hero_sweep.py` — 19/19 pass
- [ ] Map screen renders with correct zone info (visual check in editor)
- [ ] Clicking "Continue" on map advances to next node
- [ ] Defeat screen shows, records run, awards spirit points
- [ ] Locked heroes appear greyed out with cost
- [ ] Zone 2 loads after Zone 1 clear (headless run reaches zone_2)
- [ ] 呂布 無雙 double-dodge mechanic triggers correctly
