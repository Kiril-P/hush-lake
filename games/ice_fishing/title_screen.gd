class_name TitleScreen
extends Control
## The title: Hush Lake at dusk behind it, frost creeping in from the edges of the glass, the title crystallising out of the frost,
## an amber line drawn under "Feed the Eye", a few quiet text buttons. The camera drift and the Eye's hum belong to the game and Opening.

signal play_pressed
signal settings_pressed
signal controls_pressed
signal quit_pressed
signal left            # the fade to black is complete: the opening may begin

const FROST_SHADER := """
shader_type canvas_item;
uniform float grow = 0.0;
uniform float aspect = 1.78;
uniform float time_s = 0.0;
uniform vec4 frost_col : source_color = vec4(0.78, 0.9, 1.0, 1.0);
float hash21(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
vec2 hash22(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973)); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.xx + p3.yz) * p3.zy); }
float vnoise(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y); }
float fbm(vec2 p){ float v = 0.0; float a = 0.5; for (int i = 0; i < 5; i++){ v += a * vnoise(p); p *= 2.03; a *= 0.5; } return v; }
vec3 voro(vec2 x){
	vec2 n = floor(x); vec2 f = fract(x); vec2 mg = vec2(0.0); vec2 mr = vec2(0.0); float md = 8.0;
	for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++){
		vec2 g = vec2(float(i), float(j)); vec2 o = hash22(n + g); vec2 r = g + o - f; float d = dot(r, r);
		if (d < md){ md = d; mr = r; mg = g; } }
	md = 8.0;
	for (int j = -2; j <= 2; j++) for (int i = -2; i <= 2; i++){
		vec2 g = mg + vec2(float(i), float(j)); vec2 o = hash22(n + g); vec2 r = g + o - f;
		if (dot(mr - r, mr - r) > 0.00001) md = min(md, dot(0.5 * (mr + r), normalize(r - mr))); }
	return vec3(md, mr);
}
void fragment(){
	vec2 uv = UV;
	vec2 p = vec2(uv.x * aspect, uv.y);
	float ex = min(uv.x, 1.0 - uv.x) * aspect;
	float ey = min(uv.y, 1.0 - uv.y);
	float edge = min(ex * 0.8, ey);
	float n = fbm(p * 3.0 + 7.0);
	float reach = grow * 0.2;
	float cover = 1.0 - smoothstep(reach * 0.15, reach, edge + (n - 0.5) * 0.22 * grow);
	// fine crystal veins, strongest right at the glass edge and thinning toward the clear middle
	vec3 v = voro(p * 22.0 + n * 2.0);
	float vein = (1.0 - smoothstep(0.0, 0.03, v.x)) * cover;
	float shade = 0.7 + 0.3 * vnoise(p * 40.0 + v.yz * 5.0);
	float haze = fbm(p * 6.0 + 3.0);
	float sp = hash21(floor(p * 170.0));
	float spark = pow(sp, 30.0) * (0.5 + 0.5 * sin(time_s * 3.0 + sp * 40.0));
	vec3 col = frost_col.rgb * shade + vec3(vein * 0.35) + vec3(spark * 3.0 * cover);
	float a = cover * (0.12 + 0.3 * haze + 0.3 * vein);
	COLOR = vec4(col, clamp(a, 0.0, 0.85));
}
"""

const TEXT_SHADER := """
shader_type canvas_item;
uniform float reveal = 0.0;
uniform vec2 center = vec2(960.0, 330.0);
uniform float radius = 760.0;
uniform float time_s = 0.0;
float hash21(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y); }
float fbm(vec2 p){ float v = 0.0; float a = 0.5; for (int i = 0; i < 5; i++){ v += a * vnoise(p); p *= 2.03; a *= 0.5; } return v; }
void fragment(){
	vec2 sp = FRAGCOORD.xy;
	float d = distance(sp * vec2(1.0, 1.6), center * vec2(1.0, 1.6)) / radius;
	float n = fbm(sp * 0.02);
	float m = d * 0.8 + n * 0.5;
	float front = reveal * 1.45 - m;
	float vis = smoothstep(0.0, 0.2, front);
	float band = clamp(1.0 - abs(front - 0.1) / 0.1, 0.0, 1.0);
	vec3 base = mix(vec3(0.84, 0.97, 1.0), vec3(0.45, 0.82, 0.95), clamp(n * 1.3 + (sp.y - center.y) * 0.0015, 0.0, 1.0));
	float shimmer = 0.5 + 0.5 * sin(sp.x * 0.012 - time_s * 0.8 + n * 6.0);
	float tw = pow(hash21(floor(sp * 0.5)), 30.0) * 5.0 * (0.5 + 0.5 * sin(time_s * 4.0 + sp.x));
	vec3 col = base * (0.88 + 0.18 * shimmer) + vec3(band * 0.9) + vec3(tw);
	COLOR = vec4(col, COLOR.a * vis);
}
"""

