class_name Models
extends RefCounted
## Builds every character and creature out of primitives.
## All models stand on y = 0 and face +Z.

const SKIN := Color("ffe2cf")
const EYE := Color("2b1f3a")
const BLUSH := Color("ffa6bd")
const WHITE := Color("fffaf5")


static func _root(kind: String, height: float) -> ModelAnim:
	var r := ModelAnim.new()
	r.name = "Model"
	r.kind = kind
	r.height = height
	return r


## Big cute eyes, blush and a little mouth on a head of radius r.
static func face(head: Node3D, r: float, opts := {}) -> void:
	var eye_col: Color = opts.get("eye", EYE)
	var spread: float = opts.get("spread", 0.36)
	var y: float = opts.get("y", -0.05)
	var size: float = opts.get("size", 0.17)
	for s in [-1, 1]:
		var e := Art.node(head, "EyeL" if s < 0 else "EyeR", Vector3(spread * r * s, y * r, 0.86 * r))
		Art.part(e, Art.sphere(size * r), eye_col, Vector3.ZERO, Vector3.ZERO, Vector3(0.8, 1.2, 0.5), 0.0, false)
		Art.part(e, Art.sphere(size * 0.33 * r), Color.WHITE, Vector3(0.05 * r, 0.07 * r, 0.07 * r), Vector3.ZERO, Vector3.ONE, 0.6, false)
		if opts.get("blush", true):
			Art.part(head, Art.sphere(0.16 * r), BLUSH, Vector3(0.62 * r * s, (y - 0.27) * r, 0.72 * r), Vector3.ZERO, Vector3(1.2, 0.6, 0.3), 0.0, false)
	if opts.get("mouth", true):
		Art.part(head, Art.torus(0.05 * r, 0.1 * r), Color("8a3a5a"), Vector3(0, (y - 0.3) * r, 0.9 * r), Vector3(90, 0, 0), Vector3(1, 1, 0.5), 0.0, false)
	if opts.get("brows", false):
		var b := Art.node(head, "Brows")
		for s in [-1, 1]:
			Art.part(b, Art.box(Vector3(0.3 * r, 0.07 * r, 0.06 * r)), EYE, Vector3(spread * r * s, (y + 0.3) * r, 0.9 * r), Vector3(0, 0, -22 * s), Vector3.ONE, 0.0, false)


# ================================================================ PEOPLE
## Chibi humanoid. spec keys: skin, hair, robe, accent, shoes, hair_style,
## hat (witch|wizard|circlet|helmet|none), extras (Array), scale.
static func humanoid(spec: Dictionary) -> ModelAnim:
	if not spec.get("classic", false):
		return kay_humanoid(spec)
	return classic_humanoid(spec)


## Maps an old-style NPC spec onto a rigged KayKit character with its colors.
static func kay_humanoid(spec: Dictionary) -> ModelAnim:
	var hat: String = spec.get("hat", "")
	var extras: Array = spec.get("extras", [])
	var char := "Rogue"
	if hat == "helmet":
		char = "Knight"
	elif extras.has("beard"):
		char = "Barbarian"
	elif hat == "wizard" or hat == "witch":
		char = "Mage"
	elif spec.get("hair_style", "") == "none" or extras.has("hood"):
		char = "Rogue_Hooded"
	var opts := {"items": [], "robe": spec.get("robe", Color("c9b6ec")), "scale": 0.8 * float(spec.get("scale", 1.0)),
		"wings": extras.has("wings"), "idle": spec.get("idle", "Idle")}
	if spec.has("hair"):
		opts["hair"] = spec["hair"]
	if spec.has("hat_color") and char == "Mage":
		opts["robe"] = spec["hat_color"]
	if extras.has("wand"):
		opts["wand"] = true
	return KayChar.make(char, opts)


