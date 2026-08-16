extends Node
## XenoHeart game root autoload.
## Owns: tick loop (0.7s), player state, entity registry, interaction &
## combat resolution, save orchestration. UI (hud/pause) reads from here.

signal tick_processed(t: int)
signal player_moved(pos: Vector2i, facing: int)
signal player_died
signal interaction_happened(interaction: Dictionary)
signal enemy_killed(kind: String, pos: Vector2i)
signal low_health_changed(low: bool)
signal pause_requested(paused: bool)

const BALANCE_PATH := "res://balance.json"
const CONTENT_PATH := "res://content.json"
const SAVE_KEY := "xenoh_save_v1"

var world: WorldGen
var inventory: InventorySystem
var crafting: CraftingSystem
var quests: QuestSystem
var save: SaveSystem
var balance: Dictionary = {}
var content: Dictionary = {}

# ---- player state ----
var pos: Vector2i = Vector2i.ZERO
var facing: int = 0
var hp: int = 2
var max_hp: int = 2
var equipped_weapon: String = "none"
var equipped_armor: String = "none"
var last_hit_at: float = 0.0
var alive: bool = true

# ---- run state ----
var tick: int = 0
var paused: bool = false
var world_seed: int = 0

# ---- runtime entities (not persisted individually; positions are transient) ----
var enemies: Array[Dictionary] = []   # {kind, pos(Vector2i), hp, id}
var next_entity_id: int = 1

var rng: SeededRng


func _ready() -> void:
	_load_config()
	_world_setup()
	_wire_yt_wrapper()
	_try_load_save()
	# first-frame / ready handshake for Playables
	if OS.has_feature("web") and YTGameWrapper.in_playables_env():
		YTGameWrapper.first_frame_ready()
		YTGameWrapper.game_ready()
	_start_ticking()


func _load_config() -> void:
	var f := FileAccess.open(BALANCE_PATH, FileAccess.READ)
	balance = JSON.parse_string(f.get_as_text())
	var fc := FileAccess.open(CONTENT_PATH, FileAccess.READ)
	content = JSON.parse_string(fc.get_as_text())
	balance = balance if balance else {}
	content = content if content else {}


func _world_setup() -> void:
	world = WorldGen.new(world_seed, balance)
	inventory = InventorySystem.new()
	crafting = CraftingSystem.new(balance, inventory)
	quests = QuestSystem.new(balance, content, inventory)
	save = SaveSystem.new()
	rng = SeededRng.new(world_seed * 7 + 3)


func _wire_yt_wrapper() -> void:
	YTGameWrapper.game_paused.connect(_on_yt_pause)
	YTGameWrapper.game_resumed.connect(_on_yt_resume)
	YTGameWrapper.load_data_received.connect(_on_load_data_received)
	if OS.has_feature("web") and YTGameWrapper.in_playables_env():
		YTGameWrapper.load_data()


func _on_yt_pause() -> void:
	set_paused(true, "yt")


func _on_yt_resume() -> void:
	set_paused(false, "yt")


func _on_load_data_received(data: String) -> void:
	_apply_save_payload(data)


# ================================================================ ticking

var _tick_timer: float = 0.0


func _process(delta: float) -> void:
	if paused or not alive:
		# still heal? no — paused time is game time; healing only while playing
		return
	_tick_timer += delta
	var tick_s: float = float(balance.get("ticks", {}).get("tick_seconds", 0.7))
	while _tick_timer >= tick_s and not paused and alive:
		_tick_timer -= tick_s
		_do_tick()


func _start_ticking() -> void:
	pass  # ticking is driven by _process


func _do_tick() -> void:
	tick += 1
	# auto-save cadence
	var every: int = int(balance.get("ticks", {}).get("auto_save_every_ticks", 50))
	if every > 0 and tick % every == 0:
		do_save()
	# player auto-moves forward
	_try_move()
	# interaction on bump
	_resolve_interaction()
	# auto-attack
	_auto_attack()
	# enemies act
	_enemies_tick()
	# spawn logic
	if tick % int(balance.get("spawns", {}).get("spawn_check_every_ticks", 3)) == 0:
		_try_spawn_enemies()
	_despawn_far_enemies()
	# hp regen (20s since last hit)
	_regen_check()
	tick_processed.emit(tick)
	player_moved.emit(pos, facing)


# ================================================================ movement

func _facing_hex() -> Vector2i:
	return pos + HexUtil.dir_vec(facing)


