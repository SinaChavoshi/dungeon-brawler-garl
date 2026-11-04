class_name Hud
extends CanvasLayer
## On-screen stats, the system notification feed, the minimap and the full map.
## Built in code.

const HOST_COLOR := Color(1.0, 0.85, 0.3)

var minimap := MapView.new()
var full_map := MapView.new()

var _stats := Label.new()
var _feed := VBoxContainer.new()
var _center := Label.new()
var _controls := Label.new()
var _map_label := Label.new()

var _health: int = 0
var _max_health: int = 0
var _floor: int = 1
var _time_left: float = 0.0
var _gold: int = 0


func _ready() -> void:
	_stats.position = Vector2(16, 12)
	_stats.add_theme_font_size_override("font_size", 22)
	_stats.add_theme_constant_override("outline_size", 6)
	_stats.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	add_child(_stats)

	# System notifications stack down from the top-center.
	_feed.anchor_left = 0.5
	_feed.anchor_right = 0.5
	_feed.offset_left = -270
	_feed.offset_right = 270
	_feed.offset_top = 12
	_feed.add_theme_constant_override("separation", 6)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed)

	_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_center.offset_left = -420
	_center.offset_right = 420
	_center.offset_top = -100
	_center.offset_bottom = 100
	_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_center.add_theme_font_size_override("font_size", 34)
	_center.add_theme_constant_override("outline_size", 8)
	_center.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	add_child(_center)

	_controls.anchor_top = 1.0
	_controls.anchor_bottom = 1.0
	_controls.offset_left = 16
	_controls.offset_top = -92
	_controls.offset_bottom = -10
	_controls.add_theme_font_size_override("font_size", 14)
	_controls.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_controls.text = "WASD move · Left click / Space / J punch · Right-drag camera · Wheel zoom\nI inventory · Q quick heal · M map"
	add_child(_controls)

	# Minimap in the top-right corner.
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.offset_left = -196
	minimap.offset_right = -16
	minimap.offset_top = 16
	minimap.offset_bottom = 196
	add_child(minimap)

	# Full map in the middle of the screen, hidden until M.
	full_map.full = true
	full_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	full_map.offset_left = 120
	full_map.offset_right = -120
	full_map.offset_top = 70
	full_map.offset_bottom = -70
	full_map.visible = false
	add_child(full_map)
	_map_label.text = "MAP  ·  only shows what you've seen  ·  M to close"
	_map_label.position = Vector2(132, 76)
	_map_label.visible = false
	add_child(_map_label)


func set_level(level: Level, player: Player) -> void:
	for view in [minimap, full_map]:
		view.level = level
		view.player = player


func toggle_full_map() -> void:
	full_map.visible = not full_map.visible
	_map_label.visible = full_map.visible
	minimap.visible = not full_map.visible


func set_health(current: int, maximum: int) -> void:
	_health = current
	_max_health = maximum
	_refresh()


func set_floor(number: int) -> void:
	_floor = number
	_refresh()


func set_time(seconds_left: float) -> void:
	_time_left = maxf(seconds_left, 0.0)
	_refresh()


func set_gold(amount: int) -> void:
	_gold = amount
	_refresh()


## Push a system notification card onto the feed.
func notify(title: String, body: String, color: Color = HOST_COLOR, seconds: float = 6.0) -> void:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.03, 0.1, 0.88)
	style.border_color = color
	style.border_width_left = 5
	style.set_corner_radius_all(4)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	card.add_child(column)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_color_override("font_color", color)
	heading.add_theme_font_size_override("font_size", 14)
	column.add_child(heading)
	var text := Label.new()
	text.text = body
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(500, 0)
	text.add_theme_font_size_override("font_size", 17)
	column.add_child(text)

	_feed.add_child(card)
	while _feed.get_child_count() > 4:
		var oldest := _feed.get_child(0)
		_feed.remove_child(oldest)
		oldest.queue_free()

	card.modulate.a = 0.0
	var tween := card.create_tween()
	tween.tween_property(card, "modulate:a", 1.0, 0.2)
	tween.tween_interval(seconds + body.length() * 0.03)
	tween.tween_property(card, "modulate:a", 0.0, 0.6)
	tween.tween_callback(card.queue_free)


## Shorthand for a line from the dungeon AI.
func announce(text: String) -> void:
	notify("H.O.S.T.", text)


func show_center(text: String) -> void:
	_center.text = text


func _refresh() -> void:
	var seconds := int(ceil(_time_left))
	var minutes := floori(seconds / 60.0)
	_stats.text = "HP %d / %d\nFloor %d\nCollapse in %d:%02d\nGold %d" % [
		_health, _max_health, _floor, minutes, seconds % 60, _gold]
