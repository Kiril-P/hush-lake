class_name Guide
extends Node
## Onboarding and hand-holding. Four pieces:
##  - an intro flyover with Olga's captions (fresh games only; click to skip)
##  - a live "what to do now" strip, worked out from game state (so it also works after loading a save)
##  - a world marker plus an edge-of-screen arrow pointing at wherever the step happens
##  - one-time tips (new tools, first affordable upgrades), and H to ask where to go

const INTRO := [
	[0.0, 3.2, "Hush Lake.\nEvery winter it freezes over a little earlier.", false],
	[3.4, 6.8, "Out on the ice, something old watches through the dark water.\nOlga, who keeps the hut, calls it the Eye.", false],
	[7.0, 9.8, "It is very hungry.\nAnd it pays well for what it is fed.", false],
	[10.0, 12.4, "Olga: Drill a hole, dear. Catch a fish.\nCarry it to the Eye.", true],
]
const INTRO_LEN := 12.8
const INTRO_FLY := 11.0
const BAR_H := 78.0
const STUCK_AFTER := 45.0
const DRILL_SPOT_FROM := Vector3(-8.2, 0.0, 14.3)

# how-to text for the main-line goals, by goal text: [hint, where]
# where: "" none, "eye", "hole", "auto", "hut", "stall:<upgrade id>"
const HINTS := {
	"Earn 50 coins": ["Keep fishing and feeding the Eye. Every fish pays as it is swallowed.", ""],
	"Fish a patch empty": ["Fish the same area dry. The lake map (bottom left) shows what is left in each patch.", ""],
	"Build an Auto-Rod": ["Press 3, then click a hole you drilled. It fishes on its own - click it to collect.", "hole"],
	"Lay a belt to the Eye": ["Press 6, then click your Auto-Rod. A belt carries its catch into the Eye.", "auto"],
	"Feed the Eye 25 fish": ["Belts feed it while you build more Auto-Rods (3).", "eye"],
	"Buy a Snowmobile": ["Walk to its stall and click the sign. Then press V to ride.", "stall:snowmobile"],
	"Build a Cannery on a belt": ["Press 7, press Q until it says Cannery, then click a belt's Auto-Rod.", "auto"],
	"Build a Depot": ["Press 7, press Q until it says Depot, then click open ice. Drop fish there for a sled to run them in.", ""],
	"Build an Ice-Breaker": ["Press 7, press Q until it says Ice-Breaker, then click open ice. It is big and expensive and it never stops.", ""],
	"Drill 4 holes": ["Press 1 and hold click on fresh ice. Wide Drill opens several at once.", ""],
	"Clear the Shallows": ["Fish every hole in the Shallows dry. Sonar shows where fish still hide.", ""],
	"Earn 250 coins": ["Gut Tables (5) and Smokers (4) make each fish worth more. Build them on fished-out holes.", ""],
	"Build 3 Auto-Rods": ["Press 3 and click holes. More rods, more fish, no walking.", "hole"],
	"Clear 3 sectors": ["Empty every hole in a sector to open the next. The lake map shows how far along you are.", ""],
	"Tithe the Eye": ["With empty hands, click the Eye to offer it coins. Every gift makes fish worth more.", "eye"],
	"Reach Eye stage 3": ["Feed it more. Belts, rigs and tithes all count.", "eye"],
}
const GENERIC_HINTS := {
	"autos": "Press 3 and click holes you drilled. More rods, no walking.",
	"sectors": "Empty every hole in a sector to open the next.",
	"rigs": "Press 7, press Q until it says Ice-Breaker, then click open ice.",
	"tithe": "With empty hands, click the Eye to offer it coins.",
	"eye_stage": "Feed the Eye. Rigs and tithes count too.",
	"eye_fed": "Feed the Eye. Belts do it for you.",
	"earned": "Keep the fish moving into the Eye.",
}

