extends Node
## Global game state, data tables and save/load.

# ------------------------------------------------------------------
# 💌 Personalize the game here!
const DEFAULT_NAME := "Luna"
const LOVE_NOTE := "Thank you for being my favorite adventurer.\nOn Mondays and every other day. I love you!"
# ------------------------------------------------------------------

signal stats_changed

const SAVE_PATH := "user://fantasy_forever_save_v2.json"

const STYLES := ["witch", "fairy", "elf"]
const STYLE_NAMES := {"witch": "Witch", "fairy": "Fairy", "elf": "Elf"}
const ROBE_COLORS := [Color("8f6ee8"), Color("ff8fb8"), Color("5fc9a8"), Color("5b8def"), Color("ffb347"), Color("e8e3f7")]
const HAIR_COLORS := [Color("6b4a3a"), Color("f5d47a"), Color("ff9fc4"), Color("3a2c4a"), Color("c2e0ff")]

const ELEMENT_NAMES := {"fire": "Fire", "ice": "Ice", "arcane": "Sparkle"}
const ELEMENT_COLORS := {"fire": Color("ff8a4c"), "ice": Color("7cc8ff"), "arcane": Color("ff8fd8"), "none": Color("ffffff")}

# Real-time skills. Slot order = button order.
const SKILL_ORDER := ["flame", "frost", "heal", "starfall"]
const SKILLS := {
	"flame": {"name": "Flame Petal", "mp": 5, "cd": 2.2, "element": "fire", "icon": "fire",
		"desc": "Throw three fiery petals. Burns critters over time."},
	"frost": {"name": "Frost Bloom", "mp": 6, "cd": 5.0, "element": "ice", "icon": "ice",
		"desc": "An icy ring around you. Freezes critters in place."},
	"heal": {"name": "Heal Glow", "mp": 8, "cd": 9.0, "element": "none", "icon": "hp",
		"desc": "Restore a big chunk of HP."},
	"starfall": {"name": "Starfall", "mp": 14, "cd": 12.0, "element": "arcane", "icon": "star_gold",
		"desc": "Stars rain on every critter nearby and stun them."},
}

const ITEMS := {
	"muffin": {"name": "Pumpkin Muffin", "desc": "Restores 50 HP. (Menu or H key)", "price": 8, "icon": "muffin"},
	"tea": {"name": "Moon Tea", "desc": "Restores 15 MP. (Menu or T key)", "price": 10, "icon": "tea"},
}

# Enemy behaviors: melee (lunge), charger (dash line), shooter (projectiles),
# bomber (marks your spot, then bursts), spinner (area around itself).
const ENEMIES := {
	"cloud": {"name": "Grumpy Cloud", "hp": 40, "dmg": 9, "speed": 2.2, "behavior": "bomber", "weak": "fire",
		"xp": 8, "coins": 3, "calm": "rains a tiny rainbow and floats away happy!"},
	"shroom": {"name": "Sleepy Mushroom", "hp": 45, "dmg": 8, "speed": 1.6, "behavior": "spinner", "weak": "fire",
		"xp": 8, "coins": 3, "calm": "curls up for a peaceful nap."},
	"pigeon": {"name": "Pigeon of Doom", "hp": 30, "dmg": 8, "speed": 3.0, "behavior": "charger", "weak": "ice",
		"xp": 7, "coins": 4, "calm": "coos softly and does a happy dance."},
	"umbrella": {"name": "Lost Umbrella", "hp": 50, "dmg": 9, "speed": 2.4, "behavior": "spinner", "weak": "arcane",
		"xp": 9, "coins": 4, "calm": "hops off to find its owner."},
	"bee": {"name": "Busy Bee", "hp": 28, "dmg": 7, "speed": 3.4, "behavior": "melee", "weak": "ice",
		"xp": 7, "coins": 3, "calm": "buzzes back to its flower."},
	"paper": {"name": "Paperwork Imp", "hp": 70, "dmg": 12, "speed": 2.4, "behavior": "shooter", "weak": "fire",
		"xp": 14, "coins": 6, "calm": "gets signed and flutters away, fulfilled."},
	"coffee": {"name": "Coffee Slime", "hp": 90, "dmg": 12, "speed": 1.8, "behavior": "bomber", "weak": "ice",
		"xp": 15, "coins": 6, "calm": "becomes a lovely iced latte."},
	"clip": {"name": "Paperclip Poltergeist", "hp": 60, "dmg": 14, "speed": 3.2, "behavior": "charger", "weak": "arcane",
		"xp": 14, "coins": 7, "calm": "straightens out and feels much better."},
	"printer": {"name": "Printer Golem", "hp": 110, "dmg": 13, "speed": 1.6, "behavior": "shooter", "weak": "arcane",
		"xp": 17, "coins": 8, "calm": "prints you a thank-you card."},
	"email": {"name": "Reply-All Wraith", "hp": 75, "dmg": 12, "speed": 2.8, "behavior": "melee", "weak": "fire",
		"xp": 15, "coins": 7, "calm": "unsubscribes itself peacefully."},
	"tick": {"name": "Tick-Tock", "hp": 35, "dmg": 10, "speed": 3.4, "behavior": "melee", "weak": "ice",
		"xp": 4, "coins": 1, "calm": "stops ticking and yawns."},
	"printer_king": {"name": "The Printer King", "hp": 900, "dmg": 16, "speed": 1.8, "behavior": "boss", "weak": "arcane",
		"xp": 90, "coins": 50, "calm": "finally finishes printing... a paper crown for you."},
	"monday": {"name": "The Monday Monster", "hp": 2400, "dmg": 18, "speed": 2.4, "behavior": "boss", "weak": "ice",
		"xp": 200, "coins": 100, "calm": "yawns and turns back into a sleepy little clock."},
}

