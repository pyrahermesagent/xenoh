extends Node
## Main scene: wires WorldView + HUD + PauseMenu and handles input.
## Entire UI is built in code (no .tscn node graph) to keep the project
## small and the node tree authoritative in one place.

const VIEW_R := 7

var world_view: WorldView
var hud: CanvasLayer
var pause_menu: CanvasLayer
var low_hp: ColorRect
var toast: Label
var toast_tween: Tween
var score_lbl: Label
var weapon_lbl: Label
var quest_lbl: Label
var death_overlay: CanvasLayer

var _btn_left: Button
var _btn_right: Button
var _btn_pause: Button
var _last_prev_pos: Vector2i = Vector2i.ZERO
var _hp_pulse: Tween


func _vp() -> Vector2:
	return get_viewport().get_visible_rect().size


func _ready() -> void:
	# world renderer
	world_view = WorldView.new()
	add_child(world_view)
	_last_prev_pos = Game.pos

	# signal wiring
	Game.player_moved.connect(_on_player_moved)
	Game.low_health_changed.connect(_on_low_health)
	Game.interaction_happened.connect(_on_interaction)
	Game.player_died.connect(_on_player_died)
	Game.pause_requested.connect(_on_pause_requested)

	_build_hud()
	_build_pause_menu()
	_build_death_overlay()
	_refresh_hud()

	if Game.pos == Vector2i.ZERO and Game.tick == 0 and Game.inventory.counts.is_empty():
		pass  # fresh run: nothing to announce


func _on_player_moved(_p: Vector2i, _f: int) -> void:
	world_view.note_player_moved(_last_prev_pos)
	_last_prev_pos = Game.pos
	_refresh_hud()


func _on_low_health(low: bool) -> void:
	if low_hp == null:
		return
	if _hp_pulse != null and _hp_pulse.is_valid():
		_hp_pulse.kill()
	if low:
		_hp_pulse = create_tween().set_loops()
		_hp_pulse.tween_property(low_hp, "modulate:a", 0.45, 0.8)
		_hp_pulse.tween_property(low_hp, "modulate:a", 0.15, 0.8)
	else:
		low_hp.modulate.a = 0.0


func _on_interaction(it: Dictionary) -> void:
	match str(it.get("type", "")):
		"chop":
			_toast("+%d wood" % int(it["qty"]), "res://art/sprites/icn_wood.png")
		"mine":
			_toast("+%d rare ore" % int(it["qty"]), "res://art/sprites/icn_ore.png")
		"chest":
			_chest_reveal(str(it["item"]), int(it["qty"]))
		"crystal":
			_toast("Darkness crystal acquired! The gloom lifts…", "res://art/sprites/icn_crystal.png")
		"trade":
			_toast("Traded %d wood for %d rare ore" % [int(it.get("gave_wood", 0)), int(it.get("got_ore", 0))], "res://art/sprites/icn_ore.png")
		"trade_failed":
			_toast("Not enough wood to trade.", "res://art/sprites/icn_wood.png")
		"quest_offer":
			var q: Dictionary = it["quest"]
			_toast("New quest: %s x%d" % [_q_label(q), int(q["qty"])], "res://art/sprites/icn_quest.png")
		"quest_full":
			_toast("Quests full — finish one first.", "res://art/sprites/icn_quest.png")
		"talk":
			_toast("The villager hums a tune.", "res://art/sprites/spr_villager.png")
	_refresh_hud()


func _q_label(q: Dictionary) -> String:
	match str(q["kind"]):
		"fetch":
			return "gather %s" % str(q["target"])
		"defeat":
			return "defeat %s" % str(q["target"])
	return ""


func _on_player_died() -> void:
	death_overlay.visible = true
	var lbl: Label = death_overlay.get_node("DeadLabel")
	lbl.text = "You have fallen.\nYour pack is safe. Waking at the meadow's heart…"
	var tw: Tween = create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(func(): death_overlay.visible = false)


