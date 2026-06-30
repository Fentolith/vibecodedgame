extends Resource
class_name Item

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
enum ItemType { WEAPON, ARMOR, CONSUMABLE, MISC }

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