const PARK_POOL := ["cloud", "shroom", "pigeon", "umbrella", "bee"]
const OFFICE_POOL := ["paper", "coffee", "clip", "printer", "email"]
const FRIENDBOOK := ["cloud", "shroom", "pigeon", "umbrella", "bee", "paper", "coffee", "clip", "printer", "email",
	"tick", "printer_king", "monday"]
const SHARD_TOTAL := 5

const PERKS := {
	"sparkle_edge": {"name": "Sparkle Edge", "desc": "Wand hits deal +20% damage.", "max": 3},
	"fire_heart": {"name": "Fire Heart", "desc": "Flame Petal deals +30% damage and burns longer.", "max": 2},
	"frost_touch": {"name": "Frost Touch", "desc": "Frost Bloom is 25% bigger and freezes longer.", "max": 2},
	"quick_step": {"name": "Quick Step", "desc": "Your dash recharges 35% faster.", "max": 2},
	"star_trail": {"name": "Star Trail", "desc": "Dashing leaves a trail of stinging sparkles.", "max": 1},
	"big_heart": {"name": "Big Heart", "desc": "+25 max HP.", "max": 3},
	"deep_pockets": {"name": "Deep Pockets", "desc": "+8 max MP.", "max": 3},
	"mana_bloom": {"name": "Mana Bloom", "desc": "Wand hits restore 1 more MP.", "max": 2},
	"mochi_power": {"name": "Mochi Power", "desc": "Mochi pounces more often and harder.", "max": 2},
	"lucky_star": {"name": "Lucky Star", "desc": "+50% coins and more muffin drops.", "max": 2},
	"cozy_regen": {"name": "Cozy Regen", "desc": "Regenerate HP twice as fast when safe.", "max": 1},
	"crit": {"name": "Crit Sparkle", "desc": "12% chance to deal double damage.", "max": 2},
	"swift": {"name": "Swift Shoes", "desc": "Move 12% faster.", "max": 2},
}

# Main quest chapters.
const QUESTS := [
	{"title": "A Cozy Morning", "goal": "Get a Moonbeam Latte from Bree at the Bubbling Cauldron"},
	{"title": "Wand Practice", "goal": "Find Grandpa Merlo in Petal Park"},
	{"title": "Wand Practice", "goal": "Cheer up grumpy critters in Petal Park (%d/5)"},
	{"title": "First Day", "goal": "Head to Spellwork Tower"},
	{"title": "The Missing Badge", "goal": "Get your badge back in west Petal Park"},
	{"title": "First Day Jitters", "goal": "Report to Dot at the tower reception"},
	{"title": "Gremlin Trouble", "goal": "Cheer up the 3 sparkly office gremlins (%d/3)"},
	{"title": "Paper Jam", "goal": "Defeat the Printer King guarding the stairs"},
	{"title": "The Monday Monster", "goal": "Climb to the rooftop and face the Monday Monster"},
	{"title": "Happily Ever Friday", "goal": "You saved Monday! Finish side quests and fill your Friendbook"},
]

