extends Control
## Main Menu — entry point for the game.
## Start → Hero Select → Battle

@onready var start_btn: Button = $StartBtn
@onready var quit_btn: Button = $QuitBtn

func _ready() -> void:
	start_btn.pressed.connect(_on_start)
	quit_btn.pressed.connect(_on_quit)

func _on_start() -> void:
	# Transition to hero select screen
	get_tree().change_scene_to_file("res://scenes/menu/hero_select.tscn")

func _on_quit() -> void:
	get_tree().quit()