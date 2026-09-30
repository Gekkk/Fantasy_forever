class_name Rpg
extends RefCounted
## Character building: attributes, the skill tree (active skills with ranks
## plus passive talents), equipment with rarities and random bonuses, and
## the derived combat stats they all feed into (see recalc()).

# ============================================================ attributes
const ATTRS := ["str", "int", "vit", "agi", "luk"]
const ATTR_INFO := {
	"str": {"name": "Strength", "icon": "str", "desc": "+2 wand power"},
	"int": {"name": "Intellect", "icon": "int", "desc": "+2.5 spell power, +4 max MP"},
	"vit": {"name": "Vitality", "icon": "vit", "desc": "+12 max HP, +1 defense"},
	"agi": {"name": "Agility", "icon": "agi", "desc": "Faster moves, swings and dashes"},
	"luk": {"name": "Luck", "icon": "luk", "desc": "+1% critical hits, better loot"},
}
const ATTR_PER_LEVEL := 3
const SKILL_POINTS_PER_LEVEL := 2

# ================================================================ skills
## Active skills. Story skills are taught by people in town; the others
## are bought with skill points once you reach their level.
const ACTIVES := {
	"flame": {"name": "Flame Petal", "icon": "fire", "element": "fire", "mp": 5, "cd": 2.2, "max": 5, "req": 1, "story": true,
		"desc": "Throw fiery petals that burn critters.", "per": "+25% damage, +1 petal every 2 ranks"},
	"frost": {"name": "Frost Bloom", "icon": "ice", "element": "ice", "mp": 6, "cd": 5.0, "max": 5, "req": 1, "story": true,
		"desc": "An icy ring that freezes everything around you.", "per": "+20% damage, bigger ring, longer freeze"},
	"heal": {"name": "Heal Glow", "icon": "hp", "element": "none", "mp": 8, "cd": 9.0, "max": 5, "req": 1, "story": true,
		"desc": "Restore a big chunk of HP.", "per": "+6% healing, -0.8s cooldown"},
	"starfall": {"name": "Starfall", "icon": "star_gold", "element": "arcane", "mp": 14, "cd": 12.0, "max": 5, "req": 1, "story": true,
		"desc": "Stars rain on every critter nearby and stun them.", "per": "+30% damage, +2 stars"},
	"bolt": {"name": "Sparkle Bolt", "icon": "bolt", "element": "arcane", "mp": 3, "cd": 0.9, "max": 5, "req": 2,
		"desc": "A fast bolt that pierces through critters.", "per": "+25% damage, pierces one more"},
	"blink": {"name": "Moon Step", "icon": "moon", "element": "arcane", "mp": 4, "cd": 5.0, "max": 3, "req": 3,
		"desc": "Teleport forward in a moonlit burst. You can't be hit mid-step.", "per": "-1s cooldown, +40% burst damage"},
	"thunder": {"name": "Thunder Bell", "icon": "thunder", "element": "arcane", "mp": 9, "cd": 6.0, "max": 5, "req": 4,
		"desc": "Lightning chains between critters and stuns them.", "per": "+25% damage, +1 chain"},
	"shield": {"name": "Petal Shield", "icon": "shield", "element": "none", "mp": 10, "cd": 14.0, "max": 5, "req": 5,
		"desc": "A barrier that soaks up damage for 6 seconds.", "per": "Absorbs +10% of max HP more"},
}
const ACTIVE_ORDER := ["flame", "frost", "heal", "starfall", "bolt", "blink", "thunder", "shield"]

