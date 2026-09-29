class_name Story
extends RefCounted
## All dialogue and quest logic. Every function here is a coroutine that
## main.run_script() awaits, so control always returns to the player after.

const C_MOCHI := Color("ffb37a")
const C_BREE := Color("7cd6b8")
const C_DOT := Color("6cc98f")
const C_MERLO := Color("6f95ef")
const C_BOSS := Color("ff5d7a")
const C_SYS := Color("b38cf0")

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
	m.refresh_markers()


func marker_ids() -> Array:
	match q():
		0: return ["cafe", "bree"]
		1: return ["tower_door"]
		2: return ["badge"] if Game.flag("frost") else ["merlo", "badge"]
		3: return ["tower_door", "dot"]
		5: return ["stairs", "boss"]
	return []


# ================================================================ intro
func intro() -> void:
	await Game.get_tree().create_timer(0.4).timeout
	await say("Mochi", "Mrrrow! {name}! Wake up! Today is your FIRST DAY at Spellwork Tower!", C_MOCHI)
	await say("Mochi", "I'm Mochi, your loyal familiar. Mostly loyal. Loyal-ish.", C_MOCHI)
	var hint := "Use the joystick to walk and tap A to talk." if DisplayServer.is_touchscreen_available() else "Walk with WASD or the arrow keys. Press Space to talk and to swing your wand."
	await say("Mochi", hint, C_MOCHI)
	await say("Mochi", "First stop: coffee. The Bubbling Cauldron is the big mushroom cafe. Follow the gold  !  marks.", C_MOCHI)
	await say("Mochi", "Oh, and watch out for grumpy critters in Petal Park. We don't hurt anyone in Moonbrook. We cheer them up with magic!", C_MOCHI)
	await say("Mochi", "Tip: swing your wand at a critter before it bumps into you and you'll get a First Strike!", C_MOCHI)


# =========================================================== dispatcher
func interact(id: String) -> void:
	if id.begins_with("shard_"):
		await _shard(id.substr(6))
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
		"exit": await m.load_map("city", Vector3(15, 0, -6.9))
		"stairs": await _stairs()
		"down": await m.load_map("tower", Vector3(0, 0, -6.9))
		"ward": await _ward()
		"badge": await _badge()
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


# ================================================================ places
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


const DOOR_SPAWNS := {"home": Vector3(-15, 0, -6.8), "cafe": Vector3(0, 0, -6.8),
	"library": Vector3(-32, 0, -6.8), "boutique": Vector3(31, 0, -6.8)}


func _enter(map_id: String) -> void:
	Audio.sfx("door")
	await m.load_map(map_id, Vector3(0, 0, 3.0))


func _leave(building: String) -> void:
	Audio.sfx("door")
	await m.load_map("city", DOOR_SPAWNS[building])


