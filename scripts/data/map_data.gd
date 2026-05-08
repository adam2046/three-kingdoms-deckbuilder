extends Resource
class_name MapData

## MapData — defines the roguelike map structure.
## Zones contain a sequence of nodes. Nodes define what happens at each step.

# -- Node Types --
enum NodeType { START, BATTLE, CAMPFIRE, ELITE, BOSS, SHOP, EVENT }

# -- Zone Definition --
class ZoneDef:
	var id: String
	var name_zh: String
	var name_en: String
	var nodes: Array        # Array of NodeDef
	var boss_id: String     # EnemyData ID for the boss

	func _init(p_id: String, p_name_zh: String, p_name_en: String, p_nodes: Array, p_boss_id: String):
		id = p_id
		name_zh = p_name_zh
		name_en = p_name_en
		nodes = p_nodes
		boss_id = p_boss_id


# -- Node Definition --
class NodeDef:
	var type: NodeType
	var enemy_pool: Array[String] = []  # EnemyData IDs for Battle/Elite nodes
	var label_zh: String
	var label_en: String

	func _init(p_type: NodeType, p_label_zh: String = "", p_label_en: String = "", p_enemy_pool: Array[String] = []):
		type = p_type
		label_zh = p_label_zh
		label_en = p_label_en
		enemy_pool = p_enemy_pool


# ============================================================
#  ZONE DEFINITIONS
# ============================================================

## Zone 1: 黃巾之亂 (Yellow Turban Rebellion)
static func zone_1() -> ZoneDef:
	var nodes: Array = []
	nodes.append(NodeDef.new(NodeType.START, "起點", "Start"))
	nodes.append(NodeDef.new(NodeType.BATTLE, "遭遇戰", "Skirmish", ["yellow_turban_soldier"]))
	nodes.append(NodeDef.new(NodeType.SHOP, "商店", "Shop"))
	nodes.append(NodeDef.new(NodeType.CAMPFIRE, "營火", "Campfire"))
	nodes.append(NodeDef.new(NodeType.ELITE, "黃巾精銳", "Elite Guard", ["yellow_turban_elite"]))
	nodes.append(NodeDef.new(NodeType.EVENT, "事件", "Event"))
	nodes.append(NodeDef.new(NodeType.BOSS, "張角", "Zhang Jiao", ["zhang_jiao"]))
	return ZoneDef.new("zone_1", "黃巾之亂", "Yellow Turban Rebellion", nodes, "zhang_jiao")


## All zones in order
static func all_zones() -> Array[ZoneDef]:
	return [zone_1()]


## Get a zone by index
static func get_zone(index: int) -> ZoneDef:
	var zones := all_zones()
	if index >= 0 and index < zones.size():
		return zones[index]
	return null
