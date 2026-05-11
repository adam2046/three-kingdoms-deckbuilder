extends Node
## CardLibrary — the complete standard 108-card 三國殺 deck.
## Provides factory methods to create CardData instances by ID or type.
## Registered as autoload so all scenes can access it.


## All 108 card definitions. Format: { id, type_key, suit, number }
## type_key maps to CardData.SubType via _type_key_to_subtype()
var _definitions: Array = []


func _ready() -> void:
	_build_definitions()


## Get a card by exact ID. Returns CardData or null.
func get_card(card_id: String) -> CardData:
	for def in _definitions:
		if def["id"] == card_id:
			return _create_from_def(def)
	return null


## Get all cards of a given SubType.
func get_cards_by_subtype(subtype: int) -> Array:
	var result: Array = []
	for def in _definitions:
		if _type_key_to_subtype(def["type_key"]) == subtype:
			result.append(_create_from_def(def))
	return result


## Get the full 108-card deck (shuffled copy).
func get_full_deck() -> Array:
	var deck: Array = []
	for def in _definitions:
		deck.append(_create_from_def(def))
	deck.shuffle()
	return deck


## Get N random cards from the pool (no duplicates).
func get_random_cards(count: int) -> Array:
	var pool: Array = _definitions.duplicate()
	pool.shuffle()
	var result: Array = []
	for i in range(min(count, pool.size())):
		result.append(_create_from_def(pool[i]))
	return result


## Get N random cards filtered by card type (BASIC, STRATEGY, etc.)
func get_random_cards_by_type(count: int, card_type: int) -> Array:
	var pool: Array = []
	for def in _definitions:
		if _type_key_to_card_type(def["type_key"]) == card_type:
			pool.append(def)
	pool.shuffle()
	var result: Array = []
	for i in range(min(count, pool.size())):
		result.append(_create_from_def(pool[i]))
	return result


## Get cards suitable for reward/shop pools (basic + strategy + equipment).
func get_reward_pool() -> Array:
	var pool: Array = []
	for def in _definitions:
		var ct := _type_key_to_card_type(def["type_key"])
		if ct == CardData.CardType.BASIC or ct == CardData.CardType.STRATEGY or ct == CardData.CardType.EQUIPMENT:
			pool.append(_create_from_def(def))
	return pool


## Get N random cards from the reward pool.
func get_random_rewards(count: int) -> Array:
	var pool := get_reward_pool()
	pool.shuffle()
	var result: Array = []
	for i in range(min(count, pool.size())):
		result.append(pool[i])
	return result


# ============================================================
#  INTERNALS
# ============================================================

func _create_from_def(def: Dictionary) -> CardData:
	var card := CardData.new()
	card.id = def["id"]
	card.suit = _suit_str_to_enum(def["suit"])
	card.number = def["number"]
	card.number_display = _number_to_display(card.number)
	card.sub_type = _type_key_to_subtype(def["type_key"])
	card.card_type = _type_key_to_card_type(def["type_key"])
	card.name_zh = _subtype_to_name_zh(card.sub_type)

	# Set effect properties based on sub_type
	match card.sub_type:
		CardData.SubType.SLASH:
			card.damage = 1
		CardData.SubType.DODGE:
			card.block = 1
		CardData.SubType.PEACH:
			card.heal = 1
		CardData.SubType.WINE:
			card.heal = 0  # Wine effect is special: next 殺 +1 damage
		CardData.SubType.DISMANTLE:
			card.discard_count = 1
		CardData.SubType.STEAL:
			card.discard_count = 1
		CardData.SubType.DRAW2:
			card.draw_count = 2
		CardData.SubType.DUEL:
			card.damage = 2
		CardData.SubType.BARBARIAN:
			card.damage = 1
		CardData.SubType.VOLLEY:
			card.damage = 2
		CardData.SubType.PEACH_GARDEN:
			card.heal = 1
		CardData.SubType.HARVEST:
			card.draw_count = 1
		CardData.SubType.LE_BUSI:
			card.damage = 0
		CardData.SubType.LIGHTNING:
			card.damage = 3
		CardData.SubType.BING_LIANG:
			card.draw_count = 0  # Skip draw phase
		CardData.SubType.WEAPON:
			card.attack_range = 1
		CardData.SubType.ARMOR:
			card.block = 1
		CardData.SubType.HORSE_PLUS:
			card.block = 0  # +1 defense range
		CardData.SubType.HORSE_MINUS:
			card.attack_range = 1  # -1 attack range cost

	return card


