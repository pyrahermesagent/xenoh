class_name HexUtil
## Pointy-top flat hex grid math with axial coordinates (q, r), y pointing DOWN.
## Direction index (clockwise from East, standard "pointy" layout):
##   0=E  1=SE  2=SW  3=W  4=NW  5=NE
## Pixel mapping (pointy-top, hex "radius" = s):
##   x = s * sqrt(3) * (q + r/2)
##   y = s * 3/2 * r
## so E/W neighbors are s*sqrt(3) apart horizontally and N/S neighbors are
## 1.5*s apart vertically (diagonal).

const SQRT3: float = 1.7320508075688772

const DIRS: Array[Vector2i] = [
	Vector2i(1, 0),    # 0 E
	Vector2i(0, 1),    # 1 SE
	Vector2i(-1, 1),   # 2 SW
	Vector2i(-1, 0),   # 3 W
	Vector2i(-1, -1),  # 4 NW
	Vector2i(0, -1),   # 5 NE
]

const PIX_DIRS: Array[Vector2] = [
	Vector2(SQRT3, 0.0),     # E
	Vector2(SQRT3 / 2.0, 1.5),   # SE
	Vector2(-SQRT3 / 2.0, 1.5),  # SW
	Vector2(-SQRT3, 0.0),     # W
	Vector2(-SQRT3 / 2.0, -1.5), # NW
	Vector2(SQRT3 / 2.0, -1.5),  # NE
]


static func dir_vec(d: int) -> Vector2i:
	return DIRS[d % 6]


static func rotate_dir(d: int, turns: int) -> int:
	return wrap(d + turns, 0, 5)


static func axial_to_pixel(c: Vector2i, s: float) -> Vector2:
	return Vector2(
		s * SQRT3 * (float(c.x) + 0.5 * float(c.y)),
		s * 1.5 * float(c.y)
	)


static func pixel_to_axial(p: Vector2, s: float) -> Vector2i:
	var qf: float = (2.0 / 3.0 * p.x / s) - p.y / (3.0 * s)
	var rf: float = (2.0 / 3.0 * p.y / s)
	return _axial_round(qf, rf)


static func _axial_round(qf: float, rf: float) -> Vector2i:
	var x: float = qf
	var z: float = rf
	var y: float = -x - z
	var xr: int = roundi(x)
	var yr: int = roundi(y)
	var zr: int = roundi(z)
	var xd: float = absf(xr - x)
	var yd: float = absf(yr - y)
	var zd: float = absf(zr - z)
	if xd > yd and xd > zd:
		xr = -yr - zr
	elif yd > zd:
		yr = -xr - zr
	else:
		zr = -xr - yr
	return Vector2i(xr, zr)


static func distance(a: Vector2i, b: Vector2i) -> int:
	var z1: int = -a.x - a.y
	var z2: int = -b.x - b.y
	return maxi(absi(a.x - b.x), maxi(absi(a.y - b.y), absi(z1 - z2)))


static func neighbors(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS:
		out.append(c + d)
	return out


## 6-neighbor ring at given hex distance.
static func ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	if radius <= 0:
		return [center]
	var results: Array[Vector2i] = []
	var hex := center + dir_vec(2) * radius
	for i in range(6):
		for _j in range(radius):
			results.append(hex)
			hex += dir_vec(i)
	return results


## Everything within hex distance <= radius, spiral order (center first).
static func spiral(radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = [Vector2i(0, 0)]
	for r in range(1, radius + 1):
		out.append_array(ring(Vector2i(0, 0), r))
	return out


## Chunk id for hex coord with chunk side length n (square-ish chunks in axial space).
static func chunk_id(c: Vector2i, n: int) -> Vector2i:
	return Vector2i(
		int(floorf(float(c.x) / float(n))),
		int(floorf(float(c.y) / float(n)))
	)