func is_blocked(c: Vector2i) -> bool:
	var t: int = world.terrain_at(c)
	match t:
		Terrain.OCEAN, Terrain.HILL, Terrain.VILLAGE, Terrain.CHEST, Terrain.CRYSTAL, Terrain.VILLAGER:
			return true
	# enemies occupy their hex
	for e in enemies:
		if e["pos"] == c:
			return true
	return false


func _try_move() -> void:
	var target: Vector2i = _facing_hex()
	if is_blocked(target):
		# bump: interaction happens instead (see _resolve_interaction)
		return
	pos = target
	# walking into a dark zone that has a crystal: nothing special; interaction handles it


func rotate(delta: int) -> void:
	facing = HexUtil.rotate_dir(facing, delta)
	player_moved.emit(pos, facing)


# ================================================================ interaction

func _resolve_interaction() -> void:
	var target: Vector2i = _facing_hex()
	var t: int = world.terrain_at(target)
	match t:
		Terrain.TREE:
			var loot: Array = balance.get("loot", {}).get("tree_wood", [1, 2])
			var amt: int = rng.range_i(int(loot[0]), int(loot[1]))
			inventory.add("wood", amt)
			quests.on_item_gained("wood", amt)
			world.consume_feature("t", target)
			interaction_happened.emit({"type": "chop", "item": "wood", "qty": amt, "pos": target})
		Terrain.ORE:
			var amt: int = int(balance.get("loot", {}).get("ore_yield", 1))
			inventory.add("rare_ore", amt)
			quests.on_item_gained("rare_ore", amt)
			world.consume_feature("o", target)
			interaction_happened.emit({"type": "mine", "item": "rare_ore", "qty": amt, "pos": target})
		Terrain.CHEST:
			var loot: Dictionary = _roll_chest_loot()
			world.consume_feature("c", target)
			for mat in loot:
				inventory.add(str(mat), int(loot[mat]))
				quests.on_item_gained(str(mat), int(loot[mat]))
			interaction_happened.emit({"type": "chest", "item": str(loot.keys()[0]), "qty": int(loot[loot.keys()[0]]), "pos": target})
		Terrain.CRYSTAL:
			var key: String = world.break_dark_zone(target)
			var crystal_loot: Dictionary = balance.get("loot", {}).get("crystal_loot", { "darkness_crystal": 1 })
			for mat in crystal_loot:
				inventory.add(str(mat), int(crystal_loot[mat]))
				quests.on_item_gained(str(mat), int(crystal_loot[mat]))
			interaction_happened.emit({"type": "crystal", "zone": key, "pos": target})
		Terrain.VILLAGER:
			_villager_interact(target)
		_:
			pass


func _roll_chest_loot() -> Dictionary:
	var table: Array = balance.get("loot", {}).get("chest_table", [])
	var total: float = 0.0
	for row in table:
		total += float(row.get("weight", 0))
	var roll: float = rng.next_f64() * total
	var acc: float = 0.0
	var chosen: Dictionary = table[0]
	for row in table:
		acc += float(row.get("weight", 0))
		if roll <= acc:
			chosen = row
			break
	var qty: Array = chosen.get("qty", [1, 1])
	return { str(chosen["item"]): rng.range_i(int(qty[0]), int(qty[1])) }


# ---- villagers ----

## Per-villager offer is deterministic from (seed, hex) so it's stable across
## visits & saves; the RNG stream is NOT consumed (no save drift).


func _villager_interact(c: Vector2i) -> void:
	var offer: Dictionary = _villager_offer(c)
	var vkind: String = str(offer.get("kind", "none"))
	match vkind:
		"none":
			interaction_happened.emit({"type": "talk", "result": "idle", "pos": c})
		"trade":
			_do_trade(c, offer)
		"quest":
			_do_quest_offer(c, offer)


func _villager_offer(c: Vector2i) -> Dictionary:
	## Deterministic per-villager offer from (seed, hex) — stable across visits
	## and saves, independent of the run RNG stream (no drift).
	var v: Dictionary = balance.get("villagers", {})
	var h: int = WorldGen.hash_cell(c, world_seed)
	var roll: float = (h & 0xFFFF) / 65535.0
	var p_trade: float = float(v.get("offered", {}).get("trade", 0.45))
	var p_quest: float = float(v.get("offered", {}).get("quest", 0.35))
	if roll < p_trade:
		return {"kind": "trade"}
	elif roll < p_trade + p_quest:
		# quest offer: deterministically generated (hash-seeded rng fork)
		var rng2 := SeededRng.new(world_seed).fork(int(c.x) * 7919 + int(c.y) * 104729)
		return {"kind": "quest", "quest": quests.make_quest(rng2, str(c))}
	return {"kind": "none"}


