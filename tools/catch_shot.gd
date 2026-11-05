extends Node
## Renders the catch layer for review (needs a window): the field journal with every species found, and the fish models in a row.
## Usage: tools/catch_shot.sh -> renders/catch_journal.png, renders/catch_fish.png

func _ready() -> void:
	DisplayServer.window_move_to_foreground()   # a window behind others stops redrawing on macOS: captures would come back stale
	GameState.save_slot = "test_catch_shot"
	GameState.delete_save()
	GameState.reset()
	var g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	g.test_capture = true
	await get_tree().process_frame
	await get_tree().process_frame
	for i in g.SPECIES.size():
		if i % 3 != 2:
			g.journal[g.SPECIES[i].name] = 1 + i
			g.records[g.SPECIES[i].name] = 20.0 + i
	g.journal_panel.visible = true
	g._update_journal()
	for i in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://renders/catch_journal.png")
	print("saved journal")
	g.journal_panel.visible = false
	# the fish in a row on the ice, side on, lit by the day
	var pl: Node3D = g.get_node("Player")
	pl.position = Vector3(0.0, 1.7, 64.0)
	pl.rotation.y = 0.0
	g.cam.rotation.x = deg_to_rad(-12.0)
	g.day_t = 0.0
	g.scenery.set_time(0.0)
	var i := 0
	for sp in g.SPECIES:
		var f: Node3D = FishModel.build(sp.name, sp.color, 1.0)
		g.add_child(f)
		f.position = Vector3(-4.6 + (i % 5) * 2.3, 0.45, 64.0 - 4.5 - (i / 5) * 1.6)
		f.scale *= 1.5
		i += 1
	g.get_node("UI").visible = false
	g.tool_view.visible = false
	for k in 8:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://renders/catch_fish.png")
	print("saved fish")
	get_tree().quit()
