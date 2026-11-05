class_name Opening
extends Node
## The opening: a dusk title orbit, the dog-sled arrival (Olga drives, hands you a rod, the Eye opens one lid), and the "previously" beat
## for a continued save. The guide owns the machinery (letterbox, captions, skip, HUD hiding, input lock); this class owns what is IN the
## shot: the sled team, Olga, the camera poses (through CameraDirector) and the sounds.

const START := Vector3(-8.2, 1.7, 14.3)   # where the player stands when play begins
const BACK := 2.4                          # the sled stops this far behind the start spot: you step off and walk the last bit
const INTRO_LEN := 41.5
const PREV_LEN := 11.0
const STOP_AT := 22.0
const DEPART_AT := 31.0
const LID_AT := 35.2
const FOV := 75.0
const DUSK := 0.21                         # the sky for the title and the opening: the start of dusk; a new game begins here

var game: Node
var guide: Node
var rig: Node3D                  # the sled team and Olga (null outside the scene)
var parts: Dictionary = {}
var stop_pos := Vector3.ZERO
var fwd := Vector3.ZERO          # flat unit vector from the start spot to the Eye
var a_stop := 0.0
var r_stop := 0.0
var run_phase := 0.0
var bell_t := 0.0
var hiss_t := 0.0
var barked := {}
var drive_off := false           # the sled keeps pulling away after the scene ends, then Olga reappears at her hut
var drive_t := 0.0
var lid := 0.0                   # 0..1: how far the Eye has opened for the scene
var _cards: Array = []

func setup(g: Node, gd: Node) -> void:
	game = g
	guide = gd
	fwd = Vector3(-START.x, 0.0, -START.z).normalized()
	stop_pos = Vector3(START.x, 0.0, START.z) - fwd * BACK
	a_stop = rad_to_deg(atan2(stop_pos.x, -stop_pos.z))
	r_stop = Vector2(stop_pos.x, stop_pos.z).length()

# ---------------------------------------------------------------- the title

## The title camera: a slow, never-repeating drift over the ice toward the Eye, camp lights behind it.
func title_pose(t: float, mouse := Vector2.ZERO) -> Dictionary:
	var bearing := -150.0 + 11.0 * sin(t * 0.043) + 4.0 * sin(t * 0.109 + 1.3)
	var radius := 27.0 + 3.0 * sin(t * 0.067)
	var height := 2.8 + 1.2 * sin(t * 0.051 + 1.0)
	var pos := CameraDirector.orbit(Vector3.ZERO, bearing, radius, height)
	var look := Vector3(0.0, 1.9 + 0.6 * sin(t * 0.083), 0.0) + Vector3(sin(t * 0.05) * 2.0, 0.0, cos(t * 0.04) * 2.0)
	# the mouse nudges the view a little (glass-window parallax): -1..1 across the screen is about 1.4 degrees
	var right := Vector3(look - pos).cross(Vector3.UP).normalized()
	look += right * mouse.x * 0.9 + Vector3.UP * (-mouse.y) * 0.45
	return CameraDirector.pose(pos, look, 62.0 + 2.0 * sin(t * 0.03), 0.012 * sin(t * 0.07), 0.04)

# ---------------------------------------------------------------- the paths

func _path(u: float) -> Vector3:
	var a := deg_to_rad(lerpf(-172.0, a_stop, CameraDirector.smooth(u)))
	var r := lerpf(86.0, r_stop, u)
	return Vector3(sin(a) * r, 0.0, -cos(a) * r)

