extends CharacterBody3D

const ProjectileScene      := preload("res://scenes/entities/projectile.tscn")
const StatusEffectClass    := preload("res://scripts/resources/status_effect.gd")
const LimbHealthClass      := preload("res://scripts/resources/limb_health.gd")
const RANGED_COOLDOWN := 0.5

# ── Movement constants ──────────────────────────────────────────────────────────
const WALK_SPEED   := 4.0
const SPRINT_SPEED := 7.0
const CROUCH_SPEED := 2.0
const JUMP_VELOCITY := 5.0
const MOUSE_SENSITIVITY := 0.003
const PEEK_ANGLE   := 15.0
const PEEK_LERP_SPEED := 10.0
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.0

# ── Stamina constants ───────────────────────────────────────────────────────────
const MAX_STAMINA       := 100.0
const STAMINA_DRAIN_SPRINT := 20.0
const STAMINA_REGEN     := 15.0
const STAMINA_REGEN_DELAY := 1.0

# ── Hunger / thirst constants ───────────────────────────────────────────────────
const HUNGER_DRAIN_TIME := 600.0
const THIRST_DRAIN_TIME := 360.0
const DEBUFF_AMOUNT     := 2

# ── Combat constants ────────────────────────────────────────────────────────────
const HEAVY_HOLD_TIME := 0.50
const PARRY_WINDOW    := 0.30
const BASE_ATTACK_CD  := 0.50

const DMG_QUICK   := 1
const DMG_REGULAR := 2
const DMG_HEAVY   := 3

# ── Screen shake ────────────────────────────────────────────────────────────────
const TRAUMA_DECAY    := 1.6
const SHAKE_STRENGTH  := 0.022
var _cam_trauma: float = 0.0

# ── Player state ────────────────────────────────────────────────────────────────
enum State { IDLE, MOVING, ATTACKING, BLOCKING, STUNNED, DEAD }
var state: State = State.IDLE

# ── Stats ───────────────────────────────────────────────────────────────────────
var max_health: float = 20.0
var max_mana:   float = 10.0
var health:     float = 20.0
var mana:       float = 0.0
var stamina:    float = MAX_STAMINA
var stamina_regen_timer: float = 0.0
var hunger:     float = 100.0
var thirst:     float = 100.0
var is_hungry:  bool  = false
var is_thirsty: bool  = false

# ── Combat state ────────────────────────────────────────────────────────────────
var lmb_press_time: float       = 0.0
var attack_cooldown_timer: float = 0.0
var block_timer: float           = 0.0
var ranged_cooldown: float       = 0.0
var active_effects: Array        = []
var limbs: LimbHealthClass       = LimbHealthClass.new()
var is_blocking: bool            = false
var parry_active: bool           = false

# ── Lockpick state ──────────────────────────────────────────────────────────────
const LOCKPICK_HOLD_TIME := 5.0
var _lp_chest = null
var _lp_timer: float = 0.0

# ── Movement state ──────────────────────────────────────────────────────────────
var is_crouching  := false
var current_peek: float = 0.0

# ── Node refs ───────────────────────────────────────────────────────────────────
@onready var head:            Node3D             = $Head
@onready var camera:          Camera3D           = $Head/Camera3D
@onready var collision:       CollisionShape3D   = $CollisionShape3D
@onready var interact_ray:    RayCast3D          = $Head/Camera3D/InteractRay
@onready var attack_ray:      RayCast3D          = $Head/Camera3D/AttackRay
@onready var weapon:          Node3D             = $Head/Camera3D/WeaponHolder
@onready var player_model:    Node3D             = $PlayerModel
@onready var third_person_cam: Camera3D          = $ThirdPersonArm/ThirdPersonCam

var hud: CanvasLayer = null
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_third_person: bool = false

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	hud = get_parent().get_node_or_null("HUD")
	var is_new_game: bool = not GameManager.stats
	if is_new_game:
		GameManager.create_player_stats()
	GameManager.player_node = self
	max_health = float(GameManager.stats.max_health)
	max_mana   = float(GameManager.stats.max_mana)
	if GameManager.player_health >= 0.0:
		health  = GameManager.player_health
		mana    = GameManager.player_mana
		stamina = GameManager.player_stamina
		hunger  = GameManager.player_hunger
		thirst  = GameManager.player_thirst
		is_hungry  = hunger <= 0.0
		is_thirsty = thirst <= 0.0
	else:
		health = max_health
		mana   = 0.0
	_emit_all_stats()
	if is_new_game:
		_add_test_items()
	GameManager.equipment_changed.connect(_on_equipment_changed)
	# Restore weapon visual from saved equipment
	call_deferred("_restore_weapon_visual")

