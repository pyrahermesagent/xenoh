class_name WorldCell
## Data for one hex. Kept tiny & serializable (per-chunk deltas in saves).

var terrain: int = Terrain.GRASS
var entity_id: int = -1   # runtime-only link to a live entity; not saved


func to_dict() -> Dictionary:
	return { "t": terrain }


static func from_dict(d: Dictionary) -> WorldCell:
	var c := WorldCell.new()
	c.terrain = int(d.get("t", Terrain.GRASS))
	return c