## Passive talents (the old level-up perks, now bought with skill points).
const TALENTS := {
	"sparkle_edge": {"name": "Sparkle Edge", "desc": "Wand hits deal +20% damage.", "max": 3, "req": 1},
	"mana_bloom": {"name": "Mana Bloom", "desc": "Wand hits restore 1 more MP.", "max": 2, "req": 1},
	"big_heart": {"name": "Big Heart", "desc": "+25 max HP.", "max": 3, "req": 1},
	"deep_pockets": {"name": "Deep Pockets", "desc": "+8 max MP.", "max": 3, "req": 1},
	"iron_skin": {"name": "Iron Skin", "desc": "+8 defense.", "max": 3, "req": 2},
	"swift": {"name": "Swift Shoes", "desc": "Move 12% faster.", "max": 2, "req": 2},
	"fire_heart": {"name": "Fire Heart", "desc": "Fire skills +30% damage, burns last longer.", "max": 2, "req": 2},
	"frost_touch": {"name": "Frost Touch", "desc": "Ice skills 25% bigger, freezes last longer.", "max": 2, "req": 2},
	"quick_step": {"name": "Quick Step", "desc": "Dash recharges 35% faster.", "max": 2, "req": 3},
	"crit": {"name": "Crit Sparkle", "desc": "+12% critical hit chance.", "max": 2, "req": 3},
	"lucky_star": {"name": "Lucky Star", "desc": "+50% coins and more drops.", "max": 2, "req": 3},
	"combo_master": {"name": "Combo Master", "desc": "The 3rd wand hit deals +35% and sends a shockwave.", "max": 2, "req": 4},
	"mochi_power": {"name": "Mochi Power", "desc": "Mochi pounces more often and harder.", "max": 2, "req": 4},
	"cozy_regen": {"name": "Cozy Regen", "desc": "Regenerate HP twice as fast when safe.", "max": 1, "req": 4},
	"star_trail": {"name": "Star Trail", "desc": "Dashing leaves a trail of stinging sparkles.", "max": 1, "req": 5},
}
const TALENT_ORDER := ["sparkle_edge", "mana_bloom", "big_heart", "deep_pockets", "iron_skin", "swift", "fire_heart",
	"frost_touch", "quick_step", "crit", "lucky_star", "combo_master", "mochi_power", "cozy_regen", "star_trail"]

# ============================================================= equipment
const SLOTS := ["wand", "hat", "robe", "charm"]
const SLOT_NAMES := {"wand": "Wand", "hat": "Hat", "robe": "Robe", "charm": "Charm"}
const RARITY := [
	{"name": "Common", "color": Color("d8d0e0"), "affixes": 0},
	{"name": "Rare", "color": Color("6fb8ff"), "affixes": 2},
	{"name": "Epic", "color": Color("c38bff"), "affixes": 3},
	{"name": "Legendary", "color": Color("ffae42"), "affixes": 4},
]
## [name, minimum item level]
const BASES := {
	"wand": [["Twig Wand", 1], ["Willow Wand", 3], ["Crystal Wand", 5], ["Starlight Scepter", 8]],
	"hat": [["Felt Hat", 1], ["Pointy Hat", 3], ["Silver Circlet", 5], ["Moon Crown", 8]],
	"robe": [["Cotton Robe", 1], ["Silk Robe", 3], ["Enchanted Cloak", 5], ["Aurora Gown", 8]],
	"charm": [["Lucky Button", 1], ["Clover Charm", 3], ["Pearl Pendant", 5], ["Star Locket", 8]],
}
## Built-in stats per item level.
const MAIN := {"wand": {"atk": 1.6, "matk": 1.6}, "hat": {"matk": 1.2, "def": 0.8}, "robe": {"hp": 7.0, "def": 1.2}, "charm": {"mp": 2.5}}
const AFFIXES := {
	"str": {"per": 0.55, "fmt": "+%d Strength", "tag": "Mighty"},
	"int": {"per": 0.55, "fmt": "+%d Intellect", "tag": "Wise"},
	"vit": {"per": 0.55, "fmt": "+%d Vitality", "tag": "Sturdy"},
	"agi": {"per": 0.55, "fmt": "+%d Agility", "tag": "Nimble"},
	"luk": {"per": 0.55, "fmt": "+%d Luck", "tag": "Lucky"},
	"atk": {"per": 1.1, "fmt": "+%d Wand Power", "tag": "Sharp"},
	"matk": {"per": 1.1, "fmt": "+%d Spell Power", "tag": "Arcane"},
	"hp": {"per": 5.5, "fmt": "+%d Max HP", "tag": "Hearty"},
	"mp": {"per": 1.8, "fmt": "+%d Max MP", "tag": "Dreamy"},
	"def": {"per": 0.8, "fmt": "+%d Defense", "tag": "Guarded"},
	"crit": {"per": 0.7, "fmt": "+%d%% Critical Hit", "tag": "Keen", "cap": 15},
	"cdr": {"per": 0.7, "fmt": "-%d%% Cooldowns", "tag": "Hasty", "cap": 15},
	"move": {"per": 0.7, "fmt": "+%d%% Move Speed", "tag": "Breezy", "cap": 12},
	"fire": {"per": 2.2, "fmt": "+%d%% Fire Damage", "tag": "Blazing"},
	"ice": {"per": 2.2, "fmt": "+%d%% Ice Damage", "tag": "Frosty"},
	"arcane": {"per": 2.2, "fmt": "+%d%% Sparkle Damage", "tag": "Starry"},
	"mp_hit": {"per": 0.2, "fmt": "+%d MP per Wand Hit", "tag": "Thirsty", "cap": 3},
	"find": {"per": 2.2, "fmt": "+%d%% Item Find", "tag": "Treasure"},
}
const LEGENDARY_NAMES := {
	"wand": ["Monday's Alarm Hand", "Printer King's Quill"],
	"hat": ["Paper Crown of the King", "Nightcap of Sweet Dreams"],
	"robe": ["Weekend Pajamas", "Gown of a Thousand Petals"],
	"charm": ["Mochi's Bell", "Friday Feeling"],
}
const DYES := ["8f6ee8", "ff8fb8", "5fc9a8", "5b8def", "ffb347", "e8e3f7", "ff6b8a", "7cd6ff", "c9a0ff", "ffd36b"]
const BAG_SIZE := 30