static func classic_humanoid(spec: Dictionary) -> ModelAnim:
	var root := _root("biped", 1.55 * float(spec.get("scale", 1.0)))
	var skin: Color = spec.get("skin", SKIN)
	var robe: Color = spec.get("robe", Color("8f6ee8"))
	var accent: Color = spec.get("accent", Color("ffd36b"))
	var hair: Color = spec.get("hair", Color("6b4a3a"))
	var extras: Array = spec.get("extras", [])
	var pivot := Art.node(root, "Pivot")

	for s in [-1, 1]:
		Art.part(pivot, Art.sphere(0.11), spec.get("shoes", Color("6a4468")), Vector3(0.13 * s, 0.07, 0.04), Vector3.ZERO, Vector3(1, 0.7, 1.35))
	if extras.has("tail_fin"):
		Art.part(pivot, Art.cyl(0.18, 0.1, 0.5), robe, Vector3(0, 0.25, 0))
		for s in [-1, 1]:
			Art.part(pivot, Art.sphere(0.16), accent, Vector3(0.12 * s, 0.05, 0.05), Vector3(0, 0, 30 * s), Vector3(1.3, 0.4, 0.8))
	else:
		Art.part(pivot, Art.cyl(0.17, 0.36, 0.62), robe, Vector3(0, 0.4, 0))
		Art.part(pivot, Art.cyl(0.36, 0.37, 0.05), robe.darkened(0.15), Vector3(0, 0.11, 0))
	Art.part(pivot, Art.cyl(0.2, 0.21, 0.07), accent, Vector3(0, 0.65, 0))
	if extras.has("apron"):
		Art.part(pivot, Art.box(Vector3(0.36, 0.42, 0.04)), WHITE, Vector3(0, 0.36, 0.25), Vector3(-17, 0, 0))
	if extras.has("tie"):
		Art.part(pivot, Art.box(Vector3(0.07, 0.24, 0.03)), Color("e05a7a"), Vector3(0, 0.55, 0.19), Vector3(-10, 0, 0))
	if extras.has("cape"):
		Art.part(pivot, Art.box(Vector3(0.5, 0.6, 0.04)), accent, Vector3(0, 0.38, -0.27), Vector3(12, 0, 0))

	for s in [-1, 1]:
		var arm := Art.node(pivot, "ArmL" if s < 0 else "ArmR", Vector3(0.2 * s, 0.68, 0))
		Art.part(arm, Art.capsule(0.075, 0.34), robe, Vector3(0.06 * s, -0.12, 0), Vector3(0, 0, 22 * s))
		Art.part(arm, Art.sphere(0.075), skin, Vector3(0.13 * s, -0.27, 0.02))
		if s > 0 and extras.has("wand"):
			Art.part(arm, Art.cyl(0.018, 0.022, 0.45), Color("8b5a3c"), Vector3(0.15, -0.2, 0.15), Vector3(60, 0, 0))
			Art.part(arm, Art.sphere(0.06), Color("ffe27a"), Vector3(0.15, -0.08, 0.35), Vector3.ZERO, Vector3.ONE, 2.5)
		if s < 0 and extras.has("briefcase"):
			Art.part(arm, Art.box(Vector3(0.1, 0.24, 0.32)), Color("7a4a2e"), Vector3(-0.15, -0.42, 0.02))
		if s < 0 and extras.has("papers"):
			Art.part(arm, Art.box(Vector3(0.22, 0.03, 0.28)), WHITE, Vector3(-0.05, -0.25, 0.18), Vector3(20, 0, 0))

	var head := Art.node(pivot, "Head", Vector3(0, 1.02, 0))
	var r := 0.36
	Art.part(head, Art.sphere(r), skin)
	face(head, r)
	if extras.has("glasses"):
		for s in [-1, 1]:
			Art.part(head, Art.torus(0.065, 0.085), Color("5a3a6a"), Vector3(0.13 * s, -0.02, 0.35), Vector3(90, 0, 0), Vector3.ONE, 0.0, false)

	var style: String = spec.get("hair_style", "long")
	if style != "none":
		Art.part(head, Art.sphere(r * 1.07), hair, Vector3(0, 0.03, -0.07))
		Art.part(head, Art.sphere(r * 0.82), hair, Vector3(0, 0.42 * r, 0.3 * r), Vector3(-8, 0, 0), Vector3(1.25, 0.6, 1.0))
		match style:
			"long":
				Art.part(head, Art.cyl(0.3, 0.34, 0.5), hair, Vector3(0, -0.18, -0.13))
			"bun":
				Art.part(head, Art.sphere(0.15), hair, Vector3(0, 0.36, -0.14))
			"pigtails":
				for s in [-1, 1]:
					Art.part(head, Art.sphere(0.13), hair, Vector3(0.36 * s, -0.1, -0.08), Vector3.ZERO, Vector3(1, 1.4, 1))
			"bob":
				Art.part(head, Art.sphere(r * 1.1), hair, Vector3(0, -0.05, -0.04), Vector3.ZERO, Vector3(1.02, 0.8, 0.95))

	if extras.has("ears"):
		for s in [-1, 1]:
			Art.part(head, Art.cyl(0.0, 0.07, 0.28), skin, Vector3(0.38 * s, 0.05, -0.02), Vector3(0, 0, -65 * s))
	if extras.has("beard"):
		Art.part(head, Art.cyl(0.26, 0.02, 0.55), WHITE, Vector3(0, -0.4, 0.2), Vector3(12, 0, 0))
		for s in [-1, 1]:
			Art.part(head, Art.sphere(0.08), WHITE, Vector3(0.08 * s, -0.12, 0.33), Vector3.ZERO, Vector3(1.4, 0.7, 0.8))
	if extras.has("flowers"):
		var cols := [Color("ff8fb8"), Color("ffe27a"), Color("ffffff"), Color("c3a6ff"), Color("8fe0c8")]
		for i in 5:
			var a := -0.9 + i * 0.45
			Art.part(head, Art.sphere(0.07), cols[i], Vector3(sin(a) * 0.33, 0.24 + cos(a) * 0.05, cos(a) * 0.1 + 0.05), Vector3.ZERO, Vector3.ONE, 0.3, false)

	match String(spec.get("hat", "none")):
		"witch", "wizard":
			var hat_col: Color = spec.get("hat_color", robe.darkened(0.2))
			var big := 1.15 if spec.get("hat") == "wizard" else 1.0
			var hat := Art.node(head, "Hat", Vector3(0, 0.26, -0.02))
			hat.rotation_degrees.x = -8
			Art.part(hat, Art.cyl(0.52 * big, 0.52 * big, 0.04), hat_col)
			Art.part(hat, Art.cyl(0.29 * big, 0.3 * big, 0.08), accent, Vector3(0, 0.05, 0))
			Art.part(hat, Art.cyl(0.13, 0.3 * big, 0.45 * big), hat_col, Vector3(0, 0.28 * big, 0))
			Art.part(hat, Art.cyl(0.0, 0.13, 0.32), hat_col, Vector3(0, 0.55 * big, -0.08), Vector3(-35, 0, 0))
			Art.part(hat, Art.sphere(0.06), Color("ffe27a"), Vector3(0.05, 0.23 * big, 0.25 * big), Vector3.ZERO, Vector3.ONE, 2.0, false)
		"circlet":
			Art.part(head, Art.torus(0.3, 0.35), Color("ffd36b"), Vector3(0, 0.12, 0), Vector3(-12, 0, 0), Vector3.ONE, 0.3)
			Art.part(head, Art.sphere(0.05), Color("7ce8ff"), Vector3(0, 0.2, 0.34), Vector3.ZERO, Vector3.ONE, 1.5, false)
		"helmet":
			Art.part(head, Art.sphere(r * 1.1, true), Color("c9cfe0"), Vector3(0, 0.02, -0.02))
			Art.part(head, Art.box(Vector3(0.06, 0.4, 0.06)), Color("e05a7a"), Vector3(0, 0.45, -0.05))
		"postman":
			Art.part(head, Art.cyl(0.22, 0.24, 0.14), Color("4a6fd0"), Vector3(0, 0.3, 0))
			Art.part(head, Art.cyl(0.24, 0.24, 0.02), Color("2b3f8a"), Vector3(0, 0.24, 0.1), Vector3(-15, 0, 0), Vector3(1, 1, 0.7))

	if extras.has("wings"):
		var wings := Art.node(pivot, "Wings", Vector3(0, 0.72, -0.2))
		for s in [-1, 1]:
			var w := Art.node(wings, "WingL" if s < 0 else "WingR")
			var wc := Color(0.82, 0.95, 1.0, 0.55)
			Art.part(w, Art.sphere(0.24), wc, Vector3(0.25 * s, 0.15, -0.05), Vector3(0, 0, 35 * s), Vector3(0.9, 1.4, 0.1), 0.6, false)
			Art.part(w, Art.sphere(0.17), Color(1.0, 0.85, 0.95, 0.55), Vector3(0.2 * s, -0.15, -0.05), Vector3(0, 0, -30 * s), Vector3(0.9, 1.3, 0.1), 0.6, false)
	root.scale = Vector3.ONE * float(spec.get("scale", 1.0))
	return root


