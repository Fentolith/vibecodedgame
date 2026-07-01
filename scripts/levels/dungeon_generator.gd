extends Node3D

const SlimeScene:        PackedScene = preload("res://scenes/entities/slime.tscn")
const GoblinScene:       PackedScene = preload("res://scenes/entities/goblin.tscn")
const BatScene:          PackedScene = preload("res://scenes/entities/bat.tscn")
const TorchScene:        PackedScene = preload("res://scenes/entities/torch.tscn")
const TrollScene:        PackedScene = preload("res://scenes/entities/troll.tscn")
const BankChestScene:    PackedScene = preload("res://scenes/entities/bank_chest.tscn")
const ShopNPCScene:      PackedScene = preload("res://scenes/entities/shop_npc.tscn")
const LootBagScene:      PackedScene = preload("res://scenes/entities/loot_bag.tscn")
const TreasureChestScene: PackedScene = preload("res://scenes/entities/treasure_chest.tscn")
const SpikeTrapScene:    PackedScene = preload("res://scenes/entities/spike_trap.tscn")
const ArrowTrapScene:    PackedScene = preload("res://scenes/entities/arrow_trap.tscn")
const LockedChestScene:  PackedScene = preload("res://scenes/entities/locked_chest.tscn")
const ItemClass       := preload("res://scripts/resources/item.gd")
const ExitPortalClass := preload("res://scripts/entities/exit_portal.gd")

enum RoomType { SPAWN, GENERAL, COMBAT, TREASURE, EVENT, EXIT, BOSS }

# ── Layout ────────────────────────────────────────────────────────────────────
const DUNGEON_W : float = 80.0
const DUNGEON_D : float = 80.0
const MIN_PART  : float = 16.0
const MAX_DEPTH : int   = 3
const MIN_ROOM  : float = 6.0
const MAX_ROOM  : float = 18.0
const DOOR_W    : float = 3.2
const CORR_W    : float = 3.2
const WALL_H    : float = 4.0
const CEIL_Y    : float = 4.25
const FLOOR_Y   : float = -0.25

# ── Materials (set by theme) ───────────────────────────────────────────────────
var _mat_floor:   StandardMaterial3D
var _mat_wall:    StandardMaterial3D
var _mat_ceiling: StandardMaterial3D
var _mat_boss:    StandardMaterial3D
var _mat_portal:  StandardMaterial3D

# Current floor number drives visual theme
var _floor_theme: int = 0   # 0=stone 1=damp 2=deep 3=hellish

# ── Data ──────────────────────────────────────────────────────────────────────
var _rooms:     Array = []
var _corridors: Array = []

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_floor_theme = _theme_for_floor(GameManager.current_floor)
	_build_mats()
	var root: Dictionary = _new_part(Rect2(0.0, 0.0, DUNGEON_W, DUNGEON_D))
	_bsp_split(root, 0)
	_punch_corridor_doors()
	_assign_types()
	_spawn_all_geo()
	_move_player_to_spawn()
	GameManager.dungeon_rooms     = _rooms
	GameManager.dungeon_corridors = _corridors
	$NavigationRegion3D.bake_navigation_mesh()
	_spawn_entities()

func _theme_for_floor(f: int) -> int:
	if f < 3:  return 0   # Grimy stone
	if f < 6:  return 1   # Damp / mossy
	if f < 9:  return 2   # Deep stone
	return 3               # Hellish

# ── Materials ─────────────────────────────────────────────────────────────────
func _build_mats() -> void:
	_mat_floor   = StandardMaterial3D.new()
	_mat_wall    = StandardMaterial3D.new()
	_mat_ceiling = StandardMaterial3D.new()
	_mat_boss    = StandardMaterial3D.new()
	_mat_portal  = StandardMaterial3D.new()

	match _floor_theme:
		0:   # Grimy stone
			_mat_floor.albedo_color   = Color(0.15, 0.12, 0.10)
			_mat_wall.albedo_color    = Color(0.20, 0.18, 0.15)
			_mat_ceiling.albedo_color = Color(0.10, 0.08, 0.07)
			_mat_boss.albedo_color    = Color(0.25, 0.05, 0.05)
		1:   # Damp / mossy green
			_mat_floor.albedo_color   = Color(0.10, 0.14, 0.10)
			_mat_wall.albedo_color    = Color(0.12, 0.17, 0.12)
			_mat_ceiling.albedo_color = Color(0.06, 0.09, 0.06)
			_mat_boss.albedo_color    = Color(0.08, 0.18, 0.08)
			# Subtle wet-stone sheen
			_mat_floor.metallic       = 0.15
			_mat_floor.roughness      = 0.60
		2:   # Deep stone / dark amber
			_mat_floor.albedo_color   = Color(0.13, 0.09, 0.07)
			_mat_wall.albedo_color    = Color(0.18, 0.12, 0.09)
			_mat_ceiling.albedo_color = Color(0.08, 0.05, 0.04)
			_mat_boss.albedo_color    = Color(0.22, 0.06, 0.03)
		3:   # Hellish
			_mat_floor.albedo_color   = Color(0.20, 0.05, 0.03)
			_mat_wall.albedo_color    = Color(0.24, 0.06, 0.04)
			_mat_ceiling.albedo_color = Color(0.14, 0.03, 0.02)
			_mat_boss.albedo_color    = Color(0.30, 0.03, 0.01)
			# Faint lava glow on floor
			_mat_floor.emission_enabled = true
			_mat_floor.emission         = Color(0.45, 0.10, 0.0)
			_mat_floor.emission_energy_multiplier = 0.28

	_mat_floor.roughness   = maxf(_mat_floor.roughness, 0.88) if _floor_theme != 1 else 0.60
	_mat_wall.roughness    = 0.86
	_mat_ceiling.roughness = 0.94
	_mat_boss.roughness    = 0.72

	_mat_portal.albedo_color            = Color(0.0, 0.0, 0.0)
	_mat_portal.emission_enabled        = true
	_mat_portal.emission                = Color(0.3, 0.0, 0.6)
	_mat_portal.emission_energy_multiplier = 3.0
	_mat_portal.roughness               = 0.0
	_mat_portal.metallic                = 0.5

