class_name LettersPanel
extends PanelContainer
## Olga's letters on a sheet of paper: the text writes itself in, left/right turn the pages, E or Esc closes (the first press
## finishes the writing). Keyboard only, so it works with the mouse still captured. See story.gd for the letters.

signal read_letter(id: String)

var ids: Array = []
var idx := 0
var unread_ids: Array = []
var title_l: Label
var body_l: RichTextLabel
var count_l: Label
var foot_l: Label
var tw: Tween

func _init() -> void:
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color(0.93, 0.88, 0.77)
	paper.border_color = Color(0.62, 0.5, 0.36)
	paper.set_border_width_all(3)
	paper.set_corner_radius_all(4)
	paper.shadow_color = Color(0, 0, 0, 0.45)
	paper.shadow_size = 18
	paper.content_margin_left = 44
	paper.content_margin_right = 44
	paper.content_margin_top = 30
	paper.content_margin_bottom = 22
	add_theme_stylebox_override("panel", paper)
	custom_minimum_size = Vector2(620, 520)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	count_l = Label.new()
	count_l.add_theme_font_size_override("font_size", 13)
	count_l.add_theme_color_override("font_color", Color(0.5, 0.4, 0.3))
	box.add_child(count_l)
	title_l = Label.new()
	title_l.add_theme_font_size_override("font_size", 28)
	title_l.add_theme_color_override("font_color", Color(0.25, 0.16, 0.1))
	title_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title_l)
	body_l = RichTextLabel.new()
	body_l.fit_content = false
	body_l.scroll_active = false
	body_l.custom_minimum_size = Vector2(530, 340)
	body_l.add_theme_font_size_override("normal_font_size", 19)
	body_l.add_theme_color_override("default_color", Color(0.2, 0.14, 0.1))
	box.add_child(body_l)
	foot_l = Label.new()
	foot_l.add_theme_font_size_override("font_size", 13)
	foot_l.add_theme_color_override("font_color", Color(0.5, 0.4, 0.3))
	box.add_child(foot_l)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

## Opens the pile: at the oldest unread letter, or the newest when all are read.
func open(got: Array, read: Array, keeps_found: int, keeps_total: int) -> void:
	ids = got.duplicate()
	unread_ids = got.filter(func(i): return not read.has(i))
	if ids.is_empty():
		return
	idx = ids.find(unread_ids[0]) if not unread_ids.is_empty() else ids.size() - 1
	foot_l.text = ""
	visible = true
	_show(idx)
	foot_l.set_meta("keeps", "Keepsakes on the shelf: %d / %d" % [keeps_found, keeps_total])
	_foot()

func _foot() -> void:
	foot_l.text = "%s        A / D  turn the page        E or Esc  close" % String(foot_l.get_meta("keeps", ""))

func _show(i: int) -> void:
	idx = clampi(i, 0, ids.size() - 1)
	var l: Dictionary = Story.letter(ids[idx])
	title_l.text = String(l.get("title", ""))
	count_l.text = "LETTER %d OF %d%s" % [idx + 1, ids.size(), "     NEW" if unread_ids.has(ids[idx]) else ""]
	body_l.text = String(l.get("body", ""))
	body_l.visible_ratio = 0.0
	if tw:
		tw.kill()
	var secs := clampf(body_l.get_total_character_count() * 0.012, 1.2, 4.5)
	tw = create_tween()
	tw.tween_property(body_l, "visible_ratio", 1.0, secs)
	var this_id: String = ids[idx]
	tw.finished.connect(func(): _mark(this_id))   # a letter counts as read once its writing has finished (paging past it does not)

func _mark(id: String) -> void:
	unread_ids.erase(id)
	read_letter.emit(id)

func nav(dir: int) -> void:
	if ids.is_empty():
		return
	_show(posmod(idx + dir, ids.size()))

func typing() -> bool:
	return visible and body_l.visible_ratio < 0.999

## E or Esc: the first press finishes the writing, the next closes. Returns true when it closed.
func dismiss() -> bool:
	if typing():
		if tw:
			tw.kill()
		body_l.visible_ratio = 1.0
		_mark(current_id())
		return false
	visible = false
	return true

func current_id() -> String:
	return String(ids[idx]) if not ids.is_empty() else ""
