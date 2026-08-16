extends Node
# 60fps logic benchmark: 20 active enemies, 400 real ticks.
func _ready() -> void:
	var game: Node = get_node_or_null("/root/Game")
	if game == null or game.world == null:
		push_error("BENCH_FAIL: Game autoload missing")
		get_tree().quit(1)
		return
	for i in 20:
		var off: Vector2i = HexUtil.DIRS[i % 6] * (2 + (i % 4))
		game.spawn_enemy_at(game.pos + off, "zombie" if i % 2 == 0 else "wolf")
	print("BENCH SPAWNED=%d" % game.enemies.size())
	var t0 := int(Time.get_ticks_msec())
	for i in 400:
		game._do_tick()
	var t1 := int(Time.get_ticks_msec())
	print("BENCH TICKS=400 MS=%d AVG_MS=%.3f ENEMIES=%d HP=%d POS=%s" % [t1 - t0, float(t1 - t0) / 400.0, game.enemies.size(), game.hp, str(game.pos)])
	get_tree().quit(0)