func _suit_str_to_enum(s: String) -> int:
	match s:
		"S": return CardData.Suit.SPADE
		"H": return CardData.Suit.HEART
		"C": return CardData.Suit.CLUB
		"D": return CardData.Suit.DIAMOND
	return CardData.Suit.SPADE


func _number_to_display(n: int) -> String:
	match n:
		1: return "A"
		11: return "J"
		12: return "Q"
		13: return "K"
		_: return str(n)


func _type_key_to_subtype(key: String) -> int:
	match key:
		"slash": return CardData.SubType.SLASH
		"dodge": return CardData.SubType.DODGE
		"peach": return CardData.SubType.PEACH
		"wine": return CardData.SubType.WINE
		"dismantle": return CardData.SubType.DISMANTLE
		"steal": return CardData.SubType.STEAL
		"draw2": return CardData.SubType.DRAW2
		"duel": return CardData.SubType.DUEL
		"barbarian": return CardData.SubType.BARBARIAN
		"volley": return CardData.SubType.VOLLEY
		"peach_garden": return CardData.SubType.PEACH_GARDEN
		"harvest": return CardData.SubType.HARVEST
		"negate": return CardData.SubType.NEGATE
		"le_busi": return CardData.SubType.LE_BUSI
		"lightning": return CardData.SubType.LIGHTNING
		"bing_liang": return CardData.SubType.BING_LIANG
		"weapon": return CardData.SubType.WEAPON
		"armor": return CardData.SubType.ARMOR
		"horse_plus": return CardData.SubType.HORSE_PLUS
		"horse_minus": return CardData.SubType.HORSE_MINUS
		"crossbow": return CardData.SubType.WEAPON  # Zhuge Crossbow is a weapon
	return CardData.SubType.SLASH


func _type_key_to_card_type(key: String) -> int:
	match key:
		"slash", "dodge", "peach", "wine":
			return CardData.CardType.BASIC
		"dismantle", "steal", "draw2", "duel", "barbarian", "volley", "peach_garden", "harvest", "negate":
			return CardData.CardType.STRATEGY
		"le_busi", "lightning", "bing_liang":
			return CardData.CardType.DELAY_STRATEGY
		"weapon", "armor", "horse_plus", "horse_minus", "crossbow":
			return CardData.CardType.EQUIPMENT
	return CardData.CardType.BASIC


func _subtype_to_name_zh(subtype: int) -> String:
	match subtype:
		CardData.SubType.SLASH: return "殺"
		CardData.SubType.DODGE: return "閃"
		CardData.SubType.PEACH: return "桃"
		CardData.SubType.WINE: return "酒"
		CardData.SubType.DISMANTLE: return "過河拆橋"
		CardData.SubType.STEAL: return "順手牽羊"
		CardData.SubType.DRAW2: return "無中生有"
		CardData.SubType.DUEL: return "決鬥"
		CardData.SubType.BARBARIAN: return "南蠻入侵"
		CardData.SubType.VOLLEY: return "萬箭齊發"
		CardData.SubType.PEACH_GARDEN: return "桃園結義"
		CardData.SubType.HARVEST: return "五穀豐登"
		CardData.SubType.NEGATE: return "無懈可擊"
		CardData.SubType.LE_BUSI: return "樂不思蜀"
		CardData.SubType.LIGHTNING: return "閃電"
		CardData.SubType.BING_LIANG: return "兵糧寸斷"
		CardData.SubType.WEAPON: return "武器"
		CardData.SubType.ARMOR: return "防具"
		CardData.SubType.HORSE_PLUS: return "+1馬"
		CardData.SubType.HORSE_MINUS: return "-1馬"
	return "?"


