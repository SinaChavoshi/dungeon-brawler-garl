class_name Inventory
extends RefCounted
## Garl's bag, managed by H.O.S.T. Holds stacks of items, equipped gear and gold.

signal changed

const MAX_SLOTS := 12

## Each entry: {"id": String, "count": int}
var items: Array[Dictionary] = []
## slot name -> item id
var equipped: Dictionary = {}
var gold: int = 0


## Returns false if the bag is full.
func add(id: String, count: int = 1) -> bool:
	for entry in items:
		if entry["id"] == id:
			entry["count"] += count
			changed.emit()
			return true
	if items.size() >= MAX_SLOTS:
		return false
	items.append({"id": id, "count": count})
	changed.emit()
	return true


func remove(id: String, count: int = 1) -> void:
	for i in items.size():
		if items[i]["id"] == id:
			items[i]["count"] -= count
			if items[i]["count"] <= 0:
				items.remove_at(i)
			changed.emit()
			return


func count_of(id: String) -> int:
	for entry in items:
		if entry["id"] == id:
			return entry["count"]
	return 0


func add_gold(amount: int) -> void:
	gold += amount
	changed.emit()


## Moves an item from the bag into its slot, swapping out whatever was there.
func equip(id: String) -> void:
	var item := Items.info(id)
	if item.get("kind", "") != "equipment" or count_of(id) == 0:
		return
	var slot: String = item["slot"]
	remove(id)
	if equipped.has(slot):
		add(equipped[slot])
	equipped[slot] = id
	changed.emit()


func unequip(slot: String) -> void:
	if not equipped.has(slot):
		return
	if add(equipped[slot]):
		equipped.erase(slot)
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
	for entry in items:
		var heal: int = Items.info(entry["id"]).get("heal", 0)
		if heal > best_heal_amount:
			best = entry["id"]
			best_heal_amount = heal
	return best