# ── BSP ───────────────────────────────────────────────────────────────────────
func _new_part(r: Rect2) -> Dictionary:
	return {rect = r, left = null, right = null, room = null}

func _bsp_split(node: Dictionary, depth: int) -> void:
	var rect: Rect2  = node.rect
	var can_h: bool  = rect.size.x >= MIN_PART * 2.0
	var can_v: bool  = rect.size.y >= MIN_PART * 2.0

	if depth >= MAX_DEPTH or (not can_h and not can_v):
		node.room = _make_room(rect)
		_rooms.append(node.room)
		return

	var horiz: bool = can_h and (not can_v or randf() < 0.5)

	if horiz:
		var sp: float = randf_range(rect.position.x + MIN_PART, rect.end.x - MIN_PART)
		node.left  = _new_part(Rect2(rect.position, Vector2(sp - rect.position.x, rect.size.y)))
		node.right = _new_part(Rect2(Vector2(sp, rect.position.y), Vector2(rect.end.x - sp, rect.size.y)))
	else:
		var sp: float = randf_range(rect.position.y + MIN_PART, rect.end.y - MIN_PART)
		node.left  = _new_part(Rect2(rect.position, Vector2(rect.size.x, sp - rect.position.y)))
		node.right = _new_part(Rect2(Vector2(rect.position.x, sp), Vector2(rect.size.x, rect.end.y - sp)))

	_bsp_split(node.left,  depth + 1)
	_bsp_split(node.right, depth + 1)
	_connect_sibs(node.left, node.right)

func _make_room(part: Rect2) -> Dictionary:
	var max_w: float = minf(part.size.x - 4.0, MAX_ROOM)
	var max_d: float = minf(part.size.y - 4.0, MAX_ROOM)
	var w: float     = randf_range(MIN_ROOM, maxf(MIN_ROOM, max_w))
	var d: float     = randf_range(MIN_ROOM, maxf(MIN_ROOM, max_d))
	var px: float    = randf_range(part.position.x + 2.0, maxf(part.position.x + 2.0, part.end.x - w - 2.0))
	var pz: float    = randf_range(part.position.y + 2.0, maxf(part.position.y + 2.0, part.end.y - d - 2.0))
	return {rect = Rect2(px, pz, w, d), type = RoomType.GENERAL, doors = [], explored = false}

func _leaf_room(node: Dictionary) -> Dictionary:
	if node.room != null:
		return node.room
	if node.left != null:
		var r: Dictionary = _leaf_room(node.left)
		if not r.is_empty():
			return r
	if node.right != null:
		return _leaf_room(node.right)
	return {}

