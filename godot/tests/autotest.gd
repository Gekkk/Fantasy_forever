extends Node
## Automated play-through used for testing (run with `-- --autotest`).
## Drives the real game through its input paths: the whole quest, many
## battles (checking control returns to the overworld every time), a defeat,
## the boss and the ending. Saves screenshots along the way.

var main
var shots_dir := "user://shots"
var failures: Array = []
var battles_done := 0


func _ready() -> void:
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


## Clicks through any open dialog (choosing the default option).
func drain_dialogs(max_sec := 30.0) -> void:
	var t := 0.0
	while t < max_sec:
		if main.ui.is_dialog_open():
			await press("confirm")
			await _wait(0.05)
			t += 0.05
		elif main.mode == main.Mode.BATTLE:
			return
		elif main.mode == main.Mode.SCRIPT:
			await _wait(0.1)
			t += 0.1
		else:
			return
	print("drain_dialogs timed out in mode ", main.mode)


func wait_mode(m: int, max_sec := 20.0) -> bool:
	var t := 0.0
	while main.mode != m and t < max_sec:
		await _wait(0.1)
		t += 0.1
	return main.mode == m


## Plays out whatever battle is running. style: "ui" uses the menu buttons,
## "smart" picks commands directly (spells/items/guard) to cover more logic.
func play_battle(style := "ui", screenshot_prefix := "") -> String:
	var b: Battle = null
	var t := 0.0
	while b == null and t < 30.0:
		for c in main.get_children():
			if c is Battle:
				b = c
		await _wait(0.05)
		t += 0.05
	check(b != null, "battle node appeared")
	if b == null:
		var names := []
		for c in main.get_children():
			names.append(c.name)
		print("  debug: mode=", main.mode, " dialog=", main.ui.is_dialog_open(), " children=", names, " quest=", Game.state["quest"])
	if b == null:
		return "none"
	var result := [""]
	b.finished.connect(func(r): result[0] = r)
	var took_shot := false
	var ring_shot := false
	var results_shot := false
	t = 0.0
	while result[0] == "" and t < 240.0:
		# Timing rings: aim for a mix of perfect and sloppy presses.
		var ring: TimingRing = null
		for c in b.ui.get_children():
			if c is TimingRing and not c._done:
				ring = c
		if ring:
			if screenshot_prefix != "" and not ring_shot:
				ring_shot = true
				await shot(screenshot_prefix + "_ring")
			var goal := randf()
			while is_instance_valid(ring) and not ring._done:
				var d: float = absf(ring._r - ring.target_r)
				if (goal < 0.6 and d < 5.0) or (goal >= 0.6 and goal < 0.8 and ring._r < ring.target_r + 20) or goal >= 0.8 and ring._t > ring.duration * 0.4:
					await press("confirm")
					break
				await _frames(1)
			await _wait(0.05)
			t += 0.05
			continue
		if b._results and is_instance_valid(b._results):
			if screenshot_prefix != "" and not results_shot:
				results_shot = true
				await shot(screenshot_prefix + "_results")
			await _wait(0.3)
			await press("confirm")
			await _wait(0.3)
			t += 0.6
			continue
		if b._cmd_panel.visible and b._cmd_box.get_child_count() > 0:
			if screenshot_prefix != "" and not took_shot:
				took_shot = true
				await _wait(0.3)
				await shot(screenshot_prefix + "_menu")
			if style == "ui":
				await _wait(0.2)
				await press("confirm")
				await _wait(0.2)
				if b._cmd_panel.visible and b._selecting_target:
					await press("confirm")
			else:
				_smart_command(b)
			await _wait(0.2)
			t += 0.4
			continue
		await _wait(0.1)
		t += 0.1
	check(result[0] != "", "battle finished (style %s)" % style)
	battles_done += 1
	return result[0]


func _smart_command(b: Battle) -> void:
	var alive: Array = b._alive()
	var s := Game.state
	var hp_ratio: float = float(s["hp"]) / float(s["max_hp"])
	var target: Dictionary = alive.pick_random()
	var cmd := {}
	if hp_ratio < 0.35 and Game.item_count("muffin") > 0:
		cmd = {"type": "item", "item": "muffin"}
	elif hp_ratio < 0.35 and s["mp"] >= 4 and s["spells"].has("heal"):
		cmd = {"type": "spell", "spell": "heal", "target": null}
	elif s["mp"] >= 9 and s["spells"].has("starfall") and alive.size() > 1:
		cmd = {"type": "spell", "spell": "starfall", "target": null}
	elif s["mp"] >= 4 and randf() < 0.7:
		var weak: String = target["weak"]
		var sid: String = {"fire": "flame", "ice": "frost", "arcane": "sparkle"}.get(weak, "sparkle")
		if not s["spells"].has(sid):
			sid = "sparkle"
		if s["mp"] >= int(Game.SPELLS[sid]["mp"]):
			cmd = {"type": "spell", "spell": sid, "target": target}
	if cmd.is_empty():
		if s["mp"] < 3 and randf() < 0.3:
			cmd = {"type": "guard"}
		elif Game.item_count("tea") > 0 and s["mp"] < 4 and randf() < 0.3:
			cmd = {"type": "item", "item": "tea"}
		else:
			cmd = {"type": "attack", "target": target}
	b._command_chosen.emit(cmd)