var game: Node
var frost: ColorRect
var title_label: Label
var sub_label: Label
var rule: ColorRect
var button_box: VBoxContainer
var cover: ColorRect         # the black fade when leaving
var t := 0.0
var leaving := false
var leave_t := 0.0
var continuing := false
var ready_t := 0.0           # seconds until the buttons are clickable
var _frost_mat: ShaderMaterial
var _heard := {}             # one-shot sounds already played
var _text_mat: ShaderMaterial

func build(g: Node, has_save: bool) -> void:
	game = g
	continuing = has_save
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # a click on the glass must not start play through the world behind it
	# frost on the glass
	frost = ColorRect.new()
	frost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frost_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = FROST_SHADER
	_frost_mat.shader = sh
	frost.material = _frost_mat
	add_child(frost)
	# a soft dark wash behind the text so it reads on the bright ice
	var wash := ColorRect.new()
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.color = Color(0.02, 0.05, 0.13, 0.0)
	wash.name = "Wash"
	add_child(wash)
	# the title
	title_label = Label.new()
	title_label.text = "HUSH LAKE"
	title_label.add_theme_font_override("font", Style.font())
	title_label.add_theme_font_size_override("font_size", 190)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_color_override("font_outline_color", Color(0.04, 0.12, 0.25, 0.9))
	title_label.add_theme_constant_override("outline_size", 14)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.anchor_left = 0.0
	title_label.anchor_right = 1.0
	title_label.anchor_top = 0.07
	title_label.anchor_bottom = 0.33
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_mat = ShaderMaterial.new()
	var tsh := Shader.new()
	tsh.code = TEXT_SHADER
	_text_mat.shader = tsh
	title_label.material = _text_mat
	add_child(title_label)
	rule = ColorRect.new()
	rule.color = Color(1.0, 0.78, 0.35, 0.0)
	rule.anchor_left = 0.5
	rule.anchor_right = 0.5
	rule.anchor_top = 0.345
	rule.anchor_bottom = 0.345
	rule.offset_top = 0.0
	rule.offset_bottom = 3.0
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)
	sub_label = Label.new()
	sub_label.text = "F E E D    T H E    E Y E"
	sub_label.add_theme_font_override("font", Style.font())
	sub_label.add_theme_font_size_override("font_size", 30)
	sub_label.add_theme_color_override("font_color", Style.AMBER)
	sub_label.add_theme_color_override("font_outline_color", Color(0.04, 0.1, 0.22, 0.9))
	sub_label.add_theme_constant_override("outline_size", 8)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.anchor_left = 0.0
	sub_label.anchor_right = 1.0
	sub_label.anchor_top = 0.36
	sub_label.anchor_bottom = 0.42
	sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_label.modulate.a = 0.0
	add_child(sub_label)
	# quiet text buttons
	button_box = VBoxContainer.new()
	button_box.add_theme_constant_override("separation", 6)
	button_box.anchor_left = 0.5
	button_box.anchor_right = 0.5
	button_box.anchor_top = 0.62
	button_box.anchor_bottom = 0.62
	button_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	button_box.modulate.a = 0.0
	add_child(button_box)
	_button("Continue" if has_save else "Play", 34, func(): _on_play(), true)
	_button("Settings", 22, func(): settings_pressed.emit())
	_button("Controls", 22, func(): controls_pressed.emit())
	_button("Quit", 22, func(): quit_pressed.emit())
	var foot := Label.new()
	foot.text = "Esc pauses in game  -  a cozy ice-fishing incremental"
	foot.add_theme_font_size_override("font_size", 14)
	foot.add_theme_color_override("font_color", Color(0.8, 0.88, 1.0, 0.5))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.anchor_left = 0.0
	foot.anchor_right = 1.0
	foot.anchor_top = 0.95
	foot.anchor_bottom = 0.98
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(foot)
	cover = ColorRect.new()
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.color = Color(0.01, 0.02, 0.05, 1.0)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cover)
	_apply(0.0)

