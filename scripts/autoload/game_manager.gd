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

var current_floor: int = 0
var is_paused: bool = false

# ── Loot tables ──────────────────────────────────────────────────────────────
# Each entry: {id, display_name, weight, min_count, max_count, stackable, rarity, item_type}
const LOOT_TABLES: Dictionary = {
	# item_type integers: 8=CONSUMABLE, 11=MISC  (matches Item.ItemType enum)
	"slime": [
		{id="gold",         display_name="Gold",          weight=55, min=1, max=4,  stackable=true,  rarity=1, item_type=11, grid=Vector2i(1,1), desc="Coins dropped by a slime."},
		{id="health_potion",display_name="Health Potion", weight=25, min=1, max=1,  stackable=false, rarity=0, item_type=8,  grid=Vector2i(1,1), desc="Restores 10 HP."},
		{id="nothing",      display_name="",              weight=20, min=0, max=0,  stackable=false, rarity=0, item_type=11, grid=Vector2i(1,1), desc=""},
	],
}

const CLASS_STATS := {
	"fighter": {"health": 30, "strength": 8, "dexterity": 5, "constitution": 8, "magic": 2},
	"thief": {"health": 20, "strength": 5, "dexterity": 9, "constitution": 5, "magic": 3},
	"wizard": {"health": 10, "strength": 3, "dexterity": 5, "constitution": 4, "magic": 10},
}

var player_name: String = ""
var selected_class: String = ""
var stats: Resource    = null
var inventory: Resource = null
var equipment: Resource = null
var player_node: Node  = null

# Set by dungeon_generator after build; read by map_overlay
var dungeon_rooms:     Array = []
var dungeon_corridors: Array = []

# Player state persisted across floor transitions (-1 = not yet set)
var player_health:  float = -1.0
var player_mana:    float = 0.0
var player_stamina: float = 100.0
var player_hunger:  float = 100.0
var player_thirst:  float = 100.0

func create_player_stats() -> void:
	var data: Dictionary = CLASS_STATS.get(selected_class, CLASS_STATS["fighter"])
	stats = PlayerStatsClass.new()
	stats.class_id = selected_class
	stats.max_health = data["health"]
	stats.max_mana = 10
	stats.strength = data["strength"]
	stats.dexterity = data["dexterity"]
	stats.constitution = data["constitution"]
	stats.magic = data["magic"]

	# Max carry weight scales with STR: base 20 + 2 per STR point
	inventory = InventoryClass.new()
	inventory.max_weight = 20.0 + data["strength"] * 2.0
	equipment = EquipmentClass.new()

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
	var roll: float = randf() * total_weight
	var running: float = 0.0
	var chosen: Dictionary = table[-1]
	for entry: Dictionary in table:
		running += entry.weight as float
		if roll <= running:
			chosen = entry
			break
	if chosen.id == "nothing" or (chosen.min as int) == 0:
		return []
	var it := ItemClass.new()
	it.id           = chosen.id
	it.display_name = chosen.display_name
	it.stackable    = chosen.stackable
	it.stack_count  = randi_range(chosen.min, chosen.max)
	it.rarity       = chosen.rarity
	it.item_type    = chosen.item_type
	it.grid_size    = chosen.grid
	it.description  = chosen.desc
	it.weight       = 0.1
	return [it]

func use_item(item: Resource) -> void:
	if not player_node:
		return
	var it := item as ItemClass
	if it.is_consumable():
		if it.id == "health_potion":
			player_node.heal(10.0)
			inventory.remove_item(item)
			print("Used: %s — healed 10 HP" % it.display_name)