# ── Corridor connection ────────────────────────────────────────────────────────
func _connect_sibs(na: Dictionary, nb: Dictionary) -> void:
	var ra: Dictionary = _leaf_room(na)
	var rb: Dictionary = _leaf_room(nb)
	if ra.is_empty() or rb.is_empty():
		return

	var ra_rect: Rect2 = ra.rect
	var rb_rect: Rect2 = rb.rect

	var ox0: float    = maxf(ra_rect.position.x, rb_rect.position.x)
	var ox1: float    = minf(ra_rect.end.x,      rb_rect.end.x)
	var overlap_x: bool = ox1 - ox0 >= CORR_W

	var oz0: float    = maxf(ra_rect.position.y, rb_rect.position.y)
	var oz1: float    = minf(ra_rect.end.y,      rb_rect.end.y)
	var overlap_z: bool = oz1 - oz0 >= CORR_W

	if overlap_x:
		var cx: float = (ox0 + ox1) * 0.5
		var z0: float = minf(ra_rect.end.y, rb_rect.end.y)
		var z1: float = maxf(ra_rect.position.y, rb_rect.position.y)
		_corridors.append({rect = Rect2(cx - CORR_W * 0.5, z0, CORR_W, z1 - z0), horizontal = false, walled = false})
		if ra_rect.position.y < rb_rect.position.y:
			_try_door(ra, "S", cx); _try_door(rb, "N", cx)
		else:
			_try_door(ra, "N", cx); _try_door(rb, "S", cx)

	elif overlap_z:
		var cz: float = (oz0 + oz1) * 0.5
		var x0: float = minf(ra_rect.end.x, rb_rect.end.x)
		var x1: float = maxf(ra_rect.position.x, rb_rect.position.x)
		_corridors.append({rect = Rect2(x0, cz - CORR_W * 0.5, x1 - x0, CORR_W), horizontal = true, walled = false})
		if ra_rect.position.x < rb_rect.position.x:
			_try_door(ra, "E", cz); _try_door(rb, "W", cz)
		else:
			_try_door(ra, "W", cz); _try_door(rb, "E", cz)

	else:
		var ca: Vector2 = ra_rect.get_center()
		var cb: Vector2 = rb_rect.get_center()

		if cb.x > ca.x:
			var arm_x0: float = ra_rect.end.x
			var arm_x1: float = cb.x
			if arm_x1 - arm_x0 > 0.2:
				_corridors.append({rect = Rect2(arm_x0, ca.y - CORR_W * 0.5, arm_x1 - arm_x0, CORR_W), horizontal = true, walled = false})
			_try_door(ra, "E", ca.y)
		elif cb.x < ca.x:
			var arm_x0: float = cb.x
			var arm_x1: float = ra_rect.position.x
			if arm_x1 - arm_x0 > 0.2:
				_corridors.append({rect = Rect2(arm_x0, ca.y - CORR_W * 0.5, arm_x1 - arm_x0, CORR_W), horizontal = true, walled = false})
			_try_door(ra, "W", ca.y)

		if ca.y < cb.y:
			var arm_z0: float = ca.y
			var arm_z1: float = rb_rect.position.y
			if arm_z1 - arm_z0 > 0.2:
				_corridors.append({rect = Rect2(cb.x - CORR_W * 0.5, arm_z0, CORR_W, arm_z1 - arm_z0), horizontal = false, walled = false})
			_try_door(rb, "N", cb.x)
		elif ca.y > cb.y:
			var arm_z0: float = rb_rect.end.y
			var arm_z1: float = ca.y
			if arm_z1 - arm_z0 > 0.2:
				_corridors.append({rect = Rect2(cb.x - CORR_W * 0.5, arm_z0, CORR_W, arm_z1 - arm_z0), horizontal = false, walled = false})
			_try_door(rb, "S", cb.x)

func _try_door(room: Dictionary, side: String, pos: float) -> void:
	for d: Dictionary in room.doors:
		if d.side == side and absf((d.pos as float) - pos) < 1.0:
			return
	room.doors.append({side = side, pos = pos})

func _punch_corridor_doors() -> void:
	for corr: Dictionary in _corridors:
		var cr: Rect2  = corr.rect
		var is_h: bool = corr.get("horizontal", cr.size.x >= cr.size.y)
		var ccx: float = cr.get_center().x
		var ccz: float = cr.get_center().y
		for room: Dictionary in _rooms:
			var rr: Rect2 = room.rect
			if not cr.intersects(rr):
				continue
			if is_h:
				if cr.position.x < rr.position.x and cr.end.x > rr.position.x:
					_try_door(room, "W", ccz)
				if cr.end.x > rr.end.x and cr.position.x < rr.end.x:
					_try_door(room, "E", ccz)
			else:
				if cr.position.y < rr.position.y and cr.end.y > rr.position.y:
					_try_door(room, "N", ccx)
				if cr.end.y > rr.end.y and cr.position.y < rr.end.y:
					_try_door(room, "S", ccx)

# ── Room types ─────────────────────────────────────────────────────────────────
func _assign_types() -> void:
	if _rooms.is_empty():
		return
	_rooms[0].type  = RoomType.SPAWN
	_rooms[-1].type = RoomType.EXIT

	var boss_idx:  int   = -1
	var boss_area: float = 0.0
	for i: int in range(1, _rooms.size() - 1):
		var area: float = (_rooms[i].rect as Rect2).get_area()
		if area > boss_area:
			boss_area = area
			boss_idx  = i
	if boss_idx >= 0:
		_rooms[boss_idx].type = RoomType.BOSS

	var event_guaranteed  := false
	var combat_guaranteed := false
	for i: int in range(1, _rooms.size() - 1):
		if i == boss_idx:
			continue
		var r: float = randf()
		if r < 0.30:
			_rooms[i].type = RoomType.COMBAT
			combat_guaranteed = true
		elif r < 0.45:
			_rooms[i].type = RoomType.TREASURE
		elif r < 0.60:
			_rooms[i].type = RoomType.EVENT
			event_guaranteed = true

	if not combat_guaranteed:
		for i: int in range(1, _rooms.size() - 1):
			if i != boss_idx and _rooms[i].type == RoomType.GENERAL:
				_rooms[i].type = RoomType.COMBAT
				break

	if not event_guaranteed:
		for i: int in range(1, _rooms.size() - 1):
			if i != boss_idx and _rooms[i].type == RoomType.GENERAL:
				_rooms[i].type = RoomType.EVENT
				break

# ── Geometry ──────────────────────────────────────────────────────────────────
func _spawn_all_geo() -> void:
	for room: Dictionary in _rooms:
		_spawn_room(room)
	for corr: Dictionary in _corridors:
		_spawn_corridor(corr)

