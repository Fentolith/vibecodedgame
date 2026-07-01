extends Node3D

# ── Rest positions per weapon ─────────────────────────────────────────────────
const FIST_REST    := Vector3(0.20,  -0.30, -0.40)
const SWORD_REST   := Vector3(0.26,  -0.22, -0.48)
const DAGGER_REST  := Vector3(0.22,  -0.24, -0.44)
const AXE_REST     := Vector3(0.28,  -0.22, -0.46)
const STAFF_REST   := Vector3(0.14,  -0.12, -0.55)
const BOW_REST     := Vector3(0.10,  -0.14, -0.52)
const BLOCK_POS    := Vector3(0.0,   -0.08, -0.52)

var _tween:   Tween  = null
var _current: String = "fist"
var _rest_pos: Vector3 = FIST_REST
var _rest_rot: Vector3 = Vector3.ZERO

var _fist_node:   Node3D = null
var _sword_node:  Node3D = null
var _dagger_node: Node3D = null
var _axe_node:    Node3D = null
var _staff_node:  Node3D = null
var _bow_node:    Node3D = null

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Remove any mesh nodes baked into the .tscn (we build everything here)
	for ch in get_children():
		ch.queue_free()
	await get_tree().process_frame
	_fist_node   = _build_fist()
	_sword_node  = _build_sword()
	_dagger_node = _build_dagger()
	_axe_node    = _build_axe()
	_staff_node  = _build_staff()
	_bow_node    = _build_bow()
	set_weapon("fist")

func set_weapon(id: String) -> void:
	_current = id if id != "" else "fist"
	if _fist_node:   _fist_node.visible   = _current == "fist"
	if _sword_node:  _sword_node.visible  = _current == "sword"
	if _dagger_node: _dagger_node.visible = _current == "dagger"
	if _axe_node:    _axe_node.visible    = _current == "axe"
	if _staff_node:  _staff_node.visible  = _current == "staff"
	if _bow_node:    _bow_node.visible    = _current == "bow"
	match _current:
		"fist":   _rest_pos = FIST_REST
		"sword":  _rest_pos = SWORD_REST
		"dagger": _rest_pos = DAGGER_REST
		"axe":    _rest_pos = AXE_REST
		"staff":  _rest_pos = STAFF_REST
		"bow":    _rest_pos = BOW_REST
		_:        _rest_pos = FIST_REST
	_rest_rot = Vector3.ZERO
	position         = _rest_pos
	rotation_degrees = _rest_rot

func get_weapon_id() -> String:
	return _current

# ── Helper: forward-pointing transform (local Y → world -Z) ──────────────────
func _fwd(z: float) -> Transform3D:
	return Transform3D(
		Vector3(1.0, 0.0, 0.0),
		Vector3(0.0, 0.0,-1.0),
		Vector3(0.0, 1.0, 0.0),
		Vector3(0.0, 0.0, z)
	)

func _box_mesh(size: Vector3, color: Color, metallic: float = 0.0, roughness: float = 0.85,
		emission: Color = Color.TRANSPARENT) -> MeshInstance3D:
	var mi   := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh   = mesh
	var mat   := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic     = metallic
	mat.roughness    = roughness
	if emission != Color.TRANSPARENT:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = 1.8
	mi.set_surface_override_material(0, mat)
	return mi

func _sphere_mesh(radius: float, color: Color, metallic: float = 0.0, roughness: float = 0.8,
		emission: Color = Color.TRANSPARENT) -> MeshInstance3D:
	var mi   := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mi.mesh     = mesh
	var mat     := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic     = metallic
	mat.roughness    = roughness
	if emission != Color.TRANSPARENT:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = 1.8
	mi.set_surface_override_material(0, mat)
	return mi

# ── Weapon builders ───────────────────────────────────────────────────────────
func _build_fist() -> Node3D:
	var n     := Node3D.new()
	var skin  := Color(0.87, 0.70, 0.53, 1)
	var cloth := Color(0.28, 0.34, 0.50, 1)
	var cuff  := Color(0.20, 0.25, 0.40, 1)

	# Forearm sleeve extending back from wrist
	var sleeve := _box_mesh(Vector3(0.105, 0.105, 0.30), cloth)
	sleeve.position = Vector3(0.0, 0.0, 0.15)
	n.add_child(sleeve)

	# Cuff detail at wrist
	var cuff_mi := _box_mesh(Vector3(0.115, 0.115, 0.042), cuff)
	cuff_mi.position = Vector3(0.0, 0.0, 0.008)
	n.add_child(cuff_mi)

	# Knuckle block
	var knuckle := _box_mesh(Vector3(0.135, 0.105, 0.115), skin)
	knuckle.position = Vector3(0.0, 0.0, -0.058)
	n.add_child(knuckle)

	# Finger ridge
	var ridge := _box_mesh(Vector3(0.125, 0.022, 0.042), skin.darkened(0.18))
	ridge.position = Vector3(0.0, 0.052, -0.11)
	n.add_child(ridge)

	# Thumb
	var thumb := _box_mesh(Vector3(0.052, 0.075, 0.055), skin)
	thumb.position = Vector3(0.075, 0.018, -0.04)
	n.add_child(thumb)

	add_child(n)
	return n

