extends Node3D

const BASE_ENERGY := 7.0
const FLICKER_SPEED := 8.0
const FLICKER_AMOUNT := 1.2

var _phase: float = 0.0
@onready var _light: OmniLight3D = $OmniLight3D

func _ready() -> void:
	_phase = randf_range(0.0, TAU)

func _process(delta: float) -> void:
	_phase += FLICKER_SPEED * delta
	var flicker: float = sin(_phase) * 0.4 + sin(_phase * 2.3) * 0.3 + sin(_phase * 0.7) * 0.3
	_light.light_energy = BASE_ENERGY + flicker * FLICKER_AMOUNT