class ArrowCtl extends Control:
	var shown := false
	var pos := Vector2.ZERO
	var dir := Vector2.UP
	var label := ""
	func _draw() -> void:
		if not shown:
			return
		var n := dir.normalized()
		var p := Vector2(-n.y, n.x)
		var tip := pos + n * 17.0
		var a := pos - n * 10.0 + p * 14.0
		var b := pos - n * 10.0 - p * 14.0
		draw_colored_polygon(PackedVector2Array([tip + n * 2.0, a - p * 1.5 - n * 2.0, b + p * 1.5 - n * 2.0]), Color(0.1, 0.12, 0.2, 0.9))
		draw_colored_polygon(PackedVector2Array([tip, a, b]), Style.AMBER)
		var f := Style.font()
		var off := -n * 34.0
		draw_string_outline(f, pos + off + Vector2(-60, 5), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 15, 5, Color(0.05, 0.07, 0.14, 0.9))
		draw_string(f, pos + off + Vector2(-60, 5), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 15, Style.CREAM)

var game: Node
var ui_root: Control
var hidden_hud: Array = []
var want_intro := false
var intro_active := false
var tips_seen := {}
var bootstrap_tips := false

var strip: PanelContainer
var strip_tag: Label
var strip_title: Label
var strip_hint: Label
var tip_panel: PanelContainer
var tip_label: Label
var arrow: ArrowCtl
var bar_top: ColorRect
var bar_bot: ColorRect
var caption: Label
var skip_label: Label
var marker: Node3D
var marker_cone: MeshInstance3D
var marker_ring: MeshInstance3D
var marker_col: MeshInstance3D

var cur := {}
var last_id := ""
var stuck_t := 0.0
var tip_t := 0.0
var tip_scan_t := 0.0
var intro_t := 0.0
var intro_started := false
var cam_home := Vector3.ZERO
var cam_pitch := 0.0
var bars := 0.0
var ping_t := 0.0
var cine_t := 0.0
var strip_alpha := 0.0
var drill_spot := Vector3.ZERO

func build(ui: Control) -> void:
	ui_root = ui
	# the strip: top centre, "what now"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	strip_tag = _lbl(box, 13, Style.AMBER)
	strip_title = _lbl(box, 23, Style.CREAM)
	strip_hint = _lbl(box, 15, Style.MUTED)
	strip_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	strip_hint.custom_minimum_size = Vector2(460, 0)
	strip = PanelContainer.new()
	strip.add_theme_stylebox_override("panel", Style.box(Color(Style.INK.r, Style.INK.g, Style.INK.b, 0.86), 16, Color(Style.AMBER.r, Style.AMBER.g, Style.AMBER.b, 0.55), 2, Vector2(18, 10)))
	strip.add_child(box)
	strip.anchor_left = 0.5
	strip.anchor_right = 0.5
	strip.offset_top = 16.0
	strip.offset_bottom = 16.0
	strip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	strip.modulate.a = 0.0
	ui.add_child(strip)
	# one-time tips, just under it
	tip_label = Label.new()
	tip_label.add_theme_font_size_override("font_size", 16)
	tip_label.add_theme_color_override("font_color", Style.CREAM)
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.custom_minimum_size = Vector2(420, 0)
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_panel = PanelContainer.new()
	tip_panel.add_theme_stylebox_override("panel", Style.box(Color(Style.INK_SOFT.r, Style.INK_SOFT.g, Style.INK_SOFT.b, 0.88), 14, Color(Style.AQUA.r, Style.AQUA.g, Style.AQUA.b, 0.5), 1, Vector2(16, 8)))
	tip_panel.add_child(tip_label)
	tip_panel.anchor_left = 0.5
	tip_panel.anchor_right = 0.5
	tip_panel.offset_top = 128.0
	tip_panel.offset_bottom = 128.0
	tip_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tip_panel.modulate.a = 0.0
	ui.add_child(tip_panel)
	arrow = ArrowCtl.new()
	arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(arrow)
	# intro: letterbox bars, captions, skip hint
	bar_top = _bar(ui, true)
	bar_bot = _bar(ui, false)
	caption = Label.new()
	caption.set_anchors_preset(Control.PRESET_FULL_RECT)
	caption.anchor_top = 0.74
	caption.anchor_bottom = 0.92
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 30)
	caption.add_theme_constant_override("outline_size", 10)
	caption.add_theme_color_override("font_outline_color", Color(0.04, 0.06, 0.12, 0.95))
	caption.modulate.a = 0.0
	ui.add_child(caption)
	skip_label = Label.new()
	skip_label.text = "click to skip"
	skip_label.add_theme_font_size_override("font_size", 14)
	skip_label.add_theme_color_override("font_color", Style.MUTED)
	skip_label.anchor_left = 1.0
	skip_label.anchor_right = 1.0
	skip_label.anchor_top = 1.0
	skip_label.anchor_bottom = 1.0
	skip_label.offset_left = -130.0
	skip_label.offset_top = -34.0
	skip_label.modulate.a = 0.0
	ui.add_child(skip_label)
	_build_marker()
	var dir := (Vector3.ZERO - DRILL_SPOT_FROM).normalized()
	drill_spot = DRILL_SPOT_FROM + dir * 4.5

