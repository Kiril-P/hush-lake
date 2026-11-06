class_name MenuUI
extends Control
## The title / pause menu: one card over a dimmed, softly vignetted game, with pages (main, settings, controls, how to play,
## lake stats, confirm). Built entirely from the shared Style so it looks like the rest of the game, with hover and press feel
## (a small lift, a tick sound), a fade-and-rise when it opens, a live-updating settings screen and a hint line for each setting.

signal resume_requested
signal new_run_requested
signal quit_requested

var game: Node
var page := "main"
var tab := 0
var card: PanelContainer
var box: VBoxContainer
var dim: ColorRect
var hint_label: Label
var _slide := 0.0
var from_title := false      # opened from the title screen: Back and Esc return to it instead of resuming play

const CONTROLS := [
	["Moving", [["W A S D", "walk"], ["V", "ride the snowmobile (once you own one)"], ["Mouse", "look"], ["Esc", "pause / menu"]]],
	["Your hands (three slots)", [["1  2  3 / wheel", "pick the slot in your hand: a tool, a fish or a bucket"], ["Q", "put what you hold down (a tool or bucket stays where it lands)"], ["E", "pick up what you look at, or sweep the fish at your feet into a bucket"], ["Z", "take a fish out of the bucket in your hand"]]],
	["Tools", [["Drill", "hold click on ice to drill a hole"], ["Rod", "click a hole to cast, click again when it bites"], ["Builder's Kit", "from the tool rack by Olga's hut: B switches what it builds"]]],
	["Fish and buckets", [["Click a fish", "grab it (into a slot, or the bucket you hold)"], ["Click empty ice", "drop a fish, or set a bucket down where you aim"], ["Hold right mouse / F", "charge a throw (or a kick), let go to release; a kick tips a bucket over"], ["Click the Eye / a depot / a smoker", "feed it everything you carry"], ["Click a bucket on the ice", "put a fish in, or take one out"]]],
	["Everything else", [["H", "ask Olga what to do next"], ["Tab", "field journal"], ["P", "photo mode: hides the interface, click takes a picture"], ["L", "the ledger: lifetime goals that pay pearls"], ["C (hold)", "peer into a hole: see the fish swimming under it"], ["U", "upgrade the Auto-Rod or Ice-Breaker you look at (tier 2 and 3)"], ["R", "refreeze the lake (after clearing sectors)"], ["M", "mute"]]],
]

const HOWTO := [
	["The Eye", "Under the ice at the centre of Hush Lake lies the Eye. It is always hungry and it pays in coins, and as it eats it wakes."],
	["Fish", "Hold the drill (slot 1) on the ice to dig a hole, take the rod (slot 2), cast and click when the float splashes. Your catch drops onto the ice."],
	["Your hands", "You carry three things: tools, fish and buckets, one in your hand at a time. A bucket holds many fish: click fish into it, press E to sweep them up, or throw them in. Buy more buckets and set them around. Q puts what you hold down."],
	["Getting it to the Eye", "Click a fish to grab it, hold right mouse and let go to throw it at the Eye (look a little up for a lob). Or walk into it, or kick it. The Eye pulls close fish in."],
	["Machines", "Auto-rods fish for you, belts carry the catch to the Eye, canneries and sorters make it worth more, depots and smokers take thrown fish. A Bait Grinder turns a thrown fish into bait (faster bites); a Wind Fan blows loose fish toward the Eye."],
	["Sectors", "The lake is nineteen sectors. Frosted ones are locked: empty a neighbouring sector to open them."],
	["Stuck?", "Press H and Olga points the way. The NEXT strip at the top always shows the one thing to do."],
]

func build(g: Node) -> void:
	game = g
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	dim = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.12, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", Style.box(Color(Style.INK.r, Style.INK.g, Style.INK.b, 0.94), 20, Color(1.0, 0.78, 0.35, 0.35), 2, Vector2(30, 24)))
	card.custom_minimum_size = Vector2(560, 500)   # a fixed height: switching pages and tabs must not make the card jump
	cc.add_child(card)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	visible = false

