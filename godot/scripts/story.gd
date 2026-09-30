class_name Story
extends RefCounted
## All dialogue and quest logic. Every function here is a coroutine that
## main.run_script() awaits, so control always returns to the player after.
##
## Main quest (Game.state.quest):
##  0 latte from Bree -> 1 meet Merlo -> 2 cheer up 5 park critters ->
##  3 tower door (no badge) -> 4 badge arena -> 5 report to Dot ->
##  6 three elite gremlins -> 7 Printer King -> 8 Monday Monster -> 9 done

const C_MOCHI := Color("ffb37a")
const C_BREE := Color("7cd6b8")
const C_DOT := Color("6cc98f")
const C_MERLO := Color("6f95ef")
const C_BOSS := Color("ff5d7a")
const C_SYS := Color("b38cf0")
const C_HOOT := Color("c9906a")
const C_NANA := Color("c38bff")
const C_POPPY := Color("7cc97a")
const C_MARINA := Color("5fd6c9")

var m # main.gd


func _init(main) -> void:
	m = main


func say(who: String, text: String, color := UI.PINK) -> void:
	await m.ui.say(who, text, color)


func ask(who: String, text: String, options: Array, color := UI.PINK, default := 0) -> int:
	return await m.ui.ask(who, text, options, color, default)


func q() -> int:
	return int(Game.state["quest"])


func set_q(v: int) -> void:
	Game.state["quest"] = v
	m.ui.toast("New goal: " + Game.objective(), "star_gold")
	m.refresh_markers()


func marker_ids() -> Array:
	var ids: Array = []
	match q():
		0: ids = ["cafe", "bree"]
		1: ids = ["merlo"]
		3: ids = ["tower_door"]
		4: ids = ["badge"]
		5: ids = ["tower_door", "dot"]
		8: ids = ["stairs", "boss"]
	# Side quest givers with something to say get a marker too.
	if q() >= 3 and Game.side_state("books") in ["none", "ready"] and Game.flag("heal"):
		ids.append("hoot")
	if q() >= 3 and Game.side_state("yarn") in ["none", "ready"]:
		ids.append("thistle")
	if q() >= 3 and Game.side_state("garden") in ["none", "ready"]:
		ids.append("gardener")
	if q() >= 3 and Game.side_state("pearl") in ["none", "ready"]:
		ids.append("marina")
	if q() >= 1 and not Game.flag("heal"):
		ids.append("library")
	return ids


# ================================================================ intro
func intro() -> void:
	await Game.get_tree().create_timer(0.4).timeout
	await say("Mochi", "Mrrrow! {name}! Wake up! Today is your FIRST DAY at Spellwork Tower!", C_MOCHI)
	await say("Mochi", "I'm Mochi, your loyal familiar. Mostly loyal. Loyal-ish.", C_MOCHI)
	var hint := "Use the joystick to walk. Tap A to talk to people (and to swing your wand)." if DisplayServer.is_touchscreen_available() else "Walk with WASD or the arrow keys. Space talks to people, and swings your wand when nobody's around."
	await say("Mochi", hint, C_MOCHI)
	await say("Mochi", "First stop: coffee. The Bubbling Cauldron is the big mushroom cafe. Follow the gold  !  marks.", C_MOCHI)


# =========================================================== dispatcher
func interact(id: String) -> void:
	if id.begins_with("shard_"):
		await _shard(id.substr(6))
		return
	if id.begins_with("col_"):
		await _collect(id.substr(4))
		return
	match id:
		"home": await _enter("home_in")
		"cafe": await _enter("cafe_in")
		"library": await _enter("library_in")
		"boutique": await _enter("boutique_in")
		"exit_home": await _leave("home")
		"exit_cafe": await _leave("cafe")
		"exit_library": await _leave("library")
		"exit_boutique": await _leave("boutique")
		"bed": await _home()
		"photo": await say("", "Framed photos of you and your favorite person, all over the mantel. You smile every time you see them.", C_SYS)
		"bree": await _cafe()
		"gus": await _gus()
		"nyx": await _nyx()
		"hoot": await _hoot()
		"velour": await _velour()
		"mirror": await _mirror()
		"thistle": await _thistle()
		"gardener": await _poppy()
		"vending": await _vending()
		"tower_door": await _tower_door()
		"exit": await m.load_map("city", World.DOORS["tower_door"] + Vector3(0, 0, 2.3))
		"stairs": await _stairs()
		"down": await m.load_map("tower", Vector3(0, 0, -6.9))
		"ward": await _ward()
		"badge": await _badge()
		"printer_arena": await _printer_king()
		"mochi": await _mochi()
		"pip": await _pip()
		"sparkle": await _sparkle()
		"reginald": await _reginald()
		"merlo": await _merlo()
		"marina": await _marina()
		"dot": await _dot()
		"fern": await _fern()
		"ghost", "ghost_roof": await _ghost()
		"boss": await _boss()
		"clock_friend":
			await say("Tiny Clock", "tick... tock... I'm just a regular little clock now. I promise to only ring on Saturdays. At noon. Very softly.", C_BOSS)


