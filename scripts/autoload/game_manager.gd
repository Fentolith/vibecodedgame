extends Node

const PlayerStatsClass := preload("res://scripts/resources/player_stats.gd")
const InventoryClass   := preload("res://scripts/resources/inventory.gd")
const EquipmentClass   := preload("res://scripts/resources/equipment.gd")
const ItemClass        := preload("res://scripts/resources/item.gd")
const LootBagScene     := preload("res://scenes/entities/loot_bag.tscn")

@warning_ignore("unused_signal")
signal player_died
@warning_ignore("unused_signal")
signal loot_bag_opened(bag: Node)
@warning_ignore("unused_signal")
signal player_health_changed(current: float, maximum: float)
@warning_ignore("unused_signal")
signal player_mana_changed(current: float, maximum: float)
@warning_ignore("unused_signal")
signal player_stamina_changed(current: float, maximum: float)
@warning_ignore("unused_signal")
signal player_needs_changed(need: String, is_active: bool)
@warning_ignore("unused_signal")
signal player_xp_changed(xp: int, xp_to_next: int)
@warning_ignore("unused_signal")
signal player_leveled_up(new_level: int)
@warning_ignore("unused_signal")
signal status_effect_changed(effect_id: String, active: bool, display_name: String, color: Color)
@warning_ignore("unused_signal")
signal limb_condition_changed(limb_idx: int, condition: int)
@warning_ignore("unused_signal")
signal bank_opened
@warning_ignore("unused_signal")
signal shop_opened
@warning_ignore("unused_signal")
signal equipment_changed(slot: String, item)
@warning_ignore("unused_signal")
signal floor_transition_started(next_floor: int, kills: int)
@warning_ignore("unused_signal")
signal lockpick_chest_opened(chest: Node)

var current_floor: int = 0
var is_paused:    bool = false
var floor_kills:  int  = 0
var total_kills:  int  = 0

