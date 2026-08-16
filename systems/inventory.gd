class_name InventorySystem
## Unlimited inventory. Counts keyed by item id (string). "Uint overflow" is
## only a theoretical concern; counts are Godot 64-bit ints.

var counts: Dictionary = {}


func _init() -> void:
	counts = {}


func add(item: String, qty: int) -> void:
	if qty <= 0:
		return
	counts[item] = int(counts.get(item, 0)) + qty


func has(item: String, qty: int = 1) -> bool:
	return int(counts.get(item, 0)) >= qty


func take(item: String, qty: int) -> bool:
	## Removes qty if available. Returns success (false if unavailable).
	if qty <= 0:
		return true
	if not has(item, qty):
		return false
	var left: int = int(counts[item]) - qty
	if left <= 0:
		counts.erase(item)
	else:
		counts[item] = left
	return true


func count(item: String) -> int:
	## Number of `item` owned.
	return int(counts.get(item, 0))


func clear() -> void:
	counts = {}


func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for k in counts:
		out[str(k)] = int(counts[k])
	return out


func load_dict(d: Dictionary) -> void:
	counts = {}
	for k in d:
		counts[str(k)] = int(d[k])
