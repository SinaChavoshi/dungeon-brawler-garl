class_name GarlModel
extends Node3D
## Garl, built from primitive shapes: a stubby blue alien with huge eyes,
## antennae, polka-dot boxers and exactly one sock. Faces -Z.
## Animation is procedural: a waddle while walking and a jab when punching.

const SKIN := Color(0.27, 0.55, 1.0)
const SKIN_DARK := Color(0.2, 0.42, 0.85)
const BOXERS := Color(0.9, 0.18, 0.28)

var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _body: Node3D
var _antenna_l: Node3D
var _antenna_r: Node3D
var _walk_phase: float = 0.0
var _walk_amount: float = 0.0
var _time: float = 0.0
var _punch_right: bool = true


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)

	# Torso and belly.
	_add_mesh(_body, _capsule(0.36, 0.95), SKIN, Vector3(0, 0.95, 0))
	_add_mesh(_body, _sphere(0.3), Color(0.55, 0.75, 1.0), Vector3(0, 0.85, -0.12), Vector3(1.0, 1.1, 0.7))

	# Boxers with polka dots.
	_add_mesh(_body, _cylinder(0.39, 0.38, 0.32), BOXERS, Vector3(0, 0.62, 0))
	for i in 10:
		var angle := TAU * float(i) / 10.0
		var y := 0.55 + 0.12 * float(i % 2)
		_add_mesh(_body, _sphere(0.045), Color.WHITE,
			Vector3(sin(angle) * 0.39, y, cos(angle) * 0.39))

	# Big head with huge eyes.
	var head := Node3D.new()
	head.position = Vector3(0, 1.62, 0)
	_body.add_child(head)
	_add_mesh(head, _sphere(0.42), SKIN, Vector3.ZERO, Vector3(1.1, 0.95, 1.0))
	for side in [-1.0, 1.0]:
		_add_mesh(head, _sphere(0.15), Color.WHITE, Vector3(0.17 * side, 0.06, -0.33))
		_add_mesh(head, _sphere(0.07), Color(0.05, 0.05, 0.1), Vector3(0.17 * side, 0.06, -0.45))
		_add_mesh(head, _sphere(0.025), Color.WHITE, Vector3(0.15 * side, 0.09, -0.51))
	_add_mesh(head, _cylinder(0.09, 0.09, 0.02), Color(0.1, 0.1, 0.2),
		Vector3(0, -0.18, -0.38), Vector3(1.6, 1.0, 0.5), Vector3(PI / 2, 0, 0))

	# Antennae with glowing tips.
	_antenna_l = _make_antenna(head, -1.0)
	_antenna_r = _make_antenna(head, 1.0)

	# Arms (pivot at the shoulder).
	_left_arm = _make_limb(_body, Vector3(-0.42, 1.2, 0), 0.1, 0.55, SKIN_DARK)
	_right_arm = _make_limb(_body, Vector3(0.42, 1.2, 0), 0.1, 0.55, SKIN_DARK)
	_add_mesh(_left_arm, _sphere(0.13), SKIN, Vector3(0, -0.55, 0))
	_add_mesh(_right_arm, _sphere(0.13), SKIN, Vector3(0, -0.55, 0))

	# Legs (pivot at the hip). One sock, as is tradition.
	_left_leg = _make_limb(self, Vector3(-0.17, 0.5, 0), 0.12, 0.42, SKIN_DARK)
	_right_leg = _make_limb(self, Vector3(0.17, 0.5, 0), 0.12, 0.42, SKIN_DARK)
	_add_mesh(_left_leg, _cylinder(0.13, 0.13, 0.22), Color(0.95, 0.95, 0.9), Vector3(0, -0.36, 0))
	_add_mesh(_left_leg, _sphere(0.14), Color(0.95, 0.95, 0.9), Vector3(0, -0.46, -0.06), Vector3(1, 0.6, 1.4))
	_add_mesh(_right_leg, _sphere(0.14), SKIN, Vector3(0, -0.46, -0.06), Vector3(1, 0.6, 1.4))


func _process(delta: float) -> void:
	_time += delta
	_walk_phase += delta * 12.0 * _walk_amount
	var swing := sin(_walk_phase) * 0.6 * _walk_amount
	_left_leg.rotation.x = swing
	_right_leg.rotation.x = -swing
	_left_arm.rotation.x = lerpf(_left_arm.rotation.x, -swing * 0.8, 10.0 * delta)
	_right_arm.rotation.x = lerpf(_right_arm.rotation.x, swing * 0.8, 10.0 * delta)
	_body.position.y = absf(sin(_walk_phase)) * 0.08 * _walk_amount
	_body.rotation.z = sin(_walk_phase) * 0.08 * _walk_amount
	_antenna_l.rotation.z = 0.25 + sin(_time * 3.0) * 0.1 + swing * 0.2
	_antenna_r.rotation.z = -0.25 - sin(_time * 3.0 + 1.0) * 0.1 - swing * 0.2


## 0 = standing still, 1 = full speed.
func set_walk_amount(amount: float) -> void:
	_walk_amount = clampf(amount, 0.0, 1.0)


func punch() -> void:
	var arm := _right_arm if _punch_right else _left_arm
	_punch_right = not _punch_right
	var tween := create_tween()
	tween.tween_property(arm, "rotation:x", PI / 2.0, 0.06)
	tween.tween_property(arm, "rotation:x", 0.0, 0.15)


func _make_antenna(head: Node3D, side: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(0.15 * side, 0.3, 0)
	head.add_child(pivot)
	_add_mesh(pivot, _cylinder(0.025, 0.025, 0.45), SKIN_DARK, Vector3(0, 0.22, 0))
	var tip := _add_mesh(pivot, _sphere(0.08), Color(1.0, 0.9, 0.3), Vector3(0, 0.47, 0))
	var material := tip.material_override as StandardMaterial3D
	material.emission_enabled = true
	material.emission = Color(1.0, 0.85, 0.2)
	material.emission_energy_multiplier = 2.0
	return pivot


func _make_limb(parent: Node3D, at: Vector3, radius: float, length: float, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	parent.add_child(pivot)
	_add_mesh(pivot, _capsule(radius, length), color, Vector3(0, -length / 2.0, 0))
	return pivot


func _add_mesh(parent: Node3D, mesh: Mesh, color: Color, at: Vector3,
		scale_by: Vector3 = Vector3.ONE, rotate_by: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	instance.material_override = material
	instance.position = at
	instance.scale = scale_by
	instance.rotation = rotate_by
	parent.add_child(instance)
	return instance


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return mesh


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	return mesh


func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	return mesh
