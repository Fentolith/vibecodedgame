extends Resource
class_name Equipment

const SLOTS := ["head", "chest", "legs", "feet", "main_hand", "off_hand", "ring"]

var slots: Dictionary = {
	"head": null,
	"chest": null,
	"legs": null,
	"feet": null,
	"main_hand": null,
	"off_hand": null,
	"ring": null,
}

func equip(slot_name: String, item: Resource) -> bool:
	if slot_name not in slots:
		return false
	slots[slot_name] = item
	return true

func unequip(slot_name: String) -> Resource:
	if slot_name not in slots:
		return null
	var item: Resource = slots[slot_name]
	slots[slot_name] = null
	return item

func get_slot(slot_name: String) -> Resource:
	return slots.get(slot_name, null)
