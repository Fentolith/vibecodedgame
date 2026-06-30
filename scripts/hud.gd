extends CanvasLayer

@onready var health_bar:        Control = $HealthOrb
@onready var mana_bar:          Control = $ManaOrb
@onready var stamina_bar:       ProgressBar        = $StaminaBar
@onready var interact_label:    Label              = $InteractLabel
@onready var inventory_overlay: Control            = $InventoryOverlay
@onready var map_overlay:       Control            = $MapOverlay
@onready var esc_menu:          Control            = $EscMenu
@onready var hungry_moodle:     Label              = $MoodleContainer/HungryMoodle
@onready var thirsty_moodle:    Label              = $MoodleContainer/ThirstyMoodle
@onready var death_screen:      Control            = $DeathScreen
@onready var player_info:       Control            = $PlayerInfoOverlay
@onready var dev_tools_menu:    Control            = $DevToolsMenu
@onready var controls_menu:     Control            = $ControlsMenu
@onready var loot_overlay:      Control            = $LootOverlay

func _ready() -> void:
	GameManager.player_health_changed.connect(_on_health_changed)
	GameManager.player_mana_changed.connect(_on_mana_changed)
	GameManager.player_stamina_changed.connect(_on_stamina_changed)
	GameManager.player_needs_changed.connect(_on_needs_changed)
	GameManager.player_died.connect(_on_player_died)
	GameManager.loot_bag_opened.connect(_on_loot_bag_opened)

	interact_label.visible = false
	esc_menu.get_node("VBoxContainer/ResumeButton").pressed.connect(toggle_esc_menu)
	esc_menu.get_node("VBoxContainer/QuitButton").pressed.connect(get_tree().quit)
	death_screen.get_node("VBoxContainer/RestartButton").pressed.connect(_on_restart)
	death_screen.get_node("VBoxContainer/QuitButton").pressed.connect(get_tree().quit)
	esc_menu.get_node("VBoxContainer/ControlsButton").pressed.connect(_open_controls)
	esc_menu.get_node("VBoxContainer/DevToolsButton").pressed.connect(_open_dev_tools)
	controls_menu.get_node("Panel/VBox/CloseButton").pressed.connect(_close_controls)
	dev_tools_menu.get_node("Panel/VBoxContainer/ZeroHungerButton").pressed.connect(_dev_zero_hunger)
	dev_tools_menu.get_node("Panel/VBoxContainer/ZeroThirstButton").pressed.connect(_dev_zero_thirst)
	dev_tools_menu.get_node("Panel/VBoxContainer/FullHealButton").pressed.connect(_dev_full_heal)
	dev_tools_menu.get_node("Panel/VBoxContainer/ZeroHPButton").pressed.connect(_dev_zero_hp)
	dev_tools_menu.get_node("Panel/VBoxContainer/CloseButton").pressed.connect(_close_dev_tools)

func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.set_value(current, maximum)

func _on_mana_changed(current: float, maximum: float) -> void:
	mana_bar.set_value(current, maximum)

func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.value = (current / maximum) * 100.0

func _on_needs_changed(need: String, is_active: bool) -> void:
	if need == "hungry":
		hungry_moodle.visible = is_active
	elif need == "thirsty":
		thirsty_moodle.visible = is_active

func _on_loot_bag_opened(bag: Node) -> void:
	_close_all_overlays()
	loot_overlay.open_bag(bag)
	loot_overlay.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_player_died() -> void:
	_close_all_overlays()
	death_screen.visible = true

func _on_restart() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func show_interact_prompt(text: String) -> void:
	interact_label.text    = "[F] " + text
	interact_label.visible = true

func hide_interact_prompt() -> void:
	interact_label.visible = false

func toggle_inventory() -> void:
	var opening := not inventory_overlay.visible
	_close_all_overlays()
	inventory_overlay.visible = opening
	_set_mouse_for_overlay()

func toggle_map() -> void:
	var opening := not map_overlay.visible
	_close_all_overlays()
	map_overlay.visible = opening
	_set_mouse_for_overlay()

func toggle_esc_menu() -> void:
	var opening := not esc_menu.visible
	_close_all_overlays()
	esc_menu.visible = opening
	_set_mouse_for_overlay()

func toggle_player_info() -> void:
	var opening := not player_info.visible
	_close_all_overlays()
	player_info.visible = opening
	_set_mouse_for_overlay()

func _open_controls() -> void:
	esc_menu.visible      = false
	controls_menu.visible = true

func _close_controls() -> void:
	controls_menu.visible = false
	esc_menu.visible      = true

func _open_dev_tools() -> void:
	esc_menu.visible      = false
	dev_tools_menu.visible = true

func _close_dev_tools() -> void:
	dev_tools_menu.visible = false
	esc_menu.visible       = true

func _dev_zero_hunger() -> void:
	var p: Node = GameManager.player_node
	if not p:
		return
	p.hunger    = 0.0
	p.is_hungry = true
	GameManager.player_needs_changed.emit("hungry", true)

func _dev_zero_thirst() -> void:
	var p: Node = GameManager.player_node
	if not p:
		return
	p.thirst     = 0.0
	p.is_thirsty = true
	GameManager.player_needs_changed.emit("thirsty", true)

func _dev_full_heal() -> void:
	var p: Node = GameManager.player_node
	if p:
		p.heal(p.max_health)

func _dev_zero_hp() -> void:
	var p: Node = GameManager.player_node
	if p:
		p.take_damage(p.max_health)

func _close_all_overlays() -> void:
	inventory_overlay.visible  = false
	map_overlay.visible        = false
	esc_menu.visible           = false
	player_info.visible        = false
	dev_tools_menu.visible     = false
	controls_menu.visible      = false
	loot_overlay.visible       = false

func _set_mouse_for_overlay() -> void:
	var any_open := inventory_overlay.visible or map_overlay.visible \
		or esc_menu.visible or player_info.visible or loot_overlay.visible
	Input.set_mouse_mode(
		Input.MOUSE_MODE_VISIBLE if any_open else Input.MOUSE_MODE_CAPTURED
	)
