extends Control

# World-to-map scale: the 80x80 dungeon maps onto the control's size
const PADDING: float = 10.0

var _scale: float = 1.0

# Room-type colours (fog = dark grey)
const COL_FOG      := Color(0.08, 0.08, 0.08, 1.0)
const COL_SPAWN    := Color(0.20, 0.80, 0.20, 1.0)
const COL_EXIT     := Color(0.20, 0.60, 1.00, 1.0)
const COL_COMBAT   := Color(0.85, 0.25, 0.20, 1.0)
const COL_TREASURE := Color(0.90, 0.75, 0.10, 1.0)
const COL_EVENT    := Color(0.70, 0.30, 0.85, 1.0)
const COL_GENERAL  := Color(0.45, 0.40, 0.35, 1.0)
const COL_CORRIDOR := Color(0.25, 0.22, 0.18, 1.0)
const COL_PLAYER   := Color(1.00, 0.10, 0.10, 1.0)

func _ready() -> void:
	# Recalculate scale whenever the control is resized
	resized.connect(_recalc_scale)
	_recalc_scale()

func _recalc_scale() -> void:
	var usable: float = minf(size.x, size.y) - PADDING * 2.0
	_scale = usable / 80.0

func _process(_delta: float) -> void:
	_update_explored()
	queue_redraw()

func _update_explored() -> void:
	var player: Node3D = GameManager.player_node
	if not player:
		return
	var px: float = player.global_position.x
	var pz: float = player.global_position.z
	for room: Dictionary in GameManager.dungeon_rooms:
		if room.explored:
			continue
		var r: Rect2 = room.rect as Rect2
		if r.has_point(Vector2(px, pz)):
			room.explored = true

func _draw() -> void:
	# Dark background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.05, 0.92))

	# Corridors (always draw if any adjacent room explored — keep it simple: draw all)
	for corr: Dictionary in GameManager.dungeon_corridors:
		var r: Rect2 = corr.rect as Rect2
		draw_rect(_world_rect(r), COL_CORRIDOR)

	# Rooms
	for room: Dictionary in GameManager.dungeon_rooms:
		if not (room.explored as bool):
			draw_rect(_world_rect(room.rect as Rect2), COL_FOG)
			continue
		var col: Color = _room_color(room.type as int)
		draw_rect(_world_rect(room.rect as Rect2), col)

	# Player dot
	var player: Node3D = GameManager.player_node
	if player:
		var wp: Vector2 = _world_to_map(player.global_position.x, player.global_position.z)
		draw_circle(wp, 4.0, COL_PLAYER)

func _world_rect(r: Rect2) -> Rect2:
	var tl: Vector2 = _world_to_map(r.position.x, r.position.y)
	return Rect2(tl, Vector2(r.size.x * _scale, r.size.y * _scale))

func _world_to_map(wx: float, wz: float) -> Vector2:
	return Vector2(PADDING + wx * _scale, PADDING + wz * _scale)

func _room_color(rtype: int) -> Color:
	match rtype:
		0: return COL_SPAWN    # SPAWN
		5: return COL_EXIT     # EXIT
		2: return COL_COMBAT   # COMBAT
		3: return COL_TREASURE # TREASURE
		4: return COL_EVENT    # EVENT
		_: return COL_GENERAL  # GENERAL
