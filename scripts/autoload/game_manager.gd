extends Node

const PlayerStatsClass := preload("res://scripts/resources/player_stats.gd")

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
var stats: Resource = null

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
