class_name GarlModel
extends Node3D
## Garl: a rigged low-poly blue alien in polka-dot boxers and one sock.
## The mesh and its 76 animations come from assets/characters/garl.glb
## (built by tools/make_garl.py from the CC0 KayKit Barbarian). Antennae and
## googly eyes are added here. Faces -Z like other Godot models.
##
## Animation runs through an AnimationTree:
##   locomotion (2D blend: idle, run, backpedal, strafes) -> air (jump loop)
##   -> upper-body one-shot (attacks while moving) -> full-body one-shot
##   (attacks while standing, dodges) -> dead.

const GARL := preload("res://assets/characters/garl.glb")
const HIDDEN := ["Barbarian_Hat", "Barbarian_Cape", "1H_Axe_Offhand", "Barbarian_Round_Shield",
	"1H_Axe", "2H_Axe", "Mug"]
const LOOPING := ["Unarmed_Idle", "Idle", "Running_A", "Running_B", "Walking_A", "Walking_Backwards",
	"Running_Strafe_Left", "Running_Strafe_Right", "Jump_Idle", "Spellcasting", "Blocking"]
## Bones that an upper-body attack is allowed to move.
const UPPER_BONES := ["spine", "chest", "head", "upperarm.l", "lowerarm.l", "wrist.l", "hand.l", "handslot.l",
	"upperarm.r", "lowerarm.r", "wrist.r", "hand.r", "handslot.r", "elbowIK.l", "handIK.l", "elbowIK.r", "handIK.r"]
const SKIN := Color(0.27, 0.59, 0.92)
const MODEL_SCALE := 0.85
## Running_A covers about this many metres per second at MODEL_SCALE.
const RUN_ANIM_SPEED := 5.5

var _model: Node3D
var _anim: AnimationPlayer
var _tree: AnimationTree
var _root: AnimationNodeBlendTree
var _antennae: Array[Node3D] = []
var _time: float = 0.0
var _move := Vector2.ZERO
var _punch_right: bool = true


func _ready() -> void:
	_model = GARL.instantiate() as Node3D
	_model.scale = Vector3.ONE * MODEL_SCALE
	_model.rotation.y = PI  # KayKit characters face +Z
	add_child(_model)
	for node_name in HIDDEN:
		var node := _model.find_child(node_name, true, false) as Node3D
		if node != null:
			node.visible = false
	for mesh in _model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null:
		for anim_name in LOOPING:
			if _anim.has_animation(anim_name):
				_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		_build_tree()
	_add_alien_bits()


func _process(delta: float) -> void:
	_time += delta
	for i in _antennae.size():
		var side := -1.0 if i == 0 else 1.0
		var antenna := _antennae[i]
		antenna.rotation.z = side * (0.3 + sin(_time * 3.0 + i) * 0.08) - _move.x * 0.25
		antenna.rotation.x = -0.15 + sin(_time * 2.3 + i * 2.0) * 0.06 + _move.y * 0.35


## local_move: x = strafe right, y = forward, both in -1..1 (scaled by speed).
## speed is metres per second, used to match the run cycle to the ground.
func set_motion(local_move: Vector2, speed: float, on_floor: bool) -> void:
	_move = local_move
	if _tree == null:
		return
	_tree.set("parameters/loco/blend_position", local_move.limit_length(1.0))
	var scale_by := 1.0
	if local_move.length() > 0.1:
		scale_by = clampf(speed / RUN_ANIM_SPEED, 0.6, 1.6)
		if local_move.y < -0.1 and absf(local_move.x) < 0.3:
			scale_by = clampf(speed / 2.5, 0.6, 1.6)  # backpedal is a walk
	_tree.set("parameters/loco_speed/scale", scale_by)
	_tree.set("parameters/air/transition_request", "ground" if on_floor else "air")


