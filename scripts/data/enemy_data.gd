extends Resource
class_name EnemyData

## Enemy Data — defines one enemy in battle.

@export var id: String
@export var name_zh: String
@export var name_en: String
@export var max_hp: int = 3
@export var attack_range: int = 1

# -- Skills (elites and bosses may have hero-like skills) --
@export var skills: Array[String] = []  # Skill IDs

# -- AI Intent pattern --
enum Intent { ATTACK, DEFEND, BUFF, SKILL }
@export var intent_pattern: Array = [Intent.ATTACK]  # Default: attack every turn

# -- Current state (runtime) --
var current_hp: int
var current_intent: Intent
var intent_value: int = 1  # e.g. damage amount for ATTACK, block amount for DEFEND

func initialize() -> void:
    current_hp = max_hp

func take_damage(amount: int) -> bool:
    current_hp = max(0, current_hp - amount)
    return current_hp <= 0

func heal(amount: int) -> void:
    current_hp = min(current_hp + amount, max_hp)

func is_alive() -> bool:
    return current_hp > 0

func next_intent(turn: int) -> int:
    ## Cycle through intent pattern or use skill AI
    var idx: int = (turn - 1) % intent_pattern.size()
    return intent_pattern[idx]