# ================================================================ HUD

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)

	# low-health red vignette (full screen, pulsing alpha)
	low_hp = ColorRect.new()
	low_hp.color = Color(0.72, 0.05, 0.02, 0.0)
	low_hp.set_anchors_preset(Control.PRESET_FULL_RECT)
	low_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(low_hp)

	# toast
	toast = Label.new()
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_size_override("font_size", 16)
	toast.add_theme_color_override("font_color", Color(0.07, 0.06, 0.05))
	toast.add_theme_color_override("font_outline_color", Color(0.96, 0.94, 0.88))
	toast.add_theme_constant_override("outline_size", 6)
	toast.position = Vector2(0, _vp().y - 120)
	toast.size = Vector2(_vp().x, 30)
	toast.modulate.a = 0.0
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(toast)

	# top bar
	var top: HBoxContainer = HBoxContainer.new()
	top.position = Vector2(8, 6)
	top.add_theme_constant_override("separation", 14)
	hud.add_child(top)
	score_lbl = Label.new()
	score_lbl.add_theme_font_size_override("font_size", 14)
	score_lbl.text = "Score 0"
	top.add_child(score_lbl)
	weapon_lbl = Label.new()
	weapon_lbl.add_theme_font_size_override("font_size", 14)
	weapon_lbl.text = "Fists"
	top.add_child(weapon_lbl)
	quest_lbl = Label.new()
	quest_lbl.add_theme_font_size_override("font_size", 14)
	quest_lbl.text = ""
	top.add_child(quest_lbl)

	# control buttons
	_btn_left = _make_button("◀", 42)
	_btn_left.position = Vector2(14, _vp().y - 66)
	_btn_left.pressed.connect(func(): Game.rotate(-1))
	hud.add_child(_btn_left)

	_btn_right = _make_button("▶", 42)
	_btn_right.position = Vector2(_vp().x - 66, _vp().y - 66)
	_btn_right.pressed.connect(func(): Game.rotate(1))
	hud.add_child(_btn_right)

	_btn_pause = _make_button("❚❚", 42)
	_btn_pause.position = Vector2((_vp().x - 42) / 2, _vp().y - 66)
	_btn_pause.pressed.connect(_toggle_pause)
	hud.add_child(_btn_pause)


func _make_button(text: String, w: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, w)
	b.add_theme_font_size_override("font_size", 20)
	return b


func _refresh_hud() -> void:
	if score_lbl == null:
		return
	score_lbl.text = "Score %d" % Game.score()
	weapon_lbl.text = _weapon_name()
	var parts: Array[String] = []
	for q in Game.quests.active:
		parts.append("%s x%d/%d" % [_q_label(q), int(q["progress"]), int(q["qty"])])
	quest_lbl.text = " | ".join(parts)


func _weapon_name() -> String:
	match Game.equipped_weapon:
		"none":
			return "Fists"
		"sword":
			return "Sword"
		"spear":
			return "Spear"
		"axe":
			return "Axe"
		"hammer":
			return "Hammer"
		"ultimate_sword":
			return "✦ Crystal Sword"
	return Game.equipped_weapon


func _toast(text: String, icon: String) -> void:
	toast.text = text
	toast.modulate.a = 1.0
	if toast_tween != null and toast_tween.is_valid():
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(1.8)
	toast_tween.tween_property(toast, "modulate:a", 0.0, 0.5)
	if ResourceLoader.exists(icon):
		var t: Texture2D = load(icon)
		# float the icon next to the toast
		var pic: TextureRect = TextureRect.new()
		pic.texture = t
		pic.custom_minimum_size = Vector2(34, 34)
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.size = Vector2(34, 34)
		pic.position = Vector2(10, toast.position.y - 8)
		pic.modulate.a = 1.0
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(pic)
		var tw: Tween = create_tween()
		tw.parallel().tween_property(pic, "position:y", pic.position.y - 26, 1.2)
		tw.parallel().tween_property(pic, "modulate:a", 0.0, 1.2)
		tw.chain().tween_callback(pic.queue_free)


