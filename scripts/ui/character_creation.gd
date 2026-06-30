extends Control

@onready var fighter_button: Button = $CenterContainer/VBoxContainer/ClassRow/FighterButton
@onready var thief_button: Button = $CenterContainer/VBoxContainer/ClassRow/ThiefButton
@onready var wizard_button: Button = $CenterContainer/VBoxContainer/ClassRow/WizardButton
@onready var name_edit: LineEdit = $CenterContainer/VBoxContainer/NameEdit
@onready var stats_label: Label = $CenterContainer/VBoxContainer/StatsLabel
@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton

var selected_class: String = ""
var class_buttons: Dictionary

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	class_buttons = {
		"fighter": fighter_button,
		"thief": thief_button,
		"wizard": wizard_button,
	}

	fighter_button.pressed.connect(_on_class_selected.bind("fighter"))
	thief_button.pressed.connect(_on_class_selected.bind("thief"))
	wizard_button.pressed.connect(_on_class_selected.bind("wizard"))
	name_edit.text_changed.connect(_on_name_changed)
	start_button.pressed.connect(_on_start_pressed)

	stats_label.text = "Select a class to see starting stats."
	_update_start_button_enabled()

func _on_class_selected(class_id: String) -> void:
	selected_class = class_id
	for id: String in class_buttons:
		class_buttons[id].disabled = (id == selected_class)
	_refresh_stats_display()
	_update_start_button_enabled()

func _refresh_stats_display() -> void:
	var stats: Dictionary = GameManager.CLASS_STATS[selected_class]
	stats_label.text = "Health: %d   STR: %d   DEX: %d   CON: %d   Magic: %d" % [
		stats["health"], stats["strength"], stats["dexterity"], stats["constitution"], stats["magic"]
	]

func _on_name_changed(_new_text: String) -> void:
	_update_start_button_enabled()

func _update_start_button_enabled() -> void:
	var has_name := name_edit.text.strip_edges() != ""
	var has_class := selected_class != ""
	start_button.disabled = not (has_name and has_class)

func _on_start_pressed() -> void:
	GameManager.player_name = name_edit.text.strip_edges()
	GameManager.selected_class = selected_class
	get_tree().change_scene_to_file("res://scenes/levels/test_dungeon.tscn")