## Where the team is at scene time t: position, heading (unit), speed (m/s) and the distance travelled.
func sled_state(t: float) -> Dictionary:
	var x := clampf(t / STOP_AT, 0.0, 1.0)
	var u := 1.0 - pow(1.0 - x, 2.2)
	var du := 0.002
	var p := _path(u)
	var h := (_path(minf(u + du, 1.0)) - _path(maxf(u - du, 0.0)))
	h.y = 0.0
	var speed := 0.0
	if t < STOP_AT:
		speed = 76.0 * (2.2 / STOP_AT) * pow(1.0 - x, 1.2)
		h = h.normalized()
	else:
		h = (stop_pos - _path(0.97))
		h.y = 0.0
		h = h.normalized()
	if t >= DEPART_AT:   # Olga turns the team toward the hut and drives off
		var hut: Vector3 = game.hut_pos
		var to_hut := (Vector3(hut.x, 0.0, hut.z) - stop_pos)
		to_hut.y = 0.0
		to_hut = to_hut.normalized()
		var k := CameraDirector.smooth(CameraDirector.span(t, DEPART_AT, DEPART_AT + 2.2))
		h = h.lerp(to_hut, k).normalized()
		var dt := t - DEPART_AT
		var s := 0.5 * 2.6 * dt * dt if dt < 2.38 else 7.37 + 6.2 * (dt - 2.38)   # accelerates to 6.2 m/s, then cruises
		p = stop_pos + to_hut * s * k
		speed = minf(2.6 * dt, 6.2) * (0.3 + 0.7 * k)
	return {"pos": p, "h": h, "speed": speed}

func _basis_for(h: Vector3) -> Basis:
	return Basis.looking_at(h, Vector3.UP)   # local -Z = heading

# ---------------------------------------------------------------- building the actors

func _box(parent: Node, pos: Vector3, size: Vector3, c: Color, emit := 0.0) -> MeshInstance3D:
	return ToolModels.box(parent, pos, size, c, emit, 0.7, 0.0)