func set_open(on: bool) -> void:
	if on == visible:
		return
	visible = on
	if on:
		from_title = false
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # (a hidden control is not laid out: fit it to the screen when it opens)
		page = "main"
		_rebuild()
		_open_t = 0.0   # fades in from _process (a tween would be frozen by the game's pause)
		modulate.a = 0.0

var _open_t := 1.0

func _process(delta: float) -> void:
	if not visible or _open_t >= 1.0:
		return
	_open_t = minf(_open_t + delta / 0.22, 1.0)
	var k := 1.0 - pow(1.0 - _open_t, 3.0)
	modulate.a = minf(_open_t * 1.5, 1.0)
	card.position.y = (1.0 - k) * 18.0

## Opens one page straight away (the title screen's Settings and Controls).
func open_page(p: String) -> void:
	from_title = true
	visible = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page = p
	_rebuild()
	_open_t = 0.0
	modulate.a = 0.0

func close_to_title() -> void:
	from_title = false
	visible = false
	if game.sfx:
		game.sfx.play("tick", -8.0, 1.1)

func go(p: String) -> void:
	page = p
	_rebuild()
	if game.sfx:
		game.sfx.play("tick", -8.0, 1.1)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if from_title:
			close_to_title()
		elif page != "main":
			go("main")
		else:
			resume_requested.emit()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- small pieces

func _clear() -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()

func _label(text: String, size := 18, color := Style.CREAM, center := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)
	return l

func _btn(text: String, cb: Callable, kind := "normal", parent: Node = null) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_size_override("font_size", 19)
	var base := Style.box(Color(Style.INK_SOFT.r, Style.INK_SOFT.g, Style.INK_SOFT.b, 0.9), 12, Color(1, 1, 1, 0.1), 1, Vector2(18, 6))
	var hover := Style.box(Color(0.2, 0.17, 0.2, 0.95), 12, Style.AMBER, 2, Vector2(18, 6))
	if kind == "primary":
		base = Style.box(Color(0.95, 0.72, 0.3, 1.0), 12, Color(1, 1, 1, 0.3), 1, Vector2(18, 6))
		hover = Style.box(Color(1.0, 0.82, 0.45, 1.0), 12, Color(1, 1, 1, 0.6), 2, Vector2(18, 6))
		b.add_theme_color_override("font_color", Color(0.12, 0.09, 0.05))
		b.add_theme_color_override("font_hover_color", Color(0.12, 0.09, 0.05))
	elif kind == "danger":
		hover = Style.box(Color(0.3, 0.14, 0.16, 0.95), 12, Style.ROSE, 2, Vector2(18, 6))
		b.add_theme_color_override("font_hover_color", Style.ROSE)
	b.add_theme_stylebox_override("normal", base)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(func():
		if game.sfx:
			game.sfx.play("buy" if kind == "primary" else "tick", -6.0, 1.0 if kind == "primary" else 1.3)
		cb.call())
	b.mouse_entered.connect(func():
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(1.02, 1.02), 0.08)
		if game.sfx:
			game.sfx.play("tick", -16.0, 1.6))
	b.mouse_exited.connect(func():
		b.pivot_offset = b.size * 0.5
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.1))
	(parent if parent != null else box).add_child(b)
	return b

func _title(text: String, sub := "") -> void:
	var t := _label(text, 46, Style.AMBER, true)
	t.add_theme_constant_override("outline_size", 6)
	if sub != "":
		_label(sub, 16, Style.MUTED, true)

func _sep() -> void:
	var s := HSeparator.new()
	s.modulate = Color(1, 1, 1, 0.2)
	box.add_child(s)

func _back_button() -> void:
	_sep()
	_btn("Back", func(): close_to_title() if from_title else go("main"))

# ---------------------------------------------------------------- pages

func _rebuild() -> void:
	_clear()
	match page:
		"settings": _page_settings()
		"controls": _page_controls()
		"howto": _page_howto()
		"stats": _page_stats()
		"confirm_new": _page_confirm("Start over?", "This erases the current run, and the pearls and perks you earned. Your settings stay.", "Erase and start over", func(): new_run_requested.emit())
		"confirm_quit": _page_confirm("Quit the game?", "Your run is saved.", "Quit", func(): quit_requested.emit())
		_: _page_main()