## The player's hero, driven by the saved style and colors.
static func hero(style: String, robe: Color, hair: Color) -> ModelAnim:
	match style:
		"fairy":
			return KayChar.make("Rogue", {"items": [], "wand": true, "wings": true, "robe": robe, "hair": hair, "scale": 0.82})
		"elf":
			return KayChar.make("Rogue_Hooded", {"items": [], "wand": true, "robe": robe, "hair": hair, "scale": 0.82})
		_:
			return KayChar.make("Mage", {"items": ["1H_Wand"], "robe": robe, "hair": hair, "scale": 0.82})


## The old primitive-built hero (kept for reference and tests).
static func hero_classic(style: String, robe: Color, hair: Color) -> ModelAnim:
	var spec := {"robe": robe, "hair": hair, "accent": Color("ffd36b"), "extras": ["wand"]}
	match style:
		"witch":
			spec["hat"] = "witch"
			spec["hair_style"] = "long"
		"fairy":
			spec["hair_style"] = "pigtails"
			spec["extras"] = ["wand", "wings", "flowers"]
		"elf":
			spec["hair_style"] = "long"
			spec["hat"] = "circlet"
			spec["extras"] = ["wand", "ears", "cape"]
			spec["accent"] = Color("ffe6a0")
	return classic_humanoid(spec)


static func cat(fur := Color("fff4ea"), patch := Color("ffbf85")) -> ModelAnim:
	var root := _root("quad", 0.85)
	var pivot := Art.node(root, "Pivot")
	Art.part(pivot, Art.sphere(0.24), fur, Vector3(0, 0.27, 0), Vector3.ZERO, Vector3(0.85, 0.8, 1.15))
	Art.part(pivot, Art.sphere(0.13), patch, Vector3(0.1, 0.4, -0.06), Vector3.ZERO, Vector3(1, 0.5, 1.3), 0.0, false)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			Art.part(pivot, Art.sphere(0.07), fur, Vector3(0.12 * sx, 0.07, 0.15 * sz))
	var head := Art.node(pivot, "Head", Vector3(0, 0.52, 0.2))
	Art.part(head, Art.sphere(0.22), fur)
	face(head, 0.22, {"spread": 0.4, "size": 0.2})
	Art.part(head, Art.sphere(0.025), Color("ff8fb0"), Vector3(0, -0.03, 0.21), Vector3.ZERO, Vector3.ONE, 0.0, false)
	for s in [-1, 1]:
		Art.part(head, Art.cyl(0.0, 0.085, 0.16), fur, Vector3(0.12 * s, 0.18, -0.02), Vector3(0, 0, -18 * s))
		Art.part(head, Art.cyl(0.0, 0.05, 0.1), Color("ffb3c8"), Vector3(0.12 * s, 0.17, 0.02), Vector3(0, 0, -18 * s), Vector3.ONE, 0.0, false)
	var tail := Art.node(pivot, "Tail", Vector3(0, 0.3, -0.25))
	Art.part(tail, Art.sphere(0.065), fur, Vector3(0, 0.04, -0.04))
	Art.part(tail, Art.sphere(0.06), fur, Vector3(0, 0.14, -0.09))
	Art.part(tail, Art.sphere(0.06), patch, Vector3(0, 0.25, -0.08))
	return root


