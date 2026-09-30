class_name KayChar
extends ModelAnim
## A rigged, animated KayKit character (CC0 by Kay Lousberg), wrapped so it
## behaves like the procedural models: set `moving`, call `action()`.

const CHAR_PATH := "res://assets/kaykit/chars/%s.glb"
## Atlas cells (UV rects) that can be recolored, per character.
const CELLS := {
	"robe": Rect2(0.0, 0.25, 0.25, 0.25),
	"hair": Rect2(0.125, 0.0, 0.125, 0.25),
	"cape": Rect2(0.25, 0.25, 0.125, 0.25),
}

static var _scenes := {}

var char_name := "Mage"
var opts := {}
var rig: Node3D
var anim: AnimationPlayer
var idle_anim := "Idle"
var run_anim := "Running_A"
var _action := ""
var _action_t := 0.0
var _hold := false
var _mats: Array[ShaderMaterial] = []


static func make(char: String, options := {}) -> KayChar:
	var k := KayChar.new()
	k.char_name = char
	k.opts = options
	k.height = float(options.get("height", 1.45))
	return k


func _ready() -> void:
	if not _scenes.has(char_name):
		_scenes[char_name] = load(CHAR_PATH % char_name)
	rig = (_scenes[char_name] as PackedScene).instantiate()
	add_child(rig)
	rig.scale = Vector3.ONE * float(opts.get("scale", 0.62))
	anim = rig.find_child("AnimationPlayer", true, false)
	idle_anim = String(opts.get("idle", "Idle"))
	run_anim = String(opts.get("run", "Running_A"))
	for a in [idle_anim, run_anim, "Walking_A", "Spellcasting", "Blocking", "Sit_Chair_Idle", "Lie_Idle"]:
		if anim.has_animation(a):
			anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	var keep: Array = opts.get("items", [])
	var hide_all: bool = opts.has("items")
	if opts.get("wand", false) and rig.find_child("1H_Wand", true, false) == null:
		_borrow_wand()
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var slot := String(m.get_parent().name)
		if hide_all and slot.begins_with("handslot") and not keep.has(String(m.name)) and String(m.name) != "1H_Wand":
			m.visible = false
			continue
		if opts.get("hide", []).has(String(m.name)):
			m.visible = false
			continue
		m.material_override = _material_for(m)
	if opts.get("wings", false):
		_add_wings()
	anim.play(idle_anim)
	anim.seek(randf() * 1.0)


## The Mage's wand, borrowed for characters that don't carry one.
func _borrow_wand() -> void:
	if not _scenes.has("Mage"):
		_scenes["Mage"] = load(CHAR_PATH % "Mage")
	var mage := (_scenes["Mage"] as PackedScene).instantiate()
	var src: MeshInstance3D = mage.find_child("1H_Wand", true, false)
	var slot: Node3D = rig.find_child("handslot_r", true, false)
	if src and slot:
		var w := MeshInstance3D.new()
		w.name = "1H_Wand"
		w.mesh = src.mesh
		w.transform = src.transform
		slot.add_child(w)
	mage.free()


func _add_wings() -> void:
	var chest: Node3D = rig.find_child("chest", true, false)
	if chest == null:
		return
	var wings := Art.node(chest, "Wings", Vector3(0, 0.25, -0.45))
	for s in [-1, 1]:
		var w := Art.node(wings, "WingL" if s < 0 else "WingR")
		Art.part(w, Art.sphere(0.45), Color(0.82, 0.95, 1.0, 0.55), Vector3(0.45 * s, 0.3, 0), Vector3(0, 0, 35 * s), Vector3(0.9, 1.4, 0.1), 0.6, false)
		Art.part(w, Art.sphere(0.32), Color(1.0, 0.85, 0.95, 0.55), Vector3(0.36 * s, -0.25, 0), Vector3(0, 0, -30 * s), Vector3(0.9, 1.3, 0.1), 0.6, false)
	_wing_l = wings.get_node("WingL")
	_wing_r = wings.get_node("WingR")


func _material_for(m: MeshInstance3D) -> ShaderMaterial:
	var src := m.mesh.surface_get_material(0)
	var mat := ShaderMaterial.new()
	mat.shader = Art.shader("toon_tex")
	if src is BaseMaterial3D:
		mat.set_shader_parameter("tex", (src as BaseMaterial3D).albedo_texture)
	var slot := 0
	for key in ["robe", "hair", "cape"]:
		if opts.has(key):
			var r: Rect2 = opts.get(key + "_cell", CELLS[key])
			var n: String = ["swap_a", "swap_b", "swap_c"][slot]
			mat.set_shader_parameter(n + "_rect", Vector4(r.position.x, r.position.y, r.end.x, r.end.y))
			mat.set_shader_parameter(n, opts[key])
			slot += 1
	mat.set_shader_parameter("lift", float(opts.get("lift", 0.12)))
	_mats.append(mat)
	return mat


## Plays a one-shot animation; returns to idle/run afterwards unless `hold`.
func action(name: String, speed := 1.0, hold := false) -> void:
	if anim == null or not anim.has_animation(name):
		return
	anim.play(name, 0.06, speed)
	_action = name
	_hold = hold
	_action_t = anim.get_animation(name).length / maxf(0.01, speed)


func clear_action() -> void:
	_action = ""
	_hold = false


func set_glow(c: Color, energy: float) -> void:
	for m in _mats:
		m.set_shader_parameter("emission_color", c)
		m.set_shader_parameter("emission_energy", energy)


func set_calm(_v: bool) -> void:
	pass


func _process(delta: float) -> void:
	if anim == null:
		return
	_t += delta
	if _wing_l:
		var f := sin(_t * (14.0 if moving else 6.0)) * 0.35
		_wing_l.rotation.y = f
		_wing_r.rotation.y = -f
	if _action != "":
		_action_t -= delta
		if _action_t <= 0.0 and not _hold:
			_action = ""
		# Running cancels lingering casts/attacks so feet never slide.
		if moving and _action_t < 0.1 and not _hold:
			_action = ""
	if _action == "":
		var want := run_anim if moving else idle_anim
		if anim.current_animation != want:
			anim.play(want, 0.15)
	anim.speed_scale = speed_scale