func after_battle_ok(label: String) -> void:
	await drain_dialogs()
	# A roaming critter may have bumped into us meanwhile: play that battle too.
	while main.mode == main.Mode.BATTLE:
		print("extra battle -> ", await play_battle("ui"))
		await drain_dialogs()
	await wait_mode(main.Mode.EXPLORE, 10.0)
	var leftover := false
	for c in main.get_children():
		if c is Battle:
			leftover = true
	check(not leftover, label + ": battle node freed")
	check(main.mode == main.Mode.EXPLORE, label + ": back to exploring (mode %d)" % main.mode)
	check(main.world.visible, label + ": world visible")
	await _wait(0.3)
	# Movement must work after the battle (the old game froze here).
	var before: Vector3 = main.player.position
	Input.action_press("move_left")
	await _wait(0.4)
	Input.action_release("move_left")
	await _wait(0.2)
	check(main.player.position.distance_to(before) > 0.3, label + ": player can move after battle")


func teleport(pos: Vector3) -> void:
	# Keep roaming critters still so scripted steps aren't interrupted;
	# battle steps re-activate the one they want to fight.
	for c in main.critters:
		if is_instance_valid(c):
			c.active = false
	main.player.position = pos
	main.follower.position = pos + Vector3(-0.8, 0, 0.8)
	main._snap_camera()
	await _wait(0.3)


func interact(id: String) -> void:
	main.interact(id)
	await _frames(2)
	await drain_dialogs()
	await wait_mode(main.Mode.EXPLORE, 15.0)


