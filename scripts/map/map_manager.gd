extends Node
class_name MapManager

## MapManager — tracks where the player is on the roguelike map.
## Generates the map, advances between nodes, triggers battles/events.

const RunDataClass = preload("res://scripts/data/run_data.gd")
const MapDataClass = preload("res://scripts/data/map_data.gd")
const EnemyDataClass = preload("res://scripts/data/enemy_data.gd")

# -- Signals --
signal node_changed(node_type: int, node_index: int)
signal zone_changed(zone_index: int, zone_name: String)
signal run_started()
signal run_ended(victory: bool)
signal gold_changed(gold: int)

# -- State -- (untyped to avoid headless cross-file class_name issues)
var run_data = null             # RunData
var current_zone_def = null     # MapData.ZoneDef
var current_node_def = null     # MapData.NodeDef


func _ready() -> void:
    pass  # Initialized externally via start_run()


func start_run() -> void:
    ## Begin a new roguelike run. Creates RunData, loads first zone.
    run_data = RunDataClass.new()
    run_data.run_seed = randi()
    _enter_zone(0)
    run_started.emit()


func _enter_zone(zone_index: int) -> void:
    run_data.current_zone = zone_index
    run_data.current_node = 0
    current_zone_def = MapDataClass.get_zone(zone_index)
    if current_zone_def == null:
        run_ended.emit(true)  # All zones cleared = victory
        return
    zone_changed.emit(zone_index, current_zone_def.name_zh)
    _enter_node(0)


func _enter_node(node_index: int) -> void:
    run_data.current_node = node_index
    if node_index >= current_zone_def.nodes.size():
        # Zone complete — advance to next zone
        _enter_zone(run_data.current_zone + 1)
        return
    
    current_node_def = current_zone_def.nodes[node_index]
    node_changed.emit(current_node_def.type, node_index)


func get_current_node():  # Returns MapData.NodeDef
    return current_node_def


func get_current_zone():  # Returns MapData.ZoneDef
    return current_zone_def


func get_node_at(index: int):  # Returns MapData.NodeDef
    if current_zone_def and index >= 0 and index < current_zone_def.nodes.size():
        return current_zone_def.nodes[index]
    return null


func advance_to_next_node() -> void:
    ## Call after completing current node (battle won, event resolved, etc.)
    _enter_node(run_data.current_node + 1)


func get_enemy_for_current_node():  # Returns EnemyData
    ## Return an EnemyData for the current battle/elite/boss node.
    if current_node_def == null:
        return _create_enemy_for_id("yellow_turban_soldier")
    
    var enemy_id: String = "yellow_turban_soldier"
    if current_node_def.enemy_pool.size() > 0:
        # Pick random from pool
        enemy_id = current_node_def.enemy_pool[randi() % current_node_def.enemy_pool.size()]
    
    return _create_enemy_for_id(enemy_id)


