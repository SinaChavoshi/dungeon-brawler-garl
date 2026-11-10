class_name GameUI
extends CanvasLayer
## The MMO-style windows: action bar (1-9), bags (B or I), character sheet
## (C) and spellbook (P), with tooltips and drag-and-drop between them.
## Nothing pauses: the dungeon keeps going while you shop your own bag.
##
##   Right-click a bag item     use it, or equip it
##   Right-click worn gear      take it off
##   Drag                       move items around the bag, onto gear slots,
##                              or put abilities and consumables on the bar
##   Drag off the action bar    clear that button

signal use_requested(id: String)

const BAR_SLOTS := 9
const ITEM_PREFIX := "item:"

var inventory: Inventory
var player: Player
var action_slots: Array[ItemSlot] = []
var _bags := _window("Bags")
var _character := _window("Garl, Level 1 Crawler")
var _spellbook := _window("Spellbook")
var _bag_slots: Array[ItemSlot] = []
var _gear_slots: Dictionary = {}
var _gold := Label.new()
var _stats := RichTextLabel.new()
var _tooltip := PanelContainer.new()
var _tooltip_text := RichTextLabel.new()
var _tooltip_for: ItemSlot
## Icons are loaded up front: textures first loaded inside _draw() come out blank.
var _icons: Dictionary = {}


func _ready() -> void:
	layer = 5
	for id in Abilities.DATA:
		_icons[id] = load(Abilities.info(id)["icon"])
	for id in Items.DATA:
		_icons[ITEM_PREFIX + id] = Items.icon(id)
	_build_action_bar()
	_build_bags()
	_build_character()
	_build_spellbook()
	_build_tooltip()


func setup(bag: Inventory, hero: Player) -> void:
	inventory = bag
	player = hero
	inventory.changed.connect(_refresh)
	player.ability_used.connect(_on_ability_used)
	player.use_item_requested.connect(use_item_from_bar)
	player.health_changed.connect(func(_c: int, _m: int) -> void: _refresh())
	_refresh()


func any_window_open() -> bool:
	return _bags.visible or _character.visible or _spellbook.visible


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	match key_event.physical_keycode:
		KEY_B, KEY_I:
			_toggle(_bags)
		KEY_C:
			_toggle(_character)
		KEY_P:
			_toggle(_spellbook)
		KEY_ESCAPE:
			if not any_window_open():
				return
			for window in [_bags, _character, _spellbook]:
				window.visible = false
			hide_tooltip()
		_:
			return
	get_viewport().set_input_as_handled()


func _toggle(window: Control) -> void:
	window.visible = not window.visible
	hide_tooltip()
	_refresh()


func _refresh() -> void:
	if inventory == null:
		return
	_gold.text = "%d gold" % inventory.gold
	var bonus := inventory.bonuses()
	_stats.text = "[b]Health[/b]  %d / %d\n[b]Punch damage[/b]  %d\n[b]Run speed[/b]  %d%%\n\n[color=#aaaaaa]Bonuses from gear: +%d punch, +%d max HP.[/color]" % [
		player.health, player.max_health, player.punch_damage, int(round(player.speed_mult * 100.0)),
		bonus["punch_damage"], bonus["max_health"]]


func _on_ability_used(id: String) -> void:
	for slot in action_slots:
		if player.action_bar[slot.key] == id:
			slot.flash()


# --- What's in a slot -----------------------------------------------------------

## The thing in a slot: {"type": "item" or "ability", "id": ...}, or {}.
func content(slot: ItemSlot) -> Dictionary:
	match slot.kind:
		"bag":
			var id := inventory.id_at(slot.key) if inventory != null else ""
			return {"type": "item", "id": id} if id != "" else {}
		"gear":
			var id: String = inventory.equipped.get(slot.key, "") if inventory != null else ""
			return {"type": "item", "id": id} if id != "" else {}
		"action":
			var entry: String = player.action_bar[slot.key] if player != null else ""
			if entry.begins_with(ITEM_PREFIX):
				return {"type": "item", "id": entry.trim_prefix(ITEM_PREFIX)}
			return {"type": "ability", "id": entry} if entry != "" else {}
		"spell":
			return {"type": "ability", "id": slot.key}
	return {}


