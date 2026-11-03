class_name LootBox
extends Area3D
## A Bronze loot box. Walk into it to open it.

signal opened(box: LootBox)

var tier: String = "Bronze"


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.0, 1.0, 1.0)
	shape.shape = box_shape
	shape.position.y = 0.5
	add_child(shape)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.8, 0.8, 0.8)
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.5, 0.2)
	material.emission_enabled = true
	material.emission = Color(0.6, 0.35, 0.1)
	material.emission_energy_multiplier = 0.6
	mesh.material_override = material
	mesh.position.y = 0.4
	add_child(mesh)

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is Player and not (body as Player).is_dead:
		opened.emit(self)
		queue_free()
