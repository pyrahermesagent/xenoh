# Headless test runner. Usage:
#   godot --headless --path . res://tests/run_tests.tscn
# Prints ok/ERR per assertion; exit code 0 = all pass, 1 = failures.
extends SceneTree

var _failures: Array[String] = []
var _passes: int = 0


func _initialize() -> void:
	# Autoloads are already active; tests below use only pure systems.
	var f := FileAccess.open("res://balance.json", FileAccess.READ)
	var balance: Dictionary = JSON.parse_string(f.get_as_text())

	_test_world_determinism(balance)
	_test_world_deltas(balance)
	_test_crafting(balance)
	_test_save_roundtrip(balance)

	print("\n==== TEST RESULTS: %d passed, %d failed ====" % [_passes, _failures.size()])
	if _failures.size() > 0:
		for fail in _failures:
			print("  FAIL: ", fail)
		quit(1)
	else:
		quit(0)


func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
		print("  ok  - ", msg)
	else:
		_failures.append(msg)
		print("  ERR - ", msg)


func _test_world_determinism(balance: Dictionary) -> void:
	print("\n[worldgen determinism]")
	var wg1 := WorldGen.new(1337, balance)
	var wg2 := WorldGen.new(1337, balance)
	var samples := 500
	var same: bool = true
	for i in range(samples):
		var c: Vector2i = Vector2i(i % 64 - 32, (i / 64) % 64 - 32)
		if wg1.terrain_at(c) != wg2.terrain_at(c):
			same = false
			break
	_check(same, "same seed -> same terrain for %d cells" % samples)
	var wg3 := WorldGen.new(4242, balance)
	var differs: bool = false
	for i in range(samples):
		var c: Vector2i = Vector2i(i % 64 - 32, (i / 64) % 64 - 32)
		if wg1.terrain_at(c) != wg3.terrain_at(c):
			differs = true
			break
	_check(differs, "different seed -> different world")
	_check(wg1.terrain_at(Vector2i.ZERO) == Terrain.GRASS, "spawn hex is grass")
	var seen: Dictionary = {}
	for i in range(4000):
		var c: Vector2i = Vector2i(i % 80 - 40, (i / 80) % 80 - 40)
		seen[wg1.terrain_at(c)] = true
	_check(seen.has(Terrain.OCEAN) or seen.has(Terrain.HILL), "ocean/hill terrain present in 80x80")
	_check(seen.has(Terrain.TREE), "trees present")
	_check(seen.has(Terrain.ORE), "rare ores present")
	_check(seen.has(Terrain.CHEST), "chests present")
	_check(seen.has(Terrain.DARK) or seen.has(Terrain.CRYSTAL), "dark zones present")


func _test_world_deltas(balance: Dictionary) -> void:
	print("\n[worldgen deltas]")
	var wg := WorldGen.new(1337, balance)
	var tree_hex: Vector2i = Vector2i.ZERO
	for i in range(3000):
		var c: Vector2i = Vector2i(i % 70 - 35, (i / 70) % 70 - 35)
		if wg.terrain_at(c) == Terrain.TREE:
			tree_hex = c
			break
	_check(tree_hex != Vector2i.ZERO, "found a tree at %s" % str(tree_hex))
	var before: int = wg.terrain_at(tree_hex)
	wg.consume_feature("t", tree_hex)
	_check(wg.terrain_at(tree_hex) == Terrain.GRASS, "harvested tree becomes grass")
	var saved: Dictionary = wg.save_deltas()
	var wg2 := WorldGen.new(1337, balance)
	_check(wg2.terrain_at(tree_hex) == before, "fresh gen still has tree")
	wg2.apply_deltas(saved["removed_dark"], saved["consumed"])
	_check(wg2.terrain_at(tree_hex) == Terrain.GRASS, "delta restore removes tree")
	var dark_hex: Vector2i = Vector2i.ZERO
	for i in range(6000):
		var c: Vector2i = Vector2i(i % 90 - 45, (i / 90) % 90 - 45)
		if wg.terrain_at(c) == Terrain.DARK:
			dark_hex = c
			break
	if dark_hex != Vector2i.ZERO:
		wg.break_dark_zone(dark_hex)
		_check(not wg.is_dark(dark_hex), "broken zone no longer dark")
		_check(wg.terrain_at(dark_hex) != Terrain.DARK, "broken zone terrain cleared")