func slot_icon(slot: ItemSlot) -> Texture2D:
	var c := content(slot)
	if c.is_empty():
		return null
	var key: String = (ITEM_PREFIX + c["id"]) if c["type"] == "item" else c["id"]
	return _icons.get(key) as Texture2D


func slot_hint(slot: ItemSlot) -> String:
	return String(slot.key).capitalize() if slot.kind == "gear" else ""


func slot_count(slot: ItemSlot) -> int:
	var c := content(slot)
	if c.is_empty() or c["type"] != "item":
		return 0
	if slot.kind == "bag":
		return inventory.slots[slot.key]["count"]
	if slot.kind == "action":
		return inventory.count_of(c["id"])
	return 0


func slot_border(slot: ItemSlot) -> Color:
	var c := content(slot)
	if not c.is_empty() and c["type"] == "item" and slot.kind != "action":
		return Items.quality_color(c["id"]) * Color(1, 1, 1, 0.9)
	return Color(0.42, 0.36, 0.24)


## 0..1 of the cooldown sweep still to go.
func slot_cooldown(slot: ItemSlot) -> float:
	var c := content(slot)
	if c.is_empty() or player == null or (slot.kind != "action" and slot.kind != "spell"):
		return 0.0
	if c["type"] == "item":
		return player.global_cooldown / Abilities.GLOBAL_COOLDOWN
	var info := Abilities.info(c["id"])
	var left: float = player.cooldowns.get(c["id"], 0.0)
	var gcd := player.global_cooldown if info["gcd"] else 0.0
	if left > gcd and info["cooldown"] > 0.0:
		return left / info["cooldown"]
	return gcd / Abilities.GLOBAL_COOLDOWN


func slot_cooldown_seconds(slot: ItemSlot) -> float:
	var c := content(slot)
	if c.is_empty() or c["type"] != "ability" or player == null:
		return 0.0
	return player.cooldowns.get(c["id"], 0.0)


## Click (action, spell) or right-click (bag, gear).
func slot_activate(slot: ItemSlot) -> void:
	var c := content(slot)
	if c.is_empty():
		return
	match slot.kind:
		"action", "spell":
			if c["type"] == "ability":
				player.use_ability(c["id"])
			else:
				use_item_from_bar(c["id"])
		"bag":
			var item := Items.info(c["id"])
			if item.get("kind", "") == "equipment":
				inventory.equip(c["id"])
			elif item.get("kind", "") == "consumable":
				use_requested.emit(c["id"])
			else:
				player.error.emit("You can't use that")
		"gear":
			inventory.unequip(slot.key)
	_refresh_tooltip()


## Keys 1-9 and clicks on a bar button holding an item.
func use_item_from_bar(id: String) -> void:
	if inventory.count_of(id) == 0:
		player.error.emit("You don't have any of those")
		return
	if player.global_cooldown > 0.0:
		return
	player.global_cooldown = Abilities.GLOBAL_COOLDOWN
	use_requested.emit(id)


# --- Drag and drop ---------------------------------------------------------------

func slot_drag_data(slot: ItemSlot) -> Variant:
	var c := content(slot)
	if c.is_empty():
		return null
	return {"from_kind": slot.kind, "from_key": slot.key, "type": c["type"], "id": c["id"]}


func slot_can_drop(slot: ItemSlot, data: Variant) -> bool:
	if not data is Dictionary or not data.has("from_kind"):
		return false
	var from: String = data["from_kind"]
	match slot.kind:
		"bag":
			return from == "bag" or from == "gear"
		"gear":
			var item := Items.info(data["id"])
			return from == "bag" and item.get("slot", "") == slot.key
		"action":
			if data["type"] == "ability":
				return true
			return Items.info(data["id"]).get("kind", "") == "consumable"
	return false