static func owl() -> ModelAnim:
	var root := _root("hop", 1.1)
	var pivot := Art.node(root, "Pivot")
	var brown := Color("b98a63")
	Art.part(pivot, Art.sphere(0.34), brown, Vector3(0, 0.4, 0), Vector3.ZERO, Vector3(1, 1.1, 0.95))
	Art.part(pivot, Art.sphere(0.24), Color("f3dcc0"), Vector3(0, 0.33, 0.14), Vector3.ZERO, Vector3(1, 1.1, 0.7))
	var head := Art.node(pivot, "Head", Vector3(0, 0.62, 0.05))
	for s in [-1, 1]:
		var e := Art.node(head, "EyeL" if s < 0 else "EyeR", Vector3(0.12 * s, 0.02, 0.26))
		Art.part(e, Art.sphere(0.1), WHITE, Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.4))
		Art.part(e, Art.sphere(0.055), EYE, Vector3(0, 0, 0.04), Vector3.ZERO, Vector3(1, 1, 0.5))
		Art.part(head, Art.cyl(0.0, 0.06, 0.16), brown.darkened(0.2), Vector3(0.18 * s, 0.22, 0.05), Vector3(0, 0, -20 * s))
		var wing := Art.node(pivot, "WingL" if s < 0 else "WingR", Vector3(0.3 * s, 0.4, 0))
		Art.part(wing, Art.sphere(0.16), brown.darkened(0.15), Vector3(0.02 * s, 0, 0), Vector3.ZERO, Vector3(0.4, 1.2, 0.9))
	Art.part(head, Art.prism(Vector3(0.1, 0.1, 0.08)), Color("ffb347"), Vector3(0, -0.06, 0.3), Vector3(180, 0, 0))
	Art.part(head, Art.cyl(0.2, 0.22, 0.12), Color("4a6fd0"), Vector3(0, 0.2, 0))
	Art.part(pivot, Art.box(Vector3(0.18, 0.2, 0.08)), Color("c96a4a"), Vector3(0.25, 0.25, 0.18), Vector3(0, -20, 0))
	for s in [-1, 1]:
		Art.part(pivot, Art.sphere(0.05), Color("ffb347"), Vector3(0.1 * s, 0.04, 0.08))
	return root


static func unicorn() -> ModelAnim:
	var root := _root("quad", 1.6)
	var pivot := Art.node(root, "Pivot")
	var body := Color("fbf7ff")
	Art.part(pivot, Art.capsule(0.26, 0.9), body, Vector3(0, 0.62, 0), Vector3(90, 0, 0))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			Art.part(pivot, Art.cyl(0.06, 0.07, 0.5), body, Vector3(0.14 * sx, 0.25, 0.26 * sz))
			Art.part(pivot, Art.cyl(0.075, 0.075, 0.07), Color("c9b6ff"), Vector3(0.14 * sx, 0.03, 0.26 * sz))
	Art.part(pivot, Art.cyl(0.12, 0.15, 0.45), body, Vector3(0, 0.95, 0.35), Vector3(30, 0, 0))
	var head := Art.node(pivot, "Head", Vector3(0, 1.2, 0.5))
	Art.part(head, Art.sphere(0.2), body)
	Art.part(head, Art.sphere(0.13), body, Vector3(0, -0.07, 0.17))
	face(head, 0.2, {"spread": 0.55, "y": 0.15, "mouth": false})
	Art.part(head, Art.cyl(0.0, 0.05, 0.32), Color("ffd36b"), Vector3(0, 0.26, 0.05), Vector3(20, 0, 0), Vector3.ONE, 1.2)
	for s in [-1, 1]:
		Art.part(head, Art.cyl(0.0, 0.05, 0.12), body, Vector3(0.12 * s, 0.2, -0.05), Vector3(0, 0, -20 * s))
	var mane := [Color("ff9fd0"), Color("c3a6ff"), Color("8fe0ff")]
	for i in 5:
		Art.part(pivot, Art.sphere(0.09), mane[i % 3], Vector3(0, 1.25 - i * 0.12, 0.42 - i * 0.1))
	var tail := Art.node(pivot, "Tail", Vector3(0, 0.7, -0.6))
	for i in 3:
		Art.part(tail, Art.sphere(0.1 - i * 0.015), mane[i], Vector3(0, -i * 0.12, -i * 0.05))
	Art.part(pivot, Art.box(Vector3(0.07, 0.2, 0.03)), Color("5b8def"), Vector3(0, 0.82, 0.55), Vector3(-30, 0, 0))
	return root