func _spawn_room(room: Dictionary) -> void:
	var rect:  Rect2 = room.rect
	var cx:    float = rect.get_center().x
	var cz:    float = rect.get_center().y
	var W:     float = rect.size.x
	var D:     float = rect.size.y
	var rtype: int   = room.type as int

	var floor_mat: StandardMaterial3D = _mat_boss if rtype == RoomType.BOSS else _mat_floor
	_box(Vector3(cx, FLOOR_Y, cz), Vector3(W, 0.5, D), floor_mat)
	_box(Vector3(cx, CEIL_Y,  cz), Vector3(W, 0.5, D), _mat_ceiling)

	_wall_x(rect.position.x, rect.end.x, rect.position.y, _get_doors(room, "N"))
	_wall_x(rect.position.x, rect.end.x, rect.end.y,      _get_doors(room, "S"))
	_wall_z(rect.end.x,      rect.position.y, rect.end.y, _get_doors(room, "E"))
	_wall_z(rect.position.x, rect.position.y, rect.end.y, _get_doors(room, "W"))

	if rtype == RoomType.BOSS:
		var boss_light          := OmniLight3D.new()
		boss_light.light_color  = _boss_light_color()
		boss_light.light_energy = 7.0
		boss_light.omni_range   = 22.0
		add_child(boss_light)
		boss_light.global_position = Vector3(cx, 3.2, cz)
	else:
		_torch_themed(Vector3(cx, 3.2, cz))
		# Extra corner torches for larger rooms
		if W > 10.0 and D > 10.0:
			_torch_themed(Vector3(rect.position.x + 1.5, 3.2, rect.position.y + 1.5))
			_torch_themed(Vector3(rect.end.x - 1.5,      3.2, rect.position.y + 1.5))
			_torch_themed(Vector3(rect.position.x + 1.5, 3.2, rect.end.y - 1.5))
			_torch_themed(Vector3(rect.end.x - 1.5,      3.2, rect.end.y - 1.5))

	# Ambient room light (theme colored)
	_room_ambient(cx, cz, W, D)

	# Theme-specific floor decorations
	_spawn_floor_deco(cx, cz, W, D, rtype)

func _boss_light_color() -> Color:
	match _floor_theme:
		1: return Color(0.1, 0.8, 0.1)
		2: return Color(0.9, 0.5, 0.1)
		3: return Color(1.0, 0.05, 0.0)
		_: return Color(0.8, 0.1, 0.1)

func _torch_themed(pos: Vector3) -> void:
	var torch: Node3D = TorchScene.instantiate()
	add_child(torch)
	torch.global_position = pos

func _room_ambient(cx: float, cz: float, _w: float, _d: float) -> void:
	var amb := OmniLight3D.new()
	match _floor_theme:
		0: amb.light_color = Color(0.75, 0.52, 0.28); amb.light_energy = 0.5
		1: amb.light_color = Color(0.28, 0.55, 0.35); amb.light_energy = 0.4
		2: amb.light_color = Color(0.72, 0.45, 0.18); amb.light_energy = 0.6
		3: amb.light_color = Color(1.00, 0.25, 0.05); amb.light_energy = 1.1
	amb.omni_range = 22.0
	add_child(amb)
	amb.global_position = Vector3(cx, 3.0, cz)

func _spawn_floor_deco(cx: float, cz: float, w: float, d: float, rtype: int) -> void:
	var half_w: float = w * 0.5 - 1.5
	var half_d: float = d * 0.5 - 1.5

	# Barrels and crates in GENERAL / SPAWN rooms
	if rtype == RoomType.SPAWN or rtype == RoomType.GENERAL:
		if randf() < 0.7:
			_spawn_barrel(Vector3(cx + randf_range(-half_w, half_w), 0.0, cz + randf_range(-half_d, half_d)))
		if randf() < 0.5:
			_spawn_crate(Vector3(cx + randf_range(-half_w, half_w), 0.0, cz + randf_range(-half_d, half_d)))

	# Theme decorations
	match _floor_theme:
		1:  # Damp — puddles
			for _i in randi_range(1, 3):
				_spawn_puddle(Vector3(cx + randf_range(-half_w, half_w), 0.0, cz + randf_range(-half_d, half_d)))
			# Cobwebs in corners
			if randf() < 0.5:
				_spawn_cobweb(Vector3(cx - half_w, CEIL_Y - 0.5, cz - half_d))
		2:  # Deep — stalactites
			if w > 8.0 and d > 8.0:
				for _i in randi_range(1, 4):
					_spawn_stalactite(Vector3(cx + randf_range(-half_w, half_w), 0.0, cz + randf_range(-half_d, half_d)))
		3:  # Hellish — lava cracks + embers
			for _i in randi_range(2, 5):
				_spawn_lava_crack(Vector3(cx + randf_range(-half_w, half_w), 0.0, cz + randf_range(-half_d, half_d)))
			# Ember light
			var ember := OmniLight3D.new()
			ember.light_color  = Color(1.0, 0.30, 0.0)
			ember.light_energy = 1.5
			ember.omni_range   = 4.0
			add_child(ember)
			ember.global_position = Vector3(cx, 0.3, cz)

