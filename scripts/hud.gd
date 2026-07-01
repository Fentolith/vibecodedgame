extends CanvasLayer

@onready var health_bar:        Control     = $HealthOrb
@onready var mana_bar:          Control     = $ManaOrb
@onready var stamina_bar:       ProgressBar = $StaminaBar
@onready var xp_bar:            ProgressBar = $XPBar
@onready var level_label:       Label       = $LevelLabel
@onready var level_up_label:    Label       = $LevelUpLabel
@onready var interact_label:    Label       = $InteractLabel
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
@onready var floor_label:       Label              = $FloorLabel
@onready var moodle_container:  VBoxContainer      = $MoodleContainer
@onready var health_screen:     Control            = $HealthScreen
@onready var bank_overlay:      Control            = $BankOverlay
@onready var shop_overlay:      Control            = $ShopOverlay

var _effect_moodles: Dictionary = {}   # effect_id -> Label
var _floor_transition: Control = null
var _lockpick_ring: Control  = null
var _lockpick_progress: float = 0.0
var _lp_msg_label: Label     = null

func _ready() -> void:
	_build_floor_transition()
	_build_lockpick_ring()
	GameManager.floor_transition_started.connect(_on_floor_transition_started)
	GameManager.player_health_changed.connect(_on_health_changed)
	GameManager.player_mana_changed.connect(_on_mana_changed)
	GameManager.player_stamina_changed.connect(_on_stamina_changed)
	GameManager.player_needs_changed.connect(_on_needs_changed)
	GameManager.player_died.connect(_on_player_died)
	GameManager.loot_bag_opened.connect(_on_loot_bag_opened)
	GameManager.player_xp_changed.connect(_on_xp_changed)
	GameManager.player_leveled_up.connect(_on_leveled_up)
	GameManager.status_effect_changed.connect(_on_effect_changed)
	GameManager.bank_opened.connect(_on_bank_opened)
	GameManager.shop_opened.connect(_on_shop_opened)
	level_up_label.visible = false
	floor_label.text = "Floor %d" % (GameManager.current_floor + 1)

	interact_label.visible = false
	esc_menu.get_node("VBoxContainer/ResumeButton").pressed.connect(toggle_esc_menu)
	esc_menu.get_node("VBoxContainer/SaveButton").pressed.connect(GameManager.save_game)
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
	dev_tools_menu.get_node("Panel/VBoxContainer/SpawnLockedChestButton").pressed.connect(_dev_spawn_locked_chest)
	dev_tools_menu.get_node("Panel/VBoxContainer/CloseButton").pressed.connect(_close_dev_tools)

func _build_floor_transition() -> void:
	_floor_transition = Control.new()
	_floor_transition.set_anchors_preset(Control.PRESET_FULL_RECT)
	_floor_transition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floor_transition.visible      = false

	var bg       := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color     = Color(0.0, 0.0, 0.0, 0.94)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floor_transition.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left   = -240
	vbox.offset_right  =  240
	vbox.offset_top    = -90
	vbox.offset_bottom =  90
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floor_transition.add_child(vbox)

	var floor_lbl := Label.new()
	floor_lbl.name = "FloorLabel"
	floor_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floor_lbl.add_theme_font_size_override("font_size", 54)
	floor_lbl.modulate = Color(1.0, 0.88, 0.28, 1)
	floor_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(floor_lbl)

	var kills_lbl := Label.new()
	kills_lbl.name = "KillsLabel"
	kills_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kills_lbl.add_theme_font_size_override("font_size", 19)
	kills_lbl.modulate = Color(0.78, 0.78, 0.80, 1)
	kills_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(kills_lbl)

	var hint_lbl := Label.new()
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.add_theme_font_size_override("font_size", 13)
	hint_lbl.modulate = Color(0.50, 0.50, 0.52, 1)
	hint_lbl.text = "Descending..."
	hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hint_lbl)

	add_child(_floor_transition)

