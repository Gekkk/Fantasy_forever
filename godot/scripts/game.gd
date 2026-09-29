extends Node
## Global game state, data tables and save/load.

# ------------------------------------------------------------------
# 💌 Personalize the game here!
const DEFAULT_NAME := "Luna"
const LOVE_NOTE := "Thank you for being my favorite adventurer.\nOn Mondays and every other day. I love you!"
# ------------------------------------------------------------------

signal stats_changed

const SAVE_PATH := "user://fantasy_forever_save.json"

const STYLES := ["witch", "fairy", "elf"]
const STYLE_NAMES := {"witch": "Witch", "fairy": "Fairy", "elf": "Elf"}
const ROBE_COLORS := [Color("8f6ee8"), Color("ff8fb8"), Color("5fc9a8"), Color("5b8def"), Color("ffb347"), Color("e8e3f7")]
const HAIR_COLORS := [Color("6b4a3a"), Color("f5d47a"), Color("ff9fc4"), Color("3a2c4a"), Color("c2e0ff")]

const ELEMENT_NAMES := {"fire": "Fire", "ice": "Ice", "arcane": "Sparkle"}
const ELEMENT_COLORS := {"fire": Color("ff8a4c"), "ice": Color("7cc8ff"), "arcane": Color("ff8fd8"), "none": Color("ffffff")}

# Spells the hero can learn. power multiplies attack.
const SPELLS := {
	"sparkle": {"name": "Sparkle Burst", "mp": 3, "power": 1.5, "element": "arcane", "target": "one",
		"desc": "A burst of pink stars."},
	"flame": {"name": "Flame Petal", "mp": 4, "power": 1.7, "element": "fire", "target": "one",
		"desc": "Warm, fiery flower petals."},
	"frost": {"name": "Frost Bloom", "mp": 4, "power": 1.7, "element": "ice", "target": "one",
		"desc": "A blooming crystal of ice."},
	"heal": {"name": "Heal Glow", "mp": 4, "power": 0.0, "element": "none", "target": "self",
		"desc": "Restores lots of HP."},
	"starfall": {"name": "Starfall", "mp": 9, "power": 1.3, "element": "arcane", "target": "all",
		"desc": "Stars rain on every enemy."},
}

const ITEMS := {
	"muffin": {"name": "Pumpkin Muffin", "desc": "Restores 40 HP.", "price": 8, "icon": "muffin"},
	"tea": {"name": "Moon Tea", "desc": "Restores 12 MP.", "price": 10, "icon": "tea"},
}

# Enemy moves: p = power (x atk), charge = telegraphed a turn ahead, drain = MP stolen.
const ENEMIES := {
	"cloud": {"name": "Grumpy Cloud", "hp": 26, "atk": 6, "xp": 9, "coins": 4, "weak": "fire", "area": "park",
		"moves": [{"n": "Drizzle", "p": 1.0}, {"n": "Thunder Tickle", "p": 2.0, "charge": true}],
		"calm": "rains a tiny rainbow and floats away happy!"},
	"shroom": {"name": "Sleepy Mushroom", "hp": 22, "atk": 5, "xp": 8, "coins": 3, "weak": "fire", "area": "park",
		"moves": [{"n": "Spore Sneeze", "p": 1.0}, {"n": "Mega Yawn", "p": 0.4, "drain": 3}],
		"calm": "curls up for a peaceful nap."},
	"pigeon": {"name": "Pigeon of Doom", "hp": 18, "atk": 7, "xp": 8, "coins": 5, "weak": "ice", "area": "park",
		"moves": [{"n": "Peck", "p": 1.0}, {"n": "Sandwich Heist", "p": 0.8}],
		"calm": "coos softly and does a happy dance."},
	"umbrella": {"name": "Lost Umbrella", "hp": 30, "atk": 5, "xp": 10, "coins": 5, "weak": "arcane", "area": "park",
		"moves": [{"n": "Pointy Poke", "p": 1.0}, {"n": "Spin Splash", "p": 1.3}],
		"calm": "hops off to find its owner."},
	"bee": {"name": "Busy Bee", "hp": 20, "atk": 7, "xp": 9, "coins": 4, "weak": "ice", "area": "park",
		"moves": [{"n": "Stinger Boop", "p": 1.0}, {"n": "Waggle Dance", "p": 2.0, "charge": true}],
		"calm": "buzzes back to its flower."},
	"paper": {"name": "Paperwork Imp", "hp": 38, "atk": 8, "xp": 16, "coins": 7, "weak": "fire", "area": "office",
		"moves": [{"n": "Papercut", "p": 1.0}, {"n": "Triplicate Form", "p": 2.0, "charge": true}],
		"calm": "gets signed and flutters away, fulfilled."},
	"coffee": {"name": "Coffee Slime", "hp": 44, "atk": 8, "xp": 17, "coins": 7, "weak": "ice", "area": "office",
		"moves": [{"n": "Decaf Splash", "p": 1.0}, {"n": "Caffeine Jitters", "p": 1.3}],
		"calm": "becomes a lovely iced latte."},
	"clip": {"name": "Paperclip Poltergeist", "hp": 34, "atk": 10, "xp": 16, "coins": 8, "weak": "arcane", "area": "office",
		"moves": [{"n": "Clip!", "p": 1.0}, {"n": "Helpful Suggestion", "p": 0.5, "drain": 3}],
		"calm": "straightens out and feels much better."},
	"printer": {"name": "Printer Golem", "hp": 50, "atk": 9, "xp": 19, "coins": 9, "weak": "arcane", "area": "office",
		"moves": [{"n": "Paper Jam", "p": 1.0}, {"n": "PC LOAD LETTER", "p": 2.0, "charge": true}],
		"calm": "prints you a thank-you card."},
	"email": {"name": "Reply-All Wraith", "hp": 40, "atk": 9, "xp": 17, "coins": 8, "weak": "fire", "area": "office",
		"moves": [{"n": "Reply All", "p": 1.0}, {"n": "Surprise Meeting", "p": 0.6, "drain": 4}],
		"calm": "unsubscribes itself peacefully."},
	"monday": {"name": "The Monday Monster", "hp": 260, "atk": 11, "xp": 120, "coins": 60, "weak": "ice", "area": "boss",
		"moves": [{"n": "Snooze Slam", "p": 1.0}, {"n": "Monday Mist", "p": 0.6, "drain": 4},
			{"n": "RIIIIING!!", "p": 2.2, "charge": true}],
		"calm": "yawns and turns back into a sleepy little clock."},
}

