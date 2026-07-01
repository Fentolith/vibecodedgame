extends RigidBody3D

enum State { IDLE, ORBIT, DIVE, RETREAT, DEAD }

const DETECTION_RANGE := 10.0
const ORBIT_RADIUS    := 3.5
const ORBIT_SPEED     := 3.5
const DIVE_SPEED      := 8.0
const RETREAT_SPEED   := 5.0
const IDLE_SPEED      := 1.5
const ATTACK_COOLDOWN := 2.5
const MAX_HEALTH      := 6
const ATTACK_DAMAGE   := 3
const HOVER_HEIGHT    := 1.8
const BOB_AMPLITUDE   := 0.3
const BOB_SPEED       := 2.5
const HIT_RANGE       := 1.2

var state: State         = State.IDLE
var health: int          = MAX_HEALTH
var attack_timer: float  = 0.0
var bob_phase:   float   = 0.0
var _home: Vector3       = Vector3.ZERO
var _orbit_angle: float  = 0.0
var _bounce_timer: float = 0.0

@onready var health_bar: Label3D = $HealthBar

func _ready() -> void:
	health_bar.visible    = false
	gravity_scale         = 0.0
	contact_monitor       = true
	max_contacts_reported = 4
	_home                 = global_position
	bob_phase             = randf_range(0.0, TAU)
	_orbit_angle          = randf_range(0.0, TAU)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	bob_phase     += BOB_SPEED * delta
	attack_timer  -= delta
	_bounce_timer -= delta

	var player: Node3D = GameManager.player_node
	_update_state(player)

	if _bounce_timer > 0.0:
		return

	match state:
		State.IDLE:    _do_idle(delta)
		State.ORBIT:   _do_orbit(player, delta)
		State.DIVE:    _do_dive(player, delta)
		State.RETREAT: _do_retreat(player, delta)

func _update_state(player: Node3D) -> void:
	if not player or state == State.DEAD:
		if state != State.DEAD:
			state = State.IDLE
		return

	var dist: float = global_position.distance_to(player.global_position)

	match state:
		State.IDLE:
			if dist <= DETECTION_RANGE:
				state = State.ORBIT
		State.ORBIT:
			if dist > DETECTION_RANGE * 1.4:
				state = State.IDLE
			elif attack_timer <= 0.0:
				state = State.DIVE
		State.DIVE:
			if dist <= HIT_RANGE:
				if attack_timer <= 0.0:
					attack_timer = ATTACK_COOLDOWN
					if player.has_method("receive_hit"):
						player.receive_hit(ATTACK_DAMAGE, self)
					if randf() < 0.55 and player.has_method("apply_effect"):
						player.apply_effect("poisoned")
				state = State.RETREAT
		State.RETREAT:
			if dist >= ORBIT_RADIUS * 0.85:
				state = State.ORBIT

func _do_idle(delta: float) -> void:
	var target_y: float  = _home.y + HOVER_HEIGHT + sin(bob_phase) * BOB_AMPLITUDE
	var target: Vector3  = Vector3(_home.x, target_y, _home.z)
	var desired: Vector3 = (target - global_position).normalized() * IDLE_SPEED
	linear_velocity      = linear_velocity.lerp(desired, delta * 3.0)

func _do_orbit(player: Node3D, delta: float) -> void:
	if not player:
		return
	_orbit_angle += (ORBIT_SPEED / ORBIT_RADIUS) * delta
	var target_y: float  = player.global_position.y + HOVER_HEIGHT + sin(bob_phase) * BOB_AMPLITUDE
	var orbit_pos: Vector3 = Vector3(
		player.global_position.x + cos(_orbit_angle) * ORBIT_RADIUS,
		target_y,
		player.global_position.z + sin(_orbit_angle) * ORBIT_RADIUS
	)
	var dir: Vector3 = (orbit_pos - global_position).normalized()
	linear_velocity  = linear_velocity.lerp(dir * ORBIT_SPEED, delta * 5.0)

func _do_dive(player: Node3D, delta: float) -> void:
	if not player:
		state = State.ORBIT
		return
	var dir: Vector3 = (player.global_position - global_position).normalized()
	linear_velocity  = linear_velocity.lerp(dir * DIVE_SPEED, delta * 8.0)

func _do_retreat(player: Node3D, delta: float) -> void:
	if not player:
		state = State.IDLE
		return
	var away: Vector3 = (global_position - player.global_position)
	away.y = maxf(away.y, 0.5)
	linear_velocity = linear_velocity.lerp(away.normalized() * RETREAT_SPEED, delta * 6.0)

func _on_body_entered(body: Node) -> void:
	if state == State.DEAD:
		return
	var bounce_dir: Vector3 = (global_position - body.global_position).normalized()
	bounce_dir.y    = absf(bounce_dir.y) + 0.4
	linear_velocity = bounce_dir.normalized() * DIVE_SPEED * 0.7
	_bounce_timer   = 0.3
	if state == State.DIVE:
		state = State.RETREAT

func take_damage(amount: int, _attack_type: String = "") -> void:
	if state == State.DEAD:
		return
	health -= amount
	health_bar.visible = true
	_refresh_health_bar()
	if health <= 0:
		_die()

func _refresh_health_bar() -> void:
	var filled: int = int(ceil(float(max(health, 0)) / MAX_HEALTH * 8))
	var bar := ""
	for i in 8:
		bar += "█" if i < filled else "░"
	health_bar.text = bar

func apply_floor_scale(mult: float) -> void:
	health = int(float(health) * mult)

func _die() -> void:
	state = State.DEAD
	GameManager.floor_kills += 1
	GameManager.total_kills += 1
	var loot: Array = GameManager.roll_loot("bat")
	if not loot.is_empty():
		GameManager.spawn_loot_at(global_position, loot)
	var player: Node = GameManager.player_node
	if player and player.has_method("gain_xp"):
		player.gain_xp(12)
	queue_free()
