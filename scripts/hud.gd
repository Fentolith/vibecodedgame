extends CanvasLayer

@onready var health_bar: TextureProgressBar = $HealthOrb
@onready var mana_bar: TextureProgressBar = $ManaOrb
@onready var stamina_bar: ProgressBar = $StaminaBar
@onready var interact_label: Label = $InteractLabel
@onready var inventory_overlay: Control = $InventoryOverlay
@onready var map_overlay: Control = $MapOverlay
@onready var esc_menu: Control = $EscMenu

func _ready() -> void:
	GameManager.player_health_changed.connect(_on_health_changed)
	GameManager.player_mana_changed.connect(_on_mana_changed)
	GameManager.player_stamina_changed.connect(_on_stamina_changed)
	interact_label.visible = false
	esc_menu.get_node("VBoxContainer/ResumeButton").pressed.connect(toggle_esc_menu)
	esc_menu.get_node("VBoxContainer/QuitButton").pressed.connect(get_tree().quit)

func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.value = (current / maximum) * 100.0

func _on_mana_changed(current: float, maximum: float) -> void:
	mana_bar.value = (current / maximum) * 100.0

func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.value = (current / maximum) * 100.0

func show_interact_prompt(text: String) -> void:
	interact_label.text = "[F] " + text
	interact_label.visible = true

func hide_interact_prompt() -> void:
	interact_label.visible = false

func toggle_inventory() -> void:
	inventory_overlay.visible = not inventory_overlay.visible
	map_overlay.visible = false
	_set_mouse_for_overlay()

func toggle_map() -> void:
	map_overlay.visible = not map_overlay.visible
	inventory_overlay.visible = false
	_set_mouse_for_overlay()

func toggle_esc_menu() -> void:
	esc_menu.visible = not esc_menu.visible
	inventory_overlay.visible = false
	map_overlay.visible = false
	_set_mouse_for_overlay()

func _set_mouse_for_overlay() -> void:
	var any_open := inventory_overlay.visible or map_overlay.visible or esc_menu.visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if any_open else Input.MOUSE_MODE_CAPTURED)