func _do_trade(c: Vector2i, offer: Dictionary) -> void:
	var t: Dictionary = balance.get("villagers", {}).get("trade_wood_for_ore", {})
	var give: int = int(t.get("give_wood", 4))
	var get: int = int(t.get("get_ore", 1))
	if inventory.has("wood", give):
		inventory.take("wood", give)
		inventory.add("rare_ore", get)
		quests.on_item_gained("rare_ore", get)
		interaction_happened.emit({"type": "trade", "gave_wood": give, "got_ore": get, "pos": c})
	else:
		interaction_happened.emit({"type": "trade_failed", "pos": c})


func _do_quest_offer(c: Vector2i, offer: Dictionary) -> void:
	var q: Dictionary = offer.get("quest", {})
	if quests.active.size() >= quests.max_active():
		interaction_happened.emit({"type": "quest_full", "pos": c})
		return
	quests.offer(q)
	interaction_happened.emit({"type": "quest_offer", "quest": q, "pos": c})


# ================================================================ combat

func weapon_spec() -> Dictionary:
	return balance.get("weapons", {}).get(equipped_weapon, {})


func attack_hits() -> Array[Vector2i]:
	## Hexes this swing covers (facing-dependent), per weapon pattern.
	var spec: Dictionary = weapon_spec()
	var dmg: int = int(spec.get("damage", 0))
	if dmg <= 0:
		return []
	var pattern: String = str(spec.get("pattern", "face"))
	var out: Array[Vector2i] = []
	match pattern:
		"face":
			var reach: int = int(spec.get("reach", 1))
			for i in range(1, reach + 1):
				out.append(pos + HexUtil.dir_vec(facing) * i)
		"front3":
			var reach: int = int(spec.get("reach", 1))
			var base: Vector2i = pos + HexUtil.dir_vec(facing) * reach
			out.append(base)
			out.append(pos + HexUtil.dir_vec(HexUtil.rotate_dir(facing, -1)) * reach)
			out.append(pos + HexUtil.dir_vec(HexUtil.rotate_dir(facing, 1)) * reach)
		"all6":
			for n in HexUtil.neighbors(pos):
				out.append(n)
		_:
			out.append(pos + HexUtil.dir_vec(facing))
	return out


func _auto_attack() -> void:
	var spec: Dictionary = weapon_spec()
	if int(spec.get("damage", 0)) <= 0:
		return
	var hits: Array[Vector2i] = attack_hits()
	if hits.is_empty():
		return
	for i in range(enemies.size() - 1, -1, -1):
		var e: Dictionary = enemies[i]
		if hits.has(e["pos"]):
			var enemy_hp: int = int(e["hp"]) - int(spec["damage"])
			if enemy_hp <= 0:
				enemies.remove_at(i)
				enemy_killed.emit(str(e["kind"]), e["pos"])
				quests.on_enemy_killed(str(e["kind"]))
			else:
				e["hp"] = enemy_hp


# ================================================================ enemies

func _enemy_spec(kind: String) -> Dictionary:
	return balance.get("enemies", {}).get(kind, {})


func _try_spawn_enemies() -> void:
	var s: Dictionary = balance.get("spawns", {})
	var max_active: int = int(s.get("max_active_enemies", 20))
	var radius: int = int(s.get("spawn_radius", 14))
	if enemies.size() >= max_active:
		return
	# only spawn near the player in/around dark zones
	var near_dark: Array[Vector2i] = []
	for cand in HexUtil.ring(pos, radius):
		if world.is_dark(cand) or world.terrain_at(cand) == Terrain.DARK:
			var t: int = world.terrain_at(cand)
			if t == Terrain.GRASS or t == Terrain.DARK:
				if not is_blocked(cand):
					near_dark.append(cand)
	if near_dark.is_empty():
		return
	var spot: Vector2i = near_dark[rng.next_i64() % near_dark.size()]
	var kind: String = _weighted_enemy_kind()
	var spec: Dictionary = _enemy_spec(kind)
	enemies.append({
		"id": next_entity_id,
		"kind": kind,
		"pos": spot,
		"hp": int(spec.get("hp", 3)),
	})
	next_entity_id += 1


