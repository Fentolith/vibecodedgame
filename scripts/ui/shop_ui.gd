extends Control

const ItemClass      := preload("res://scripts/resources/item.gd")
const InventoryClass := preload("res://scripts/resources/inventory.gd")

const SHOP_STOCK: Array = [
	{id="health_potion", display_name="Health Potion", buy=15,  sell=7,  item_type=8,  desc="Restores 10 HP.",            nutrition=0.0, grid=Vector2i(1,1), rarity=0, weight=0.3,  stackable=false, damage_bonus=0, attack_speed=1.0, weapon_visual="",       armor_bonus=0},
	{id="mana_potion",   display_name="Mana Potion",   buy=18,  sell=8,  item_type=8,  desc="Restores 8 mana.",           nutrition=0.0, grid=Vector2i(1,1), rarity=0, weight=0.3,  stackable=false, damage_bonus=0, attack_speed=1.0, weapon_visual="",       armor_bonus=0},
	{id="bandage",       display_name="Bandage",        buy=10,  sell=5,  item_type=8,  desc="Heals a cut limb.",          nutrition=0.0, grid=Vector2i(1,1), rarity=0, weight=0.1,  stackable=false, damage_bonus=0, attack_speed=1.0, weapon_visual="",       armor_bonus=0},
	{id="bread",         display_name="Bread",          buy=8,   sell=3,  item_type=9,  desc="Restores 30 hunger.",        nutrition=30.0,grid=Vector2i(1,1), rarity=0, weight=0.2,  stackable=false, damage_bonus=0, attack_speed=1.0, weapon_visual="",       armor_bonus=0},
	{id="water_flask",   display_name="Water Flask",    buy=8,   sell=3,  item_type=10, desc="Restores 40 thirst.",        nutrition=40.0,grid=Vector2i(1,1), rarity=0, weight=0.4,  stackable=false, damage_bonus=0, attack_speed=1.0, weapon_visual="",       armor_bonus=0},
	{id="iron_sword",    display_name="Iron Sword",     buy=40,  sell=20, item_type=0,  desc="A sturdy iron sword. +2 dmg.",nutrition=0.0,grid=Vector2i(1,3), rarity=0, weight=3.5,  stackable=false, damage_bonus=2, attack_speed=1.0, weapon_visual="sword",  armor_bonus=0},
	{id="dagger",        display_name="Dagger",         buy=25,  sell=12, item_type=0,  desc="Fast and precise. +1 dmg.",  nutrition=0.0,grid=Vector2i(1,2), rarity=0, weight=1.2,  stackable=false, damage_bonus=1, attack_speed=1.4, weapon_visual="dagger", armor_bonus=0},
	{id="war_axe",       display_name="War Axe",        buy=55,  sell=28, item_type=0,  desc="Heavy axe. +4 dmg.",         nutrition=0.0,grid=Vector2i(1,3), rarity=1, weight=5.0,  stackable=false, damage_bonus=4, attack_speed=0.8, weapon_visual="axe",    armor_bonus=0},
	{id="staff",         display_name="Staff",          buy=50,  sell=25, item_type=0,  desc="Magic staff. +3 dmg.",       nutrition=0.0,grid=Vector2i(1,3), rarity=1, weight=2.8,  stackable=false, damage_bonus=3, attack_speed=0.9, weapon_visual="staff",  armor_bonus=0},
	{id="leather_armor", display_name="Leather Armor",  buy=35,  sell=17, item_type=4,  desc="Light protection. +2 armor.",nutrition=0.0,grid=Vector2i(2,2), rarity=1, weight=5.0,  stackable=false, damage_bonus=0, attack_speed=1.0, weapon_visual="",       armor_bonus=2},
	{id="lockpick",      display_name="Lockpick",       buy=6,   sell=2,  item_type=11, desc="Used to open locked chests.", nutrition=0.0,grid=Vector2i(1,1), rarity=0, weight=0.05, stackable=true,  damage_bonus=0, attack_speed=1.0, weapon_visual="",       armor_bonus=0},
]

var _shop_list: VBoxContainer = null
var _inv_list:  VBoxContainer = null
var _gold_label: Label        = null

func _ready() -> void:
	_build_ui()
	visibility_changed.connect(_on_visibility)

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -360
	panel.offset_top    = -280
	panel.offset_right  =  360
	panel.offset_bottom =  280
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "MERCHANT"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 13)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.modulate = Color(1.0, 0.85, 0.2)
	vbox.add_child(_gold_label)

	vbox.add_child(HSeparator.new())

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	var shop_col := VBoxContainer.new()
	shop_col.custom_minimum_size = Vector2(310, 0)
	shop_col.add_theme_constant_override("separation", 5)
	hbox.add_child(shop_col)
	var sl := Label.new()
	sl.text = "For Sale"
	sl.add_theme_font_size_override("font_size", 14)
	sl.modulate = Color(0.8, 0.9, 1.0)
	shop_col.add_child(sl)
	_shop_list = VBoxContainer.new()
	_shop_list.add_theme_constant_override("separation", 4)
	shop_col.add_child(_shop_list)

	var inv_col := VBoxContainer.new()
	inv_col.custom_minimum_size = Vector2(310, 0)
	inv_col.add_theme_constant_override("separation", 5)
	hbox.add_child(inv_col)
	var il := Label.new()
	il.text = "Your Items (sell)"
	il.add_theme_font_size_override("font_size", 14)
	il.modulate = Color(0.8, 1.0, 0.8)
	inv_col.add_child(il)
	_inv_list = VBoxContainer.new()
	_inv_list.add_theme_constant_override("separation", 4)
	inv_col.add_child(_inv_list)

	vbox.add_child(HSeparator.new())

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(680, 40)
	close.pressed.connect(_close)
	vbox.add_child(close)

