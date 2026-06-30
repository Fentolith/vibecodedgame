extends StaticBody3D

var items: Array = []

func add_item(item: Resource) -> void:
	items.append(item)

func remove_item(item: Resource) -> void:
	items.erase(item)
	if items.is_empty():
		queue_free()

func interact() -> void:
	if items.is_empty():
		queue_free()
		return
	GameManager.open_loot_bag(self)
