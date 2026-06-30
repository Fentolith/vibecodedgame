extends CharacterBody3D

const ItemClass := preload("res://scripts/resources/item.gd")

enum State { IDLE, ALERT, ATTACK, DEAD }

const IDLE_SPEED       := 1.0
const CHASE_SPEED      := 2.0
const DETECTION_RANGE  := 8.0
const ATTACK_RANGE     := 1.3
const ATTACK_COOLDOWN  := 2.0
const MAX_HEALTH       := 10

var state: State       = State.IDLE
var health: int        = MAX_HEALTH
var attack_timer: float = 0.0
var wander_timer: float = 0.0
var wander_target: Vector3 = Vector3.ZERO
var gravity: float     = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var health_bar: Label3D          = $HealthBar
@onready var nav_agent:  NavigationAgent3D = $NavigationAgent3D

func _ready() -> void:
	health_bar.visible = false
	wander_timer       = randf_range(1.0, 3.0)
	# Defer so global_position is valid after the node is placed in the scene tree
	call_deferred("_init_wander")

func _init_wander() -> void:
	wander_target = _random_wander_point()
	nav_agent.target_position = wander_target

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	var player: Node3D = GameManager.player_node
	_update_state(player)

	match state:
		State.IDLE:   _do_idle(delta)
		State.ALERT:  _do_alert(player)
		State.ATTACK: _do_attack_tick(delta, player)

	move_and_slide()

func _update_state(player: Node3D) -> void:
	if not player:
		return
	var dist: float = global_position.distance_to(player.global_position)
	if dist <= ATTACK_RANGE:
		state = State.ATTACK
	elif dist <= DETECTION_RANGE:
		state = State.ALERT
	else:
		if state == State.ALERT or state == State.ATTACK:
			state = State.IDLE

func _do_idle(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_target = _random_wander_point()
		wander_timer  = randf_range(2.0, 4.0)
	nav_agent.target_position = wander_target
	_move_via_nav(IDLE_SPEED)

func _do_alert(player: Node3D) -> void:
	if player:
		nav_agent.target_position = player.global_position
		_move_via_nav(CHASE_SPEED)

func _do_attack_tick(delta: float, player: Node3D) -> void:
	if player:
		nav_agent.target_position = player.global_position
		_move_via_nav(CHASE_SPEED)
	attack_timer -= delta
	if attack_timer <= 0.0:
		attack_timer = ATTACK_COOLDOWN
		if player and player.has_method("receive_hit"):
			player.receive_hit(1, self)

func _move_via_nav(speed: float) -> void:
	var target: Vector3  = nav_agent.target_position
	var flat_dist: float = Vector2(global_position.x - target.x, global_position.z - target.z).length()

	if flat_dist < 0.5:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
		return

	var dir: Vector3

	# Try to get a useful direction from the nav agent
	var next: Vector3     = nav_agent.get_next_path_position()
	var nav_dir: Vector3  = next - global_position
	nav_dir.y = 0.0

	if nav_dir.length() > 0.2:
		# Nav path is giving us a real next waypoint
		dir = nav_dir.normalized()
	else:
		# Nav not ready or path empty — move directly toward target
		var raw: Vector3 = target - global_position
		raw.y = 0.0
		if raw.length() > 0.1:
			dir = raw.normalized()
		else:
			return

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

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

func _die() -> void:
	state = State.DEAD
	var loot: Array = GameManager.roll_loot("slime")
	if not loot.is_empty():
		GameManager.spawn_loot_at(global_position, loot)
	var player: Node = GameManager.player_node
	if player and player.has_method("gain_xp"):
		player.gain_xp(15)
	queue_free()

func _random_wander_point() -> Vector3:
	return global_position + Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0))
