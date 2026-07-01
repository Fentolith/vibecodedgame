extends CharacterBody3D

const ProjectileScene := preload("res://scenes/entities/goblin_projectile.tscn")

enum State { IDLE, ALERT, SHOOT, RETREAT, DEAD }

const DETECTION_RANGE  := 12.0
const PREFERRED_DIST   := 7.0
const RETREAT_DIST     := 3.0
const MOVE_SPEED       := 2.5
const SHOOT_COOLDOWN   := 2.5
const MAX_HEALTH       := 8

var state: State        = State.IDLE
var health: int         = MAX_HEALTH
var shoot_timer: float  = 0.0
var wander_timer: float = 0.0
var wander_target: Vector3 = Vector3.ZERO
var gravity: float      = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var health_bar: Label3D           = $HealthBar
@onready var nav_agent:  NavigationAgent3D = $NavigationAgent3D

func _ready() -> void:
	health_bar.visible = false
	wander_timer       = randf_range(1.0, 3.0)
	call_deferred("_init_wander")

func _init_wander() -> void:
	wander_target             = _random_wander_point()
	nav_agent.target_position = wander_target

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta

	var player: Node3D = GameManager.player_node
	_update_state(player)
	shoot_timer -= delta

	match state:
		State.IDLE:    _do_idle(delta)
		State.ALERT:   _do_alert(player, delta)
		State.SHOOT:   _do_shoot(player, delta)
		State.RETREAT: _do_retreat(player)

	move_and_slide()

func _update_state(player: Node3D) -> void:
	if not player:
		return
	var dist: float = global_position.distance_to(player.global_position)
	if dist <= RETREAT_DIST:
		state = State.RETREAT
	elif dist <= DETECTION_RANGE:
		state = State.ALERT if dist > PREFERRED_DIST else State.SHOOT
	else:
		state = State.IDLE

func _do_idle(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_target = _random_wander_point()
		wander_timer  = randf_range(2.0, 5.0)
	nav_agent.target_position = wander_target
	_move_via_nav(MOVE_SPEED * 0.5)

func _do_alert(player: Node3D, _delta: float) -> void:
	# Strafe sideways while maintaining distance
	if player:
		var to_player: Vector3 = (player.global_position - global_position).normalized()
		var strafe: Vector3    = to_player.cross(Vector3.UP).normalized()
		var target: Vector3    = global_position + to_player * 2.0 + strafe * 1.5
		nav_agent.target_position = target
		_move_via_nav(MOVE_SPEED)

func _do_shoot(player: Node3D, _delta: float) -> void:
	if not player:
		return
	# Face the player
	var flat_dir: Vector3 = (player.global_position - global_position)
	flat_dir.y = 0.0
	if flat_dir.length() > 0.1:
		look_at(global_position + flat_dir, Vector3.UP)

	if shoot_timer <= 0.0:
		shoot_timer = SHOOT_COOLDOWN
		_fire_at(player)

	velocity.x = move_toward(velocity.x, 0.0, MOVE_SPEED)
	velocity.z = move_toward(velocity.z, 0.0, MOVE_SPEED)

func _do_retreat(player: Node3D) -> void:
	if not player:
		return
	var away: Vector3 = (global_position - player.global_position).normalized()
	nav_agent.target_position = global_position + away * 5.0
	_move_via_nav(MOVE_SPEED * 1.2)

func _fire_at(player: Node3D) -> void:
	var proj: Node3D = ProjectileScene.instantiate()
	get_parent().add_child(proj)
	proj.global_position = global_position + Vector3(0, 0.5, 0)
	var dir: Vector3 = (player.global_position + Vector3(0, 0.8, 0) - proj.global_position).normalized()
	proj.direction = dir

func _move_via_nav(speed: float) -> void:
	var next: Vector3    = nav_agent.get_next_path_position()
	var dir: Vector3     = next - global_position
	dir.y = 0.0
	if dir.length() > 0.2:
		dir = dir.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

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
	var loot: Array = GameManager.roll_loot("goblin")
	if not loot.is_empty():
		GameManager.spawn_loot_at(global_position, loot)
	var player: Node = GameManager.player_node
	if player and player.has_method("gain_xp"):
		player.gain_xp(20)
	queue_free()

func _random_wander_point() -> Vector3:
	return global_position + Vector3(randf_range(-5.0, 5.0), 0.0, randf_range(-5.0, 5.0))
