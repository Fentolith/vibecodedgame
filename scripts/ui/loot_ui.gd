extends Control

const ItemClass      := preload("res://scripts/resources/item.gd")
const InventoryClass := preload("res://scripts/resources/inventory.gd")

var _bag:       Node           = null
var _item_list: VBoxContainer  = null

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -220
	panel.offset_top    = -220
	panel.offset_right  =  220
	panel.offset_bottom =  220
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "LOOT BAG"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	_item_list = VBoxContainer.new()
	_item_list.add_theme_constant_override("separation", 8)
	vbox.add_child(_item_list)

	vbox.add_child(HSeparator.new())

	var take_all := Button.new()
	take_all.text = "Take All"
	take_all.custom_minimum_size = Vector2(400, 40)
	take_all.pressed.connect(_take_all)
	vbox.add_child(take_all)

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(400, 40)
	close.pressed.connect(close_bag)
	vbox.add_child(close)

func open_bag(bag: Node) -> void:
	_bag    = bag
	visible = true
	_refresh()

func close_bag() -> void:
	visible = false
	_bag    = null
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _refresh() -> void:
	for child in _item_list.get_children():
		child.queue_free()

	if not _bag:
		return

	if _bag.items.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "(empty)"
		empty_lbl.modulate = Color(0.6, 0.6, 0.6)
		_item_list.add_child(empty_lbl)
		return

	for item in _bag.items:
		_add_row(item)

func _add_row(item: Resource) -> void:
	var it  := item as ItemClass
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_item_list.add_child(row)

	var name_lbl := Label.new()
	var label    := it.display_name
	if it.stackable and it.stack_count > 1:
		label += "  x%d" % it.stack_count
	name_lbl.text                = label
	name_lbl.custom_minimum_size = Vector2(280, 0)
	name_lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(name_lbl)

	var btn := Button.new()
	btn.text = "Take"
	btn.pressed.connect(_take_item.bind(item))
	row.add_child(btn)

func _take_item(item: Resource) -> void:
	if not _bag:
		return
	if _auto_place(item):
		_bag.remove_item(item)
	_refresh()
	if _bag and _bag.items.is_empty():
		close_bag()

func _take_all() -> void:
	if not _bag:
		return
	var copy: Array = _bag.items.duplicate()
	for item in copy:
		if _auto_place(item):
			_bag.remove_item(item)
	close_bag()

func _auto_place(item: Resource) -> bool:
	var inv := GameManager.inventory as InventoryClass
	for row in inv.capacity_slots.y:
		for col in inv.capacity_slots.x:
			if inv.add_item(item, Vector2i(col, row)):
				return true
	return false