# Side quests: giver, goal text, how many things to do, reward text.
const SIDE_QUESTS := {
	"books": {"title": "Runaway Books", "giver": "Professor Hoot", "goal": "Catch the runaway library books (%d/4)",
		"need": 4, "reward": "+6 max MP and 30 coins"},
	"yarn": {"title": "Nana's Yarn", "giver": "Nana Thistle", "goal": "Find Nana's lost yarn balls (%d/5)",
		"need": 5, "reward": "Cozy Scarf: +20 max HP"},
	"garden": {"title": "Garden Guard", "giver": "Poppy", "goal": "Cheer up critters trampling the park (%d/8)",
		"need": 8, "reward": "Flower Crown: +3 power, 3 muffins"},
	"pearl": {"title": "Marina's Pearl", "giver": "Marina", "goal": "Find Marina's pearl near the stream",
		"need": 1, "reward": "3 Moon Teas and faster MP regen"},
	"shards": {"title": "Star Shards", "giver": "Legend", "goal": "Collect the Star Shards (%d/5)",
		"need": 5, "reward": "The Starfall spell"},
}

var state: Dictionary = {}
var combat: Combat


func _ready() -> void:
	_setup_input()


func _setup_input() -> void:
	var keys := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"confirm": [KEY_SPACE, KEY_ENTER, KEY_E, KEY_KP_ENTER],
		"cancel": [KEY_ESCAPE, KEY_BACKSPACE, KEY_M, KEY_TAB],
		"attack": [KEY_J, KEY_Z],
		"dash": [KEY_K, KEY_SHIFT, KEY_X],
		"skill1": [KEY_1, KEY_U], "skill2": [KEY_2, KEY_I], "skill3": [KEY_3, KEY_O], "skill4": [KEY_4, KEY_L],
		"use_muffin": [KEY_H], "use_tea": [KEY_T],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.3)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	var mouse := {"attack": MOUSE_BUTTON_LEFT, "dash": MOUSE_BUTTON_RIGHT}
	for action in mouse:
		var mb := InputEventMouseButton.new()
		mb.button_index = mouse[action]
		InputMap.action_add_event(action, mb)
	var pads := {"confirm": JOY_BUTTON_A, "cancel": JOY_BUTTON_START, "attack": JOY_BUTTON_X, "dash": JOY_BUTTON_B,
		"skill1": JOY_BUTTON_Y, "skill2": JOY_BUTTON_LEFT_SHOULDER, "skill3": JOY_BUTTON_RIGHT_SHOULDER}
	for action in pads:
		var jb := InputEventJoypadButton.new()
		jb.button_index = pads[action]
		InputMap.action_add_event(action, jb)
	var axes := {"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0], "skill4": [JOY_AXIS_TRIGGER_RIGHT, 1.0]}
	for action in axes:
		var jm := InputEventJoypadMotion.new()
		jm.axis = axes[action][0]
		jm.axis_value = axes[action][1]
		InputMap.action_add_event(action, jm)


# ------------------------------------------------------------------ state
func new_game(hero_name: String, style: String, robe: int, hair: int) -> void:
	state = {
		"name": hero_name, "style": style, "robe": robe, "hair": hair,
		"level": 1, "xp": 0, "hp": 60, "max_hp": 60, "mp": 24, "max_mp": 24, "atk": 10,
		"coins": 10, "items": {"muffin": 2, "tea": 1}, "spells": [],
		"quest": 0, "flags": {}, "shards": [], "friends": {}, "known_weak": {},
		"perks": {}, "pending_perks": 0, "side": {"shards": {"state": "active", "count": 0}},
		"collected": [], "park_calmed": 0,
		"map": "home_in", "pos": [-2.2, -1.2],
	}
	stats_changed.emit()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	if state.is_empty():
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(state))


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	new_game("x", "witch", 0, 0)
	for k in data:
		state[k] = data[k]
	# JSON turns ints into floats; tidy the integer stats back up.
	for k in ["level", "xp", "hp", "max_hp", "mp", "max_mp", "atk", "coins", "quest", "robe", "hair",
			"pending_perks", "park_calmed"]:
		state[k] = int(state[k])
	for dict_key in ["items", "friends", "perks"]:
		for k in state[dict_key]:
			state[dict_key][k] = int(state[dict_key][k])
	for k in state["side"]:
		state["side"][k]["count"] = int(state["side"][k]["count"])
	stats_changed.emit()
	return true


