extends Resource
class_name Follower

## Follower/Ally — the single ally companion in battle.
## Max 1 follower at a time. Support heroes rely on them.

# -- Follower type enum --
enum FollowerType {
	VOLUNTEER,    # 義勇兵 — generic, 1 dmg/turn
	GUARDIAN,     # 護衛 — can block for player
	SCOUT,        # 斥候 — draws 1 card/turn
	STRATEGIST,   # 謀士 — +1 energy every 3 turns
	MEDIC,        # 醫者 — heals 1 HP/turn
}

@export var follower_type: FollowerType = FollowerType.VOLUNTEER
@export var hp: int = 3
@export var max_hp: int = 3
@export var name_zh: String = ""
@export var name_en: String = ""
@export_multiline var passive_desc: String = ""
@export var skill_id: String = ""        # If a hero summoned via 三顧茅廬
@export var can_block: bool = false      # 護衛 type: can take hits for player
@export var attack_power: int = 1        # Damage dealt per turn
@export var turns_since_special: int = 0 # Counter for special ability cooldowns

var is_active: bool = true  # Whether follower acts this turn

func take_damage(amount: int) -> bool:
	hp = max(0, hp - amount)
	return hp <= 0  # Returns true if follower dies

func heal(amount: int) -> void:
	hp = min(hp + amount, max_hp)

func is_alive() -> bool:
	return hp > 0

## Create a follower from a type template.
static func create(type: FollowerType) -> Follower:
	var f := Follower.new()
	f.follower_type = type
	match type:
		FollowerType.VOLUNTEER:
			f.name_zh = "義勇兵"
			f.name_en = "Volunteer"
			f.hp = 3
			f.max_hp = 3
			f.attack_power = 1
			f.can_block = false
			f.passive_desc = "每回合對隨機敵人造成1點傷害"
		FollowerType.GUARDIAN:
			f.name_zh = "護衛"
			f.name_en = "Guardian"
			f.hp = 5
			f.max_hp = 5
			f.attack_power = 1
			f.can_block = true
			f.passive_desc = "可替玩家擋傷; 每回合造成1點傷害"
		FollowerType.SCOUT:
			f.name_zh = "斥候"
			f.name_en = "Scout"
			f.hp = 2
			f.max_hp = 2
			f.attack_power = 0
			f.can_block = false
			f.passive_desc = "每回合抽1張牌"
		FollowerType.STRATEGIST:
			f.name_zh = "謀士"
			f.name_en = "Strategist"
			f.hp = 3
			f.max_hp = 3
			f.attack_power = 0
			f.can_block = false
			f.passive_desc = "每3回合獲得1點能量"
		FollowerType.MEDIC:
			f.name_zh = "醫者"
			f.name_en = "Medic"
			f.hp = 3
			f.max_hp = 3
			f.attack_power = 0
			f.can_block = false
			f.passive_desc = "每回合回復1點體力"
	return f

## Follower shop cost by type.
static func get_cost(type: FollowerType) -> int:
	match type:
		FollowerType.VOLUNTEER:
			return 8
		FollowerType.GUARDIAN:
			return 12
		FollowerType.SCOUT:
			return 10
		FollowerType.STRATEGIST:
			return 15
		FollowerType.MEDIC:
			return 10
		_:
			return 8

## Execute the follower's per-turn passive action. Called at start of enemy turn.
func execute_passive(battle_manager) -> void:
	# battle_manager: BattleManager — passed as untyped to avoid circular deps
	if not is_alive():
		return
	turns_since_special += 1
	match follower_type:
		FollowerType.VOLUNTEER:
			_attack_random_enemy(battle_manager)
		FollowerType.GUARDIAN:
			_attack_random_enemy(battle_manager)
		FollowerType.SCOUT:
			battle_manager.draw_cards(1)
		FollowerType.STRATEGIST:
			if turns_since_special >= 3:
				battle_manager.energy += 1
				turns_since_special = 0
		FollowerType.MEDIC:
			battle_manager.player_hp = min(battle_manager.player_hp + 1, battle_manager.player_max_hp)

func _attack_random_enemy(battle_manager) -> void:
	if battle_manager.enemies.size() == 0:
		return
	var idx: int = randi() % battle_manager.enemies.size()
	var enemy = battle_manager.enemies[idx]
	enemy.current_hp -= attack_power
	if enemy.current_hp <= 0:
		enemy.current_hp = 0

## Reset per-turn state.
func reset_turn() -> void:
	is_active = true