# ======================================================= combat hooks
## Called by Combat every time a critter is cheered up.
func on_enemy_calmed(e: Enemy) -> void:
	if m.world == null:
		return
	if m.world.map_id == "city" and e.id in Game.PARK_POOL:
		if q() == 2:
			Game.state["park_calmed"] = int(Game.state["park_calmed"]) + 1
			m.ui.refresh()
			if int(Game.state["park_calmed"]) >= 5:
				_park_done.call_deferred()
		if Game.side_progress("garden"):
			m.ui.toast("Garden Guard done! Go see Poppy.", "star_gold")
			m.refresh_markers()
		elif Game.side_state("garden") == "active":
			m.ui.toast("Garden Guard %d/8" % Game.side_count("garden"))
	if e.uid != "":
		Game.set_flag("beat_" + e.uid)
		if q() == 6:
			var n := Game.gremlins_done()
			m.ui.refresh()
			if n >= 3:
				_gremlins_done.call_deferred()
			else:
				m.ui.toast("Sparkly gremlins cheered up: %d / 3" % n, "star_gold")


func _park_done() -> void:
	if q() != 2:
		return
	m.run_script(func():
		await say("Mochi", "Look at you go! Five grumpy critters, five happy friends. Grandpa Merlo would be proud.", C_MOCHI)
		await say("Mochi", "Okay, practice is over. Time for your first day at Spellwork Tower. It's the tall purple one!", C_MOCHI)
		set_q(3))


func _gremlins_done() -> void:
	if q() != 6:
		return
	m.run_script(func():
		Audio.sfx("shard")
		for node_name in ["Ward", "WardBody"]:
			var w: Node = m.world.get_node_or_null(node_name)
			if w:
				w.queue_free()
		for it in m.world.interactables:
			if it["id"] == "ward":
				m.world.interactables.erase(it)
				break
		Art.burst(m.world, Vector3(0, 1.6, -6), Color("e0b8ff"), 60, "sparkle", 6, 1.5, 0.4)
		await say("", "POP! The grumpy magic ward bursts like a soap bubble!", C_SYS)
		await say("", "...and then the floor starts to rumble. KA-CHUNK. KA-CHUNK. PC LOAD LETTER.", C_SYS)
		await say("Mochi", "Uh oh. That doesn't sound like a normal printer.", C_MOCHI)
		set_q(7)
		m.world.add_interactable("printer_arena", Vector3(0, 0, -3.8), 3.2, "", true))


# ================================================================ places
## Where you appear in town after walking out of a building.
static func door_spawn(building: String) -> Vector3:
	return (World.DOORS[building] as Vector3) + Vector3(0, 0, 1.4)


func _enter(map_id: String) -> void:
	Audio.sfx("door")
	await m.load_map(map_id, Vector3(0, 0, 3.0))


func _leave(building: String) -> void:
	Audio.sfx("door")
	await m.load_map("city", door_spawn(building))


func _home() -> void:
	var c := await ask("Home", "Home sweet home. Take a cozy nap? (Restores HP and MP and saves.)", ["Nap time", "Not now"], C_SYS)
	if c != 0:
		return
	await m.ui.fade_out(0.5)
	Game.full_heal()
	Audio.sfx("heal")
	Game.save_game()
	await Game.get_tree().create_timer(0.5).timeout
	await m.ui.fade_in(0.5)
	await say("Home", "Zzz... You wake up fresh as a daisy! (Game saved)", C_SYS)


