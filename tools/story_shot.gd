extends Node
## Renders the story layer for review (needs a window): the mailbox and shelf at the hut, a letter, the dream, the ending.
## Usage: tools/story_shot.sh -> renders/story_*.png

func shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png("res://renders/story_%s.png" % n)
	print("saved ", n)

func _ready() -> void:
	DisplayServer.window_move_to_foreground()   # a window behind others stops redrawing on macOS: captures would come back stale
	GameState.save_slot = "test_story_shot"
	GameState.delete_save()
	GameState.reset()
	var g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	g.test_capture = true
	await get_tree().process_frame
	await get_tree().process_frame
	g.stats.eye_fed = 300
	for k in ["thermos", "key", "photo", "compass", "mitten"]:
		g.story.keeps.append(k)
	g._refresh()
	var hut: Node3D = g.hut_node
	var p: Node3D = g.get_node("Player")
	var fwd: Vector3 = hut.global_basis.z
	p.position = Vector3(hut.global_position.x + fwd.x * 8.0 - hut.global_basis.x.x * 1.5, 1.7, hut.global_position.z + fwd.z * 8.0 - hut.global_basis.x.z * 1.5)
	p.look_at(Vector3(hut.global_position.x - hut.global_basis.x.x * 1.8, 1.7, hut.global_position.z - hut.global_basis.x.z * 1.8), Vector3.UP)
	p.rotation.x = 0.0
	g.cam.rotation.x = deg_to_rad(-4.0)
	g.day_t = 0.25
	g.scenery.set_time(0.25)
	g.get_node("UI").visible = false
	g.tool_view.visible = false
	for i in 14:
		await get_tree().process_frame
	shot("hut")
	g.get_node("UI").visible = true
	g.tool_view.visible = true
	g._open_letters()
	for i in 90:
		await get_tree().process_frame
	shot("letter")
	g._close_letters()
	g._close_letters()
	g.test_capture = false
	g.dream.play(Story.dream_lines(1, 412), "THE EYE DREAMS")
	for step in [[3.0, "dream_a"], [3.4, "dream_b"]]:
		while g.dream.t < step[0]:
			await get_tree().process_frame
		shot(step[1])
	g.dream.t = g.dream.total_time()
	await get_tree().process_frame
	g.dream.play(Story.ENDING_LINES, "THE EYE REMEMBERS", 1.0, 4.4)
	while g.dream.t < 11.0:
		await get_tree().process_frame
	shot("ending")
	get_tree().quit()
