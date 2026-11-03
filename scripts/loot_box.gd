class_name LootBox
extends Area3D
## A loot chest (KayKit CC0 model). Walk into it and the lid pops open.

signal opened(box: LootBox)

const CHEST := preload("res://assets/kaykit/dungeon/chest.glb")
const CHEST_GOLD := preload("res://assets/kaykit/dungeon/chest_gold.glb")

var tier: String = "Bronze"
var _opened: bool = false
var _model: Node3D


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.6, 1.2, 1.6)
	shape.shape = box_shape
	shape.position.y = 0.6
	add_child(shape)

	_model = (CHEST_GOLD if tier == "Gold" else CHEST).instantiate()
	_model.scale = Vector3.ONE * 0.8
	add_child(_model)

	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.75, 0.3)
	glow.light_energy = 0.8
	glow.omni_range = 2.5
	glow.position = Vector3(0, 1.0, 0)
	add_child(glow)

	body_entered.connect(_on_body_entered)


func _process(_delta: float) -> void:
	if not _opened:
		# A little "pick me" wiggle.
		_model.rotation.y = sin(Time.get_ticks_msec() / 300.0) * 0.08


func _on_body_entered(body: Node3D) -> void:
	if _opened or not (body is Player) or (body as Player).is_dead:
		return
	_opened = true
	opened.emit(self)
	var lid := _model.find_child("*lid*", true, false) as Node3D
	var tween := create_tween()
	if lid != null:
		tween.tween_property(lid, "rotation:x", -1.9, 0.25).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(0.8)
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.3)
	tween.tween_callback(queue_free)