## Chest reveal: the single loot item pops in with a spin/float.
func _chest_reveal(item: String, qty: int) -> void:
	var icon: String = _icon_for(item)
	if not ResourceLoader.exists(icon):
		_toast("Chest: %s x%d" % [item, qty], _icon_for(item))
		return
	var c := CanvasLayer.new()
	c.layer = 50
	add_child(c)
	var pic := TextureRect.new()
	pic.texture = load(icon)
	pic.size = Vector2(84, 84)
	pic.position = _vp() * 0.5 - Vector2(42, 42)
	c.add_child(pic)
	var lbl := Label.new()
	lbl.text = "Found: %s x%d" % [_item_name(item), qty]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_outline_color", Color(0.96, 0.94, 0.88))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.position = _vp() * Vector2(0.5, 0.68)
	lbl.size = Vector2(300, 24)
	lbl.offset_left = -150
	c.add_child(lbl)
	pic.pivot_offset = Vector2(42, 42)
	pic.scale = Vector2(0.2, 0.2)
	pic.modulate.a = 0.0
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(pic, "scale", Vector2(1.0, 1.0), 0.6)
	tw.parallel().tween_property(pic, "rotation", -14.0, 0.6)
	tw.parallel().tween_property(pic, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(lbl, "modulate:a", 1.0, 0.25)
	lbl.modulate.a = 0.0
	tw.tween_interval(1.0)
	tw.tween_property(pic, "modulate:a", 0.0, 0.4)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.tween_callback(c.queue_free)


func _icon_for(item: String) -> String:
	match item:
		"wood":
			return "res://art/sprites/icn_wood.png"
		"rare_ore":
			return "res://art/sprites/icn_ore.png"
		"rare_stone":
			return "res://art/sprites/icn_stone.png"
		"darkness_crystal":
			return "res://art/sprites/icn_crystal.png"
		"leather_armor", "steel_armor":
			return "res://art/sprites/icn_armor_steel.png"
		"ultimate_armor":
			return "res://art/sprites/icn_armor_ultimate.png"
		"sword":
			return "res://art/sprites/icn_sword.png"
		"spear":
			return "res://art/sprites/icn_spear.png"
		"axe":
			return "res://art/sprites/icn_axe.png"
		"hammer":
			return "res://art/sprites/icn_hammer.png"
		"ultimate_sword":
			return "res://art/sprites/icn_ultimate_sword.png"
		_:
			return ""


func _item_name(item: String) -> String:
	match item:
		"wood":
			return "Wood"
		"rare_ore":
			return "Rare Ore"
		"rare_stone":
			return "Rare Stone"
		"darkness_crystal":
			return "Darkness Crystal"
		"leather_armor":
			return "Leather Armor"
		"steel_armor":
			return "Steel Armor"
		"ultimate_armor":
			return "✦ Ultimate Armor"
		"sword":
			return "Sword"
		"spear":
			return "Spear"
		"axe":
			return "Axe"
		"hammer":
			return "Hammer"
		"ultimate_sword":
			return "✦ Crystal Sword"
	return item


# ================================================================ pause

func _toggle_pause() -> void:
	if Game.paused:
		Game.set_paused(false, "user")
	else:
		Game.set_paused(true, "user")


func _on_pause_requested(p: bool) -> void:
	if pause_menu == null:
		return
	pause_menu.visible = p
	if p:
		refresh_pause_pages()


func _build_pause_menu() -> void:
	pause_menu = CanvasLayer.new()
	pause_menu.name = "PauseMenu"
	pause_menu.layer = 40
	pause_menu.visible = false
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_menu)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.06, 0.42)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(bg)

	var title := Label.new()
	title.text = "— XenoHeart —"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	title.position = Vector2(0, 12)
	title.size = Vector2(_vp().x, 34)
	pause_menu.add_child(title)

	# 4 buttons "around the character" (screen edges)
	var btns := {
		"inventory": _corner_button("Inventory", Vector2(12, 44)),
		"crafting": _corner_button("Crafting", Vector2(_vp().x - 104, 44)),
		"equipment": _corner_button("Equipment", Vector2(12, _vp().y - 74)),
		"sidequests": _corner_button("Sidequests", Vector2(_vp().x - 104, _vp().y - 74)),
	}
	for key in btns:
		btns[key].pressed.connect(_open_page.bind(key))

	# center: the character + resume hint
	var pc := TextureRect.new()
	pc.texture = load("res://art/sprites/spr_player.png")
	pc.size = Vector2(90, 90)
	pc.position = _vp() * 0.5 - Vector2(45, 26)
	pause_menu.add_child(pc)
	var hint := Label.new()
	hint.text = "paused — game saved"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8, 0.8))
	hint.position = _vp() * Vector2(0.5, 0.5) + Vector2(-120, 60)
	hint.size = Vector2(240, 18)
	pause_menu.add_child(hint)

	# close
	var close := Button.new()
	close.text = "Resume ▶"
	close.position = Vector2((_vp().x - 120) / 2, _vp().y - 74)
	close.pressed.connect(_toggle_pause)
	pause_menu.add_child(close)

	# pages container (fills screen)
	var pages := Control.new()
	pages.name = "Pages"
	pages.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(pages)
	_build_pages(pages)