static func dragon() -> ModelAnim:
	var root := _root("biped", 1.6)
	var pivot := Art.node(root, "Pivot")
	var green := Color("7fd6a0")
	Art.part(pivot, Art.sphere(0.36), green, Vector3(0, 0.45, 0), Vector3.ZERO, Vector3(1, 1.15, 0.95))
	Art.part(pivot, Art.sphere(0.26), Color("fff0b0"), Vector3(0, 0.42, 0.14), Vector3.ZERO, Vector3(1, 1.2, 0.8))
	for s in [-1, 1]:
		Art.part(pivot, Art.sphere(0.12), green, Vector3(0.18 * s, 0.08, 0.05), Vector3.ZERO, Vector3(1, 0.7, 1.3))
		var arm := Art.node(pivot, "ArmL" if s < 0 else "ArmR", Vector3(0.3 * s, 0.6, 0.05))
		Art.part(arm, Art.capsule(0.07, 0.28), green, Vector3(0.03 * s, -0.1, 0), Vector3(0, 0, 25 * s))
		Art.part(pivot, Art.prism(Vector3(0.4, 0.3, 0.04)), Color("b7a0f0"), Vector3(0.28 * s, 0.75, -0.25), Vector3(0, 25 * s, -40 * s))
	var tail := Art.node(pivot, "Tail", Vector3(0, 0.25, -0.3))
	Art.part(tail, Art.cyl(0.02, 0.14, 0.5), green, Vector3(0, 0, -0.2), Vector3(-70, 0, 0))
	var head := Art.node(pivot, "Head", Vector3(0, 1.0, 0.02))
	Art.part(head, Art.sphere(0.32), green)
	Art.part(head, Art.sphere(0.18), green.lightened(0.15), Vector3(0, -0.1, 0.25), Vector3.ZERO, Vector3(1.2, 0.8, 1))
	face(head, 0.32, {"y": 0.15, "mouth": false})
	for s in [-1, 1]:
		Art.part(head, Art.cyl(0.0, 0.06, 0.2), Color("fff0b0"), Vector3(0.16 * s, 0.3, -0.05), Vector3(-20, 0, -15 * s))
		Art.part(head, Art.torus(0.06, 0.08), Color("5a3a6a"), Vector3(0.12 * s, 0.05, 0.3), Vector3(90, 0, 0), Vector3.ONE, 0.0, false)
	for i in 5:
		Art.part(pivot, Art.sphere(0.035), Color("fffaf0"), Vector3(sin(-0.8 + i * 0.4) * 0.3, 0.72, cos(-0.8 + i * 0.4) * 0.28), Vector3.ZERO, Vector3.ONE, 0.4, false)
	return root


static func ghost() -> ModelAnim:
	var root := _root("float", 1.4)
	var pivot := Art.node(root, "Pivot", Vector3(0, 0.2, 0))
	var c := Color(1, 1, 1, 0.78)
	Art.part(pivot, Art.sphere(0.38), c, Vector3(0, 0.75, 0))
	Art.part(pivot, Art.cyl(0.38, 0.12, 0.5), c, Vector3(0, 0.45, 0))
	var head := Art.node(pivot, "Head", Vector3(0, 0.78, 0))
	face(head, 0.38)
	Art.part(pivot, Art.cyl(0.08, 0.07, 0.14), Color("e07a5f"), Vector3(0.3, 0.6, 0.25))
	Art.part(pivot, Art.sphere(0.07), Color("7a4a2e"), Vector3(0.3, 0.66, 0.25), Vector3.ZERO, Vector3(1, 0.3, 1))
	return root


static func tiny_clock() -> ModelAnim:
	var root := _root("hop", 1.0)
	var pivot := Art.node(root, "Pivot")
	Art.part(pivot, Art.cyl(0.3, 0.3, 0.18, 24), Color("ff8fa3"), Vector3(0, 0.42, 0), Vector3(90, 0, 0))
	Art.part(pivot, Art.cyl(0.25, 0.25, 0.02, 24), WHITE, Vector3(0, 0.42, 0.09), Vector3(90, 0, 0))
	for s in [-1, 1]:
		Art.part(pivot, Art.sphere(0.1, true), Color("ffd36b"), Vector3(0.18 * s, 0.7, 0), Vector3(0, 0, -25 * s))
		Art.part(pivot, Art.cyl(0.03, 0.03, 0.15), Color("ffd36b"), Vector3(0.18 * s, 0.1, 0))
	var head := Art.node(pivot, "Head", Vector3(0, 0.42, -0.115))
	face(head, 0.25, {"y": 0.1})
	return root