func _restore_weapon_visual() -> void:
	if not GameManager.equipment:
		return
	var equipped = GameManager.equipment.get_slot("main_hand")
	_update_weapon_visual(equipped)

func _on_equipment_changed(slot: String, item) -> void:
	if slot == "main_hand":
		_update_weapon_visual(item)

func _update_weapon_visual(item) -> void:
	if not weapon or not weapon.has_method("set_weapon"):
		return
	var id: String = ""
	if item != null:
		id = (item as Item).weapon_visual_id
	weapon.set_weapon(id if id != "" else "fist")

func _get_weapon_damage_bonus() -> int:
	if not GameManager.equipment:
		return 0
	var equipped = GameManager.equipment.get_slot("main_hand")
	if not equipped:
		return 0
	return (equipped as Item).damage_bonus

func _get_attack_cooldown() -> float:
	if not GameManager.equipment:
		return BASE_ATTACK_CD
	var equipped = GameManager.equipment.get_slot("main_hand")
	if not equipped:
		return BASE_ATTACK_CD
	var mult: float = (equipped as Item).attack_speed_mult
	if mult <= 0.0:
		mult = 1.0
	return BASE_ATTACK_CD / mult

func _add_test_items() -> void:
	var potion := Item.new()
	potion.id           = "health_potion"
	potion.display_name = "Health Potion"
	potion.grid_size    = Vector2i(1, 1)
	potion.weight       = 0.3
	potion.rarity       = Item.Rarity.COMMON
	potion.item_type    = Item.ItemType.CONSUMABLE
	potion.description  = "Restores 10 HP."
	GameManager.inventory.add_item(potion, Vector2i(0, 0))

	var potion2 := Item.new()
	potion2.id           = "health_potion"
	potion2.display_name = "Health Potion"
	potion2.grid_size    = Vector2i(1, 1)
	potion2.weight       = 0.3
	potion2.rarity       = Item.Rarity.COMMON
	potion2.item_type    = Item.ItemType.CONSUMABLE
	potion2.description  = "Restores 10 HP."
	GameManager.inventory.add_item(potion2, Vector2i(1, 0))

	var bandage := Item.new()
	bandage.id           = "bandage"
	bandage.display_name = "Bandage"
	bandage.grid_size    = Vector2i(1, 1)
	bandage.weight       = 0.1
	bandage.rarity       = Item.Rarity.COMMON
	bandage.item_type    = Item.ItemType.CONSUMABLE
	bandage.description  = "Treats a cut or deep cut on your worst injured limb."
	GameManager.inventory.add_item(bandage, Vector2i(0, 1))

	var bread := Item.new()
	bread.id           = "bread"
	bread.display_name = "Bread"
	bread.grid_size    = Vector2i(1, 1)
	bread.weight       = 0.2
	bread.rarity       = Item.Rarity.COMMON
	bread.item_type    = Item.ItemType.FOOD
	bread.nutrition    = 30.0
	bread.description  = "Restores 30 hunger."
	GameManager.inventory.add_item(bread, Vector2i(1, 1))

	var flask := Item.new()
	flask.id           = "water_flask"
	flask.display_name = "Water Flask"
	flask.grid_size    = Vector2i(1, 1)
	flask.weight       = 0.4
	flask.rarity       = Item.Rarity.COMMON
	flask.item_type    = Item.ItemType.WATER
	flask.nutrition    = 40.0
	flask.description  = "Restores 40 thirst."
	GameManager.inventory.add_item(flask, Vector2i(2, 1))

	var sword := Item.new()
	sword.id              = "iron_sword"
	sword.display_name    = "Iron Sword"
	sword.grid_size       = Vector2i(1, 3)
	sword.weight          = 3.5
	sword.rarity          = Item.Rarity.COMMON
	sword.item_type       = Item.ItemType.WEAPON_MELEE
	sword.description     = "A basic iron sword. +2 damage."
	sword.damage_bonus    = 2
	sword.attack_speed_mult = 1.0
	sword.weapon_visual_id  = "sword"
	GameManager.inventory.add_item(sword, Vector2i(4, 0))

	var armor := Item.new()
	armor.id           = "leather_armor"
	armor.display_name = "Leather Armor"
	armor.grid_size    = Vector2i(2, 2)
	armor.weight       = 5.0
	armor.rarity       = Item.Rarity.UNCOMMON
	armor.item_type    = Item.ItemType.ARMOR_CHEST
	armor.description  = "Light armor offering modest protection."
	armor.armor_bonus  = 2
	GameManager.inventory.add_item(armor, Vector2i(6, 0))

	var picks := Item.new()
	picks.id           = "lockpick"
	picks.display_name = "Lockpick"
	picks.grid_size    = Vector2i(1, 1)
	picks.weight       = 0.05
	picks.rarity       = Item.Rarity.COMMON
	picks.item_type    = Item.ItemType.MISC
	picks.stackable    = true
	picks.stack_count  = 5
	picks.description  = "A thin metal pick. Used to open locked chests."
	GameManager.inventory.add_item(picks, Vector2i(3, 1))

