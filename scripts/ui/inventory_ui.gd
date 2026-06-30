extends Control

const ItemClass      := preload("res://scripts/resources/item.gd")
const InventoryClass := preload("res://scripts/resources/inventory.gd")

const CELL_SIZE    := 60
const COLS         := 8
const ROWS         := 6
const SLOT_NAMES   := ["head", "chest", "legs", "feet", "main_hand", "off_hand", "ring"]
const SLOT_LABELS  := ["Head", "Chest", "Legs", "Feet", "Main Hand", "Off Hand", "Ring"]
const RARITY_COLORS := {
	0: Color(0.75, 0.75, 0.75),  # COMMON    — gray
	1: Color(0.2,  0.85, 0.2 ),  # UNCOMMON  — green
	2: Color(0.25, 0.5,  1.0 ),  # RARE      — blue
	3: Color(0.8,  0.2,  1.0 ),  # EPIC      — purple
	4: Color(1.0,  0.72, 0.1 ),  # LEGENDARY — gold
}

var _grid_cells:   Array      = []   # flat Panel array, row-major
var _item_rects:   Array      = []   # ColorRect nodes drawn for each inventory item
var _slot_buttons: Dictionary = {}   # slot_name -> Button
var _weight_label: Label      = null
var _info_label:   RichTextLabel = null
var _grid_root:    Control    = null

# Drag state
var _dragging_item:    Resource  = null
var _drag_rect:        ColorRect = null
var _context_item:     Resource  = null
var _context_menu:     PopupMenu = null

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_ui()
	visibility_changed.connect(_on_visibility_changed)

func _build_ui() -> void:
	# ── Outer panel ──────────────────────────────────────────────────────────
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -470
	panel.offset_top    = -280
	panel.offset_right  =  470
	panel.offset_bottom =  280
	add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	outer.add_theme_constant_override("margin_left",   16)
	outer.add_theme_constant_override("margin_right",  16)
	outer.add_theme_constant_override("margin_top",    12)
	outer.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(outer)

	# Title
	var title := Label.new()
	title.text = "INVENTORY"
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(title)

	# ── Middle row: grid + equipment ─────────────────────────────────────────
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	outer.add_child(hbox)

	_build_grid(hbox)
	_build_equipment_panel(hbox)

	# ── Bottom row: weight + item info ───────────────────────────────────────
	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 4)
	outer.add_child(bottom)

	_weight_label = Label.new()
	_weight_label.text = "Weight: 0.0 / 0.0 kg"
	_weight_label.add_theme_font_size_override("font_size", 13)
	bottom.add_child(_weight_label)

	_info_label = RichTextLabel.new()
	_info_label.bbcode_enabled = true
	_info_label.fit_content    = true
	_info_label.custom_minimum_size = Vector2(0, 52)
	_info_label.scroll_active = false
	bottom.add_child(_info_label)

	# ── Drag rect (top-level, mouse-passthrough) ──────────────────────────────
	_drag_rect = ColorRect.new()
	_drag_rect.size         = Vector2(CELL_SIZE - 4, CELL_SIZE - 4)
	_drag_rect.color        = Color(1, 1, 1, 0.65)
	_drag_rect.visible      = false
	_drag_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drag_rect)

	# Context menu
	_context_menu = PopupMenu.new()
	_context_menu.id_pressed.connect(_on_context_id_pressed)
	add_child(_context_menu)

func _build_grid(parent: Control) -> void:
	_grid_root = Control.new()
	_grid_root.custom_minimum_size = Vector2(COLS * CELL_SIZE, ROWS * CELL_SIZE)
	parent.add_child(_grid_root)

	for row in ROWS:
		for col in COLS:
			var cell := Panel.new()
			cell.position     = Vector2(col * CELL_SIZE, row * CELL_SIZE)
			cell.size         = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
			cell.mouse_filter = Control.MOUSE_FILTER_STOP
			var gp := Vector2i(col, row)
			cell.gui_input.connect(_on_cell_input.bind(gp))
			cell.mouse_entered.connect(_on_cell_hover.bind(gp))
			_grid_root.add_child(cell)
			_grid_cells.append(cell)

