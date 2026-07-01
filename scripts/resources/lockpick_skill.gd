extends Resource
class_name LockpickSkill

# Skill level 0–100. XP gained per successful pick.
var level: int   = 0
var xp:    int   = 0

# XP needed to reach next level (grows with level)
func xp_to_next() -> int:
	return 10 + level * 8

# Difficulty tiers: minimum level required and base success chance at min level
enum Difficulty { VERY_EASY, EASY, MEDIUM, HARD, VERY_HARD, MASTERWORK }

const DIFFICULTY_NAMES: Array = ["Very Easy", "Easy", "Medium", "Hard", "Very Hard", "Masterwork"]

const DIFFICULTY_DATA: Array = [
	# { min_level, base_chance at min, chance_per_level above min }
	{min_level = 0,  base_chance = 0.90, per_level = 0.002},  # Very Easy
	{min_level = 5,  base_chance = 0.72, per_level = 0.004},  # Easy
	{min_level = 15, base_chance = 0.55, per_level = 0.005},  # Medium
	{min_level = 30, base_chance = 0.38, per_level = 0.006},  # Hard
	{min_level = 50, base_chance = 0.22, per_level = 0.007},  # Very Hard
	{min_level = 75, base_chance = 0.10, per_level = 0.009},  # Masterwork
]

func can_attempt(diff: Difficulty) -> bool:
	return level >= (DIFFICULTY_DATA[diff] as Dictionary).min_level as int

func success_chance(diff: Difficulty) -> float:
	var data: Dictionary = DIFFICULTY_DATA[diff]
	if level < (data.min_level as int):
		return 0.0
	var above: int = level - (data.min_level as int)
	return clampf((data.base_chance as float) + above * (data.per_level as float), 0.0, 0.98)

func attempt(diff: Difficulty) -> bool:
	if not can_attempt(diff):
		return false
	var success: bool = randf() < success_chance(diff)
	if success:
		_gain_xp(diff)
	return success

func _gain_xp(diff: Difficulty) -> void:
	# Harder locks give more XP
	var xp_reward: int = (diff as int) * 4 + 3
	xp += xp_reward
	while xp >= xp_to_next() and level < 100:
		xp    -= xp_to_next()
		level += 1
