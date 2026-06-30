extends Node3D

const SlimeScene      := preload("res://scenes/entities/slime.tscn")
const LootBagScene    := preload("res://scenes/entities/loot_bag.tscn")
const ItemClass       := preload("res://scripts/resources/item.gd")
const ExitPortalClass := preload("res://scripts/entities/exit_portal.gd")

enum RoomType { SPAWN, GENERAL, COMBAT, TREASURE, EVENT, EXIT, BOSS }

# ── Layout ───────────────────────────────────────────────────────────────────
const DUNGEON_W  : float = 80.0
const DUNGEON_D  : float = 80.0
const MIN_PART   : float = 16.0
const MAX_DEPTH  : int   = 3
const MIN_ROOM   : float = 6.0
const MAX_ROOM   : float = 18.0
const DOOR_W     : float = 3.2
const CORR_W     : float = 3.2
const WALL_H     : float = 4.0
const CEIL_Y     : float = 4.25
const FLOOR_Y    : float = -0.25

# ── Materials ────────────────────────────────────────────────────────────────
var _mat_floor:   StandardMaterial3D
var _mat_wall:    StandardMaterial3D
var _mat_ceiling: StandardMaterial3D
var _mat_boss:    StandardMaterial3D
var _mat_portal:  StandardMaterial3D

# ── Data ─────────────────────────────────────────────────────────────────────
var _rooms:     Array = []
var _corridors: Array = []

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
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

# ── Materials ────────────────────────────────────────────────────────────────
func _build_mats() -> void:
	_mat_floor = StandardMaterial3D.new()
	_mat_floor.albedo_color = Color(0.15, 0.12, 0.10)
	_mat_floor.roughness    = 0.9

	_mat_wall = StandardMaterial3D.new()
	_mat_wall.albedo_color = Color(0.20, 0.18, 0.15)
	_mat_wall.roughness    = 0.85

	_mat_ceiling = StandardMaterial3D.new()
	_mat_ceiling.albedo_color = Color(0.10, 0.08, 0.07)
	_mat_ceiling.roughness    = 0.95

	_mat_boss = StandardMaterial3D.new()
	_mat_boss.albedo_color = Color(0.25, 0.05, 0.05)
	_mat_boss.roughness    = 0.7

	_mat_portal = StandardMaterial3D.new()
	_mat_portal.albedo_color     = Color(0.0, 0.0, 0.0)
	_mat_portal.emission_enabled = true
	_mat_portal.emission         = Color(0.3, 0.0, 0.6)
	_mat_portal.emission_energy_multiplier = 3.0
	_mat_portal.roughness        = 0.0
	_mat_portal.metallic         = 0.5

# ── BSP ──────────────────────────────────────────────────────────────────────
func _new_part(r: Rect2) -> Dictionary:
	return {rect = r, left = null, right = null, room = null}

func _bsp_split(node: Dictionary, depth: int) -> void:
	var rect: Rect2 = node.rect
	var can_h: bool = rect.size.x >= MIN_PART * 2.0
	var can_v: bool = rect.size.y >= MIN_PART * 2.0

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

# ── Corridor connection ───────────────────────────────────────────────────────
func _connect_sibs(na: Dictionary, nb: Dictionary) -> void:
	var ra: Dictionary = _leaf_room(na)
	var rb: Dictionary = _leaf_room(nb)
	if ra.is_empty() or rb.is_empty():
		return

	var ra_rect: Rect2 = ra.rect
	var rb_rect: Rect2 = rb.rect

	var ox0: float = maxf(ra_rect.position.x, rb_rect.position.x)
	var ox1: float = minf(ra_rect.end.x,      rb_rect.end.x)
	var overlap_x: bool = ox1 - ox0 >= CORR_W

	var oz0: float = maxf(ra_rect.position.y, rb_rect.position.y)
	var oz1: float = minf(ra_rect.end.y,      rb_rect.end.y)
	var overlap_z: bool = oz1 - oz0 >= CORR_W

	if overlap_x:
		var cx: float = (ox0 + ox1) * 0.5
		var z0: float = minf(ra_rect.end.y, rb_rect.end.y)
		var z1: float = maxf(ra_rect.position.y, rb_rect.position.y)
		_corridors.append({rect = Rect2(cx - CORR_W * 0.5, z0, CORR_W, z1 - z0), horizontal = false, walled = false})
		if ra_rect.position.y < rb_rect.position.y:
			_try_door(ra, "S", cx)
			_try_door(rb, "N", cx)
		else:
			_try_door(ra, "N", cx)
			_try_door(rb, "S", cx)

	elif overlap_z:
		var cz: float = (oz0 + oz1) * 0.5
		var x0: float = minf(ra_rect.end.x, rb_rect.end.x)
		var x1: float = maxf(ra_rect.position.x, rb_rect.position.x)
		_corridors.append({rect = Rect2(x0, cz - CORR_W * 0.5, x1 - x0, CORR_W), horizontal = true, walled = false})
		if ra_rect.position.x < rb_rect.position.x:
			_try_door(ra, "E", cz)
			_try_door(rb, "W", cz)
		else:
			_try_door(ra, "W", cz)
			_try_door(rb, "E", cz)

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

