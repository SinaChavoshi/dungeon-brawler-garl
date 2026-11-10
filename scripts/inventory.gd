class_name Inventory
extends RefCounted
## Garl's bag, managed by H.O.S.T. Holds stacks of items, equipped gear and gold.

signal changed

const MAX_SLOTS := 16

## One entry per bag slot: null (empty) or {"id": String, "count": int}.
var slots: Array = []
## gear slot name -> item id
var equipped: Dictionary = {}
var gold: int = 0


func _init() -> void:
	slots.resize(MAX_SLOTS)


## Stacks onto a matching item, or takes the first empty slot.
## Returns false if the bag is full.
func add(id: String, count: int = 1) -> bool:
	for entry in slots:
		if entry != null and entry["id"] == id:
			entry["count"] += count
			changed.emit()
			return true
	var empty := slots.find(null)
	if empty < 0:
		return false
	slots[empty] = {"id": id, "count": count}
	changed.emit()
	return true


func remove(id: String, count: int = 1) -> void:
	for i in slots.size():
		if slots[i] != null and slots[i]["id"] == id:
			slots[i]["count"] -= count
			if slots[i]["count"] <= 0:
				slots[i] = null
			changed.emit()
			return


func count_of(id: String) -> int:
	var total := 0
	for entry in slots:
		if entry != null and entry["id"] == id:
			total += entry["count"]
	return total


func id_at(index: int) -> String:
	return slots[index]["id"] if slots[index] != null else ""


## Drag and drop inside the bag: swap two slots.
func move(from: int, to: int) -> void:
	if from == to:
		return
	var moving = slots[from]
	slots[from] = slots[to]
	slots[to] = moving
	changed.emit()


func add_gold(amount: int) -> void:
	gold += amount
	changed.emit()


## Moves an item from the bag into its gear slot. Whatever was there goes
## back into the bag (into the same bag slot, if there is one).
func equip(id: String) -> void:
	var item := Items.info(id)
	if item.get("kind", "") != "equipment" or count_of(id) == 0:
		return
	var gear_slot: String = item["slot"]
	var from := -1
	for i in slots.size():
		if slots[i] != null and slots[i]["id"] == id:
			from = i
			break
	slots[from]["count"] -= 1
	if slots[from]["count"] <= 0:
		slots[from] = null
	if equipped.has(gear_slot):
		var old: String = equipped[gear_slot]
		if slots[from] == null:
			slots[from] = {"id": old, "count": 1}
		else:
			add(old)
	equipped[gear_slot] = id
	changed.emit()


## Takes gear off into the bag (into bag slot `to` if it's free).
func unequip(gear_slot: String, to: int = -1) -> void:
	if not equipped.has(gear_slot):
		return
	var id: String = equipped[gear_slot]
	if to >= 0 and slots[to] == null:
		slots[to] = {"id": id, "count": 1}
	elif not add(id):
		return
	equipped.erase(gear_slot)
	changed.emit()


## Sum of all equipped bonuses.
func bonuses() -> Dictionary:
	var result := {"punch_damage": 0, "max_health": 0, "speed_mult": 1.0}
	for slot in equipped:
		var item := Items.info(equipped[slot])
		result["punch_damage"] += item.get("punch_damage", 0)
		result["max_health"] += item.get("max_health", 0)
		result["speed_mult"] *= item.get("speed_mult", 1.0)
	return result


## The best healing item in the bag, or "" if there isn't one.
func best_heal() -> String:
	var best := ""
	var best_heal_amount := 0
	for entry in slots:
		if entry == null:
			continue
		var heal: int = Items.info(entry["id"]).get("heal", 0)
		if heal > best_heal_amount:
			best = entry["id"]
			best_heal_amount = heal
	return best