static func s() -> Dictionary:
	return Game.state


# ---------------------------------------------------------- new / migrate
static func init_state(st: Dictionary) -> void:
	st["attr"] = {"str": 0, "int": 0, "vit": 0, "agi": 0, "luk": 0}
	st["attr_points"] = 0
	st["skill_points"] = 0
	st["skills"] = {}
	st["slots"] = ["", "", "", ""]
	st["base"] = {"hp": 60, "mp": 24, "atk": 10, "matk": 10}
	st["equip"] = {"wand": {}, "hat": {}, "robe": {}, "charm": {}}
	st["bag"] = []
	var w := make_item("wand", 1, 0)
	w["name"] = "Twig Wand"
	st["equip"]["wand"] = w
	var r := make_item("robe", 1, 0)
	r["name"] = "Cotton Robe"
	st["equip"]["robe"] = r


## Brings a save from before the skill/gear update up to date.
static func migrate(st: Dictionary) -> void:
	if st.has("base"):
		_fix_types(st)
		return
	var old_perks: Dictionary = st.get("perks", {})
	var lvl := int(st.get("level", 1))
	var spells: Array = st.get("spells", [])
	var keep_hp := int(st.get("hp", 60))
	var keep_mp := int(st.get("mp", 24))
	init_state(st)
	st["base"] = {"hp": 60 + 10 * (lvl - 1), "mp": 24 + 3 * (lvl - 1), "atk": 10 + 2 * (lvl - 1), "matk": 10 + 2 * (lvl - 1)}
	# Side-quest rewards that raised stats directly.
	if st.get("side", {}).get("yarn", {}).get("state", "") == "done":
		st["base"]["hp"] += 20
	if st.get("side", {}).get("books", {}).get("state", "") == "done":
		st["base"]["mp"] += 6
	if st.get("side", {}).get("garden", {}).get("state", "") == "done":
		st["base"]["atk"] += 3
	for sid in spells:
		st["skills"][sid] = 1
	var spent := 0
	for pid in old_perks:
		if TALENTS.has(pid):
			st["skills"][pid] = int(old_perks[pid])
			spent += int(old_perks[pid])
	st["attr_points"] = ATTR_PER_LEVEL * (lvl - 1)
	st["skill_points"] = maxi(0, SKILL_POINTS_PER_LEVEL * (lvl - 1) - spent)
	_auto_slots(st)
	recalc()
	st["hp"] = mini(keep_hp, st["max_hp"])
	st["mp"] = mini(keep_mp, st["max_mp"])


