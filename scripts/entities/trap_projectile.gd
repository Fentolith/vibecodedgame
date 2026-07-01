extends Area3D

const SPEED:    float = 16.0
const LIFETIME: float = 2.8
const DAMAGE:   int   = 4

var direction: Vector3 = Vector3.FORWARD
var _timer:    float   = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask  = 2   # player only
	_build_arrow()
	body_entered.connect(_on_hit)

func _build_arrow() -> void:
	var shaft_mat := StandardMaterial3D.new()
	shaft_mat.albedo_color = Color(0.55, 0.38, 0.18, 1)
	shaft_mat.roughness    = 0.9

	var tip_mat := StandardMaterial3D.new()
	tip_mat.albedo_color = Color(0.70, 0.68, 0.65, 1)
	tip_mat.metallic     = 0.7
	tip_mat.roughness    = 0.3

	# Shaft (thin cylinder)
	var shaft_mi   := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius    = 0.018
	shaft_mesh.bottom_radius = 0.018
	shaft_mesh.height        = 0.42
	shaft_mi.mesh = shaft_mesh
	shaft_mi.set_surface_override_material(0, shaft_mat)
	shaft_mi.rotation_degrees.x = 90.0   # point along -Z (forward)
	add_child(shaft_mi)

	# Tip cone
	var tip_mi   := MeshInstance3D.new()
	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius    = 0.0
	tip_mesh.bottom_radius = 0.028
	tip_mesh.height        = 0.10
	tip_mi.mesh = tip_mesh
	tip_mi.set_surface_override_material(0, tip_mat)
	tip_mi.position           = Vector3(0.0, 0.0, -0.25)
	tip_mi.rotation_degrees.x = 90.0
	add_child(tip_mi)

	# Collision sphere
	var col_shape := CollisionShape3D.new()
	var sphere    := SphereShape3D.new()
	sphere.radius  = 0.06
	col_shape.shape = sphere
	add_child(col_shape)

func _physics_process(delta: float) -> void:
	global_position += direction * SPEED * delta
	_timer += delta
	if _timer >= LIFETIME:
		queue_free()

func _on_hit(body: Node) -> void:
	if body == GameManager.player_node:
		if body.has_method("receive_hit"):
			body.receive_hit(DAMAGE, self)
	queue_free()