func _test_crafting(balance: Dictionary) -> void:
	print("\n[crafting]")
	var inv := InventorySystem.new()
	var craft := CraftingSystem.new(balance, inv)
	_check(craft.recipes().size() >= 7, "7+ recipes defined")
	_check(not craft.can_craft("sword"), "sword uncraftable with empty inventory")
	_check(not craft.craft("sword"), "craft() refused without materials")
	var rec: Dictionary = craft.recipe_of("sword")
	for mat in rec:
		inv.add(str(mat), int(rec[mat]))
	_check(craft.can_craft("sword"), "sword craftable with exact costs")
	_check(craft.craft("sword"), "craft() succeeds")
	_check(inv.count("sword") == 1, "sword in inventory after craft")
	_check(not craft.can_craft("sword"), "materials consumed (can't craft again)")
	var leather: int = int(balance["player"]["armor_hp_bonus"]["leather_armor"])
	_check(leather > 0, "leather armor grants HP bonus")


func _test_save_roundtrip(balance: Dictionary) -> void:
	print("\n[save/load round-trip]")
	var save := SaveSystem.new()
	var inv := InventorySystem.new()
	inv.add("wood", 12)
	inv.add("rare_ore", 3)
	inv.add("sword", 1)
	var state := {
		"seed": 777,
		"tick": 123,
		"pos": [4, -2],
		"facing": 3,
		"hp": 1,
		"weapon": "sword",
		"armor": "leather_armor",
		"inventory": inv.to_dict(),
		"quests": {"active": [], "completed": [], "next_id": 1},
		"deltas": {"removed_dark": ["dz:1,2"], "consumed": ["t:5,6", "c:7,8"]},
		"last_hit_at": 0.0,
	}
	var payload: String = save.build_payload(state)
	var parsed: Dictionary = save.parse_payload(payload)
	_check(int(parsed["seed"]) == 777, "seed round-trips")
	_check(int(parsed["tick"]) == 123, "tick round-trips")
	var pos_arr = parsed["pos"]
	_check(int(pos_arr[0]) == 4 and int(pos_arr[1]) == -2, "pos round-trips")
	_check(int(parsed["facing"]) == 3, "facing round-trips")
	_check(int(parsed["inventory"]["wood"]) == 12, "inventory wood round-trips")
	_check(int(parsed["inventory"]["sword"]) == 1, "inventory sword round-trips")
	_check(parsed["deltas"]["removed_dark"] == ["dz:1,2"], "removed_dark round-trips")
	_check(parsed["deltas"]["consumed"] == ["t:5,6", "c:7,8"], "consumed round-trips")
	_check(save.parse_payload("") == {}, "empty payload -> {}")
	_check(save.parse_payload("not json") == {}, "garbage payload -> {}")
	var qinv := InventorySystem.new()
	var qs := QuestSystem.new(balance, {}, qinv)
	var rng := SeededRng.new(99)
	var q: Dictionary = qs.make_quest(rng, "v1")
	qs.offer(q)
	var qd: Dictionary = qs.to_dict()
	var qs2 := QuestSystem.new(balance, {}, qinv)
	qs2.load_dict(qd)
	_check(qs2.active.size() == 1 and qs2.active[0]["id"] == q["id"], "quest round-trips")
	qinv.add(str(q["target"]), 999)
	qs2.on_item_gained(str(q["target"]), 999)
	_check(qs2.completed.size() == 1, "quest completion after load works")
