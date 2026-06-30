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

var current_floor: int = 0
var is_paused: bool = false

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

func use_item(item: Resource) -> void:
	if not player_node:
		return
	var it := item as ItemClass
	if it.item_type == ItemClass.ItemType.CONSUMABLE:
		if it.id == "health_potion":
			player_node.heal(10.0)
			inventory.remove_item(item)
			print("Used: %s — healed 10 HP" % it.display_name)