func _page_main() -> void:
	var playing: bool = game.ever_captured
	_title("HUSH LAKE", "PAUSED" if playing else "a cozy ice-fishing incremental")
	var s: Dictionary = game.stats
	if int(s.get("eye_fed", 0)) > 0 or int(s.get("holes", 0)) > 0:
		var line := "%s #%d   -   %s fish fed   -   Eye stage %d of %d   -   %s played" % [game.model.mod_info().name, int(GameState.meta.get("lakes", 0)) + 1,
			game._fmt_num(float(s.eye_fed)), game.eye_stage(), game.EYE_STAGES.size(), game._clock(game.play_time)]
		var l := _label(line, 14, Style.MUTED, true)
		l.custom_minimum_size = Vector2(500, 0)
	_sep()
	_btn("Continue" if playing or int(s.get("holes", 0)) > 0 else "Play", func(): resume_requested.emit(), "primary")
	_btn("Settings", func(): go("settings"))
	_btn("Controls", func(): go("controls"))
	_btn("How to play", func(): go("howto"))
	_btn("Lake stats", func(): go("stats"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var b1 := _btn("Start over", func(): go("confirm_new"), "danger", row)
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b2 := _btn("Quit", func(): go("confirm_quit"), "normal", row)
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label("Esc closes this menu", 13, Style.MUTED, true)

func _page_confirm(title: String, body: String, yes: String, action: Callable) -> void:
	_label(title, 30, Style.AMBER, true)
	var l := _label(body, 17, Style.CREAM, true)
	l.custom_minimum_size = Vector2(480, 0)
	_sep()
	_btn(yes, action, "danger")
	_btn("Cancel", func(): go("main"))

func _page_controls() -> void:
	_label("CONTROLS", 30, Style.AMBER, true)
	for sec in CONTROLS:
		_label(sec[0], 15, Style.MUTED)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 22)
		grid.add_theme_constant_override("v_separation", 2)
		box.add_child(grid)
		for r in sec[1]:
			var k := Label.new()
			k.text = r[0]
			k.add_theme_font_size_override("font_size", 16)
			k.add_theme_color_override("font_color", Style.AMBER)
			k.custom_minimum_size = Vector2(190, 0)
			grid.add_child(k)
			var d := Label.new()
			d.text = r[1]
			d.add_theme_font_size_override("font_size", 16)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.custom_minimum_size = Vector2(330, 0)
			grid.add_child(d)
	_back_button()

func _page_howto() -> void:
	_label("HOW TO PLAY", 30, Style.AMBER, true)
	for r in HOWTO:
		_label(r[0], 16, Style.AMBER)
		var l := _label(r[1], 16, Style.CREAM)
		l.custom_minimum_size = Vector2(500, 0)
	_back_button()

func _page_stats() -> void:
	_label("LAKE STATS", 30, Style.AMBER, true)
	var s: Dictionary = game.stats
	var rows := [["Time played", game._clock(game.play_time)], ["Fish caught", game._fmt_num(float(s.caught))], ["Fed to the Eye", game._fmt_num(float(s.eye_fed))],
		["Coins earned", game._fmt_num(float(s.earned))], ["Holes drilled", str(int(s.holes))], ["Sectors cleared", "%d / %d" % [game.model.cleared_count(), game.model.sectors.size()]],
		["Auto-rods built", str(int(s.autos))], ["Ice-breakers", str(int(s.rigs))], ["Tithes paid", str(int(s.tithe))],
		["Species found", "%d / %d" % [game.journal.size(), game.SPECIES.size()]], ["Pearls", str(int(GameState.meta.get("pearls", 0)))], ["Lakes finished", str(int(GameState.meta.get("lakes", 0)))]]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 3)
	box.add_child(grid)
	for r in rows:
		var a := Label.new()
		a.text = r[0]
		a.add_theme_font_size_override("font_size", 17)
		a.add_theme_color_override("font_color", Style.MUTED)
		a.custom_minimum_size = Vector2(230, 0)
		grid.add_child(a)
		var b := Label.new()
		b.text = r[1]
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_color_override("font_color", Style.CREAM)
		grid.add_child(b)
	_back_button()

# ---------------------------------------------------------------- settings

