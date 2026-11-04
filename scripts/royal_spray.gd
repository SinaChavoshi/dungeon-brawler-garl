class_name RoyalSpray
extends Node3D
## Duchess's signature attack: a homing puff of extremely regal stink.

var target: Node3D
var damage: int = 1
var speed: float = 11.0
var _life: float = 2.0
var _material := StandardMaterial3D.new()


func _ready() -> void:
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = Color(0.55, 1.0, 0.35, 0.65)
	for i in 3:
		var puff := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.16 - 0.03 * i
		sphere.height = sphere.radius * 2.0
		puff.mesh = sphere
		puff.material_override = _material
		puff.position = Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), 0.12 * i)
		add_child(puff)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0 or target == null or not is_instance_valid(target) or not target.is_in_group("enemies"):
		queue_free()
		return
	var aim := target.global_position + Vector3(0, 1.0, 0)
	var to_target := aim - global_position
	if to_target.length() < 0.5:
		if target.has_method("take_damage"):
			target.take_damage(damage, to_target.normalized())
		queue_free()
		return
	global_position += to_target.normalized() * speed * delta
	look_at(aim)
