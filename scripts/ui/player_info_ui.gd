extends Control

const DEBUFF_COLOR   := Color(1.0, 0.35, 0.35)
const InventoryClass := preload("res://scripts/resources/inventory.gd")

var _name_label:     Label = null
var _class_label:    Label = null
var _level_label:    Label = null
var _xp_bar:         ProgressBar = null
var _str_label:      Label = null
var _dex_label:      Label = null
var _con_label:      Label = null
var _mag_label:      Label = null
var _hp_label:       Label = null
var _mana_label:     Label = null
var _stamina_label:  Label = null
var _hunger_bar:     ProgressBar = null
var _thirst_bar:     ProgressBar = null
var _weight_label:   Label = null

func _ready() -> void:
	_build_ui()
	visibility_changed.connect(_on_visibility_changed)

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -280
	panel.offset_top    = -320
	panel.offset_right  =  280
	panel.offset_bottom =  320
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# ── Header ───────────────────────────────────────────────────────────────
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 24)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_name_label)

	_class_label = Label.new()
	_class_label.add_theme_font_size_override("font_size", 14)
	_class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_class_label.modulate = Color(0.75, 0.75, 0.75)
	vbox.add_child(_class_label)

	# Level + XP row
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 12)
	vbox.add_child(level_row)

	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 13)
	_level_label.custom_minimum_size = Vector2(80, 0)
	level_row.add_child(_level_label)

	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(180, 18)
	_xp_bar.show_percentage = false
	var xp_style := StyleBoxFlat.new()
	xp_style.bg_color = Color(0.9, 0.8, 0.1)
	_xp_bar.add_theme_stylebox_override("fill", xp_style)
	level_row.add_child(_xp_bar)

	_add_separator(vbox)

	# ── Attributes ────────────────────────────────────────────────────────────
	var attr_label := Label.new()
	attr_label.text = "Attributes"
	attr_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(attr_label)

	var attr_grid := GridContainer.new()
	attr_grid.columns = 2
	attr_grid.add_theme_constant_override("h_separation", 24)
	attr_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(attr_grid)

	_str_label    = _add_stat_row(attr_grid, "Strength")
	_dex_label    = _add_stat_row(attr_grid, "Dexterity")
	_con_label    = _add_stat_row(attr_grid, "Constitution")
	_mag_label    = _add_stat_row(attr_grid, "Magic")

	_add_separator(vbox)

	# ── Vitals ───────────────────────────────────────────────────────────────
	var vitals_label := Label.new()
	vitals_label.text = "Vitals"
	vitals_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(vitals_label)

	var vitals_grid := GridContainer.new()
	vitals_grid.columns = 2
	vitals_grid.add_theme_constant_override("h_separation", 24)
	vitals_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(vitals_grid)

	_hp_label     = _add_stat_row(vitals_grid, "Health")
	_mana_label   = _add_stat_row(vitals_grid, "Mana")
	_stamina_label = _add_stat_row(vitals_grid, "Stamina")

	_add_separator(vbox)

	# ── Needs ─────────────────────────────────────────────────────────────────
	var needs_label := Label.new()
	needs_label.text = "Needs"
	needs_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(needs_label)

	var needs_grid := GridContainer.new()
	needs_grid.columns = 2
	needs_grid.add_theme_constant_override("h_separation", 16)
	needs_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(needs_grid)

	_add_bar_row(needs_grid, "Hunger",  Color(0.9, 0.7, 0.1))
	_add_bar_row(needs_grid, "Thirst",  Color(0.2, 0.6, 1.0))

	_add_separator(vbox)

	# ── Weight ────────────────────────────────────────────────────────────────
	_weight_label = Label.new()
	_weight_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_weight_label)

	var hint := Label.new()
	hint.text = "[C] to close"
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(0.55, 0.55, 0.55)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

func _add_separator(parent: Control) -> void:
	var sep := HSeparator.new()
	parent.add_child(sep)

func _add_stat_row(grid: GridContainer, label_text: String) -> Label:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 13)
	grid.add_child(lbl)

	var val := Label.new()
	val.add_theme_font_size_override("font_size", 13)
	grid.add_child(val)
	return val

func _add_bar_row(grid: GridContainer, label_text: String, bar_color: Color) -> void:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 13)
	grid.add_child(lbl)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(160, 18)
	bar.value = 100.0
	bar.show_percentage = false
	var style := StyleBoxFlat.new()
	style.bg_color = bar_color
	bar.add_theme_stylebox_override("fill", style)
	grid.add_child(bar)

	if label_text == "Hunger":
		_hunger_bar = bar
	else:
		_thirst_bar = bar

# ─────────────────────────────────────────────────────────────────────────────
func refresh() -> void:
	if not GameManager.stats:
		return

	var p: Node = GameManager.player_node
	var s: Resource = GameManager.stats

	_name_label.text  = GameManager.player_name if GameManager.player_name != "" else "Unknown"
	_class_label.text = s.class_id.capitalize()
	_level_label.text = "Level %d" % s.level
	_xp_bar.max_value = s.xp_to_next
	_xp_bar.value     = s.xp

	# Attributes — show base (effective in red if debuffed)
	_set_stat_label(_str_label, "STR", s.strength, p.get_effective_strength() if p else s.strength)
	_set_stat_label(_dex_label, "DEX", s.dexterity, p.get_effective_dexterity() if p else s.dexterity)
	_set_stat_label(_con_label, "CON", s.constitution, p.get_effective_constitution() if p else s.constitution)
	_mag_label.text = str(s.magic)

	# Vitals
	if p:
		_hp_label.text     = "%d / %d" % [int(p.health), int(p.max_health)]
		_mana_label.text   = "%d / %d" % [int(p.mana), int(p.max_mana)]
		_stamina_label.text = "%d / %d" % [int(p.stamina), int(p.MAX_STAMINA)]
		_hunger_bar.value  = p.hunger
		_thirst_bar.value  = p.thirst

	# Weight
	if GameManager.inventory:
		var inv := GameManager.inventory as InventoryClass
		_weight_label.text = "Carry Weight: %.1f / %.1f kg" % [inv.current_weight(), inv.max_weight]

func _set_stat_label(lbl: Label, _prefix: String, base: int, effective: int) -> void:
	if effective < base:
		lbl.text     = "%d  [%d]" % [base, effective]
		lbl.modulate = DEBUFF_COLOR
	else:
		lbl.text     = str(base)
		lbl.modulate = Color.WHITE

func _on_visibility_changed() -> void:
	if visible:
		refresh()