## Plays a one-shot animation. upper_only keeps the legs running.
func play_action(anim_name: String, upper_only: bool = false) -> void:
	if _tree == null or not _anim.has_animation(anim_name):
		return
	var shot := "upper" if upper_only else "full"
	(_root.get_node(shot + "_anim") as AnimationNodeAnimation).animation = anim_name
	_tree.set("parameters/%s/request" % shot, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Alternating jabs. Returns the animation it used.
func punch(upper_only: bool) -> void:
	play_action("Unarmed_Melee_Attack_Punch_A" if _punch_right else "Unarmed_Melee_Attack_Punch_B", upper_only)
	_punch_right = not _punch_right


func hit(upper_only: bool) -> void:
	play_action("Hit_A", upper_only)


func die() -> void:
	if _tree != null:
		_tree.set("parameters/dead/transition_request", "dead")


func _build_tree() -> void:
	_root = AnimationNodeBlendTree.new()

	var loco := AnimationNodeBlendSpace2D.new()
	loco.add_blend_point(_clip("Unarmed_Idle"), Vector2.ZERO)
	loco.add_blend_point(_clip("Running_A"), Vector2(0.0, 1.0))
	loco.add_blend_point(_clip("Walking_Backwards"), Vector2(0.0, -1.0))
	loco.add_blend_point(_clip("Running_Strafe_Left"), Vector2(-1.0, 0.0))
	loco.add_blend_point(_clip("Running_Strafe_Right"), Vector2(1.0, 0.0))
	_root.add_node("loco", loco)
	_root.add_node("loco_speed", AnimationNodeTimeScale.new())
	_root.connect_node("loco_speed", 0, "loco")

	var air := AnimationNodeTransition.new()
	air.add_input("ground")
	air.add_input("air")
	air.xfade_time = 0.12
	_root.add_node("air", air)
	_root.add_node("air_anim", _clip("Jump_Idle"))
	_root.connect_node("air", 0, "loco_speed")
	_root.connect_node("air", 1, "air_anim")

	var upper := AnimationNodeOneShot.new()
	upper.fadein_time = 0.08
	upper.fadeout_time = 0.2
	upper.filter_enabled = true
	var reference := _anim.get_animation("Unarmed_Melee_Attack_Punch_A")
	for track in reference.get_track_count():
		var path := reference.track_get_path(track)
		if path.get_subname_count() > 0 and String(path.get_subname(0)) in UPPER_BONES:
			upper.set_filter_path(path, true)
	_root.add_node("upper", upper)
	_root.add_node("upper_anim", _clip("Unarmed_Melee_Attack_Punch_A"))
	_root.connect_node("upper", 0, "air")
	_root.connect_node("upper", 1, "upper_anim")

	var full := AnimationNodeOneShot.new()
	full.fadein_time = 0.08
	full.fadeout_time = 0.2
	_root.add_node("full", full)
	_root.add_node("full_anim", _clip("Unarmed_Melee_Attack_Punch_A"))
	_root.connect_node("full", 0, "upper")
	_root.connect_node("full", 1, "full_anim")

	var dead := AnimationNodeTransition.new()
	dead.add_input("alive")
	dead.add_input("dead")
	dead.xfade_time = 0.2
	_root.add_node("dead", dead)
	_root.add_node("dead_anim", _clip("Death_A"))
	_root.connect_node("dead", 0, "full")
	_root.connect_node("dead", 1, "dead_anim")
	_root.connect_node("output", 0, "dead")

	_tree = AnimationTree.new()
	_model.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(_anim)
	_tree.tree_root = _root
	_tree.active = true
	# Transitions start with no current input until asked, so ask.
	_tree.set("parameters/air/transition_request", "ground")
	_tree.set("parameters/dead/transition_request", "alive")


## One line about the animation state, for CI logs.
func debug_state() -> String:
	if _tree == null:
		return "no AnimationTree (anim player: %s)" % _anim
	var skeleton := _model.find_child("Skeleton3D", true, false) as Skeleton3D
	var arm := skeleton.find_bone("upperarm.l") if skeleton else -1
	return "tree active=%s valid=%s loco=%s air=%s dead=%s arm_pose=%s arm_rest=%s" % [
		_tree.active, _tree.tree_root != null, _tree.get("parameters/loco/blend_position"),
		_tree.get("parameters/air/current_state"), _tree.get("parameters/dead/current_state"),
		skeleton.get_bone_pose_rotation(arm) if arm >= 0 else "?", skeleton.get_bone_rest(arm).basis.get_rotation_quaternion() if arm >= 0 else "?"]


func _clip(anim_name: String) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = anim_name
	return node


## Antennae and big googly eyes, stuck to the head bone so they follow
## every animation.
func _add_alien_bits() -> void:
	var skeleton := _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	var head_bone := skeleton.find_bone("head")
	if head_bone < 0:
		return
	var attach := BoneAttachment3D.new()
	attach.bone_name = "head"
	skeleton.add_child(attach)
	# Work in the model's rest pose, then convert into the head bone's space.
	var head_rest := skeleton.get_bone_global_rest(head_bone)
	var holder := Node3D.new()
	holder.transform = head_rest.affine_inverse()
	attach.add_child(holder)

	var skin := _material(SKIN, Color.BLACK)
	var glow := _material(Color(0.75, 1.0, 0.35), Color(0.6, 1.0, 0.2) * 2.0)
	var white := _material(Color(0.97, 0.97, 0.95), Color.BLACK)
	var black := _material(Color(0.03, 0.03, 0.06), Color.BLACK)

	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.2 * side, 2.08, -0.02)
		holder.add_child(pivot)
		var stalk := CylinderMesh.new()
		stalk.top_radius = 0.025
		stalk.bottom_radius = 0.045
		stalk.height = 0.5
		stalk.radial_segments = 6
		stalk.rings = 1
		_mesh(pivot, stalk, skin, Vector3(0.0, 0.25, 0.0))
		var tip := SphereMesh.new()
		tip.radius = 0.09
		tip.height = 0.18
		tip.radial_segments = 8
		tip.rings = 4
		_mesh(pivot, tip, glow, Vector3(0.0, 0.52, 0.0))
		_antennae.append(pivot)

		var eye := SphereMesh.new()
		eye.radius = 0.15
		eye.height = 0.3
		eye.radial_segments = 10
		eye.rings = 5
		_mesh(holder, eye, white, Vector3(0.21 * side, 1.66, 0.42))
		var pupil := SphereMesh.new()
		pupil.radius = 0.07
		pupil.height = 0.14
		pupil.radial_segments = 8
		pupil.rings = 4
		_mesh(holder, pupil, black, Vector3(0.2 * side, 1.66, 0.55))


func _mesh(parent: Node3D, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


func _material(color: Color, emission: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
	return material