func _emit_all_stats() -> void:
	GameManager.player_health_changed.emit(health, max_health)
	GameManager.player_mana_changed.emit(mana, max_mana)
	GameManager.player_stamina_changed.emit(stamina, MAX_STAMINA)
	var s := GameManager.stats
	if s:
		GameManager.player_xp_changed.emit(s.xp, s.xp_to_next)

# ─────────────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if hud:
			hud.toggle_esc_menu()

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

	if event.is_action_pressed("attack_quick") and _can_attack():
		_do_attack(State.ATTACKING, "QUICK", DMG_QUICK)

	if event.is_action_pressed("attack") and _can_attack():
		lmb_press_time = Time.get_ticks_msec() / 1000.0
		weapon.start_charge()

	if event.is_action_released("attack") and _can_attack():
		var held := (Time.get_ticks_msec() / 1000.0) - lmb_press_time
		if held >= HEAVY_HOLD_TIME:
			_do_attack(State.ATTACKING, "HEAVY", DMG_HEAVY)
		else:
			_do_attack(State.ATTACKING, "REGULAR", DMG_REGULAR)

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
	if event.is_action_pressed("fire_ranged"):
		_fire_projectile()
	if event.is_action_pressed("open_health"):
		if hud and hud.has_method("toggle_health_screen"):
			hud.toggle_health_screen()
	if event is InputEventKey and (event as InputEventKey).pressed:
		if (event as InputEventKey).physical_keycode == KEY_K:
			if hud and hud.has_method("toggle_controls"):
				hud.toggle_controls()

# ─────────────────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_handle_lockpick(delta)
	# Camera screen shake
	if _cam_trauma > 0.0:
		_cam_trauma = maxf(_cam_trauma - TRAUMA_DECAY * delta, 0.0)
		var s: float = _cam_trauma * _cam_trauma * SHAKE_STRENGTH
		camera.position.x = randf_range(-s, s)
		camera.position.y = randf_range(-s, s)
	elif camera.position != Vector3.ZERO:
		camera.position = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	_handle_crouch(delta)
	_handle_peek(delta)
	_handle_hunger_thirst(delta)
	_handle_combat_timers(delta)

	if is_blocking:
		block_timer += delta
		parry_active = block_timer < PARRY_WINDOW

	if ranged_cooldown > 0.0:
		ranged_cooldown -= delta

	_tick_effects(delta)

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
	speed *= _get_effect_move_mult()
	speed *= _get_encumbrance_mult()

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

# ─────────────────────────────────────────────────────────────────────────────
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
	attack_cooldown_timer = _get_attack_cooldown()

	var str_bonus: int = int((get_effective_strength() - 5) * 0.5)
	var wpn_bonus: int = _get_weapon_damage_bonus()
	var final_damage: int = max(base_damage + str_bonus + wpn_bonus, 1)

	weapon.play_attack(attack_name)

	if attack_ray.is_colliding():
		var target: Node = attack_ray.get_collider()
		if target.has_method("take_damage"):
			target.take_damage(final_damage, attack_name)

func _start_block() -> void:
	if state == State.DEAD or state == State.STUNNED:
		return
	state        = State.BLOCKING
	is_blocking  = true
	block_timer  = 0.0
	parry_active = true
	weapon.start_block()

func _stop_block() -> void:
	is_blocking  = false
	parry_active = false
	block_timer  = 0.0
	if state == State.BLOCKING:
		state = State.IDLE
	weapon.stop_block()

func receive_hit(damage: int, attacker: Node) -> void:
	if state == State.DEAD:
		return

	if parry_active:
		if attacker and is_instance_valid(attacker) and attacker.has_method("take_damage"):
			attacker.take_damage(5, "parry")
		return

	var actual_damage := damage
	if is_blocking:
		actual_damage = max(int(damage * 0.25), 0)

	# Knockback
	if attacker and is_instance_valid(attacker) and attacker != self:
		var kb_dir: Vector3 = (global_position - attacker.global_position)
		kb_dir.y = 0.0
		if kb_dir.length() > 0.01:
			kb_dir = kb_dir.normalized()
			velocity += kb_dir * clampf(float(damage) * 1.8, 2.0, 8.0)

	take_damage(float(actual_damage))

