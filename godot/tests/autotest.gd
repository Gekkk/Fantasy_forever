extends Node
## Automated play-through used for testing (run with `-- --autotest`).
## A little bot plays the real-time combat through the real input actions:
## it walks up to critters, chains wand combos, casts skills, dashes out of
## red telegraphs, drinks potions, spends attribute/skill points and wears the best
## gear it finds. It plays the whole main
## quest (arenas, elite gremlins, both bosses), a side quest, a defeat, and
## the ending, saving screenshots along the way.

var main
var shots_dir := "user://shots"
var failures: Array = []
var stats := {"attacks": 0, "casts": 0, "dashes": 0, "items": 0, "downs": 0}
var _shot_flags := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(shots_dir)
	_run.call_deferred()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	await _frames(3)
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [shots_dir, name])
	print("SHOT ", name)


func shot_once(name: String) -> void:
	if not _shot_flags.has(name):
		_shot_flags[name] = true
		await shot(name)


func press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(1)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(1)


func check(cond: bool, what: String) -> void:
	if not cond:
		failures.append(what)
		print("FAIL: ", what)
	else:
		print("ok: ", what)


func q() -> int:
	return int(Game.state["quest"])


## Clicks through dialogs until control returns.
func drain_dialogs(max_sec := 30.0) -> void:
	var t := 0.0
	while t < max_sec:
		if main.ui.is_dialog_open():
			await press("confirm")
			await _wait(0.05)
			t += 0.05
		elif main.mode == main.Mode.SCRIPT:
			await _wait(0.1)
			t += 0.1
		else:
			return
	print("drain_dialogs timed out in mode ", main.mode)


func wait_mode(m: int, max_sec := 20.0) -> bool:
	var t := 0.0
	while main.mode != m and t < max_sec:
		if main.ui.is_dialog_open():
			await press("confirm")
		await _wait(0.1)
		t += 0.1
	return main.mode == m


func release_moves() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)


func steer(v: Vector3) -> void:
	release_moves()
	if v.length() < 0.05:
		return
	var d := v.normalized()
	if d.x < -0.1:
		Input.action_press("move_left", -d.x)
	elif d.x > 0.1:
		Input.action_press("move_right", d.x)
	if d.z < -0.1:
		Input.action_press("move_up", -d.z)
	elif d.z > 0.1:
		Input.action_press("move_down", d.z)


func teleport(pos: Vector3) -> void:
	release_moves()
	main.player.position = pos
	main.player.velocity = Vector3.ZERO
	main.follower.position = pos + Vector3(-0.8, 0, 0.8)
	main._snap_camera()
	await _wait(0.3)


func door(id: String) -> Vector3:
	return World.DOORS[id]


## Walks up to the tower's auto-door (it triggers when you step close).
func enter_tower() -> void:
	await teleport(door("tower_door") + Vector3(0, 0, 2.6))
	await teleport(door("tower_door") + Vector3(0, 0, 0.3))


func interact(id: String) -> void:
	main.interact(id)
	await _frames(2)
	await drain_dialogs()
	await wait_mode(main.Mode.EXPLORE, 15.0)


# ================================================================ combat bot
func _threats(p: Vector3) -> Array:
	var out: Array = []
	for c in main.world.get_children():
		if c is Hazard and not c.friendly and not c.is_queued_for_deletion():
			var h: Hazard = c
			if h.contains(p) or h.contains(p + Vector3(0.5, 0, 0)) or h.contains(p - Vector3(0.5, 0, 0)):
				out.append(h)
	return out


func _live_enemies() -> Array:
	return main.combat.enemies.filter(func(e): return is_instance_valid(e) and not e.dead)


func _nearest(p: Vector3, prefer: Callable) -> Enemy:
	var best: Enemy = null
	var bd := 1e9
	for e in _live_enemies():
		var d: float = p.distance_to(e.global_position)
		if prefer.is_valid() and prefer.call(e):
			d -= 100.0
		if d < bd:
			bd = d
			best = e
	return best


func _ready_skill(sid: String) -> bool:
	return Game.state["slots"].has(sid) and float(main.player.skill_cd.get(sid, 0.0)) <= 0.0 \
		and int(Game.state["mp"]) >= Rpg.skill_mp(sid)


func _cast(sid: String) -> void:
	stats["casts"] += 1
	stats["cast_" + sid] = int(stats.get("cast_" + sid, 0)) + 1
	await press("skill%d" % (Game.state["slots"].find(sid) + 1))