# ── Loot tables ──────────────────────────────────────────────────────────────
const LOOT_TABLES: Dictionary = {
	"slime": [
		{id="gold",         display_name="Gold",          weight=40, min=1, max=4,  stackable=true,  rarity=1, item_type=11, grid=Vector2i(1,1), desc="Coins.",             nutrition=0.0, damage_bonus=0, attack_speed=1.0, weapon_visual=""},
		{id="health_potion",display_name="Health Potion", weight=20, min=1, max=1,  stackable=false, rarity=0, item_type=8,  grid=Vector2i(1,1), desc="Restores 10 HP.",    nutrition=0.0, damage_bonus=0, attack_speed=1.0, weapon_visual=""},
		{id="bread",        display_name="Bread",         weight=15, min=1, max=1,  stackable=false, rarity=0, item_type=9,  grid=Vector2i(1,1), desc="Restores 30 hunger.",nutrition=30.0,damage_bonus=0, attack_speed=1.0, weapon_visual=""},
		{id="water_flask",  display_name="Water Flask",   weight=10, min=1, max=1,  stackable=false, rarity=0, item_type=10, grid=Vector2i(1,1), desc="Restores 40 thirst.",nutrition=40.0,damage_bonus=0, attack_speed=1.0, weapon_visual=""},
		{id="lockpick",     display_name="Lockpick",      weight=10, min=1, max=2,  stackable=true,  rarity=0, item_type=11, grid=Vector2i(1,1), desc="A thin metal pick for opening locks.", nutrition=0.0, damage_bonus=0, attack_speed=1.0, weapon_visual=""},
		{id="nothing",      display_name="",              weight=15, min=0, max=0,  stackable=false, rarity=0, item_type=11, grid=Vector2i(1,1), desc="",                   nutrition=0.0, damage_bonus=0, attack_speed=1.0, weapon_visual=""},
	],
	"goblin": [
		{id="gold",         display_name="Gold",          weight=35, min=2, max=6,  stackable=true,  rarity=1, item_type=11, grid=Vector2i(1,1), desc="Coins.",             nutrition=0.0, damage_bonus=0, attack_speed=1.0, weapon_visual=""},
		{id="health_potion",display_name="Health Potion", weight=20, min=1, max=1,  stackable=false, rarity=0, item_type=8,  grid=Vector2i(1,1), desc="Restores 10 HP.",    nutrition=0.0, damage_bonus=0, attack_speed=1.0, weapon_visual=""},
		{id="dagger",       display_name="Rusty Dagger",  weight=12, min=1, max=1,  stackable=false, rarity=0, item_type=0,  grid=Vector2i(1,2), desc="Fast but weak. Favoured by goblins.", nutrition=0.0, damage_bonus=1, attack_speed=1.4, weapon_visual="dagger"},
		{id="bread",        display_name="Bread",         weight=13, min=1, max=1,  stackable=false, rarity=0, item_type=9,  grid=Vector2i(1,1), desc="Restores 30 hunger.",nutrition=30.0,damage_bonus=0, attack_speed=1.0, weapon_visual=""},
		{id="lockpick",     display_name="Lockpick",      weight=15, min=1, max=3,  stackable=true,  rarity=0, item_type=11, grid=Vector2i(1,1), desc="A thin metal pick for opening locks.", nutrition=0.0, damage_bonus=0, attack_speed=1.0, weapon_visual=""},
		{id="nothing",      display_name="",              weight=20, min=0, max=0,  stackable=false, rarity=0, item_type=11, grid=Vector2i(1,1), desc="",                   nutrition=0.0, damage_bonus=0, attack_speed=1.0, weapon_visual=""},
	],
	"troll": [
		{id="gold",         display_name="Gold",          weight=25, min=5, max=18, stackable=true,  rarity=1, item_type=11, grid=Vector2i(1,1), desc="Coins.",             nutrition=0.0, damage_bonus=0, attack_speed=1.0, weapon_visual=""},
		{id="health_potion",display_name="Health Potion", weight=20, min=1, max=2,  stackable=false, rarity=0, item_type=8,  grid=Vector2i(1,1), desc="Restores 10 HP.",    nutrition=0.0, damage_bonus=0, attack_speed=1.0, weapon_visual=""},
		{id="mana_potion",  display_name="Mana Potion",   weight=12, min=1, max=1,  stackable=false, rarity=1, item_type=8,  grid=Vector2i(1,1), desc="Restores 8 Mana.",   nutrition=0.0, damage_bonus=0, attack_speed=1.0, weapon_visual=""},
		{id="war_axe",      display_name="War Axe",       weight=8,  min=1, max=1,  stackable=false, rarity=1, item_type=0,  grid=Vector2i(1,3), desc="Heavy and brutal. High damage, slow swing.", nutrition=0.0, damage_bonus=4, attack_speed=0.65, weapon_visual="axe"},
		{id="bread",        display_name="Bread",         weight=15, min=1, max=1,  stackable=false, rarity=0, item_type=9,  grid=Vector2i(1,1), desc="Restores 30 hunger.",nutrition=30.0,damage_bonus=0, attack_speed=1.0, weapon_visual=""},
		{id="nothing",      display_name="",              weight=20, min=0, max=0,  stackable=false, rarity=0, item_type=11, grid=Vector2i(1,1), desc="",                   nutrition=0.0, damage_bonus=0, attack_speed=1.0, weapon_visual=""},
	],
	"bat": [
		{id="nothing",      display_name="",              weight=55, min=0, max=0,  stackable=false, rarity=0, item_type=11, grid=Vector2i(1,1), desc="",                   nutrition=0.0, damage_bonus=0, attack_speed=1.0, weapon_visual=""},
		{id="gold",         display_name="Gold",          weight=35, min=1, max=3,  stackable=true,  rarity=1, item_type=11, grid=Vector2i(1,1), desc="Coins.",             nutrition=0.0, damage_bonus=0, attack_speed=1.0, weapon_visual=""},
		{id="water_flask",  display_name="Water Flask",   weight=10, min=1, max=1,  stackable=false, rarity=0, item_type=10, grid=Vector2i(1,1), desc="Restores 40 thirst.",nutrition=40.0,damage_bonus=0, attack_speed=1.0, weapon_visual=""},
	],
}

const CLASS_STATS := {
	"fighter": {"health": 30, "strength": 8, "dexterity": 5, "constitution": 8, "magic": 2},
	"thief":   {"health": 20, "strength": 5, "dexterity": 9, "constitution": 5, "magic": 3},
	"wizard":  {"health": 10, "strength": 3, "dexterity": 5, "constitution": 4, "magic": 10},
}

var player_name:    String         = ""
var selected_class: String         = ""
var stats:          Resource       = null
var inventory:      Resource       = null
var equipment:      Resource       = null
var player_node:    Node           = null
var lockpick_skill = preload("res://scripts/resources/lockpick_skill.gd").new()

var dungeon_rooms:     Array = []
var dungeon_corridors: Array = []

var bank_items: Array = []

var player_health:  float = -1.0
var player_mana:    float = 0.0
var player_stamina: float = 100.0
var player_hunger:  float = 100.0
var player_thirst:  float = 100.0

# ── Floor scaling ─────────────────────────────────────────────────────────────
func get_floor_scale() -> float:
	return 1.0 + float(current_floor) * 0.15

# ── Floor transition ──────────────────────────────────────────────────────────
func begin_floor_transition() -> void:
	var p: Node = player_node
	if p:
		player_health  = p.health
		player_mana    = p.mana
		player_stamina = p.stamina
		player_hunger  = p.hunger
		player_thirst  = p.thirst
	floor_transition_started.emit(current_floor + 1, floor_kills)
	current_floor += 1
	floor_kills    = 0

