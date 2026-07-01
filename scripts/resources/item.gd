extends Resource
class_name Item

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
enum ItemType {
	WEAPON_MELEE,
	WEAPON_RANGED,
	ARMOR_HEAD,
	ARMOR_CHEST,
	ARMOR_LEGS,
	ARMOR_FEET,
	SHIELD,
	RING,
	CONSUMABLE,
	FOOD,
	WATER,
	MISC,
}

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D = null
@export var grid_size: Vector2i = Vector2i(1, 1)
@export var weight: float = 0.5
@export var rarity: Rarity = Rarity.COMMON
@export var item_type: ItemType = ItemType.MISC
@export var description: String = ""
@export var stackable: bool = false
@export var stack_count: int = 1
@export var nutrition: float = 0.0   # hunger/thirst restore for food/water
@export var damage_bonus: int = 0
@export var attack_speed_mult: float = 1.0
@export var weapon_visual_id: String = ""   # "fist","sword","dagger","axe","staff","bow"
@export var armor_bonus: int = 0

func get_equipment_slot() -> String:
	match item_type:
		ItemType.WEAPON_MELEE, ItemType.WEAPON_RANGED: return "main_hand"
		ItemType.ARMOR_HEAD:   return "head"
		ItemType.ARMOR_CHEST:  return "chest"
		ItemType.ARMOR_LEGS:   return "legs"
		ItemType.ARMOR_FEET:   return "feet"
		ItemType.SHIELD:       return "off_hand"
		ItemType.RING:         return "ring"
		_:                     return ""

func is_equippable() -> bool:
	return get_equipment_slot() != ""

func is_consumable() -> bool:
	return item_type == ItemType.CONSUMABLE \
		or item_type == ItemType.FOOD \
		or item_type == ItemType.WATER

func get_icon() -> ImageTexture:
	if icon:
		return icon as ImageTexture
	return _placeholder_icon()

func _placeholder_icon() -> ImageTexture:
	var col: Color = _icon_color()
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(col)
	# Darker 1-px border
	var border := col.darkened(0.35)
	for i in 32:
		img.set_pixel(i, 0,  border)
		img.set_pixel(i, 31, border)
		img.set_pixel(0,  i, border)
		img.set_pixel(31, i, border)
	return ImageTexture.create_from_image(img)

func _icon_color() -> Color:
	match item_type:
		ItemType.WEAPON_MELEE:  return Color(0.75, 0.75, 0.82)  # silver
		ItemType.WEAPON_RANGED: return Color(0.65, 0.55, 0.40)  # wood/brown
		ItemType.ARMOR_HEAD:    return Color(0.40, 0.60, 0.80)  # steel blue
		ItemType.ARMOR_CHEST:   return Color(0.35, 0.55, 0.75)
		ItemType.ARMOR_LEGS:    return Color(0.30, 0.50, 0.70)
		ItemType.ARMOR_FEET:    return Color(0.25, 0.45, 0.65)
		ItemType.SHIELD:        return Color(0.50, 0.45, 0.35)
		ItemType.RING:          return Color(0.90, 0.75, 0.20)  # gold
		ItemType.CONSUMABLE:    return Color(0.80, 0.20, 0.20)  # red potion
		ItemType.FOOD:          return Color(0.70, 0.50, 0.20)  # bread
		ItemType.WATER:         return Color(0.20, 0.55, 0.90)  # blue water
		_:                      return Color(0.50, 0.50, 0.50)  # grey misc
