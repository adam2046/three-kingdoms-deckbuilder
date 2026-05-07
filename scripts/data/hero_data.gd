extends Resource
class_name HeroData

## Hero Data Resource — defines one playable hero.

# -- Identity --
@export var id: String                    # e.g. "cao_cao"
@export var name_zh: String              # e.g. "曹操"
@export var name_en: String              # e.g. "Cao Cao"
@export var title_zh: String             # e.g. "魏武帝"
@export var title_en: String             # e.g. "Emperor Wu of Wei"

# -- Faction --
enum Faction { WEI, SHU, WU, QUN }
@export var faction: Faction

# -- Archetype --
enum Archetype { ATTACK, BALANCED, SUPPORT }
@export var archetype: Archetype = Archetype.BALANCED

# -- Stats --
@export var max_hp: int = 4
@export var base_attack_range: int = 1

# -- Skills --
@export var skill_1_name_zh: String       # e.g. "奸雄"
@export var skill_1_name_en: String
@export_multiline var skill_1_desc_zh: String
@export_multiline var skill_1_desc_en: String

@export var skill_1_has_fallback: bool = false  # Support-only: self-use when no follower
@export_multiline var skill_1_fallback_zh: String
@export_multiline var skill_1_fallback_en: String

@export var skill_2_name_zh: String       # Some heroes have a second skill
@export var skill_2_name_en: String
@export_multiline var skill_2_desc_zh: String
@export_multiline var skill_2_desc_en: String

@export var skill_2_has_fallback: bool = false
@export_multiline var skill_2_fallback_zh: String
@export_multiline var skill_2_fallback_en: String

# -- Starting Deck --
@export var starting_deck: Array[String] = []  # Card IDs for starting deck

# -- Unlock --
@export var is_starter: bool = false     # Unlocked from the beginning
@export var unlock_condition_zh: String  # How to unlock this hero
@export var unlock_condition_en: String

# -- Helpers --
func faction_name_zh() -> String:
    match faction:
        Faction.WEI: return "魏"
        Faction.SHU: return "蜀"
        Faction.WU: return "吳"
        Faction.QUN: return "群"
    return "?"

func archetype_name_zh() -> String:
    match archetype:
        Archetype.ATTACK: return "攻擊型"
        Archetype.BALANCED: return "均衡型"
        Archetype.SUPPORT: return "支援型"
    return "?"

func has_second_skill() -> bool:
    return not skill_2_name_zh.is_empty()
