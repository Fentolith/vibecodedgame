extends Control

const ItemClass      := preload("res://scripts/resources/item.gd")
const InventoryClass := preload("res://scripts/resources/inventory.gd")

var _bank_list:  VBoxContainer = null
var _inv_list:   VBoxContainer = null

func _ready() -> void:
	_build_ui()
	visibility_changed.connect(_on_visibility)

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -320
	panel.offset_top    = -260
	panel.offset_right  =  320
	panel.offset_bottom =  260
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "BANK CHEST"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	# Bank side
	var bank_col := VBoxContainer.new()
	bank_col.custom_minimum_size = Vector2(260, 0)
	bank_col.add_theme_constant_override("separation", 6)
	hbox.add_child(bank_col)

	var bank_lbl := Label.new()
	bank_lbl.text = "Bank (safe across floors)"
	bank_lbl.add_theme_font_size_override("font_size", 13)
	bank_lbl.modulate = Color(0.9, 0.75, 0.2)
	bank_col.add_child(bank_lbl)

	_bank_list = VBoxContainer.new()
	_bank_list.add_theme_constant_override("separation", 4)
	bank_col.add_child(_bank_list)

	# Inventory side
	var inv_col := VBoxContainer.new()
	inv_col.custom_minimum_size = Vector2(260, 0)
	inv_col.add_theme_constant_override("separation", 6)
	hbox.add_child(inv_col)

	var inv_lbl := Label.new()
	inv_lbl.text = "Your Inventory"
	inv_lbl.add_theme_font_size_override("font_size", 13)
	inv_lbl.modulate = Color(0.7, 0.9, 0.7)
	inv_col.add_child(inv_lbl)

	_inv_list = VBoxContainer.new()
	_inv_list.add_theme_constant_override("separation", 4)
	inv_col.add_child(_inv_list)

	vbox.add_child(HSeparator.new())

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(580, 40)
	close.pressed.connect(_close)
	vbox.add_child(close)

func _refresh() -> void:
	# Clear lists
	for c in _bank_list.get_children():
		c.queue_free()
	for c in _inv_list.get_children():
		c.queue_free()

	# Bank items
	if GameManager.bank_items.is_empty():
		var e := Label.new()
		e.text = "(empty)"
		e.modulate = Color(0.5, 0.5, 0.5)
		_bank_list.add_child(e)
	else:
		for item in GameManager.bank_items:
			_add_row(_bank_list, item, true)

	# Inventory items
	if not GameManager.inventory:
		return
	var inv := GameManager.inventory as InventoryClass
	if inv.items.is_empty():
		var e := Label.new()
		e.text = "(empty)"
		e.modulate = Color(0.5, 0.5, 0.5)
		_inv_list.add_child(e)
	else:
		for entry in inv.items:
			_add_row(_inv_list, entry["item"], false)

func _add_row(parent: VBoxContainer, item: Resource, from_bank: bool) -> void:
	var it  := item as ItemClass
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var lbl := Label.new()
	var label := it.display_name
	if it.stackable and it.stack_count > 1:
		label += "  x%d" % it.stack_count
	lbl.text = label
	lbl.custom_minimum_size = Vector2(160, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(lbl)

	var btn := Button.new()
	btn.text = "← Deposit" if not from_bank else "Withdraw →"
	btn.pressed.connect(_transfer.bind(item, from_bank))
	row.add_child(btn)

func _transfer(item: Resource, from_bank: bool) -> void:
	if from_bank:
		# Withdraw to inventory
		var inv := GameManager.inventory as InventoryClass
		for row_idx in inv.capacity_slots.y:
			for col_idx in inv.capacity_slots.x:
				if inv.add_item(item, Vector2i(col_idx, row_idx)):
					GameManager.bank_items.erase(item)
					_refresh()
					return
	else:
		# Deposit to bank
		GameManager.bank_items.append(item)
		(GameManager.inventory as InventoryClass).remove_item(item)
		_refresh()

func _close() -> void:
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_visibility() -> void:
	if visible:
		_refresh()
