extends Node3D

const TrapProjectileScene: PackedScene = preload("res://scenes/entities/trap_projectile.tscn")
const SHOOT_INTERVAL := 3.5
const DETECT_RANGE   := 10.0

var _shoot_timer:  float  = randf_range(0.8, 2.0)   # stagger so traps don't all fire at once
var _detect_area:  Area3D = null
var _eye_light:    OmniLight3D = null
var _armed:        bool   = false

func _ready() -> void:
	_build_model()
	_build_detector()

func _build_model() -> void:
	# Wall bracket / mount
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.30, 0.26, 0.22, 1)
	stone_mat.roughness    = 0.9

	var bracket_mi   := MeshInstance3D.new()
	var bracket_mesh := BoxMesh.new()
	bracket_mesh.size = Vector3(0.18, 0.32, 0.16)
	bracket_mi.mesh   = bracket_mesh
	bracket_mi.set_surface_override_material(0, stone_mat)
	bracket_mi.position = Vector3(0.0, 0.0, 0.08)
	add_child(bracket_mi)

	# Crossbow body
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.36, 0.22, 0.10, 1)
	wood_mat.roughness    = 0.88

	var body_mi   := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.07, 0.07, 0.38)
	body_mi.mesh   = body_mesh
	body_mi.set_surface_override_material(0, wood_mat)
	add_child(body_mi)

	# Bow arms
	var metal_mat := StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.50, 0.46, 0.40, 1)
	metal_mat.metallic     = 0.55
	metal_mat.roughness    = 0.45

	for side: int in [-1, 1]:
		var arm_mi   := MeshInstance3D.new()
		var arm_mesh := BoxMesh.new()
		arm_mesh.size = Vector3(0.30, 0.045, 0.04)
		arm_mi.mesh   = arm_mesh
		arm_mi.set_surface_override_material(0, metal_mat)
		arm_mi.position = Vector3(0.0, float(side) * 0.10, -0.10)
		arm_mi.rotation_degrees = Vector3(0.0, 0.0, float(side) * 12.0)
		add_child(arm_mi)

	# Warning eye-light
	_eye_light              = OmniLight3D.new()
	_eye_light.light_color  = Color(1.0, 0.15, 0.0, 1)
	_eye_light.light_energy = 0.6
	_eye_light.omni_range   = 1.8
	_eye_light.position     = Vector3(0.0, 0.0, -0.18)
	add_child(_eye_light)

func _build_detector() -> void:
	_detect_area                 = Area3D.new()
	_detect_area.collision_layer = 0
	_detect_area.collision_mask  = 2   # player

	var col    := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = DETECT_RANGE
	col.shape     = sphere
	_detect_area.add_child(col)
	add_child(_detect_area)

func _physics_process(delta: float) -> void:
	var player_nearby: bool = _detect_area.get_overlapping_bodies().any(
		func(b: Node3D) -> bool: return b.has_method("receive_hit")
	)

	if player_nearby:
		if not _armed:
			_armed = true
			_eye_light.light_energy = 2.0   # glow brighter when armed
		_shoot_timer -= delta
		if _shoot_timer <= 0.0:
			_shoot_timer = SHOOT_INTERVAL
			_fire()
	else:
		if _armed:
			_armed = false
			_eye_light.light_energy = 0.6

func _fire() -> void:
	var proj: Node3D = TrapProjectileScene.instantiate()
	get_parent().add_child(proj)
	proj.global_position = global_position
	proj.direction       = -global_basis.z   # forward in local space
