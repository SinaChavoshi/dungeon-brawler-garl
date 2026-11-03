class_name Stairs
extends Area3D
## The way down. Step on it to go to the next floor.

signal reached


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(2.0, 1.0, 2.0)
	shape.shape = box_shape
	shape.position.y = 0.5
	add_child(shape)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 0.1, 2.0)
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.3, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.2, 0.4, 1.0)
	material.emission_energy_multiplier = 1.5
	mesh.material_override = material
	mesh.position.y = 0.05
	add_child(mesh)

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is Player and not (body as Player).is_dead:
		reached.emit()
