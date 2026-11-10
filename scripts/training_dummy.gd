class_name TrainingDummy
extends StaticBody3D
## A punching dummy for the Training Room. It has signed a waiver.
## Turns its target green once it's been hit enough times.

signal trained(dummy: TrainingDummy)

@export var hits_needed: int = 3

var hits: int = 0
var display_name: String = "Training Dummy"
var _wobble: Node3D
var _target_material := StandardMaterial3D.new()


func _ready() -> void:
	add_to_group("hittable")
	add_to_group("dummies")
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)

	var wood := Color(0.45, 0.3, 0.18)
	var burlap := Color(0.76, 0.64, 0.42)
	_add(self, _cylinder(0.08, 0.6), wood, Vector3(0, 0.3, 0))
	_add(self, _cylinder(0.4, 0.08), wood, Vector3(0, 0.04, 0))
	_wobble = Node3D.new()
	_wobble.position.y = 0.55
	add_child(_wobble)
	_add(_wobble, _capsule(0.38, 1.0), burlap, Vector3(0, 0.45, 0))
	_add(_wobble, _sphere(0.27), burlap, Vector3(0, 1.15, 0))
	_add(_wobble, _cylinder(0.05, 1.1), wood, Vector3(0, 0.55, 0), Vector3(0, 0, PI / 2))
	# A painted target on its chest.
	_target_material.albedo_color = Color(0.85, 0.15, 0.15)
	var target := MeshInstance3D.new()
	target.mesh = _cylinder(0.2, 0.02)
	target.material_override = _target_material
	target.position = Vector3(0, 0.55, -0.37)
	target.rotation.x = PI / 2
	_wobble.add_child(target)
	var bullseye := _add(_wobble, _cylinder(0.08, 0.03), Color.WHITE, Vector3(0, 0.55, -0.38))
	bullseye.rotation.x = PI / 2


func health_fraction() -> float:
	return clampf(1.0 - float(hits) / float(hits_needed), 0.0, 1.0)


func take_damage(_amount: int, push_direction: Vector3) -> void:
	hits += 1
	var axis := Vector3(push_direction.z, 0.0, -push_direction.x).normalized()
	var tween := create_tween()
	tween.tween_property(_wobble, "rotation", axis * 0.5, 0.06)
	tween.tween_property(_wobble, "rotation", -axis * 0.25, 0.15)
	tween.tween_property(_wobble, "rotation", Vector3.ZERO, 0.2)
	if hits == hits_needed:
		_target_material.albedo_color = Color(0.2, 0.85, 0.3)
		trained.emit(self)


func _add(parent: Node3D, mesh: Mesh, color: Color, at: Vector3, rotate_by: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	instance.material_override = material
	instance.position = at
	instance.rotation = rotate_by
	parent.add_child(instance)
	return instance


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return mesh


func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return mesh