func _cafe() -> void:
	if q() == 0:
		await say("Bree", "Welcome to the Bubbling Cauldron! Ooh, a new face!", C_BREE)
		await say("Bree", "First day at Spellwork Tower? Then this Moonbeam Latte is on the house!", C_BREE)
		Game.full_heal()
		Audio.sfx("heal")
		await say("", "You sip the latte... you feel magically awake! (HP and MP restored)", C_SYS)
		await say("Bree", "And a little secret recipe of mine: FLAME PETAL! Three fiery petals that make grumpy critters toasty.", C_BREE)
		Game.learn("flame")
		Audio.sfx("level_up")
		m.ui.toast("Learned Flame Petal!", "fire")
		var keyhint := "It's your first skill button next to A." if DisplayServer.is_touchscreen_available() else "Press 1 to cast it. It costs MP, and your wand hits give MP back."
		await say("Bree", keyhint, C_BREE)
		await say("Bree", "Oh! Grandpa Merlo was asking about you. He's in Petal Park, across the road. He teaches the best wand tricks.", C_BREE)
		set_q(1)
		return
	while true:
		var coins: int = Game.state["coins"]
		var c := await ask("Bree", "Welcome back, {name}! What can I get you? (You have %d coins)" % coins,
			["Pumpkin Muffin (8 coins)", "Moon Tea, +15 MP (10 coins)", "Moonbeam Latte, full heal (5 coins)", "That's all, thanks!"], C_BREE, 3)
		match c:
			0:
				if coins >= 8:
					Game.add_coins(-8)
					Game.add_item("muffin")
					Audio.sfx("coin")
					await say("Bree", "One muffin, fresh from the enchanted oven! Press H to munch it in a pinch.", C_BREE)
				else:
					await say("Bree", "Aww, not quite enough coins. Cheer up some critters and come back!", C_BREE)
			1:
				if coins >= 10:
					Game.add_coins(-10)
					Game.add_item("tea")
					Audio.sfx("coin")
					await say("Bree", "Moon Tea, brewed under a full moon. Press T to sip it!", C_BREE)
				else:
					await say("Bree", "Not enough coins for tea, sweetie.", C_BREE)
			2:
				if coins >= 5:
					Game.add_coins(-5)
					Game.full_heal()
					Audio.sfx("heal")
					await say("Bree", "Extra foam, extra moonbeams! You look refreshed!", C_BREE)
				else:
					await say("Bree", "Here, at least smell the latte. Mmm.", C_BREE)
			_:
				await say("Bree", ["Bye bye! Fly safe!", "Come back soon, sweetie!", "Don't let the Mondays get you down!"].pick_random(), C_BREE)
				return


func _tower_door() -> void:
	match q():
		0, 1, 2:
			await say("Mochi", "Not yet! Coffee first, then wand practice with Grandpa Merlo. A wizard needs to warm up.", C_MOCHI)
		3:
			Audio.sfx("ui_cancel")
			await say("Door", "BEEP BOOP. Employee badge not detected. Please present your badge, valued wizard.", C_SYS)
			await say("Mochi", "...{name}. Where is your badge?", C_MOCHI)
			await say("Mochi", "Wait. Yesterday. Petal Park. You were chasing butterflies and I heard a little 'plink'.", C_MOCHI)
			await say("Mochi", "It's probably by the big trees on the west side of the park. Let's go get it!", C_MOCHI)
			set_q(4)
			m.world.spawn_badge(Vector3(-18, 0, 12))
			m.refresh_markers()
		4:
			await say("Door", "BEEP BOOP. Still no badge. The park is south-west, valued wizard.", C_SYS)
		_:
			Audio.sfx("door")
			await m.load_map("tower", Vector3(0, 0, 12.2))
			if q() == 5:
				await say("Dot", "Oh! Are you the new hire? Over here at reception, sweetie!", C_DOT)


func _stairs() -> void:
	if q() < 8:
		return
	Audio.sfx("door")
	await m.load_map("roof", Vector3(0, 0, 6.8))
	if q() == 8:
		Audio.sfx("alarm")
		await say("The Monday Monster", "RIIIIIING! WHO DARES CLIMB TO MY ROOFTOP?!", C_BOSS)


func _ward() -> void:
	await say("Magic Ward", "A grumpy purple ward crackles in front of the stairs. It's powered by office gremlins.", C_SYS)
	if q() == 6:
		await say("Magic Ward", "Sparkly gremlins cheered up: %d / 3" % Game.gremlins_done(), C_SYS)
	elif q() < 6:
		await say("Mochi", "Maybe the receptionist knows what's going on.", C_MOCHI)


func _shard(id: String) -> void:
	if Game.state["shards"].has(id):
		return
	Game.state["shards"].append(id)
	Game.side_progress("shards")
	var n: Node3D = m.world.get_node_or_null("Shard_" + id)
	if n:
		Art.burst(m.world, n.global_position, Color("c9a6ff"), 30, "sparkle", 4, 1.0, 0.35)
		n.queue_free()
	_remove_interactable("shard_" + id)
	Audio.sfx("shard")
	var count: int = Game.state["shards"].size()
	m.ui.toast("Star Shard %d / %d" % [count, Game.SHARD_TOTAL], "shard")
	if count >= Game.SHARD_TOTAL:
		Game.learn("starfall")
		Game.finish_side("shards")
		_reward_item("hat", 3)
		Audio.sfx("level_up")
		await say("", "All five Star Shards glow together and swirl around you...", C_SYS)
		await say("", "You learned STARFALL! Stars rain on every critter nearby and stun them. (Skill 4)", C_SYS)
	elif count == 1:
		await say("Mochi", "Ooh, a Star Shard! Legend says five of them teach a wizard a secret spell.", C_MOCHI)