# After all corridors are built, punch doors in any room wall that a corridor crosses.
# This fixes straight corridors passing through intermediate rooms and L-arms
# that exit room A through a wall that didn't get a door registered.
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
				# Horizontal corridor may cross room's W or E walls
				if cr.position.x < rr.position.x and cr.end.x > rr.position.x:
					_try_door(room, "W", ccz)
				if cr.end.x > rr.end.x and cr.position.x < rr.end.x:
					_try_door(room, "E", ccz)
			else:
				# Vertical corridor may cross room's N or S walls
				if cr.position.y < rr.position.y and cr.end.y > rr.position.y:
					_try_door(room, "N", ccx)
				if cr.end.y > rr.end.y and cr.position.y < rr.end.y:
					_try_door(room, "S", ccx)

# ── Room types ───────────────────────────────────────────────────────────────
func _assign_types() -> void:
	if _rooms.is_empty():
		return
	_rooms[0].type = RoomType.SPAWN
	_rooms[-1].type = RoomType.EXIT

	# Pick the largest room (excluding spawn and exit) for the boss
	var boss_idx: int = -1
	var boss_area: float = 0.0
	for i: int in range(1, _rooms.size() - 1):
		var area: float = (_rooms[i].rect as Rect2).get_area()
		if area > boss_area:
			boss_area = area
			boss_idx  = i
	if boss_idx >= 0:
		_rooms[boss_idx].type = RoomType.BOSS

	for i: int in range(1, _rooms.size() - 1):
		if i == boss_idx:
			continue
		var r: float = randf()
		if r < 0.30:
			_rooms[i].type = RoomType.COMBAT
		elif r < 0.45:
			_rooms[i].type = RoomType.TREASURE
		elif r < 0.55:
			_rooms[i].type = RoomType.EVENT

# ── Geometry ─────────────────────────────────────────────────────────────────
func _spawn_all_geo() -> void:
	for room: Dictionary in _rooms:
		_spawn_room(room)
	for corr: Dictionary in _corridors:
		_spawn_corridor(corr)

func _spawn_room(room: Dictionary) -> void:
	var rect: Rect2 = room.rect
	var cx: float   = rect.get_center().x
	var cz: float   = rect.get_center().y
	var W:  float   = rect.size.x
	var D:  float   = rect.size.y
	var rtype: int  = room.type as int

	var floor_mat: StandardMaterial3D = _mat_boss if rtype == RoomType.BOSS else _mat_floor
	_box(Vector3(cx, FLOOR_Y, cz), Vector3(W, 0.5, D), floor_mat)
	_box(Vector3(cx, CEIL_Y,  cz), Vector3(W, 0.5, D), _mat_ceiling)

	_wall_x(rect.position.x, rect.end.x, rect.position.y, _get_doors(room, "N"))
	_wall_x(rect.position.x, rect.end.x, rect.end.y,      _get_doors(room, "S"))
	_wall_z(rect.end.x,      rect.position.y, rect.end.y, _get_doors(room, "E"))
	_wall_z(rect.position.x, rect.position.y, rect.end.y, _get_doors(room, "W"))

	if rtype == RoomType.BOSS:
		var boss_light := OmniLight3D.new()
		boss_light.light_color  = Color(0.8, 0.1, 0.1)
		boss_light.light_energy = 6.0
		boss_light.omni_range   = 20.0
		add_child(boss_light)
		boss_light.global_position = Vector3(cx, 3.2, cz)
	else:
		_torch(Vector3(cx, 3.2, cz))

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
	var is_h: bool   = corr.get("horizontal", W >= D)
	var walled: bool = corr.get("walled", true)

	_box(Vector3(cx, FLOOR_Y, cz), Vector3(W, 0.5, D), _mat_floor)
	_box(Vector3(cx, CEIL_Y,  cz), Vector3(W, 0.5, D), _mat_ceiling)

	if not walled:
		return

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
	var body  := StaticBody3D.new()
	var mi    := MeshInstance3D.new()
	var bm    := BoxMesh.new()
	bm.size   = sz
	mi.mesh   = bm
	mi.set_surface_override_material(0, mat)
	var col   := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = sz
	col.shape  = shape
	body.add_child(mi)
	body.add_child(col)
	add_child(body)
	body.global_position = pos