func _cafe() -> void:
	if q() == 0:
		await say("Bree", "Welcome to the Bubbling Cauldron! Ooh, a new face!", C_BREE)
		await say("Bree", "First day at Spellwork Tower? Then this Moonbeam Latte is on the house!", C_BREE)
		Game.full_heal()
		Audio.sfx("heal")
		await say("", "You sip the latte... you feel magically awake! (HP and MP restored)", C_SYS)
		await say("Bree", "And a little secret recipe of mine: Flame Petal! Toss it at anything soggy or papery.", C_BREE)
		Game.learn("flame")
		Audio.sfx("level_up")
		m.ui.toast("Learned Flame Petal!", "fire")
		await say("Bree", "Plus two Pumpkin Muffins for the road. Eat one in battle if you get hurt!", C_BREE)
		Game.add_item("muffin", 2)
		m.ui.toast("Got 2 Pumpkin Muffins", "muffin")
		await say("Bree", "Spellwork Tower is the tall purple one with the glowing ring. Knock 'em dead! ...Figuratively!", C_BREE)
		set_q(1)
		return
	while true:
		var coins: int = Game.state["coins"]
		var c := await ask("Bree", "Welcome back, {name}! What can I get you? (You have %d coins)" % coins,
			["Pumpkin Muffin (8 coins)", "Moon Tea, +12 MP (10 coins)", "Moonbeam Latte, full heal (5 coins)", "That's all, thanks!"], C_BREE, 3)
		match c:
			0:
				if coins >= 8:
					Game.add_coins(-8)
					Game.add_item("muffin")
					Audio.sfx("coin")
					await say("Bree", "One muffin, fresh from the enchanted oven!", C_BREE)
				else:
					await say("Bree", "Aww, not quite enough coins. Cheer up some critters and come back!", C_BREE)
			1:
				if coins >= 10:
					Game.add_coins(-10)
					Game.add_item("tea")
					Audio.sfx("coin")
					await say("Bree", "Moon Tea, brewed under a full moon. Sip it in battle for MP!", C_BREE)
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
		0:
			await say("", "The revolving door spins you right back outside. You're way too sleepy for work... Coffee first!", C_SYS)
		1:
			Audio.sfx("ui_cancel")
			await say("Door", "BEEP BOOP. Employee badge not detected. Please present your badge, valued wizard.", C_SYS)
			await say("Mochi", "...{name}. Where is your badge?", C_MOCHI)
			await say("Mochi", "Wait. Yesterday. Petal Park. You were chasing butterflies and I heard a little 'plink'.", C_MOCHI)
			await say("Mochi", "It's probably down by the big trees on the west side of the park. Let's go get it!", C_MOCHI)
			set_q(2)
			m.world.spawn_badge(Vector3(-18, 0, 12))
			m.refresh_markers()
		2:
			await say("Door", "BEEP BOOP. Still no badge. The park is south-west, valued wizard.", C_SYS)
		_:
			Audio.sfx("door")
			await m.load_map("tower", Vector3(0, 0, 12.2))
			if q() == 3:
				await say("Dot", "Oh! Are you the new hire? Over here at reception, sweetie!", C_DOT)


func _stairs() -> void:
	if q() < 5:
		return
	Audio.sfx("door")
	await m.load_map("roof", Vector3(0, 0, 6.8))
	if q() == 5:
		Audio.sfx("alarm")
		await say("The Monday Monster", "RIIIIIING! WHO DARES CLIMB TO MY ROOFTOP?!", C_BOSS)


func _ward() -> void:
	await say("Magic Ward", "A grumpy purple ward crackles in front of the stairs. It's powered by office gremlins.", C_SYS)
	if q() == 4:
		await say("Magic Ward", "Gremlins cheered up: %d / 3" % Game.gremlins_done(), C_SYS)
	elif q() < 4:
		await say("Mochi", "Maybe the receptionist knows what's going on.", C_MOCHI)


func _shard(id: String) -> void:
	if Game.state["shards"].has(id):
		return
	Game.state["shards"].append(id)
	var n: Node3D = m.world.get_node_or_null("Shard_" + id)
	if n:
		Art.burst(m.world, n.global_position, Color("c9a6ff"), 30, "sparkle", 4, 1.0, 0.35)
		n.queue_free()
	for it in m.world.interactables:
		if it["id"] == "shard_" + id:
			m.world.interactables.erase(it)
			break
	Audio.sfx("shard")
	var count: int = Game.state["shards"].size()
	m.ui.toast("Star Shard %d / %d" % [count, Game.SHARD_TOTAL], "shard")
	if count >= Game.SHARD_TOTAL:
		Game.learn("starfall")
		Audio.sfx("level_up")
		await say("", "All five Star Shards glow together and swirl around you...", C_SYS)
		await say("", "You learned STARFALL! It rains stars on every enemy at once.", C_SYS)
	elif count == 1:
		await say("Mochi", "Ooh, a Star Shard! Legend says five of them teach a wizard a secret spell.", C_MOCHI)