func _collect(cid: String) -> void:
	if Game.state["collected"].has(cid):
		return
	Game.state["collected"].append(cid)
	var node: Node3D = m.world.get_node_or_null("Col_" + cid)
	if node:
		Art.burst(m.world, node.global_position, Color("fff3b0"), 20, "sparkle", 3, 0.8, 0.3)
		node.queue_free()
	_remove_interactable("col_" + cid)
	Audio.sfx("coin")
	var quest := "books" if cid.begins_with("book") else ("yarn" if cid.begins_with("yarn") else "pearl")
	var ready := Game.side_progress(quest)
	var sq: Dictionary = Game.SIDE_QUESTS[quest]
	if ready:
		m.ui.toast("%s complete! Return to %s." % [sq["title"], sq["giver"]], "star_gold")
		m.refresh_markers()
	else:
		m.ui.toast(Game.side_goal(quest), "star_gold")


## Side quests also hand out a piece of shiny gear.
func _reward_item(slot: String, rarity: int) -> void:
	var it := Rpg.make_item(slot, int(Game.state["level"]) + 1, rarity)
	if Rpg.add_to_bag(it):
		m.ui.toast("Reward: %s! (Menu > Gear)" % it["name"], slot)


func _remove_interactable(id: String) -> void:
	for it in m.world.interactables:
		if it["id"] == id:
			m.world.interactables.erase(it)
			return


# ============================================================ fights
func _badge() -> void:
	if q() != 4:
		return
	await say("Mochi", "There's your badge! And... uh oh. A whole gang of grumpy critters is playing keep-away with it.", C_MOCHI)
	await say("Grumpy Cloud", "Hmph! Finders keepers! It's MONDAY and we're GRUMPY!", Color("9a93c9"))
	for k in ["badge_gang_a", "badge_gang_b"]:
		if m.world.npcs.has(k):
			m.world.npcs[k].visible = false
	await say("Mochi", "They've trapped us in a bubble! Cheer them all up to get out. Dash with Shift (or the Dash button) to dodge!", C_MOCHI)
	var result: String = await m.fight_arena(Vector3(-18, 0, 11.5), 7.5, [["cloud", "pigeon", "bee"], ["shroom", "umbrella", "cloud", "pigeon"]])
	if result != "win":
		return
	for k in ["badge_gang_a", "badge_gang_b"]:
		if m.world.npcs.has(k):
			m.world.npcs[k].queue_free()
			m.world.npcs.erase(k)
	var b: Node3D = m.world.get_node_or_null("Badge")
	if b:
		b.queue_free()
	_remove_interactable("badge")
	Audio.sfx("coin")
	m.ui.toast("Got your Employee Badge!", "star_gold")
	await say("Mochi", "Got it! Now let's get to work before the boss notices you're late.", C_MOCHI)
	set_q(5)


func _printer_king() -> void:
	if q() != 7:
		return
	_remove_interactable("printer_arena")
	Audio.sfx("alarm")
	await say("The Printer King", "KA-CHUNK! I AM THE PRINTER KING! NO ONE CLIMBS THOSE STAIRS WITHOUT FILLING OUT FORM 27-B!", C_BOSS)
	await say("Mochi", "It's weak to Sparkle, I bet. Your wand is Sparkle magic! And when it slams down, it gets dizzy. That's your moment!", C_MOCHI)
	var center := Vector3(0, 0, 0)
	m.combat.start_arena(center, 9.0, [])
	var boss: Enemy = m.combat.spawn_enemy("printer_king", Vector3(0, 0, -3.0), Rect2(-9, -5, 18, 10), "", true)
	var result: String = await m.fight(boss)
	m.combat.end_arena(false)
	if result != "win":
		# Try again next time you walk up.
		return
	await say("The Printer King", "...paper jam... cleared. Here. I printed you a crown. It's paper. You're welcome.", C_BOSS)
	await say("Dot (intercom)", "The stairs are clear! {name}, the Monday Monster is on the roof. Everyone's counting on you!", C_DOT)
	set_q(8)