## Levels up like a player would: spend points, slot the best spells, wear the best gear.
func _spend_points() -> void:
	var s := Game.state
	var order := ["int", "vit", "int", "str", "vit", "agi", "luk"]
	var i := 0
	while int(s["attr_points"]) > 0:
		Rpg.spend_attr(order[i % order.size()])
		i += 1
	var wish := ["bolt", "heal", "thunder", "shield", "starfall", "iron_skin", "big_heart", "sparkle_edge", "combo_master",
		"frost", "flame", "crit", "mana_bloom", "quick_step", "blink", "swift", "deep_pockets", "fire_heart", "frost_touch",
		"lucky_star", "cozy_regen", "mochi_power", "star_trail"]
	var progress := true
	while int(s["skill_points"]) > 0 and progress:
		progress = false
		for id in wish:
			if Rpg.raise(id):
				stats["skill_ups"] = int(stats.get("skill_ups", 0)) + 1
				progress = true
				break
	var slot_pref := ["heal", "bolt", "thunder", "starfall", "shield", "frost", "flame"]
	var k := 0
	for sid in slot_pref:
		if k < 4 and Rpg.rank(sid) > 0:
			Rpg.set_slot(k, sid)
			k += 1
	var equipped := 0
	for slot in Rpg.SLOTS:
		var best := -1
		var best_score := Rpg.score(s["equip"][slot])
		var bag: Array = s["bag"]
		for j in bag.size():
			if bag[j]["slot"] == slot and Rpg.score(bag[j]) > best_score:
				best = j
				best_score = Rpg.score(bag[j])
		if best >= 0:
			Rpg.equip_from_bag(best)
			equipped += 1
	if equipped > 0:
		stats["equips"] = int(stats.get("equips", 0)) + equipped
		main.player.rebuild_model()


## One decision of the bot. Uses the same actions a player would press.
func _bot_tick(prefer: Callable) -> void:
	var p: Player = main.player
	var s := Game.state
	var pos := p.global_position
	var hp_ratio := float(s["hp"]) / float(s["max_hp"])
	# 1) Survive.
	if hp_ratio < 0.65 and p.barrier <= 0 and _ready_skill("shield"):
		await _cast("shield")
		return
	if hp_ratio < 0.4:
		if _ready_skill("heal"):
			await _cast("heal")
			return
		if hp_ratio < 0.3 and Game.item_count("muffin") > 0:
			stats["items"] += 1
			await press("use_muffin")
			return
	if int(s["mp"]) < 5 and Game.item_count("tea") > 0 and randf() < 0.05:
		stats["items"] += 1
		await press("use_tea")
	# 2) Dodge telegraphs: dash out of anything glowing under us.
	var threats := _threats(pos)
	if not threats.is_empty():
		var h: Hazard = threats[0]
		var away := pos - h.global_position
		away.y = 0
		if h.shape == "line" or h.shape == "sweep":
			away = h.dir.cross(Vector3.UP) * (1.0 if away.dot(h.dir.cross(Vector3.UP)) >= 0.0 else -1.0)
		if away.length() < 0.1:
			away = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
		steer(away)
		if p.dash_ready() <= 0.0:
			stats["dashes"] += 1
			await press("dash")
		else:
			await _frames(2)
		return
	# 3) Fight the nearest critter.
	var e := _nearest(pos, prefer)
	if e == null:
		release_moves()
		await _frames(2)
		return
	var to := e.global_position - pos
	to.y = 0
	var dist := to.length()
	var near := 0
	for o in _live_enemies():
		if pos.distance_to(o.global_position) < 6.0:
			near += 1
	if near >= 2 and _ready_skill("thunder"):
		await _cast("thunder")
		return
	if near >= 2 and _ready_skill("starfall"):
		await _cast("starfall")
		return
	if dist < 3.0 and _ready_skill("frost") and (e.weak == "ice" or near >= 2 or randf() < 0.3):
		await _cast("frost")
		return
	if dist < 7.0 and _ready_skill("flame") and (e.weak == "fire" or randf() < 0.25):
		p.face(to)
		steer(to)
		await _cast("flame")
		return
	if dist > 2.5 and dist < 11.0 and _ready_skill("bolt") and randf() < 0.6:
		p.face(to)
		steer(to)
		await _cast("bolt")
		return
	var reach := 1.5 + e.hit_radius
	if dist > reach:
		steer(to)
		await _frames(2)
	else:
		release_moves()
		p.face(to)
		stats["attacks"] += 1
		await press("attack")


