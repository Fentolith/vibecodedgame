extends CharacterBody3D

const WALK_SPEED := 4.0
const SPRINT_SPEED := 7.0
const CROUCH_SPEED := 2.0
const JUMP_VELOCITY := 5.0
const MOUSE_SENSITIVITY := 0.003
const PEEK_ANGLE := 15.0
const PEEK_LERP_SPEED := 10.0

const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.0

const MAX_HEALTH := 100.0
const MAX_MANA := 50.0
const MAX_STAMINA := 100.0
const STAMINA_DRAIN_SPRINT := 20.0
const STAMINA_REGEN := 15.0
const STAMINA_REGEN_DELAY := 1.0

var health: float = MAX_HEALTH
var mana: float = MAX_MANA
var stamina: float = MAX_STAMINA
var stamina_regen_timer: float = 0.0

var is_crouching := false
var current_peek: float = 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_emit_all_stats()

func _emit_all_stats() -> void:
	GameManager.player_health_changed.emit(health, MAX_HEALTH)
	GameManager.player_mana_changed.emit(mana, MAX_MANA)
	GameManager.player_stamina_changed.emit(stamina, MAX_STAMINA)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

	if event.is_action_pressed("interact"):
		_try_interact()

	if event.is_action_pressed("inventory"):
		_toggle_inventory()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	_handle_crouch(delta)
	_handle_peek(delta)

	var is_sprinting := Input.is_action_pressed("sprint") and not is_crouching and stamina > 0.0

	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = JUMP_VELOCITY

	var speed: float
	if is_crouching:
		speed = CROUCH_SPEED
	elif is_sprinting:
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed * delta * 10.0)
		velocity.z = move_toward(velocity.z, 0, speed * delta * 10.0)

	var is_moving := direction.length() > 0.1
	if is_sprinting and is_moving:
		stamina -= STAMINA_DRAIN_SPRINT * delta
		stamina = max(stamina, 0.0)
		stamina_regen_timer = STAMINA_REGEN_DELAY
		GameManager.player_stamina_changed.emit(stamina, MAX_STAMINA)
	else:
		stamina_regen_timer -= delta
		if stamina_regen_timer <= 0.0 and stamina < MAX_STAMINA:
			stamina = min(stamina + STAMINA_REGEN * delta, MAX_STAMINA)
			GameManager.player_stamina_changed.emit(stamina, MAX_STAMINA)

	move_and_slide()

func _handle_crouch(delta: float) -> void:
	var target_height: float
	if Input.is_action_pressed("crouch"):
		is_crouching = true
		target_height = CROUCH_HEIGHT
	else:
		is_crouching = false
		target_height = STAND_HEIGHT

	var shape: CapsuleShape3D = collision.shape
	shape.height = lerp(shape.height, target_height, delta * 10.0)
	collision.position.y = shape.height / 2.0
	head.position.y = lerp(head.position.y, target_height - 0.2, delta * 10.0)

func _handle_peek(delta: float) -> void:
	var target_peek := 0.0
	if Input.is_action_pressed("peek_left"):
		target_peek = PEEK_ANGLE
	elif Input.is_action_pressed("peek_right"):
		target_peek = -PEEK_ANGLE

	current_peek = lerp(current_peek, target_peek, delta * PEEK_LERP_SPEED)
	camera.rotation_degrees.z = current_peek

func _try_interact() -> void:
	if interact_ray.is_colliding():
		var collider := interact_ray.get_collider()
		if collider.has_method("interact"):
			collider.interact()

func _toggle_inventory() -> void:
	pass

func take_damage(amount: float) -> void:
	health = max(health - amount, 0.0)
	GameManager.player_health_changed.emit(health, MAX_HEALTH)
	if health <= 0.0:
		_die()

func heal(amount: float) -> void:
	health = min(health + amount, MAX_HEALTH)
	GameManager.player_health_changed.emit(health, MAX_HEALTH)

func _die() -> void:
	print("Player died!")
