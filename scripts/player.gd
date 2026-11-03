extends CharacterBody3D
## Garl, our pantsless hero. For now he just walks around the test room.
##
## Only the Visuals node turns to face the movement direction. The body and
## the child camera stay unrotated, so the camera keeps its fixed angle.

@export var move_speed: float = 6.0
@export var turn_speed: float = 12.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var visuals: Node3D = $Visuals


func _physics_process(delta: float) -> void:
	var input := _read_move_input()
	var direction := Vector3(input.x, 0.0, input.y)
	if direction.length() > 1.0:
		direction = direction.normalized()

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


## WASD or arrow keys. Returns x = right, y = toward the camera (+Z).
## TODO: move these into named actions in the Input Map once we add attacks.
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