# ─────────────────────────────────────────────────────────────────────────────
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
	var base: int  = GameManager.stats.strength if GameManager.stats else 5
	var penalty    := (DEBUFF_AMOUNT if is_hungry else 0) + (DEBUFF_AMOUNT if is_thirsty else 0)
	return max(base - penalty, 1)

func get_effective_dexterity() -> int:
	var base: int  = GameManager.stats.dexterity if GameManager.stats else 5
	var penalty    := (DEBUFF_AMOUNT if is_hungry else 0) + (DEBUFF_AMOUNT if is_thirsty else 0)
	return max(base - penalty, 1)

func get_effective_constitution() -> int:
	var base: int  = GameManager.stats.constitution if GameManager.stats else 5
	var penalty    := (DEBUFF_AMOUNT if is_hungry else 0) + (DEBUFF_AMOUNT if is_thirsty else 0)
	return max(base - penalty, 1)

# ─────────────────────────────────────────────────────────────────────────────
func _handle_crouch(delta: float) -> void:
	var target_height: float
	if Input.is_action_pressed("crouch"):
		is_crouching  = true
		target_height = CROUCH_HEIGHT
	else:
		is_crouching  = false
		target_height = STAND_HEIGHT

	var shape: CapsuleShape3D = collision.shape
	shape.height      = lerp(shape.height, target_height, delta * 10.0)
	collision.position.y = shape.height / 2.0
	head.position.y   = lerp(head.position.y, target_height - 0.2, delta * 10.0)

func _handle_peek(delta: float) -> void:
	var target_peek := 0.0
	if Input.is_action_pressed("peek_left"):
		target_peek = PEEK_ANGLE
	elif Input.is_action_pressed("peek_right"):
		target_peek = -PEEK_ANGLE

	current_peek = lerp(current_peek, target_peek, delta * PEEK_LERP_SPEED)
	camera.rotation_degrees.z = current_peek

func _try_interact() -> void:
	if not interact_ray.is_colliding():
		return
	var collider: Node = interact_ray.get_collider()
	if not collider.has_method("interact"):
		return
	# LockedChests are handled by _handle_lockpick — skip here
	if collider.has_method("open_success"):
		return
	collider.interact()

func _handle_lockpick(delta: float) -> void:
	# Find out if we're currently looking at a locked chest
	var target_chest = null
	if interact_ray.is_colliding():
		var col: Node = interact_ray.get_collider()
		if col.has_method("open_success") and not col.get("_opened"):
			target_chest = col

	if target_chest == null:
		# Not looking at a chest — reset
		if _lp_chest != null:
			_lp_chest = null
			_lp_timer = 0.0
			if hud and hud.has_method("hide_lockpick_ring"):
				hud.hide_lockpick_ring()
		return

	# Switched to a different chest — reset timer
	if target_chest != _lp_chest:
		_lp_chest = target_chest
		_lp_timer = 0.0

	# Show the ring
	if hud and hud.has_method("set_lockpick_progress"):
		hud.set_lockpick_progress(_lp_timer / LOCKPICK_HOLD_TIME)

	if Input.is_action_pressed("interact"):
		_lp_timer += delta
		if _lp_timer >= LOCKPICK_HOLD_TIME:
			_lp_timer = 0.0
			_do_lockpick_attempt()
	else:
		if _lp_timer > 0.0:
			_lp_timer = 0.0
			if hud and hud.has_method("set_lockpick_progress"):
				hud.set_lockpick_progress(0.0)

func _do_lockpick_attempt() -> void:
	var chest = _lp_chest
	if not chest:
		return
	var skill = GameManager.lockpick_skill
	# Check min level
	if not skill.can_attempt(chest.difficulty):
		var min_lvl: int = (skill.DIFFICULTY_DATA[chest.difficulty] as Dictionary).min_level as int
		if hud and hud.has_method("show_lockpick_message"):
			hud.show_lockpick_message("Need lockpick level %d" % min_lvl, false)
		return
	# Check picks in inventory
	if _lp_count_picks() <= 0:
		if hud and hud.has_method("show_lockpick_message"):
			hud.show_lockpick_message("No lockpicks left!", false)
		return
	_lp_consume_pick()
	var success: bool = skill.attempt(chest.difficulty)
	if success:
		chest.open_success()
		_lp_chest = null
		if hud and hud.has_method("hide_lockpick_ring"):
			hud.hide_lockpick_ring()
	else:
		if hud and hud.has_method("show_lockpick_message"):
			hud.show_lockpick_message("Lockpick Failed!", false)

