extends Control

const LockpickSkillClass := preload("res://scripts/resources/lockpick_skill.gd")

# How long (seconds) to hold F per difficulty tier
const HOLD_TIMES: Array = [1.0, 1.6, 2.2, 3.0, 4.0, 5.5]

var _chest = null   # LockedChest node
var _skill = null   # LockpickSkill instance

var _progress:   float = 0.0
var _flash_time: float = 0.0
var _flash_success: bool = false
var _holding: bool = false   # tracked explicitly via _input

# Ring visual settings
const RING_RADIUS:    float = 48.0
const RING_THICKNESS: float = 10.0
const CENTER: Vector2 = Vector2(0.0, 80.0)   # offset from screen centre

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func open_for_chest(chest: Node, skill) -> void:
	_chest    = chest
	_skill    = skill
	_progress = 0.0
	_flash_time = 0.0
	_holding  = false
	visible   = true

func _process(delta: float) -> void:
	if not visible or _chest == null:
		return

	# Close if chest was freed or player walked away (check every frame is cheap)
	if not is_instance_valid(_chest):
		_close()
		return

	# Flash timer (show result color briefly)
	if _flash_time > 0.0:
		_flash_time -= delta
		queue_redraw()
		if _flash_time <= 0.0:
			if _flash_success:
				_close()
			else:
				_progress = 0.0
				queue_redraw()
		return

	_holding = Input.is_action_pressed("interact")

	if _holding and _can_attempt():
		var hold_time: float = HOLD_TIMES[_chest.difficulty]
		_progress = minf(_progress + delta / hold_time, 1.0)
		queue_redraw()
		if _progress >= 1.0:
			_do_attempt()
	elif not _holding and _progress > 0.0:
		_progress = 0.0
		queue_redraw()

func _can_attempt() -> bool:
	if not _skill or not _chest:
		return false
	return _skill.can_attempt(_chest.difficulty) and _count_picks() > 0

func _do_attempt() -> void:
	_consume_one_pick()
	var success: bool = _skill.attempt(_chest.difficulty)
	_flash_success = success
	_flash_time    = 0.65
	if success:
		_chest.open_success()
	queue_redraw()

func _close() -> void:
	_chest    = null
	_progress = 0.0
	_holding  = false
	visible   = false

# ── Drawing ───────────────────────────────────────────────────────────────────
func _draw() -> void:
	var center: Vector2 = get_viewport_rect().size * 0.5 + CENTER

	# Background circle
	draw_arc(center, RING_RADIUS, 0.0, TAU, 64, Color(0.0, 0.0, 0.0, 0.55), RING_THICKNESS)

	# Filled arc
	var fill_color: Color
	if _flash_time > 0.0:
		var t: float = _flash_time / 0.65
		fill_color = Color(0.2, 1.0, 0.3, t) if _flash_success else Color(1.0, 0.2, 0.2, t)
	else:
		fill_color = _progress_color()

	if _progress > 0.0 or _flash_time > 0.0:
		var end_angle: float = -PI * 0.5 + TAU * _progress
		draw_arc(center, RING_RADIUS,
			-PI * 0.5, end_angle if _flash_time <= 0.0 else PI * 1.5,
			64, fill_color, RING_THICKNESS)

	# Lock icon (simple text in centre)
	var font_size: int = 20
	var icon_str: String = "🔓" if (_flash_time > 0.0 and _flash_success) else "🔒"
	# Fallback to text if emoji not available
	draw_string(ThemeDB.fallback_font, center + Vector2(-font_size * 0.3, font_size * 0.38),
		icon_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 1.0, 1.0, 0.9))

	# Difficulty / status text below ring
	var status_text: String
	if _flash_time > 0.0:
		status_text = "OPENED!" if _flash_success else "FAILED"
	elif not _can_attempt():
		if _skill and _chest:
			var min_lvl: int = (LockpickSkillClass.DIFFICULTY_DATA[_chest.difficulty] as Dictionary).min_level as int
			if _skill.level < min_lvl:
				status_text = "Need level %d" % min_lvl
			else:
				status_text = "No lockpicks"
		else:
			status_text = ""
	else:
		var pct: int = int(_skill.success_chance(_chest.difficulty) * 100.0)
		status_text = "%d%% chance" % pct

	draw_string(ThemeDB.fallback_font,
		center + Vector2(0.0, RING_RADIUS + 22.0),
		status_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14,
		Color(0.9, 0.9, 0.9, 0.85))

	# "Hold F" hint below status (only while not flashing)
	if _flash_time <= 0.0 and _can_attempt():
		draw_string(ThemeDB.fallback_font,
			center + Vector2(0.0, RING_RADIUS + 40.0),
			"Hold F to pick", HORIZONTAL_ALIGNMENT_CENTER, -1, 12,
			Color(0.65, 0.65, 0.65, 0.70))

func _progress_color() -> Color:
	if _progress < 0.5:
		return Color(1.0, 0.85, 0.2)          # yellow
	elif _progress < 0.85:
		return Color(0.6, 1.0, 0.3)           # green
	else:
		return Color(0.3, 1.0, 1.0)           # cyan near completion

# ── Inventory helpers ─────────────────────────────────────────────────────────
func _count_picks() -> int:
	if not GameManager.inventory:
		return 0
	var total: int = 0
	for e in GameManager.inventory.items:
		var it := e["item"] as Item
		if it.id == "lockpick":
			total += it.stack_count
	return total

func _consume_one_pick() -> void:
	if not GameManager.inventory:
		return
	for e in GameManager.inventory.items:
		var it := e["item"] as Item
		if it.id == "lockpick":
			it.stack_count -= 1
			if it.stack_count <= 0:
				GameManager.inventory.remove_item(it)
			return
