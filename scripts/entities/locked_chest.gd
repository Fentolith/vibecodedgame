extends StaticBody3D

const LootBagScene       := preload("res://scenes/entities/loot_bag.tscn")
const LockpickSkillClass := preload("res://scripts/resources/lockpick_skill.gd")

var difficulty: int = 0
var _loot:   Array  = []
var _opened: bool   = false

var _hinge: Node3D     = null   # lid rotates from this pivot at the back edge
var _glow:  OmniLight3D = null

func _ready() -> void:
	_build_model()

func _build_model() -> void:
	collision_layer = 1
	collision_mask  = 0

	var mat_wood := StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.32, 0.20, 0.08)
	mat_wood.roughness    = 0.92

	var mat_metal := StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.48, 0.40, 0.28)
	mat_metal.metallic     = 0.65
	mat_metal.roughness    = 0.40

	var mat_lock := StandardMaterial3D.new()
	mat_lock.albedo_color = Color(0.55, 0.42, 0.10)
	mat_lock.metallic     = 0.80
	mat_lock.roughness    = 0.30

	var mat_dark := StandardMaterial3D.new()
	mat_dark.albedo_color = Color(0.02, 0.02, 0.02)

	# ── Base body ──────────────────────────────────────────────────────────────
	var base_mi   := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.80, 0.42, 0.56)
	base_mi.mesh   = base_mesh
	base_mi.set_surface_override_material(0, mat_wood)
	base_mi.position = Vector3(0.0, 0.21, 0.0)
	add_child(base_mi)

	# ── Lid hinge node at the back-top edge of the base ───────────────────────
	# Hinge sits at y=0.42 (top of base), z=-0.28 (back edge)
	_hinge = Node3D.new()
	_hinge.position = Vector3(0.0, 0.42, -0.28)
	add_child(_hinge)

	# Lid mesh: offset forward so its back edge aligns with the hinge z=0
	var lid_mi   := MeshInstance3D.new()
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(0.80, 0.08, 0.56)
	lid_mi.mesh   = lid_mesh
	lid_mi.set_surface_override_material(0, mat_wood)
	lid_mi.position = Vector3(0.0, 0.04, 0.28)   # center of lid is 0.28 forward of hinge
	_hinge.add_child(lid_mi)

	# ── Corner metal straps ────────────────────────────────────────────────────
	for xi: int in [-1, 1]:
		for zi: int in [-1, 1]:
			var strap_mi   := MeshInstance3D.new()
			var strap_mesh := BoxMesh.new()
			strap_mesh.size = Vector3(0.06, 0.46, 0.06)
			strap_mi.mesh   = strap_mesh
			strap_mi.set_surface_override_material(0, mat_metal)
			strap_mi.position = Vector3(xi * 0.37, 0.23, zi * 0.25)
			add_child(strap_mi)

	# ── Lock plate ─────────────────────────────────────────────────────────────
	var lock_mi   := MeshInstance3D.new()
	var lock_mesh := BoxMesh.new()
	lock_mesh.size = Vector3(0.12, 0.14, 0.04)
	lock_mi.mesh   = lock_mesh
	lock_mi.set_surface_override_material(0, mat_lock)
	lock_mi.position = Vector3(0.0, 0.26, 0.285)
	add_child(lock_mi)

	var hole_mi   := MeshInstance3D.new()
	var hole_mesh := BoxMesh.new()
	hole_mesh.size = Vector3(0.03, 0.06, 0.05)
	hole_mi.mesh   = hole_mesh
	hole_mi.set_surface_override_material(0, mat_dark)
	hole_mi.position = Vector3(0.0, 0.26, 0.312)
	add_child(hole_mi)

	# ── Collision ──────────────────────────────────────────────────────────────
	var col   := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size   = Vector3(0.80, 0.50, 0.56)
	col.shape    = shape
	col.position = Vector3(0.0, 0.25, 0.0)
	add_child(col)

	# ── Glow ──────────────────────────────────────────────────────────────────
	_glow = OmniLight3D.new()
	_glow.light_color  = Color(0.60, 0.35, 0.05)
	_glow.light_energy = 1.6
	_glow.omni_range   = 2.6
	_glow.position     = Vector3(0.0, 0.55, 0.0)
	add_child(_glow)

	# ── Floating difficulty label ──────────────────────────────────────────────
	var lbl           := Label3D.new()
	lbl.text          = "[Hold F]  " + LockpickSkillClass.DIFFICULTY_NAMES[difficulty] + " Lock"
	lbl.font_size     = 18
	lbl.modulate      = _diff_color()
	lbl.position      = Vector3(0.0, 1.05, 0.0)
	lbl.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	add_child(lbl)

func _diff_color() -> Color:
	match difficulty:
		0: return Color(0.6, 1.0, 0.6)
		1: return Color(0.9, 1.0, 0.5)
		2: return Color(1.0, 0.85, 0.2)
		3: return Color(1.0, 0.50, 0.1)
		4: return Color(1.0, 0.15, 0.1)
		5: return Color(0.80, 0.1, 0.9)
	return Color.WHITE

func add_loot_item(item: Item) -> void:
	_loot.append(item)

func interact() -> void:
	if _opened:
		return
	GameManager.lockpick_chest_opened.emit(self)

func open_success() -> void:
	if _opened:
		return
	_opened = true
	_animate_open()
	if not _loot.is_empty():
		var bag: Node3D = LootBagScene.instantiate()
		get_parent().add_child(bag)
		bag.global_position = global_position + Vector3(0.0, 0.9, 0.0)
		for item in _loot:
			bag.add_item(item)
		await get_tree().create_timer(0.45).timeout
		GameManager.loot_bag_opened.emit(bag)

func _animate_open() -> void:
	# Glow flares gold as lid swings up
	_glow.light_color = Color(1.0, 0.80, 0.15)

	var tw := create_tween()
	tw.set_parallel(true)

	# Lid hinge swings back — negative X rotation opens it
	tw.tween_property(_hinge, "rotation_degrees:x", -105.0, 0.40) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Glow burst then settle to soft gold
	tw.tween_property(_glow, "light_energy", 8.0, 0.18)
	tw.chain().tween_property(_glow, "light_energy", 2.2, 0.55)