func _on_floor_transition_started(next_floor: int, kills: int) -> void:
	if not _floor_transition:
		return
	_close_all_overlays()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_floor_transition.get_node("VBoxContainer/FloorLabel").text = "FLOOR  %d" % next_floor
	_floor_transition.get_node("VBoxContainer/KillsLabel").text = "Enemies slain this floor: %d" % kills
	_floor_transition.modulate.a = 0.0
	_floor_transition.visible    = true

	var tw := create_tween()
	tw.tween_property(_floor_transition, "modulate:a", 1.0, 0.55).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.80)
	tw.tween_callback(func(): GameManager.do_floor_change())

func _build_lockpick_ring() -> void:
	# Invisible drawing canvas centered on screen
	_lockpick_ring = Control.new()
	_lockpick_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lockpick_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lockpick_ring.visible      = false
	_lockpick_ring.draw.connect(_draw_lockpick_ring)
	add_child(_lockpick_ring)

	_lp_msg_label = Label.new()
	_lp_msg_label.set_anchors_preset(Control.PRESET_CENTER)
	_lp_msg_label.offset_left   = -200
	_lp_msg_label.offset_right  =  200
	_lp_msg_label.offset_top    =  60
	_lp_msg_label.offset_bottom =  90
	_lp_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lp_msg_label.add_theme_font_size_override("font_size", 22)
	_lp_msg_label.modulate = Color(1.0, 0.2, 0.2, 0.0)
	_lp_msg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lp_msg_label)

func _draw_lockpick_ring() -> void:
	if not _lockpick_ring or not _lockpick_ring.visible:
		return
	var center: Vector2 = _lockpick_ring.get_rect().size * 0.5
	var radius: float   = 38.0
	var thick:  float   = 8.0
	# Background ring
	_lockpick_ring.draw_arc(center, radius, 0.0, TAU, 64,
		Color(0.0, 0.0, 0.0, 0.55), thick, true)
	# Fill arc
	if _lockpick_progress > 0.0:
		var end_a: float = -PI * 0.5 + TAU * _lockpick_progress
		var col: Color
		if _lockpick_progress < 0.5:
			col = Color(1.0, 0.85, 0.15)
		elif _lockpick_progress < 0.9:
			col = Color(0.4, 1.0, 0.3)
		else:
			col = Color(0.2, 1.0, 1.0)
		_lockpick_ring.draw_arc(center, radius, -PI * 0.5, end_a, 64, col, thick, true)
	# "Hold F" hint
	_lockpick_ring.draw_string(ThemeDB.fallback_font,
		center + Vector2(0.0, radius + 18.0),
		"Hold F  —  Lockpicking",
		HORIZONTAL_ALIGNMENT_CENTER, 260, 13,
		Color(0.9, 0.9, 0.9, 0.80))

func set_lockpick_progress(p: float) -> void:
	_lockpick_progress = p
	if _lockpick_ring:
		_lockpick_ring.visible = true
		_lockpick_ring.queue_redraw()

func hide_lockpick_ring() -> void:
	_lockpick_progress = 0.0
	if _lockpick_ring:
		_lockpick_ring.visible = false

func show_lockpick_message(msg: String, _success: bool) -> void:
	if not _lp_msg_label:
		return
	_lp_msg_label.text     = msg
	_lp_msg_label.modulate = Color(1.0, 0.2, 0.2, 1.0)
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(_lp_msg_label, "modulate:a", 0.0, 0.6)

func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.set_value(current, maximum)

func _on_mana_changed(current: float, maximum: float) -> void:
	mana_bar.set_value(current, maximum)

func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.value = (current / maximum) * 100.0

func _on_xp_changed(xp: int, xp_to_next: int) -> void:
	xp_bar.value = (float(xp) / float(xp_to_next)) * 100.0

func _on_leveled_up(new_level: int) -> void:
	level_label.text   = "Level %d" % new_level
	level_up_label.visible = true
	await get_tree().create_timer(2.0).timeout
	level_up_label.visible = false

func _on_needs_changed(need: String, is_active: bool) -> void:
	if need == "hungry":
		hungry_moodle.visible = is_active
	elif need == "thirsty":
		thirsty_moodle.visible = is_active