func do_floor_change() -> void:
	var st: SceneTree = get_tree()
	if st:
		st.change_scene_to_file("res://scenes/levels/dungeon.tscn")

func create_player_stats() -> void:
	var data: Dictionary = CLASS_STATS.get(selected_class, CLASS_STATS["fighter"])
	stats             = PlayerStatsClass.new()
	stats.class_id    = selected_class
	stats.max_health  = data["health"]
	stats.max_mana    = 10
	stats.strength    = data["strength"]
	stats.dexterity   = data["dexterity"]
	stats.constitution = data["constitution"]
	stats.magic       = data["magic"]

	inventory            = InventoryClass.new()
	inventory.max_weight = 20.0 + data["strength"] * 2.0
	equipment            = EquipmentClass.new()

func open_loot_bag(bag: Node) -> void:
	loot_bag_opened.emit(bag)

func drop_item(item: Resource) -> void:
	inventory.remove_item(item)
	if not player_node:
		return
	var offset := Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.3, 0.6))
	spawn_loot_at(player_node.global_position + offset, [item])

func spawn_loot_at(pos: Vector3, loot_items: Array) -> void:
	if not player_node:
		return
	var bag: Node = LootBagScene.instantiate()
	for item in loot_items:
		bag.add_item(item)
	player_node.get_parent().add_child(bag)
	bag.global_position = pos

func roll_loot(table_id: String) -> Array:
	var table: Array = LOOT_TABLES.get(table_id, []) as Array
	if table.is_empty():
		return []
	var total_weight: float = 0.0
	for entry: Dictionary in table:
		total_weight += entry.weight as float
	var roll:    float      = randf() * total_weight
	var running: float      = 0.0
	var chosen:  Dictionary = table[-1]
	for entry: Dictionary in table:
		running += entry.weight as float
		if roll <= running:
			chosen = entry
			break
	if chosen.id == "nothing" or (chosen.min as int) == 0:
		return []
	var it := ItemClass.new()
	it.id              = chosen.id
	it.display_name    = chosen.display_name
	it.stackable       = chosen.stackable
	it.stack_count     = randi_range(chosen.min, chosen.max)
	it.rarity          = chosen.rarity
	it.item_type       = chosen.item_type
	it.grid_size       = chosen.grid
	it.description     = chosen.desc
	it.nutrition       = chosen.get("nutrition", 0.0)
	it.damage_bonus    = int(chosen.get("damage_bonus", 0))
	it.attack_speed_mult = float(chosen.get("attack_speed", 1.0))
	it.weapon_visual_id  = str(chosen.get("weapon_visual", ""))
	it.weight          = 0.1 if it.item_type == 11 else 0.5
	return [it]

func use_item(item: Resource) -> void:
	if not player_node:
		return
	var it := item as Item
	if not it.is_consumable():
		return
	match it.id:
		"health_potion":
			player_node.heal(10.0)
			inventory.remove_item(item)
		"mana_potion":
			player_node.mana = minf(player_node.mana + 8.0, player_node.max_mana)
			player_mana_changed.emit(player_node.mana, player_node.max_mana)
			inventory.remove_item(item)
		"bandage":
			_use_bandage()
			inventory.remove_item(item)
		"bread", "mushroom", "meat":
			if player_node.has_method("eat"):
				player_node.eat(it.nutrition if "nutrition" in it else 30.0)
			inventory.remove_item(item)
		"water_flask", "water":
			if player_node.has_method("drink"):
				player_node.drink(it.nutrition if "nutrition" in it else 40.0)
			inventory.remove_item(item)

func _use_bandage() -> void:
	if not player_node or not player_node.get("limbs"):
		return
	var LimbHealthClass := preload("res://scripts/resources/limb_health.gd")
	var limb_health: Resource = player_node.limbs
	var healed := false
	for i in LimbHealthClass.LIMB_NAMES.size():
		var cond: int = limb_health.get_condition(i)
		if cond == LimbHealthClass.Condition.DEEP_CUT or cond == LimbHealthClass.Condition.CUT:
			limb_health.heal_limb(i)
			limb_condition_changed.emit(i, LimbHealthClass.Condition.HEALTHY)
			healed = true
			break
	if not healed:
		pass

# ── Save / Load ───────────────────────────────────────────────────────────────
const SAVE_PATH := "user://save.json"