# ============================================================== CRITTERS
static func critter(id: String) -> ModelAnim:
	match id:
		"cloud": return _cloud()
		"shroom": return _shroom()
		"pigeon": return _pigeon()
		"umbrella": return _umbrella()
		"bee": return _bee()
		"paper": return _paper()
		"coffee": return _coffee()
		"clip": return _clip()
		"printer": return _printer()
		"email": return _email()
		"monday": return monday()
	return _cloud()


static func _cloud() -> ModelAnim:
	var root := _root("float", 1.3)
	var pivot := Art.node(root, "Pivot", Vector3(0, 0.55, 0))
	var c := Color("c9c2e8")
	for p in [Vector3(0, 0.1, 0), Vector3(-0.3, 0, 0), Vector3(0.3, -0.02, 0), Vector3(-0.15, 0.25, -0.05), Vector3(0.18, 0.22, -0.05)]:
		Art.part(pivot, Art.sphere(0.28), c, p)
	var head := Art.node(pivot, "Head", Vector3(0, 0.05, 0.05))
	face(head, 0.3, {"brows": true})
	for i in 3:
		Art.part(pivot, Art.sphere(0.05), Color("8fc8ff"), Vector3(-0.2 + i * 0.2, -0.4 - (i % 2) * 0.12, 0), Vector3.ZERO, Vector3(1, 1.6, 1), 0.3, false)
	return root


static func _shroom() -> ModelAnim:
	var root := _root("hop", 1.1)
	var pivot := Art.node(root, "Pivot")
	Art.part(pivot, Art.cyl(0.18, 0.22, 0.45), Color("fff1dc"), Vector3(0, 0.3, 0))
	Art.part(pivot, Art.sphere(0.45, true), Color("ff6b7a"), Vector3(0, 0.5, 0), Vector3.ZERO, Vector3(1, 0.9, 1))
	for p in [Vector3(0.2, 0.75, 0.25), Vector3(-0.25, 0.7, 0.2), Vector3(0.05, 0.88, -0.1), Vector3(-0.1, 0.7, -0.3), Vector3(0.3, 0.65, -0.15)]:
		Art.part(pivot, Art.sphere(0.07), WHITE, p, Vector3.ZERO, Vector3(1, 0.5, 1), 0.0, false)
	var head := Art.node(pivot, "Head", Vector3(0, 0.32, 0.02))
	face(head, 0.2, {"brows": true})
	for s in [-1, 1]:
		Art.part(pivot, Art.sphere(0.07), Color("e8c9a8"), Vector3(0.1 * s, 0.05, 0.05))
	return root


static func _pigeon() -> ModelAnim:
	var root := _root("hop", 1.0)
	var pivot := Art.node(root, "Pivot")
	var c := Color("9aa6c9")
	Art.part(pivot, Art.sphere(0.3), c, Vector3(0, 0.35, 0), Vector3.ZERO, Vector3(0.9, 0.9, 1.2))
	Art.part(pivot, Art.sphere(0.18), Color("a8e0c8"), Vector3(0, 0.45, 0.2), Vector3.ZERO, Vector3(1, 0.8, 0.6))
	var head := Art.node(pivot, "Head", Vector3(0, 0.68, 0.18))
	Art.part(head, Art.sphere(0.2), c.lightened(0.1))
	face(head, 0.2, {"brows": true, "mouth": false, "spread": 0.45})
	Art.part(head, Art.cyl(0.0, 0.06, 0.14), Color("ffb347"), Vector3(0, -0.04, 0.22), Vector3(90, 0, 0))
	Art.part(head, Art.cyl(0.08, 0.1, 0.08), Color("ffd36b"), Vector3(0, 0.2, 0), Vector3.ZERO, Vector3.ONE, 0.5)
	for s in [-1, 1]:
		var w := Art.node(pivot, "WingL" if s < 0 else "WingR", Vector3(0.25 * s, 0.38, -0.02))
		Art.part(w, Art.sphere(0.16), c.darkened(0.15), Vector3.ZERO, Vector3.ZERO, Vector3(0.35, 0.9, 1.2))
		Art.part(pivot, Art.cyl(0.02, 0.02, 0.15), Color("ff9f7a"), Vector3(0.1 * s, 0.07, 0))
	return root


static func _umbrella() -> ModelAnim:
	var root := _root("hop", 1.3)
	var pivot := Art.node(root, "Pivot")
	Art.part(pivot, Art.cyl(0.03, 0.03, 0.7), Color("8b5a3c"), Vector3(0, 0.4, 0))
	Art.part(pivot, Art.torus(0.06, 0.1), Color("8b5a3c"), Vector3(0.08, 0.06, 0), Vector3(90, 0, 0), Vector3(1, 1, 1))
	Art.part(pivot, Art.cyl(0.0, 0.62, 0.38), Color("5fc9c0"), Vector3(0, 0.95, 0))
	for i in 4:
		var a := i * PI / 2 + PI / 4
		Art.part(pivot, Art.sphere(0.12), Color("ff8fb8"), Vector3(sin(a) * 0.42, 0.8, cos(a) * 0.42), Vector3.ZERO, Vector3(1, 0.4, 1), 0.0, false)
	var head := Art.node(pivot, "Head", Vector3(0, 0.88, 0.23))
	face(head, 0.22, {"brows": true, "blush": false})
	return root


