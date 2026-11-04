extends Node3D
## A clean studio for judging assets: every machine, the tools and the fish lined up on blue ice under the game's sun.
## Usage: tools/showroom.sh  -> renders/room_*.png (needs a window)

func _env() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.17, 0.25, 0.55)
	sm.sky_horizon_color = Color(0.8, 0.82, 0.95)
	sm.ground_horizon_color = Color(0.8, 0.82, 0.95)
	sm.ground_bottom_color = Color(0.45, 0.7, 0.88)
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.85, 0.75)
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-38, 35, 0)
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.6, 0.75, 1.0)
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-20, -140, 0)
	add_child(fill)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.14, 0.3, 0.62)
	gm.roughness = 0.4
	ground.material_override = gm
	add_child(ground)

func _shoot(name: String, from: Vector3, target: Vector3, cam: Camera3D) -> void:
	cam.global_position = from
	cam.look_at(target, Vector3.UP)
	for i in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://renders/room_%s.png" % name)
	print("saved ", name)

func _ready() -> void:
	_env()
	var cam := Camera3D.new()
	cam.fov = 55.0
	add_child(cam)
	cam.current = true
	var parts := {}
	# machines
	var root := Node3D.new()
	add_child(root)
	var a := Node3D.new()
	a.position = Vector3(-6, 0, 0)
	a.scale = Vector3.ONE * 1.5
	root.add_child(a)
	var ap: Dictionary = MachineModels.auto_rod(a)
	var s := Node3D.new()
	s.position = Vector3(-2.5, 0, 0)
	s.scale = Vector3.ONE * 1.5
	root.add_child(s)
	var sp: Dictionary = MachineModels.smoker(s)
	sp.smoke.emitting = true
	var t := Node3D.new()
	t.position = Vector3(1.0, 0, 0)
	t.scale = Vector3.ONE * 1.5
	root.add_child(t)
	MachineModels.gut_table(t)
	var bl := Node3D.new()
	bl.position = Vector3(5.5, 0.55, 0)
	root.add_child(bl)
	bl.rotation_degrees.y = 90
	MachineModels.belt(bl, 8.0, 2.0)
	var c := Node3D.new()
	c.position = Vector3(-6, 0, 12)
	root.add_child(c)
	MachineModels.cannery(c)
	var so := Node3D.new()
	so.position = Vector3(0, 0, 12)
	root.add_child(so)
	MachineModels.sorter(so)
	var d := Node3D.new()
	d.position = Vector3(7, 0, 12)
	root.add_child(d)
	MachineModels.depot(d)
	var r := Node3D.new()
	r.position = Vector3(0, 0, 32)
	root.add_child(r)
	MachineModels.rig(r)
	# fish
	var fish := Node3D.new()
	fish.position = Vector3(0, 0.5, -10)
	add_child(fish)
	var i := 0
	for sp_name in ["Minnow", "Perch", "Silver Pike", "Golden Trout", "Ancient Fish", "Old Boot", "Old Coin", "Glass Pearl"]:
		var f := FishModel.build(sp_name, Color.WHITE, 0.34 * 2.2)
		f.position = Vector3(-7 + i * 2.0, 0.0, 0)
		f.rotation_degrees.y = -30
		(f as FishNode).amp = 0.4
		fish.add_child(f)
		i += 1
	# tools
	await get_tree().process_frame
	await _shoot("machines_a", Vector3(-1, 3.2, 8), Vector3(-1, 1.0, 0), cam)
	await _shoot("machines_b", Vector3(0, 4.5, 24), Vector3(0, 1.8, 12), cam)
	await _shoot("rig", Vector3(8, 6, 44), Vector3(0, 2.5, 32), cam)
	await _shoot("rig_side", Vector3(-12, 5, 36), Vector3(0, 2.5, 32), cam)
	await _shoot("fish", Vector3(0, 1.8, -5.5), Vector3(0, 0.5, -10), cam)
	await _shoot("cannery_close", Vector3(-6, 3.0, 19), Vector3(-6, 1.5, 12), cam)
	await _shoot("auto_close", Vector3(-6, 2.6, 4.5), Vector3(-6, 1.0, 0), cam)
	await _shoot("depot_close", Vector3(10, 3.5, 18), Vector3(7, 1.0, 12), cam)
	get_tree().quit()
