class_name WorldGen
## Deterministic procedural world generator.
##
## The world is a pure function of the seed: any cell's terrain can be
## recomputed from (seed, coords) with no stored base state. Mutations
## (harvested trees, opened chests, broken dark zones) are stored as
## per-chunk *deltas* in the save, keeping saves tiny for an infinite world.
##
## Dark zones: the "darkness" field is a second noise pass. A zone is a coarse
## 9x9 quantized cell of that field; each zone has exactly ONE crystal at its
## deterministic anchor hex. Breaking the crystal removes the whole zone.

const DARK_QUANTUM := 9


var seed: int
var balance: Dictionary
var noise: FbmNoise
var dark_noise: FbmNoise

## delta state (persisted):
var removed_dark_zones: Dictionary = {}   # zone key -> true
var consumed_features: Dictionary = {}    # "t:q,r" / "c:q,r" / "o:q,r" -> true


func _init(p_seed: int, p_balance: Dictionary) -> void:
	seed = p_seed
	balance = p_balance
	noise = FbmNoise.new(seed)
	dark_noise = FbmNoise.new(seed * 31 + 17)


# ================================================================ terrain

func terrain_at(c: Vector2i) -> int:
	# 1) player deltas win (harvested tree -> GRASS etc.)
	var dk: String = "t:" + _key(c)
	if consumed_features.has(dk):
		return int(consumed_features[dk])
	# 2) one-shot features consumed -> base falls back to grass
	if consumed_features.has("c:" + _key(c)):
		return Terrain.GRASS
	if consumed_features.has("o:" + _key(c)):
		return Terrain.GRASS
	return _base_terrain(c)


func _key(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]


func _cell_hash(c: Vector2i) -> int:
	return hash_cell(c, seed)


func _base_terrain(c: Vector2i) -> int:
	var w: Dictionary = balance.get("world", {})
	var dist_spawn: int = HexUtil.distance(c, Vector2i.ZERO)
	var clear_r: int = int(w.get("spawn_clear_radius", 8))
	if dist_spawn <= clear_r:
		return Terrain.GRASS
	# ocean
	if noise.fbm(float(c.x) * 0.035, float(c.y) * 0.035, 4) \
			> float(w.get("ocean_noise_threshold", 0.88)):
		return Terrain.OCEAN
	# hills: low-frequency noise -> ring-like walls
	if noise.fbm(float(c.x) * 0.028 + 100.0, float(c.y) * 0.028 + 100.0, 4) \
			> float(w.get("hill_noise_threshold", 0.905)):
		return Terrain.HILL
	# villages
	var v: Dictionary = _village_at(c)
	if v.get("kind") == "center":
		return Terrain.VILLAGE
	if v.get("kind") == "path":
		return Terrain.PATH
	# dark zones (after villages: a village hex is never dark)
	if _in_dark_zone(c):
		var dkey: String = dark_zone_key(c)
		if not removed_dark_zones.has(dkey):
			if c == crystal_hex(dkey):
				return Terrain.CRYSTAL
			return Terrain.DARK
	# scattered features via per-cell hash (deterministic, O(1))
	var h: int = _cell_hash(c)
	var f1: float = (h & 0x7FFFFF) / 8388607.0
	var f2: float = ((h >> 21) & 0x7FFFFF) / 8388607.0
	var f3: float = ((h >> 42) & 0x7F) / 127.0
	var ore_min: int = int(w.get("ore_min_dist_from_spawn", 5))
	var chest_min: int = int(w.get("chest_min_dist_from_spawn", 6))
	if dist_spawn >= chest_min and f3 < float(w.get("chest_chance", 0.004)):
		return Terrain.CHEST
	if dist_spawn >= ore_min and f2 < float(w.get("ore_chance", 0.02)):
		return Terrain.ORE
	if f1 < float(w.get("tree_chance", 0.14)):
		return Terrain.TREE
	return Terrain.GRASS


static func hash_cell(c: Vector2i, p_seed: int) -> int:
	## Deterministic 64-bit hash of (seed, coords) — xmur3-style mixing,
	## signed-safe (Godot int wrap semantics).
	var h: int = (p_seed ^ 0x9E3779B9)
	h ^= int(c.x) + -7046029254386353131
	h = h * 2246822507
	h ^= int(c.y) + 3266489909
	h = h * 3266489909
	return h ^ (h >> 31)

# ================================================================ villages