func _build_sword() -> Node3D:
	var n := Node3D.new()
	var silver := Color(0.80, 0.85, 0.92, 1)
	var gold   := Color(0.82, 0.72, 0.28, 1)
	var wood   := Color(0.36, 0.20, 0.08, 1)

	var blade := _box_mesh(Vector3(0.040, 0.58, 0.040), silver, 0.90, 0.18)
	blade.transform = _fwd(-0.29)
	n.add_child(blade)

	# Blade fuller (groove down center)
	var fuller := _box_mesh(Vector3(0.010, 0.52, 0.010), silver.darkened(0.10), 0.85, 0.22)
	fuller.transform = _fwd(-0.26)
	n.add_child(fuller)

	var guard := _box_mesh(Vector3(0.20, 0.030, 0.040), silver, 0.85, 0.28)
	guard.transform = _fwd(0.012)
	n.add_child(guard)

	# Guard crosspiece ends (small nubs)
	for side: int in [-1, 1]:
		var nub := _box_mesh(Vector3(0.028, 0.052, 0.028), gold, 0.80, 0.35)
		nub.transform = Transform3D(
			Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.0), Vector3(0.0, 1.0, 0.0),
			Vector3(float(side) * 0.104, 0.0, 0.012))
		n.add_child(nub)

	var handle := _box_mesh(Vector3(0.030, 0.22, 0.030), wood, 0.0, 0.90)
	handle.transform = _fwd(0.124)
	n.add_child(handle)

	var pommel := _box_mesh(Vector3(0.062, 0.062, 0.062), silver, 0.80, 0.30)
	pommel.transform = _fwd(0.244)
	n.add_child(pommel)

	add_child(n)
	return n

func _build_dagger() -> Node3D:
	var n     := Node3D.new()
	var steel := Color(0.72, 0.78, 0.88, 1)
	var bone  := Color(0.82, 0.78, 0.68, 1)

	var blade := _box_mesh(Vector3(0.032, 0.32, 0.032), steel, 0.88, 0.14)
	blade.transform = _fwd(-0.16)
	n.add_child(blade)

	# Serrated spine (tiny ridge)
	var spine := _box_mesh(Vector3(0.008, 0.30, 0.018), steel.lightened(0.1), 0.90, 0.12)
	spine.transform = _fwd(-0.16)
	n.add_child(spine)

	var guard := _box_mesh(Vector3(0.14, 0.024, 0.030), steel, 0.82, 0.32)
	guard.transform = _fwd(0.008)
	n.add_child(guard)

	var handle := _box_mesh(Vector3(0.028, 0.15, 0.028), bone, 0.0, 0.80)
	handle.transform = _fwd(0.086)
	n.add_child(handle)

	var pommel := _sphere_mesh(0.028, steel, 0.82, 0.30)
	pommel.position = Vector3(0.0, 0.0, 0.166)
	n.add_child(pommel)

	add_child(n)
	return n

func _build_axe() -> Node3D:
	var n     := Node3D.new()
	var steel := Color(0.58, 0.60, 0.66, 1)
	var wood  := Color(0.42, 0.26, 0.10, 1)

	var handle := _box_mesh(Vector3(0.052, 0.62, 0.052), wood, 0.0, 0.90)
	handle.transform = _fwd(0.048)
	n.add_child(handle)

	# Axe head main body
	var head := _box_mesh(Vector3(0.30, 0.24, 0.058), steel, 0.72, 0.28)
	head.transform = _fwd(-0.26)
	n.add_child(head)

	# Beard (lower extended cutting edge)
	var beard := _box_mesh(Vector3(0.18, 0.10, 0.045), steel.darkened(0.08), 0.70, 0.30)
	beard.transform = Transform3D(
		Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.0), Vector3(0.0, 1.0, 0.0),
		Vector3(-0.055, 0.0, -0.32))
	n.add_child(beard)

	# Poll (back of axe head)
	var poll := _box_mesh(Vector3(0.065, 0.12, 0.048), steel, 0.70, 0.32)
	poll.transform = Transform3D(
		Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.0), Vector3(0.0, 1.0, 0.0),
		Vector3(0.10, 0.0, -0.22))
	n.add_child(poll)

	add_child(n)
	return n