## Plays the real-time fight until `done` returns true. Returns false on timeout.
func fight_bot(done: Callable, max_sec: float, label: String, prefer := Callable()) -> bool:
	var start := Time.get_ticks_msec()
	var shot_at := 3.0
	while (Time.get_ticks_msec() - start) / 1000.0 < max_sec:
		if done.call():
			release_moves()
			return true
		if int(Game.state["attr_points"]) + int(Game.state["skill_points"]) > 0:
			_spend_points()
		if main.ui.is_dialog_open():
			release_moves()
			await press("confirm")
			await _wait(0.05)
			continue
		if main.mode != main.Mode.EXPLORE:
			release_moves()
			await _wait(0.1)
			continue
		await _bot_tick(prefer)
		var el := (Time.get_ticks_msec() - start) / 1000.0
		if el > shot_at and label != "":
			shot_at = 1e9
			await shot(label)
	release_moves()
	print("fight_bot timed out: ", label, " quest=", q(), " enemies=", _live_enemies().size())
	return done.call()


func controls_ok(label: String) -> void:
	await drain_dialogs()
	await wait_mode(main.Mode.EXPLORE, 15.0)
	check(main.mode == main.Mode.EXPLORE, label + ": back to exploring (mode %d)" % main.mode)
	await _wait(0.2)
	var before: Vector3 = main.player.position
	var dir := "move_left" if before.x > 0 else "move_right"
	Input.action_press(dir)
	await _wait(0.4)
	Input.action_release(dir)
	await _wait(0.1)
	check(main.player.position.distance_to(before) > 0.3, label + ": player can move")


## A boss/arena fight; if the hero gets knocked out, heal up and retry.
func boss_fight(start: Callable, done: Callable, label: String, tries := 3) -> void:
	for attempt in tries:
		var downs_before: int = stats["downs"]
		await start.call()
		var ok := await fight_bot(func(): return done.call() or main.world.map_id == "home_in", 240.0, label + ("" if attempt == 0 else "_retry%d" % attempt))
		await drain_dialogs()
		if done.call():
			print(label, " won on attempt ", attempt + 1, " at level ", Game.state["level"], " hp ", Game.state["hp"], "/", Game.state["max_hp"])
			return
		if main.world.map_id == "home_in":
			stats["downs"] = downs_before + 1
			print(label, ": knocked out on attempt ", attempt + 1, " (level ", Game.state["level"], ")")
			await wait_mode(main.Mode.EXPLORE, 15.0)
		elif not ok:
			print(label, ": timeout")
		# Level up a bit, like a player would by roaming around.
		Game.add_xp(Game.xp_to_next())
		Game.add_item("muffin", 2)
		await drain_dialogs()
	check(done.call(), label + " beaten")