## If `c` belongs to a village (center, path, or villager hex) return its
## layout info; otherwise {}. Village lattice: every `spacing`-th hex in both
## axial axes; ~60% of lattice points (by hash) host a village.
func _village_at(c: Vector2i) -> Dictionary:
	var spacing: int = int(balance.get("world", {}).get("village_spacing", 22))
	if spacing <= 0:
		return {}
	var rem_x: int = c.x % spacing
	var rem_y: int = c.y % spacing
	if rem_x != 0 and rem_y != 0:
		return {}
	# The lattice POINT is the nearest axis-aligned multiple:
	var lx: int = c.x - rem_x
	var ly: int = c.y - rem_y
	var lattice: Vector2i = Vector2i(lx, ly)
	var h: int = _cell_hash(lattice)
	if h % 100 >= 60:
		return {}
	if HexUtil.distance(lattice, Vector2i.ZERO) < 12:
		return {}
	var ring: Array[Vector2i] = HexUtil.ring(lattice, 1)
	var v0: Vector2i = ring[h % 6]
	var v1: Vector2i = ring[(h / 6) % 6]
	if v1 == v0:
		v1 = ring[(h / 6 + 1) % 6]
	if c == lattice:
		return {"kind": "center", "villagers": [v0, v1]}
	if ring.has(c):
		if c == v0 or c == v1:
			return {"kind": "villager", "villager_hex": c, "center": lattice, "villagers": [v0, v1]}
		return {"kind": "path"}
	return {}


func village_villagers(center: Vector2i) -> Array[Vector2i]:
	var v: Dictionary = _village_at(center)
	if v.get("kind") != "center":
		return []
	return (v.get("villagers", []) as Array).duplicate()


func nearest_village_center(c: Vector2i) -> Vector2i:
	var spacing: int = int(balance.get("world", {}).get("village_spacing", 22))
	var gx: int = roundf(float(c.x) / float(spacing)) * spacing
	var gy: int = roundf(float(c.y) / float(spacing)) * spacing
	var best: Vector2i = Vector2i.ZERO
	var best_d: int = 1 << 30
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var cand: Vector2i = Vector2i(gx + dx * spacing, gy + dy * spacing)
			if _village_at(cand).is_empty():
				continue
			var d: int = HexUtil.distance(c, cand)
			if d < best_d:
				best_d = d
				best = cand
	return best

# ================================================================ dark zones

func _in_dark_zone(c: Vector2i) -> bool:
	var thr: float = float(balance.get("world", {}).get("dark_noise_threshold", 0.74))
	return dark_noise.fbm(float(c.x) * 0.06, float(c.y) * 0.06, 3) > thr


## Zone key = coarse quantized cell of the dark field.
func dark_zone_key(c: Vector2i) -> String:
	var q: int = int(floorf(float(c.x) / DARK_QUANTUM))
	var r: int = int(floorf(float(c.y) / DARK_QUANTUM))
	return "dz:%d,%d" % [q, r]


## The zone's single crystal hex (deterministic anchor, jittered by hash).
func crystal_hex(zone_key: String) -> Vector2i:
	var parts: Array = zone_key.substr(3).split(",")
	var qx: int = int(parts[0]) * DARK_QUANTUM
	var qr: int = int(parts[1]) * DARK_QUANTUM
	var h: int = _cell_hash(Vector2i(qx, qr))
	return Vector2i(qx + (h % 5) + 2, qr + ((h >> 5) % 5) + 2)


func is_dark(c: Vector2i) -> bool:
	if not _in_dark_zone(c):
		return false
	return not removed_dark_zones.has(dark_zone_key(c))


func break_dark_zone(c: Vector2i) -> String:
	var key: String = dark_zone_key(c)
	removed_dark_zones[key] = true
	return key


# ================================================================ deltas

func consume_feature(kind: String, c: Vector2i) -> void:
	## kind: "t" tree, "o" ore, "c" chest. Trees/ores also record GRASS delta.
	var k: String = kind + ":" + _key(c)
	consumed_features[k] = true
	if kind == "t" or kind == "o":
		consumed_features["t:" + _key(c)] = Terrain.GRASS
	elif kind == "c":
		consumed_features["t:" + _key(c)] = Terrain.GRASS


func save_deltas() -> Dictionary:
	## removed_dark: list of zone keys. consumed: list of "key|value" strings
	## (values matter for "t:" terrain overrides).
	var rem: Array = removed_dark_zones.keys()
	var con: Array = []
	for k in consumed_features:
		con.append("%s|%s" % [str(k), str(consumed_features[k])])
	return {"removed_dark": rem, "consumed": con}


func apply_deltas(removed: Array, consumed: Array) -> void:
	removed_dark_zones.clear()
	for k in removed:
		removed_dark_zones[str(k)] = true
	consumed_features.clear()
	for entry in consumed:
		var e: String = str(entry)
		var sep: int = e.rfind("|")
		var k: String
		var v: Variant
		if sep >= 0:
			k = e.substr(0, sep)
			v = e.substr(sep + 1)
		else:
			k = e
			v = true
		if k.begins_with("t:"):
			consumed_features[k] = int(v)
		else:
			consumed_features[k] = v