# ============================================================
#  THE STANDARD 108-CARD DECK
# ============================================================
# Format: { id, type_key, suit, number }
# Suit: S=Spade, H=Heart, C=Club, D=Diamond
# Number: 1=A, 2-10, 11=J, 12=Q, 13=K

func _build_definitions() -> void:
	_definitions.clear()

	# ============================================================
	#  BASIC CARDS (58 total)
	# ============================================================

	# --- 殺 (Slash) — 30 cards ---
	# Spade: 2,3,4,5,6,7,8,9,10 (9 cards)
	for n in range(2, 11):
		_add("slash", "S", n)
	# Club: 2,3,4,5,6,7,8 (7 cards)
	for n in range(2, 9):
		_add("slash", "C", n)
	# Heart: 10,10,10,11,11 (5 cards — extras for balance)
	_add("slash", "H", 10)
	_add("slash", "H", 10)  # Duplicate allowed
	_add("slash", "H", 11)
	_add("slash", "H", 11)
	# Diamond: 6,7,8,9,10,13 (6 cards)
	for n in [6, 7, 8, 9, 10, 13]:
		_add("slash", "D", n)
	# Spade: 8,9,10 (3 extra spade slashes)
	for n in [8, 9, 10]:
		_add("slash", "S", n)  # Duplicate IDs resolved below

	# --- 閃 (Dodge) — 15 cards ---
	# Heart: 2,2,13 (3 cards)
	_add("dodge", "H", 2)
	_add("dodge", "H", 2)
	_add("dodge", "H", 13)
	# Diamond: 2,2,3,4,5,6,7,8,9,10,11,12 (12 cards)
	_add("dodge", "D", 2)
	_add("dodge", "D", 2)
	for n in range(3, 13):
		_add("dodge", "D", n)

	# --- 桃 (Peach) — 8 cards ---
	# Heart: 3,4,6,7,8,9,12 (7)
	for n in [3, 4, 6, 7, 8, 9, 12]:
		_add("peach", "H", n)
	# Diamond: 12 (1)
	_add("peach", "D", 12)

	# --- 酒 (Wine) — 5 cards ---
	# Spade: 3,9 (2)
	_add("wine", "S", 3)
	_add("wine", "S", 9)
	# Club: 3,9 (2)
	_add("wine", "C", 3)
	_add("wine", "C", 9)
	# Diamond: 9 (1)
	_add("wine", "D", 9)

	# ============================================================
	#  STRATEGY CARDS (29 total)
	# ============================================================

	# --- 過河拆橋 (Dismantle) — 6 cards ---
	# Spade: 3,4,12 (3)
	_add("dismantle", "S", 3)
	_add("dismantle", "S", 4)
	_add("dismantle", "S", 12)
	# Club: 3,4,12 (3)
	_add("dismantle", "C", 3)
	_add("dismantle", "C", 4)
	_add("dismantle", "C", 12)

	# --- 順手牽羊 (Steal) — 5 cards ---
	# Spade: 3,4,11 (3)
	_add("steal", "S", 3)
	_add("steal", "S", 4)
	_add("steal", "S", 11)
	# Diamond: 3,4 (2)
	_add("steal", "D", 3)
	_add("steal", "D", 4)

	# --- 無中生有 (Draw 2) — 4 cards ---
	# Heart: 7,8,9,11 (4)
	_add("draw2", "H", 7)
	_add("draw2", "H", 8)
	_add("draw2", "H", 9)
	_add("draw2", "H", 11)

	# --- 決鬥 (Duel) — 3 cards ---
	# Spade: 1 (A)
	_add("duel", "S", 1)
	# Club: 1 (A)
	_add("duel", "C", 1)
	# Diamond: 1 (A)
	_add("duel", "D", 1)

	# --- 南蠻入侵 (Barbarian) — 3 cards ---
	# Spade: 7,13 (K)
	_add("barbarian", "S", 7)
	_add("barbarian", "S", 13)
	# Spade: 7 (duplicate)
	_add("barbarian", "S", 7)

	# --- 萬箭齊發 (Volley) — 1 card ---
	# Heart: 1 (A)
	_add("volley", "H", 1)

	# --- 桃園結義 (Peach Garden) — 1 card ---
	# Heart: 1 (A)
	_add("peach_garden", "H", 1)

	# --- 五穀豐登 (Harvest) — 2 cards ---
	# Heart: 3,4
	_add("harvest", "H", 3)
	_add("harvest", "H", 4)

	# --- 無懈可擊 (Negate) — 4 cards ---
	# Spade: 11 (J)
	_add("negate", "S", 11)
	# Club: 12 (Q)
	_add("negate", "C", 12)
	# Diamond: 12 (Q)
	_add("negate", "D", 12)
	# Diamond: 13 (K)
	_add("negate", "D", 13)

	# ============================================================
	#  DELAY STRATEGY CARDS (6 total)
	# ============================================================

	# --- 樂不思蜀 (Le Busi) — 2 cards ---
	# Heart: 6
	_add("le_busi", "H", 6)
	# Spade: 6
	_add("le_busi", "S", 6)

	# --- 閃電 (Lightning) — 2 cards ---
	# Spade: 1 (A)
	_add("lightning", "S", 1)
	# Heart: 12 (Q)
	_add("lightning", "H", 12)

	# --- 兵糧寸斷 (Bing Liang) — 2 cards ---
	# Spade: 10
	_add("bing_liang", "S", 10)
	# Club: 10
	_add("bing_liang", "C", 10)

	# ============================================================
	#  EQUIPMENT CARDS (16 total)
	# ============================================================

	# --- 武器 (Weapons) — 8 cards ---
	# 諸葛連弩 (Crossbow): Club 1(A), Diamond 1(A)
	_add("crossbow", "C", 1)
	_add("crossbow", "D", 1)
	# 青釭劍 (Qinggang Sword): Spade 6
	_add("weapon", "S", 6)
	# 雌雄雙股劍: Spade 2
	_add("weapon", "S", 2)
	# 青龍偃月刀 (Green Dragon Blade): Spade 5
	_add("weapon", "S", 5)
	# 丈八蛇矛: Spade 12(Q)
	_add("weapon", "S", 12)
	# 貫石斧: Diamond 5
	_add("weapon", "D", 5)
	# 方天畫戟: Diamond 12(Q)
	_add("weapon", "D", 12)
	# 麒麟弓: Heart 5
	_add("weapon", "H", 5)

	# --- 防具 (Armor) — 2 cards ---
	# 八卦陣: Spade 2
	_add("armor", "S", 2)
	# 仁王盾: Club 2
	_add("armor", "C", 2)

	# --- +1馬 (Horse Plus / Defense) — 3 cards ---
	# 爪黃飛電: Heart 13(K)
	_add("horse_plus", "H", 13)
	# 的盧: Club 5
	_add("horse_plus", "C", 5)
	# 絕影: Spade 5
	_add("horse_plus", "S", 5)

	# --- -1馬 (Horse Minus / Attack) — 3 cards ---
	# 赤兔: Heart 5
	_add("horse_minus", "H", 5)
	# 大宛: Spade 13(K)
	_add("horse_minus", "S", 13)
	# 紫騂: Diamond 13(K)
	_add("horse_minus", "D", 13)

	# Deduplicate IDs: append counter for duplicate type+suit+number combos
	_deduplicate_ids()


func _add(type_key: String, suit: String, number: int) -> void:
	_definitions.append({
		"id": "%s_%s_%d" % [type_key, suit, number],
		"type_key": type_key,
		"suit": suit,
		"number": number,
	})


func _deduplicate_ids() -> void:
	## Append _N suffix for duplicate IDs to keep them unique.
	var seen: Dictionary = {}
	for def in _definitions:
		var base_id: String = def["id"]
		if seen.has(base_id):
			seen[base_id] += 1
			def["id"] = "%s_%d" % [base_id, seen[base_id]]
		else:
			seen[base_id] = 1


func get_count() -> int:
	return _definitions.size()