func _build_rig() -> void:
	rig = Node3D.new()
	game.add_child(rig)
	var sled := Node3D.new()
	rig.add_child(sled)
	var wood := Color(0.42, 0.28, 0.19)
	var dark := Color(0.26, 0.18, 0.14)
	var steel := Color(0.55, 0.6, 0.7)
	for sx in [-0.5, 0.5]:   # runners, with the front curling up
		_box(sled, Vector3(sx, 0.09, 0.2), Vector3(0.07, 0.1, 2.7), steel)
		var curl := _box(sled, Vector3(sx, 0.2, -1.3), Vector3(0.07, 0.1, 0.5), steel)
		curl.rotation_degrees.x = 24.0
		for z in [-0.6, 0.5, 1.4]:
			_box(sled, Vector3(sx, 0.2, z), Vector3(0.06, 0.2, 0.08), dark)
	_box(sled, Vector3(0, 0.3, 0.1), Vector3(1.0, 0.07, 1.9), wood)   # the basket floor
	for sx in [-0.5, 0.5]:
		_box(sled, Vector3(sx, 0.45, 0.1), Vector3(0.07, 0.3, 1.9), dark)   # sides
	_box(sled, Vector3(0, 0.45, -0.82), Vector3(1.0, 0.28, 0.07), dark)   # the front board (low: you look over it at the dogs)
	_box(sled, Vector3(0, 0.7, 0.98), Vector3(1.0, 0.7, 0.07), dark)   # the backrest
	_box(sled, Vector3(0, 0.4, 0.2), Vector3(0.84, 0.1, 1.1), Color(0.16, 0.5, 0.58))   # a teal blanket
	_box(sled, Vector3(0.0, 0.46, 0.5), Vector3(0.84, 0.05, 0.2), Color(0.95, 0.92, 0.84))   # with a cream stripe
	_box(sled, Vector3(0, 0.22, 1.65), Vector3(1.0, 0.05, 0.75), dark)   # Olga's standing board
	for sx in [-0.45, 0.45]:   # the handlebar
		_box(sled, Vector3(sx, 0.75, 1.3), Vector3(0.05, 1.1, 0.05), wood)
	_box(sled, Vector3(0, 1.28, 1.3), Vector3(1.0, 0.06, 0.06), wood)
	_box(sled, Vector3(0.62, 0.6, 0.6), Vector3(0.3, 0.3, 0.3), Color(0.5, 0.36, 0.24))   # a lashed crate on the side
	var lan := Node3D.new()   # a lantern on a bracket at the front-left
	lan.position = Vector3(-0.62, 0.95, -1.55)   # out on the bow, so it hangs in the shot instead of in your face
	sled.add_child(lan)
	_box(lan, Vector3(0, -0.5, 0), Vector3(0.04, 1.0, 0.04), dark)
	_box(lan, Vector3(0.12, 0.08, 0), Vector3(0.28, 0.03, 0.03), dark)   # the bracket arm
	_box(lan, Vector3(0.0, 0.1, 0), Vector3(0.14, 0.03, 0.14), dark)   # the lantern's cap
	var gl := _box(lan, Vector3(0, 0.0, 0), Vector3(0.1, 0.14, 0.1), Color(1.0, 0.76, 0.32), 1.5)
	gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ll := OmniLight3D.new()
	ll.light_color = Color(1.0, 0.7, 0.35)
	ll.omni_range = 9.0
	ll.light_energy = 1.4
	lan.add_child(ll)
	parts["lantern"] = lan
	# the team: two pairs, a long tow line down the middle
	var dogs: Array = []
	var furs := [[Color(0.72, 0.58, 0.42), Color(0.3, 0.22, 0.18)], [Color(0.8, 0.82, 0.86), Color(0.35, 0.37, 0.45)],
		[Color(0.55, 0.45, 0.38), Color(0.22, 0.17, 0.15)], [Color(0.9, 0.86, 0.78), Color(0.5, 0.4, 0.32)]]
	var slots := [Vector3(-0.5, 0, -3.6), Vector3(0.5, 0, -3.6), Vector3(-0.5, 0, -5.4), Vector3(0.5, 0, -5.4)]
	for i in 4:
		var d: Dictionary = NpcModels.dog(furs[i][0], furs[i][1])
		(d.root as Node3D).position = slots[i]
		sled.add_child(d.root)
		dogs.append(d)
	_box(sled, Vector3(0, 0.45, -3.3), Vector3(0.04, 0.04, 5.0), Color(0.2, 0.16, 0.13))   # the gangline
	for sx in [-0.5, 0.5]:
		_box(sled, Vector3(sx * 0.9, 0.5, -3.6), Vector3(0.03, 0.03, 4.2), Color(0.25, 0.2, 0.16))
	parts["dogs"] = dogs
	# Olga, on the board, facing forward (+Z of her model is world -Z)
	var o: Dictionary = NpcModels.olga()
	(o.root as Node3D).position = Vector3(0, 0.25, 1.7)
	(o.root as Node3D).rotation.y = PI
	sled.add_child(o.root)
	parts["olga"] = o
	# the gift
	var gift := Node3D.new()
	var gb := Node3D.new()
	gift.add_child(gb)
	ToolModels.rod(gb, ToolModels.WOOD, 0, false)
	gift.visible = false
	gift.scale = Vector3.ONE * 1.1
	rig.add_child(gift)
	parts["gift"] = gift
	# snow thrown up by the runners, and the dogs' breath
	var spray := CPUParticles3D.new()
	spray.position = Vector3(0, 0.15, 1.2)
	spray.amount = 60
	spray.lifetime = 1.1
	spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	spray.emission_box_extents = Vector3(0.7, 0.05, 0.3)
	spray.direction = Vector3(0, 1, 1)
	spray.spread = 35.0
	spray.gravity = Vector3(0, -3.0, 0)
	spray.initial_velocity_min = 1.0
	spray.initial_velocity_max = 3.2
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	sm.radial_segments = 4
	sm.rings = 2
	spray.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(1, 1, 1, 0.8)
	spray.material_override = smat
	spray.emitting = false
	sled.add_child(spray)
	parts["spray"] = spray
	parts["sled"] = sled

func _free_rig() -> void:
	if rig and is_instance_valid(rig):
		rig.queue_free()
	rig = null
	parts.clear()

# ---------------------------------------------------------------- the scenes

func length(kind: String) -> float:
	return INTRO_LEN if kind == "intro" else PREV_LEN

