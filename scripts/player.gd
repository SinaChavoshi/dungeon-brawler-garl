class_name Player
extends CharacterBody3D
## Garl, our pantsless hero. Walks, punches, takes hits.
## Left-drag orbits the camera, so punching lives on Space / J / right click.
##
## Only the Visuals node turns to face the movement direction. The body and
## the child camera stay unrotated, so the camera keeps its fixed angle.

signal health_changed(current: int, maximum: int)
signal damaged
signal died(cause: String)

@export var move_speed: float = 6.0
@export var turn_speed: float = 12.0
@export var max_health: int = 10
@export var punch_damage: int = 1
@export var punch_range: float = 1.6
@export var punch_cooldown: float = 0.35
@export var hurt_invulnerability: float = 0.6

var health: int
var is_dead: bool = false
var _punch_timer: float = 0.0
var _hurt_timer: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var visuals: GarlModel = $Visuals
@onready var camera_rig: CameraRig = $CameraRig


func _ready() -> void:
	add_to_group("player")
	health = max_health


func _physics_process(delta: float) -> void:
	_punch_timer = maxf(_punch_timer - delta, 0.0)
	_hurt_timer = maxf(_hurt_timer - delta, 0.0)
	if is_dead:
		return

	var input := _read_move_input()
	var direction := Vector3(input.x, 0.0, input.y)
	if direction.length() > 1.0:
		direction = direction.normalized()
	# Move relative to where the camera is looking.
	direction = direction.rotated(Vector3.UP, camera_rig.rotation.y)
	visuals.set_walk_amount(direction.length())

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	move_and_slide()

	if direction.length() > 0.01:
		# Godot models face -Z, so solve for the yaw that points -Z along `direction`.
		var target_yaw := atan2(-direction.x, -direction.z)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_yaw, turn_speed * delta)

	if _wants_punch() and _punch_timer == 0.0:
		_punch()


func _punch() -> void:
	_punch_timer = punch_cooldown
	visuals.punch()

	var facing := -visuals.global_transform.basis.z
	facing.y = 0.0
	facing = facing.normalized()
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		var to_enemy := enemy.global_position - global_position
		to_enemy.y = 0.0
		if to_enemy.length() <= punch_range and facing.dot(to_enemy.normalized()) > 0.3:
			enemy.take_damage(punch_damage, facing)


func take_damage(amount: int) -> void:
	if is_dead or _hurt_timer > 0.0:
		return
	_hurt_timer = hurt_invulnerability
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	damaged.emit()
	camera_rig.shake(0.6)
	if health == 0:
		die("enemies")


func heal(amount: int) -> void:
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)


func die(cause: String) -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector3.ZERO
	visuals.set_walk_amount(0.0)
	visuals.rotation.z = PI / 2.0  # flop over dramatically
	died.emit(cause)


func reset_for_new_floor(spawn: Vector3) -> void:
	position = spawn
	velocity = Vector3.ZERO


func _wants_punch() -> bool:
	return Input.is_physical_key_pressed(KEY_SPACE) \
		or Input.is_physical_key_pressed(KEY_J) \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


## WASD or arrow keys. Returns x = right, y = toward the camera (+Z).
## TODO: move these into named actions in the Input Map.
func _read_move_input() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		v.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		v.y += 1.0
	return v
