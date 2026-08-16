class_name FbmNoise
## 2D gradient (Perlin-like) noise + fBm (fractal Brownian motion).
## Fully deterministic from a seed (xorshift-seeded permutation table),
## so the same seed always yields the same world.

var _perm: PackedInt32Array
const PERM_SIZE := 256


## 8 unit-ish gradient directions (quantized for speed).
const GRAD: Array[Vector2] = [
	Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1),
	Vector2(0.7071, 0.7071), Vector2(-0.7071, 0.7071),
	Vector2(0.7071, -0.7071), Vector2(-0.7071, -0.7071),
]


func _init(seed: int) -> void:
	var rng := SeededRng.new(seed)
	_perm = PackedInt32Array()
	var base: PackedInt32Array = PackedInt32Array()
	for i in range(PERM_SIZE):
		base.append(i)
	# Deterministic Fisher-Yates shuffle
	for i in range(PERM_SIZE - 1, 0, -1):
		var j: int = int(rng.next_i64() % (i + 1))
		var t: int = base[i]
		base[i] = base[j]
		base[j] = t
	for i in range(PERM_SIZE):
		_perm.append(base[i])
		_perm.append(base[i])  # double length so we never bound-check


## Perlin-style gradient noise in [-1, 1] (practical range ~[-0.9, 0.9]).
func noise2(x: float, y: float) -> float:
	var xi: int = int(floorf(x)) & 0xFF
	var yi: int = int(floorf(y)) & 0xFF
	var xf: float = x - floorf(x)
	var yf: float = y - floorf(y)
	var u: float = _fade(xf)
	var v: float = _fade(yf)
	var g00: float = _dot(_perm[_perm[xi] + yi] & 7, xf, yf)
	var g10: float = _dot(_perm[_perm[xi + 1] + yi] & 7, xf - 1.0, yf)
	var g01: float = _dot(_perm[_perm[xi] + yi + 1] & 7, xf, yf - 1.0)
	var g11: float = _dot(_perm[_perm[xi + 1] + yi + 1] & 7, xf - 1.0, yf - 1.0)
	var top: float = _lerp(g00, g10, u)
	var bot: float = _lerp(g01, g11, u)
	return _lerp(top, bot, v)


func _dot(gi: int, x: float, y: float) -> float:
	var g: Vector2 = GRAD[gi]
	return g.x * x + g.y * y


## Fractal Brownian motion, normalized to roughly [-1, 1].
func fbm(x: float, y: float, octaves: int = 4, lacunarity: float = 2.0, gain: float = 0.5) -> float:
	var amp: float = 1.0
	var freq: float = 1.0
	var sum: float = 0.0
	var norm: float = 0.0
	for _i in range(octaves):
		sum += amp * noise2(x * freq, y * freq)
		norm += amp
		amp *= gain
		freq *= lacunarity
	return sum / norm if norm > 0.0 else 0.0


func _fade(t: float) -> float:
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


func _lerp(a: float, b: float, t: float) -> float:
	return a + (b - a) * t