func _corner_button(text: String, pos: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.add_theme_font_size_override("font_size", 15)
	pause_menu.add_child(b)
	return b


var _pages_root: Control


func _open_page(page: String) -> void:
	if _pages_root == null:
		return
	for child in _pages_root.get_children():
		child.visible = false
	var target: Node = _pages_root.get_node_or_null(page)
	if target != null:
		target.visible = true


func _build_pages(pages: Control) -> void:
	_pages_root = pages
	_build_inventory_page(pages)
	_build_crafting_page(pages)
	_build_equipment_page(pages)
	_build_quests_page(pages)


func _page_header(p: Control, title: String) -> void:
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	lbl.position = Vector2(24, 56)
	lbl.size = Vector2(400, 26)
	p.add_child(lbl)
	var back := Button.new()
	back.text = "← back"
	back.position = Vector2(24, 88)
	back.pressed.connect(_open_page_root)
	p.add_child(back)


func _open_page_root() -> void:
	if _pages_root == null:
		return
	for child in _pages_root.get_children():
		child.visible = false


func _build_inventory_page(pages: Control) -> void:
	var p := Control.new()
	p.name = "inventory"
	p.visible = false
	pages.add_child(p)
	_page_header(p, "Inventory")
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 120)
	scroll.size = Vector2(620, 250)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	p.set_meta("content", content)


func _build_crafting_page(pages: Control) -> void:
	var p := Control.new()
	p.name = "crafting"
	p.visible = false
	pages.add_child(p)
	_page_header(p, "Crafting — wood, ore & crystals become gear")
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 120)
	scroll.size = Vector2(620, 250)
	p.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	p.set_meta("content", content)


func _build_equipment_page(pages: Control) -> void:
	var p := Control.new()
	p.name = "equipment"
	p.visible = false
	pages.add_child(p)
	_page_header(p, "Equipment")
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 120)
	scroll.size = Vector2(620, 250)
	p.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	p.set_meta("content", content)


func _build_quests_page(pages: Control) -> void:
	var p := Control.new()
	p.name = "sidequests"
	p.visible = false
	pages.add_child(p)
	_page_header(p, "Sidequests")
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 120)
	scroll.size = Vector2(620, 250)
	p.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	p.set_meta("content", content)


## Rebuild page contents (called when the pause menu opens / state changes).
func refresh_pause_pages() -> void:
	if _pages_root == null:
		return
	_rebuild_inventory()
	_rebuild_crafting()
	_rebuild_equipment()
	_rebuild_quests()


func _content_of(name: String) -> Control:
	var p: Node = _pages_root.get_node_or_null(name)
	if p == null:
		return null
	return p.get_meta("content")


func _rebuild_inventory() -> void:
	var c: Control = _content_of("inventory")
	if c == null:
		return
	for ch in c.get_children():
		ch.queue_free()
	var inv: Dictionary = Game.inventory.counts
	if inv.is_empty():
		var l := Label.new()
		l.text = "Empty. Chop trees (auto on bump) and find chests."
		c.add_child(l)
		return
	for item in inv:
		var row := HBoxContainer.new()
		var icon := TextureRect.new()
		var ipath: String = _icon_for(str(item))
		if ResourceLoader.exists(ipath):
			icon.texture = load(ipath)
		icon.custom_minimum_size = Vector2(28, 28)
		icon.stretch = true
		row.add_child(icon)
		var name_lbl := Label.new()
		name_lbl.text = "%s x%d" % [_item_name(str(item)), int(inv[item])]
		name_lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(name_lbl)
		c.add_child(row)


func _rebuild_crafting() -> void:
	var c: Control = _content_of("crafting")
	if c == null:
		return
	for ch in c.get_children():
		ch.queue_free()
	for item in Game.crafting.recipes():
		var row := HBoxContainer.new()
		var rec: Dictionary = Game.crafting.recipe_of(item)
		var costs: Array[String] = []
		for mat in rec:
			costs.append("%s x%d" % [_item_name(str(mat)), int(rec[mat])])
		var name_lbl := Label.new()
		name_lbl.text = "%s   —   needs: %s" % [_item_name(item), ", ".join(costs)]
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		var b := Button.new()
		var ok: bool = Game.crafting.can_craft(item)
		b.text = "Craft" if ok else "—"
		b.disabled = not ok
		b.custom_minimum_size = Vector2(64, 0)
		var bound_item: String = item
		b.pressed.connect(func():
			if Game.crafting.craft(bound_item):
				_toast("Crafted %s!" % _item_name(bound_item), _icon_for(bound_item))
				refresh_pause_pages())
		row.add_child(b)
		c.add_child(row)


