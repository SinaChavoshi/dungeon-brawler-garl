class_name CameraRig
extends Node3D
## Third-person camera, MMO style. Sits behind Garl's shoulder on a spring
## arm so rock walls push it in instead of blocking the view.
##
##   Left drag   orbit the camera around Garl (he keeps facing his way)
##   Right drag  turn Garl and the camera together (steer with the mouse)
##   Wheel       zoom
##
## The rig is top-level (it doesn't inherit Garl's rotation); Player tells
## it where to look and which way Garl faces.

signal clicked(button: MouseButton, screen_position: Vector2)

@export var distance: float = 7.0
@export var min_distance: float = 2.0
@export var max_distance: float = 18.0
@export var pitch_degrees: float = -22.0
@export var min_pitch: float = -75.0
@export var max_pitch: float = 35.0
@export var mouse_sensitivity: float = 0.25
@export var follow_height: float = 1.55
## How fast the camera swings back behind Garl when he runs.
@export var recenter_speed: float = 4.0

var yaw: float = 0.0
var orbiting: bool = false
var steering: bool = false
var _drag_travel: float = 0.0
var _press_position := Vector2.ZERO
var _shake: float = 0.0
var _target: Node3D

@onready var arm: SpringArm3D = $Arm
@onready var camera: Camera3D = $Arm/Camera


func _ready() -> void:
	top_level = true
	_target = get_parent() as Node3D
	arm.add_excluded_object((_target as CollisionObject3D).get_rid())
	arm.spring_length = distance
	arm.margin = 0.3
	var probe := SphereShape3D.new()
	probe.radius = 0.25
	arm.shape = probe
	arm.collision_mask = Level.TERRAIN_LAYER  # rock and props only, not skeletons


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null:
		match button.button_index:
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
				_on_drag_button(button)
			MOUSE_BUTTON_WHEEL_UP:
				if button.pressed:
					distance = maxf(min_distance, distance - 1.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					distance = minf(max_distance, distance + 1.0)
		return
	var motion := event as InputEventMouseMotion
	if motion != null and (orbiting or steering):
		_drag_travel += motion.relative.length()
		if _drag_travel < 4.0:
			return  # still might be a click
		yaw -= deg_to_rad(motion.relative.x * mouse_sensitivity)
		pitch_degrees = clampf(pitch_degrees - motion.relative.y * mouse_sensitivity, min_pitch, max_pitch)
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_drag_button(button: InputEventMouseButton) -> void:
	var is_left := button.button_index == MOUSE_BUTTON_LEFT
	if button.pressed:
		if not orbiting and not steering:
			_drag_travel = 0.0
			_press_position = button.position
		if is_left:
			orbiting = true
		else:
			steering = true
		return
	if is_left:
		orbiting = false
	else:
		steering = false
	if not orbiting and not steering:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			Input.warp_mouse(_press_position)
		if _drag_travel < 4.0:
			clicked.emit(button.button_index, _press_position)


## Called by Player every frame.
func follow(facing_yaw: float, moving: bool, delta: float) -> void:
	global_position = _target.global_position + Vector3(0.0, follow_height, 0.0)
	if steering:
		pass  # Player turns to match our yaw
	elif moving and not orbiting:
		yaw = lerp_angle(yaw, facing_yaw, clampf(recenter_speed * delta, 0.0, 1.0))
	rotation = Vector3(deg_to_rad(pitch_degrees), yaw, 0.0)
	arm.spring_length = lerpf(arm.spring_length, distance, clampf(10.0 * delta, 0.0, 1.0))

	if _shake > 0.0:
		_shake = maxf(_shake - delta * 2.5, 0.0)
		camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.3
		camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.3
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


## Kick the camera. 0.5 is a bonk, 1.0 is a wallop.
func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Snap to a spot right away (used for screenshots and new floors).
func snap(facing_yaw: float, new_distance: float = -1.0, new_pitch: float = 999.0) -> void:
	yaw = facing_yaw
	if new_distance > 0.0:
		distance = new_distance
		arm.spring_length = new_distance
	if new_pitch < 900.0:
		pitch_degrees = new_pitch
	global_position = _target.global_position + Vector3(0.0, follow_height, 0.0)
	rotation = Vector3(deg_to_rad(pitch_degrees), yaw, 0.0)
