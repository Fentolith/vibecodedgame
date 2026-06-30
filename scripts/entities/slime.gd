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

@onready var health_bar: Label3D = $HealthBar

func _ready() -> void:
	health_bar.visible = false
	wander_target      = _random_wander_point()
	wander_timer       = randf_range(1.0, 3.0)

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
	_move_toward(wander_target, IDLE_SPEED)

func _do_alert(player: Node3D) -> void:
	if player:
		_move_toward(player.global_position, CHASE_SPEED)

func _do_attack_tick(delta: float, player: Node3D) -> void:
	if player:
		_move_toward(player.global_position, CHASE_SPEED)
	attack_timer -= delta
	if attack_timer <= 0.0:
		attack_timer = ATTACK_COOLDOWN
		if player and player.has_method("receive_hit"):
			player.receive_hit(1, self)

func _move_toward(target: Vector3, speed: float) -> void:
	var dir := target - global_position
	dir.y = 0.0
	if dir.length() > 0.15:
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

func _die() -> void:
	state = State.DEAD
	GameManager.spawn_loot_at(global_position, _make_gold_drop())
	queue_free()

func _make_gold_drop() -> Array:
	var gold      := ItemClass.new()
	gold.id           = "gold"
	gold.display_name = "Gold"
	gold.grid_size    = Vector2i(1, 1)
	gold.weight       = 0.01
	gold.rarity       = ItemClass.Rarity.UNCOMMON
	gold.item_type    = ItemClass.ItemType.MISC
	gold.stackable    = true
	gold.stack_count  = randi_range(1, 3)
	gold.description  = "Shiny coins dropped by a slime."
	return [gold]

func _random_wander_point() -> Vector3:
	return global_position + Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0))
