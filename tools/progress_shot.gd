extends Node
## Renders the progression screens (needs a window): the Ledger and the refreeze card with its lake choice.
## Usage: tools/progress_shot.sh -> renders/progress_*.png

func shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png("res://renders/progress_%s.png" % n)
	print("saved ", n)

func _ready() -> void:
	GameState.save_slot = "test_progress_shot"
	GameState.delete_save()
	GameState.reset()
	GameState.meta = {"lakes": 2, "pearls": 7, "life": {"fed": 6200, "caught": 900, "sectors": 14, "tithe": 9, "rigs": 3}, "ledger": {"fed": 2, "caught": 1, "lakes": 1}, "ledger_pearls": 7, "life_species": ["Minnow", "Perch", "Silver Pike", "Lantern Eel"]}
	var g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	g.test_capture = true
	await get_tree().process_frame
	await get_tree().process_frame
	g.stats.eye_fed = 800
	g.stats.sectors = 3
	g.journal["Minnow"] = 3
	g.journal["Ghost Carp"] = 1
	g.story.keeps.append("key")
	g.ledger_panel.visible = true
	g._update_ledger()
	for i in 6:
		await get_tree().process_frame
	shot("ledger")
	g.ledger_panel.visible = false
	g.stats.ended = 1
	g._toggle_refreeze()
	for i in 6:
		await get_tree().process_frame
	shot("refreeze")
	get_tree().quit()