func _badge() -> void:
	if q() != 2:
		return
	await say("Mochi", "There's your badge! And... uh oh. A Grumpy Cloud and a Pigeon of Doom are playing keep-away with it.", C_MOCHI)
	await say("Grumpy Cloud", "Hmph! Finders keepers! It's MONDAY and we're GRUMPY!", Color("9a93c9"))
	var ids := ["cloud", "pigeon"]
	if int(Game.state["level"]) >= 2:
		ids.append("shroom")
	var result: String = await m.battle(ids, "park")
	if result != "win":
		return
	for k in ["badge_gang_a", "badge_gang_b"]:
		if m.world.npcs.has(k):
			m.world.npcs[k].queue_free()
			m.world.npcs.erase(k)
	var b: Node3D = m.world.get_node_or_null("Badge")
	if b:
		b.queue_free()
	for it in m.world.interactables:
		if it["id"] == "badge":
			m.world.interactables.erase(it)
			break
	Audio.sfx("coin")
	m.ui.toast("Got your Employee Badge!", "star_gold")
	await say("Mochi", "Got it! Now let's get to work before the boss notices you're late.", C_MOCHI)
	set_q(3)


func after_battle(uid: String) -> void:
	if uid == "" or q() != 4:
		return
	var n := Game.gremlins_done()
	if n < 3:
		m.ui.toast("Office gremlins cheered up: %d / 3" % n, "star_gold")
		return
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
	await say("Mochi", "The stairs to the roof are open. The Monday Monster is up there. Maybe nap or grab a latte first?", C_MOCHI)
	set_q(5)


# ================================================================ people
func _mochi() -> void:
	var lines := {
		0: "Coffee first, then work. That's the ancient law. (The cafe is the big mushroom!)",
		1: "Spellwork Tower is the tall purple one with the glowing ring. Go go go!",
		2: "Your badge should be in the west side of Petal Park. Grandpa Merlo hangs out there too.",
		3: "Badge acquired. Tower time!",
		4: "Office gremlins wander the blue carpet. Hit them with the right element and they get dizzy!",
		5: "Every few turns, the Monday Monster charges a giant alarm. Guard with perfect timing!",
	}
	await say("Mochi", lines.get(q(), "You saved Monday?! I'm impressed. Here, have a slow blink."), C_MOCHI)
	var c := await ask("Mochi", "Mochi looks at you expectantly.", ["Pet Mochi", "Leave her be"], C_MOCHI)
	if c == 0:
		Audio.sfx("purr")
		Art.burst(m.world, m.follower.position + Vector3(0, 0.8, 0), Color("ff9fc4"), 10, "heart", 1.5, 1.2, 0.3, Vector3(0, 1.5, 0))
		await say("Mochi", ["Purrrrrr...", "Mrrp! ...Okay, that was acceptable.", "Purr. You may continue. For science."].pick_random(), C_MOCHI)


func _pip() -> void:
	await say("Pip the Postowl", ["Hoo! Special delivery for... {name}? Oh wait, no. It's for Mochi. Catnip. Again.",
		"Hoo hoo! Enchanted mail moves at the speed of wings! Unless it's raining. Then it's soggy.",
		"Did you know the cafe fairy bakes muffins with actual moonlight? Very healthy. Probably."].pick_random(), Color("c9906a"))


func _sparkle() -> void:
	await say("Sparkle", ["Ugh, the 8:15 sky-tram is late AGAIN.",
		"I'm a certified accountant. Horn-tified. ...Heh. Sorry.",
		"Rush hour in Moonbrook is wild. Yesterday a broom cut me off!"].pick_random(), Color("c38bff"))


func _reginald() -> void:
	await say("Sir Reginald", ["I slew three dragons before breakfast! ...Just kidding. I do spreadsheets now. Dragon-themed spreadsheets.",
		"A knight's armor is great for jousting. Terrible for the sky-tram turnstile.",
		"Mondays are the true final boss, young wizard."].pick_random(), Color("8f9bb8"))