func _lbl(parent: Node, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

func _bar(ui: Control, top: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.02, 0.03, 0.07, 1.0)
	r.anchor_left = 0.0
	r.anchor_right = 1.0
	r.anchor_top = 0.0 if top else 1.0
	r.anchor_bottom = 0.0 if top else 1.0
	ui.add_child(r)
	return r

func _build_marker() -> void:
	marker = Node3D.new()
	game.add_child(marker)
	marker.visible = false
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(Style.AMBER.r, Style.AMBER.g, Style.AMBER.b, 0.92)
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.no_depth_test = true
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.42
	cone.height = 0.95
	cone.radial_segments = 4
	cone.rings = 1
	marker_cone = MeshInstance3D.new()
	marker_cone.mesh = cone
	marker_cone.material_override = glow
	marker_cone.rotation_degrees.x = 180.0
	marker_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_child(marker_cone)
	var ringm := StandardMaterial3D.new()
	ringm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ringm.albedo_color = Color(Style.AMBER.r, Style.AMBER.g, Style.AMBER.b, 0.8)
	ringm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var tor := TorusMesh.new()
	tor.inner_radius = 1.05
	tor.outer_radius = 1.25
	tor.rings = 24
	tor.ring_segments = 6
	marker_ring = MeshInstance3D.new()
	marker_ring.mesh = tor
	marker_ring.material_override = ringm
	marker_ring.scale = Vector3(1, 0.05, 1)
	marker_ring.position.y = 0.06
	marker_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_child(marker_ring)
	var colm := StandardMaterial3D.new()
	colm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	colm.albedo_color = Color(Style.AMBER.r, Style.AMBER.g, Style.AMBER.b, 0.11)
	colm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	colm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	colm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.1
	cyl.bottom_radius = 0.26
	cyl.height = 16.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	cyl.radial_segments = 10
	marker_col = MeshInstance3D.new()
	marker_col.mesh = cyl
	marker_col.material_override = colm
	marker_col.position.y = 8.0
	marker_col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_child(marker_col)

# ---------- state -> what to do now ----------
func is_early() -> bool:
	return GameState.level("bucket") == 0

func _step(id: String, title: String, hint: String, where = null) -> Dictionary:
	return {"id": id, "title": title, "hint": hint, "where": where}

func _player_pos() -> Vector3:
	return (game.get_node("Player") as Node3D).global_position

func _nearest_hole(state: String) -> Variant:
	var pp := _player_pos()
	var best: Variant = null
	var bd := 1e9
	for t in game.holes:
		if t.state != state:
			continue
		var d := Vector2(t.pos.x - pp.x, t.pos.z - pp.z).length()
		if d < bd:
			bd = d
			best = Vector3(t.pos.x, 0.0, t.pos.z)
	return best

func _resolve(where: String) -> Variant:
	match where:
		"eye":
			var p: Vector3 = game.scenery.eye_landing(_player_pos())
			return Vector3(p.x, 0.0, p.z)
		"hole":
			return _nearest_hole("hole")
		"auto":
			var a: Variant = _nearest_hole("auto")
			return a if a != null else _nearest_hole("hole")
		"hut":
			return Vector3(game.hut_pos.x, 0.0, game.hut_pos.z)
		"drill":
			return drill_spot
	if where.begins_with("stall:"):
		var spot: Array = game.SceneryScript.SHOP_SPOTS[where.substr(6)]
		var bp: Vector3 = game.SceneryScript.bearing_pos(spot[0], spot[1])
		return Vector3(bp.x, 0.0, bp.z)
	return null

func _hole_with_cast(c: int) -> bool:
	for t in game.holes:
		if t.state == "hole" and t.cast == c:
			return true
	return false

func current() -> Dictionary:
	var g := game
	var s: Dictionary = g.stats
	var carrying: bool = not g.carry.is_empty()
	if _hole_with_cast(2):
		return _step("bite", "It's biting!", "Click now!", _resolve("hole"))
	if carrying and g.free_space() <= 0 and not is_early():  # (early on, the carry steps say it better)
		return _step("full", "Your hands are full", "Carry it to the Eye: walk up to the glowing rim and click.", _resolve("eye"))
	if is_early():
		if s.holes == 0:
			if g.tool != 0:
				return _step("tool0", "Take out the drill", "Press 1 to equip it.", _resolve("drill"))
			return _step("drill", "Drill a hole in the ice", "Hold click on the marked spot until the ring fills.", _resolve("drill"))
		if carrying:
			if s.eye_fed == 0:
				return _step("carry0", "Take your fish to the Eye", "Walk to the glowing rim and click. It pays as it swallows.", _resolve("eye"))
			return _step("carry", "Feed it to the Eye", "Walk to the rim and click. Every fish is coins.", _resolve("eye"))
		if s.eye_fed >= 1 and GameState.currency >= GameState.cost("bucket", g.UPGRADES.bucket.base, g.UPGRADES.bucket.growth):
			return _step("bucket", "Buy a Bucket", "Walk to its stall and click the sign. You will carry more fish per trip.", _resolve("stall:bucket"))
		if _hole_with_cast(3):
			return _step("fight", "Hold on!", "It is fighting. It lands in your hands when it tires.", _resolve("hole"))
		if _hole_with_cast(1):
			return _step("wait", "Wait for a bite", "A dip in the float is only a nibble. Click when it splashes and the marker pops up.", _resolve("hole"))
		if _nearest_hole("hole") == null:
			return _step("drill2", "Drill another hole", "Press 1, then hold click on the ice.", _resolve("drill"))
		if g.tool != 1:
			return _step("tool1", "Take out the rod", "Press 2 to equip it.", _resolve("hole"))
		var more := "Click your hole to cast a line."
		if s.eye_fed >= 1:
			more = "Cast again. Save up for a Bucket at the stalls (%d coins)." % GameState.cost("bucket", g.UPGRADES.bucket.base, g.UPGRADES.bucket.growth)
		return _step("cast", "Cast a line", more, _resolve("hole"))
	if _hole_with_cast(3):
		return _step("fight", "Hold on!", "It is fighting. It lands in your hands when it tires.", _resolve("hole"))
	for pass_opt in [false, true]:
		for i in g.GOALS.size():
			var gl: Dictionary = g.GOALS[i]
			if g.goal_done[i] or bool(gl.get("opt", false)) != pass_opt:
				continue
			var h: Array = HINTS.get(gl.text, [GENERIC_HINTS.get(gl.stat, ""), ""])
			var cur_v := mini(int(g._stat(gl.stat)), int(gl.target))
			var title := String(gl.text)
			if int(gl.target) > 1:
				title += "   %d / %d" % [cur_v, int(gl.target)]
			return _step("goal%d" % i, title, String(h[0]), _resolve(String(h[1])) if h[1] != "" else null)
	return _step("done", "Wake the Eye", "Keep feeding it. When the lake is empty, press R to refreeze.", _resolve("eye"))

## Letterbox bars for a moment (the Eye waking).
func cinematic(seconds: float) -> void:
	cine_t = seconds

func ping() -> void:
	if intro_active or cur.is_empty():
		return
	ping_t = 1.6
	var line := "Olga: %s." % cur.title
	if cur.hint != "":
		line = "Olga: %s %s" % [cur.title + ".", cur.hint]
	game._say(line)
	game.sfx.play("tick", -2.0, 1.4)

func olga_line() -> String:
	var c := current()
	if c.hint == "":
		return "Olga: Next, dear: %s." % String(c.title).to_lower()
	return "Olga: %s. %s" % [c.title, c.hint]

# ---------- per frame ----------
func tick(delta: float, captured: bool) -> void:
	if want_intro and captured and not intro_started:
		_begin_intro()
	if intro_active:
		_tick_intro(delta)
	cine_t = maxf(0.0, cine_t - delta)
	bars = move_toward(bars, BAR_H if (intro_active or cine_t > 0.0) else 0.0, delta * 160.0)
	bar_top.offset_bottom = bars
	bar_bot.offset_top = -bars
	cur = current()
	if cur.id != last_id:
		if last_id != "" and not intro_active:
			game.sfx.play("tick", -8.0, 1.2)
			_pop()
		last_id = cur.id
		stuck_t = 0.0
	else:
		stuck_t += delta
	var show: bool = captured and not intro_active and not game.journal_panel.visible and not game.refreeze_panel.visible \
		and not game.ending_panel.visible and not game.riding and cine_t <= 0.0
	strip_alpha = move_toward(strip_alpha, 1.0 if show else 0.0, delta * 4.0)
	strip.modulate.a = strip_alpha
	strip_tag.text = "NEXT"
	var to: Variant = cur.where
	var title: String = cur.title
	if to != null and show:
		var pp := _player_pos()
		var d := Vector2(to.x - pp.x, to.z - pp.z).length()
		if d > 6.0:
			title += "   -   %d m" % int(d)
	strip_title.text = title
	var hint: String = cur.hint
	if stuck_t > STUCK_AFTER and not hint.is_empty() and cur.id != "bite":
		hint += "\nPress H and Olga points the way."
	strip_hint.text = hint
	strip_hint.visible = hint != ""
	_tick_marker(delta, to, show)
	_tick_tips(delta, captured and not intro_active and cine_t <= 0.0)

func _pop() -> void:
	strip.pivot_offset = strip.size * 0.5
	strip.scale = Vector2.ONE * 1.07
	var tw := create_tween()
	tw.tween_property(strip, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _tick_marker(delta: float, to: Variant, show: bool) -> void:
	ping_t = maxf(0.0, ping_t - delta)
	if to == null or not show:
		marker.visible = false
		arrow.shown = false
		arrow.queue_redraw()
		return
	var pp := _player_pos()
	var dist := Vector2(to.x - pp.x, to.z - pp.z).length()
	marker.visible = dist > 2.5
	marker.global_position = Vector3(to.x, 0.0, to.z)
	var k := clampf(dist / 16.0, 0.6, 5.0)
	if ping_t > 0.0:
		k *= 1.0 + 0.35 * absf(sin(ping_t * 6.0))
	marker.scale = Vector3.ONE * k
	var tm := Time.get_ticks_msec() * 0.001
	marker_cone.position.y = 2.6 + sin(tm * 3.0) * 0.28
	marker_cone.rotation.y = tm * 1.4
	marker_ring.scale = Vector3(1.0 + 0.06 * sin(tm * 2.0), 0.05, 1.0 + 0.06 * sin(tm * 2.0))
	# edge arrow when the target is off screen
	var cam: Camera3D = game.cam
	var vp: Vector2 = game.get_viewport().get_visible_rect().size
	var p3 := Vector3(to.x, 1.5, to.z)
	var behind := cam.is_position_behind(p3)
	var sp := cam.unproject_position(p3)
	var margin := 78.0
	var on_screen := not behind and sp.x > margin and sp.x < vp.x - margin and sp.y > margin and sp.y < vp.y - margin
	if on_screen or dist < 4.0:
		arrow.shown = false
	else:
		var center := vp * 0.5
		var d := sp - center
		if behind:
			d = -d
		if d.length() < 1.0:
			d = Vector2.UP
		var half := vp * 0.5 - Vector2(margin, margin)
		var kk := minf(half.x / maxf(absf(d.x), 0.001), half.y / maxf(absf(d.y), 0.001))
		arrow.pos = center + d * kk
		arrow.dir = d.normalized()
		arrow.label = "%d m" % int(dist)
		arrow.shown = true
	arrow.queue_redraw()

# ---------- tips ----------
func _candidate_tips() -> Array:
	var out := []
	for i in range(2, game.TOOLS.size()):
		if game._tool_unlocked(i):
			out.append(["tool%d" % i, "New tool: %s. Press %d to use it." % [game.TOOLS[i], i + 1]])
	for id in game.UPGRADES:
		if id == "bucket" or not game.unlocked.get(id, false):
			continue
		var u: Dictionary = game.UPGRADES[id]
		if GameState.level(id) == 0 and GameState.currency >= GameState.cost(id, u.base, u.growth):
			out.append(["aff:" + id, "You can afford %s (%d coins): %s. Find its stall and click the sign. [M]" % [u.name, GameState.cost(id, u.base, u.growth), u.desc]])
	return out

func _tick_tips(delta: float, active: bool) -> void:
	tip_t = maxf(0.0, tip_t - delta)
	tip_scan_t -= delta
	if tip_scan_t > 0.0 or not active:
		return
	tip_scan_t = 0.5
	var cands := _candidate_tips()
	if bootstrap_tips:  # an old save: do not announce everything it already has
		for c in cands:
			tips_seen[c[0]] = true
		bootstrap_tips = false
		return
	if tip_t > 0.0:
		return
	for c in cands:
		if not tips_seen.has(c[0]):
			tips_seen[c[0]] = true
			_show_tip(String(c[1]).replace(" [M]", ""))
			return

func _show_tip(text: String) -> void:
	tip_label.text = text
	tip_t = 7.5
	tip_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(tip_panel, "modulate:a", 1.0, 0.3)
	tw.tween_interval(6.6)
	tw.tween_property(tip_panel, "modulate:a", 0.0, 0.6)
	game.sfx.play("coin", -10.0, 1.3)

# ---------- intro ----------
func _begin_intro() -> void:
	intro_started = true
	intro_active = true
	intro_t = 0.0
	var cam: Camera3D = game.cam
	cam_home = cam.position
	cam_pitch = cam.rotation.x
	game.get_node("Player").set_process_unhandled_input(false)
	game.view.visible = false
	game.tool_view.visible = false
	var own := [strip, tip_panel, arrow, bar_top, bar_bot, caption, skip_label]
	hidden_hud.clear()
	for c in ui_root.get_children():  # a clean frame for the flyover
		if c is Control and not own.has(c) and c.visible:
			c.visible = false
			hidden_hud.append(c)
	game.prompt_label.text = ""
	game.msg_label.text = ""
	_apply_cam(0.0)

func _apply_cam(k: float) -> void:
	var cam: Camera3D = game.cam
	var e := k * k * (3.0 - 2.0 * k)
	cam.position = cam_home + Vector3(0.0, 25.0 * (1.0 - e), 9.0 * (1.0 - e))
	cam.rotation.x = lerpf(deg_to_rad(-43.0), cam_pitch, e)
	cam.rotation.y = 0.5 * (1.0 - e)

func _tick_intro(delta: float) -> void:
	var before := intro_t
	intro_t += delta
	_apply_cam(clampf(intro_t / INTRO_FLY, 0.0, 1.0))
	skip_label.modulate.a = lerpf(skip_label.modulate.a, 0.7 if intro_t > 1.2 else 0.0, minf(1.0, delta * 4.0))
	var line_a := 0.0
	for ln in INTRO:
		var t0: float = ln[0]
		var t1: float = ln[1]
		if intro_t >= t0 and intro_t <= t1:
			if caption.text != ln[2]:
				caption.text = ln[2]
				caption.add_theme_color_override("font_color", Style.AMBER if ln[3] else Style.CREAM)
			line_a = clampf(minf((intro_t - t0) / 0.6, (t1 - intro_t) / 0.6), 0.0, 1.0)
	caption.modulate.a = line_a
	if before < 3.4 and intro_t >= 3.4 and is_instance_valid(game.scenery):
		game.scenery.pulse_eye()
		game.sfx.play("rare", -12.0, 0.6)
	if intro_t >= INTRO_LEN:
		skip_intro()

func skip_intro() -> void:
	if not intro_active:
		return
	intro_active = false
	want_intro = false
	var cam: Camera3D = game.cam
	cam.position = cam_home
	cam.rotation.x = cam_pitch
	cam.rotation.y = 0.0
	game.get_node("Player").set_process_unhandled_input(true)
	game.view.visible = true
	game.tool_view.visible = true
	for c in hidden_hud:
		if is_instance_valid(c):
			c.visible = true
	hidden_hud.clear()
	caption.modulate.a = 0.0
	skip_label.modulate.a = 0.0
	game._say("Olga: Drill a hole, dear. Catch a fish. Carry it to the Eye.")

# ---------- save ----------
func to_dict() -> Dictionary:
	return tips_seen

func from_dict(d: Variant) -> void:
	if d is Dictionary:
		tips_seen = d
	else:
		bootstrap_tips = true
