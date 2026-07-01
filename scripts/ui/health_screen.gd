extends Control

const LimbHealthClass := preload("res://scripts/resources/limb_health.gd")

const CONDITION_COLORS: Array = [
	Color(0.20, 0.80, 0.20),   # HEALTHY  — green
	Color(0.90, 0.55, 0.10),   # CUT      — orange
	Color(0.75, 0.10, 0.10),   # DEEP_CUT — red
	Color(0.55, 0.25, 0.90),   # FRACTURED— purple
]
const CONDITION_LABELS: Array = ["Healthy", "Cut", "Deep Cut", "Fractured"]

var _limb_labels: Array = []   # Label per limb

func _ready() -> void:
	_build_ui()
	visibility_changed.connect(_on_visibility)
	GameManager.limb_condition_changed.connect(_on_limb_changed)

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -220
	panel.offset_top    = -260
	panel.offset_right  =  220
	panel.offset_bottom =  260
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "BODY"
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(grid)

	for i in LimbHealthClass.LIMB_NAMES.size():
		var name_lbl := Label.new()
		name_lbl.text = LimbHealthClass.LIMB_NAMES[i]
		name_lbl.add_theme_font_size_override("font_size", 14)
		grid.add_child(name_lbl)

		var cond_lbl := Label.new()
		cond_lbl.add_theme_font_size_override("font_size", 14)
		grid.add_child(cond_lbl)
		_limb_labels.append(cond_lbl)

	vbox.add_child(HSeparator.new())

	var hint := Label.new()
	hint.text = "[H] to close"
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(0.55, 0.55, 0.55)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

func refresh() -> void:
	var p: Node = GameManager.player_node
	if not p or not p.get("limbs"):
		return
	var limb_health: LimbHealthClass = p.limbs
	for i in _limb_labels.size():
		var cond: int = limb_health.get_condition(i)
		var lbl: Label = _limb_labels[i]
		lbl.text     = CONDITION_LABELS[cond]
		lbl.modulate = CONDITION_COLORS[cond]

func _on_visibility() -> void:
	if visible:
		refresh()

func _on_limb_changed(_limb_idx: int, _cond: int) -> void:
	if visible:
		refresh()
