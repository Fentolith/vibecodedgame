extends CharacterBody3D

# ── Movement constants ──────────────────────────────────────────────────────
const WALK_SPEED := 4.0
const SPRINT_SPEED := 7.0
const CROUCH_SPEED := 2.0
const JUMP_VELOCITY := 5.0
const MOUSE_SENSITIVITY := 0.003
const PEEK_ANGLE := 15.0
const PEEK_LERP_SPEED := 10.0
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.0

# ── Stamina constants ───────────────────────────────────────────────────────
const MAX_STAMINA := 100.0
const STAMINA_DRAIN_SPRINT := 20.0
const STAMINA_REGEN := 15.0
const STAMINA_REGEN_DELAY := 1.0

# ── Hunger / thirst constants ───────────────────────────────────────────────
const HUNGER_DRAIN_TIME := 600.0
const THIRST_DRAIN_TIME := 360.0
const DEBUFF_AMOUNT := 2

# ── Combat constants ────────────────────────────────────────────────────────
const HEAVY_HOLD_TIME   := 0.50   # hold LMB longer than this to charge a heavy attack
const PARRY_WINDOW      := 0.30   # first N seconds of blocking = active parry
const ATTACK_COOLDOWN   := 0.50   # minimum time between any two attacks

# Base damage per attack type (modified by STR and weapon later)
const DMG_QUICK   := 1
const DMG_REGULAR := 2
const DMG_HEAVY   := 3

# ── Player state ────────────────────────────────────────────────────────────
enum State { IDLE, MOVING, ATTACKING, BLOCKING, STUNNED, DEAD }
var state: State = State.IDLE

# ── Stats (set from class choice in _ready) ─────────────────────────────────
var max_health: float = 20.0
var max_mana: float   = 10.0
var health: float     = 20.0
var mana: float       = 0.0
var stamina: float    = MAX_STAMINA
var stamina_regen_timer: float = 0.0
var hunger: float     = 100.0
var thirst: float     = 100.0
var is_hungry: bool   = false
var is_thirsty: bool  = false

# ── Combat state vars ───────────────────────────────────────────────────────
var lmb_press_time: float    = 0.0   # when LMB was pressed
var attack_cooldown_timer: float = 0.0
var block_timer: float       = 0.0   # how long we've been holding block
var is_blocking: bool        = false
var parry_active: bool       = false

# ── Movement state ──────────────────────────────────────────────────────────
var is_crouching := false
var current_peek: float = 0.0

# ── Node refs ───────────────────────────────────────────────────────────────
@onready var head: Node3D              = $Head
@onready var camera: Camera3D          = $Head/Camera3D
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var interact_ray: RayCast3D   = $Head/Camera3D/InteractRay
@onready var attack_ray: RayCast3D     = $Head/Camera3D/AttackRay
@onready var weapon: Node3D            = $Head/Camera3D/WeaponHolder
@onready var player_model: Node3D      = $PlayerModel
@onready var third_person_cam: Camera3D = $ThirdPersonArm/ThirdPersonCam

var hud: CanvasLayer = null
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_third_person: bool = false

# ───────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	hud = get_parent().get_node_or_null("HUD")
	GameManager.create_player_stats()
	GameManager.player_node = self
	max_health = float(GameManager.stats.max_health)
	max_mana   = float(GameManager.stats.max_mana)
	health     = max_health
	mana       = 0.0
	_emit_all_stats()
	_add_test_items()