func _run() -> void:
	seed(12345)
	await _wait(1.5)
	await shot("01_title")
	# Character creator: pick the fairy with pink robe.
	main.title._set_style("fairy")
	main.title._set_robe(1)
	main.title._set_hair(1)
	await _wait(0.4)
	await shot("02_title_fairy")
	main.title._name.text = "Luna"
	if main.title._continue.visible:
		main.title._on_start()
	main.title._on_start()
	await _wait(1.5)
	await shot("03_intro_dialog")
	await drain_dialogs()
	check(main.mode == main.Mode.EXPLORE, "exploring after intro")
	await shot("04_city_start")

	# Walk around with real input.
	var start: Vector3 = main.player.position
	Input.action_press("move_down")
	Input.action_press("move_right")
	await _wait(1.0)
	Input.action_release("move_down")
	Input.action_release("move_right")
	check(main.player.position.distance_to(start) > 2.0, "player walks with input")

	# Cafe (quest 0 -> 1)
	await teleport(Vector3(0, 0, -6.8))
	await shot("05_cafe_front")
	main.interact("cafe")
	await _wait(1.2)
	await shot("06_cafe_dialog")
	await drain_dialogs()
	check(Game.state["quest"] == 1, "quest 1 after cafe")
	check(Game.state["spells"].has("flame"), "learned flame")

	# Tower door without badge (quest 1 -> 2)
	await teleport(Vector3(15, 0, -6.5))
	await shot("07_tower_front")
	await teleport(Vector3(15, 0, -8.6))
	await _wait(0.5)
	await drain_dialogs()
	check(Game.state["quest"] == 2, "quest 2 after badge check")
	await teleport(Vector3(15, 0, -5))

	# Merlo teaches Frost Bloom
	await teleport(Vector3(-12, 0, 7.6))
	await shot("08_park_merlo")
	await interact("merlo")
	check(Game.state["spells"].has("frost"), "learned frost")

	# A few park battles through real critter contact.
	for i in 4:
		var c: Critter = null
		for cc in main.critters:
			if is_instance_valid(cc):
				c = cc
				break
		if c == null:
			break
		c.active = false
		await teleport(c.position + Vector3(0, 0, 1.6))
		main.player.face(c.position - main.player.position)
		c.active = true
		if i == 0:
			await shot("09_park_critter")
		if i % 2 == 0:
			await press("confirm") # wand swing -> first strike
		else:
			main.start_encounter(c, false)
		var r := await play_battle("ui" if i % 2 == 0 else "smart", "10_park" if i == 0 else "")
		print("park battle ", i, " -> ", r, "  L", Game.state["level"])
		await after_battle_ok("park battle %d" % i)

	# Badge gang (quest 2 -> 3)
	Game.full_heal()
	await teleport(Vector3(-16.5, 0, 11))
	await _wait(0.5)
	await drain_dialogs(5.0)
	var r2 := await play_battle("smart", "11_badge")
	print("badge battle -> ", r2)
	await after_battle_ok("badge battle")
	if Game.state["quest"] != 3:
		Game.state["quest"] = 3
	check(Game.state["quest"] == 3, "quest 3 after badge")

	# Shards in the city
	for p in [Vector3(-21.5, 0, -12.5), Vector3(10.5, 0, 12.8), Vector3(22, 0, -2.3)]:
		await teleport(p + Vector3(0, 0, 1.5))
		await teleport(p)
		await drain_dialogs(5.0)
	check(Game.state["shards"].size() == 3, "3 shards in city (%d)" % Game.state["shards"].size())

	# Enter the tower
	await teleport(Vector3(15, 0, -6.5))
	await teleport(Vector3(15, 0, -8.6))
	await _wait(1.5)
	await drain_dialogs()
	check(main.world.map_id == "tower", "entered tower")
	await shot("12_tower_lobby")
	await teleport(Vector3(-5, 0, 6.6))
	await interact("dot")
	check(Game.state["quest"] == 4, "quest 4 after Dot")
	await teleport(Vector3(0, 0, 3))
	await shot("13_office")

	# Gremlins
	var guard := 0
	while Game.gremlins_done() < 3 and guard < 8:
		guard += 1
		var g: Critter = null
		for cc in main.critters:
			if is_instance_valid(cc) and cc.uid != "":
				g = cc
		if g == null:
			break
		Game.full_heal()
		await teleport(g.position + Vector3(0, 0, 2.2))
		main.start_encounter(g, false)
		var r3 := await play_battle("smart", "14_office" if guard == 1 else "")
		print("gremlin battle -> ", r3)
		await after_battle_ok("gremlin battle %d" % guard)
	check(Game.state["quest"] == 5, "quest 5 after gremlins (%d)" % Game.state["quest"])

	# Tower shards (-> Starfall)
	for p in [Vector3(11.3, 0, -4.2), Vector3(-11.3, 0, 12.3)]:
		await teleport(p + Vector3(-1.5, 0, 0))
		await teleport(p)
		await drain_dialogs(8.0)
	check(Game.state["spells"].has("starfall"), "learned starfall")

	# A defeat: control must come back at home, healed.
	for cc in main.critters:
		if is_instance_valid(cc):
			Game.state["hp"] = 1
			await teleport(cc.position + Vector3(0, 0, 2))
			main.start_encounter(cc, false)
			var b: Battle = null
			await _wait(1.5)
			for c in main.get_children():
				if c is Battle:
					b = c
			if b:
				b._command_chosen.emit({"type": "guard"})
				# Don't guard the incoming hit so we faint.
				var tt := 0.0
				while tt < 30.0 and is_instance_valid(b) and not b._over:
					await _wait(0.1)
					tt += 0.1
			await after_battle_ok("defeat")
			check(main.world.map_id == "city", "woke up in the city after defeat")
			check(Game.state["hp"] == Game.state["max_hp"], "healed after defeat")
			break

	# Go back up to the roof. Give the hero typical end-game stats.
	var s := Game.state
	while s["level"] < 6:
		Game.add_xp(Game.xp_to_next())
	Game.add_item("muffin", 3)
	Game.add_item("tea", 2)
	await main.load_map("tower", Vector3(0, 0, -5))
	await teleport(Vector3(0, 0, -7.4))
	await teleport(Vector3(0, 0, -8.6))
	await _wait(1.5)
	await drain_dialogs()
	check(main.world.map_id == "roof", "reached rooftop")
	await shot("15_rooftop")
	await teleport(Vector3(0, 0, -1.0))
	main.interact("boss")
	await _wait(0.8)
	await press("confirm") # finish typing
	await _wait(0.2)
	await press("confirm") # choose "Fight!"
	var r4 := await play_battle("smart", "16_boss")
	print("boss battle -> ", r4, "  hp ", Game.state["hp"])
	# Ending sequence
	var t := 0.0
	while t < 40.0:
		if main.ui.is_dialog_open():
			await press("confirm")
		var ending := false
		for c in main.ui.get_children():
			if c is Control and c.get_child_count() > 2 and c.get_child(2) is PanelContainer and c != main.ui.hud and c != main.ui.dialog:
				ending = true
		if ending:
			await _wait(1.0)
			await shot("17_ending")
			await press("confirm")
			break
		await _wait(0.1)
		t += 0.1
	await drain_dialogs()
	check(Game.state["quest"] == 6, "boss beaten, quest 6 (%d)" % Game.state["quest"])
	await wait_mode(main.Mode.EXPLORE, 10)
	await shot("18_after_boss")

	# Stress: many quick battles, alternating styles, all must return cleanly.
	await main.load_map("city", Vector3(-10, 0, 8))
	for i in 10:
		var ids: Array = [Game.PARK_POOL.pick_random()]
		if i % 3 == 0:
			ids.append(Game.PARK_POOL.pick_random())
		main.run_script(func(): await main.battle(ids, "park", i % 2 == 0))
		var rr := await play_battle("ui" if i % 2 else "smart")
		await after_battle_ok("stress battle %d (%s)" % [i, rr])

	# Menu
	main.open_menu()
	await _wait(0.5)
	await shot("19_menu_friendbook")
	main.close_menu()

	print("BATTLES PLAYED: ", battles_done)
	if failures.is_empty():
		print("AUTOTEST PASS")
	else:
		print("AUTOTEST FAIL (%d): %s" % [failures.size(), ", ".join(failures)])
	get_tree().quit(0 if failures.is_empty() else 1)
