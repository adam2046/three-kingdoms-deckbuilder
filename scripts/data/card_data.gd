extends Resource
class_name CardData

## Card Data Resource — defines one card in the game.
## Cards follow the 三國殺 108-card standard library structure.

# -- Card Identity --
@export var id: String                    # e.g. "slash_spade_7"
@export var name_zh: String              # e.g. "殺"
@export var name_en: String              # e.g. "Slash"

# -- Suit & Number (三國殺 standard) --
enum Suit { SPADE, HEART, CLUB, DIAMOND }
@export var suit: Suit                   # ♠♡♣♢
@export var number: int = 1             # 1-13 (A=1, J=11, Q=12, K=13)
@export var number_display: String = "A" # "A","2"-"10","J","Q","K"

# -- Card Type --
enum CardType { BASIC, STRATEGY, EQUIPMENT, DELAY_STRATEGY }
@export var card_type: CardType

# -- Sub-type --
enum SubType {
    SLASH, DODGE, PEACH, WINE,             # Basic
    DISMANTLE, STEAL, DRAW2, DUEL,          # Strategy
    BARBARIAN, VOLLEY, PEACH_GARDEN, HARVEST, NEGATE,  # Strategy
    LE_BUSI, LIGHTNING, BING_LIANG,         # Delay Strategy
    WEAPON, ARMOR, HORSE_PLUS, HORSE_MINUS  # Equipment
}
@export var sub_type: SubType

# -- Rarity (Roguelike layer) --
enum Rarity { COMMON, RARE, EPIC, LEGENDARY }
@export var rarity: Rarity = Rarity.COMMON

# -- Effect --
@export_multiline var effect_zh: String   # Chinese description
@export_multiline var effect_en: String   # English description

# -- Numeric properties --
@export var damage: int = 0              # Base damage (for 殺, 決鬥, etc.)
@export var block: int = 0               # Base block (for 閃)
@export var heal: int = 0                # Healing amount (for 桃, 酒)
@export var draw_count: int = 0          # Cards to draw (for 無中生有, 英姿)
@export var attack_range: int = 1        # Range for weapons
@export var discard_count: int = 0       # Cards to discard (for 過河拆橋)

# -- Upgraded version --
@export var upgraded_version: CardData   # Reference to upgraded card

# -- Helpers --
func is_red() -> bool:
    return suit == Suit.HEART or suit == Suit.DIAMOND

func is_black() -> bool:
    return suit == Suit.SPADE or suit == Suit.CLUB

func suit_symbol() -> String:
    match suit:
        Suit.SPADE: return "♠"
        Suit.HEART: return "♡"
        Suit.CLUB: return "♣"
        Suit.DIAMOND: return "♢"
    return "?"

func can_play_as(sub_type_target: SubType) -> bool:
    ## Check if this card can be used as a different sub-type
    ## (Used by hero abilities like 武聖, 龍膽, 奇襲, 傾國, 國色, 急救)
    return false  # Base cards can't; hero abilities override this logic