func slot_drop(slot: ItemSlot, data: Variant) -> void:
	var from: String = data["from_kind"]
	match slot.kind:
		"bag":
			if from == "bag":
				inventory.move(data["from_key"], slot.key)
			elif from == "gear":
				inventory.unequip(data["from_key"], slot.key)
		"gear":
			inventory.equip(data["id"])
		"action":
			var entry: String = data["id"] if data["type"] == "ability" else ITEM_PREFIX + data["id"]
			if from == "action":
				player.action_bar[data["from_key"]] = player.action_bar[slot.key]
			player.action_bar[slot.key] = entry
	_refresh()


func slot_clear(slot: ItemSlot) -> void:
	if slot.kind == "action":
		player.action_bar[slot.key] = ""


# --- Tooltip ---------------------------------------------------------------------

func show_tooltip(slot: ItemSlot) -> void:
	_tooltip_for = slot
	_refresh_tooltip()


func hide_tooltip() -> void:
	_tooltip_for = null
	_tooltip.visible = false


func _refresh_tooltip() -> void:
	var slot := _tooltip_for
	if slot == null or not is_instance_valid(slot):
		_tooltip.visible = false
		return
	var c := content(slot)
	if c.is_empty():
		_tooltip.visible = false
		return
	if c["type"] == "item":
		var hint := ""
		var kind: String = Items.info(c["id"]).get("kind", "")
		if slot.kind == "bag":
			hint = "Right-click to equip" if kind == "equipment" else ("Right-click to use" if kind == "consumable" else "")
		elif slot.kind == "gear":
			hint = "Right-click to take off"
		_tooltip_text.text = Items.tooltip(c["id"], hint)
	else:
		var info := Abilities.info(c["id"])
		var text := "[b][color=#ffffff]%s[/color][/b]" % info["name"]
		var meta := PackedStringArray()
		if info["range"] > 0.0:
			meta.append("%d m range" % int(info["range"]))
		meta.append("%d sec cooldown" % int(info["cooldown"]) if info["cooldown"] > 0.0 else "Instant")
		text += "\n[color=#cccccc]%s[/color]\n[color=#ffd100]%s[/color]" % ["   ".join(meta), info["desc"]]
		if slot.kind == "spell":
			text += "\n[color=#aaaaaa]Drag onto your action bar[/color]"
		_tooltip_text.text = text
	_tooltip.visible = true
	_tooltip.reset_size()
	# Sit beside the slot, kept on screen.
	var screen := get_viewport().get_visible_rect().size
	var at := slot.get_global_rect().position + Vector2(slot.size.x + 8.0, -_tooltip.size.y * 0.5)
	if at.x + _tooltip.size.x > screen.x - 8.0:
		at.x = slot.get_global_rect().position.x - _tooltip.size.x - 8.0
	at.y = clampf(at.y, 8.0, screen.y - _tooltip.size.y - 8.0)
	_tooltip.position = at


# --- Building the windows --------------------------------------------------------

func _build_action_bar() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 5)
	var width := BAR_SLOTS * ItemSlot.SIZE + (BAR_SLOTS - 1) * 5.0
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -width / 2.0
	bar.offset_right = width / 2.0
	bar.offset_top = -ItemSlot.SIZE - 16.0
	bar.offset_bottom = -16.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backing := Panel.new()
	backing.add_theme_stylebox_override("panel", _style(Color(0.06, 0.05, 0.07, 0.85), Color(0.42, 0.36, 0.24)))
	backing.anchor_left = 0.5
	backing.anchor_right = 0.5
	backing.anchor_top = 1.0
	backing.anchor_bottom = 1.0
	backing.offset_left = -width / 2.0 - 8.0
	backing.offset_right = width / 2.0 + 8.0
	backing.offset_top = -ItemSlot.SIZE - 24.0
	backing.offset_bottom = -8.0
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backing)
	add_child(bar)
	for i in BAR_SLOTS:
		var slot := ItemSlot.new("action", i, self)
		slot.hotkey = str(i + 1)
		bar.add_child(slot)
		action_slots.append(slot)