func captions(kind: String) -> Array:
	if kind == "intro":
		return [
			[1.0, 4.8, "Hush Lake.\nEvery winter it freezes over a little earlier.", false],
			[5.2, 9.2, "Out on the ice, something old watches through the dark water.", false],
			[9.9, 14.8, "Olga, who keeps the hut, calls it the Eye.\nIt is very hungry. And it pays well for what it is fed.", false],
			[16.2, 19.6, "Olga: Hold on, dear. The dogs know the way.", true],
			[20.0, 22.6, "Olga: Easy... easy now. Whoa.", true],
			[24.0, 27.2, "Olga: Forty winters I have watched it.\nIt never once looked back.", true],
			[27.6, 30.4, "Olga: Take this. Feed it, dear, and it pays.", true],
			[31.2, 34.6, "Olga: Go on. Drill a hole. Catch a fish.", true],
			[37.6, 41.0, "...it is looking at you.", false],
		]
	return _cards

func begin(kind: String) -> void:
	_free_rig()
	barked.clear()
	run_phase = 0.0
	lid = 0.0
	drive_off = false
	drive_t = 0.0
	game.sfx.set_hum(0.35)
	if kind == "intro":
		_build_rig()
		var oh: Dictionary = game.scenery.olga
		if not oh.is_empty():
			(oh.root as Node3D).visible = false   # she is out on the lake with you: the hut has no Olga until the sled gets home
		game.scenery.eye_prelude(true)
		game.flash_rect.color = Color(0.01, 0.02, 0.05, 1.0)
		tick("intro", 0.0, 0.0)
	else:
		_build_cards()
		game.flash_rect.color = Color(0.01, 0.02, 0.05, 1.0)
		tick("previously", 0.0, 0.0)

func _build_cards() -> void:
	var s: Dictionary = game.stats
	var st: int = game.eye_stage()
	var eye_line: String = "It has not noticed you yet." if st <= 0 else String(game.EYE_LINES[mini(st - 1, game.EYE_LINES.size() - 1)])
	var step: Dictionary = guide.current()
	var next := "Olga: Next, dear: %s." % String(step.title).to_lower() if not step.is_empty() else "Olga: Mind the ice, dear."
	var when: String = game.day_phase()
	_cards = [
		[0.9, 3.4, "Previously, on Hush Lake...", true],
		[3.7, 6.4, "%s fish fed to the Eye.\n%d of %d sectors cleared." % [game._fmt_num(float(s.eye_fed)), game.model.cleared_count(), game.model.sectors.size()], false],
		[6.7, 9.0, "The Eye: stage %d of %d.\n%s" % [st, game.EYE_STAGES.size(), eye_line], false],
		[9.2, 10.9, next, true],
	]
	var _unused := when

## Called every frame of a scene by the guide. `t` is scene time, `delta` the frame time.
func tick(kind: String, t: float, delta: float) -> void:
	if kind == "intro":
		_tick_intro(t, delta)
	else:
		_tick_previously(t)
	var cam: Camera3D = game.cam
	game.cine_fov = CameraDirector.apply(cam, _pose, t, game.fov_base)

var _pose: Dictionary = {}

## The player's real first view: the camera lands here, so handing over control cannot jump.
func final_pose() -> Dictionary:
	var pl: Node3D = game.get_node("Player")
	var b := Basis(Vector3.UP, pl.rotation.y) * Basis(Vector3.RIGHT, guide.cam_pitch)
	var pos := pl.global_position
	return CameraDirector.pose(pos, pos + b * Vector3(0, 0, -10.0), game.fov_base, 0.0, 0.0)

func _tick_previously(t: float) -> void:
	game.flash_rect.color = Color(0.01, 0.02, 0.05, 1.0 - CameraDirector.smooth(CameraDirector.span(t, 0.0, 1.3)))
	var fin := final_pose()
	var hut: Vector3 = game.hut_pos
	var p1 := CameraDirector.pose(Vector3(0.0, 70.0, 26.0), Vector3(0.0, 0.0, 0.0), 58.0, 0.0, 0.0)   # high over the Eye, looking down
	var p2 := CameraDirector.pose(Vector3(hut.x * 0.6 - 10.0, 22.0, hut.z * 0.6 + 34.0), Vector3(hut.x * 0.5, 1.0, hut.z * 0.5 - 2.0), 62.0, -0.04, 0.05)   # swinging over the camp
	var p3 := CameraDirector.pose(fin.pos + Vector3(0, 7.0, 10.0) , fin.pos + Vector3(0.0, 0.5, 0.0) + (fin.look - fin.pos).normalized() * 6.0, 66.0, 0.0, 0.04)   # settling behind you
	var pose := p1
	if t < 4.6:
		pose = CameraDirector.blend(p1, p2, CameraDirector.smoother(CameraDirector.span(t, 0.5, 4.6)))
	elif t < 8.2:
		pose = CameraDirector.blend(p2, p3, CameraDirector.smoother(CameraDirector.span(t, 4.6, 8.2)))
	else:
		pose = CameraDirector.blend(p3, fin, CameraDirector.smoother(CameraDirector.span(t, 8.2, PREV_LEN)))
	_pose = pose

