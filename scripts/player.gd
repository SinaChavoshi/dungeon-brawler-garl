class_name Player
extends CharacterBody3D
## Garl, our pantsless hero, with MMO-style controls:
##
##   W / S          run forward / backpedal
##   A / D          turn (strafe while holding the right mouse button)
##   Q / E          strafe left / right
##   Space          jump
##   Both mouse buttons   run forward
##   Right drag     steer Garl with the mouse;  Left drag  look around
##   Left click     target an enemy;  Right click  target and attack
##   Tab            target the nearest enemy in front;  Esc  clear target
##   1-9            action bar abilities (see Abilities)
##
## Garl swings at his target automatically once he is attacking it.

signal health_changed(current: int, maximum: int)
signal damaged
signal died(cause: String)
signal target_changed(target: Node3D)
## Something went wrong with a button press ("Out of range", ...).
signal error(text: String)
signal ability_used(id: String)

@export var move_speed: float = 6.5
@export var backpedal_mult: float = 0.55
@export var turn_rate_degrees: float = 180.0
@export var jump_speed: float = 6.0
@export var max_health: int = 10
@export var punch_damage: int = 1
@export var melee_range: float = 2.2
@export var swing_time: float = 1.4
@export var hurt_invulnerability: float = 0.6

var health: int
var speed_mult: float = 1.0
var is_dead: bool = false
var facing_yaw: float = 0.0
var target: Node3D
var auto_attacking: bool = false
## Ability id -> seconds left.
var cooldowns: Dictionary = {}
var global_cooldown: float = 0.0
## Ability ids on keys 1-9.
var action_bar: Array = Abilities.DEFAULT_BAR.duplicate()
var duchess: Node3D
var inventory_heal: Callable  ## set by game.gd: returns false if no heal item
var _base_max_health: int
var _base_punch_damage: int
var _swing_timer: float = 0.0
var _hurt_timer: float = 0.0
var _dodge_timer: float = 0.0
var _dodge_velocity := Vector3.ZERO
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var visuals: GarlModel = $Visuals
@onready var camera_rig: CameraRig = $CameraRig


func _ready() -> void:
	add_to_group("player")
	_base_max_health = max_health
	_base_punch_damage = punch_damage
	health = max_health
	camera_rig.clicked.connect(_on_clicked)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if is_dead:
		velocity = Vector3(0.0, velocity.y - gravity * delta, 0.0)
		move_and_slide()
		camera_rig.follow(facing_yaw, false, delta)
		return
	if target != null and (not is_instance_valid(target) or not target.is_in_group("hittable")):
		set_target(null)

	var steering := camera_rig.steering
	var forward := 0.0
	var strafe := 0.0
	var turn := 0.0
	if _key(KEY_W) or _key(KEY_UP) or (camera_rig.steering and camera_rig.orbiting):
		forward += 1.0
	if _key(KEY_S) or _key(KEY_DOWN):
		forward -= 1.0
	if _key(KEY_Q):
		strafe -= 1.0
	if _key(KEY_E):
		strafe += 1.0
	var left := _key(KEY_A) or _key(KEY_LEFT)
	var right := _key(KEY_D) or _key(KEY_RIGHT)
	if steering:
		strafe += (1.0 if right else 0.0) - (1.0 if left else 0.0)
	else:
		turn += (1.0 if left else 0.0) - (1.0 if right else 0.0)
	strafe = clampf(strafe, -1.0, 1.0)

	if steering:
		facing_yaw = camera_rig.yaw
	else:
		facing_yaw += deg_to_rad(turn_rate_degrees) * turn * delta
	visuals.rotation.y = facing_yaw

	var local := Vector2(strafe, forward)
	if local.length() > 1.0:
		local = local.normalized()
	var speed := move_speed * speed_mult * (backpedal_mult if forward < 0.0 else 1.0)
	var basis_yaw := Basis(Vector3.UP, facing_yaw)
	var wish := basis_yaw * Vector3(local.x, 0.0, -local.y) * speed

	if _dodge_timer > 0.0:
		wish = _dodge_velocity
	if is_on_floor():
		velocity.x = wish.x
		velocity.z = wish.z
		velocity.y = 0.0
		if _key(KEY_SPACE) and _dodge_timer == 0.0:
			velocity.y = jump_speed
	else:
		# A little air control, like the games this is spoofing.
		velocity.x = lerpf(velocity.x, wish.x, 2.0 * delta)
		velocity.z = lerpf(velocity.z, wish.z, 2.0 * delta)
		velocity.y -= gravity * delta
	move_and_slide()

	visuals.set_motion(local, speed, is_on_floor())
	camera_rig.follow(facing_yaw, local.length() > 0.1 or turn != 0.0, delta)
	_auto_attack()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or is_dead:
		return
	if key.physical_keycode == KEY_TAB:
		target_nearest()
		get_viewport().set_input_as_handled()
	elif key.physical_keycode == KEY_ESCAPE and target != null:
		set_target(null)
		get_viewport().set_input_as_handled()
	elif key.physical_keycode >= KEY_1 and key.physical_keycode <= KEY_9:
		var slot := int(key.physical_keycode - KEY_1)
		if slot < action_bar.size() and action_bar[slot] != "":
			use_ability(action_bar[slot])