static func _fix_types(st: Dictionary) -> void:
	for k in ["attr_points", "skill_points"]:
		st[k] = int(st[k])
	for k in st["attr"]:
		st["attr"][k] = int(st["attr"][k])
	for k in st["skills"]:
		st["skills"][k] = int(st["skills"][k])
	for k in st["base"]:
		st["base"][k] = int(st["base"][k])
	for it in _all_items(st):
		_fix_item(it)


static func _fix_item(it: Dictionary) -> void:
	if it.is_empty():
		return
	for k in ["rarity", "ilvl", "price"]:
		it[k] = int(it[k])
	for k in it["stats"]:
		it["stats"][k] = int(it["stats"][k])


static func _all_items(st: Dictionary) -> Array:
	var out: Array = []
	for slot in SLOTS:
		if not (st["equip"][slot] as Dictionary).is_empty():
			out.append(st["equip"][slot])
	out.append_array(st["bag"])
	return out


# ------------------------------------------------------------- level up
static func on_level_up() -> void:
	s()["base"]["hp"] += 10
	s()["base"]["mp"] += 3
	s()["base"]["atk"] += 2
	s()["base"]["matk"] += 2
	s()["attr_points"] += ATTR_PER_LEVEL
	s()["skill_points"] += SKILL_POINTS_PER_LEVEL


static func add_base(key: String, n: int) -> void:
	s()["base"][key] = int(s()["base"][key]) + n
	recalc()


static func spend_attr(a: String) -> bool:
	if int(s()["attr_points"]) <= 0:
		return false
	s()["attr_points"] -= 1
	s()["attr"][a] = int(s()["attr"][a]) + 1
	recalc()
	return true


static func reset_attrs() -> void:
	var total := 0
	for a in ATTRS:
		total += int(s()["attr"][a])
		s()["attr"][a] = 0
	s()["attr_points"] += total
	recalc()


# ---------------------------------------------------------------- skills
static func rank(id: String) -> int:
	return int(s().get("skills", {}).get(id, 0))


static func max_rank(id: String) -> int:
	return int((ACTIVES[id] if ACTIVES.has(id) else TALENTS[id])["max"])


static func req_level(id: String) -> int:
	return int((ACTIVES[id] if ACTIVES.has(id) else TALENTS[id])["req"])


## Why a skill point can't go into this skill, or "" if it can.
static func cant_raise(id: String) -> String:
	if rank(id) >= max_rank(id):
		return "Maxed"
	if ACTIVES.has(id) and ACTIVES[id].get("story", false) and rank(id) == 0:
		return "Learn in town"
	if int(s()["level"]) < req_level(id):
		return "Level %d" % req_level(id)
	if int(s()["skill_points"]) <= 0:
		return "No points"
	return ""


static func raise(id: String) -> bool:
	if cant_raise(id) != "":
		return false
	s()["skill_points"] -= 1
	s()["skills"][id] = rank(id) + 1
	if ACTIVES.has(id) and rank(id) == 1:
		_learned(id)
	recalc()
	return true


## Story teachers grant rank 1 for free.
static func learn(id: String) -> void:
	if rank(id) == 0:
		s()["skills"][id] = 1
		_learned(id)
	recalc()


static func _learned(id: String) -> void:
	if not s()["spells"].has(id):
		s()["spells"].append(id)
	_auto_slots(s())


static func _auto_slots(st: Dictionary) -> void:
	for sid in ACTIVE_ORDER:
		if int(st["skills"].get(sid, 0)) > 0 and not st["slots"].has(sid):
			var i: int = st["slots"].find("")
			if i >= 0:
				st["slots"][i] = sid


static func set_slot(i: int, sid: String) -> void:
	var slots: Array = s()["slots"]
	var old := slots.find(sid)
	if old >= 0:
		slots[old] = slots[i]
	slots[i] = sid


static func slot_skill(i: int) -> String:
	var slots: Array = s().get("slots", ["", "", "", ""])
	return String(slots[i]) if i < slots.size() else ""


