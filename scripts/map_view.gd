class_name MapView
extends Control
## Draws the explored part of the current floor, plus markers for Garl,
## Duchess, enemies, loot and the way down. Used for both the corner
## minimap (follows Garl) and the full map (fits the whole floor).

const FLOOR_COLOR := Color(0.55, 0.52, 0.62, 0.9)

var level: Level
var player: Player
var full: bool = false
var minimap_scale: float = 5.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.01, 0.05, 0.75))
	if level == null or not is_instance_valid(level) or player == null:
		return

	var scale_px := minimap_scale
	var center := Vector2(player.global_position.x, player.global_position.z)
	if full:
		var area := level.bounds.grow(2.0)
		scale_px = minf(size.x / area.size.x, size.y / area.size.y)
		center = area.get_center()

	var cell_px := Level.MAP_CELL * scale_px
	for cell in level.explored:
		var corner := Vector2(cell) * Level.MAP_CELL
		draw_rect(Rect2(_to_map(corner, center, scale_px), Vector2(cell_px, cell_px)).grow(0.5), FLOOR_COLOR)

	for node in get_tree().get_nodes_in_group("stairs"):
		_marker(node as Node3D, center, scale_px, Color(0.3, 0.7, 1.0), 6.0, true)
	for node in get_tree().get_nodes_in_group("loot"):
		_marker(node as Node3D, center, scale_px, Color(1.0, 0.8, 0.2), 4.5, true)
	for node in get_tree().get_nodes_in_group("enemies"):
		_marker(node as Node3D, center, scale_px, Color(1.0, 0.25, 0.25), 4.0, true)
	for node in get_tree().get_nodes_in_group("companion"):
		_marker(node as Node3D, center, scale_px, Color(1.0, 0.45, 0.8), 4.0, false)

	# Garl: a triangle pointing the way he faces.
	var here := _to_map(Vector2(player.global_position.x, player.global_position.z), center, scale_px)
	var yaw := player.visuals.rotation.y
	var forward := Vector2(-sin(yaw), -cos(yaw))
	var side := Vector2(-forward.y, forward.x)
	var tip := 8.0 if full else 7.0
	draw_colored_polygon(PackedVector2Array([
		here + forward * tip, here - forward * tip * 0.6 + side * tip * 0.6,
		here - forward * tip * 0.6 - side * tip * 0.6]), Color(0.35, 0.65, 1.0))

	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.35), false, 2.0)


func _marker(node: Node3D, center: Vector2, scale_px: float, color: Color, radius: float, only_if_seen: bool) -> void:
	if node == null or not node.is_inside_tree():
		return
	if only_if_seen and not level.is_revealed(node.global_position):
		return
	var at := _to_map(Vector2(node.global_position.x, node.global_position.z), center, scale_px)
	draw_circle(at, radius, color)


func _to_map(world: Vector2, center: Vector2, scale_px: float) -> Vector2:
	return (world - center) * scale_px + size / 2.0
