class_name Stairs
extends Area3D
## The way down: an open grate with an ominous glow. Step on it to descend.

signal reached

const GRATE := preload("res://assets/kaykit/dungeon/floor_tile_big_grate_open.glb")


func _ready() -> void:
	add_to_group("stairs")
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(2.4, 1.0, 2.4)
	shape.shape = box_shape
	shape.position.y = 0.5
	add_child(shape)

	var grate := GRATE.instantiate() as Node3D
	add_child(grate)

	var glow := OmniLight3D.new()
	glow.light_color = Color(0.3, 0.5, 1.0)
	glow.light_energy = 2.5
	glow.omni_range = 5.0
	glow.position = Vector3(0, -0.5, 0)
	add_child(glow)

	var beam := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.2
	cylinder.bottom_radius = 1.4
	cylinder.height = 3.0
	beam.mesh = cylinder
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.35, 0.55, 1.0, 0.18)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = material
	beam.position.y = 1.5
	add_child(beam)

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is Player and not (body as Player).is_dead:
		reached.emit()