# ── Prop builders ─────────────────────────────────────────────────────────────
func _spawn_barrel(pos: Vector3) -> void:
	var body := StaticBody3D.new()

	var mat_wood  := StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.38, 0.24, 0.10); mat_wood.roughness = 0.90

	var mat_metal := StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.45, 0.40, 0.35); mat_metal.metallic = 0.55; mat_metal.roughness = 0.45

	var barrel_mi   := MeshInstance3D.new()
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius    = 0.22
	barrel_mesh.bottom_radius = 0.22
	barrel_mesh.height        = 0.56
	barrel_mi.mesh  = barrel_mesh
	barrel_mi.set_surface_override_material(0, mat_wood)
	barrel_mi.position = Vector3(0.0, 0.28, 0.0)
	body.add_child(barrel_mi)

	for i in 2:
		var ring_mi   := MeshInstance3D.new()
		var ring_mesh := CylinderMesh.new()
		ring_mesh.top_radius    = 0.235
		ring_mesh.bottom_radius = 0.235
		ring_mesh.height        = 0.038
		ring_mi.mesh  = ring_mesh
		ring_mi.set_surface_override_material(0, mat_metal)
		ring_mi.position = Vector3(0.0, 0.14 + float(i) * 0.30, 0.0)
		body.add_child(ring_mi)

	var col := CollisionShape3D.new()
	var cs  := CylinderShape3D.new()
	cs.radius = 0.22; cs.height = 0.56
	col.shape  = cs; col.position = Vector3(0.0, 0.28, 0.0)
	body.add_child(col)

	body.collision_layer = 1; body.collision_mask = 0
	body.rotation_degrees.y = randf_range(0.0, 360.0)
	add_child(body)
	body.global_position = pos

func _spawn_crate(pos: Vector3) -> void:
	var body := StaticBody3D.new()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.40, 0.28, 0.14); mat.roughness = 0.94

	var mat_nail := StandardMaterial3D.new()
	mat_nail.albedo_color = Color(0.50, 0.48, 0.44); mat_nail.metallic = 0.6; mat_nail.roughness = 0.4

	var crate_mi   := MeshInstance3D.new()
	var crate_mesh := BoxMesh.new()
	crate_mesh.size = Vector3(0.52, 0.52, 0.52)
	crate_mi.mesh   = crate_mesh
	crate_mi.set_surface_override_material(0, mat)
	crate_mi.position = Vector3(0.0, 0.26, 0.0)
	body.add_child(crate_mi)

	# Cross planks
	for axis: int in [0, 1]:
		var plank_mi   := MeshInstance3D.new()
		var plank_mesh := BoxMesh.new()
		plank_mesh.size = Vector3(0.54, 0.04, 0.04) if axis == 0 else Vector3(0.04, 0.04, 0.54)
		plank_mi.mesh   = plank_mesh
		plank_mi.set_surface_override_material(0, mat_nail)
		plank_mi.position = Vector3(0.0, 0.26, 0.27)
		body.add_child(plank_mi)

	var col := CollisionShape3D.new()
	var cs  := BoxShape3D.new(); cs.size = Vector3(0.52, 0.52, 0.52)
	col.shape  = cs; col.position = Vector3(0.0, 0.26, 0.0)
	body.add_child(col)

	body.collision_layer = 1; body.collision_mask = 0
	body.rotation_degrees.y = randf_range(0.0, 360.0)
	add_child(body)
	body.global_position = pos

func _spawn_puddle(pos: Vector3) -> void:
	var mi       := MeshInstance3D.new()
	var mesh     := CylinderMesh.new()
	mesh.top_radius    = randf_range(0.18, 0.55)
	mesh.bottom_radius = randf_range(0.18, 0.55)
	mesh.height        = 0.018
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color  = Color(0.04, 0.07, 0.10, 0.88)
	mat.metallic      = 0.85
	mat.roughness     = 0.05
	mat.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.set_surface_override_material(0, mat)
	pos.y = FLOOR_Y + 0.26 + 0.012
	mi.position = pos
	add_child(mi)

func _spawn_cobweb(pos: Vector3) -> void:
	var mi   := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(randf_range(0.55, 1.10), randf_range(0.55, 1.10))
	mi.mesh   = mesh
	var mat   := StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 0.82, 0.80, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode    = BaseMaterial3D.CULL_DISABLED
	mi.set_surface_override_material(0, mat)
	mi.position         = pos
	mi.rotation_degrees = Vector3(randf_range(-15.0, 15.0), randf_range(0.0, 360.0), 0.0)
	add_child(mi)

func _spawn_stalactite(pos: Vector3) -> void:
	var mi       := MeshInstance3D.new()
	var mesh     := CylinderMesh.new()
	mesh.top_radius    = randf_range(0.055, 0.12)
	mesh.bottom_radius = 0.008
	mesh.height        = randf_range(0.40, 1.20)
	mi.mesh = mesh
	var mat := _mat_wall.duplicate() as StandardMaterial3D
	mi.set_surface_override_material(0, mat)
	pos.y = CEIL_Y - mesh.height * 0.5 - 0.28
	mi.position = pos
	add_child(mi)

func _spawn_lava_crack(pos: Vector3) -> void:
	var mi   := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(randf_range(0.05, 0.14), 0.018, randf_range(0.30, 0.85))
	mi.mesh   = mesh
	var mat   := StandardMaterial3D.new()
	mat.albedo_color              = Color(1.0, 0.22, 0.0, 1)
	mat.emission_enabled          = true
	mat.emission                  = Color(1.0, 0.35, 0.0)
	mat.emission_energy_multiplier = 5.0
	mi.set_surface_override_material(0, mat)
	pos.y = FLOOR_Y + 0.26 + 0.01
	mi.position         = pos
	mi.rotation_degrees.y = randf_range(0.0, 360.0)
	add_child(mi)

	# Small light from crack
	var glow := OmniLight3D.new()
	glow.light_color  = Color(1.0, 0.35, 0.0)
	glow.light_energy = 0.9
	glow.omni_range   = 2.2
	glow.position     = pos + Vector3(0.0, 0.5, 0.0)
	add_child(glow)