# --- Targeting -------------------------------------------------------------

func set_target(new_target: Node3D) -> void:
	if new_target == target:
		return
	target = new_target
	if target == null:
		auto_attacking = false
	target_changed.emit(target)


## Tab: the closest enemy roughly in front of Garl; pressing again cycles.
func target_nearest() -> void:
	var forward := _forward()
	var candidates: Array = []
	for node in get_tree().get_nodes_in_group("hittable"):
		var thing := node as Node3D
		var to_thing := thing.global_position - global_position
		to_thing.y = 0.0
		if to_thing.length() > 25.0:
			continue
		var score := to_thing.length() - forward.dot(to_thing.normalized()) * 6.0
		candidates.append([score, thing])
	if candidates.is_empty():
		error.emit("No targets nearby")
		return
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var index := 0
	for i in candidates.size():
		if candidates[i][1] == target:
			index = (i + 1) % candidates.size()
	set_target(candidates[index][1])


func _on_clicked(button: MouseButton, screen_position: Vector2) -> void:
	if is_dead:
		return
	var camera := camera_rig.camera
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * 60.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var thing: Node3D = null
	if not hit.is_empty() and (hit["collider"] as Node).is_in_group("hittable"):
		thing = hit["collider"] as Node3D
	if thing == null:
		if button == MOUSE_BUTTON_LEFT:
			set_target(null)
		return
	set_target(thing)
	if button == MOUSE_BUTTON_RIGHT:
		auto_attacking = true


# --- Combat ----------------------------------------------------------------

func _auto_attack() -> void:
	if not auto_attacking or target == null or _swing_timer > 0.0:
		return
	if _distance_to(target) > melee_range:
		return
	if not _is_facing(target):
		return
	_swing_timer = swing_time
	visuals.punch(_is_moving())
	_strike(target, punch_damage, 1.0)


func use_ability(id: String) -> void:
	var info := Abilities.info(id)
	if info.is_empty() or is_dead:
		return
	if cooldowns.get(id, 0.0) > 0.0:
		error.emit("That ability isn't ready yet")
		return
	if info["gcd"] and global_cooldown > 0.0:
		return  # quietly ignore button mashing during the global cooldown
	if info["needs_target"] and target == null:
		error.emit("You have no target")
		return
	if info["range"] > 0.0 and target != null and _distance_to(target) > info["range"]:
		if info["needs_target"]:
			error.emit("Out of range")
			return

	match id:
		"haymaker":
			if not _melee_ability(info["range"], punch_damage * 2 + 1, 1.0, "Unarmed_Melee_Attack_Punch_B"):
				return
			camera_rig.shake(0.3)
		"boot":
			if not _melee_ability(info["range"], punch_damage + 1, 2.2, "Unarmed_Melee_Attack_Kick"):
				return
		"belly_flop":
			velocity.y = jump_speed * 0.8
			visuals.play_action("Jump_Full_Short")
			get_tree().create_timer(0.55).timeout.connect(_belly_flop_land)
		"dodge":
			var dir := velocity * Vector3(1, 0, 1)
			var anim := "Dodge_Forward"
			if dir.length() < 0.5:
				dir = -_forward()
				anim = "Dodge_Backward"
			else:
				var local := Basis(Vector3.UP, -facing_yaw) * dir
				if absf(local.x) > absf(local.z):
					anim = "Dodge_Right" if local.x > 0.0 else "Dodge_Left"
				elif local.z > 0.0:
					anim = "Dodge_Backward"
			_dodge_velocity = dir.normalized() * 11.0
			_dodge_timer = 0.4
			_hurt_timer = maxf(_hurt_timer, 0.55)
			visuals.play_action(anim)
		"royal_spray":
			if duchess == null or not duchess.has_method("command_spray"):
				return
			duchess.call("command_spray", target)
			visuals.play_action("Spellcast_Shoot", _is_moving())
		"quick_heal":
			if not inventory_heal.is_valid() or not inventory_heal.call():
				return
			visuals.play_action("Use_Item", true)

	if info["cooldown"] > 0.0:
		cooldowns[id] = info["cooldown"]
	if info["gcd"]:
		global_cooldown = Abilities.GLOBAL_COOLDOWN
	ability_used.emit(id)