func _tick_intro(t: float, delta: float) -> void:
	var st := sled_state(t)
	var pos: Vector3 = st.pos
	var h: Vector3 = st.h
	var spd: float = st.speed
	var sled: Node3D = parts.sled
	if sled == null:
		return
	rig.global_transform = Transform3D(_basis_for(h), pos)
	# the gait follows distance, so the legs never skate
	run_phase += spd * delta * 1.6
	for d in parts.dogs:
		NpcModels.dog_run(d, run_phase + (0.0 if d.root.position.x < 0.0 else 0.9) + d.root.position.z * 0.3, spd)
	(parts.spray as CPUParticles3D).emitting = spd > 1.2
	(parts.lantern as Node3D).rotation.z = sin(t * 3.1) * 0.12 * minf(spd / 4.0, 1.0)
	_animate_olga(t)
	_sounds(t, spd, delta)
	_pose = _intro_pose(t, pos, h)
	_fade(t)
	_eye(t)

func _fade(t: float) -> void:
	var a := 1.0 - CameraDirector.smooth(CameraDirector.span(t, 0.0, 1.5))
	game.flash_rect.color = Color(0.01, 0.02, 0.05, a)

func _eye(t: float) -> void:
	var x := CameraDirector.smooth(CameraDirector.span(t, LID_AT, LID_AT + 3.4))
	if x > 0.0 and lid <= 0.0:
		game.scenery.eye_prelude(false)
		game.scenery.pulse_eye()
		game.sfx.play("rumble", -8.0, 0.8)
		game.sfx.play("swell", -10.0, 0.7)
		game.shake = maxf(game.shake, 0.05)
		game.scenery.eye.wave = 0.0
		game.scenery.eye.wave_amp = 1.4
	lid = maxf(lid, x)
	game.cine_eye = 0.10 * x
	game.scenery.set_eye_open(game.eye_open_frac())
	game.sfx.set_hum(0.35 + 0.65 * x)
	if x > 0.0:
		game.scenery.eye.flare = maxf(game.scenery.eye.flare, 1.5 * sin(PI * minf(x, 1.0)))

func _animate_olga(t: float) -> void:
	var o: Dictionary = parts.olga
	var body: Node3D = o.body
	var arm: Node3D = o.arm
	var arm_l: Node3D = o.arm_l
	var head: Node3D = o.head
	var drive := 1.0 - CameraDirector.smooth(CameraDirector.span(t, 26.2, 27.0)) + CameraDirector.smooth(CameraDirector.span(t, 29.6, 30.4))
	drive = clampf(drive, 0.0, 1.0)
	arm_l.rotation_degrees.x = lerpf(-14.0, -78.0, drive)   # both hands on the bar while driving
	arm_l.rotation_degrees.z = lerpf(-14.0, -8.0, drive)
	arm.rotation_degrees.z = lerpf(14.0, 8.0, drive)
	var offer := CameraDirector.smooth(CameraDirector.span(t, 26.4, 27.4)) * (1.0 - CameraDirector.smooth(CameraDirector.span(t, 28.9, 29.6)))
	arm.rotation_degrees.x = lerpf(-78.0 * drive, -92.0, offer)   # the right arm reaches toward you with the rod
	head.rotation_degrees.y = sin(t * 0.7) * 8.0 + (6.0 if t > 31.0 else 0.0)
	head.rotation_degrees.x = -4.0 * sin(t * 1.3)
	body.rotation_degrees.x = -3.0 * drive
	var o_root: Node3D = o.root
	o_root.position.y = 0.25 + 0.012 * sin(t * 9.0) * float(drive)
	# the rod: from her hand to yours, then gone into your hands
	var gift: Node3D = parts.gift
	var g_t := CameraDirector.span(t, 26.6, 28.9)
	gift.visible = g_t > 0.0 and g_t < 1.0
	if gift.visible:
		var from: Vector3 = (o_root as Node3D).to_global(Vector3(0.25, 1.0, 0.55))
		var cam_p: Vector3 = _pose.pos if _pose.has("pos") else from
		var to: Vector3 = cam_p + (_pose.look - cam_p).normalized() * 0.55 + Vector3(0.22, -0.28, 0.0)
		var e := CameraDirector.smooth(g_t)
		gift.global_position = from.lerp(to, e)
		var face: Vector3 = (cam_p - from).normalized()
		gift.global_transform.basis = Basis.looking_at(-face, Vector3.UP) * Basis(Vector3.UP, PI)   # the handle toward you, the tip toward her
		gift.scale = Vector3.ONE * lerpf(1.1, 0.7, e)
	if g_t >= 1.0 and not barked.has("gift"):
		barked["gift"] = true
		game.sfx.play("buy", -6.0, 1.3)
		game.view_pop = 0.8

