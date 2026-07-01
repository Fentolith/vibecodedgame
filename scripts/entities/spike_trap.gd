extends StaticBody3D

const DAMAGE        := 5
const EXTEND_TIME   := 0.14
const HOLD_TIME     := 0.40
const RETRACT_TIME  := 0.30
const COOLDOWN_TIME := 4.0

var _spikes:   Array[MeshInstance3D] = []
var _trigger:  Area3D                = null
var _cooldown: float                 = 0.0
var _active:   bool                  = false

func _ready() -> void:
	collision_layer = 1
	collision_mask  = 0

	# Floor plate (walkable surface)
	var plate_mat := StandardMaterial3D.new()
	plate_mat.albedo_color = Color(0.22, 0.18, 0.16, 1)
	plate_mat.roughness    = 0.9
	# Subtle worn-circle to hint at trap
	plate_mat.emission_enabled = true
	plate_mat.emission         = Color(0.35, 0.06, 0.0, 1)
	plate_mat.emission_energy_multiplier = 0.25

	var plate_mi    := MeshInstance3D.new()
	var plate_mesh  := BoxMesh.new()
	plate_mesh.size = Vector3(1.0, 0.06, 1.0)
	plate_mi.mesh   = plate_mesh
	plate_mi.set_surface_override_material(0, plate_mat)
	plate_mi.position = Vector3(0.0, -0.03, 0.0)
	add_child(plate_mi)

	var plate_col   := CollisionShape3D.new()
	var plate_shape := BoxShape3D.new()
	plate_shape.size = Vector3(1.0, 0.06, 1.0)
	plate_col.shape  = plate_shape
	plate_col.position = Vector3(0.0, -0.03, 0.0)
	add_child(plate_col)

	_build_spikes()
	_build_trigger()

func _build_spikes() -> void:
	var spike_mat := StandardMaterial3D.new()
	spike_mat.albedo_color = Color(0.55, 0.52, 0.48, 1)
	spike_mat.metallic     = 0.75
	spike_mat.roughness    = 0.35

	for row in 3:
		for col in 3:
			var spike_mi  := MeshInstance3D.new()
			var cone_mesh := CylinderMesh.new()
			cone_mesh.top_radius    = 0.0
			cone_mesh.bottom_radius = 0.038
			cone_mesh.height        = 0.52
			spike_mi.mesh = cone_mesh
			spike_mi.set_surface_override_material(0, spike_mat)
			spike_mi.position = Vector3(-0.30 + col * 0.30, 0.0, -0.30 + row * 0.30)
			spike_mi.scale.y  = 0.04   # flat initially
			add_child(spike_mi)
			_spikes.append(spike_mi)

func _build_trigger() -> void:
	_trigger = Area3D.new()
	_trigger.collision_layer = 0
	_trigger.collision_mask  = 2   # player layer

	var ts    := CollisionShape3D.new()
	var tshp  := BoxShape3D.new()
	tshp.size = Vector3(0.92, 0.28, 0.92)
	ts.shape  = tshp
	ts.position = Vector3(0.0, 0.14, 0.0)
	_trigger.add_child(ts)
	add_child(_trigger)
	_trigger.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if _active or _cooldown > 0.0:
		return
	if body.has_method("receive_hit"):
		_trigger_spikes(body)

func _trigger_spikes(victim: Node3D) -> void:
	_active = true
	victim.receive_hit(DAMAGE, self)

	var tw := create_tween()
	for sp in _spikes:
		tw.parallel().tween_property(sp, "scale:y", 1.0, EXTEND_TIME).set_ease(Tween.EASE_OUT)
	tw.tween_interval(HOLD_TIME)
	for sp in _spikes:
		tw.parallel().tween_property(sp, "scale:y", 0.04, RETRACT_TIME).set_ease(Tween.EASE_IN)
	tw.tween_callback(_on_retracted)

func _on_retracted() -> void:
	_active   = false
	_cooldown = COOLDOWN_TIME

func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
