extends Resource
class_name Inventory

const ItemClass := preload("res://scripts/resources/item.gd")

@export var capacity_slots: Vector2i = Vector2i(8, 6)
@export var max_weight: float = 30.0

# Each entry: { "item": Resource, "position": Vector2i }
var items: Array = []

func current_weight() -> float:
	var total := 0.0
	for entry in items:
		total += (entry["item"] as ItemClass).weight
	return total

func can_add(item: Resource, at_position: Vector2i) -> bool:
	var it := item as ItemClass
	if current_weight() + it.weight > max_weight:
		return false
	for cell in _cells_for(it.grid_size, at_position):
		if not _in_bounds(cell):
			return false
		if get_item_at(cell) != null:
			return false
	return true

func add_item(item: Resource, at_position: Vector2i) -> bool:
	var it := item as ItemClass
	if it.stackable:
		for entry in items:
			var existing := entry["item"] as ItemClass
			if existing.id == it.id:
				existing.stack_count += it.stack_count
				return true
	if not can_add(item, at_position):
		return false
	items.append({"item": item, "position": at_position})
	return true

func remove_item(item: Resource) -> void:
	for i in items.size():
		if items[i]["item"] == item:
			items.remove_at(i)
			return

func get_item_at(grid_pos: Vector2i) -> Resource:
	for entry in items:
		var it := entry["item"] as ItemClass
		var origin: Vector2i = entry["position"]
		if grid_pos in _cells_for(it.grid_size, origin):
			return entry["item"]
	return null

func get_position_of(item: Resource) -> Vector2i:
	for entry in items:
		if entry["item"] == item:
			return entry["position"]
	return Vector2i(-1, -1)

func _cells_for(size: Vector2i, origin: Vector2i) -> Array:
	var cells: Array = []
	for x in size.x:
		for y in size.y:
			cells.append(origin + Vector2i(x, y))
	return cells

func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 \
		and cell.x < capacity_slots.x and cell.y < capacity_slots.y
