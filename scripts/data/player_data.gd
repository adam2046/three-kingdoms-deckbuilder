extends Node
## Global singleton for persisting data between scenes (hero choice, run state).
## Add to Project Settings → Autoload as "PlayerData".

var chosen_hero_id: String = "lv_bu"  # Default hero for testing