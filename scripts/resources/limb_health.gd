extends Resource
class_name LimbHealth

enum Limb { HEAD, TORSO, LEFT_ARM, RIGHT_ARM, LEFT_LEG, RIGHT_LEG }
enum Condition { HEALTHY, CUT, DEEP_CUT, FRACTURED }

const LIMB_NAMES: Array = ["Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"]

# Weighted chance each limb gets hit (out of 100 total)
const HIT_WEIGHTS: Array = [10, 30, 12, 12, 18, 18]

# condition → status effect to apply on the player
const CONDITION_EFFECTS: Dictionary = {
	Condition.CUT:       "cut",
	Condition.DEEP_CUT:  "deep_cut",
	Condition.FRACTURED: "paralyzed",
}

var conditions: Array = []   # one Condition per Limb (index matches Limb enum)

func _init() -> void:
	conditions.resize(Limb.size())
	conditions.fill(Condition.HEALTHY)

static func roll_injury(incoming_damage: int) -> int:
	# Higher damage = higher chance of injury, returns Limb index or -1
	var chance: float = clampf(float(incoming_damage) * 0.08, 0.0, 0.6)
	if randf() > chance:
		return -1
	# Weighted random limb
	var roll: int = randi_range(0, 99)
	var acc: int  = 0
	for i in HIT_WEIGHTS.size():
		acc += HIT_WEIGHTS[i] as int
		if roll < acc:
			return i
	return 0

func injure(limb_idx: int, incoming_damage: int) -> Condition:
	var current: Condition = conditions[limb_idx]
	var new_cond: Condition
	if current == Condition.HEALTHY:
		new_cond = Condition.CUT if incoming_damage < 5 else Condition.DEEP_CUT
	elif current == Condition.CUT:
		new_cond = Condition.DEEP_CUT
	elif current == Condition.DEEP_CUT:
		new_cond = Condition.FRACTURED
	else:
		new_cond = current   # already fractured — can't get worse
	conditions[limb_idx] = new_cond
	return new_cond

func get_condition(limb_idx: int) -> Condition:
	return conditions[limb_idx]

func heal_limb(limb_idx: int) -> void:
	conditions[limb_idx] = Condition.HEALTHY

func heal_all() -> void:
	conditions.fill(Condition.HEALTHY)