## Public helper: force-spawn an enemy at a hex (used by the benchmark and
## by tests to guarantee a combat scenario).
func spawn_enemy_at(c: Vector2i, kind: String) -> int:
	var spec: Dictionary = _enemy_spec(kind)
	if spec.is_empty():
		push_warning("spawn_enemy_at: unknown enemy kind '%s'" % kind)
		return -1
	enemies.append({
		"id": next_entity_id,
		"kind": kind,
		"pos": c,
		"hp": int(spec.get("hp", 3)),
	})
	var id: int = next_entity_id
	next_entity_id += 1
	return id


func _weighted_enemy_kind() -> String:
	var specs: Dictionary = balance.get("enemies", {})
	var total: int = 0
	for k in specs:
		total += int(specs[k].get("spawn_weight", 1))
	var roll: int = int(rng.next_i64() % total)
	var acc: int = 0
	for k in specs:
		acc += int(specs[k].get("spawn_weight", 1))
		if roll < acc:
			return str(k)
	return "zombie"


func _enemies_tick() -> void:
	for e in enemies:
		_move_enemy(e)
	# enemies on player hex attack
	for e in enemies:
		if e["pos"] == pos:
			_enemy_hit_player(int(_enemy_spec(str(e["kind"])).get("damage", 1)))
			# leave the player hex (can't stack)
			var escape: Vector2i = _find_walkable_away(e)
			if escape != Vector2i() :
				e["pos"] = escape


func _move_enemy(e: Dictionary) -> void:
	# Wolf: 50% strafe (sideways), else chase. Zombie: always chase.
	var kind: String = str(e["kind"])
	var step_dir: int
	if kind == "wolf" and rng.chance(0.5):
		step_dir = HexUtil.rotate_dir(_toward(e["pos"], pos), rng.range_i(1, 5))
		if step_dir < 0:
			step_dir += 6
	else:
		step_dir = _toward(e["pos"], pos)
	var target: Vector2i = e["pos"] + HexUtil.dir_vec(step_dir)
	if not is_blocked(target) and not _enemy_occupied(target, e["id"]):
		e["pos"] = target


func _enemy_occupied(c: Vector2i, self_id: int) -> bool:
	for e in enemies:
		if e["id"] != self_id and e["pos"] == c:
			return true
	return false


func _toward(a: Vector2i, b: Vector2i) -> int:
	## Best direction from a to b (hex A* lite: try all 6, pick min distance).
	var best_d: int = HexUtil.distance(a, b)
	var best: int = 0
	for d in range(6):
		var nd: int = HexUtil.distance(a + HexUtil.dir_vec(d), b)
		if nd < best_d:
			best_d = nd
			best = d
	return best


func _find_walkable_away(e: Dictionary) -> Vector2i:
	var pos_e: Vector2i = e["pos"]
	var best: int = _toward(pos_e, pos)
	var target: Vector2i = pos_e + HexUtil.dir_vec(best)
	if not is_blocked(target) and not _enemy_occupied(target, int(e["id"])) and target != pos:
		return target
	return Vector2i()  # stays (will attack again next tick)


func _enemy_hit_player(dmg: int) -> void:
	hp -= dmg
	last_hit_at = Time.get_ticks_msec() / 1000.0
	_low_health_update()
	if hp <= 0:
		_die()


func _despawn_far_enemies() -> void:
	var despawn: int = int(balance.get("spawns", {}).get("despawn_radius", 26))
	var keep: Array[Dictionary] = []
	for e in enemies:
		if HexUtil.distance(e["pos"], pos) <= despawn:
			keep.append(e)
	enemies = keep


func _regen_check() -> void:
	## HP regen: 1 HP per `hp_regen_seconds_since_hit` seconds of no hits.
	if hp >= max_hp:
		return
	var secs: float = float(balance.get("player", {}).get("hp_regen_seconds_since_hit", 20.0))
	var now: float = Time.get_ticks_msec() / 1000.0
	if last_hit_at <= 0.0 or (now - last_hit_at) >= secs:
		hp = mini(hp + 1, max_hp)
		if last_hit_at > 0.0:
			last_hit_at += secs  # keep the cadence even under long gaps
		_low_health_update()


func _low_health_update() -> void:
	## Low-HP signal: screen flashes red when hp <= 1.
	low_health_changed.emit(hp <= 1)


# ================================================================ death / respawn

func _die() -> void:
	alive = false
	hp = 0
	player_died.emit()
	do_save()  # items persist
	# short delay then respawn
	var t := get_tree().create_timer(1.2)
	t.timeout.connect(_respawn)


