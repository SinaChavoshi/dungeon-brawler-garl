class_name CameraRig
extends Node3D
## Orbiting follow camera. Drag with the left mouse button to rotate,
## scroll to zoom. Lives under the player, so it follows him around.

@export var distance: float = 13.0
@export var min_distance: float = 6.0
@export var max_distance: float = 24.0
@export var pitch_degrees: float = -58.0
@export var min_pitch: float = -80.0
@export var max_pitch: float = -20.0
@export var drag_sensitivity: float = 0.3

var _dragging: bool = false
var _shake: float = 0.0

@onready var camera: Camera3D = $Camera


func _ready() -> void:
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
		elif button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			distance = maxf(min_distance, distance - 1.0)
			_apply()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			distance = minf(max_distance, distance + 1.0)
			_apply()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		rotation.y -= deg_to_rad(motion.relative.x * drag_sensitivity)
		pitch_degrees = clampf(pitch_degrees - motion.relative.y * drag_sensitivity, min_pitch, max_pitch)
		_apply()


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 2.5, 0.0)
		camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.4
		camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.4
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


## Kick the camera. 0.5 is a bonk, 1.0 is a wallop.
func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _apply() -> void:
	var pitch := deg_to_rad(pitch_degrees)
	camera.rotation = Vector3(pitch, 0.0, 0.0)
	camera.position = Vector3(0.0, -sin(pitch) * distance, cos(pitch) * distance)