func _add_test_items() -> void:
	var ItemClass := preload("res://scripts/resources/item.gd")

	var potion := ItemClass.new()
	potion.id           = "health_potion"
	potion.display_name = "Health Potion"
	potion.grid_size    = Vector2i(1, 1)
	potion.weight       = 0.3
	potion.rarity       = ItemClass.Rarity.COMMON
	potion.item_type    = ItemClass.ItemType.CONSUMABLE
	potion.description  = "Restores 10 HP. Cannot exceed max health."
	GameManager.inventory.add_item(potion, Vector2i(0, 0))

	var potion2 := ItemClass.new()
	potion2.id           = "health_potion"
	potion2.display_name = "Health Potion"
	potion2.grid_size    = Vector2i(1, 1)
	potion2.weight       = 0.3
	potion2.rarity       = ItemClass.Rarity.COMMON
	potion2.item_type    = ItemClass.ItemType.CONSUMABLE
	potion2.description  = "Restores 10 HP. Cannot exceed max health."
	GameManager.inventory.add_item(potion2, Vector2i(1, 0))

	var sword := ItemClass.new()
	sword.id           = "iron_sword"
	sword.display_name = "Iron Sword"
	sword.grid_size    = Vector2i(1, 3)
	sword.weight       = 3.5
	sword.rarity       = ItemClass.Rarity.COMMON
	sword.item_type    = ItemClass.ItemType.WEAPON
	sword.description  = "A basic iron sword."
	GameManager.inventory.add_item(sword, Vector2i(2, 0))

	var armor := ItemClass.new()
	armor.id           = "leather_armor"
	armor.display_name = "Leather Armor"
	armor.grid_size    = Vector2i(2, 2)
	armor.weight       = 5.0
	armor.rarity       = ItemClass.Rarity.UNCOMMON
	armor.item_type    = ItemClass.ItemType.ARMOR
	armor.description  = "Light armor offering modest protection."
	GameManager.inventory.add_item(armor, Vector2i(4, 0))

func _emit_all_stats() -> void:
	GameManager.player_health_changed.emit(health, max_health)
	GameManager.player_mana_changed.emit(mana, max_mana)
	GameManager.player_stamina_changed.emit(stamina, MAX_STAMINA)

# ───────────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if hud:
			hud.toggle_esc_menu()

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

	# ── Middle mouse: quick attack ──
	if event.is_action_pressed("attack_quick") and _can_attack():
		_do_attack(State.ATTACKING, "QUICK", DMG_QUICK)

	# ── LMB pressed: record time and start charge drift ──
	if event.is_action_pressed("attack") and _can_attack():
		lmb_press_time = Time.get_ticks_msec() / 1000.0
		weapon.start_charge()

	# ── LMB released: regular or heavy based on hold duration ──
	if event.is_action_released("attack") and _can_attack():
		var held := (Time.get_ticks_msec() / 1000.0) - lmb_press_time
		if held >= HEAVY_HOLD_TIME:
			_do_attack(State.ATTACKING, "HEAVY", DMG_HEAVY)
		else:
			_do_attack(State.ATTACKING, "REGULAR", DMG_REGULAR)

	# ── RMB held = block; released = stop blocking ──
	if event.is_action_pressed("attack_special"):
		_start_block()
	if event.is_action_released("attack_special"):
		_stop_block()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_interact()
	if event.is_action_pressed("inventory"):
		_toggle_inventory()
	if event.is_action_pressed("open_map"):
		_toggle_map()
	if event.is_action_pressed("player_info"):
		_toggle_player_info()
	if event.is_action_pressed("toggle_camera"):
		_toggle_camera()

# ───────────────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	_handle_crouch(delta)
	_handle_peek(delta)
	_handle_hunger_thirst(delta)
	_handle_combat_timers(delta)

	# Block timer tracks parry window
	if is_blocking:
		block_timer += delta
		parry_active = block_timer < PARRY_WINDOW

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

	if direction.length() > 0.1 and state != State.ATTACKING and state != State.BLOCKING:
		state = State.MOVING
	elif state == State.MOVING:
		state = State.IDLE

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

# ───────────────────────────────────────────────────────────────────────────
func _handle_combat_timers(delta: float) -> void:
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta
		if attack_cooldown_timer <= 0.0 and state == State.ATTACKING:
			state = State.IDLE

func _can_attack() -> bool:
	return state != State.BLOCKING and state != State.STUNNED \
		and state != State.DEAD and attack_cooldown_timer <= 0.0

func _do_attack(new_state: State, attack_name: String, base_damage: int) -> void:
	state = new_state
	attack_cooldown_timer = ATTACK_COOLDOWN

	# Scale damage by effective STR (Phase 5 will refine this formula)
	var str_bonus := int((get_effective_strength() - 5) * 0.5)
	var final_damage: int = max(base_damage + str_bonus, 1)

	print("ATTACK: %s | damage: %d | STR bonus: %d" % [attack_name, final_damage, str_bonus])
	weapon.play_attack(attack_name)

	# Check if anything is in melee range and deal damage to it
	if attack_ray.is_colliding():
		var target: Node = attack_ray.get_collider()
		if target.has_method("take_damage"):
			target.take_damage(final_damage, attack_name)

