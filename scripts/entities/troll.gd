extends CharacterBody3D

enum State { IDLE, CHASE, ATTACK, DEAD }

const DETECTION_RANGE  := 18.0
const ATTACK_RANGE     := 2.2
const CHASE_SPEED      := 2.0
const IDLE_SPEED       := 0.8
const ATTACK_COOLDOWN  := 3.0
const MAX_HEALTH       := 120
const ATTACK_DAMAGE    := 15

var state: State        = State.IDLE
var health: int         = MAX_HEALTH
var attack_timer: float = 0.0
var wander_timer: float = 0.0
var wander_target: Vector3 = Vector3.ZERO
var gravity: float      = ProjectSettings.get_setting("physics/3d/default_gravity")

var _attack_arm: MeshInstance3D = null
var _arm_tween:  Tween          = null

@onready var health_bar: Label3D           = $HealthBar
@onready var nav_agent:  NavigationAgent3D = $NavigationAgent3D

func _ready() -> void:
	health_bar.visible = false
	wander_timer       = randf_range(2.0, 5.0)
	_build_attack_arm()
	_init_wander.call_deferred()

func _build_attack_arm() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.28, 0.28, 1.2)
	var mat := StandardMaterial3D.new()
	mat.albedo_color          = Color(0.20, 0.35, 0.12, 1.0)
	mat.emission_enabled      = true
	mat.emission              = Color(0.04, 0.10, 0.02, 1.0)
	mat.emission_energy_multiplier = 0.4
	_attack_arm              = MeshInstance3D.new()
	_attack_arm.mesh         = mesh
	_attack_arm.set_surface_override_material(0, mat)
	_attack_arm.visible      = false
	add_child(_attack_arm)

func _init_wander() -> void:
	await get_tree().physics_frame
	wander_target             = _random_wander_point()
	nav_agent.target_position = wander_target

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta

	var player: Node3D = GameManager.player_node
	_update_state(player)
	attack_timer -= delta

	match state:
		State.IDLE:   _do_idle(delta)
		State.CHASE:  _do_chase(player)
		State.ATTACK: _do_attack(player, delta)

	move_and_slide()

func _update_state(player: Node3D) -> void:
	if not player:
		return
	var dist: float = global_position.distance_to(player.global_position)
	if dist <= ATTACK_RANGE:
		state = State.ATTACK
	elif dist <= DETECTION_RANGE:
		state = State.CHASE
	else:
		if state != State.IDLE:
			state = State.IDLE

func _do_idle(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_target = _random_wander_point()
		wander_timer  = randf_range(3.0, 7.0)
	nav_agent.target_position = wander_target
	_move_via_nav(IDLE_SPEED)

func _do_chase(player: Node3D) -> void:
	if player:
		nav_agent.target_position = player.global_position
		_move_via_nav(CHASE_SPEED)

func _do_attack(player: Node3D, _delta: float) -> void:
	if player:
		nav_agent.target_position = player.global_position
		_move_via_nav(CHASE_SPEED * 0.5)
	if attack_timer <= 0.0 and player:
		attack_timer = ATTACK_COOLDOWN
		if player.has_method("receive_hit"):
			player.receive_hit(ATTACK_DAMAGE, self)
		if randf() < 0.5 and player.has_method("apply_effect"):
			player.apply_effect("deep_cut" if randf() < 0.6 else "paralyzed")
		_swing_arm(player)

func _swing_arm(player: Node3D) -> void:
	if not player or not _attack_arm:
		return
	var dir: Vector3 = (player.global_position - global_position).normalized()
	dir.y = 0.0
	if dir.length() < 0.1:
		return
	dir = dir.normalized()

	# Start arm at shoulder height, retracted
	_attack_arm.position = Vector3(dir.x * 0.5, 1.4, dir.z * 0.5)
	_attack_arm.visible  = true
	_attack_arm.look_at(global_position + dir + Vector3(0, 1.4, 0), Vector3.UP)

	if _arm_tween:
		_arm_tween.kill()
	_arm_tween = create_tween()
	# Slam arm forward
	_arm_tween.tween_property(_attack_arm, "position",
		Vector3(dir.x * 1.9, 1.2, dir.z * 1.9), 0.10)
	# Pull back
	_arm_tween.tween_property(_attack_arm, "position",
		Vector3(dir.x * 0.5, 1.4, dir.z * 0.5), 0.30)
	_arm_tween.tween_callback(func(): _attack_arm.visible = false)

func _move_via_nav(speed: float) -> void:
	var target: Vector3  = nav_agent.target_position
	var flat_dist: float = Vector2(global_position.x - target.x, global_position.z - target.z).length()

	if flat_dist < 0.5:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
		return

	var dir: Vector3
	var next: Vector3    = nav_agent.get_next_path_position()
	var nav_dir: Vector3 = next - global_position
	nav_dir.y = 0.0

	if nav_dir.length() > 0.2:
		dir = nav_dir.normalized()
	else:
		# Nav path not ready — move directly toward target
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
	var filled: int = int(ceil(float(max(health, 0)) / MAX_HEALTH * 10))
	var bar := ""
	for i in 10:
		bar += "█" if i < filled else "░"
	health_bar.text = "TROLL  " + bar

func apply_floor_scale(mult: float) -> void:
	health = int(float(health) * mult)

func _die() -> void:
	state = State.DEAD
	GameManager.floor_kills += 1
	GameManager.total_kills += 1
	# Boss drops good loot — multiple items
	for _i in 3:
		var loot: Array = GameManager.roll_loot("troll")
		if not loot.is_empty():
			var offset := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
			GameManager.spawn_loot_at(global_position + offset, loot)
	var player: Node = GameManager.player_node
	if player and player.has_method("gain_xp"):
		player.gain_xp(200)
	queue_free()

func _random_wander_point() -> Vector3:
	return global_position + Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0))
