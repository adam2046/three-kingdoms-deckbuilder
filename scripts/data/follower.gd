extends Resource
class_name Follower

## Follower/Ally — the single ally companion in battle.
## Max 1 follower at a time. Support heroes rely on them.

@export var hp: int = 3
@export var max_hp: int = 3
@export var name_zh: String = ""
@export var name_en: String = ""
@export_multiline var passive_desc: String = ""
@export var skill_id: String = ""        # If a hero summoned via 三顧茅廬
@export var can_block: bool = false      # 護衛 type: can take hits for player

func take_damage(amount: int) -> bool:
    hp = max(0, hp - amount)
    return hp <= 0  # Returns true if follower dies

func heal(amount: int) -> void:
    hp = min(hp + amount, max_hp)

func is_alive() -> bool:
    return hp > 0