func _sounds(t: float, spd: float, delta: float) -> void:
	bell_t -= delta
	hiss_t -= delta
	if spd > 0.8:
		if bell_t <= 0.0:
			bell_t = lerpf(0.9, 0.4, clampf(spd / 6.0, 0.0, 1.0))
			game.sfx.play("bells", -14.0 + minf(spd, 6.0) * 0.7, randf_range(0.92, 1.08))
		if hiss_t <= 0.0:
			hiss_t = 0.22
			game.sfx.play("slide", -14.0 + minf(spd, 7.0) * 0.8, randf_range(0.7, 0.9))
	for bt in [21.4, 30.6]:
		if t >= bt and not barked.has(bt):
			barked[bt] = true
			game.sfx.play("bark", -8.0, randf_range(0.95, 1.15))

# ---------------------------------------------------------------- the camera shots

func _intro_pose(t: float, pos: Vector3, h: Vector3) -> Dictionary:
	var right := h.cross(Vector3.UP).normalized()
	var up := Vector3.UP
	# A: the chase from above and behind: the lake, the Eye ahead, the team small and sure
	var ka := CameraDirector.span(t, 0.0, 10.2)
	var a := CameraDirector.pose(pos - h * lerpf(34.0, 15.0, ka) + up * lerpf(21.0, 8.5, ka) + right * lerpf(-7.0, 5.0, ka),
		pos + h * 15.0 + up * 1.2, lerpf(66.0, 56.0, ka), 0.0, 0.05)
	# B: low beside the dogs, fast
	var kb := CameraDirector.span(t, 9.4, 16.2)
	var b := CameraDirector.pose(pos + right * lerpf(8.5, 6.0, kb) + h * lerpf(7.0, -1.5, kb) + up * 1.05,
		pos + h * 3.6 + up * 0.85, lerpf(44.0, 52.0, kb), 0.0, 0.12)
	# C: from the basket, over the dogs' backs at the Eye
	var seat := pos + up * 1.0 - h * 0.0
	var sway := CameraDirector.sway(t * 1.2, 3.0) * 0.5
	var c := CameraDirector.pose(seat + up * 0.02 * sway.y, pos + h * 40.0 + up * 1.3 + right * sway.x * 1.2, lerpf(72.0, 66.0, CameraDirector.span(t, 15.6, 22.0)), 0.012 * sway.x, 0.22 * clampf(sled_state(t).speed / 5.0, 0.0, 1.0))
	# D: you turn in your seat to Olga, and she comes close
	var o: Node3D = parts.olga.root
	var olga_head: Vector3 = o.to_global(Vector3(0, 1.32, 0.04))
	var kd := CameraDirector.smoother(CameraDirector.span(t, 22.4, 24.4))
	var look_d := (pos + h * 30.0 + up * 1.3).lerp(olga_head, kd)
	var d := CameraDirector.pose(seat, look_d, lerpf(66.0, 40.0, CameraDirector.smooth(CameraDirector.span(t, 23.4, 27.0))), 0.0, 0.07)
	# E: step off and walk onto the ice, turn to the Eye, the dolly-zoom as the lid lifts, then the world settles back to your own view
	var fin := final_pose()
	var kw := CameraDirector.smoother(CameraDirector.span(t, 30.0, 34.4))
	var stand := (pos + up * 1.0).lerp(fin.pos, kw)
	var bob := sin(kw * PI * 6.0) * 0.045 * sin(kw * PI)
	stand.y += bob
	var eye_t := Vector3(0.0, 1.6, 0.0)
	var look_e := olga_head.lerp(eye_t, CameraDirector.smoother(CameraDirector.span(t, 31.0, 34.0)))
	var kz := CameraDirector.smooth(CameraDirector.span(t, LID_AT - 0.2, LID_AT + 3.8))
	var fov_z := lerpf(FOV, 42.0, kz)
	var d0: float = Vector2(fin.pos.x, fin.pos.z).length()
	var pull := d0 * (tan(deg_to_rad(FOV * 0.5)) / tan(deg_to_rad(fov_z * 0.5)) - 1.0)
	var e_pos := stand - fwd * pull
	var e := CameraDirector.pose(e_pos, look_e, fov_z, 0.0, 0.04 + 0.12 * sin(PI * kz))
	var rel := CameraDirector.smoother(CameraDirector.span(t, LID_AT + 3.6, INTRO_LEN - 0.4))
	e = CameraDirector.blend(e, fin, rel)
	# the cuts: dissolves, never hard
	var pose := a
	if t < 9.4:
		pose = a
	elif t < 10.2:
		pose = CameraDirector.blend(a, b, CameraDirector.span(t, 9.4, 10.2))
	elif t < 15.6:
		pose = b
	elif t < 16.4:
		pose = CameraDirector.blend(b, c, CameraDirector.span(t, 15.6, 16.4))
	elif t < 22.4:
		pose = c
	elif t < 30.0:
		pose = d
	else:
		pose = e
	return pose