func _boss() -> void:
	var c := await ask("The Monday Monster", "RIIIING! NO. MORE. WEEKENDS. EVERY DAY IS MONDAY NOW!!", ["Fight!", "Not yet (heal up first)"], C_BOSS)
	if c != 0:
		return
	await say("Mochi", "Watch the rings on the ground! Dash THROUGH the shockwaves. It's weak to Ice... until it gets angry.", C_MOCHI)
	var npc: Node3D = m.world.npcs.get("boss")
	var pos := Vector3(0, 0, -4.2)
	if npc:
		pos = npc.position
		npc.visible = false
	var boss: Enemy = m.combat.spawn_enemy("monday", pos, Rect2(-8, -8, 16, 15), "", true)
	var result: String = await m.fight(boss)
	if result != "win":
		return
	set_q(9)
	if npc:
		npc.queue_free()
		m.world.npcs.erase("boss")
	_remove_interactable("boss")
	m.world.add_npc("clock_friend", Models.tiny_clock(), pos, 0, "Talk to the Tiny Clock")
	Audio.play_music("ending", 1.5)
	for i in 6:
		var p := Vector3(randf_range(-8, 8), randf_range(6, 10), randf_range(-10, -4))
		Art.burst(m.world, p, [Color("ff8fc8"), Color("ffe27a"), Color("8fe8ff")][i % 3], 50, "sparkle", 6.0, 1.6, 0.45, Vector3(0, -2, 0))
	await say("", "The Monday Monster lets out a huge yawn... and shrinks into a tiny, sleepy clock.", C_SYS)
	await say("Tiny Clock", "...sorry. I just really, really wanted a weekend too.", C_BOSS)
	await say("Mochi", "Aww. Everyone deserves a weekend. Even alarm clocks.", C_MOCHI)
	await say("Dot (intercom)", "ATTENTION ALL STAFF: {name} saved Monday! Everyone gets Friday off!", C_DOT)
	for i in 8:
		var p := Vector3(randf_range(-9, 9), randf_range(6, 11), randf_range(-12, -3))
		Art.burst(m.world, p, [Color("ff8fc8"), Color("ffe27a"), Color("8fe8ff"), Color("c3a6ff")][i % 4], 60, "star", 7.0, 1.8, 0.5, Vector3(0, -2, 0))
		Audio.sfx("sparkle", 0.2)
		await Game.get_tree().create_timer(0.35).timeout
	Game.save_game()
	await m.ui.show_ending()


# ================================================================ people
func _mochi() -> void:
	var lines := {
		0: "Coffee first, then work. That's the ancient law. (The cafe is the big mushroom!)",
		1: "Grandpa Merlo is in Petal Park, by the benches. He'll show you some wand tricks.",
		2: "Cheer up grumpy critters in the park! Space or J swings your wand. Chain three swings for a big finisher.",
		3: "Spellwork Tower is the tall purple one with the glowing ring. Go go go!",
		4: "Your badge should be on the west side of Petal Park.",
		5: "Report to Dot at reception!",
		6: "The sparkly gremlins hide on the blue carpet. They're tougher than normal critters. Use your skills!",
		7: "That printer is BIG. Wait for it to slam down and get dizzy, then hit it hard.",
		8: "Every few seconds, the Monday Monster sends a shockwave. Dash through it at the last moment!",
	}
	await say("Mochi", lines.get(q(), "You saved Monday?! I'm impressed. Here, have a slow blink."), C_MOCHI)
	var c := await ask("Mochi", "Mochi looks at you expectantly.", ["Pet Mochi", "Leave her be"], C_MOCHI)
	if c == 0:
		Audio.sfx("purr")
		Art.burst(m.world, m.follower.position + Vector3(0, 0.8, 0), Color("ff9fc4"), 10, "heart", 1.5, 1.2, 0.3, Vector3(0, 1.5, 0))
		await say("Mochi", ["Purrrrrr...", "Mrrp! ...Okay, that was acceptable.", "Purr. You may continue. For science."].pick_random(), C_MOCHI)


func _merlo() -> void:
	if q() == 1:
		await say("Grandpa Merlo", "Ho ho! Bree's new favorite customer! Back in my day we fought DRAGONS. Now the dragons work in HR.", C_MERLO)
		await say("Grandpa Merlo", "Wand basics: swing three times in a row for a big sparkly finisher. Each hit gives you a little MP back.", C_MERLO)
		var dash := "the Dash button" if DisplayServer.is_touchscreen_available() else "Shift, K or right-click"
		await say("Grandpa Merlo", "When the ground glows red under you, something is about to hit that spot. DASH out with %s. You can't be hurt mid-dash!" % dash, C_MERLO)
		await say("Grandpa Merlo", "Now watch closely... FROST BLOOM! An icy ring that freezes everything around you.", C_MERLO)
		Game.learn("frost")
		Game.set_flag("frost")
		Audio.sfx("ice")
		m.ui.toast("Learned Frost Bloom!", "ice")
		await say("Grandpa Merlo", "Every critter has a weakness: Fire, Ice or Sparkle. Hit it and you'll see WEAK! pop up.", C_MERLO)
		await say("Grandpa Merlo", "Now go cheer up five grumpy critters here in the park. Show me what you've got!", C_MERLO)
		Game.state["park_calmed"] = 0
		set_q(2)
		return
	var tips := [
		"Tip: red circles mean danger. Dash away, or dash right through the attack!",
		"Tip: frozen critters can't attack. Frost Bloom first, then wand combo!",
		"Tip: every level up lets you pick a perk. Build your own style of wizard!",
		"Tip: Flame Petal burns. The burn keeps working while you dodge.",
		"Tip: there are five Star Shards hidden in town, the library and the tower.",
	]
	var i := int(Game.state["flags"].get("merlo_tip", 0))
	Game.set_flag("merlo_tip", (i + 1) % tips.size())
	await say("Grandpa Merlo", tips[i % tips.size()], C_MERLO)