func flag(name: String) -> bool:
	return state["flags"].get(name, false)


func set_flag(name: String, value := true) -> void:
	state["flags"][name] = value


func robe_color() -> Color:
	return ROBE_COLORS[int(state.get("robe", 0)) % ROBE_COLORS.size()]


func hair_color() -> Color:
	return HAIR_COLORS[int(state.get("hair", 0)) % HAIR_COLORS.size()]


# ------------------------------------------------------------------ stats
func heal(hp: int, mp := 0) -> void:
	state["hp"] = clampi(state["hp"] + hp, 0, state["max_hp"])
	state["mp"] = clampi(state["mp"] + mp, 0, state["max_mp"])
	stats_changed.emit()


func full_heal() -> void:
	state["hp"] = state["max_hp"]
	state["mp"] = state["max_mp"]
	stats_changed.emit()


func add_coins(n: int) -> void:
	state["coins"] = max(0, state["coins"] + n)
	stats_changed.emit()


func add_item(id: String, n := 1) -> void:
	state["items"][id] = int(state["items"].get(id, 0)) + n
	stats_changed.emit()


func item_count(id: String) -> int:
	return int(state["items"].get(id, 0))


func learn(spell: String) -> void:
	if not state["spells"].has(spell):
		state["spells"].append(spell)
	stats_changed.emit()


func perk(id: String) -> int:
	return int(state["perks"].get(id, 0))


func add_perk(id: String) -> void:
	state["perks"][id] = perk(id) + 1
	match id:
		"big_heart":
			state["max_hp"] += 25
			state["hp"] += 25
		"deep_pockets":
			state["max_mp"] += 8
			state["mp"] += 8
	stats_changed.emit()


## Three random perks that aren't maxed out yet.
func perk_choices() -> Array:
	var pool: Array = []
	for id in PERKS:
		if perk(id) < int(PERKS[id]["max"]):
			pool.append(id)
	pool.shuffle()
	return pool.slice(0, 3)


func xp_to_next() -> int:
	return 25 * int(state["level"])


## Adds XP and returns how many levels were gained. Each level also grants a perk pick.
func add_xp(n: int) -> int:
	state["xp"] += n
	var gained := 0
	while state["xp"] >= xp_to_next():
		state["xp"] -= xp_to_next()
		state["level"] += 1
		state["max_hp"] += 10
		state["max_mp"] += 3
		state["atk"] += 2
		state["pending_perks"] += 1
		gained += 1
	if gained > 0:
		full_heal()
	stats_changed.emit()
	return gained


# ------------------------------------------------------------ quests
func objective() -> String:
	var q := int(state.get("quest", 0))
	if q >= QUESTS.size():
		return ""
	var goal: String = QUESTS[q]["goal"]
	match q:
		2: return goal % mini(5, int(state["park_calmed"]))
		6: return goal % gremlins_done()
	return goal


func chapter_title() -> String:
	var q := clampi(int(state.get("quest", 0)), 0, QUESTS.size() - 1)
	return QUESTS[q]["title"]


func gremlins_done() -> int:
	var n := 0
	for id in ["g1", "g2", "g3"]:
		if flag("beat_" + id):
			n += 1
	return n


func side_state(id: String) -> String:
	return String(state["side"].get(id, {}).get("state", "none"))


func side_count(id: String) -> int:
	return int(state["side"].get(id, {}).get("count", 0))


func start_side(id: String) -> void:
	if not state["side"].has(id):
		state["side"][id] = {"state": "active", "count": 0}


## Adds progress to an active side quest. Returns true when it just became ready to turn in.
func side_progress(id: String, n := 1) -> bool:
	if side_state(id) != "active":
		return false
	state["side"][id]["count"] = side_count(id) + n
	if side_count(id) >= int(SIDE_QUESTS[id]["need"]):
		state["side"][id]["state"] = "ready"
		return true
	return false


func finish_side(id: String) -> void:
	state["side"][id]["state"] = "done"


func side_goal(id: String) -> String:
	var g: String = SIDE_QUESTS[id]["goal"]
	return g % side_count(id) if g.contains("%d") else g