# ── Wall / floor geometry helpers ─────────────────────────────────────────────
func _get_doors(room: Dictionary, side: String) -> Array:
	var out: Array = []
	for d: Dictionary in room.doors:
		if d.side == side:
			out.append(d)
	return out

func _spawn_corridor(corr: Dictionary) -> void:
	var rect: Rect2  = corr.rect
	var cx: float    = rect.get_center().x
	var cz: float    = rect.get_center().y
	var W:  float    = rect.size.x
	var D:  float    = rect.size.y
	var walled: bool = corr.get("walled", true)

	_box(Vector3(cx, FLOOR_Y, cz), Vector3(W, 0.5, D), _mat_floor)
	_box(Vector3(cx, CEIL_Y,  cz), Vector3(W, 0.5, D), _mat_ceiling)

	if not walled:
		return
	var is_h: bool = corr.get("horizontal", W >= D)
	if is_h:
		_wall_x(rect.position.x, rect.end.x, rect.position.y, [])
		_wall_x(rect.position.x, rect.end.x, rect.end.y,      [])
	else:
		_wall_z(rect.end.x,      rect.position.y, rect.end.y, [])
		_wall_z(rect.position.x, rect.position.y, rect.end.y, [])

func _wall_x(x0: float, x1: float, z: float, doors: Array) -> void:
	var gaps: Array = []
	for d: Dictionary in doors:
		var p: float = d.pos as float
		gaps.append({from = p - DOOR_W * 0.5, to = p + DOOR_W * 0.5})
	for seg: Dictionary in _segs(x0, x1, gaps):
		var sw: float = (seg.to as float) - (seg.from as float)
		var sx: float = ((seg.from as float) + (seg.to as float)) * 0.5
		_box(Vector3(sx, WALL_H * 0.5, z), Vector3(sw, WALL_H, 0.5), _mat_wall)

func _wall_z(x: float, z0: float, z1: float, doors: Array) -> void:
	var gaps: Array = []
	for d: Dictionary in doors:
		var p: float = d.pos as float
		gaps.append({from = p - DOOR_W * 0.5, to = p + DOOR_W * 0.5})
	for seg: Dictionary in _segs(z0, z1, gaps):
		var sd: float = (seg.to as float) - (seg.from as float)
		var sz: float = ((seg.from as float) + (seg.to as float)) * 0.5
		_box(Vector3(x, WALL_H * 0.5, sz), Vector3(0.5, WALL_H, sd), _mat_wall)

func _segs(start: float, end: float, gaps: Array) -> Array:
	var cuts: Array = [start]
	for gap: Dictionary in gaps:
		cuts.append(clampf(gap.from as float, start, end))
		cuts.append(clampf(gap.to   as float, start, end))
	cuts.append(end)
	cuts.sort()
	var out: Array = []
	var i: int = 0
	while i + 1 < cuts.size():
		if i % 2 == 0:
			var a: float = cuts[i]   as float
			var b: float = cuts[i+1] as float
			if b - a > 0.1:
				out.append({from = a, to = b})
		i += 1
	return out

func _box(pos: Vector3, sz: Vector3, mat: StandardMaterial3D) -> void:
	var body   := StaticBody3D.new()
	var mi     := MeshInstance3D.new()
	var bm     := BoxMesh.new()
	bm.size    = sz
	mi.mesh    = bm
	mi.set_surface_override_material(0, mat)
	var col    := CollisionShape3D.new()
	var shape  := BoxShape3D.new()
	shape.size = sz
	col.shape  = shape
	body.add_child(mi)
	body.add_child(col)
	add_child(body)
	body.global_position = pos