func _respawn() -> void:
	pos = Vector2i.ZERO
	facing = 0
	alive = true
	hp = max_hp
	enemies = []
	last_hit_at = 0.0
	player_moved.emit(pos, facing)
	_low_health_update()


# ================================================================ equipment

func equip(weapon: String) -> bool:
	if not balance.get("weapons", {}).has(weapon):
		return false
	equipped_weapon = weapon
	return true


func equip_armor(armor: String) -> bool:
	if not balance.get("player", {}).get("armor_hp_bonus", {}).has(armor):
		return false
	equipped_armor = armor
	_max_hp_recalc()
	hp = mini(hp, max_hp)
	return true


func _max_hp_recalc() -> void:
	var base: int = int(balance.get("player", {}).get("base_hp", 2))
	var bonus: int = int(balance.get("player", {}).get("armor_hp_bonus", {}).get(equipped_armor, 0))
	max_hp = base + bonus


# ================================================================ pause / save

func set_paused(p: bool, source: String = "user") -> void:
	if paused == p:
		return
	paused = p
	if p:
		do_save()
	get_tree().paused = p
	pause_requested.emit(p)
	if p and source == "yt":
		YTGameWrapper.request_interstitial_ad()


func do_save() -> void:
	var payload: String = save.build_payload(collect_state())
	if OS.has_feature("web") and YTGameWrapper.in_playables_env():
		# YouTube Playables cloud save
		YTGameWrapper.save_data(payload)
	else:
		# standalone: browser localStorage
		save.save_local(payload)


func collect_state() -> Dictionary:
	return {
		"seed": world_seed,
		"tick": tick,
		"pos": [pos.x, pos.y],
		"facing": facing,
		"hp": hp,
		"weapon": equipped_weapon,
		"armor": equipped_armor,
		"inventory": inventory.to_dict(),
		"quests": quests.to_dict(),
		"deltas": world.save_deltas(),
		"last_hit_at": last_hit_at,
	}


func _try_load_save() -> void:
	# Order: YouTube cloud (async -> arrives via _on_load_data_received),
	# then localStorage (sync).
	var local: String = save.load_local()
	if local != "":
		_apply_save_payload(local)
	elif OS.has_feature("web") and YTGameWrapper.in_playables_env():
		YTGameWrapper.load_data()  # async; applied when received


func _apply_save_payload(json_str: String) -> void:
	var data: Dictionary = save.parse_payload(json_str)
	if data.is_empty():
		return
	apply_state(data)


func apply_state(d: Dictionary) -> void:
	if not d.is_empty():
		world_seed = int(d.get("seed", world_seed))
		world = WorldGen.new(world_seed, balance)
		# re-wire systems that hold world references
		if inventory == null:
			inventory = InventorySystem.new()
		crafting = CraftingSystem.new(balance, inventory)
		quests = QuestSystem.new(balance, content, inventory)
		_apply_deltas(d.get("deltas", {}))
		pos = Vector2i(int(d.get("pos", [0, 0])[0]), int(d.get("pos", [0, 0])[1]))
		facing = int(d.get("facing", 0))
		equipped_weapon = str(d.get("weapon", "none"))
		equipped_armor = str(d.get("armor", "none"))
		_max_hp_recalc()
		hp = int(d.get("hp", max_hp))
		hp = clampi(hp, 0, max_hp)
		if hp <= 0:
			hp = max_hp
		tick = int(d.get("tick", 0))
		last_hit_at = float(d.get("last_hit_at", 0.0))
		inventory.load_dict(d.get("inventory", {}))
		quests.load_dict(d.get("quests", {}))
		alive = true
		enemies = []
		rng = SeededRng.new(world_seed * 7 + 3)
		_low_health_update()


func _apply_deltas(deltas: Dictionary) -> void:
	if world == null:
		return
	world.apply_deltas(deltas.get("removed_dark", []), deltas.get("consumed", []))


# ================================================================ new game

func new_game(seed: int) -> void:
	world_seed = seed
	_world_setup()
	pos = Vector2i.ZERO
	facing = 0
	tick = 0
	_max_hp_recalc()
	hp = max_hp
	alive = true
	last_hit_at = 0.0
	save.clear_local()


func score() -> int:
	## Simple engagement score: ticks survived + items gathered.
	var items: int = 0
	for k in inventory.counts:
		items += int(inventory.counts[k])
	return tick + items * 10
