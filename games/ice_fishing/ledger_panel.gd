class_name LedgerPanel
extends PanelContainer
## The Ledger screen (L): one row per lifetime goal with a bar to the next tier and pips for the tiers passed.

var grid: GridContainer
var title: Label
var foot: Label

func _init() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.1, 0.2, 0.96)
	sb.border_color = Color(1.0, 0.78, 0.35, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(22)
	add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.35))
	box.add_child(title)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(700, 430)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(sc)
	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 8)
	sc.add_child(grid)
	foot = Label.new()
	foot.add_theme_font_size_override("font_size", 14)
	foot.add_theme_color_override("font_color", Color(0.62, 0.66, 0.85))
	box.add_child(foot)
	visible = false

func _fmt(v: float) -> String:
	if v >= 10000.0:
		return "%.1fk" % (v / 1000.0)
	return "%d" % int(v)

## rows: Ledger.rows(); pearls: what you hold; claimed_pearls: paid so far; total: the most the ledger can ever pay.
func show_rows(rows: Array, pearls: int, claimed_pearls: int, total: int) -> void:
	title.text = "THE LEDGER      %d / %d pearls earned      you hold %d" % [claimed_pearls, total, pearls]
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	for r in rows:
		var nm := Label.new()
		nm.text = r.name
		nm.add_theme_font_size_override("font_size", 18)
		nm.add_theme_color_override("font_color", Color(0.96, 0.93, 0.85) if r.tier > 0 else Color(0.8, 0.82, 0.92))
		nm.custom_minimum_size = Vector2(200, 0)
		grid.add_child(nm)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(230, 16)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		bar.min_value = r.prev
		bar.max_value = r.next if r.next > 0.0 else maxf(r.prev, 1.0)
		bar.value = r.value if r.next > 0.0 else bar.max_value
		grid.add_child(bar)
		var tx := Label.new()
		tx.text = ("%s / %s  %s" % [_fmt(r.value), _fmt(r.next), r.desc]) if r.next > 0.0 else ("%s  %s  - done" % [_fmt(r.value), r.desc])
		tx.add_theme_font_size_override("font_size", 14)
		tx.add_theme_color_override("font_color", Color(0.62, 0.66, 0.85))
		tx.custom_minimum_size = Vector2(230, 0)
		grid.add_child(tx)
		var pips := Label.new()
		pips.text = "●".repeat(r.tier) + "○".repeat(r.tiers - r.tier)
		pips.add_theme_font_size_override("font_size", 16)
		pips.add_theme_color_override("font_color", Color(1.0, 0.78, 0.35))
		grid.add_child(pips)
	foot.text = "Each tier pays pearls once. Pearls buy perks when you refreeze (R).        L: close"