func _dot() -> void:
	match q():
		5:
			await say("Dot", "Thank goodness you're here! I'm Dot, reception dragon. Welcome to Spellwork Tower!", C_DOT)
			await say("Dot", "Bad news, sweetie. Someone left the Enchanted Alarm Clock on all weekend...", C_DOT)
			await say("Dot", "It soaked up ALL the Monday grumpiness in the city and became... THE MONDAY MONSTER!", C_DOT)
			await say("Dot", "It sealed itself on the rooftop behind a magic ward. Three sparkly office gremlins are powering it.", C_DOT)
			await say("Dot", "They're on the blue carpet, and they're tough. Cheer up all three and the ward should pop!", C_DOT)
			set_q(6)
			# The gremlins arrive now that you know about them.
			var office := Rect2(-10.5, -4.8, 21, 9.4)
			var types := ["paper", "coffee", "printer"]
			for i in 3:
				var uid := "g%d" % (i + 1)
				if not Game.flag("beat_" + uid):
					var already := false
					for e in m.combat.enemies:
						if is_instance_valid(e) and e.uid == uid:
							already = true
					if not already:
						m.combat.spawn_enemy(types[i], Vector3(-7 + i * 7, 0, -0.5 + (i % 2) * 2), office, uid, false, true)
		6:
			await say("Dot", "Sparkly gremlins cheered up: %d / 3. You've got this, {name}!" % Game.gremlins_done(), C_DOT)
		7:
			await say("Dot", "Is that the PRINTER KING? Nobody's seen it since the Great Toner Incident!", C_DOT)
		8:
			await say("Dot", "The stairs are open! Go get 'em! (Maybe nap or grab a latte first. Just saying.)", C_DOT)
		9:
			await say("Dot", "Employee of the month! No, of the CENTURY! I made you a sparkly badge.", C_DOT)
		_:
			await say("Dot", "Welcome to Spellwork Tower, where magic means business!", C_DOT)


func _hoot() -> void:
	if not Game.flag("heal"):
		await say("Professor Hoot", "Hoo! A young wizard in my library! Mind the floating books, they bite. Gently.", C_HOOT)
		await say("Professor Hoot", "Every wizard should know how to take care of themselves. Let me teach you HEAL GLOW.", C_HOOT)
		Game.learn("heal")
		Game.set_flag("heal")
		Audio.sfx("heal")
		m.ui.toast("Learned Heal Glow!", "hp")
		return
	match Game.side_state("books"):
		"none":
			await say("Professor Hoot", "Oh dear, oh dear. Four of my books flapped out the window this morning. Monday grumpiness, I suspect.", C_HOOT)
			var c := await ask("Professor Hoot", "Could you catch them for me? They're somewhere around town.", ["Of course!", "Maybe later"], C_HOOT)
			if c == 0:
				Game.start_side("books")
				m.ui.toast("Side quest: Runaway Books", "star_gold")
				await say("Professor Hoot", "Bless you! They glow a little, so they're easy to spot.", C_HOOT)
		"active":
			await say("Professor Hoot", "Still missing some books. %s" % Game.side_goal("books"), C_HOOT)
		"ready":
			await say("Professor Hoot", "All four! Hoo hoo! As thanks, let me share a bit of my wisdom. Your mind feels... roomier.", C_HOOT)
			Rpg.add_base("mp", 6)
			Game.add_coins(30)
			Game.finish_side("books")
			_reward_item("charm", 2)
			Audio.sfx("level_up")
			m.ui.toast("Reward: +6 max MP and 30 coins", "mp")
		_:
			await say("Professor Hoot", ["The Monday Monster was once a humble alarm clock. Grumpiness is a powerful magic.",
				"One Star Shard hides in this very library. Have you found it?",
				"Fire melts paper and clouds. Ice chills bugs and birds. Sparkle soothes machines."].pick_random(), C_HOOT)


func _thistle() -> void:
	match Game.side_state("yarn"):
		"none":
			await say("Nana Thistle", "Oh, hello dearie. I was knitting a scarf for the Wishing Tree when a gust stole my yarn!", C_NANA)
			var c := await ask("Nana Thistle", "Five balls of yarn, rolled all over town. Would you fetch them for an old witch?", ["I'll find them!", "Maybe later"], C_NANA)
			if c == 0:
				Game.start_side("yarn")
				m.world._side_collectibles()
				m.ui.toast("Side quest: Nana's Yarn", "star_gold")
				Game.add_item("tea", 1)
				await say("Nana Thistle", "Take a Moon Tea for the road, dearie.", C_NANA)
		"active":
			await say("Nana Thistle", "Any luck? %s" % Game.side_goal("yarn"), C_NANA)
		"ready":
			await say("Nana Thistle", "My yarn! Here, I knitted you a Cozy Scarf while I waited. It's very warm. And very pink.", C_NANA)
			Rpg.add_base("hp", 20)
			Game.heal(20)
			Game.finish_side("yarn")
			_reward_item("robe", 2)
			Audio.sfx("level_up")
			m.ui.toast("Reward: Cozy Scarf, +20 max HP", "hp")
		_:
			await say("Nana Thistle", ["Knit one, purl two... sparkle three.", "Back in my day, critters were grumpy on Tuesdays too.",
				"Visit the Wishing Tree past the stream, dearie. It likes company."].pick_random(), C_NANA)