func _button(text: String, size: int, cb: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Style.font())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Style.AMBER if primary else Color(0.88, 0.94, 1.0, 0.9))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.6))
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", Color(0.03, 0.08, 0.18, 0.9))
	b.add_theme_constant_override("outline_size", 8)
	b.custom_minimum_size = Vector2(280, size + 18)
	var empty := StyleBoxEmpty.new()
	for sn in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(sn, empty)
	b.pressed.connect(func():
		if ready_t > 0.0 or leaving:
			return
		if game.sfx:
			game.sfx.play("buy" if primary else "tick", -8.0, 1.0 if primary else 1.3)
		cb.call())
	b.mouse_entered.connect(func():
		if game.sfx and ready_t <= 0.0:
			game.sfx.play("tick", -18.0, 1.7))
	button_box.add_child(b)
	return b

func _on_play() -> void:
	if leaving:
		return
	leaving = true
	leave_t = 0.0
	play_pressed.emit()

## Everything on screen as a function of time since the title opened.
func _apply(time_s: float) -> void:
	var sm := func(a: float, b: float) -> float: return CameraDirector.smooth(CameraDirector.span(time_s, a, b))
	_frost_mat.set_shader_parameter("grow", sm.call(0.8, 5.2))
	_frost_mat.set_shader_parameter("time_s", time_s)
	_frost_mat.set_shader_parameter("aspect", maxf(size.x / maxf(size.y, 1.0), 1.0))
	var vp := get_viewport_rect().size
	_text_mat.set_shader_parameter("reveal", sm.call(2.6, 6.4))
	_text_mat.set_shader_parameter("time_s", time_s)
	_text_mat.set_shader_parameter("center", Vector2(vp.x * 0.5, vp.y * 0.2))
	_text_mat.set_shader_parameter("radius", maxf(vp.x * 0.5, 1.0))
	var ln: float = sm.call(5.2, 6.8)
	rule.offset_left = -330.0 * ln
	rule.offset_right = 330.0 * ln
	rule.color.a = 0.9 * ln
	sub_label.modulate.a = sm.call(5.8, 7.2)
	button_box.modulate.a = sm.call(6.6, 8.0)
	(get_node("Wash") as ColorRect).color.a = 0.28 * sm.call(1.0, 4.0)
	if not leaving:
		cover.color.a = 1.0 - sm.call(0.0, 2.2)
	ready_t = maxf(0.0, 7.2 - time_s)

## Enter or Space also starts play once the buttons are up.
func _unhandled_input(event: InputEvent) -> void:
	if visible and not leaving and ready_t <= 0.0 and event is InputEventKey and event.pressed and not event.echo \
			and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and (game.menu == null or not game.menu.visible):
		get_viewport().set_input_as_handled()
		if game.sfx:
			game.sfx.play("buy", -8.0)
		_on_play()

func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	_apply(t)
	if game and game.sfx and not leaving:   # the title announces itself softly: a swell as the frost starts, a few bells as the name is done
		if t > 1.2 and not _heard.has("swell"):
			_heard["swell"] = true
			game.sfx.play("swell", -18.0, 0.7)
		if t > 6.0 and not _heard.has("bells"):
			_heard["bells"] = true
			game.sfx.play("bells", -20.0, 0.9)
	if leaving:
		leave_t += delta
		cover.color.a = CameraDirector.smooth(CameraDirector.span(leave_t, 0.0, 1.1))
		button_box.modulate.a = maxf(0.0, button_box.modulate.a - delta * 3.0)
		title_label.modulate.a = maxf(0.0, 1.0 - leave_t * 1.2)
		if leave_t >= 1.15:
			leaving = false
			left.emit()
