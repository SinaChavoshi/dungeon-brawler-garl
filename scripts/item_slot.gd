class_name ItemSlot
extends Control
## One square button that can hold an item or an ability: a bag slot, a gear
## slot on the character sheet, an action bar button or a spellbook entry.
## It draws itself and supports hover tooltips, clicks and drag-and-drop;
## GameUI decides what's in it and what a drop means.

const SIZE := 46.0

## "bag", "gear", "action" or "spell"
var kind: String = "bag"
## Bag index, gear slot name, action bar index or ability id.
var key: Variant
var ui: GameUI
## Small text in the corner (the keybind on action buttons).
var hotkey: String = ""
var hovered: bool = false
var _flash: float = 0.0
var _dragging_from_me: bool = false


func _init(slot_kind: String = "bag", slot_key: Variant = 0, owner_ui: GameUI = null) -> void:
	kind = slot_kind
	key = slot_key
	ui = owner_ui
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta * 3.0, 0.0)
	queue_redraw()


func flash() -> void:
	_flash = 1.0


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.03, 0.03, 0.04, 0.92))
	var icon := ui.slot_icon(self)
	if icon != null:
		draw_texture_rect(icon, rect.grow(-2.0), false)
	else:
		var hint := ui.slot_hint(self)
		if hint != "":
			_text(hint, Vector2(0, size.y / 2.0 + 4.0), 11, Color(1, 1, 1, 0.35), HORIZONTAL_ALIGNMENT_CENTER)
	var fraction := ui.slot_cooldown(self)
	if fraction > 0.0:
		_draw_sweep(rect.grow(-2.0), fraction)
		var left := ui.slot_cooldown_seconds(self)
		if left >= 1.0:
			_text(str(ceili(left)), Vector2(0, size.y / 2.0 + 7.0), 18, Color(1, 0.95, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	var count := ui.slot_count(self)
	if count > 1:
		_text(str(count), Vector2(-4, size.y - 4.0), 13, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	if hotkey != "":
		_text(hotkey, Vector2(4, 14), 12, Color(0.9, 0.9, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
	var border := ui.slot_border(self)
	draw_rect(rect, border, false, 2.0)
	if hovered:
		draw_rect(rect, Color(1, 1, 1, 0.12))
	if _flash > 0.0:
		draw_rect(rect, Color(1, 1, 0.75, 0.5 * _flash))


func _text(text: String, at: Vector2, font_size: int, color: Color, align: HorizontalAlignment) -> void:
	var font := get_theme_default_font()
	var width := size.x if align != HORIZONTAL_ALIGNMENT_LEFT else -1.0
	draw_string_outline(font, at, text, align, width, font_size, 4, Color.BLACK)
	draw_string(font, at, text, align, width, font_size, color)


## Dark clock wedge for cooldowns.
func _draw_sweep(rect: Rect2, fraction: float) -> void:
	var center := rect.get_center()
	var points := PackedVector2Array([center])
	var steps := 24
	for s in steps + 1:
		var a := -PI / 2.0 + TAU * fraction * float(s) / float(steps)
		var dir := Vector2(cos(a), sin(a))
		points.append(center + dir * (rect.size.x / 2.0) / maxf(absf(dir.x), absf(dir.y)))
	draw_colored_polygon(points, Color(0, 0, 0, 0.62))


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_LEFT and (kind == "action" or kind == "spell"):
		ui.slot_activate(self)
		accept_event()
	elif button.button_index == MOUSE_BUTTON_RIGHT:
		ui.slot_activate(self)
		accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	var data: Variant = ui.slot_drag_data(self)
	if data == null:
		return null
	var preview := TextureRect.new()
	preview.texture = ui.slot_icon(self)
	preview.size = Vector2(SIZE, SIZE)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.modulate.a = 0.85
	set_drag_preview(preview)
	ui.hide_tooltip()
	_dragging_from_me = true
	return data


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return ui.slot_can_drop(self, data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	ui.slot_drop(self, data)


func _notification(what: int) -> void:
	# Dragging an action button off the bar and letting go clears it.
	if what == NOTIFICATION_DRAG_END and _dragging_from_me:
		_dragging_from_me = false
		if kind == "action" and not get_viewport().gui_is_drag_successful():
			ui.slot_clear(self)


func _on_mouse_entered() -> void:
	hovered = true
	ui.show_tooltip(self)


func _on_mouse_exited() -> void:
	hovered = false
	ui.hide_tooltip()