func _refresh() -> void:
	for c in _shop_list.get_children():
		c.queue_free()
	for c in _inv_list.get_children():
		c.queue_free()

	_gold_label.text = "Gold: %d" % _count_gold()

	for entry in SHOP_STOCK:
		_add_shop_row(entry)

	if GameManager.inventory:
		for e in (GameManager.inventory as InventoryClass).items:
			_add_inv_row(e["item"])

func _add_shop_row(entry: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_shop_list.add_child(row)

	var lbl := Label.new()
	lbl.text = "%s  (%d gold)" % [entry.display_name, entry.buy]
	lbl.custom_minimum_size = Vector2(220, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(lbl)

	var btn := Button.new()
	btn.text = "Buy"
	btn.pressed.connect(_buy.bind(entry))
	row.add_child(btn)

func _add_inv_row(item: Resource) -> void:
	var it  := item as ItemClass
	if it.id == "gold":
		return
	var sell_price: int = _sell_price(it)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_inv_list.add_child(row)

	var lbl := Label.new()
	lbl.text = "%s  (%d gold)" % [it.display_name, sell_price]
	lbl.custom_minimum_size = Vector2(220, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(lbl)

	var btn := Button.new()
	btn.text = "Sell"
	btn.pressed.connect(_sell.bind(item, sell_price))
	row.add_child(btn)

func _buy(entry: Dictionary) -> void:
	var cost: int = entry.buy as int
	if not _spend_gold(cost):
		return
	var it := ItemClass.new()
	it.id               = entry.id
	it.display_name     = entry.display_name
	it.item_type        = entry.item_type
	it.description      = entry.desc
	it.nutrition        = entry.nutrition
	it.grid_size        = entry.grid
	it.rarity           = entry.rarity
	it.weight           = entry.weight
	it.stackable        = entry.stackable
	it.damage_bonus     = entry.get("damage_bonus", 0)
	it.attack_speed_mult = entry.get("attack_speed", 1.0)
	it.weapon_visual_id = entry.get("weapon_visual", "")
	it.armor_bonus      = entry.get("armor_bonus", 0)
	var inv := GameManager.inventory as InventoryClass
	for row_idx in inv.capacity_slots.y:
		for col_idx in inv.capacity_slots.x:
			if inv.add_item(it, Vector2i(col_idx, row_idx)):
				_refresh()
				return

func _sell(item: Resource, price: int) -> void:
	(GameManager.inventory as InventoryClass).remove_item(item)
	_add_gold(price)
	_refresh()

func _count_gold() -> int:
	if not GameManager.inventory:
		return 0
	var total: int = 0
	for e in (GameManager.inventory as InventoryClass).items:
		var it := e["item"] as ItemClass
		if it.id == "gold":
			total += it.stack_count
	return total

func _spend_gold(amount: int) -> bool:
	var inv := GameManager.inventory as InventoryClass
	for e in inv.items:
		var it := e["item"] as ItemClass
		if it.id == "gold" and it.stack_count >= amount:
			it.stack_count -= amount
			if it.stack_count <= 0:
				inv.remove_item(e["item"])
			return true
	return false

func _add_gold(amount: int) -> void:
	var inv := GameManager.inventory as InventoryClass
	for e in inv.items:
		var it := e["item"] as ItemClass
		if it.id == "gold":
			it.stack_count += amount
			return
	var gold := ItemClass.new()
	gold.id           = "gold"
	gold.display_name = "Gold"
	gold.stackable    = true
	gold.stack_count  = amount
	gold.item_type    = ItemClass.ItemType.MISC
	gold.grid_size    = Vector2i(1, 1)
	gold.weight       = 0.01
	gold.description  = "Shiny gold coins."
	for row_idx in inv.capacity_slots.y:
		for col_idx in inv.capacity_slots.x:
			if inv.add_item(gold, Vector2i(col_idx, row_idx)):
				return

func _sell_price(it: ItemClass) -> int:
	for entry in SHOP_STOCK:
		if entry.id == it.id:
			return entry.sell as int
	return maxi(1, int(it.weight * 5))

func _close() -> void:
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_visibility() -> void:
	if visible:
		_refresh()