static func skill_cd(sid: String) -> float:
	var cd := float(ACTIVES[sid]["cd"])
	match sid:
		"heal": cd -= 0.8 * (rank(sid) - 1)
		"blink": cd -= 1.0 * (rank(sid) - 1)
	return cd * (1.0 - float(d("cdr")))


static func skill_mp(sid: String) -> int:
	return int(ACTIVES[sid]["mp"])


# ------------------------------------------------------------ equipment
static func make_item(slot: String, ilvl: int, rarity: int) -> Dictionary:
	ilvl = maxi(1, ilvl)
	var bases: Array = BASES[slot]
	var pick: Array = bases[0]
	for b in bases:
		if ilvl >= int(b[1]):
			pick = b
	var stats := {}
	var mul := 1.0 + 0.2 * rarity
	for k in MAIN[slot]:
		stats[k] = maxi(1, int(round(float(MAIN[slot][k]) * (ilvl + 2) * mul)))
	var keys: Array = AFFIXES.keys()
	keys.shuffle()
	var tags: Array = []
	for i in int(RARITY[rarity]["affixes"]):
		var k: String = keys[i]
		var a: Dictionary = AFFIXES[k]
		var v := maxi(1, int(round(float(a["per"]) * (ilvl + 2) * randf_range(0.7, 1.25) * (1.0 + 0.1 * rarity))))
		if a.has("cap"):
			v = mini(v, int(a["cap"]))
		stats[k] = int(stats.get(k, 0)) + v
		tags.append(a["tag"])
	var item_name: String = pick[0]
	if rarity == 3:
		item_name = (LEGENDARY_NAMES[slot] as Array).pick_random()
	elif rarity >= 1 and not tags.is_empty():
		item_name = "%s %s" % [tags[0], pick[0]]
	var it := {"id": str(randi()), "slot": slot, "name": item_name, "rarity": rarity, "ilvl": ilvl, "stats": stats,
		"price": int((12 + ilvl * 6) * (1.0 + rarity * 1.6))}
	if slot == "robe" and rarity >= 1:
		it["dye"] = DYES.pick_random()
	return it


## Random rarity for a drop; `boost` shifts the odds (elites, bosses, luck).
static func roll_rarity(boost := 0.0) -> int:
	var r := randf() * maxf(0.2, 1.0 - boost)
	if r < 0.025:
		return 3
	if r < 0.13:
		return 2
	if r < 0.42:
		return 1
	return 0


static func random_item(ilvl: int, boost := 0.0, min_rarity := 0) -> Dictionary:
	return make_item(SLOTS.pick_random(), ilvl, maxi(min_rarity, roll_rarity(boost)))


static func add_to_bag(it: Dictionary) -> bool:
	if (s()["bag"] as Array).size() >= BAG_SIZE:
		return false
	s()["bag"].append(it)
	return true


static func equip_from_bag(index: int) -> void:
	var bag: Array = s()["bag"]
	if index < 0 or index >= bag.size():
		return
	var it: Dictionary = bag[index]
	var slot: String = it["slot"]
	var old: Dictionary = s()["equip"][slot]
	s()["equip"][slot] = it
	bag.remove_at(index)
	if not old.is_empty():
		bag.insert(index, old)
	recalc()


static func sell_from_bag(index: int) -> int:
	var bag: Array = s()["bag"]
	if index < 0 or index >= bag.size():
		return 0
	var coins := int(int(bag[index]["price"]) / 4)
	bag.remove_at(index)
	Game.add_coins(coins)
	recalc()
	return coins


## A rough "how good is this" number, used to compare and auto-equip.
static func score(it: Dictionary) -> float:
	if it.is_empty():
		return 0.0
	var w := {"atk": 2.0, "matk": 2.0, "hp": 0.35, "mp": 0.8, "def": 1.6, "str": 3.5, "int": 3.5, "vit": 3.5, "agi": 3.0,
		"luk": 2.5, "crit": 3.0, "cdr": 3.0, "move": 2.0, "fire": 0.8, "ice": 0.8, "arcane": 0.8, "mp_hit": 5.0, "find": 0.6}
	var t := 0.0
	for k in it["stats"]:
		t += float(it["stats"][k]) * float(w.get(k, 1.0))
	return t