# ---------------------------------------------------------------- the end

## Restores everything the scene touched. `skipped`: the player skipped (jump straight to the end state).
func finish(kind: String, skipped: bool) -> void:
	game.flash_rect.color = Color(0.01, 0.02, 0.05, 0.0)
	GameState.autosave = not GameState.save_slot.begins_with("test")   # the run is real now: it may be saved
	game.sfx.set_hum(0.1)
	if kind == "intro":
		game.scenery.eye_prelude(false)
		game.stats["ajar"] = 1
		game.cine_eye = 0.0
		game.scenery.set_eye_open(game.eye_open_frac())
		game.equip(1)   # Olga's rod is in your hand
		var oh: Dictionary = game.scenery.olga
		if skipped or rig == null or not is_instance_valid(rig):
			_free_rig()
			if not oh.is_empty():
				(oh.root as Node3D).visible = true
		else:
			drive_off = true   # the team keeps pulling away toward the hut; Olga shows up there once it arrives
			drive_t = INTRO_LEN
		game.cine_fov = 0.0
	else:
		game.cine_fov = 0.0

func _process(delta: float) -> void:
	if not drive_off or rig == null or not is_instance_valid(rig):
		return
	drive_t += delta
	var st := sled_state(drive_t)
	var pos: Vector3 = st.pos
	rig.global_transform = Transform3D(_basis_for(st.h), pos)
	run_phase += float(st.speed) * delta * 1.6
	for d in parts.dogs:
		NpcModels.dog_run(d, run_phase + d.root.position.z * 0.3, st.speed)
	(parts.spray as CPUParticles3D).emitting = st.speed > 1.2
	if Vector2(pos.x - game.hut_pos.x, pos.z - game.hut_pos.z).length() < 8.0 or drive_t > INTRO_LEN + 30.0:
		drive_off = false
		_free_rig()
		var oh: Dictionary = game.scenery.olga
		if not oh.is_empty():
			(oh.root as Node3D).visible = true
