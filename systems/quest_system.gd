class_name QuestSystem
## Sidequests from villagers: FETCH (gather N items) and DEFEAT (kill N of a type).
## Quests are data-only here (dictionaries) so the whole system is unit-testable
## and save-serializable. Content (names/flavor) comes from content.json.

var balance: Dictionary
var content: Dictionary
var inventory: InventorySystem

var active: Array[Dictionary] = []
var completed: Array[Dictionary] = []
var _next_id: int = 1


func _init(p_balance: Dictionary, p_content: Dictionary, p_inventory: InventorySystem) -> void:
	balance = p_balance
	content = p_content
	inventory = p_inventory


func max_active() -> int:
	return int(balance.get("quests", {}).get("max_active", 3))


## Offer a new quest (deterministic choice from a SeededRng).
func make_quest(rng: SeededRng, village_id: String) -> Dictionary:
	var q: Dictionary = balance.get("quests", {})
	var kind: String = "fetch" if rng.chance(0.5) else "defeat"
	var id: int = _next_id
	_next_id += 1
	var quest: Dictionary = {
		"id": id,
		"kind": kind,
		"village": village_id,
		"target": "",
		"qty": 0,
		"progress": 0,
		"reward": {},
		"flavor": "",
		"given": true,
	}
	if kind == "fetch":
		var mats: Array = ["wood", "rare_ore"]
		quest["target"] = str(rng.pick(mats))
		quest["qty"] = rng.range_i(int(q.get("fetch_qty_min", 3)), int(q.get("fetch_qty_max", 6)))
		var rw: Dictionary = q.get("rewards", {}).get("fetch_" + quest["target"], { "rare_ore": 1 })
		quest["reward"] = rw.duplicate()
	else:
		var foes: Array = ["zombie", "wolf"]
		quest["target"] = str(rng.pick(foes))
		quest["qty"] = rng.range_i(int(q.get("defeat_count_min", 2)), int(q.get("defeat_count_max", 4)))
		var rw2: Dictionary = q.get("rewards", {}).get("defeat_" + quest["target"], { "wood": 1 })
		quest["reward"] = rw2.duplicate()
	quest["flavor"] = _flavor_for(quest)
	return quest


func _flavor_for(q: Dictionary) -> String:
	var lines: Array = content.get("quest_lines", {}).get(q["kind"], [])
	if lines.is_empty():
		return ""
	return str(lines[absi(q["id"]) % lines.size()])


func offer(quest: Dictionary) -> bool:
	if active.size() >= max_active():
		return false
	active.append(quest)
	return true


func accept(quest: Dictionary) -> bool:
	return offer(quest)


## Player handed target item -> advance fetch quests.
func on_item_gained(item: String, qty: int) -> void:
	for quest in active:
		if quest["kind"] == "fetch" and quest["target"] == item:
			quest["progress"] = int(quest["progress"]) + qty
			_check(quest)


## Enemy of `kind` died -> advance defeat quests.
func on_enemy_killed(kind: String) -> void:
	for quest in active:
		if quest["kind"] == "defeat" and quest["target"] == kind:
			quest["progress"] = int(quest["progress"]) + 1
			_check(quest)


func _check(quest: Dictionary) -> void:
	if int(quest["progress"]) >= int(quest["qty"]):
		_complete(quest)


## Called when the player re-bumps the villager; auto-reward if done.
func is_complete(quest: Dictionary) -> bool:
	return int(quest["progress"]) >= int(quest["qty"])


func _complete(quest: Dictionary) -> void:
	# grant reward on completion
	for mat in quest["reward"]:
		inventory.add(str(mat), int(quest["reward"][mat]))
	quest["given"] = false
	quest["completed"] = true
	active.erase(quest)
	completed.append(quest)


func active_list() -> Array[Dictionary]:
	return active


func completed_list() -> Array[Dictionary]:
	return completed


# ---------------------------------------------------------------- save

func to_dict() -> Dictionary:
	return {
		"active": active.duplicate(true),
		"completed": completed.duplicate(true),
		"next_id": _next_id,
	}


func load_dict(d: Dictionary) -> void:
	active = []
	completed = []
	for q in d.get("active", []):
		active.append(q.duplicate(true))
	for q in d.get("completed", []):
		completed.append(q.duplicate(true))
	_next_id = int(d.get("next_id", 1))
	if _next_id < 1:
		_next_id = 1