func save_game() -> void:
	var p: Node = player_node
	var data: Dictionary = {
		"floor":      current_floor,
		"class":      selected_class,
		"name":       player_name,
		"health":     p.health     if p else player_health,
		"mana":       p.mana       if p else player_mana,
		"stamina":    p.stamina    if p else player_stamina,
		"hunger":     p.hunger     if p else player_hunger,
		"thirst":     p.thirst     if p else player_thirst,
		"stats": {
			"level":        stats.level        if stats else 1,
			"xp":           stats.xp           if stats else 0,
			"xp_to_next":   stats.xp_to_next   if stats else 100,
			"strength":     stats.strength     if stats else 0,
			"dexterity":    stats.dexterity    if stats else 0,
			"constitution": stats.constitution if stats else 0,
			"magic":        stats.magic        if stats else 0,
			"max_health":   stats.max_health   if stats else 20,
		},
		"inventory": _serialize_items(inventory.items if inventory else []),
		"bank":      _serialize_item_list(bank_items),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		print("Game saved.")

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var result: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not result is Dictionary:
		return false
	var data: Dictionary = result as Dictionary
	current_floor  = int(data.get("floor",  0))
	selected_class = str(data.get("class",  "fighter"))
	player_name    = str(data.get("name",   "Hero"))
	player_health  = float(data.get("health",  -1.0))
	player_mana    = float(data.get("mana",    0.0))
	player_stamina = float(data.get("stamina", 100.0))
	player_hunger  = float(data.get("hunger",  100.0))
	player_thirst  = float(data.get("thirst",  100.0))

	create_player_stats()
	var sd: Dictionary = data.get("stats", {})
	if stats and not sd.is_empty():
		stats.level        = int(sd.get("level",  1))
		stats.xp           = int(sd.get("xp",     0))
		stats.xp_to_next   = int(sd.get("xp_to_next", 100))
		stats.strength     = int(sd.get("strength",  0))
		stats.dexterity    = int(sd.get("dexterity", 0))
		stats.constitution = int(sd.get("constitution", 0))
		stats.magic        = int(sd.get("magic",   0))
		stats.max_health   = int(sd.get("max_health", 20))

	if not inventory:
		inventory = InventoryClass.new()
	inventory.items.clear()
	_deserialize_items(data.get("inventory", []), inventory)
	bank_items = _deserialize_item_list(data.get("bank", []))
	return true

func _serialize_items(item_entries: Array) -> Array:
	var out: Array = []
	for entry in item_entries:
		var it: Item = entry["item"] as Item
		out.append(_item_to_dict(it, entry["position"]))
	return out

func _serialize_item_list(items: Array) -> Array:
	var out: Array = []
	for item in items:
		out.append(_item_to_dict(item as Item, Vector2i(-1, -1)))
	return out

func _item_to_dict(it: Item, pos: Vector2i) -> Dictionary:
	return {
		"id":             it.id,
		"display_name":   it.display_name,
		"item_type":      it.item_type,
		"rarity":         it.rarity,
		"weight":         it.weight,
		"stackable":      it.stackable,
		"stack_count":    it.stack_count,
		"nutrition":      it.nutrition,
		"description":    it.description,
		"grid_x":         it.grid_size.x,
		"grid_y":         it.grid_size.y,
		"pos_x":          pos.x,
		"pos_y":          pos.y,
		"damage_bonus":   it.damage_bonus,
		"attack_speed":   it.attack_speed_mult,
		"weapon_visual":  it.weapon_visual_id,
		"armor_bonus":    it.armor_bonus,
	}

func _deserialize_items(arr: Array, inv: Resource) -> void:
	for d in arr:
		var it: Item = _dict_to_item(d)
		var pos := Vector2i(int(d.get("pos_x", 0)), int(d.get("pos_y", 0)))
		inv.add_item(it, pos)

func _deserialize_item_list(arr: Array) -> Array:
	var out: Array = []
	for d in arr:
		out.append(_dict_to_item(d))
	return out

func _dict_to_item(d: Dictionary) -> Item:
	var it := ItemClass.new()
	it.id              = str(d.get("id", ""))
	it.display_name    = str(d.get("display_name", ""))
	it.item_type       = int(d.get("item_type", 11))
	it.rarity          = int(d.get("rarity", 0))
	it.weight          = float(d.get("weight", 0.1))
	it.stackable       = bool(d.get("stackable", false))
	it.stack_count     = int(d.get("stack_count", 1))
	it.nutrition       = float(d.get("nutrition", 0.0))
	it.description     = str(d.get("description", ""))
	it.grid_size       = Vector2i(int(d.get("grid_x", 1)), int(d.get("grid_y", 1)))
	it.damage_bonus    = int(d.get("damage_bonus", 0))
	it.attack_speed_mult = float(d.get("attack_speed", 1.0))
	it.weapon_visual_id  = str(d.get("weapon_visual", ""))
	it.armor_bonus     = int(d.get("armor_bonus", 0))
	return it