func _build_staff() -> Node3D:
	var n        := Node3D.new()
	var dark_wood := Color(0.20, 0.14, 0.08, 1)
	var magic_col := Color(0.35, 0.60, 1.00, 1)
	var bind_col  := Color(0.55, 0.42, 0.18, 1)

	var rod := _box_mesh(Vector3(0.046, 0.85, 0.046), dark_wood, 0.0, 0.92)
	rod.transform = _fwd(0.045)
	n.add_child(rod)

	# Crystal orb at tip
	var orb := _sphere_mesh(0.072, magic_col, 0.15, 0.08, magic_col * 0.7)
	orb.position = Vector3(0.0, 0.0, -0.40)
	n.add_child(orb)

	# Glow ring under orb
	var ring_mi   := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius    = 0.078
	ring_mesh.bottom_radius = 0.078
	ring_mesh.height        = 0.018
	ring_mi.mesh = ring_mesh
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = magic_col * 0.5
	ring_mat.emission_enabled = true
	ring_mat.emission = magic_col
	ring_mat.emission_energy_multiplier = 2.5
	ring_mi.set_surface_override_material(0, ring_mat)
	ring_mi.position = Vector3(0.0, 0.0, -0.368)
	n.add_child(ring_mi)

	# Binding wraps
	for i in 3:
		var wrap := _box_mesh(Vector3(0.058, 0.058, 0.040), bind_col, 0.22, 0.60)
		wrap.transform = _fwd(-0.06 + float(i) * 0.12)
		n.add_child(wrap)

	add_child(n)
	return n

func _build_bow() -> Node3D:
	var n    := Node3D.new()
	var wood := Color(0.48, 0.30, 0.12, 1)
	var str_col := Color(0.88, 0.84, 0.76, 1)

	# Center grip
	var grip := _box_mesh(Vector3(0.042, 0.22, 0.042), wood.darkened(0.20), 0.0, 0.88)
	grip.position = Vector3(0.0, 0.0, -0.02)
	n.add_child(grip)

	# Upper and lower limbs (angled outward)
	for sign: int in [-1, 1]:
		var limb := _box_mesh(Vector3(0.030, 0.30, 0.026), wood, 0.0, 0.82)
		limb.position         = Vector3(0.0, float(sign) * 0.195, -0.02)
		limb.rotation_degrees = Vector3(float(sign) * 14.0, 0.0, 0.0)
		n.add_child(limb)

		# String half
		var s := _box_mesh(Vector3(0.007, 0.34, 0.007), str_col, 0.0, 0.95)
		s.position         = Vector3(0.0, float(sign) * 0.17, 0.06)
		s.rotation_degrees = Vector3(float(sign) * -8.0, 0.0, 0.0)
		n.add_child(s)

	# Arrow nocked
	var arrow_shaft := _box_mesh(Vector3(0.010, 0.10, 0.010), Color(0.50, 0.32, 0.12, 1))
	arrow_shaft.position = Vector3(0.0, 0.0, 0.04)
	n.add_child(arrow_shaft)

	add_child(n)
	return n

# ── Animations ────────────────────────────────────────────────────────────────
func start_charge() -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	if _current == "fist":
		_tween.tween_property(self, "position",
			_rest_pos + Vector3(0.04, -0.09, 0.14), 0.38).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_property(self, "rotation_degrees",
			_rest_rot + Vector3(10.0, 16.0, 0.0), 0.38).set_ease(Tween.EASE_OUT)
	else:
		_tween.tween_property(self, "position",
			_rest_pos + Vector3(0.28, 0.08, 0.05), 0.45).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_property(self, "rotation_degrees",
			_rest_rot + Vector3(0.0, -25.0, 15.0), 0.45).set_ease(Tween.EASE_OUT)

func play_attack(attack_type: String) -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	match _current:
		"fist":   _anim_fist(attack_type)
		"dagger": _anim_dagger(attack_type)
		"axe":    _anim_axe(attack_type)
		"staff":  _anim_staff(attack_type)
		_:        _anim_sword(attack_type)