func _create_enemy_for_id(enemy_id: String):  # Returns EnemyData
    ## Factory for enemy instances. Full data will be in resources/enemies/.
    var enemy = EnemyDataClass.new()
    match enemy_id:
        "yellow_turban_soldier":
            enemy.id = "yellow_turban_soldier"
            enemy.name_zh = "黃巾兵"
            enemy.name_en = "Yellow Turban Soldier"
            enemy.max_hp = 5
            enemy.intent_pattern = [0, 0, 2]  # ATTACK, ATTACK, DEFEND
        "yellow_turban_crossbow":
            enemy.id = "yellow_turban_crossbow"
            enemy.name_zh = "黃巾弓手"
            enemy.name_en = "Yellow Turban Crossbow"
            enemy.max_hp = 4
            enemy.intent_pattern = [0, 2, 0]  # ATTACK, DEFEND, ATTACK
        "yellow_turban_elite":
            enemy.id = "yellow_turban_elite"
            enemy.name_zh = "黃巾精銳"
            enemy.name_en = "Yellow Turban Elite"
            enemy.max_hp = 8
            enemy.intent_pattern = [0, 2, 0]  # ATTACK, BUFF, ATTACK
        "zhang_jiao":
            enemy.id = "zhang_jiao"
            enemy.name_zh = "張角"
            enemy.name_en = "Zhang Jiao"
            enemy.max_hp = 15
            enemy.intent_pattern = [0, 3, 0, 2]  # ATTACK, SKILL, ATTACK, BUFF
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
            enemy.requires_double_dodge = true
        # --- Zone 2 new enemies ---
        "dong_zhuo_crossbow":
            enemy.id = "dong_zhuo_crossbow"
            enemy.name_zh = "董卓弓手"
            enemy.name_en = "Dong Zhuo Crossbow"
            enemy.max_hp = 4
            enemy.intent_pattern = [0, 0, 2]  # ATTACK, ATTACK, DEFEND — fragile but aggressive
        "road_bandit":
            enemy.id = "road_bandit"
            enemy.name_zh = "路盜"
            enemy.name_en = "Road Bandit"
            enemy.max_hp = 5
            enemy.intent_pattern = [0, 2, 0]  # ATTACK, DEFEND, ATTACK
        # --- Zone 3: 赤壁之戰 ---
        "cao_navy_soldier":
            enemy.id = "cao_navy_soldier"
            enemy.name_zh = "曹軍水兵"
            enemy.name_en = "Cao Navy Soldier"
            enemy.max_hp = 6
            enemy.intent_pattern = [0, 0, 2]  # ATTACK, ATTACK, DEFEND
        "cao_navy_archer":
            enemy.id = "cao_navy_archer"
            enemy.name_zh = "曹軍弓手"
            enemy.name_en = "Cao Navy Archer"
            enemy.max_hp = 5
            enemy.intent_pattern = [0, 2, 0]  # ATTACK, DEFEND, ATTACK — medium damage
        "cao_strategist":
            enemy.id = "cao_strategist"
            enemy.name_zh = "曹軍謀士"
            enemy.name_en = "Cao Strategist"
            enemy.max_hp = 4
            enemy.intent_pattern = [3, 2, 0]  # SKILL, DEFEND, ATTACK — skill first
        "cao_iron_guard":
            enemy.id = "cao_iron_guard"
            enemy.name_zh = "鐵索衛"
            enemy.name_en = "Iron Chain Guard"
            enemy.max_hp = 10
            enemy.intent_pattern = [2, 0, 0, 3]  # DEFEND, ATTACK, ATTACK, SKILL — tanky
        "cai_mao":
            enemy.id = "cai_mao"
            enemy.name_zh = "蔡瑁"
            enemy.name_en = "Cai Mao"
            enemy.max_hp = 12
            enemy.intent_pattern = [0, 3, 2, 0]  # ATTACK, SKILL, DEFEND, ATTACK — elite admiral
        "cao_cao_boss":
            enemy.id = "cao_cao_boss"
            enemy.name_zh = "曹操"
            enemy.name_en = "Cao Cao (Boss)"
            enemy.max_hp = 25
            enemy.intent_pattern = [0, 0, 3, 2, 0, 3]  # ATTACK, ATTACK, SKILL, DEFEND, ATTACK, SKILL
        _:
            enemy.id = enemy_id
            enemy.name_zh = "敵兵"
            enemy.name_en = "Soldier"
            enemy.max_hp = 5
            enemy.intent_pattern = [0]  # ATTACK
    
    enemy.initialize()
    enemy.current_intent = enemy.intent_pattern[0]
    enemy.intent_value = _get_intent_value(enemy.current_intent, enemy_id)
    return enemy


func _get_intent_value(intent: int, enemy_id: String) -> int:
    match enemy_id:
        "yellow_turban_elite":
            return 2 if intent == 0 else 1  # ATTACK=0
        "zhang_jiao":
            return 3 if intent == 0 else (2 if intent == 3 else 1)  # ATTACK=0, SKILL=3
        "dong_zhuo_soldier":
            return 2 if intent == 0 else 1
        "dong_zhuo_crossbow":
            return 2 if intent == 0 else 1
        "road_bandit":
            return 2 if intent == 0 else 1
        "hu_lao_guard":
            return 3 if intent == 0 else (2 if intent == 3 else 1)
        "lv_bu":
            return 2 if intent == 0 else (3 if intent == 3 else 2)
        "cao_navy_soldier":
            return 2 if intent == 0 else 1
        "cao_navy_archer":
            return 2 if intent == 0 else 1
        "cao_strategist":
            return 1 if intent == 0 else (2 if intent == 3 else 1)
        "cao_iron_guard":
            return 2 if intent == 0 else (2 if intent == 3 else 1)
        "cai_mao":
            return 2 if intent == 0 else (3 if intent == 3 else 1)
        "cao_cao_boss":
            return 3 if intent == 0 else (3 if intent == 3 else 2)
        _:
            return 1


func add_gold(amount: int) -> void:
    if run_data:
        run_data.add_gold(amount)
        gold_changed.emit(run_data.gold)


func get_gold() -> int:
    return run_data.gold if run_data else 0