func _rebuild_equipment() -> void:
	var c: Control = _content_of("equipment")
	if c == null:
		return
	for ch in c.get_children():
		ch.queue_free()
	var head := Label.new()
	head.text = "Weapons"
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	c.add_child(head)
	for item in Game.balance.get("weapons", {}).keys():
		if item == "none":
			continue
		if Game.inventory.count(item) <= 0:
			continue
		var row := HBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.text = _item_name(item) + ("   ★ equipped" if Game.equipped_weapon == item else "")
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		var b := Button.new()
		b.text = "Equip"
		b.disabled = Game.equipped_weapon == item
		b.custom_minimum_size = Vector2(64, 0)
		b.pressed.connect(func():
			Game.equip(str(item))
			_refresh_hud()
			refresh_pause_pages())
		row.add_child(b)
		c.add_child(row)
	var head2 := Label.new()
	head2.text = "Armor"
	head2.add_theme_font_size_override("font_size", 15)
	head2.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	c.add_child(head2)
	var armors: Dictionary = Game.balance.get("player", {}).get("armor_hp_bonus", {})
	for item in armors.keys():
		if item == "none":
			continue
		if Game.inventory.count(item) <= 0:
			continue
		var row2 := HBoxContainer.new()
		var name_lbl2 := Label.new()
		var bonus: int = int(armors[item])
		name_lbl2.text = "%s  (+%d max HP) %s" % [_item_name(item), bonus, "★ equipped" if Game.equipped_armor == item else ""]
		name_lbl2.add_theme_font_size_override("font_size", 13)
		name_lbl2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(name_lbl2)
		var b2 := Button.new()
		b2.text = "Equip"
		b2.disabled = Game.equipped_armor == item
		b2.custom_minimum_size = Vector2(64, 0)
		b2.pressed.connect(func():
			Game.equip_armor(str(item))
			_refresh_hud()
			refresh_pause_pages())
		row2.add_child(b2)
		c.add_child(row2)


func _rebuild_quests() -> void:
	var c: Control = _content_of("sidequests")
	if c == null:
		return
	for ch in c.get_children():
		ch.queue_free()
	var act := Game.quests.active
	if act.is_empty():
		var l := Label.new()
		l.text = "No active quests. Visit villagers on the path hexes of little huts."
		c.add_child(l)
	for q in act:
		var l := Label.new()
		var done: bool = int(q["progress"]) >= int(q["qty"])
		l.text = "• %s x%d  [%d/%d]  reward: %s %s" % [
			_q_label(q), int(q["qty"]), int(q["progress"]), int(q["qty"]),
			_reward_text(q), "✔ done — bump the villager to collect" if done else "",
		]
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color(0.75, 0.85, 0.6) if done else Color(1))
		c.add_child(l)
	var comp := Game.quests.completed
	if comp.size() > 0:
		var head := Label.new()
		head.text = "Completed (%d)" % comp.size()
		head.add_theme_font_size_override("font_size", 14)
		head.add_theme_color_override("font_color", Color(0.8, 0.78, 0.7))
		c.add_child(head)
		for q in comp.slice(-5):
			var l2 := Label.new()
			l2.text = "  ✔ %s x%d" % [_q_label(q), int(q["qty"])]
			l2.add_theme_font_size_override("font_size", 12)
			l2.add_theme_color_override("font_color", Color(0.6, 0.7, 0.55))
			c.add_child(l2)


func _reward_text(q: Dictionary) -> String:
	var parts: Array[String] = []
	for mat in q["reward"]:
		parts.append("%s x%d" % [_item_name(str(mat)), int(q["reward"][mat])])
	return ", ".join(parts)


# ================================================================ death

func _build_death_overlay() -> void:
	death_overlay = CanvasLayer.new()
	death_overlay.name = "DeathOverlay"
	death_overlay.layer = 60
	death_overlay.visible = false
	add_child(death_overlay)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.04, 0.72)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_overlay.add_child(bg)
	var lbl := Label.new()
	lbl.name = "DeadLabel"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85))
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_overlay.add_child(lbl)


# ================================================================ input

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_toggle_pause()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if Game.paused:
		return
	if event.is_action_pressed("rotate_left"):
		Game.rotate(-1)
	elif event.is_action_pressed("rotate_right"):
		Game.rotate(1)
	elif event.is_action_pressed("pause_toggle"):
		_toggle_pause()
