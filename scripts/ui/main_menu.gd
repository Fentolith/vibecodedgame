extends Control

@onready var start_button:    Button = $CenterContainer/VBoxContainer/StartButton
@onready var continue_button: Button = $CenterContainer/VBoxContainer/ContinueButton
@onready var quit_button:     Button = $CenterContainer/VBoxContainer/QuitButton

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	start_button.pressed.connect(_on_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	continue_button.visible = FileAccess.file_exists("user://save.json")

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/character_creation.tscn")

func _on_continue_pressed() -> void:
	if GameManager.load_game():
		get_tree().change_scene_to_file("res://scenes/levels/dungeon.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
