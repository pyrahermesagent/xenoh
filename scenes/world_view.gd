class_name WorldView
extends Node2D
## WorldView: a single CanvasItem that draws EVERYTHING — hex terrain (one
## pass), prop sprites, the player, and all enemies — in draw order.
## Keeping it to one CanvasItem + one Sprite-less draw path is what keeps
## 20+ enemies at 60fps on the web (gl_compatibility) target.

var world: WorldGen
var hex_size: float = 26.0

const TINT := {
	Terrain.GRASS: Color("b2cd8f"),
	Terrain.OCEAN: Color("7aa8be"),
	Terrain.HILL: Color("c4b294"),
	Terrain.PATH: Color("d8c8a8"),
	Terrain.VILLAGE: Color("ded0b6"),
	Terrain.DARK: Color("4a4658"),
	Terrain.CHEST: Color("b2cd8f"),
	Terrain.ORE: Color("b2cd8f"),
	Terrain.TREE: Color("b2cd8f"),
	Terrain.CRYSTAL: Color("4a4658"),
	Terrain.VILLAGER: Color("b2cd8f"),
}
const INK := Color(0.07, 0.06, 0.05)

var _tex: Dictionary = {}
var _player_tex: Texture2D
var _zombie_tex: Texture2D
var _wolf_tex: Texture2D
var _villager_tex: Texture2D

var _bob: float = 0.0          # player idle bob
var _last_pos: Vector2i = Vector2i.ZERO
var _move_progress: float = 1.0  # 0..1 animation of the last step


func _ready() -> void:
	for name in ["prop_tree", "prop_ore", "prop_chest", "prop_crystal",
			"tex_building", "spr_villager", "spr_player", "spr_zombie", "spr_wolf"]:
		var p: String = "res://art/sprites/%s.png" % name
		if ResourceLoader.exists(p):
			_tex[name] = load(p)
	_player_tex = _tex.get("spr_player")
	_zombie_tex = _tex.get("spr_zombie")
	_wolf_tex = _tex.get("spr_wolf")
	_villager_tex = _tex.get("spr_villager")


func _process(delta: float) -> void:
	if Game == null:
		return
	_bob += delta * 6.0
	_move_progress = minf(_move_progress + delta / 0.35, 1.0)
	queue_redraw()


## Call when the player has stepped to a new hex (start the step animation).
func note_player_moved(prev: Vector2i) -> void:
	_last_pos = prev
	_move_progress = 0.0


