extends Node
## Focused check: losing a battle wakes you up at home, healed, able to move.

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().create_timer(1.0).timeout
	main.title.visible = false
	Game.new_game("Luna", "witch", 0, 0)
	await main.load_map("city", Vector3(-10, 0, 8), false)
	main.mode = main.Mode.EXPLORE
	for c in main.critters:
		c.active = false
	Game.state["hp"] = 1
	main.run_script(func(): await main.battle(["bee"], "park"))
	var b: Battle = null
	while b == null:
		await get_tree().create_timer(0.2).timeout
		for c in main.get_children():
			if c is Battle:
				b = c
	while not b._cmd_panel.visible:
		await get_tree().create_timer(0.2).timeout
	b._command_chosen.emit({"type": "guard"})
	var t := 0.0
	while t < 120.0 and main.mode != main.Mode.EXPLORE:
		if main.ui.is_dialog_open():
			main.ui._advance()
		# Stay at 1 HP (Mochi likes to heal you!) and never time the guard.
		if is_instance_valid(b) and not b._over and Game.state["hp"] > 1:
			Game.state["hp"] = 1
		if is_instance_valid(b) and b._cmd_panel.visible:
			b._command_chosen.emit({"type": "guard"})
		await get_tree().create_timer(0.2).timeout
		t += 0.2
	print("RESULT map=", main.world.map_id, " hp=", Game.state["hp"], "/", Game.state["max_hp"], " mode=", main.mode)
	get_tree().quit()