func _lp_count_picks() -> int:
	if not GameManager.inventory:
		return 0
	var total: int = 0
	for e in GameManager.inventory.items:
		if (e["item"] as Item).id == "lockpick":
			total += (e["item"] as Item).stack_count
	return total

func _lp_consume_pick() -> void:
	if not GameManager.inventory:
		return
	for e in GameManager.inventory.items:
		var it := e["item"] as Item
		if it.id == "lockpick":
			it.stack_count -= 1
			if it.stack_count <= 0:
				GameManager.inventory.remove_item(it)
			return

func _toggle_inventory() -> void:
	if hud: hud.toggle_inventory()

func _toggle_player_info() -> void:
	if hud: hud.toggle_player_info()

func _toggle_camera() -> void:
	is_third_person          = not is_third_person
	camera.current           = not is_third_person
	third_person_cam.current = is_third_person
	player_model.visible     = is_third_person
	weapon.visible           = not is_third_person

func _toggle_map() -> void:
	if hud: hud.toggle_map()

# ─────────────────────────────────────────────────────────────────────────────
func take_damage(amount: float) -> void:
	health = max(health - amount, 0.0)
	GameManager.player_health_changed.emit(health, max_health)

	_cam_trauma = minf(_cam_trauma + clampf(amount * 0.12, 0.18, 0.75), 1.0)

	var limb_idx: int = LimbHealthClass.roll_injury(int(amount))
	if limb_idx >= 0:
		var cond: LimbHealthClass.Condition = limbs.injure(limb_idx, int(amount))
		var effect_id: String = LimbHealthClass.CONDITION_EFFECTS.get(cond, "")
		if effect_id != "" and has_method("apply_effect"):
			apply_effect(effect_id)
		GameManager.limb_condition_changed.emit(limb_idx, cond)
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

func gain_xp(amount: int) -> void:
	var s := GameManager.stats
	if not s:
		return
	s.xp += amount
	while s.xp >= s.xp_to_next and s.level < 12:
		s.xp         -= s.xp_to_next
		s.level      += 1
		s.xp_to_next  = s.level * 80 + 20
		match GameManager.selected_class:
			"fighter": max_health += 6; s.max_health += 6; s.strength += 1
			"thief":   max_health += 4; s.max_health += 4; s.dexterity += 1
			"wizard":  max_health += 2; s.max_health += 2; s.magic += 1; max_mana += 3; s.max_mana += 3
		heal(max_health)
		GameManager.player_leveled_up.emit(s.level)
	GameManager.player_xp_changed.emit(s.xp, s.xp_to_next)

func apply_effect(effect_id: String) -> void:
	for e in active_effects:
		if (e as StatusEffectClass).id == effect_id:
			(e as StatusEffectClass).duration = StatusEffectClass.DEFINITIONS[effect_id].duration
			return
	var e: StatusEffectClass = StatusEffectClass.create(effect_id)
	if e:
		active_effects.append(e)
		GameManager.status_effect_changed.emit(effect_id, true,
			(e as StatusEffectClass).display_name, (e as StatusEffectClass).color)

func _tick_effects(delta: float) -> void:
	var i: int = active_effects.size() - 1
	while i >= 0:
		var e: StatusEffectClass = active_effects[i]
		var dmg: int = e.tick(delta)
		if dmg > 0:
			take_damage(float(dmg))
		if e.is_expired():
			GameManager.status_effect_changed.emit(e.id, false, e.display_name, e.color)
			active_effects.remove_at(i)
		i -= 1

func _get_encumbrance_mult() -> float:
	if not GameManager.inventory:
		return 1.0
	var inv   := GameManager.inventory
	var ratio: float = inv.current_weight() / inv.max_weight
	if ratio <= 0.75:
		return 1.0
	elif ratio <= 1.0:
		return lerp(1.0, 0.4, (ratio - 0.75) / 0.25)
	else:
		return 0.2

func _get_effect_move_mult() -> float:
	var mult: float = 1.0
	for e in active_effects:
		mult *= (e as StatusEffectClass).move_mult
	return mult

func _fire_projectile() -> void:
	if state == State.DEAD or ranged_cooldown > 0.0:
		return
	ranged_cooldown = RANGED_COOLDOWN
	var proj: Node3D = ProjectileScene.instantiate()
	get_parent().add_child(proj)
	proj.global_position = camera.global_position + camera.global_basis.z * -0.5
	proj.direction       = -camera.global_basis.z

func _die() -> void:
	state = State.DEAD
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	GameManager.player_died.emit()
