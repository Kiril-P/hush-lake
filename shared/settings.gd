class_name GameSettings
extends RefCounted
## Every player setting in one place: the defaults, the limits, how it is saved (in `GameState.meta.settings`, so it survives
## starting a new run) and the list the settings screen is built from. The game applies them in `_apply_settings()`.

## key -> {label, kind: "slider"|"toggle"|"choice", def, min, max, step, tab, hint, fmt}
const DEFS := {
	"sens":   {"label": "Mouse sensitivity", "kind": "slider", "def": 0.002, "min": 0.0005, "max": 0.006, "tab": 0, "fmt": "x", "hint": "How far the view turns per mouse movement."},
	"inv":    {"label": "Invert look (Y)", "kind": "toggle", "def": 0.0, "tab": 0, "hint": "Mouse up looks down."},
	"fov":    {"label": "Field of view", "kind": "slider", "def": 75.0, "min": 60.0, "max": 100.0, "step": 1.0, "tab": 0, "fmt": "deg", "hint": "A wider view sees more but bends the edges."},
	"bob":    {"label": "Head bob", "kind": "slider", "def": 1.0, "min": 0.0, "max": 1.0, "tab": 0, "fmt": "pct", "hint": "The sway of the view while you walk. 0 = steady."},
	"shake":  {"label": "Screen shake", "kind": "slider", "def": 1.0, "min": 0.0, "max": 1.0, "tab": 0, "fmt": "pct", "hint": "Kicks, big catches and the Eye waking. 0 = still."},
	"hero":   {"label": "Slow motion on big catches", "kind": "toggle", "def": 1.0, "tab": 0, "hint": "A half-second slow beat for a first-of-its-kind or valuable catch. Off = no time change."},
	"punch":  {"label": "View punch (FOV kicks)", "kind": "slider", "def": 1.0, "min": 0.0, "max": 1.0, "tab": 0, "fmt": "pct", "hint": "The little zoom pulses on bites, throws and feeding streaks."},
	"hints":  {"label": "Guidance (NEXT strip, tips, pin)", "kind": "toggle", "def": 1.0, "tab": 1, "hint": "Turn off once you know the game. H still asks Olga."},
	"prompts": {"label": "Interaction prompts", "kind": "toggle", "def": 1.0, "tab": 1, "hint": "The line under the crosshair that says what a click does."},
	"arc":    {"label": "Throw arc preview", "kind": "toggle", "def": 1.0, "tab": 1, "hint": "The dotted line and ring while you charge a throw."},
	"rings":  {"label": "Kick target rings", "kind": "toggle", "def": 1.0, "tab": 1, "hint": "Amber rings under the fish a kick would hit."},
	"ui":     {"label": "UI size", "kind": "slider", "def": 1.0, "min": 0.8, "max": 1.4, "step": 0.05, "tab": 1, "fmt": "pct", "hint": "Scales every card and label on screen."},
	"vol":    {"label": "Master volume", "kind": "slider", "def": 1.0, "min": 0.0, "max": 1.0, "tab": 2, "fmt": "pct", "hint": ""},
	"sfx":    {"label": "Effects", "kind": "slider", "def": 1.0, "min": 0.0, "max": 1.0, "tab": 2, "fmt": "pct", "hint": "Kicks, splashes, coins, drills."},
	"music":  {"label": "Music", "kind": "slider", "def": 0.8, "min": 0.0, "max": 1.0, "tab": 2, "fmt": "pct", "hint": "The score: a piano and glass bells that follow the hour, the weather and the Eye."},
	"amb":    {"label": "Ambience", "kind": "slider", "def": 1.0, "min": 0.0, "max": 1.0, "tab": 2, "fmt": "pct", "hint": "The wind and the soft pad underneath."},
	"cinematic": {"label": "Cinematic lighting", "kind": "toggle", "def": 0.0, "tab": 3, "hint": "Ambient occlusion, glossy ice that reflects the Eye and lamps, light shafts. Prettier, needs a stronger GPU; turn off if the frame rate drops."},
	"full":   {"label": "Fullscreen", "kind": "toggle", "def": 0.0, "tab": 3, "hint": ""},
	"vsync":  {"label": "V-Sync", "kind": "toggle", "def": 1.0, "tab": 3, "hint": "Smoother picture, may add a little input delay."},
	"shadows": {"label": "Shadows", "kind": "toggle", "def": 1.0, "tab": 3, "hint": "Turn off for a lighter load on slower machines."},
	"snow":   {"label": "Falling snow", "kind": "toggle", "def": 1.0, "tab": 3, "hint": ""},
	"vignette": {"label": "Screen vignette", "kind": "toggle", "def": 1.0, "tab": 3, "hint": "The soft dark edge."},
	"weather": {"label": "Weather", "kind": "toggle", "def": 1.0, "tab": 3, "hint": "Flurries, snowfall, fog and blizzards come and go. Off = always clear."},
}

const TABS := ["Look & feel", "Interface", "Audio", "Video"]

static func def(key: String) -> float:
	return float(DEFS[key].def)

static func get_value(key: String) -> float:
	var sv: Dictionary = GameState.meta.get("settings", {})
	return float(sv.get(key, DEFS[key].def))

static func on(key: String) -> bool:
	return get_value(key) > 0.5

static func set_value(key: String, v: float) -> void:
	var sv: Dictionary = GameState.meta.get("settings", {})
	sv[key] = v
	GameState.meta["settings"] = sv

static func reset_all() -> void:
	GameState.meta["settings"] = {}

static func is_default(key: String) -> bool:
	return absf(get_value(key) - def(key)) < 0.0001

static func format(key: String, v: float) -> String:
	var d: Dictionary = DEFS[key]
	match String(d.get("fmt", "")):
		"pct": return "%d%%" % int(round(v * 100.0))
		"deg": return "%d" % int(round(v))
		"x": return "%.1fx" % (v / 0.002)
	return "%.2f" % v

static func keys_for_tab(tab: int) -> Array:
	var out := []
	for k in DEFS:
		if int(DEFS[k].tab) == tab:
			out.append(k)
	return out