func _anim_fist(t: String) -> void:
	match t:
		"QUICK":
			_tween.tween_property(self, "position", _rest_pos, 0.02)
			_tween.tween_property(self, "position",
				_rest_pos + Vector3(0.0, 0.0, -0.38), 0.07).set_ease(Tween.EASE_OUT)
			_tween.tween_property(self, "position",
				_rest_pos, 0.10).set_ease(Tween.EASE_IN)
		"REGULAR":
			_tween.tween_property(self, "position",
				_rest_pos + Vector3(-0.12, 0.08, 0.08), 0.11)
			_tween.parallel().tween_property(self, "rotation_degrees",
				_rest_rot + Vector3(0.0, 22.0, -14.0), 0.11)
			_tween.tween_property(self, "position",
				_rest_pos + Vector3(0.16, -0.05, -0.20), 0.18)
			_tween.parallel().tween_property(self, "rotation_degrees",
				_rest_rot + Vector3(0.0, -32.0, 12.0), 0.18)
			_tween.tween_property(self, "position", _rest_pos, 0.16)
			_tween.parallel().tween_property(self, "rotation_degrees", _rest_rot, 0.16)
		"HEAVY":
			_tween.tween_property(self, "position",
				_rest_pos + Vector3(0.06, -0.18, 0.10), 0.22)
			_tween.parallel().tween_property(self, "rotation_degrees",
				_rest_rot + Vector3(-24.0, 12.0, 0.0), 0.22)
			_tween.tween_property(self, "position",
				_rest_pos + Vector3(-0.04, 0.26, -0.28), 0.15).set_ease(Tween.EASE_IN)
			_tween.parallel().tween_property(self, "rotation_degrees",
				_rest_rot + Vector3(30.0, -14.0, 0.0), 0.15)
			_tween.tween_property(self, "position", _rest_pos, 0.28)
			_tween.parallel().tween_property(self, "rotation_degrees", _rest_rot, 0.28)

func _anim_sword(t: String) -> void:
	match t:
		"QUICK":
			_tween.tween_property(self, "position", _rest_pos, 0.01)
			_tween.tween_property(self, "position",
				_rest_pos + Vector3(0.0, 0.0, -0.55), 0.06).set_ease(Tween.EASE_OUT)
			_tween.tween_property(self, "position",
				_rest_pos, 0.08).set_ease(Tween.EASE_IN)
		"REGULAR":
			_tween.tween_property(self, "position",
				_rest_pos + Vector3(0.12, 0.18, 0.04), 0.13)
			_tween.parallel().tween_property(self, "rotation_degrees",
				_rest_rot + Vector3(0.0, -30.0, 25.0), 0.13)
			_tween.tween_property(self, "position",
				_rest_pos + Vector3(-0.20, -0.14, -0.06), 0.16)
			_tween.parallel().tween_property(self, "rotation_degrees",
				_rest_rot + Vector3(0.0, 35.0, -30.0), 0.16)
			_tween.tween_property(self, "position", _rest_pos, 0.18)
			_tween.parallel().tween_property(self, "rotation_degrees", _rest_rot, 0.18)
		"HEAVY":
			_tween.tween_property(self, "position",
				_rest_pos + Vector3(0.18, 0.30, 0.10), 0.22)
			_tween.parallel().tween_property(self, "rotation_degrees",
				_rest_rot + Vector3(0.0, -42.0, 38.0), 0.22)
			_tween.tween_property(self, "position",
				_rest_pos + Vector3(-0.30, -0.22, -0.10), 0.14).set_ease(Tween.EASE_IN)
			_tween.parallel().tween_property(self, "rotation_degrees",
				_rest_rot + Vector3(0.0, 55.0, -45.0), 0.14)
			_tween.tween_property(self, "position", _rest_pos, 0.28)
			_tween.parallel().tween_property(self, "rotation_degrees", _rest_rot, 0.28)

func _anim_dagger(t: String) -> void:
	match t:
		"QUICK":
			_tween.tween_property(self, "position", _rest_pos, 0.01)
			_tween.tween_property(self, "position",
				_rest_pos + Vector3(0.0, 0.0, -0.48), 0.05).set_ease(Tween.EASE_OUT)
			_tween.tween_property(self, "position", _rest_pos, 0.07)
		"REGULAR":
			_tween.tween_property(self, "position",
				_rest_pos + Vector3(0.10, 0.10, 0.04), 0.09)
			_tween.parallel().tween_property(self, "rotation_degrees",
				_rest_rot + Vector3(0.0, -22.0, 20.0), 0.09)
			_tween.tween_property(self, "position",
				_rest_pos + Vector3(-0.18, -0.12, -0.10), 0.12)
			_tween.parallel().tween_property(self, "rotation_degrees",
				_rest_rot + Vector3(0.0, 30.0, -24.0), 0.12)
			_tween.tween_property(self, "position", _rest_pos, 0.12)
			_tween.parallel().tween_property(self, "rotation_degrees", _rest_rot, 0.12)
		"HEAVY":
			_tween.tween_property(self, "position",
				_rest_pos + Vector3(0.14, 0.22, 0.08), 0.18)
			_tween.parallel().tween_property(self, "rotation_degrees",
				_rest_rot + Vector3(0.0, -38.0, 32.0), 0.18)
			_tween.tween_property(self, "position",
				_rest_pos + Vector3(-0.26, -0.20, -0.10), 0.13)
			_tween.parallel().tween_property(self, "rotation_degrees",
				_rest_rot + Vector3(0.0, 48.0, -40.0), 0.13)
			_tween.tween_property(self, "position", _rest_pos, 0.22)
			_tween.parallel().tween_property(self, "rotation_degrees", _rest_rot, 0.22)