func _build_equipment_panel(parent: Control) -> void:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(170, 0)
	col.add_theme_constant_override("separation", 8)
	parent.add_child(col)

	var lbl := Label.new()
	lbl.text = "Equipment"
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(lbl)

	for i in SLOT_NAMES.size():
		var sname: String = SLOT_NAMES[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		col.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = SLOT_LABELS[i]
		name_lbl.custom_minimum_size = Vector2(82, 0)
		name_lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(name_lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(80, 34)
		btn.text = "—"
		btn.pressed.connect(_on_slot_pressed.bind(sname))
		btn.mouse_entered.connect(_on_slot_hover.bind(sname))
		row.add_child(btn)
		_slot_buttons[sname] = btn

# ─────────────────────────────────────────────────────────────────────────────
func refresh() -> void:
	if not GameManager.inventory:
		return

	# Clear drawn item rects
	for r in _item_rects:
		if is_instance_valid(r):
			r.queue_free()
	_item_rects.clear()

	# Draw items in grid
	for entry in GameManager.inventory.items:
		_draw_grid_item(entry["item"], entry["position"])

	# Equipment slots
	for sname in SLOT_NAMES:
		var btn: Button = _slot_buttons[sname]
		var equipped: Resource = GameManager.equipment.get_slot(sname)
		if equipped:
			var it := equipped as ItemClass
			btn.text     = it.display_name.left(9)
			btn.modulate = RARITY_COLORS.get(it.rarity, Color.WHITE)
		else:
			btn.text     = "—"
			btn.modulate = Color.WHITE

	# Weight
	var inv := GameManager.inventory as InventoryClass
	var w: float  = inv.current_weight()
	var mw: float = inv.max_weight
	_weight_label.text = "Weight: %.1f / %.1f kg" % [w, mw]

func _draw_grid_item(item: Resource, grid_pos: Vector2i) -> void:
	var it     := item as ItemClass
	var origin := _grid_root.global_position

	var rect       := ColorRect.new()
	rect.position   = origin + Vector2(grid_pos.x * CELL_SIZE, grid_pos.y * CELL_SIZE)
	rect.size       = Vector2(it.grid_size.x * CELL_SIZE - 4, it.grid_size.y * CELL_SIZE - 4)
	rect.color      = RARITY_COLORS.get(it.rarity, Color.WHITE)
	rect.color.a    = 0.78
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	rect.gui_input.connect(_on_item_input.bind(item))
	rect.mouse_entered.connect(_on_item_hover.bind(item))
	add_child(rect)
	_item_rects.append(rect)

	var name_lbl := Label.new()
	name_lbl.text                = it.display_name
	name_lbl.size                = rect.size
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	name_lbl.autowrap_mode       = TextServer.AUTOWRAP_WORD_SMART
	rect.add_child(name_lbl)

	if it.stackable and it.stack_count > 1:
		var stack_lbl := Label.new()
		stack_lbl.text = str(it.stack_count)
		stack_lbl.size = rect.size - Vector2(4, 4)
		stack_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stack_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_BOTTOM
		stack_lbl.add_theme_font_size_override("font_size", 9)
		stack_lbl.add_theme_color_override("font_color", Color.WHITE)
		stack_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.add_child(stack_lbl)

# ─────────────────────────────────────────────────────────────────────────────
func _on_cell_input(event: InputEvent, cell_pos: Vector2i) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		if _dragging_item:
			_try_place(_dragging_item, cell_pos)

func _on_cell_hover(cell_pos: Vector2i) -> void:
	if _dragging_item:
		return
	var item: Resource = GameManager.inventory.get_item_at(cell_pos)
	if item:
		_show_info(item)

func _on_item_input(event: InputEvent, item: Resource) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		_pick_up(item)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		_open_context_menu(item)

func _on_item_hover(item: Resource) -> void:
	if not _dragging_item:
		_show_info(item)

func _on_slot_pressed(slot_name: String) -> void:
	if _dragging_item:
		_try_equip_to_slot(_dragging_item, slot_name)
	else:
		_unequip_slot(slot_name)

func _on_slot_hover(slot_name: String) -> void:
	if _dragging_item:
		return
	var item: Resource = GameManager.equipment.get_slot(slot_name)
	if item:
		_show_info(item)

# ─────────────────────────────────────────────────────────────────────────────
func _pick_up(item: Resource) -> void:
	GameManager.inventory.remove_item(item)
	_dragging_item = item
	var it := item as ItemClass
	_drag_rect.size    = Vector2(it.grid_size.x * CELL_SIZE - 4, it.grid_size.y * CELL_SIZE - 4)
	_drag_rect.color   = RARITY_COLORS.get(it.rarity, Color.WHITE)
	_drag_rect.color.a = 0.7
	_drag_rect.visible = true
	refresh()

func _try_place(item: Resource, cell_pos: Vector2i) -> void:
	if GameManager.inventory.add_item(item, cell_pos):
		_dragging_item     = null
		_drag_rect.visible = false
		refresh()

func _open_context_menu(item: Resource) -> void:
	_context_item = item
	_context_menu.clear()
	var it := item as ItemClass
	if it.item_type == ItemClass.ItemType.CONSUMABLE:
		_context_menu.add_item("Use", 0)
	if it.item_type == ItemClass.ItemType.WEAPON or it.item_type == ItemClass.ItemType.ARMOR:
		_context_menu.add_item("Equip", 1)
	_context_menu.add_item("Drop", 2)
	_context_menu.popup(Rect2i(
		int(get_viewport().get_mouse_position().x),
		int(get_viewport().get_mouse_position().y),
		0, 0))

func _on_context_id_pressed(id: int) -> void:
	if not _context_item:
		return
	match id:
		0: # Use
			GameManager.use_item(_context_item)
			refresh()
		1: # Equip
			var it   := _context_item as ItemClass
			var slot := _slot_for_item(it)
			if slot != "":
				GameManager.inventory.remove_item(_context_item)
				var old: Resource = GameManager.equipment.get_slot(slot)
				if old:
					_auto_place(old)
				GameManager.equipment.equip(slot, _context_item)
				refresh()
		2: # Drop
			GameManager.drop_item(_context_item)
			refresh()
	_context_item = null

func _try_equip_to_slot(item: Resource, slot_name: String) -> void:
	var old: Resource = GameManager.equipment.get_slot(slot_name)
	if old:
		_auto_place(old)
	GameManager.equipment.equip(slot_name, item)
	_dragging_item     = null
	_drag_rect.visible = false
	refresh()

func _unequip_slot(slot_name: String) -> void:
	var item: Resource = GameManager.equipment.unequip(slot_name)
	if item:
		_auto_place(item)
		refresh()

func _auto_place(item: Resource) -> void:
	for row in ROWS:
		for col in COLS:
			if GameManager.inventory.add_item(item, Vector2i(col, row)):
				return

func _slot_for_item(it: ItemClass) -> String:
	match it.item_type:
		ItemClass.ItemType.WEAPON: return "main_hand"
		ItemClass.ItemType.ARMOR:  return "chest"
	return ""

func _show_info(item: Resource) -> void:
	var it           := item as ItemClass
	var rarity_names := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
	var col: String = (RARITY_COLORS.get(it.rarity, Color.WHITE) as Color).to_html(false)
	_info_label.text  = "[color=#%s][b]%s[/b][/color]   [i]%s[/i]   %.1f kg\n%s" % [
		col, it.display_name, rarity_names[it.rarity], it.weight, it.description
	]

# ─────────────────────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if _dragging_item and _drag_rect.visible:
		_drag_rect.global_position = get_viewport().get_mouse_position() \
			- _drag_rect.size * 0.5

func _on_visibility_changed() -> void:
	if visible:
		refresh()
	elif _dragging_item:
		_auto_place(_dragging_item)
		_dragging_item     = null
		_drag_rect.visible = false