# ── Exit portal ────────────────────────────────────────────────────────────────
func _spawn_exit_portal(pos: Vector3) -> void:
	var portal: StaticBody3D = StaticBody3D.new()
	portal.set_script(ExitPortalClass)

	var stone_mat          := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.30, 0.28, 0.26, 1)
	stone_mat.roughness    = 0.95

	var portal_mat := StandardMaterial3D.new()
	portal_mat.albedo_color              = Color(0.15, 0.0, 0.35, 1)
	portal_mat.emission_enabled          = true
	portal_mat.emission                  = Color(0.5, 0.0, 1.0, 1)
	portal_mat.emission_energy_multiplier = 3.0

	var lp_mesh := BoxMesh.new(); lp_mesh.size = Vector3(0.40, 2.60, 0.40)
	var lp := MeshInstance3D.new(); lp.mesh = lp_mesh
	lp.set_surface_override_material(0, stone_mat); lp.position = Vector3(-0.75, 1.30, 0.0)

	var rp_mesh := BoxMesh.new(); rp_mesh.size = Vector3(0.40, 2.60, 0.40)
	var rp := MeshInstance3D.new(); rp.mesh = rp_mesh
	rp.set_surface_override_material(0, stone_mat); rp.position = Vector3(0.75, 1.30, 0.0)

	var tb_mesh := BoxMesh.new(); tb_mesh.size = Vector3(1.90, 0.40, 0.40)
	var tb := MeshInstance3D.new(); tb.mesh = tb_mesh
	tb.set_surface_override_material(0, stone_mat); tb.position = Vector3(0.0, 2.60, 0.0)

	var pf_mesh := QuadMesh.new(); pf_mesh.size = Vector2(1.10, 2.20)
	var pf := MeshInstance3D.new(); pf.mesh = pf_mesh
	pf.set_surface_override_material(0, portal_mat); pf.position = Vector3(0.0, 1.10, 0.0)

	for i in 3:
		var st_mesh := BoxMesh.new()
		st_mesh.size = Vector3(1.0 - i * 0.15, 0.08, 0.22)
		var st := MeshInstance3D.new(); st.mesh = st_mesh
		st.set_surface_override_material(0, stone_mat)
		st.position = Vector3(0.0, i * 0.10, -0.10 - i * 0.20)
		portal.add_child(st)

	var col   := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size   = Vector3(1.50, 2.60, 0.60)
	col.shape    = shape; col.position = Vector3(0.0, 1.30, 0.0)

	var label           := Label3D.new()
	label.text          = "[F] DESCEND"
	label.font_size     = 22
	label.modulate      = Color(0.85, 0.55, 1.0, 1)
	label.position      = Vector3(0.0, 3.0, 0.0)
	label.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
	label.double_sided  = true
	label.no_depth_test = true

	var glow          := OmniLight3D.new()
	glow.light_color  = Color(0.45, 0.0, 1.0, 1.0)
	glow.light_energy = 5.0
	glow.omni_range   = 14.0
	glow.position     = Vector3(0.0, 1.2, 0.0)

	portal.add_child(lp); portal.add_child(rp); portal.add_child(tb)
	portal.add_child(pf); portal.add_child(col)
	portal.add_child(label); portal.add_child(glow)
	add_child(portal)
	portal.global_position = pos

# ── Player ────────────────────────────────────────────────────────────────────
func _move_player_to_spawn() -> void:
	if _rooms.is_empty():
		return
	var c: Vector2 = (_rooms[0].rect as Rect2).get_center()
	var player: Node = GameManager.player_node
	if player:
		player.global_position = Vector3(c.x, 1.0, c.y)

# ── Entities ──────────────────────────────────────────────────────────────────
func _spawn_entities() -> void:
	var floor_bonus: int   = GameManager.current_floor
	var fscale: float      = GameManager.get_floor_scale()

	for room: Dictionary in _rooms:
		var c:     Vector2 = (room.rect as Rect2).get_center()
		var cx:    float   = c.x
		var cz:    float   = c.y
		var rtype: int     = room.type as int
		var rrect: Rect2   = room.rect

		if rtype == RoomType.SPAWN:
			var chest: Node3D = BankChestScene.instantiate()
			add_child(chest); chest.global_position = Vector3(cx + 1.5, 0.0, cz + 1.5)
			var shop: Node3D = ShopNPCScene.instantiate()
			add_child(shop); shop.global_position = Vector3(cx - 1.5, 0.0, cz + 1.5)

		elif rtype == RoomType.COMBAT:
			_spawn_slimes(cx, cz, randi_range(1, 3), fscale)
			_spawn_goblins(cx, cz, randi_range(1, 3), fscale)
			_spawn_bats(cx, cz, randi_range(1, 3), fscale)
			# Spike traps in combat rooms
			if randf() < 0.55:
				_spawn_spike_traps(rrect, randi_range(1, 3))
			# Arrow traps on walls
			if randf() < 0.35:
				_spawn_arrow_trap_on_wall(rrect)

		elif rtype == RoomType.BOSS:
			var troll: Node3D = TrollScene.instantiate()
			add_child(troll)
			troll.global_position = Vector3(cx, 1.2, cz)
			if troll.has_method("apply_floor_scale"):
				troll.apply_floor_scale(fscale * 1.5)   # boss is tougher
			if floor_bonus > 0:
				_spawn_goblins(cx, cz, floor_bonus, fscale)
			_torch_themed(Vector3(cx - 3.0, 3.2, cz - 3.0))
			_torch_themed(Vector3(cx + 3.0, 3.2, cz - 3.0))
			_torch_themed(Vector3(cx - 3.0, 3.2, cz + 3.0))
			_torch_themed(Vector3(cx + 3.0, 3.2, cz + 3.0))

		elif rtype == RoomType.TREASURE:
			var tc: Node = TreasureChestScene.instantiate()
			add_child(tc); tc.global_position = Vector3(cx, 0.0, cz)
			var gold = ItemClass.new()
			gold.id           = "gold"; gold.display_name = "Gold"
			gold.stackable    = true
			gold.stack_count  = randi_range(10, 25) + floor_bonus * 5
			gold.rarity       = ItemClass.Rarity.UNCOMMON
			gold.item_type    = ItemClass.ItemType.MISC
			gold.grid_size    = Vector2i(1, 1); gold.weight = 0.01
			gold.description  = "Shiny gold coins."
			tc.add_item(gold)
			var bonus_loot: Array = GameManager.roll_loot("troll")
			for loot_item in bonus_loot:
				tc.add_item(loot_item)
			# 65% chance of an additional locked chest beside the treasure chest
			if randf() < 0.65:
				_spawn_locked_chest(Vector3(cx + 1.2, 0.0, cz - 0.8), floor_bonus)

		elif rtype == RoomType.EXIT:
			_spawn_exit_portal(Vector3(cx, 0.02, cz))

		elif rtype == RoomType.EVENT:
			_spawn_slimes(cx, cz, randi_range(1, 3), fscale)
			_spawn_goblins(cx, cz, randi_range(1, 3), fscale)
			_spawn_bats(cx, cz, randi_range(1, 3), fscale)
			if randf() < 0.40:
				_spawn_arrow_trap_on_wall(rrect)

		elif rtype == RoomType.GENERAL:
			_spawn_slimes(cx, cz, randi_range(1, 3), fscale)
			_spawn_goblins(cx, cz, randi_range(1, 3), fscale)
			_spawn_bats(cx, cz, randi_range(1, 3), fscale)
			# 30% chance of a locked chest in general rooms
			if randf() < 0.30:
				_spawn_locked_chest(Vector3(cx + randf_range(-2.0, 2.0), 0.0, cz + randf_range(-2.0, 2.0)), floor_bonus)

