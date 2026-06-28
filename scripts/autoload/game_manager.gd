extends Node

signal player_health_changed(current: float, maximum: float)
signal player_mana_changed(current: float, maximum: float)
signal player_stamina_changed(current: float, maximum: float)

var current_floor: int = 0
var is_paused: bool = false
