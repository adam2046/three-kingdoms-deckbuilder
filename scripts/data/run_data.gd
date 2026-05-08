extends Resource
class_name RunData

## RunData — tracks persistent state across a roguelike run.
## One instance per run, survives between battles.

# -- Currency --
@export var gold: int = 0

# -- Progression --
@export var current_zone: int = 0          # Index into zone list
@export var current_node: int = 0          # Index into current zone's node sequence
@export var zones_cleared: int = 0

# -- Meta --
@export var run_seed: int = 0
@export var total_battles_won: int = 0

# -- Relics (passive items) --
@export var relics: Array[String] = []     # Relic IDs

# -- Helpers --
func add_gold(amount: int) -> void:
    gold += amount

func spend_gold(amount: int) -> bool:
    if gold >= amount:
        gold -= amount
        return true
    return false

func advance_node() -> void:
    current_node += 1

func advance_zone() -> void:
    current_zone += 1
    current_node = 0
    zones_cleared += 1