func _merlo() -> void:
	if not Game.flag("frost") and q() >= 1:
		await say("Grandpa Merlo", "Ho ho! A young wizard! Back in my day we fought DRAGONS. Now the dragons work in HR.", C_MERLO)
		await say("Grandpa Merlo", "Let me teach you something useful. Watch closely... FROST BLOOM!", C_MERLO)
		Game.learn("frost")
		Game.set_flag("frost")
		Audio.sfx("ice")
		m.ui.toast("Learned Frost Bloom!", "ice")
		await say("Grandpa Merlo", "Birds and buzzy things hate the cold. Every critter has a weakness: Fire, Ice or Sparkle.", C_MERLO)
		await say("Grandpa Merlo", "Hit a weakness and they get dizzy for a turn. Watch the little icon above their heads!", C_MERLO)
		return
	var tips := [
		"Tip: when the pink ring shrinks onto the circle, press right as it lines up for a PERFECT hit!",
		"Tip: when a critter lunges at you, press A as it arrives to guard. A perfect guard blocks everything!",
		"Tip: 'Charging up!' above a critter means a big attack next turn. Get ready to guard!",
		"Tip: Guarding restores a little MP. Patience is a spell too.",
		"Tip: there are five Star Shards hidden around town and the tower. Collect them all!",
	]
	var i := int(Game.state["flags"].get("merlo_tip", 0))
	Game.set_flag("merlo_tip", (i + 1) % tips.size())
	await say("Grandpa Merlo", tips[i % tips.size()], C_MERLO)


func _marina() -> void:
	await say("Marina", ["I work from home. Well, from pond. The wifi is surprisingly good down here.",
		"If you see a shiny Star Shard, grab it! I saw one twinkling on the far side of my pond.",
		"The fountain crystal keeps the pond warm. Perfect for mermaid meetings."].pick_random(), Color("5fd6c9"))


func _dot() -> void:
	match q():
		3:
			await say("Dot", "Thank goodness you're here! I'm Dot, reception dragon. Welcome to Spellwork Tower!", C_DOT)
			await say("Dot", "Bad news, sweetie. Someone left the Enchanted Alarm Clock on all weekend...", C_DOT)
			await say("Dot", "It soaked up ALL the Monday grumpiness in the city and became... THE MONDAY MONSTER!", C_DOT)
			await say("Dot", "It sealed itself on the rooftop behind a magic ward. Three office gremlins are powering it.", C_DOT)
			await say("Dot", "They're the sparkly ones wandering the blue carpet. Cheer up all three and the ward should pop!", C_DOT)
			set_q(4)
		4:
			await say("Dot", "Gremlins cheered up: %d / 3. You've got this, {name}!" % Game.gremlins_done(), C_DOT)
		5:
			await say("Dot", "The ward is down! Go get 'em! (Maybe take a nap or grab a latte first. Just saying.)", C_DOT)
		6:
			await say("Dot", "Employee of the month! No, of the CENTURY! I made you a sparkly badge.", C_DOT)
		_:
			await say("Dot", "Welcome to Spellwork Tower, where magic means business!", C_DOT)


func _fern() -> void:
	await say("Fern", "Hi, new person! I'm Fern from Accounts Enchantable.", Color("5fc9a8"))
	var lines := {
		4: "The gremlins hide under the desks. Paperwork hates Fire, Coffee hates Ice, and the Printer... just needs Sparkle.",
		5: "The ward's down?! You're a legend. I'd help, but I have a two o'clock.",
		6: "Lunch is on me today! Honestly, lunch is on me forever.",
	}
	await say("Fern", lines.get(q(), "Facilities says the blue carpet is 'enchanted'. I say it's haunted."), Color("5fc9a8"))


func _ghost() -> void:
	await say("Boo-b the Intern", "Boo! ...Sorry, force of habit.", Color("b8b8e0"))
	if q() < 6:
		await say("Boo-b the Intern", "Hot tip: the Monday Monster is weak to Ice. But when it gets angry, it overheats. Then try Fire!", Color("b8b8e0"))
	else:
		await say("Boo-b the Intern", "Now that it's quiet up here I can finally haunt in peace. Thanks, {name}!", Color("b8b8e0"))