func _build_bags() -> void:
	_bags.anchor_left = 1.0
	_bags.anchor_right = 1.0
	_bags.anchor_top = 1.0
	_bags.anchor_bottom = 1.0
	_bags.offset_left = -246
	_bags.offset_right = -16
	_bags.offset_top = -420
	_bags.offset_bottom = -90
	_bags.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_bags.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var body: VBoxContainer = _bags.get_meta("body")
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	for i in Inventory.MAX_SLOTS:
		var slot := ItemSlot.new("bag", i, self)
		grid.add_child(slot)
		_bag_slots.append(slot)
	_gold.add_theme_color_override("font_color", Color(1.0, 0.84, 0.2))
	_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	body.add_child(_gold)


func _build_character() -> void:
	_character.position = Vector2(16, 150)
	_character.custom_minimum_size = Vector2(380, 0)
	var body: VBoxContainer = _character.get_meta("body")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	body.add_child(row)
	var gear_column := VBoxContainer.new()
	gear_column.add_theme_constant_override("separation", 8)
	row.add_child(gear_column)
	for gear_slot in Items.SLOTS:
		var line := HBoxContainer.new()
		var slot := ItemSlot.new("gear", gear_slot, self)
		line.add_child(slot)
		var label := Label.new()
		label.text = String(gear_slot).capitalize()
		label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(label)
		gear_column.add_child(line)
		_gear_slots[gear_slot] = slot
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var portrait := TextureRect.new()
	portrait.texture = load("res://assets/icons/portrait_garl.png")
	portrait.custom_minimum_size = Vector2(96, 96)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	right.add_child(portrait)
	_stats.bbcode_enabled = true
	_stats.fit_content = true
	_stats.custom_minimum_size = Vector2(200, 0)
	right.add_child(_stats)
	var note := Label.new()
	note.text = "Drag gear here from your bags. Pants slot not found."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	body.add_child(note)


func _build_spellbook() -> void:
	_spellbook.position = Vector2(420, 150)
	_spellbook.custom_minimum_size = Vector2(380, 0)
	var body: VBoxContainer = _spellbook.get_meta("body")
	for id in Abilities.DATA:
		var info := Abilities.info(id)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		line.add_child(ItemSlot.new("spell", id, self))
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.text = "[b]%s[/b]\n[color=#bbbbbb][font_size=12]%s[/font_size][/color]" % [info["name"], info["desc"]]
		line.add_child(text)
		body.add_child(line)


func _build_tooltip() -> void:
	_tooltip.add_theme_stylebox_override("panel", _style(Color(0.04, 0.03, 0.08, 0.96), Color(0.55, 0.55, 0.6), 10))
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.visible = false
	_tooltip.z_index = 10
	_tooltip_text.bbcode_enabled = true
	_tooltip_text.fit_content = true
	_tooltip_text.custom_minimum_size = Vector2(270, 0)
	_tooltip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_child(_tooltip_text)
	add_child(_tooltip)


func _window(title: String) -> PanelContainer:
	var window := PanelContainer.new()
	window.add_theme_stylebox_override("panel", _style(Color(0.07, 0.06, 0.09, 0.95), Color(0.55, 0.45, 0.25), 12))
	window.mouse_filter = Control.MOUSE_FILTER_STOP
	window.visible = false
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	window.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	var label := Label.new()
	label.text = title
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var close := Button.new()
	close.text = "x"
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(_close_window.bind(window))
	header.add_child(close)
	window.set_meta("body", body)
	add_child(window)
	return window


func _close_window(window: Control) -> void:
	window.visible = false
	hide_tooltip()


func _style(fill: Color, border: Color, margin: float = 4.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(margin)
	return style
