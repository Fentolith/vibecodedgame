extends Node3D

# Sword mesh runs along Y axis by default (tip up).
# Rotating X by 90 tilts the tip forward away from the player.
const REST_POS := Vector3(0.26, -0.22, -0.48)
const REST_ROT := Vector3(0.0, 0.0, 0.0)

const BLOCK_POS := Vector3(0.0, -0.08, -0.52)
const BLOCK_ROT := Vector3(0.0, 0.0, 0.0)

var _tween: Tween = null

func _ready() -> void:
	position = REST_POS
	rotation_degrees = REST_ROT

func start_charge() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	# Slowly drift right while player holds LMB — released by play_attack
	_tween.tween_property(self, "position",
		REST_POS + Vector3(0.28, 0.08, 0.05), 0.45).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "rotation_degrees",
		REST_ROT + Vector3(0.0, -25.0, 15.0), 0.45).set_ease(Tween.EASE_OUT)

func play_attack(attack_type: String) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()

	match attack_type:

		"QUICK":
			# Fast poke straight forward — snap to rest, dart out, snap back
			_tween.tween_property(self, "position", REST_POS, 0.01)
			_tween.tween_property(self, "position",
				REST_POS + Vector3(0.0, 0.0, -0.55), 0.06).set_ease(Tween.EASE_OUT)
			_tween.tween_property(self, "position",
				REST_POS, 0.08).set_ease(Tween.EASE_IN)

		"REGULAR":
			# Wind up upper-right, slash diagonally down-left
			_tween.tween_property(self, "position",
				REST_POS + Vector3(0.12, 0.18, 0.04), 0.13).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(self, "rotation_degrees",
				REST_ROT + Vector3(0.0, -30.0, 25.0), 0.13).set_ease(Tween.EASE_OUT)
			_tween.tween_property(self, "position",
				REST_POS + Vector3(-0.20, -0.14, -0.06), 0.16).set_ease(Tween.EASE_IN)
			_tween.parallel().tween_property(self, "rotation_degrees",
				REST_ROT + Vector3(0.0, 35.0, -30.0), 0.16).set_ease(Tween.EASE_IN)
			_tween.tween_property(self, "position",
				REST_POS, 0.18).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(self, "rotation_degrees",
				REST_ROT, 0.18).set_ease(Tween.EASE_OUT)

		"HEAVY":
			# Bigger windup, faster heavier slam, slower recovery
			_tween.tween_property(self, "position",
				REST_POS + Vector3(0.18, 0.30, 0.10), 0.22).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(self, "rotation_degrees",
				REST_ROT + Vector3(0.0, -42.0, 38.0), 0.22).set_ease(Tween.EASE_OUT)
			_tween.tween_property(self, "position",
				REST_POS + Vector3(-0.30, -0.22, -0.10), 0.14).set_ease(Tween.EASE_IN)
			_tween.parallel().tween_property(self, "rotation_degrees",
				REST_ROT + Vector3(0.0, 55.0, -45.0), 0.14).set_ease(Tween.EASE_IN)
			_tween.tween_property(self, "position",
				REST_POS, 0.28).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(self, "rotation_degrees",
				REST_ROT, 0.28).set_ease(Tween.EASE_OUT)

func start_block() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", BLOCK_POS, 0.1).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "rotation_degrees",
		BLOCK_ROT, 0.1).set_ease(Tween.EASE_OUT)

func stop_block() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", REST_POS, 0.12).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "rotation_degrees",
		REST_ROT, 0.12).set_ease(Tween.EASE_OUT)