const PARK_POOL := ["cloud", "shroom", "pigeon", "umbrella", "bee"]
const OFFICE_POOL := ["paper", "coffee", "clip", "printer", "email"]
const SHARD_TOTAL := 5

var state: Dictionary = {}


func _ready() -> void:
	_setup_input()


func _setup_input() -> void:
	var keys := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"confirm": [KEY_SPACE, KEY_ENTER, KEY_Z, KEY_E, KEY_KP_ENTER],
		"cancel": [KEY_ESCAPE, KEY_X, KEY_BACKSPACE, KEY_M],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.3)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	var pads := {"confirm": JOY_BUTTON_A, "cancel": JOY_BUTTON_B}
	for action in pads:
		var jb := InputEventJoypadButton.new()
		jb.button_index = pads[action]
		InputMap.action_add_event(action, jb)
	var axes := {"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0]}
	for action in axes:
		var jm := InputEventJoypadMotion.new()
		jm.axis = axes[action][0]
		jm.axis_value = axes[action][1]
		InputMap.action_add_event(action, jm)


# ------------------------------------------------------------------ state
func new_game(hero_name: String, style: String, robe: int, hair: int) -> void:
	state = {
		"name": hero_name, "style": style, "robe": robe, "hair": hair,
		"level": 1, "xp": 0, "hp": 40, "max_hp": 40, "mp": 14, "max_mp": 14, "atk": 8, "def": 2,
		"coins": 10, "items": {"muffin": 1, "tea": 0}, "spells": ["sparkle"],
		"quest": 0, "flags": {}, "shards": [], "friends": {}, "known_weak": {},
		"map": "city", "pos": [-13.0, 0.0, -5.0], "tutorial_timing": 0,
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
	for k in ["level", "xp", "hp", "max_hp", "mp", "max_mp", "atk", "def", "coins", "quest", "robe", "hair", "tutorial_timing"]:
		state[k] = int(state[k])
	for k in state["items"]:
		state["items"][k] = int(state["items"][k])
	for k in state["friends"]:
		state["friends"][k] = int(state["friends"][k])
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


func xp_to_next() -> int:
	return 20 * int(state["level"])


## Adds XP and returns how many levels were gained.
func add_xp(n: int) -> int:
	state["xp"] += n
	var gained := 0
	while state["xp"] >= xp_to_next():
		state["xp"] -= xp_to_next()
		state["level"] += 1
		state["max_hp"] += 10
		state["max_mp"] += 3
		state["atk"] += 2
		state["def"] += 1
		gained += 1
	if gained > 0:
		full_heal()
	stats_changed.emit()
	return gained


func objective() -> String:
	match int(state.get("quest", 0)):
		0: return "Grab a Moonbeam Latte at the Bubbling Cauldron cafe"
		1: return "Head to Spellwork Tower for your first day"
		2: return "Find your lost badge in Petal Park"
		3: return "Enter Spellwork Tower and report to reception"
		4: return "Cheer up the 3 office gremlins (%d/3)" % gremlins_done()
		5: return "Climb to the rooftop and face the Monday Monster"
		_: return "You saved Monday! Explore and fill your Friendbook"


func gremlins_done() -> int:
	var n := 0
	for id in ["g1", "g2", "g3"]:
		if flag("beat_" + id):
			n += 1
	return n