# ==================================================================== script
func _run() -> void:
	seed(12345)
	await _wait(1.5)
	await shot("01_title")
	main.title._set_style("fairy")
	main.title._set_robe(1)
	main.title._set_hair(1)
	main.title._name.text = "Luna"
	if main.title._continue.visible:
		main.title._on_start() # first tap only arms "start over"
	main.title._on_start()
	await _wait(1.5)
	await drain_dialogs()
	check(main.mode == main.Mode.EXPLORE, "exploring after intro")
	check(main.world.map_id == "home_in", "new game starts at home")

	# Leave home.
	await teleport(Vector3(0, 0, 3.4))
	await teleport(Vector3(0, 0, 5.2))
	await _wait(1.2)
	await drain_dialogs()
	check(main.world.map_id == "city", "left home into the city")
	await shot("02_city")

	# Chapter 1: latte + Flame Petal.
	await teleport(door("cafe") + Vector3(0, 0, 1.3))
	await shot("02b_main_street")
	await interact("cafe")
	await teleport(Vector3(-0.6, 0, -1.4))
	await interact("bree")
	check(q() == 1, "quest 1 after cafe")
	check(Game.state["spells"].has("flame"), "learned flame")
	await teleport(Vector3(0, 0, 4.9))
	await _wait(1.2)
	await drain_dialogs()

	# Library: Heal Glow (and the library shard).
	await teleport(door("library") + Vector3(0, 0, 1.4))
	await shot("02c_north_ave")
	await interact("library")
	await teleport(Vector3(0, 0, -1.6))
	await interact("hoot")
	check(Game.state["spells"].has("heal"), "learned heal")
	await teleport(Vector3(5.0, 0, -3.0))
	await teleport(Vector3(6.4, 0, -4.2))
	await drain_dialogs(8.0)
	await teleport(Vector3(0, 0, 5.9))
	await _wait(1.2)
	await drain_dialogs()

	# Chapter 2: Merlo teaches Frost, then cheer up 5 park critters in real time.
	await teleport(Vector3(-12, 0, 7.8))
	await interact("merlo")
	check(Game.state["spells"].has("frost"), "learned frost")
	check(q() == 2, "quest 2 after Merlo")
	var e := _nearest(main.player.position, func(x): return x.id in Game.PARK_POOL)
	if e:
		await teleport(e.global_position + Vector3(0, 0, 3.0))
	await fight_bot(func(): return q() >= 3, 200.0, "03_park_fight", func(x): return x.global_position.z > 3.0)
	await controls_ok("park")
	check(q() == 3, "park practice done (quest %d, calmed %d)" % [q(), Game.state["park_calmed"]])

	# Side quest: Nana's yarn.
	await teleport(Vector3(-30, 0, 17.4))
	await interact("thistle")
	check(Game.side_state("yarn") == "active", "yarn side quest started")
	for spot in main.world.YARN_SPOTS:
		await teleport(spot + Vector3(2.0, 0, 0))
		await teleport(spot)
		await drain_dialogs(5.0)
		await fight_bot(func(): return not main.combat.any_aggro_near(main.player.position, 7.0), 30.0, "")
	check(Game.side_state("yarn") == "ready", "all yarn found (%d)" % Game.side_count("yarn"))
	await teleport(Vector3(-30, 0, 17.4))
	await interact("thistle")
	check(Game.side_state("yarn") == "done", "yarn side quest turned in")

	# City shards.
	for pos in [World.SHARD_S1, Vector3(3.4, 0, 26.6)]:
		await teleport(pos + Vector3(1.5, 0, 0))
		await teleport(pos)
		await drain_dialogs(5.0)

	# Chapter 3: no badge -> badge arena (two waves).
	await enter_tower()
	await _wait(0.4)
	await drain_dialogs()
	check(q() == 4, "quest 4 after tower door")
	Game.full_heal()
	await boss_fight(func():
		await teleport(Vector3(-15, 0, 12))
		await teleport(Vector3(-18, 0, 12))
		await _wait(0.2)
		await drain_dialogs(), func(): return q() >= 5, "04_badge_arena")
	await controls_ok("badge arena")
	check(not main.combat.arena_active, "arena barrier removed")

	# Chapter 4: into the tower, Dot, elite gremlins.
	await enter_tower()
	await _wait(1.5)
	await drain_dialogs()
	check(main.world.map_id == "tower", "entered tower")
	await teleport(Vector3(-5, 0, 6.6))
	await interact("dot")
	check(q() == 6, "quest 6 after Dot")
	await shot("05_tower")
	Game.full_heal()
	var g := _nearest(main.player.position, func(x): return x.uid != "")
	if g:
		await teleport(g.global_position + Vector3(0, 0, 3.5))
	await fight_bot(func(): return q() >= 7, 240.0, "06_gremlins", func(x): return x.uid != "")
	await drain_dialogs()
	check(q() == 7, "gremlins cheered up (%d/3)" % Game.gremlins_done())

	# Tower shards -> Starfall.
	for pos in [Vector3(11.3, 0, -4.2), Vector3(-11.3, 0, 12.3)]:
		await teleport(pos + Vector3(-1.5, 0, 0))
		await teleport(pos)
		await drain_dialogs(8.0)
	check(Game.state["spells"].has("starfall"), "learned starfall")

	# Shopping at Madame Velour's boutique on North Avenue.
	Game.add_coins(400)
	await main.load_map("city", door("boutique") + Vector3(0, 0, 1.4))
	await drain_dialogs()
	await interact("boutique")
	check(main.world.map_id == "boutique_in", "entered the boutique")
	await teleport(Vector3(-0.8, 0, -1.9))
	var bag_before: int = Game.state["bag"].size()
	var coins_before: int = Game.state["coins"]
	main.interact("velour")
	var picks := 0
	var t_shop := 0.0
	while t_shop < 30.0 and (main.mode != main.Mode.EXPLORE or main.ui.is_dialog_open()):
		if main.ui.is_dialog_open():
			if main.ui._typing:
				main.ui._finish_typing()
			elif not main.ui._options.is_empty() and picks < 2:
				if picks == 0:
					await shot("11a_shop")
				main.ui._choose(0) # the first item, then "Buy it!"
				picks += 1
			else:
				await press("confirm")
		await _wait(0.1)
		t_shop += 0.1
	check(Game.state["bag"].size() == bag_before + 1, "bought an item at the boutique")
	check(int(Game.state["coins"]) < coins_before, "paid for it")
	_spend_points()
	await drain_dialogs()
	await teleport(Vector3(0, 0, 3.9))
	await _wait(1.2)
	await drain_dialogs()

	# Chapter 5: the Printer King.
	Game.full_heal()
	await boss_fight(func():
		if main.world.map_id != "tower":
			await main.load_map("tower", Vector3(0, 0, 5))
		await teleport(Vector3(0, 0, 3))
		await teleport(Vector3(0, 0, -3.5))
		await _wait(0.2)
		await drain_dialogs(), func(): return q() >= 8, "07_printer_king")
	await controls_ok("printer king")

	# A defeat on purpose: you must wake up at home, healed, able to move.
	# Leash the attacker to wherever we are standing so it can always reach us.
	# (Removed quietly: cheering them up would give XP and loot.)
	for old in _live_enemies():
		main.combat.enemies.erase(old)
		old.queue_free()
	var here: Vector3 = main.player.position
	main.combat.spawn_enemy("email", here + Vector3(2, 0, 0), Rect2(here.x - 6, here.z - 6, 12, 12), "", true)
	Game.state["hp"] = 1
	var t0 := Time.get_ticks_msec()
	while main.world.map_id != "home_in" and Time.get_ticks_msec() - t0 < 30000:
		Game.state["hp"] = mini(int(Game.state["hp"]), 1)
		var v := _nearest(main.player.position, Callable())
		if v == null and main.mode == main.Mode.EXPLORE:
			# Mochi may have cheered the last one up: bring in another.
			var pp: Vector3 = main.player.position
			main.combat.spawn_enemy("email", pp + Vector3(2, 0, 0), Rect2(pp.x - 6, pp.z - 6, 12, 12), "", true)
			await _frames(2)
			continue
		if v and main.player.position.distance_to(v.global_position) > 1.2 and main.mode == main.Mode.EXPLORE:
			steer(v.global_position - main.player.position)
		await _frames(2)
	release_moves()
	await drain_dialogs()
	check(main.world.map_id == "home_in", "woke up at home after defeat")
	check(Game.state["hp"] == Game.state["max_hp"], "healed after defeat")
	await controls_ok("after defeat")

	# Chapter 6: the rooftop.
	await main.load_map("tower", Vector3(0, 0, -5))
	await teleport(Vector3(0, 0, -7.4))
	await teleport(Vector3(0, 0, -8.8))
	await _wait(1.5)
	await drain_dialogs()
	check(main.world.map_id == "roof", "reached rooftop")
	await shot("08_rooftop")
	Game.full_heal()
	await boss_fight(func():
		if main.world.map_id != "roof":
			await main.load_map("roof", Vector3(0, 0, 6.8))
			await drain_dialogs()
		await teleport(Vector3(0, 0, -1.0))
		main.interact("boss")
		await _wait(0.8)
		await press("confirm")
		await _wait(0.2)
		await press("confirm")
		await drain_dialogs(), func(): return q() >= 9, "09_monday")
	# Ending.
	var t := 0.0
	while t < 60.0:
		if main.ui.is_dialog_open():
			await press("confirm")
		var ending := false
		for c in main.ui.get_children():
			if c is Control and c.get_child_count() > 2 and c.get_child(2) is PanelContainer and c != main.ui.hud and c != main.ui.dialog:
				ending = true
		if ending:
			await _wait(1.0)
			await shot("10_ending")
			await press("confirm")
			break
		await _wait(0.1)
		t += 0.1
	await drain_dialogs()
	check(q() == 9, "boss beaten, quest 9 (%d)" % q())
	await controls_ok("after ending")

	# Quest log / skills menu.
	main.open_menu()
	await _wait(0.5)
	await shot("11_menu_quests")
	main.menu._hero()
	await _wait(0.3)
	await shot("11b_menu_hero")
	main.menu._gear()
	await _wait(0.3)
	await shot("11c_menu_gear")
	main.menu._magic()
	await _wait(0.3)
	await shot("12_menu_skills")
	main.close_menu()

	var worn := []
	for slot in Rpg.SLOTS:
		var it: Dictionary = Game.state["equip"][slot]
		if not it.is_empty():
			worn.append("%s [%s]" % [it["name"], Rpg.RARITY[int(it["rarity"])]["name"]])
	print("STATS ", stats, " level ", Game.state["level"], " attr ", Game.state["attr"], " skills ", Game.state["skills"])
	print("GEAR ", worn, " bag ", Game.state["bag"].size(), " hp ", Game.state["max_hp"], " atk ", Game.state["atk"], " matk ", Rpg.d("matk"), " def ", Rpg.d("def"))
	if failures.is_empty():
		print("AUTOTEST PASS")
	else:
		print("AUTOTEST FAIL (%d): %s" % [failures.size(), ", ".join(failures)])
	get_tree().quit(0 if failures.is_empty() else 1)
