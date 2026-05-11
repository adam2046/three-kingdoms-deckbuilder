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