static func _bee() -> ModelAnim:
	var root := _root("float", 1.2)
	var pivot := Art.node(root, "Pivot", Vector3(0, 0.6, 0))
	Art.part(pivot, Art.sphere(0.3), Color("ffd84d"), Vector3.ZERO, Vector3.ZERO, Vector3(0.9, 0.9, 1.15))
	for z in [-0.12, 0.08]:
		Art.part(pivot, Art.cyl(0.29, 0.29, 0.08), Color("3a2c3a"), Vector3(0, 0, z - 0.05), Vector3(90, 0, 0), Vector3(1, 1, 1))
	Art.part(pivot, Art.cyl(0.0, 0.06, 0.15), Color("3a2c3a"), Vector3(0, 0, -0.38), Vector3(-90, 0, 0))
	var head := Art.node(pivot, "Head", Vector3(0, 0.08, 0.2))
	face(head, 0.22, {"brows": true})
	for s in [-1, 1]:
		Art.part(pivot, Art.cyl(0.01, 0.01, 0.2), Color("3a2c3a"), Vector3(0.08 * s, 0.35, 0.25), Vector3(20, 0, -15 * s))
		Art.part(pivot, Art.sphere(0.04), Color("3a2c3a"), Vector3(0.11 * s, 0.45, 0.28))
		var w := Art.node(pivot, "WingL" if s < 0 else "WingR", Vector3(0.1 * s, 0.28, -0.05))
		Art.part(w, Art.sphere(0.2), Color(0.9, 0.97, 1.0, 0.6), Vector3(0.15 * s, 0.05, 0), Vector3(0, 0, 30 * s), Vector3(1, 0.6, 0.1), 0.5, false)
	return root


static func _paper() -> ModelAnim:
	var root := _root("hop", 1.2)
	var pivot := Art.node(root, "Pivot")
	Art.part(pivot, Art.box(Vector3(0.6, 0.8, 0.08)), WHITE, Vector3(0, 0.55, 0), Vector3(0, 0, 4))
	for i in 4:
		Art.part(pivot, Art.box(Vector3(0.42, 0.025, 0.02)), Color("b9c4e8"), Vector3(0, 0.35 + i * 0.07, 0.045), Vector3(0, 0, 4), Vector3.ONE, 0.0, false)
	var head := Art.node(pivot, "Head", Vector3(0, 0.75, -0.17))
	face(head, 0.25, {"brows": true})
	for s in [-1, 1]:
		Art.part(pivot, Art.cyl(0.0, 0.05, 0.14), Color("ff6b7a"), Vector3(0.22 * s, 1.0, 0), Vector3(0, 0, -20 * s))
		var arm := Art.node(pivot, "ArmL" if s < 0 else "ArmR", Vector3(0.33 * s, 0.55, 0))
		Art.part(arm, Art.cyl(0.02, 0.02, 0.25), EYE, Vector3(0.05 * s, -0.08, 0), Vector3(0, 0, 40 * s))
		Art.part(pivot, Art.cyl(0.02, 0.02, 0.18), EYE, Vector3(0.12 * s, 0.1, 0))
	return root


static func _coffee() -> ModelAnim:
	var root := _root("hop", 1.1)
	var pivot := Art.node(root, "Pivot")
	Art.part(pivot, Art.cyl(0.3, 0.26, 0.5, 20), WHITE, Vector3(0, 0.27, 0))
	Art.part(pivot, Art.torus(0.08, 0.14), WHITE, Vector3(0.32, 0.3, 0), Vector3(90, 0, 0))
	Art.part(pivot, Art.cyl(0.31, 0.31, 0.06), Color("ff8fb8"), Vector3(0, 0.2, 0))
	Art.part(pivot, Art.sphere(0.33), Color("8a5a3c"), Vector3(0, 0.55, 0), Vector3.ZERO, Vector3(1, 0.75, 1))
	for p in [Vector3(0.22, 0.4, 0.2), Vector3(-0.25, 0.38, 0.15)]:
		Art.part(pivot, Art.sphere(0.08), Color("8a5a3c"), p, Vector3.ZERO, Vector3(1, 1.6, 1))
	var head := Art.node(pivot, "Head", Vector3(0, 0.6, 0.08))
	face(head, 0.25, {"brows": true})
	return root


static func _clip() -> ModelAnim:
	var root := _root("float", 1.3)
	var pivot := Art.node(root, "Pivot", Vector3(0, 0.5, 0))
	var c := Color("c8d6ff")
	Art.part(pivot, Art.torus(0.18, 0.24), c, Vector3(0, 0.1, 0), Vector3(90, 0, 0), Vector3(1, 1, 2.2), 0.6)
	Art.part(pivot, Art.torus(0.12, 0.17), c, Vector3(0, 0.05, 0.02), Vector3(90, 0, 0), Vector3(1, 1, 2.2), 0.6)
	var head := Art.node(pivot, "Head", Vector3(0, 0.2, 0.0))
	face(head, 0.22, {"brows": true})
	return root


