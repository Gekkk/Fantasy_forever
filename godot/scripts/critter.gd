class_name Critter
extends Node3D
## A grumpy critter wandering the overworld. Touching it starts a battle.

signal touched(critter: Critter)

var enemy_id := "cloud"
var uid := "" # set for quest critters that should stay cheered-up
var area := Rect2(-5, -5, 10, 10)
var player: Node3D
var model: ModelAnim
var active := true
var aura: CPUParticles3D

var _target := Vector3.ZERO
var _wait := 0.0
var _alerted := false
var _alert_label: Label3D


func _ready() -> void:
	model = Models.critter(enemy_id)
	model.scale = Vector3.ONE * 0.9
	add_child(model)
	_alert_label = Art.label3d(self, "!", Vector3(0, model.height + 0.4, 0), 96, Color("ffd36b"))
	_alert_label.visible = false
	if uid != "":
		aura = Art.ambient(self, Vector3(0, 0.6, 0), Vector3(0.5, 0.5, 0.5), Color("c38bff"), 10, "sparkle", 0.25, 1.5)
	_pick_target()


func _pick_target() -> void:
	_target = Vector3(randf_range(area.position.x, area.end.x), 0, randf_range(area.position.y, area.end.y))
	_wait = randf_range(0.5, 2.5)


func _process(delta: float) -> void:
	if not active or player == null:
		model.moving = false
		return
	var to_player := player.global_position - global_position
	to_player.y = 0
	var dist := to_player.length()
	var dir := Vector3.ZERO
	var speed := 1.1
	if dist < 4.5 and player.get("can_move") and not player.get_meta("invulnerable", false):
		if not _alerted:
			_alerted = true
			_alert_label.visible = true
			Audio.sfx("ui_move", 0.0, -4.0)
			get_tree().create_timer(0.8).timeout.connect(func(): _alert_label.visible = false)
		dir = to_player.normalized()
		speed = 2.3
	else:
		_alerted = false
		if _wait > 0.0:
			_wait -= delta
		else:
			var to_t := _target - global_position
			to_t.y = 0
			if to_t.length() < 0.3:
				_pick_target()
			else:
				dir = to_t.normalized()
	if dir != Vector3.ZERO:
		position += dir * speed * delta
		position.x = clampf(position.x, area.position.x, area.end.x)
		position.z = clampf(position.z, area.position.y, area.end.y)
		model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), minf(1.0, 8.0 * delta))
	model.moving = dir != Vector3.ZERO
	if dist < 0.95 and player.get("can_move") and not player.get_meta("invulnerable", false):
		active = false
		touched.emit(self)
