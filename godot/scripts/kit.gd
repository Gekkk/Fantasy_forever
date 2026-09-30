class_name Kit
extends RefCounted
## CC0 props from the KayKit packs by Kay Lousberg (kaylousberg.com):
## trees, rocks, furniture, cafe bits, city bits and fantasy buildings.
## Each prop is flattened into [mesh, local transform] parts so the world's
## Batch can draw many copies as MultiMeshes with the toon texture shader.

const ROOT := "res://assets/kaykit/%s.gltf"
## Atlas cells (UV rects, 8x4 grid) swapped by material variants.
const LEAF_CELLS := [Rect2(0.5, 0.25, 0.125, 0.25), Rect2(0.125, 0.5, 0.125, 0.25), Rect2(0.375, 0.75, 0.125, 0.25)]
const VARIANTS := {
	"blossom": [Color("ffb3d1"), Color("ff9fc4"), Color("ffc9df")],
	"autumn": [Color("ffc46b"), Color("ff9a5c"), Color("ffd98a")],
	"mint": [Color("8fe8c0"), Color("6fd6b0"), Color("a8f0d0")],
}

static var _parts := {}
static var _mats := {}


## [[Mesh, Transform3D], ...] for a prop path like "nature/trees_A_large".
static func parts(path: String) -> Array:
	if _parts.has(path):
		return _parts[path]
	var out: Array = []
	var ps: PackedScene = load(ROOT % path)
	if ps == null:
		push_warning("Kit: missing " + path)
		_parts[path] = out
		return out
	var root := ps.instantiate() as Node3D
	_collect(root, Transform3D.IDENTITY, out, true)
	root.free()
	_parts[path] = out
	return out


static func _collect(n: Node, xf: Transform3D, out: Array, is_root: bool) -> void:
	var t := xf
	if n is Node3D and not is_root:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		out.append([(n as MeshInstance3D).mesh, t])
	for c in n.get_children():
		_collect(c, t, out, false)


static func texture_of(mesh: Mesh) -> Texture2D:
	var m := mesh.surface_get_material(0)
	if m is BaseMaterial3D:
		return (m as BaseMaterial3D).albedo_texture
	return null


## Shared toon material for an atlas texture, optionally recolored.
static func mat(tex: Texture2D, variant := "", emit := 0.0) -> ShaderMaterial:
	var key := "%d|%s|%.2f" % [tex.get_instance_id() if tex else 0, variant, emit]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = Art.shader("toon_tex")
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("lift", 0.1)
	m.set_shader_parameter("rim", 0.25)
	if VARIANTS.has(variant):
		var cols: Array = VARIANTS[variant]
		for i in 3:
			var r: Rect2 = LEAF_CELLS[i]
			var n: String = ["swap_a", "swap_b", "swap_c"][i]
			m.set_shader_parameter(n + "_rect", Vector4(r.position.x, r.position.y, r.end.x, r.end.y))
			m.set_shader_parameter(n, cols[i])
	elif variant.begins_with("=") or variant.begins_with("~"):
		# "=#hex" repaints the prop in one pastel; "~#hex" only leans toward it.
		var c := Color(variant.substr(1))
		m.set_shader_parameter("recolor", Color(c.r, c.g, c.b, 0.85 if variant.begins_with("=") else 0.45))
	elif variant.begins_with("#"):
		m.set_shader_parameter("tint", Color(variant))
	if emit > 0.0:
		m.set_shader_parameter("emission_color", Color("ffe6b0"))
		m.set_shader_parameter("emission_energy", emit)
	_mats[key] = m
	return m


## A standalone (non-batched) copy, e.g. for props that move.
static func spawn(parent: Node3D, path: String, pos: Vector3, rot_y := 0.0, s := 1.0, variant := "") -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	n.scale = Vector3.ONE * s
	parent.add_child(n)
	for p in parts(path):
		var mi := MeshInstance3D.new()
		mi.mesh = p[0]
		mi.transform = p[1]
		mi.material_override = mat(texture_of(p[0]), variant)
		n.add_child(mi)
	return n
