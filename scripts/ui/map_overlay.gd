extends Control

const PADDING:    float = 20.0
const DUNGEON_SZ: float = 80.0
const ZOOM_MIN:   float = 0.5
const ZOOM_MAX:   float = 4.0

# Room-type colours
const COL_FOG      := Color(0.08, 0.08, 0.08, 1.0)
const COL_SPAWN    := Color(0.20, 0.80, 0.20, 1.0)
const COL_EXIT     := Color(0.20, 0.60, 1.00, 1.0)
const COL_COMBAT   := Color(0.85, 0.25, 0.20, 1.0)
const COL_TREASURE := Color(0.90, 0.75, 0.10, 1.0)
const COL_EVENT    := Color(0.70, 0.30, 0.85, 1.0)
const COL_GENERAL  := Color(0.45, 0.40, 0.35, 1.0)
const COL_CORRIDOR := Color(0.25, 0.22, 0.18, 1.0)
const COL_PLAYER   := Color(1.00, 0.10, 0.10, 1.0)

var _base_scale: float = 1.0   # fits full dungeon in screen
var _zoom:       float = 1.0   # extra zoom multiplier
var _pan:        Vector2 = Vector2.ZERO   # pixel offset
var _dragging:   bool    = false
var _drag_start: Vector2 = Vector2.ZERO
var _pan_start:  Vector2 = Vector2.ZERO

func _ready() -> void:
	resized.connect(_reset_view)
	visibility_changed.connect(_on_visibility)
	# Hide the placeholder labels from hud.tscn
	for child in get_children():
		if child is Label:
			child.visible = false

func _reset_view() -> void:
	var usable: float = minf(size.x, size.y) - PADDING * 2.0
	_base_scale = usable / DUNGEON_SZ
	_zoom       = 1.0
	_pan        = Vector2.ZERO

func _on_visibility() -> void:
	if visible:
		_reset_view()
		# Centre view on player
		var player: Node3D = GameManager.player_node
		if player:
			var world_centre := Vector2(
				player.global_position.x * _base_scale,
				player.global_position.z * _base_scale
			)
			_pan = size * 0.5 - world_centre

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
		if (room.rect as Rect2).has_point(Vector2(px, pz)):
			room.explored = true

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging   = true
				_drag_start = mb.position
				_pan_start  = _pan
			else:
				_dragging = false
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(mb.position, 1.15)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(mb.position, 1.0 / 1.15)
	elif event is InputEventMouseMotion and _dragging:
		_pan = _pan_start + (event as InputEventMouseMotion).position - _drag_start

func _zoom_at(mouse_pos: Vector2, factor: float) -> void:
	var new_zoom: float = clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	var actual:   float = new_zoom / _zoom
	_pan    = mouse_pos + ((_pan - mouse_pos) * actual)
	_zoom   = new_zoom

func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.07, 0.95))

	var s: float = _base_scale * _zoom

	# Corridors
	for corr: Dictionary in GameManager.dungeon_corridors:
		var r: Rect2 = corr.rect as Rect2
		draw_rect(_map_rect(r, s), COL_CORRIDOR)

	# Rooms
	for room: Dictionary in GameManager.dungeon_rooms:
		var r: Rect2 = room.rect as Rect2
		if not (room.explored as bool):
			draw_rect(_map_rect(r, s), COL_FOG)
		else:
			draw_rect(_map_rect(r, s), _room_color(room.type as int))

	# Player dot
	var player: Node3D = GameManager.player_node
	if player:
		var wp: Vector2 = _to_screen(player.global_position.x, player.global_position.z, s)
		draw_circle(wp, 5.0, COL_PLAYER)

	# HUD text (drawn last so it's on top)
	draw_string(ThemeDB.fallback_font,
		Vector2(10, 22),
		"Floor %d  —  drag to pan  |  scroll to zoom  |  [M] close" % (GameManager.current_floor + 1),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.75, 0.75))

	# Legend (bottom-right)
	var legend := [
		["Spawn",    COL_SPAWN],
		["Exit",     COL_EXIT],
		["Combat",   COL_COMBAT],
		["Treasure", COL_TREASURE],
		["General",  COL_GENERAL],
	]
	var lx: float = size.x - 110.0
	var ly: float = size.y - float(legend.size()) * 22.0 - 8.0
	for entry in legend:
		draw_rect(Rect2(Vector2(lx, ly), Vector2(14, 14)), entry[1] as Color)
		draw_string(ThemeDB.fallback_font,
			Vector2(lx + 18, ly + 13),
			entry[0] as String,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.85, 0.85))
		ly += 22.0

func _map_rect(r: Rect2, s: float) -> Rect2:
	return Rect2(_to_screen(r.position.x, r.position.y, s),
				 Vector2(r.size.x * s, r.size.y * s))

func _to_screen(wx: float, wz: float, s: float) -> Vector2:
	return _pan + Vector2(wx * s, wz * s)

func _room_color(rtype: int) -> Color:
	match rtype:
		0: return COL_SPAWN
		5: return COL_EXIT
		2: return COL_COMBAT
		3: return COL_TREASURE
		4: return COL_EVENT
		_: return COL_GENERAL
