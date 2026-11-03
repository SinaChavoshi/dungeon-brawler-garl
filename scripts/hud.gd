class_name Hud
extends CanvasLayer
## On-screen stats plus the H.O.S.T. announcer ticker. Built in code.

var _stats := Label.new()
var _announcer := Label.new()
var _center := Label.new()
var _controls := Label.new()
var _queue: Array[String] = []
var _announce_timer: float = 0.0

var _health: int = 0
var _max_health: int = 0
var _floor: int = 1
var _time_left: float = 0.0


func _ready() -> void:
	_stats.position = Vector2(16, 12)
	_stats.add_theme_font_size_override("font_size", 22)
	add_child(_stats)

	_announcer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_announcer.offset_left = -500
	_announcer.offset_right = 500
	_announcer.offset_top = -110
	_announcer.offset_bottom = -40
	_announcer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announcer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_announcer.add_theme_font_size_override("font_size", 20)
	_announcer.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	add_child(_announcer)

	_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_center.offset_left = -400
	_center.offset_right = 400
	_center.offset_top = -80
	_center.offset_bottom = 80
	_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_center.add_theme_font_size_override("font_size", 34)
	add_child(_center)

	_controls.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_controls.offset_left = -460
	_controls.offset_right = -16
	_controls.offset_top = 12
	_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_controls.add_theme_font_size_override("font_size", 16)
	_controls.text = "WASD / arrows: move\nSpace / J / right click: punch\nLeft drag: rotate camera · Wheel: zoom"
	add_child(_controls)


func _process(delta: float) -> void:
	if _announce_timer > 0.0:
		_announce_timer -= delta
	elif not _queue.is_empty():
		_announcer.text = _queue.pop_front()
		_announce_timer = 3.5
	else:
		_announcer.text = ""


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


## Queue a line from the dungeon AI. Lines show one at a time.
func announce(text: String) -> void:
	_queue.append(text)


func show_center(text: String) -> void:
	_center.text = text


func _refresh() -> void:
	var seconds := int(ceil(_time_left))
	_stats.text = "HP %d / %d\nFloor %d\nCollapse in %d:%02d" % [
		_health, _max_health, _floor, seconds / 60, seconds % 60]  # integer minutes
