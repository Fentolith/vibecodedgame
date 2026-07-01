extends Control

@onready var fighter_button:  Button        = $CenterContainer/VBoxContainer/ClassRow/FighterButton
@onready var thief_button:    Button        = $CenterContainer/VBoxContainer/ClassRow/ThiefButton
@onready var wizard_button:   Button        = $CenterContainer/VBoxContainer/ClassRow/WizardButton
@onready var name_edit:       LineEdit      = $CenterContainer/VBoxContainer/NameEdit
@onready var stats_label:     Label         = $CenterContainer/VBoxContainer/StatsLabel
@onready var desc_label:      Label         = $CenterContainer/VBoxContainer/DescLabel
@onready var start_button:    Button        = $CenterContainer/VBoxContainer/StartButton

var selected_class: String = ""
var class_buttons: Dictionary

const CLASS_DESCRIPTIONS := {
	"fighter": "A seasoned warrior forged in battle. Tough and relentless — can take punishment and dish it back harder. Starts with higher health and strength.",
	"thief":   "A nimble rogue who strikes from the shadows. Exceptional dexterity lets them dodge, pick locks, and land quick precise blows before vanishing.",
	"wizard":  "A scholar of the arcane arts. Devastatingly powerful magic but a frail body. Keep your distance and never let enemies close the gap.",
}

const CLASS_COLORS := {
	"fighter": Color(0.90, 0.55, 0.15, 1.0),
	"thief":   Color(0.30, 0.85, 0.50, 1.0),
	"wizard":  Color(0.55, 0.35, 1.00, 1.0),
}

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	class_buttons = {
		"fighter": fighter_button,
		"thief":   thief_button,
		"wizard":  wizard_button,
	}

	fighter_button.pressed.connect(_on_class_selected.bind("fighter"))
	thief_button.pressed.connect(_on_class_selected.bind("thief"))
	wizard_button.pressed.connect(_on_class_selected.bind("wizard"))
	name_edit.text_changed.connect(_on_name_changed)
	start_button.pressed.connect(_on_start_pressed)

	stats_label.text = ""
	desc_label.text  = "Choose your class above."
	_update_start_button_enabled()

func _on_class_selected(class_id: String) -> void:
	selected_class = class_id
	for id: String in class_buttons:
		var btn: Button = class_buttons[id]
		btn.disabled = (id == selected_class)
		btn.modulate = CLASS_COLORS[id] if id == selected_class else Color.WHITE
	_refresh_stats_display()
	_update_start_button_enabled()

func _refresh_stats_display() -> void:
	var s: Dictionary = GameManager.CLASS_STATS[selected_class]
	var col: Color    = CLASS_COLORS[selected_class]

	stats_label.modulate = col
	stats_label.text = (
		"HP %d   STR %d   DEX %d   CON %d   Magic %d" % [
			s["health"], s["strength"], s["dexterity"], s["constitution"], s["magic"]
		]
	)
	desc_label.text = CLASS_DESCRIPTIONS[selected_class]

func _on_name_changed(_new_text: String) -> void:
	_update_start_button_enabled()

func _update_start_button_enabled() -> void:
	var has_name:  bool = name_edit.text.strip_edges() != ""
	var has_class: bool = selected_class != ""
	start_button.disabled = not (has_name and has_class)

func _on_start_pressed() -> void:
	GameManager.player_name    = name_edit.text.strip_edges()
	GameManager.selected_class = selected_class
	get_tree().change_scene_to_file("res://scenes/levels/dungeon.tscn")