# ── Locked chests ─────────────────────────────────────────────────────────────
func _spawn_locked_chest(pos: Vector3, floor_num: int) -> void:
	var chest: Node3D = LockedChestScene.instantiate()
	add_child(chest)
	chest.global_position = pos

	# Difficulty scales with floor: floors 0-1 → very easy/easy, 2-4 → medium, 5-7 → hard, 8+ → very hard/masterwork
	var max_diff: int = clampi(floor_num / 2, 0, 5)
	chest.difficulty = randi_range(maxi(0, max_diff - 1), max_diff)

	# Loot scales with difficulty
	var diff: int = chest.difficulty
	var gold = ItemClass.new()
	gold.id          = "gold"; gold.display_name = "Gold"
	gold.stackable   = true
	gold.stack_count = (diff + 1) * randi_range(5, 12) + floor_num * 3
	gold.rarity      = ItemClass.Rarity.UNCOMMON
	gold.item_type   = ItemClass.ItemType.MISC
	gold.grid_size   = Vector2i(1, 1); gold.weight = 0.01
	gold.description = "Shiny gold coins."
	chest.add_loot_item(gold)

	# Higher difficulty = better loot
	if diff >= 2:
		var loot: Array = GameManager.roll_loot("troll")
		for item in loot:
			chest.add_loot_item(item)
	if diff >= 4:
		var loot2: Array = GameManager.roll_loot("troll")
		for item in loot2:
			chest.add_loot_item(item)

# ── Trap spawning ─────────────────────────────────────────────────────────────
func _spawn_spike_traps(room_rect: Rect2, count: int) -> void:
	var margin: float = 2.0
	for _i in count:
		var tx: float = randf_range(room_rect.position.x + margin, room_rect.end.x - margin)
		var tz: float = randf_range(room_rect.position.y + margin, room_rect.end.y - margin)
		var trap: Node3D = SpikeTrapScene.instantiate()
		add_child(trap)
		trap.global_position = Vector3(tx, FLOOR_Y + 0.28, tz)

func _spawn_arrow_trap_on_wall(room_rect: Rect2) -> void:
	# Pick a random wall and position
	var side: int = randi() % 4
	var pos: Vector3
	var trap: Node3D = ArrowTrapScene.instantiate()
	match side:
		0:  # North wall
			pos = Vector3(room_rect.get_center().x, 1.8, room_rect.position.y + 0.35)
			trap.rotation_degrees.y = 180.0   # face south
		1:  # South wall
			pos = Vector3(room_rect.get_center().x, 1.8, room_rect.end.y - 0.35)
			trap.rotation_degrees.y = 0.0     # face north
		2:  # East wall
			pos = Vector3(room_rect.end.x - 0.35, 1.8, room_rect.get_center().y)
			trap.rotation_degrees.y = -90.0   # face west
		3:  # West wall
			pos = Vector3(room_rect.position.x + 0.35, 1.8, room_rect.get_center().y)
			trap.rotation_degrees.y = 90.0    # face east
	add_child(trap)
	trap.global_position = pos

# ── Enemy spawning helpers ────────────────────────────────────────────────────
func _spawn_slimes(cx: float, cz: float, count: int, fscale: float) -> void:
	for _i: int in count:
		var slime: Node3D = SlimeScene.instantiate()
		add_child(slime)
		slime.global_position = Vector3(cx + randf_range(-3.0, 3.0), 0.5, cz + randf_range(-3.0, 3.0))
		if fscale > 1.0 and slime.has_method("apply_floor_scale"):
			slime.apply_floor_scale(fscale)

func _spawn_goblins(cx: float, cz: float, count: int, fscale: float) -> void:
	for _i: int in count:
		var goblin: Node3D = GoblinScene.instantiate()
		add_child(goblin)
		goblin.global_position = Vector3(cx + randf_range(-4.0, 4.0), 0.45, cz + randf_range(-4.0, 4.0))
		if fscale > 1.0 and goblin.has_method("apply_floor_scale"):
			goblin.apply_floor_scale(fscale)

func _spawn_bats(cx: float, cz: float, count: int, fscale: float) -> void:
	for _i: int in count:
		var bat: Node3D = BatScene.instantiate()
		add_child(bat)
		bat.global_position = Vector3(cx + randf_range(-3.0, 3.0), 2.0 + randf_range(0.0, 1.0), cz + randf_range(-3.0, 3.0))
		if fscale > 1.0 and bat.has_method("apply_floor_scale"):
			bat.apply_floor_scale(fscale)