## Hits the target if it's in range, otherwise whatever is right in front.
func _melee_ability(reach: float, damage: int, knockback: float, anim: String) -> bool:
	var victim: Node3D = null
	if target != null:
		if _distance_to(target) > reach:
			error.emit("Out of range")
			return false
		if not _is_facing(target):
			error.emit("You must be facing your target")
			return false
		victim = target
	else:
		victim = _thing_in_front(reach)
	visuals.play_action(anim, _is_moving())
	if victim != null:
		_strike(victim, damage, knockback)
		if target == null:
			set_target(victim)
		auto_attacking = true
	return true


func _belly_flop_land() -> void:
	if is_dead:
		return
	camera_rig.shake(0.8)
	for node in get_tree().get_nodes_in_group("hittable"):
		var thing := node as Node3D
		if _distance_to(thing) <= 3.5:
			_strike(thing, punch_damage + 1, 1.5)
	var dust := CPUParticles3D.new()
	dust.one_shot = true
	dust.emitting = true
	dust.amount = 40
	dust.lifetime = 0.8
	dust.explosiveness = 1.0
	dust.direction = Vector3.UP
	dust.spread = 80.0
	dust.initial_velocity_min = 2.0
	dust.initial_velocity_max = 4.5
	dust.gravity = Vector3(0, -6, 0)
	var puff := SphereMesh.new()
	puff.radius = 0.12
	puff.height = 0.24
	puff.radial_segments = 6
	puff.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.5, 0.45)
	puff.material = mat
	dust.mesh = puff
	get_parent().add_child(dust)
	dust.global_position = global_position + Vector3(0, 0.2, 0)
	get_tree().create_timer(1.5).timeout.connect(dust.queue_free)


func _strike(thing: Node3D, damage: int, knockback: float) -> void:
	var push := thing.global_position - global_position
	push.y = 0.0
	thing.call("take_damage", damage, push.normalized() * knockback)


func take_damage(amount: int) -> void:
	if is_dead or _hurt_timer > 0.0:
		return
	_hurt_timer = hurt_invulnerability
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	damaged.emit()
	camera_rig.shake(0.6)
	visuals.hit(true)
	if health == 0:
		die("enemies")


## Recompute stats from equipped gear (see Inventory.bonuses()).
func apply_bonuses(bonuses: Dictionary) -> void:
	punch_damage = _base_punch_damage + int(bonuses.get("punch_damage", 0))
	speed_mult = float(bonuses.get("speed_mult", 1.0))
	var new_max := _base_max_health + int(bonuses.get("max_health", 0))
	if new_max > max_health:
		health += new_max - max_health
	max_health = new_max
	health = mini(health, max_health)
	health_changed.emit(health, max_health)


func heal(amount: int) -> void:
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)


func die(cause: String) -> void:
	if is_dead:
		return
	is_dead = true
	auto_attacking = false
	visuals.die()
	died.emit(cause)


func reset_for_new_floor(spawn: Vector3) -> void:
	position = spawn
	velocity = Vector3.ZERO
	facing_yaw = 0.0
	set_target(null)
	camera_rig.snap(facing_yaw)


# --- Helpers ---------------------------------------------------------------

func _tick_timers(delta: float) -> void:
	_swing_timer = maxf(_swing_timer - delta, 0.0)
	_hurt_timer = maxf(_hurt_timer - delta, 0.0)
	_dodge_timer = maxf(_dodge_timer - delta, 0.0)
	global_cooldown = maxf(global_cooldown - delta, 0.0)
	for id in cooldowns.keys():
		cooldowns[id] = maxf(cooldowns[id] - delta, 0.0)


func _forward() -> Vector3:
	return Vector3(-sin(facing_yaw), 0.0, -cos(facing_yaw))


func _distance_to(thing: Node3D) -> float:
	var offset := thing.global_position - global_position
	offset.y = 0.0
	return offset.length()


func _is_facing(thing: Node3D) -> bool:
	var to_thing := thing.global_position - global_position
	to_thing.y = 0.0
	return to_thing.length() < 0.8 or _forward().dot(to_thing.normalized()) > 0.4


func _is_moving() -> bool:
	return Vector2(velocity.x, velocity.z).length() > 0.5


func _thing_in_front(reach: float) -> Node3D:
	var best: Node3D = null
	var best_distance := reach
	for node in get_tree().get_nodes_in_group("hittable"):
		var thing := node as Node3D
		var d := _distance_to(thing)
		if d <= best_distance and _is_facing(thing):
			best = thing
			best_distance = d
	return best


func _key(code: Key) -> bool:
	return Input.is_physical_key_pressed(code)