static func item_lines(it: Dictionary) -> Array:
	var out: Array = []
	for k in it["stats"]:
		var v := int(it["stats"][k])
		if MAIN.get(it["slot"], {}).has(k) and not AFFIXES.has(k):
			continue
		var fmt: String = AFFIXES[k]["fmt"] if AFFIXES.has(k) else "+%d " + k
		out.append(fmt % v)
	return out


static func equip_totals() -> Dictionary:
	var t := {}
	for slot in SLOTS:
		var it: Dictionary = s()["equip"][slot]
		if it.is_empty():
			continue
		for k in it["stats"]:
			t[k] = int(t.get(k, 0)) + int(it["stats"][k])
	return t


## Robe dye from equipment overrides the character-creator color.
static func robe_dye() -> Variant:
	var robe: Dictionary = s().get("equip", {}).get("robe", {})
	if robe.has("dye"):
		return Color(String(robe["dye"]))
	return null


# ---------------------------------------------------------- derived stats
static var _d := {}


static func d(key: String) -> Variant:
	return _d.get(key, 0.0)


static func attr_total(a: String) -> int:
	return int(s()["attr"][a]) + int(equip_totals().get(a, 0))


## Recomputes max HP/MP, wand power and the derived combat stats.
static func recalc() -> void:
	var st := s()
	if not st.has("base"):
		return
	var eq := equip_totals()
	var b: Dictionary = st["base"]
	var at := {}
	for a in ATTRS:
		at[a] = int(st["attr"][a]) + int(eq.get(a, 0))
	st["max_hp"] = int(b["hp"]) + 12 * int(at["vit"]) + int(eq.get("hp", 0)) + 25 * rank("big_heart")
	st["max_mp"] = int(b["mp"]) + 4 * int(at["int"]) + int(eq.get("mp", 0)) + 8 * rank("deep_pockets")
	st["atk"] = int(b["atk"]) + 2 * int(at["str"]) + int(eq.get("atk", 0))
	_d = {
		"atk": st["atk"],
		"matk": int(round(float(b["matk"]) + 2.5 * at["int"] + float(eq.get("matk", 0)))),
		"def": int(at["vit"]) + int(eq.get("def", 0)) + 8 * rank("iron_skin"),
		"crit": 0.05 + 0.01 * at["luk"] + float(eq.get("crit", 0)) / 100.0 + 0.12 * rank("crit"),
		"move": 1.0 + minf(0.3, 0.012 * at["agi"]) + float(eq.get("move", 0)) / 100.0 + 0.12 * rank("swift"),
		"aspd": 1.0 + minf(0.4, 0.02 * at["agi"]),
		"dash": (1.0 - 0.35 * rank("quick_step")) * (1.0 - minf(0.3, 0.015 * at["agi"])),
		"cdr": minf(0.4, float(eq.get("cdr", 0)) / 100.0),
		"fire": 1.0 + float(eq.get("fire", 0)) / 100.0 + 0.3 * rank("fire_heart"),
		"ice": 1.0 + float(eq.get("ice", 0)) / 100.0,
		"arcane": 1.0 + float(eq.get("arcane", 0)) / 100.0,
		"mp_hit": 1 + rank("mana_bloom") + int(eq.get("mp_hit", 0)),
		"find": 1.0 + 0.04 * at["luk"] + float(eq.get("find", 0)) / 100.0,
		"coins": 1.0 + 0.5 * rank("lucky_star"),
	}
	st["hp"] = clampi(int(st.get("hp", 0)), 0, st["max_hp"])
	st["mp"] = clampi(int(st.get("mp", 0)), 0, st["max_mp"])
	Game.stats_changed.emit()


## Damage after defense: every 60 defense halves incoming damage.
static func mitigate(dmg: int) -> int:
	var df := float(d("def"))
	return maxi(1, int(round(dmg * 60.0 / (60.0 + df))))


static func element_mult(element: String) -> float:
	if element in ["fire", "ice", "arcane"]:
		return float(d(element))
	return 1.0