func _anim_axe(t: String) -> void:
	match t:
		"QUICK":
			_tween.tween_property(self, "position",
				_rest_pos + Vector3(0.0, 0.18, 0.06), 0.14)
			_tween.tween_property(self, "position",
				_rest_pos + Vector3(0.0, -0.22, -0.10), 0.20).set_ease(Tween.EASE_IN)
			_tween.tween_property(self, "position", _rest_pos, 0.24)
		"REGULAR":
			_tween.tween_property(self, "position",
				_rest_pos + Vector3(0.22, 0.30, 0.10), 0.22)
			_tween.parallel().tween_property(self, "rotation_degrees",
				_rest_rot + Vector3(0.0, -40.0, 35.0), 0.22)
			_tween.tween_property(self, "position",
				_rest_pos + Vector3(-0.24, -0.20, -0.06), 0.22).set_ease(Tween.EASE_IN)
			_tween.parallel().tween_property(self, "rotation_degrees",
				_rest_rot + Vector3(0.0, 50.0, -42.0), 0.22)
			_tween.tween_property(self, "position", _rest_pos, 0.32)
			_tween.parallel().tween_property(self, "rotation_degrees", _rest_rot, 0.32)
		"HEAVY":
			_tween.tween_property(self, "position",
				_rest_pos + Vector3(0.26, 0.44, 0.14), 0.32)
			_tween.parallel().tween_property(self, "rotation_degrees",
				_rest_rot + Vector3(0.0, -58.0, 50.0), 0.32)
			_tween.tween_property(self, "position",
				_rest_pos + Vector3(-0.32, -0.30, -0.10), 0.17).set_ease(Tween.EASE_IN)
			_tween.parallel().tween_property(self, "rotation_degrees",
				_rest_rot + Vector3(0.0, 68.0, -58.0), 0.17)
			_tween.tween_property(self, "position", _rest_pos, 0.42)
			_tween.parallel().tween_property(self, "rotation_degrees", _rest_rot, 0.42)

func _anim_staff(t: String) -> void:
	match t:
		"QUICK":
			_tween.tween_property(self, "position",
				_rest_pos + Vector3(0.0, 0.0, -0.45), 0.09)
			_tween.tween_property(self, "position", _rest_pos, 0.14)
		"REGULAR":
			_tween.tween_property(self, "position",
				_rest_pos + Vector3(0.12, 0.12, 0.0), 0.14)
			_tween.parallel().tween_property(self, "rotation_degrees",
				_rest_rot + Vector3(0.0, -24.0, 18.0), 0.14)
			_tween.tween_property(self, "position",
				_rest_pos + Vector3(-0.20, -0.10, 0.0), 0.20)
			_tween.parallel().tween_property(self, "rotation_degrees",
				_rest_rot + Vector3(0.0, 30.0, -22.0), 0.20)
			_tween.tween_property(self, "position", _rest_pos, 0.20)
			_tween.parallel().tween_property(self, "rotation_degrees", _rest_rot, 0.20)
		"HEAVY":
			_tween.tween_property(self, "position",
				_rest_pos + Vector3(0.0, 0.32, 0.14), 0.28)
			_tween.tween_property(self, "position",
				_rest_pos + Vector3(0.0, -0.22, -0.14), 0.16).set_ease(Tween.EASE_IN)
			_tween.tween_property(self, "position", _rest_pos, 0.32)

func start_block() -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", BLOCK_POS, 0.10)
	_tween.parallel().tween_property(self, "rotation_degrees", Vector3.ZERO, 0.10)

func stop_block() -> void:
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", _rest_pos, 0.12)
	_tween.parallel().tween_property(self, "rotation_degrees", _rest_rot, 0.12)