func _poppy() -> void:
	match Game.side_state("garden"):
		"none":
			await say("Poppy", "I'm the head gardener! And grumpy critters keep trampling my flower beds.", C_POPPY)
			var c := await ask("Poppy", "Could you cheer up eight of them anywhere in the park?", ["Leave it to me!", "Maybe later"], C_POPPY)
			if c == 0:
				Game.start_side("garden")
				m.ui.toast("Side quest: Garden Guard", "star_gold")
		"active":
			await say("Poppy", "Thank you for helping! %s" % Game.side_goal("garden"), C_POPPY)
		"ready":
			await say("Poppy", "The flowers are dancing again! Here, a Flower Crown. Wearing flowers makes everyone stronger. Science!", C_POPPY)
			Rpg.add_base("atk", 3)
			Game.add_item("muffin", 3)
			Game.finish_side("garden")
			_reward_item("wand", 2)
			Audio.sfx("level_up")
			m.ui.toast("Reward: Flower Crown, +3 power and 3 muffins", "star_gold")
		_:
			await say("Poppy", ["The hedge garden took me three hundred naps to grow.", "The flowers glow at night if you sing to them.",
				"Swing your wand in threes. The third swing is the big one!"].pick_random(), C_POPPY)


func _marina() -> void:
	match Game.side_state("pearl"):
		"none":
			await say("Marina", "I work from home. Well, from pond. But I lost my lucky pearl near the stream!", C_MARINA)
			var c := await ask("Marina", "Could you look along the stream bank? It's the shiny pink one.", ["Sure!", "Maybe later"], C_MARINA)
			if c == 0:
				Game.start_side("pearl")
				m.world._side_collectibles()
				m.ui.toast("Side quest: Marina's Pearl", "star_gold")
		"active":
			await say("Marina", "It should be on the stream bank, west of the first bridge.", C_MARINA)
		"ready":
			await say("Marina", "My pearl! Here, take this Tidal Charm. Your magic will flow back faster.", C_MARINA)
			Game.set_flag("pearl_charm")
			Game.add_item("tea", 3)
			Game.finish_side("pearl")
			_reward_item("charm", 2)
			Audio.sfx("level_up")
			m.ui.toast("Reward: Tidal Charm (faster MP) and 3 Moon Teas", "tea")
		_:
			await say("Marina", ["The fountain crystal keeps the pond warm. Perfect for mermaid meetings.",
				"If you see a shiny Star Shard, grab it!", "The wifi down here is surprisingly good."].pick_random(), C_MARINA)


func _fern() -> void:
	await say("Fern", "Hi, new person! I'm Fern from Accounts Enchantable.", Color("5fc9a8"))
	var lines := {
		6: "The sparkly gremlins are tough! Paperwork hates Fire, Coffee hates Ice, and the Printer just needs Sparkle.",
		7: "The Printer King? I KNEW it was haunted!",
		8: "The stairs are open? You're a legend. I'd help, but I have a two o'clock.",
		9: "Lunch is on me today! Honestly, lunch is on me forever.",
	}
	await say("Fern", lines.get(q(), "Facilities says the blue carpet is 'enchanted'. I say it's haunted."), Color("5fc9a8"))


func _ghost() -> void:
	await say("Boo-b the Intern", "Boo! ...Sorry, force of habit.", Color("b8b8e0"))
	if q() < 9:
		await say("Boo-b the Intern", "Hot tip: the Monday Monster is weak to Ice. When it gets angry, it overheats. Then use Fire!", Color("b8b8e0"))
		await say("Boo-b the Intern", "And those spinning clock hands? Stay out of their path, or dash through them.", Color("b8b8e0"))
	else:
		await say("Boo-b the Intern", "Now that it's quiet up here I can finally haunt in peace. Thanks, {name}!", Color("b8b8e0"))


func _gus() -> void:
	await say("Gus the Gnome", ["I've been coming here for 300 years. The muffins used to cost one acorn.",
		"Psst. If you're low on MP, Moon Tea is the secret. Press T!",
		"My beard? Enchanted. It keeps my coffee warm."].pick_random(), Color("e05a5a"))


func _nyx() -> void:
	await say("Nyx", ["I'm a bat, so technically this is my breakfast. It's 7 p.m. for me.",
		"Have you tried the Wishing Tree past the stream? Everyone says it grants cozy wishes.",
		"Professor Hoot at the library knows EVERYTHING. Ask him about spells."].pick_random(), Color("8f6ee8"))