func _page_settings() -> void:
	_label("SETTINGS", 30, Style.AMBER, true)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	box.add_child(tabs)
	for i in GameSettings.TABS.size():
		var b := _btn(GameSettings.TABS[i], func():
			tab = i
			_rebuild(), "primary" if i == tab else "normal", tabs)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 36)
	_sep()
	for key in GameSettings.keys_for_tab(tab):
		_setting_row(key)
	hint_label = _label(" ", 14, Style.MUTED)
	hint_label.custom_minimum_size = Vector2(500, 36)
	_sep()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var back := _btn("Back", func(): go("main"), "normal", row)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var reset := _btn("Reset all to default", func():
		GameSettings.reset_all()
		game._apply_settings()
		game.save_settings()
		_rebuild(), "danger", row)
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _setting_row(key: String) -> void:
	var d: Dictionary = GameSettings.DEFS[key]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var name_l := Label.new()
	name_l.text = d.label
	name_l.add_theme_font_size_override("font_size", 17)
	name_l.custom_minimum_size = Vector2(230, 0)
	row.add_child(name_l)
	var show_hint := func():
		if hint_label:
			hint_label.text = String(d.get("hint", "")) if String(d.get("hint", "")) != "" else " "
	var val := GameSettings.get_value(key)
	var value_l: Label = null
	var reset_b: Button = null
	var refresh_reset := func():
		if reset_b:
			reset_b.visible = not GameSettings.is_default(key)
	if String(d.kind) == "slider":
		var sl := HSlider.new()
		sl.min_value = float(d.min)
		sl.max_value = float(d.max)
		sl.step = float(d.get("step", (float(d.max) - float(d.min)) / 100.0))
		sl.value = val
		sl.custom_minimum_size = Vector2(170, 24)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sl)
		value_l = Label.new()
		value_l.text = GameSettings.format(key, val)
		value_l.add_theme_font_size_override("font_size", 16)
		value_l.add_theme_color_override("font_color", Style.AMBER)
		value_l.custom_minimum_size = Vector2(52, 0)
		row.add_child(value_l)
		sl.value_changed.connect(func(v: float):
			GameSettings.set_value(key, v)
			value_l.text = GameSettings.format(key, v)
			game._apply_settings()
			refresh_reset.call())
		sl.drag_ended.connect(func(_changed: bool):
			game.save_settings()
			if key == "sfx" or key == "vol":
				game.sfx.play("coin", -4.0, 1.0))
		sl.mouse_entered.connect(show_hint)
	else:
		var cb := CheckButton.new()
		cb.button_pressed = val > 0.5
		cb.focus_mode = Control.FOCUS_NONE
		row.add_child(cb)
		value_l = Label.new()
		value_l.text = "On" if val > 0.5 else "Off"
		value_l.add_theme_font_size_override("font_size", 16)
		value_l.add_theme_color_override("font_color", Style.AMBER if val > 0.5 else Style.MUTED)
		value_l.custom_minimum_size = Vector2(52, 0)
		row.add_child(value_l)
		cb.toggled.connect(func(on: bool):
			GameSettings.set_value(key, 1.0 if on else 0.0)
			value_l.text = "On" if on else "Off"
			value_l.add_theme_color_override("font_color", Style.AMBER if on else Style.MUTED)
			game._apply_settings()
			game.save_settings()
			game.sfx.play("tick", -6.0, 1.4 if on else 0.9)
			refresh_reset.call())
		cb.mouse_entered.connect(show_hint)
	reset_b = Button.new()
	reset_b.text = "reset"
	reset_b.flat = true
	reset_b.focus_mode = Control.FOCUS_NONE
	reset_b.add_theme_font_size_override("font_size", 13)
	reset_b.add_theme_color_override("font_color", Style.MUTED)
	reset_b.add_theme_color_override("font_hover_color", Style.AMBER)
	reset_b.visible = not GameSettings.is_default(key)
	reset_b.pressed.connect(func():
		GameSettings.set_value(key, GameSettings.def(key))
		game._apply_settings()
		game.save_settings()
		_rebuild())
	row.add_child(reset_b)
	name_l.mouse_filter = Control.MOUSE_FILTER_PASS
	name_l.mouse_entered.connect(show_hint)
