class_name UnitFrames
extends Control
## Player, target and party frames in the top-left corner, plus enemy
## nameplates and floating combat numbers drawn over the 3D view.

const FRAME := Vector2(232, 58)
const PORTRAITS := {
	"garl": preload("res://assets/icons/portrait_garl.png"),
	"duchess": preload("res://assets/icons/portrait_duchess.png"),
	"skeleton": preload("res://assets/icons/portrait_skeleton.png"),
	"dummy": preload("res://assets/icons/portrait_dummy.png"),
}
const HOSTILE := Color(0.85, 0.15, 0.12)
const NEUTRAL := Color(0.95, 0.8, 0.15)
const FRIENDLY := Color(0.15, 0.8, 0.2)

var player: Player
var duchess: Node3D
## Floating numbers: {pos (Vector3), text, color, age}
var _floaters: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func pop_number(at: Vector3, text: String, color: Color) -> void:
	_floaters.append({"pos": at + Vector3(randf_range(-0.3, 0.3), 2.2, 0.0), "text": text, "color": color, "age": 0.0})


func _process(delta: float) -> void:
	for f in _floaters:
		f["age"] += delta
	_floaters = _floaters.filter(func(f: Dictionary) -> bool: return f["age"] < 1.2)
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		_draw_nameplates(camera)
		_draw_floaters(camera)

	_frame(Vector2(16, 14), "Garl", "Level 1 Crawler", PORTRAITS["garl"],
		float(player.health) / float(maxi(player.max_health, 1)), "%d / %d" % [player.health, player.max_health], FRIENDLY)
	_frame(Vector2(16, 14 + FRAME.y + 10), "Duchess Pumpernickel III", "Companion", PORTRAITS["duchess"],
		1.0, "Diva", Color(0.85, 0.35, 0.7), 0.82)
	var t := player.target
	if t != null and is_instance_valid(t):
		var is_dummy := t is TrainingDummy
		var fraction: float = t.call("health_fraction") if t.has_method("health_fraction") else 1.0
		_frame(Vector2(16 + FRAME.x + 16, 14), str(t.get("display_name")), "Training equipment" if is_dummy else "Undead",
			PORTRAITS["dummy" if is_dummy else "skeleton"], fraction, "%d%%" % int(round(fraction * 100.0)),
			NEUTRAL if is_dummy else HOSTILE)


func _frame(at: Vector2, title: String, subtitle: String, portrait: Texture2D, fraction: float,
		bar_text: String, bar_color: Color, size_scale: float = 1.0) -> void:
	var font := get_theme_default_font()
	var box := Rect2(at, FRAME * size_scale)
	draw_rect(box, Color(0.04, 0.035, 0.06, 0.88))
	draw_rect(box, Color(0.5, 0.42, 0.26), false, 2.0)
	var p := box.size.y - 8.0
	draw_texture_rect(portrait, Rect2(at + Vector2(4, 4), Vector2(p, p)), false)
	var x := at.x + p + 12.0
	var w := box.end.x - x - 8.0
	draw_string_outline(font, Vector2(x, at.y + 18.0 * size_scale), title, HORIZONTAL_ALIGNMENT_LEFT, w, int(15 * size_scale), 4, Color.BLACK)
	draw_string(font, Vector2(x, at.y + 18.0 * size_scale), title, HORIZONTAL_ALIGNMENT_LEFT, w, int(15 * size_scale), Color(1, 0.86, 0.35))
	var bar := Rect2(Vector2(x, at.y + 25.0 * size_scale), Vector2(w, 14.0 * size_scale))
	draw_rect(bar, Color(0.1, 0.1, 0.1))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(fraction, 0.0, 1.0), bar.size.y)), bar_color)
	draw_rect(bar, Color(0, 0, 0), false, 1.0)
	draw_string_outline(font, bar.position + Vector2(0, bar.size.y - 2.0), bar_text, HORIZONTAL_ALIGNMENT_CENTER, w, int(12 * size_scale), 3, Color.BLACK)
	draw_string(font, bar.position + Vector2(0, bar.size.y - 2.0), bar_text, HORIZONTAL_ALIGNMENT_CENTER, w, int(12 * size_scale), Color.WHITE)
	draw_string(font, Vector2(x, box.end.y - 5.0), subtitle, HORIZONTAL_ALIGNMENT_LEFT, w, int(11 * size_scale), Color(0.7, 0.7, 0.7))


func _draw_nameplates(camera: Camera3D) -> void:
	var font := get_theme_default_font()
	for node in get_tree().get_nodes_in_group("hittable"):
		var thing := node as Node3D
		var head := thing.global_position + Vector3(0.0, 2.35, 0.0)
		if camera.is_position_behind(head) or camera.global_position.distance_to(head) > 30.0:
			continue
		var at := camera.unproject_position(head)
		var targeted := thing == player.target
		var is_dummy := thing is TrainingDummy
		var color := NEUTRAL if is_dummy else HOSTILE
		var w := 84.0 if targeted else 70.0
		var bar := Rect2(at + Vector2(-w / 2.0, 0.0), Vector2(w, 7.0))
		var fraction: float = thing.call("health_fraction") if thing.has_method("health_fraction") else 1.0
		draw_rect(bar.grow(1.0), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * fraction, bar.size.y)), color)
		if targeted:
			draw_rect(bar.grow(2.0), Color(1, 1, 1, 0.9), false, 1.5)
		var label := str(thing.get("display_name"))
		draw_string_outline(font, at + Vector2(-80, -4), label, HORIZONTAL_ALIGNMENT_CENTER, 160, 13, 4, Color.BLACK)
		draw_string(font, at + Vector2(-80, -4), label, HORIZONTAL_ALIGNMENT_CENTER, 160, 13, color.lightened(0.35))


func _draw_floaters(camera: Camera3D) -> void:
	var font := get_theme_default_font()
	for f in _floaters:
		var age: float = f["age"]
		var pos: Vector3 = f["pos"] + Vector3(0.0, age * 1.2, 0.0)
		if camera.is_position_behind(pos):
			continue
		var at := camera.unproject_position(pos)
		var color: Color = f["color"]
		color.a = clampf(1.6 - age * 1.4, 0.0, 1.0)
		var font_size := int(26 + 10 * maxf(0.0, 0.15 - age) / 0.15)
		draw_string_outline(font, at + Vector2(-60, 0), f["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, font_size, 6, Color(0, 0, 0, color.a))
		draw_string(font, at + Vector2(-60, 0), f["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, font_size, color)