func _velour() -> void:
	var cv := Color("e05aa8")
	await say("Madame Velour", "Bienvenue, darling! Every hero deserves a signature look. The mirror is free; my enchanted gear is... not.", cv)
	var shop: Dictionary = Game.state.get("shop", {})
	if int(shop.get("quest", -1)) != q():
		# New stock every chapter.
		shop = {"quest": q(), "items": []}
		for i in 4:
			# One of each: wand, hat, robe and charm.
			shop["items"].append(Rpg.make_item(Rpg.SLOTS[i], int(Game.state["level"]) + 1, maxi(1 + int(i == 3), Rpg.roll_rarity(0.4))))
		Game.state["shop"] = shop
	while true:
		var items: Array = shop["items"]
		var opts: Array = []
		for it in items:
			opts.append("%s (%d coins)" % [it["name"], int(it["price"])])
		opts.append("Just looking, thanks")
		var c := await ask("Madame Velour", "What catches your eye? (You have %d coins)" % Game.state["coins"], opts, cv, opts.size() - 1)
		if c >= items.size():
			await say("Madame Velour", "Au revoir, darling! Come back when the collection changes.", cv)
			return
		var it: Dictionary = items[c]
		var lines := Rpg.item_lines(it)
		var desc := "%s %s. %s" % [Rpg.RARITY[int(it["rarity"])]["name"], Rpg.SLOT_NAMES[it["slot"]], ", ".join(lines)]
		var yes := await ask("Madame Velour", desc, ["Buy it!", "Maybe not"], cv)
		if yes != 0:
			continue
		if int(Game.state["coins"]) < int(it["price"]):
			await say("Madame Velour", "Ah, a little short, darling. Critters drop coins, you know.", cv)
			continue
		if not Rpg.add_to_bag(it):
			await say("Madame Velour", "Your bag is bursting! Sell something first (Menu > Gear).", cv)
			return
		Game.add_coins(-int(it["price"]))
		items.remove_at(c)
		Audio.sfx("coin")
		m.ui.toast("Bought %s! Equip it in Menu > Gear." % it["name"], it["slot"])


func _mirror() -> void:
	var style_names := ["Witch", "Fairy", "Elf", "Keep my style"]
	var c := await ask("Magic Mirror", "Mirror, mirror... which look today?", style_names, Color("ffd36b"), 3)
	if c < 3:
		Game.state["style"] = Game.STYLES[c]
	var robes := ["Lavender", "Rose", "Mint", "Sky", "Peach", "Pearl"]
	var r := await ask("Magic Mirror", "And your robe color?", robes, Color("ffd36b"), int(Game.state["robe"]))
	Game.state["robe"] = r
	var hairs := ["Cocoa", "Honey", "Bubblegum", "Midnight", "Frost"]
	var h := await ask("Magic Mirror", "And your hair?", hairs, Color("ffd36b"), int(Game.state["hair"]))
	Game.state["hair"] = h
	Audio.sfx("sparkle")
	m.player.rebuild_model()
	Art.burst(m.world, m.player.position + Vector3(0, 1, 0), Color("ffd3e6"), 30, "sparkle", 3.0, 1.0, 0.35)
	await say("Madame Velour", "Magnifique! You look absolutely enchanting.", Color("e05aa8"))


func _pip() -> void:
	await say("Pip the Postowl", ["Hoo! Special delivery for... {name}? Oh wait, no. It's for Mochi. Catnip. Again.",
		"Hoo hoo! Enchanted mail moves at the speed of wings! Unless it's raining. Then it's soggy.",
		"Did you know the cafe fairy bakes muffins with actual moonlight? Very healthy. Probably."].pick_random(), Color("c9906a"))


func _sparkle() -> void:
	await say("Sparkle", ["Ugh, the 8:15 sky-tram is late AGAIN.",
		"I'm a certified accountant. Horn-tified. ...Heh. Sorry.",
		"Rush hour in Moonbrook is wild. Yesterday a broom cut me off!"].pick_random(), Color("c38bff"))


func _reginald() -> void:
	await say("Sir Reginald", ["I slew three dragons before breakfast! ...Just kidding. I do spreadsheets now.",
		"A knight's armor is great for jousting. Terrible for the sky-tram turnstile.",
		"Mondays are the true final boss, young wizard."].pick_random(), Color("8f9bb8"))


func _vending() -> void:
	var coins: int = Game.state["coins"]
	var c := await ask("Potion Machine", "BLOOP. One Moon Tea: 6 coins. (You have %d coins)" % coins, ["Buy one", "No thanks"], Color("ff8fb8"), 1)
	if c != 0:
		return
	if coins < 6:
		await say("Potion Machine", "BLOOP BLOOP. Insufficient sparkle funds.", Color("ff8fb8"))
		return
	Game.add_coins(-6)
	Game.add_item("tea")
	Audio.sfx("coin")
	await say("Potion Machine", "*clunk* A warm Moon Tea rolls out. It smells like stars.", Color("ff8fb8"))
