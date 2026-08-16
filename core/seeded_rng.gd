class_name SeededRng
## Deterministic RNG (xorshift128+ variant on signed 64-bit).
## Same seed -> same sequence, always. Used for world features & combat so the
## world is reproducible from a seed.
##
## GDScript ints are SIGNED 64-bit: we rely on two's-complement wrap (Godot
## guarantees wraparound for int arithmetic) and use DECIMAL constants (hex
## literals above 0x7F… don't parse as int64).

## splitmix64 golden ratio (decimal of 0x9E3779B97F4A7C15)
const SM_A: int = -7046029254386353131
## multiplier (decimal of 0xBF58476D1CE4E5B9)
const SM_M1: int = -4658895280553007687
## multiplier (decimal of 0x94D049BB133111EB)
const SM_M2: int = -7723592293110705685
## zero-state fallback (decimal of 0x6A09E667F3BCC908)
const SM_FALLBACK: int = 7694713095061849176


var _s0: int
var _s1: int


func _init(seed: int) -> void:
	_s0 = _splitmix64(seed)
	if _s0 == 0:
		_s0 = SM_FALLBACK
	_s1 = _splitmix64(_s0)
	if _s1 == 0:
		_s1 = SM_FALLBACK + 1


static func _splitmix64(x: int) -> int:
	var z: int = x + SM_A
	z = (z ^ (z >> 30)) * SM_M1
	z = (z ^ (z >> 27)) * SM_M2
	return z ^ (z >> 31)


## Pseudo-random int64 (signed). Deterministic stream.
func next_i64() -> int:
	var s1: int = _s0
	var s0v: int = _s1
	_s0 = s0v
	s1 += 1
	s1 = (s1 + (s1 << 7)) ^ s0v
	_s1 = s1
	return s1 ^ (s1 >> 31)


func next_f64() -> float:
	# 53-bit mantissa in [0,1)
	return float(_s1 & 0x0001FFFFFFFFFFFFF) / 9007199254740992.0


func range_f(minv: float, maxv: float) -> float:
	return minv + (maxv - minv) * next_f64()


func range_i(minv: int, maxv: int) -> int:
	# inclusive
	if minv > maxv:
		var t := minv
		minv = maxv
		maxv = t
	var span: int = maxv - minv + 1
	if span <= 0:
		return minv
	return minv + int(_s1 % span)


func chance(p: float) -> bool:
	return next_f64() < p


func pick(arr: Array) -> Variant:
	return arr[int(_s1 % arr.size())]


func fork(salt: int) -> SeededRng:
	## Independent stream for a sub-purpose (per-chunk / per-villager).
	var derived: int = _splitmix64(salt + 1189437831372502198) ^ _s0
	return SeededRng.new(derived)
