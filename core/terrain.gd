## Global terrain type constants (plain ints — most robust across GDScript
## enum-namespace edge cases, trivially serializable).
class_name Terrain

const GRASS := 0
const OCEAN := 1
const HILL := 2        # impassable wall
const TREE := 3        # walkable ground, auto-chop on bump (wood)
const ORE := 4         # walkable ground, auto-mine on bump (rare ore)
const CHEST := 5       # non-walkable, auto-open on bump (1 loot item)
const VILLAGE := 6     # non-walkable building
const PATH := 7        # walkable village path
const VILLAGER := 8    # non-walkable, auto-talk on bump
const DARK := 9        # walkable dark-tinted ground (enemy spawn zone)
const CRYSTAL := 10    # non-walkable, break on bump (darkness crystal)

const ALL := [GRASS, OCEAN, HILL, TREE, ORE, CHEST, VILLAGE, PATH, VILLAGER, DARK, CRYSTAL]