func _torch(pos: Vector3) -> void:
	var light := OmniLight3D.new()
	light.light_color      = Color(1.0, 0.7, 0.3)
	light.light_energy     = 7.0
	light.omni_range       = 14.0
	light.omni_attenuation = 1.2
	add_child(light)
	light.global_position = pos

# ── Exit portal ───────────────────────────────────────────────────────────────
func _spawn_exit_portal(pos: Vector3) -> void:
	var portal: StaticBody3D = StaticBody3D.new()
	portal.set_script(ExitPortalClass)

	# Black glowing box, chest-high so it's obvious
	var box_size := Vector3(1.6, 2.0, 1.6)

	var mi    := MeshInstance3D.new()
	var bm    := BoxMesh.new()
	bm.size   = box_size
	mi.mesh   = bm
	mi.set_surface_override_material(0, _mat_portal)
	mi.position = Vector3(0.0, box_size.y * 0.5, 0.0)

	var col   := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	col.shape  = shape
	col.position = Vector3(0.0, box_size.y * 0.5, 0.0)

	var label          := Label3D.new()
	label.text         = "[F] DESCEND"
	label.font_size    = 28
	label.modulate     = Color(0.85, 0.5, 1.0)
	label.position     = Vector3(0.0, box_size.y + 0.5, 0.0)
	label.billboard    = BaseMaterial3D.BILLBOARD_ENABLED
	label.double_sided = true

	var glow              := OmniLight3D.new()
	glow.light_color      = Color(0.4, 0.0, 0.9)
	glow.light_energy     = 6.0
	glow.omni_range       = 20.0
	glow.position         = Vector3(0.0, box_size.y * 0.5, 0.0)

	portal.add_child(mi)
	portal.add_child(col)
	portal.add_child(label)
	portal.add_child(glow)
	add_child(portal)
	portal.global_position = pos

# ── Player ───────────────────────────────────────────────────────────────────
func _move_player_to_spawn() -> void:
	if _rooms.is_empty():
		return
	var c: Vector2 = (_rooms[0].rect as Rect2).get_center()
	var player: Node = GameManager.player_node
	if player:
		player.global_position = Vector3(c.x, 1.0, c.y)

# ── Entities ─────────────────────────────────────────────────────────────────
func _spawn_entities() -> void:
	var floor_bonus: int = GameManager.current_floor

	for room: Dictionary in _rooms:
		var c:     Vector2 = (room.rect as Rect2).get_center()
		var cx:    float   = c.x
		var cz:    float   = c.y
		var rtype: int     = room.type as int

		if rtype == RoomType.COMBAT:
			var count: int = randi_range(1, 3) + floor_bonus
			_spawn_slimes(cx, cz, count)

		elif rtype == RoomType.BOSS:
			var count: int = 5 + floor_bonus * 2
			_spawn_slimes(cx, cz, count)
			# Extra torches for dramatic effect
			_torch(Vector3(cx - 3.0, 3.2, cz - 3.0))
			_torch(Vector3(cx + 3.0, 3.2, cz - 3.0))
			_torch(Vector3(cx - 3.0, 3.2, cz + 3.0))
			_torch(Vector3(cx + 3.0, 3.2, cz + 3.0))

		elif rtype == RoomType.TREASURE:
			var bag: Node = LootBagScene.instantiate()
			add_child(bag)
			bag.global_position = Vector3(cx, 0.13, cz)
			var gold := ItemClass.new()
			gold.id           = "gold"
			gold.display_name = "Gold"
			gold.stackable    = true
			gold.stack_count  = randi_range(5, 15) + floor_bonus * 3
			gold.rarity       = ItemClass.Rarity.UNCOMMON
			gold.item_type    = ItemClass.ItemType.MISC
			gold.grid_size    = Vector2i(1, 1)
			gold.weight       = 0.01
			gold.description  = "Shiny gold coins."
			bag.add_item(gold)

		elif rtype == RoomType.EXIT:
			# Portal has its own 30-range beacon; just spawn it
			_spawn_exit_portal(Vector3(cx, 0.02, cz))

func _spawn_slimes(cx: float, cz: float, count: int) -> void:
	for _i: int in count:
		var slime: Node3D = SlimeScene.instantiate()
		add_child(slime)
		slime.global_position = Vector3(
			cx + randf_range(-3.0, 3.0),
			0.325,
			cz + randf_range(-3.0, 3.0)
		)