func hex_points(center: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(6):
		var ang: float = deg_to_rad(60.0 * i - 30.0)
		pts.append(center + Vector2(cos(ang), sin(ang)) * hex_size)
	return pts


func _world_center_screen() -> Vector2:
	return get_viewport_rect().size * 0.5


func _cell_screen(c: Vector2i) -> Vector2:
	var p: Vector2 = HexUtil.axial_to_pixel(c, hex_size)
	return _world_center_screen() - p


func _draw() -> void:
	if Game == null or Game.world == null:
		return
	world = Game.world
	var ppos: Vector2i = Game.pos
	var view_r: int = int(_world_center_screen().x / (hex_size * 1.732)) + 2
	# ---- terrain pass (far to near by y for correct overlap) ----
	var cells: Array[Vector2i] = HexUtil.spiral(view_r)
	# sort by pixel y so lower hexes draw on top of higher ones
	var sorted: Array = cells.duplicate()
	sorted.sort_custom(func(a, b):
		return HexUtil.axial_to_pixel(a, hex_size).y < HexUtil.axial_to_pixel(b, hex_size).y)
	for cell in sorted:
		var c: Vector2i = ppos + (cell as Vector2i)
		var t: int = world.terrain_at(c)
		var center: Vector2 = _cell_screen(c)
		var pts: PackedVector2Array = hex_points(center)
		var col: Color = TINT.get(t, TINT[Terrain.GRASS])
		draw_colored_polygon(pts, col)
		var outline: PackedVector2Array = pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, INK, 2.0, true)
		if t == Terrain.HILL:
			var inner: PackedVector2Array = PackedVector2Array()
			for i in range(6):
				inner.append(center + (pts[i] - center) * 0.55)
			draw_colored_polygon(inner, Color("b09678"))
			var io: PackedVector2Array = inner.duplicate()
			io.append(inner[0])
			draw_polyline(io, INK, 1.5, true)
	# ---- entity/prop pass, same y-sorted order ----
	var items: Array = []
	for cell in sorted:
		var c: Vector2i = ppos + (cell as Vector2i)
		var t: int = world.terrain_at(c)
		var key: Vector2 = HexUtil.axial_to_pixel(c, hex_size)
		match t:
			Terrain.TREE:
				items.append([key.y, "prop_tree", c])
			Terrain.ORE:
				items.append([key.y, "prop_ore", c])
			Terrain.CHEST:
				items.append([key.y, "prop_chest", c])
			Terrain.CRYSTAL:
				items.append([key.y, "prop_crystal", c])
			Terrain.VILLAGE:
				items.append([key.y, "tex_building", c])
			Terrain.VILLAGER, Terrain.PATH:
				pass
	# villagers: from the village layout (villager hexes)
	for center in _near_villages(ppos, 3):
		for vh in world.village_villagers(center):
			var key: Vector2 = HexUtil.axial_to_pixel(vh, hex_size)
			items.append([key.y, "spr_villager", vh])
	# enemies
	for e in Game.enemies:
		var key: Vector2 = HexUtil.axial_to_pixel(e["pos"], hex_size)
		items.append([key.y, str(e["kind"]), e["pos"]])
	# player last-ish (sorted in too)
	items.append([HexUtil.axial_to_pixel(ppos, hex_size).y, "@player", ppos])
	items.sort_custom(func(a, b): return a[0] < b[0])
	for it in items:
		var y: float = it[0]
		var kind: String = it[1]
		var c: Vector2i = it[2]
		var center: Vector2 = _cell_screen(c)
		match kind:
			"@player":
				_draw_player(center)
			"zombie":
				_draw_texture_at(_zombie_tex, center, hex_size * 2.1)
			"wolf":
				_draw_texture_at(_wolf_tex, center, hex_size * 2.1)
			_:
				_draw_texture_at(_tex.get(kind), center, hex_size * 2.0)


func _near_villages(ppos: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var spacing: int = int(Game.balance.get("world", {}).get("village_spacing", 22))
	var gx: int = roundf(float(ppos.x) / float(spacing)) * spacing
	var gy: int = roundf(float(ppos.y) / float(spacing)) * spacing
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var cand: Vector2i = Vector2i(gx + dx * spacing, gy + dy * spacing)
			if world._village_at(cand).get("kind") == "center":
				out.append(cand)
	return out


func _draw_texture_at(tex: Texture2D, center: Vector2, target_w: float) -> void:
	if tex == null:
		return
	var sz: Vector2 = tex.get_size()
	var scale: float = target_w / sz.x
	var pos: Vector2 = center + Vector2(-sz.x * 0.5 * scale, -sz.y * 0.5 * scale + hex_size * 0.3)
	draw_texture(tex, pos)


func _draw_player(center: Vector2) -> void:
	if _player_tex == null:
		return
	var sz: Vector2 = _player_tex.get_size()
	var scale: float = hex_size * 2.2 / sz.x
	# step lerp: animate from previous pos to current
	var from: Vector2 = _cell_screen(_prev_pos_for_anim())
	var to: Vector2 = center
	var pos: Vector2 = from.lerp(to, _move_progress)
	var bob: float = sin(_bob) * 1.5
	pos += Vector2(0, bob)
	var dpos: Vector2 = pos + Vector2(-sz.x * 0.5 * scale, -sz.y * 0.5 * scale + hex_size * 0.3)
	draw_texture(_player_tex, dpos)
	# facing indicator: small ink arrow showing where the sword points
	var f: Vector2 = HexUtil.PIX_DIRS[Game.facing].normalized()
	var a0: Vector2 = pos + f * (hex_size * 0.85)
	var a1: Vector2 = pos + f * (hex_size * 1.5)
	draw_line(a0, a1, INK, 3.0)
	draw_circle(a1, 3.0, INK)


func _prev_pos_for_anim() -> Vector2i:
	return _last_pos