func _start_block() -> void:
	if state == State.DEAD or state == State.STUNNED:
		return
	state = State.BLOCKING
	is_blocking = true
	block_timer = 0.0
	parry_active = true
	print("BLOCKING — parry window open")
	weapon.start_block()

func _stop_block() -> void:
	is_blocking = false
	parry_active = false
	block_timer = 0.0
	if state == State.BLOCKING:
		state = State.IDLE
	print("BLOCKING — stopped")
	weapon.stop_block()

# Called by enemy attacks hitting the player
func receive_hit(damage: int, attacker: Node) -> void:
	if state == State.DEAD:
		return

	if parry_active:
		print("PARRY SUCCESS — countered ", attacker.name)
		# Future: stun attacker here
		return

	if is_blocking:
		# Blocking reduces damage by 75%
		var blocked_damage := int(damage * 0.25)
		print("BLOCKED — took %d instead of %d" % [blocked_damage, damage])
		take_damage(float(blocked_damage))
		return

	take_damage(float(damage))

# ───────────────────────────────────────────────────────────────────────────
func _handle_hunger_thirst(delta: float) -> void:
	hunger -= (100.0 / HUNGER_DRAIN_TIME) * delta
	thirst -= (100.0 / THIRST_DRAIN_TIME) * delta
	hunger = max(hunger, 0.0)
	thirst = max(thirst, 0.0)

	if hunger <= 0.0 and not is_hungry:
		is_hungry = true
		GameManager.player_needs_changed.emit("hungry", true)

	if thirst <= 0.0 and not is_thirsty:
		is_thirsty = true
		GameManager.player_needs_changed.emit("thirsty", true)

func get_effective_strength() -> int:
	var base: int = GameManager.stats.strength if GameManager.stats else 5
	var penalty := (DEBUFF_AMOUNT if is_hungry else 0) + (DEBUFF_AMOUNT if is_thirsty else 0)
	return max(base - penalty, 1)

func get_effective_dexterity() -> int:
	var base: int = GameManager.stats.dexterity if GameManager.stats else 5
	var penalty := (DEBUFF_AMOUNT if is_hungry else 0) + (DEBUFF_AMOUNT if is_thirsty else 0)
	return max(base - penalty, 1)

func get_effective_constitution() -> int:
	var base: int = GameManager.stats.constitution if GameManager.stats else 5
	var penalty := (DEBUFF_AMOUNT if is_hungry else 0) + (DEBUFF_AMOUNT if is_thirsty else 0)
	return max(base - penalty, 1)

# ───────────────────────────────────────────────────────────────────────────
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
		var collider: Node = interact_ray.get_collider()
		if collider.has_method("interact"):
			collider.interact()

func _toggle_inventory() -> void:
	if hud:
		hud.toggle_inventory()

func _toggle_player_info() -> void:
	if hud:
		hud.toggle_player_info()

func _toggle_camera() -> void:
	is_third_person = not is_third_person
	camera.current           = not is_third_person
	third_person_cam.current = is_third_person
	player_model.visible     = is_third_person
	weapon.visible           = not is_third_person

func _toggle_map() -> void:
	if hud:
		hud.toggle_map()

# ───────────────────────────────────────────────────────────────────────────
func take_damage(amount: float) -> void:
	health = max(health - amount, 0.0)
	GameManager.player_health_changed.emit(health, max_health)
	if health <= 0.0:
		_die()

func heal(amount: float) -> void:
	health = min(health + amount, max_health)
	GameManager.player_health_changed.emit(health, max_health)

func eat(hunger_restore: float) -> void:
	hunger = min(hunger + hunger_restore, 100.0)
	if hunger > 0.0 and is_hungry:
		is_hungry = false
		GameManager.player_needs_changed.emit("hungry", false)

func drink(thirst_restore: float) -> void:
	thirst = min(thirst + thirst_restore, 100.0)
	if thirst > 0.0 and is_thirsty:
		is_thirsty = false
		GameManager.player_needs_changed.emit("thirsty", false)

func _die() -> void:
	state = State.DEAD
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	GameManager.player_died.emit()