static func _printer() -> ModelAnim:
	var root := _root("hop", 1.3)
	var pivot := Art.node(root, "Pivot")
	Art.part(pivot, Art.box(Vector3(0.8, 0.5, 0.6)), Color("e8e0d0"), Vector3(0, 0.4, 0))
	Art.part(pivot, Art.box(Vector3(0.7, 0.12, 0.5)), Color("b8b0c8"), Vector3(0, 0.71, -0.03))
	Art.part(pivot, Art.box(Vector3(0.5, 0.03, 0.35)), WHITE, Vector3(0, 0.25, 0.4), Vector3(-15, 0, 0))
	Art.part(pivot, Art.sphere(0.04), Color("7cff9a"), Vector3(0.3, 0.55, 0.31), Vector3.ZERO, Vector3.ONE, 3.0, false)
	var head := Art.node(pivot, "Head", Vector3(0, 0.45, 0.11))
	face(head, 0.22, {"brows": true})
	for s in [-1, 1]:
		Art.part(pivot, Art.cyl(0.05, 0.05, 0.16), Color("8a8aa8"), Vector3(0.25 * s, 0.08, 0))
	return root


static func _email() -> ModelAnim:
	var root := _root("float", 1.3)
	var pivot := Art.node(root, "Pivot", Vector3(0, 0.55, 0))
	Art.part(pivot, Art.cyl(0.25, 0.05, 0.5), Color(0.85, 0.8, 1.0, 0.7), Vector3(0, -0.15, -0.05))
	Art.part(pivot, Art.box(Vector3(0.7, 0.46, 0.1)), WHITE, Vector3(0, 0.25, 0))
	Art.part(pivot, Art.prism(Vector3(0.7, 0.25, 0.02)), Color("e8e0f7"), Vector3(0, 0.36, 0.055), Vector3(180, 0, 0), Vector3.ONE, 0.0, false)
	Art.part(pivot, Art.cyl(0.07, 0.07, 0.03), Color("e05a7a"), Vector3(0, 0.25, 0.07), Vector3(90, 0, 0), Vector3.ONE, 0.3, false)
	var head := Art.node(pivot, "Head", Vector3(0, 0.16, -0.14))
	face(head, 0.22, {"brows": true, "spread": 0.7})
	return root


static func monday() -> ModelAnim:
	var root := _root("hop", 3.2)
	var pivot := Art.node(root, "Pivot")
	var red := Color("ff5d7a")
	Art.part(pivot, Art.cyl(1.0, 1.0, 0.6, 32), red, Vector3(0, 1.5, 0), Vector3(90, 0, 0))
	Art.part(pivot, Art.cyl(0.85, 0.85, 0.05, 32), WHITE, Vector3(0, 1.5, 0.3), Vector3(90, 0, 0))
	for i in 12:
		var a := i * TAU / 12
		Art.part(pivot, Art.box(Vector3(0.06, 0.14, 0.03)), EYE, Vector3(sin(a) * 0.72, 1.5 + cos(a) * 0.72, 0.33), Vector3(0, 0, -rad_to_deg(a)), Vector3.ONE, 0.0, false)
	var hands := Art.node(pivot, "Hands", Vector3(0, 1.5, 0.35))
	Art.part(hands, Art.box(Vector3(0.07, 0.55, 0.03)), EYE, Vector3(0.12, 0.2, 0), Vector3(0, 0, -30), Vector3.ONE, 0.0, false)
	Art.part(hands, Art.box(Vector3(0.07, 0.4, 0.03)), EYE, Vector3(-0.15, 0.1, 0), Vector3(0, 0, 55), Vector3.ONE, 0.0, false)
	for s in [-1, 1]:
		Art.part(pivot, Art.sphere(0.38, true), Color("ffd36b"), Vector3(0.55 * s, 2.35, 0), Vector3(0, 0, -30 * s), Vector3.ONE, 0.3)
		Art.part(pivot, Art.cyl(0.1, 0.12, 0.7), red.darkened(0.2), Vector3(0.45 * s, 0.35, 0))
		Art.part(pivot, Art.sphere(0.2), red.darkened(0.3), Vector3(0.45 * s, 0.05, 0.1), Vector3.ZERO, Vector3(1, 0.6, 1.4))
		var arm := Art.node(pivot, "ArmL" if s < 0 else "ArmR", Vector3(1.0 * s, 1.5, 0))
		Art.part(arm, Art.capsule(0.1, 0.6), red.darkened(0.2), Vector3(0.2 * s, -0.2, 0), Vector3(0, 0, 40 * s))
		Art.part(arm, Art.sphere(0.16), WHITE, Vector3(0.4 * s, -0.45, 0))
	Art.part(pivot, Art.cyl(0.05, 0.05, 0.5), Color("ffd36b"), Vector3(0, 2.6, 0))
	Art.part(pivot, Art.sphere(0.12), Color("ffd36b"), Vector3(0, 2.9, 0), Vector3.ZERO, Vector3.ONE, 0.5)
	var head := Art.node(pivot, "Head", Vector3(0, 1.45, -0.28))
	face(head, 0.75, {"brows": true, "y": 0.2, "spread": 0.45, "blush": false})
	return root