func _on_effect_changed(effect_id: String, active: bool, display_name: String, color: Color) -> void:
	if active:
		if effect_id not in _effect_moodles:
			var lbl := Label.new()
			lbl.add_theme_font_size_override("font_size", 16)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			moodle_container.add_child(lbl)
			_effect_moodles[effect_id] = lbl
		var m: Label = _effect_moodles[effect_id]
		m.text     = "⚠ " + display_name
		m.modulate = color
		m.visible  = true
	else:
		if effect_id in _effect_moodles:
			_effect_moodles[effect_id].queue_free()
			_effect_moodles.erase(effect_id)

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
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _close_controls() -> void:
	controls_menu.visible = false
	# Return to esc menu only if it was the entry point
	if esc_menu.visible == false and not _any_overlay_open():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		esc_menu.visible = true

func toggle_controls() -> void:
	if controls_menu.visible:
		_close_controls()
	else:
		_close_all_overlays()
		_open_controls()

func _any_overlay_open() -> bool:
	return inventory_overlay.visible or map_overlay.visible \
		or player_info.visible or loot_overlay.visible \
		or health_screen.visible or bank_overlay.visible or shop_overlay.visible

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

func _dev_spawn_locked_chest() -> void:
	var p: Node = GameManager.player_node
	if not p:
		return
	var LockedChestScene: PackedScene = preload("res://scenes/entities/locked_chest.tscn")
	var chest = LockedChestScene.instantiate()
	chest.difficulty = 0   # Very Easy
	# Add gold loot
	var gold = Item.new()
	gold.id          = "gold"
	gold.display_name = "Gold"
	gold.stackable   = true
	gold.stack_count = 25
	gold.item_type   = Item.ItemType.MISC
	gold.grid_size   = Vector2i(1, 1)
	gold.weight      = 0.01
	gold.description = "Shiny gold coins."
	chest.add_loot_item(gold)
	# Make sure player has lockpicks
	if GameManager.inventory:
		var has_picks: bool = false
		for e in GameManager.inventory.items:
			if (e["item"] as Item).id == "lockpick":
				has_picks = true
				break
		if not has_picks:
			var picks := Item.new()
			picks.id = "lockpick"; picks.display_name = "Lockpick"
			picks.stackable = true; picks.stack_count = 10
			picks.item_type = Item.ItemType.MISC
			picks.grid_size = Vector2i(1, 1); picks.weight = 0.05
			picks.description = "A thin metal pick."
			GameManager.inventory.add_item(picks, Vector2i(3, 1))
	# Spawn 2 units in front of the player
	var dungeon: Node = p.get_parent()
	dungeon.add_child(chest)
	chest.global_position = p.global_position + (-p.global_basis.z * 2.0)
	chest.global_position.y = 0.0
	_close_dev_tools()

func _on_bank_opened() -> void:
	_close_all_overlays()
	bank_overlay.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_shop_opened() -> void:
	_close_all_overlays()
	shop_overlay.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func toggle_health_screen() -> void:
	var opening := not health_screen.visible
	_close_all_overlays()
	health_screen.visible = opening
	_set_mouse_for_overlay()

func _close_all_overlays() -> void:
	inventory_overlay.visible  = false
	map_overlay.visible        = false
	esc_menu.visible           = false
	player_info.visible        = false
	dev_tools_menu.visible     = false
	controls_menu.visible      = false
	loot_overlay.visible       = false
	health_screen.visible      = false
	bank_overlay.visible       = false
	shop_overlay.visible       = false
	hide_lockpick_ring()

func _set_mouse_for_overlay() -> void:
	var any_open := inventory_overlay.visible or map_overlay.visible \
		or esc_menu.visible or player_info.visible or loot_overlay.visible \
		or health_screen.visible or bank_overlay.visible or shop_overlay.visible \
		or controls_menu.visible
	Input.set_mouse_mode(
		Input.MOUSE_MODE_VISIBLE if any_open else Input.MOUSE_MODE_CAPTURED
	)