# ================================================================ boss
func _boss() -> void:
	var c := await ask("The Monday Monster", "RIIIING! NO. MORE. WEEKENDS. EVERY DAY IS MONDAY NOW!!", ["Fight!", "Not yet (heal up first)"], C_BOSS)
	if c != 0:
		return
	var result: String = await m.battle(["monday"], "boss")
	if result != "win":
		return
	set_q(6)
	var boss: Node3D = m.world.npcs.get("boss")
	var pos := Vector3(0, 0, -4.2)
	if boss:
		pos = boss.position
		boss.queue_free()
		m.world.npcs.erase("boss")
	for it in m.world.interactables:
		if it["id"] == "boss":
			m.world.interactables.erase(it)
			break
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


# ============================================================ new friends
func _gus() -> void:
	await say("Gus the Gnome", ["I've been coming here for 300 years. The muffins used to cost one acorn.",
		"Psst. If you're low on MP, Moon Tea is the secret. Bree brews it under a full moon.",
		"My beard? Enchanted. It keeps my coffee warm."].pick_random(), Color("e05a5a"))


func _nyx() -> void:
	await say("Nyx", ["I'm a bat, so technically this is my breakfast. It's 7 p.m. for me.",
		"Have you tried the Wishing Tree past the stream? Everyone says it grants cozy wishes.",
		"I work night shift at the Library. Professor Hoot knows EVERYTHING. Ask him about spells."].pick_random(), Color("8f6ee8"))


func _hoot() -> void:
	if not Game.flag("heal"):
		await say("Professor Hoot", "Hoo! A young wizard in my library! Welcome, welcome. Mind the floating books, they bite. Gently.", Color("c9906a"))
		await say("Professor Hoot", "Every wizard should know how to take care of themselves. Here, let me teach you HEAL GLOW.", Color("c9906a"))
		Game.learn("heal")
		Game.set_flag("heal")
		Audio.sfx("heal")
		m.ui.toast("Learned Heal Glow!", "hp")
		await say("Professor Hoot", "Time your casting when the ring meets the circle, and it heals even more. Hoo hoo!", Color("c9906a"))
		return
	await say("Professor Hoot", ["The Monday Monster was once a humble alarm clock. Grumpiness is a powerful magic, you know.",
		"Legend says five Star Shards together teach the Starfall spell. One is hiding in this very library!",
		"Fire melts paper and clouds, Ice chills bugs and birds, Sparkle soothes machines. Write that down!"].pick_random(), Color("c9906a"))


func _velour() -> void:
	await say("Madame Velour", "Bienvenue, darling! Every hero deserves a signature look.", Color("e05aa8"))
	await say("Madame Velour", "Step up to the magic mirror and try anything you like. First fitting is free. So are all the others.", Color("e05aa8"))


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


func _thistle() -> void:
	if not Game.flag("thistle_gift"):
		await say("Nana Thistle", "Oh, hello dearie. I'm knitting a scarf for the Wishing Tree. It gets chilly at night.", Color("c38bff"))
		await say("Nana Thistle", "You look like you work too hard. Take some of my Moon Tea, I always brew too much.", Color("c38bff"))
		Game.add_item("tea", 2)
		Game.set_flag("thistle_gift")
		Audio.sfx("coin")
		m.ui.toast("Got 2 Moon Teas", "tea")
		return
	await say("Nana Thistle", ["Knit one, purl two... sparkle three.", "Back in my day, critters were grumpy on Tuesdays too.",
		"Visit the Wishing Tree past the stream, dearie. It likes company."].pick_random(), Color("c38bff"))


func _poppy() -> void:
	await say("Poppy", ["I'm the head gardener! The hedge garden took me three hundred naps to grow.",
		"The flowers glow at night if you sing to them. Off-key is fine!",
		"Grumpy critters love flower beds. Swing your wand at them first for a First Strike!"].pick_random(), Color("7cc97a"))


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
