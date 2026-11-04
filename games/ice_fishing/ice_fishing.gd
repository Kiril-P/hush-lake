extends Node3D
## First-person ice fishing on a hex lake.
##
## STORY: Olga has watched the Eye under Hush Lake for most of her life. She does not buy fish:
## she talks, hints and remembers. YOU feed the Eye, which pays in coins as it wakes.
## You start with bare hands: ONE fish at a time. A bucket (shop) lets you carry more;
## auto-rods and belts deliver for you. Optional processing stations (gutting table, smoker) multiply value.
##
## Borrowed from the reference games:
##  Moon Sweepers     carry capacity + walk it to the depot, tool/gear upgrades, boots
##  Leaf it Alone     hold-to-work tool, wide-area upgrade (drill opens neighbours), satisfying counters
##  Needle in Haystack rare finds hidden in the catch + a journal to fill
##  Project P.I.T.T.  goal chain with rewards, automation feeding the delivery point, combo chains
##  Chopping Trees    calm, no fail state, world that grows outward (lake expansion)

const SceneryScript := preload("res://games/ice_fishing/scenery.gd")
const SfxScript := preload("res://shared/sfx.gd")
const LakeModelScript := preload("res://games/ice_fishing/lake_model.gd")
const LakeMapScript := preload("res://games/ice_fishing/lake_map.gd")
const GuideScript := preload("res://games/ice_fishing/guide.gd")
const YardScript := preload("res://games/ice_fishing/fish_yard.gd")

const TILE := 7.0            # hex radius of a fish cell. Cells are invisible now: the lake is open ice
const EYE_R := 10.0          # the Eye at the centre of the lake (see scenery.gd)
const PUPIL_R := 4.8
const EYE_H := 1.7           # eye height: you are a person on a big lake
const EYE_MULT := 1.25       # every fish fed to the Eye pays this multiple of its base value
const EYE_STAGES := [50, 300, 1050, 4000, 8500]   # fish fed to reach each stage
const EYE_LINES := ["The Eye blinks.", "The Eye turns to look at you.", "The Eye opens wider. The ice hums.",
	"The Eye is almost fully open. It is still hungry.", "THE EYE IS AWAKE."]
const BELT_SPEED := 4.5
const BELT_MAX_FISH := 600
const MIN_HOLE_GAP := 1.6
const RIDE_SPEED := [1.0, 2.4, 3.0, 3.6]   # snowmobile levels 0..3
const SLED_BONUS := 10                      # snowmobile level 3 tows a sled: +10 carry while riding
const CANNERY_MULT := 1.5                   # a cannery on a belt: every fish riding it is worth x1.5
const SORTER_MULT := 1.6                    # a sorter: fish worth 5+ get x1.6
const DEPOT_MULT := 1.05                    # a depot's sled run pays a little less than hand-feeding the Eye
const BUILD_ITEMS := ["Cannery", "Sorter", "Depot", "Ice-Breaker"]
const FEED_NOTES := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21]   # semitones: a hand-fed streak climbs a pentatonic scale
const KICK_MIN := 7.0                                    # a tap kick sends a fish ~8 m over the ice
const KICK_BASE_MAX := 16.0                               # a fully charged kick (more with Kick Power)
const KICK_CHARGE_TIME := 0.9
const KICK_REACH := 3.6
const PICKUP_RADIUS := 3.8
const DIVE_MAX := 16                                      # belt fish diving into the funnel at once (visual only)
const RIG_INTERVAL := 7.0
const RIG_BASE := 900.0
const RIG_GROWTH := 2.4
const AUTO_WAIT := [16.0, 22.0]   # seconds between an auto-rod's fish
const AUTO_BASE := 60.0
const AUTO_GROWTH := 1.55
const RIG_BASE_CAP := 3     # rigs allowed at the start; every Eye stage past the first allows one more
# The Eye is the point: waking it unlocks the late game. Coins offered at its rim (a "tithe") are an endless sink.
const TITHE_BASE := 150.0
const TITHE_GROWTH := 1.8
const TITHE_BONUS := 0.07    # +7% fish value per tithe level
const TITHE_MIN_STAGE := 1
const AWAKEN_BONUS := 0.25   # waking the Eye fully: +25% fish value for the rest of the lake
const AWAKEN_PEARLS := 3
const DEPTH_VALUE := 0.25    # each lake finished before this one makes its fish 25% richer (and the lake 30% bigger)
const EYE_BOONS := ["The Eye takes tithes: with empty hands, click it to offer coins for endless value",
	"A 4th Ice-Breaker may be built", "A 5th Ice-Breaker may be built", "A 6th Ice-Breaker may be built",
	"The Eye wakes: +25% fish value, +3 pearls, a 7th rig; the next lake is bigger and richer"]
const RANGE_BUILD := 9.0
const BITE_WINDOW := 1.5
const REACH := 70.0
const DRILL_BASE_TIME := 1.6
const GUT_TIME := 0.9
const GUT_MULT := 1.4
const SMOKE_TIME := 10.0
const SMOKE_MULT := 2.5
const SMOKER_SLOTS := 4
const STASH_MAX := 4
const WALK_LIMIT := 112.0   # the lake is ~180 m across; you can walk anywhere on it and a little way onto the shore
const HUT_RADIUS := 27.0    # Olga's hut sits in the camp on the ice beside the Eye
const HUT_BEARING := -62.0
const RANGE_ICE := 7.0      # you must walk to things: ice and holes within 7 m,
const RANGE_SIGN := 7.0     # shop stalls within 7 m,
const RANGE_HATCH := 6.0    # Olga's hatch within 6 m,
const RANGE_EYE := 9.0      # you must be within 9 m of the Eye's rim (aim anywhere on it)
const SECTOR_REWARD := [200, 700, 1800]
const REFREEZE_MIN_SECTORS := 6   # clear this many sectors before you may refreeze the lake
const EMPTY_LAKE_PEARLS := 5      # bonus pearls for emptying the whole lake
# Pearls are the permanent currency. Earned by clearing sectors, spent between lakes. Cost = base * (level + 1).
const PERKS := {
	"pockets": {"name": "Warm Pockets", "desc": "start each lake with +1 bucket level", "cost": 2, "max": 3},
	"seed":    {"name": "Seed Money",   "desc": "start each lake with +40 coins",      "cost": 1, "max": 5},
	"favour":  {"name": "Olga's Favour", "desc": "+10% sale value, always",            "cost": 3, "max": 5},
	"hands":   {"name": "Quick Hands",  "desc": "start with +1 drill speed level",     "cost": 2, "max": 3},
}
const SECTOR_PERK := 0.02   # +2% sale value per cleared sector
const COMBO_WINDOW := 14.0   # long enough to push a catch to the Eye between casts
const CAPACITIES := [1, 3, 6, 10, 16, 24, 36, 50]
const TOOLS := ["Drill", "Rod", "Auto-Rod", "Smoker", "Gut Table", "Belt", "Build"]
const TOOL_UNLOCK := ["", "", "t_auto", "t_smoker", "t_table", "t_belt", "t_build"]

const SPECIES := [
	{"name": "Minnow",       "value": 1.0,   "w": 60.0, "color": Color(0.75, 0.8, 0.85)},
	{"name": "Perch",        "value": 2.0,   "w": 22.0, "color": Color(0.6, 0.8, 0.5)},
	{"name": "Silver Pike",  "value": 5.0,   "w": 9.0,  "color": Color(0.85, 0.9, 1.0)},
	{"name": "Golden Trout", "value": 14.0,  "w": 3.0,  "color": Color(1.0, 0.8, 0.25)},
	{"name": "Old Boot",     "value": 0.5,   "w": 3.0,  "color": Color(0.4, 0.28, 0.2)},
	{"name": "Old Coin",     "value": 30.0,  "w": 1.8,  "color": Color(0.95, 0.75, 0.2)},
	{"name": "Glass Pearl",  "value": 90.0,  "w": 0.7,  "color": Color(0.7, 0.95, 1.0)},
	{"name": "Ancient Fish", "value": 250.0, "w": 0.5,  "color": Color(0.4, 1.0, 0.8)},
]

# shop: "start" = available from the beginning, otherwise unlocked by a goal
const UPGRADES := {
	"bucket":   {"name": "Bucket",      "base": 6.0,   "growth": 2.2,  "max": 7, "start": true},
	"bait":     {"name": "Bait",        "base": 10.0,  "growth": 1.6,  "max": 8, "start": true, "desc": "bites come sooner"},
	"boots":    {"name": "Boots",       "base": 12.0,  "growth": 1.8,  "max": 5, "start": true, "desc": "walk faster"},
	"drill":    {"name": "Drill Speed", "base": 18.0,  "growth": 1.6,  "max": 6, "start": true, "desc": "drill & gut faster"},
	"lines":    {"name": "Extra Line",  "base": 14.0,  "growth": 1.9,  "max": 4, "desc": "+1 fish per bite"},
	"market":   {"name": "Lure Polish", "base": 25.0,  "growth": 1.85, "max": 12, "desc": "+10% fish value"},
	"sonar":    {"name": "Sonar",       "base": 40.0,  "growth": 2.0,  "max": 3, "desc": "see the fish under the ice"},
	"wide":     {"name": "Wide Drill",  "base": 60.0,  "growth": 2.2,  "max": 3, "desc": "drilling opens neighbours"},
	"snowmobile": {"name": "Snowmobile", "base": 90.0, "growth": 2.6, "max": 3, "desc": "V to ride: faster. Lv3 tows a sled (+10 carry)"},
	"kick":     {"name": "Kick Power", "base": 20.0,  "growth": 1.8,  "max": 5, "start": true, "desc": "kicks send fish farther"},
	"conveyor": {"name": "Belt Motor",  "base": 140.0, "growth": 2.3,  "max": 4, "desc": "belts run faster, +15% value"},
}

# goals: stat keys are counters (stats[...]), "lvl:<upgrade>", "found:<species>", or "journal"
const GOALS := [
	{"text": "Drill your first hole", "stat": "holes", "target": 1, "reward": 4,
		"line": "Olga: Every last fish out of this lake, dear. Start with the Shallows. Cast a line (2)."},
	{"text": "Catch a fish", "stat": "caught", "target": 1, "reward": 4,
		"line": "Olga: Now push it into the Eye, dear. Walk into it, or kick it with the right mouse."},
	{"text": "Feed a fish to the Eye", "stat": "eye_fed", "target": 1, "reward": 5,
		"line": "Olga: There. It looked at you, didn't it? Save up for a bucket at the stalls."},
	{"text": "Buy a Bucket", "stat": "lvl:bucket", "target": 1, "reward": 10,
		"line": "Olga: Three at a time! Now we're a business.", "unlock": ["lines", "market"]},
	{"text": "Earn 50 coins", "stat": "earned", "target": 50, "reward": 15,
		"line": "Olga: An Auto-Rod (3) will fish a hole for you. Click it to collect.", "unlock": ["t_auto"]},
	{"text": "Fish a patch empty", "stat": "tiles_cleared", "target": 1, "reward": 20,
		"line": "Olga: That patch is fished out. Sonar shows what's still under the ice.", "unlock": ["sonar"]},
	{"text": "Build an Auto-Rod", "stat": "autos", "target": 1, "reward": 30,
		"line": "Olga: Now a belt (6) can carry its catch straight into the Eye.", "unlock": ["t_belt"]},
	{"text": "Lay a belt to the Eye", "stat": "belts", "target": 1, "reward": 40,
		"line": "Olga: Watch them go. It is always hungry, that one."},
	{"text": "Feed the Eye 25 fish", "stat": "eye_fed", "target": 25, "reward": 60,
		"line": "Olga: ...Did it just blink? There's a snowmobile at the stalls now, and Build (7) for the machines.", "unlock": ["snowmobile", "t_build"]},
	{"text": "Buy a Snowmobile", "stat": "lvl:snowmobile", "target": 1, "reward": 80,
		"line": "Olga: Press V to ride. Mind the ice, dear."},
	{"text": "Build a Cannery on a belt", "stat": "cans", "target": 1, "reward": 90,
		"line": "Olga: Canned fish fetch half again. Q cycles what you build."},
	{"text": "Build a Depot", "stat": "depots", "target": 1, "reward": 80,
		"line": "Olga: Drop fish at a depot and a sled runs them to the Eye. Less walking."},
	{"text": "Build an Ice-Breaker", "stat": "rigs", "target": 1, "reward": 400,
		"line": "Olga: ...That is a very large machine. It is eating the lake faster than I can count."},
	{"text": "Drill 4 holes", "stat": "holes", "target": 4, "reward": 15,
		"line": "Olga: Wide Drill opens up several holes at once.", "unlock": ["wide"]},
	{"text": "Clear the Shallows", "stat": "sectors", "target": 1, "reward": 60,
		"line": "Olga: One sector down! The shelves beyond are open now."},
	{"opt": true, "text": "Catch a Silver Pike", "stat": "found:Silver Pike", "target": 1, "reward": 25,
		"line": "Olga: Ooh, shiny. Keep a journal (Tab) of what you find."},
	{"text": "Earn 250 coins", "stat": "earned", "target": 250, "reward": 60,
		"line": "Olga: Gut the fish at a table, smoke them... extra coin! Build them on fished-out tiles.", "unlock": ["t_smoker", "t_table"]},
	{"opt": true, "text": "Gut 5 fish", "stat": "gutted", "target": 5, "reward": 50,
		"line": "Olga: Clean work. Gutted fish fetch 40% more."},
	{"opt": true, "text": "Smoke a batch", "stat": "smokes", "target": 1, "reward": 70,
		"line": "Olga: Mmm, smoked. 2.5x! I'd pay double for these."},
	{"text": "Build 3 Auto-Rods", "stat": "autos", "target": 3, "reward": 120,
		"line": "Olga: A conveyor would save your legs, dear.", "unlock": ["conveyor"]},
	{"text": "Clear 3 sectors", "stat": "sectors", "target": 3, "reward": 150,
		"line": "Olga: The fish are getting wary. The last ones take their time."},
	{"opt": true, "text": "Find a Golden Trout", "stat": "found:Golden Trout", "target": 1, "reward": 120,
		"line": "Olga: Gold! In MY lake?"},
	{"text": "Clear 6 sectors", "stat": "sectors", "target": 6, "reward": 400,
		"line": "Olga: Something down there is stirring. The water's colder."},
	{"text": "Clear 10 sectors", "stat": "sectors", "target": 10, "reward": 800,
		"line": "Olga: More than half. Keep going. I don't like how quiet it's got."},
	{"opt": true, "text": "Find an Ancient Fish", "stat": "found:Ancient Fish", "target": 1, "reward": 1000,
		"line": "Olga: That one's older than the hut. Older than the lake, maybe."},
	{"opt": true, "text": "Fill the journal", "stat": "journal", "target": 8, "reward": 800,
		"line": "Olga: You've found everything the lake gives up."},
	{"text": "Tithe the Eye", "stat": "tithe", "target": 1, "reward": 100,
		"line": "Olga: It likes being given things. Every offering makes the fish worth more."},
	{"text": "Reach Eye stage 3", "stat": "eye_stage", "target": 3, "reward": 400,
		"line": "Olga: Its eyelid is all the way up now. Build more rigs. It wants more."},
	{"text": "Own 2 Ice-Breakers", "stat": "rigs", "target": 2, "reward": 1200,
		"line": "Olga: Two of those monsters... the lake is shaking."},
	{"text": "Tithe the Eye 5 times", "stat": "tithe", "target": 5, "reward": 800,
		"line": "Olga: Five gifts. It hums when you walk up now."},
	{"text": "Earn 10000 coins", "stat": "earned", "target": 10000, "reward": 1500,
		"line": "Olga: More money than I've seen in forty winters."},
	{"text": "Build 12 Auto-Rods", "stat": "autos", "target": 12, "reward": 2500,
		"line": "Olga: A whole forest of rods. Mind the belts, dear."},
	{"text": "Reach Eye stage 4", "stat": "eye_stage", "target": 4, "reward": 3000,
		"line": "Olga: Almost awake. Can you feel the ice breathing?"},
	{"text": "Own 4 Ice-Breakers", "stat": "rigs", "target": 4, "reward": 4000,
		"line": "Olga: ...Four. The lake can hardly hold them."},
	{"text": "Tithe the Eye 12 times", "stat": "tithe", "target": 12, "reward": 5000,
		"line": "Olga: It remembers every one of them."},
	{"text": "Clear 15 sectors", "stat": "sectors", "target": 15, "reward": 4000,
		"line": "Olga: Nearly all of it. The deep is very quiet."},
	{"text": "Earn 100000 coins", "stat": "earned", "target": 100000, "reward": 8000,
		"line": "Olga: A fortune. In fish."},
	{"text": "Wake the Eye (stage 5)", "stat": "eye_stage", "target": 5, "reward": 10000,
		"line": "Olga: ...It's looking right at me. It's awake. Dear, it has been waiting for you."},
	{"text": "Empty the lake", "stat": "sectors", "target": 19, "reward": 5000,
		"line": "Olga: ...Every last one."},
]

const OLGA_CHATTER := ["Olga: Mind the ice, dear.", "Olga: Hot cocoa's on.", "Olga: Forty winters I've watched it. It watches back.",
	"Olga: It was smaller when I was a girl.", "Olga: Don't stare too long. It likes that.", "Olga: Careful with the smoker."]
const DAY_LENGTH := 600.0
const BASE_FOV := 75.0
const ROD_NAMES := ["Twig Rod", "Wooden Rod", "Fiberglass Rod", "Carbon Rod", "Golden Rod"]
const DRILL_NAMES := ["Hand Auger", "Steel Auger", "Power Auger", "Thermal Drill", "Plasma Bit", "Star Drill", "Void Drill"]
const TIER_COLORS := [Color(0.62, 0.55, 0.48), Color(0.72, 0.78, 0.85), Color(0.95, 0.55, 0.2), Color(0.4, 0.9, 1.0),
	Color(1.0, 0.85, 0.3), Color(0.9, 0.5, 1.0), Color(0.4, 1.0, 0.7)]
const HEX_DIRS := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]

var cam: Camera3D
var model
var sector_labels := {}
var lantern_idx := {}
var shadow_mat: StandardMaterial3D
var lake_label: Label
var map_ctrl: Control
var ending_panel: PanelContainer
var ending_label: Label
var refreeze_panel: PanelContainer
var refreeze_label: Label
var refreeze_armed := false
var aim_flat := 9999.0
var play_time := 0.0
var sky_t := 0.0
var tool_view: Node3D
var tool_body: Node3D
var tool_spin: Node3D
var tool_line: Node3D
var tool_sig := ""
var tool_kick := 0.0
var tool_base_x := 0.0
var working := false
var shake := 0.0
var fov_kick := 0.0
var day_t := 0.0
var order := {}
var orders_done := 0
var banner_label: Label
var banner_tween: Tween
var sfx: Node
var drill_snd_t := 0.0
var rail_mat: StandardMaterial3D
var scenery: Node3D
var hut_pos := Vector3.ZERO
var tool := 0
var carry: Array = []      # fish dicts: {name, base, color, mult, gutted, smoked}
var journal := {}          # species name -> count
var stats := {"holes": 0, "caught": 0, "deliveries": 0, "earned": 0.0, "autos": 0, "smokes": 0, "gutted": 0, "tiles_cleared": 0, "sectors": 0, "ended": 0, "eye_fed": 0, "belts": 0, "cans": 0, "sorters": 0, "depots": 0, "rigs": 0, "rides": 0, "tithe": 0, "awakened": 0}
var unlocked := {}
var goal_done: Array = []
var combo := 0
var combo_t := 0.0
var records := {}          # species name -> longest catch (cm)
var line_im: ImmediateMesh
var line_node: MeshInstance3D
var tool_tip: Node3D
var fight_amt := 0.0       # how hard the fish on the line is pulling (0..2): bends the rod, shakes the view
var view_pop := 0.0
var feed_streak := 0          # fish swallowed in a row (hand-fed ones show on the HUD)
var feed_streak_t := 0.0
var dive_live := 0
var streak_label: Label
var flash_rect: ColorRect
var reveal_title: Label
var reveal_sub: Label
var reveal_t := 0.0
var reveal_total := 1.0
var reveal_fov := 0.0
var cine_fov := 0.0           # set by the guide during cutscenes
var awaken_hold := false      # the Eye stays at stage 4 visually until the awakening cutscene opens it
var card_panel: PanelContainer
var card_rarity: Label
var card_name: Label
var card_info: Label
var card_tween: Tween
var tiles := {}            # hex fish cells: invisible, hold the stock and the shoal shadows
var holes: Array = []      # every hole you drilled; each is a "tile-like" dict (see _make_hole)
var belts: Array = []
var belt_fish: Array = []  # fish riding belts: {belt, d, f}
var belt_mm: MultiMesh
var sector_patches := {}
var aim_pos := Vector3.ZERO
var drill_pos := Vector3(9999, 0, 9999)
var depots: Array = []     # drop-off points: {pos, node, idx}
var rigs: Array = []       # ice-breakers: {pos, node, idx, t, belt, tag}
var build_item := 0
var riding := false
var moving := false
var ride_fov := 0.0
var ride_view: Node3D
var drill_prog := 0.0
var drill_marker: MeshInstance3D
var eye_seen_stage := 0
var eye_burst_t := 0.0
var eye_pending := 0.0
var eye_pending_t := 0.0
var sign_labels := {}
var msg_time := 0.0
var view: Node3D
var coins_label: Label
var carry_label: Label
var combo_label: Label
var msg_label: Label
var prompt_label: Label
var goals_label: Label
var start_label: Label
var journal_panel: PanelContainer
var journal_label: Label
var journal_grid: GridContainer
var hotbar: Array[Label] = []
var hotbar_panels: Array[PanelContainer] = []
var hotbar_icons: Array = []
var crosshair: HudWidgets.Crosshair
var carry_bar: ProgressBar
var eye_bar: ProgressBar
var eye_label: Label
var eye_next_label: Label
var start_panel: PanelContainer
var guide: Guide
var yard: FishYard
var kick_charge := -1.0       # right mouse held: 0..1, or -1 when not charging
var kicks := 0
var player_prev := Vector3.ZERO
var flying: Array = []        # fish thrown at the Eye but not yet paid: {f, m}. They are saved so a quit mid-throw loses nothing
var tithe_armed_t := 0.0      # an empty-handed click on the Eye arms the tithe; a second click inside this window pays it
var reset_armed_t := 0.0
var ever_captured := false
var sim_paused := false       # the mouse is free (Esc): the lake stops, the settings card shows
var fov_base := BASE_FOV
var rig_serial := 0
var settings_ctrls: Array = []
var test_capture := false     # headless tools cannot capture the mouse: they ask the game to behave as if it were
var kick_rings: Array = []
var hold_block := false
var tool_swap := 0.0
var pickup_from: Array = []
var restoring := false
var slide_snd_t := 0.0
var kick_boot: Node3D
var boot_tween: Tween
const BOOT_ROT := Vector3(-6, 38, 6)   # turned to show its side, toe forward
const BOOT_REST := Vector3(0.24, -0.9, -0.2)   # below the bottom of the screen
var bob_t := 0.0
var quiet_notice := ""         # an Eye stage reached out of sight: told to the player with the welcome-back line
var work_bar: ProgressBar

func _ready() -> void:
	randomize()
	if GameState.save_slot == "default":
		GameState.save_slot = "eyeslice"
	GameState.autosave = not GameState.save_slot.begins_with("test")
	var away := GameState.load_game()
	GameState.about_to_save.connect(_on_about_to_save)
	sfx = SfxScript.new()
	add_child(sfx)
	for id in UPGRADES:
		unlocked[id] = UPGRADES[id].get("start", false)
	goal_done.resize(GOALS.size())
	goal_done.fill(false)
	cam = $Player/Camera3D
	$Player.position = Vector3(-8.2, EYE_H, 14.3)   # inside the Shallows, a few steps from the Eye
	$Player.rotation.y = deg_to_rad(-30.0)             # ...facing it
	cam.rotation.x = deg_to_rad(-5)
	view = Node3D.new()
	view.position = Vector3(-0.42, -0.4, -0.8)
	cam.add_child(view)
	line_im = ImmediateMesh.new()
	line_node = MeshInstance3D.new()
	line_node.mesh = line_im
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.93, 0.97, 1.0, 0.85)
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lm.cull_mode = BaseMaterial3D.CULL_DISABLED
	line_node.material_override = lm
	line_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	line_node.extra_cull_margin = 200.0
	add_child(line_node)
	tool_view = Node3D.new()
	tool_view.position = Vector3(0.38, -0.36, -0.65)
	tool_view.scale = Vector3.ONE * 0.85
	cam.add_child(tool_view)
	kick_boot = ToolModels.boot(cam)
	kick_boot.position = BOOT_REST
	kick_boot.scale = Vector3.ONE * 0.7
	kick_boot.rotation_degrees = BOOT_ROT
	model = LakeModelScript.new()
	var fresh_lake := GameState.extra.is_empty()
	model.generate(randi(), String(GameState.meta.get("next_mod", "")) if fresh_lake else "", _meta_int("lakes") if fresh_lake else 0)
	_build_world()
	yard = YardScript.new()
	add_child(yard)
	yard.obstacles = scenery.obstacles
	yard.eye_r = EYE_R
	yard.pupil_r = PUPIL_R
	yard.swallowed.connect(_on_fish_swallowed)
	yard.overflowed.connect(_on_fish_overflow)
	yard.edge_fn = scenery.edge_at
	yard.touched.connect(func(pos: Vector3, impact: float): _snow_fx(pos, 4 + int(impact), 0.5 + impact * 0.12))
	yard.trail.connect(func(pos: Vector3, speed: float):
		_snow_fx(pos + Vector3(0, 0.05, 0), 2, 0.4 + speed * 0.04)
		if slide_snd_t <= 0.0:
			slide_snd_t = 0.18
			sfx.play("slide", -10.0 + minf(speed, 14.0) * 0.4, randf_range(0.9, 1.15)))
	yard.kicked.connect(func(pos: Vector3, dir: Vector3, power: float): _snow_fx(pos - dir * 0.3, 7, 0.9 + power * 0.06))
	yard.landed.connect(func(_f, impact): sfx.play("thud", -12.0 + minf(impact, 9.0) * 0.8, randf_range(0.85, 1.25)))
	_build_ui()
	for c in model.tile_sector:
		_make_tile(c)
	_make_sector_labels()
	_make_sector_patches()
	_setup_lanterns()
	var resumed := _restore(GameState.extra)
	_paint_all()
	GameState.currency_changed.connect(_on_currency_changed)
	_apply_settings()
	_refresh_view()
	_build_ride_view()
	_setup_belt_fish()
	eye_seen_stage = eye_stage()
	_refresh()
	sfx.start_ambient()
	_log("--- session start (resumed=%s) ---" % resumed)
	if resumed:
		_say_notice("Welcome back!")
		_offline(away)
	else:
		if _meta_int("lakes") > 0:
			_banner("%s #%d: %s" % [model.mod_info().name, _meta_int("lakes") + 1, model.mod_info().desc], Color(0.7, 0.9, 1.0))
		if GameState.save_slot.begins_with("test"):
			_say("Olga: The Eye wants feeding, dear. Press 1 and hold click anywhere on the ice. Push what you catch into the Eye.")
		else:
			guide.want_intro = true

# ---------- hex helpers ----------
func _on_currency_changed(_v: float) -> void:
	_refresh()

func _ring(c: Vector2i) -> int:
	return maxi(maxi(abs(c.x), abs(c.y)), abs(-c.x - c.y))

func _hex_pos(c: Vector2i) -> Vector3:
	return Vector3(TILE * sqrt(3.0) * (c.x + c.y / 2.0), 0.0, TILE * 1.5 * c.y)


# ---------- builders ----------
func _mat(color: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	return m

func _box(parent: Node, pos: Vector3, size: Vector3, color: Color, action := "", emit := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = _mat(color, emit)
	m.position = pos
	parent.add_child(m)
	if action != "":
		_add_collider(m, BoxShape3D.new(), size, action)
	return m

func _add_collider(m: Node3D, shape: Shape3D, size: Vector3, action: String) -> void:
	if shape is BoxShape3D:
		shape.size = size
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	body.set_meta("action", action)
	m.add_child(body)

func _label3d(parent: Node, pos: Vector3, text: String, px := 0.008, billboard := true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = px
	l.position = pos
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
	l.outline_size = 10
	parent.add_child(l)
	return l

func _fish_mesh(f: Dictionary, parent: Node, scale_f := 1.0) -> Node3D:
	var root := FishModel.build(f.name, f.color, 0.34 * scale_f * float(f.get("lenk", 1.0)))
	parent.add_child(root)
	return root

func _build_world() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.17, 0.25, 0.55)
	sm.sky_horizon_color = Color(1.0, 0.68, 0.52)
	sm.ground_horizon_color = Color(0.98, 0.62, 0.55)
	sm.ground_bottom_color = Color(0.45, 0.7, 0.88)
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.75, 0.6)
	sun.shadow_enabled = true
	add_child(sun)
	# Olga's hut: local +Z faces the lake centre
	var hut := Node3D.new()
	hut.position = Vector3(sin(deg_to_rad(HUT_BEARING)) * HUT_RADIUS, 0.0, -cos(deg_to_rad(HUT_BEARING)) * HUT_RADIUS)
	add_child(hut)
	hut.look_at(Vector3(0, 0, 0), Vector3.UP, true)
	hut_pos = hut.global_position + hut.global_basis.z * 2.3 + Vector3(0, 1.1, 0)
	_box(hut, Vector3(0, 1.5, 0), Vector3(5, 3, 4), Color(0.55, 0.2, 0.18))
	_box(hut, Vector3(0, 1.0, 2.05), Vector3(1.3, 2.0, 0.15), Color(1.0, 0.75, 0.35), "olga", 1.2)
	_box(hut, Vector3(0, 1.05, 2.45), Vector3(1.8, 0.12, 0.8), Color(0.3, 0.19, 0.13))  # her window counter
	_label3d(hut, Vector3(0, 2.7, 2.2), "OLGA'S FISH HUT", 0.011, false)
	_label3d(hut, Vector3(0, 2.3, 2.2), "knock to chat", 0.006, false)
	scenery = SceneryScript.new()
	add_child(scenery)
	scenery.build(env, sun, hut)
	# one collider for the whole sheet of ice (aim position tells us which cell) and one for the Eye
	for spec in [["ice", 100.0, 0.4, -0.3], ["eye", EYE_R, 0.7, -0.05]]:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = spec[1]
		shape.height = spec[2]
		cs.shape = shape
		body.add_child(cs)
		body.position = Vector3(0, spec[3], 0)
		body.set_meta("action", spec[0])
		add_child(body)
	# each upgrade has a stall in the camp or out on the ice (see SceneryScript.SHOP_SPOTS)
	for id in UPGRADES:
		var spot: Array = SceneryScript.SHOP_SPOTS[id]
		var bp: Vector3 = SceneryScript.bearing_pos(spot[0], spot[1])
		var s := Node3D.new()
		s.position = Vector3(bp.x, 1.6, bp.z)
		add_child(s)
		s.look_at(Vector3(0, 1.6, 0), Vector3.UP, true)
		_box(s, Vector3.ZERO, Vector3(3.4, 1.7, 0.15), Color(0.18, 0.2, 0.3), "buy:" + id)
		var l := Label3D.new()
		l.pixel_size = 0.0068
		l.font_size = 36
		l.width = 470.0   # the board is 3.4 m wide: long descriptions wrap onto the next line instead of running off the sign
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.outline_size = 10
		l.line_spacing = -2.0
		l.position = Vector3(0, 0, 0.1)
		s.add_child(l)
		sign_labels[id] = l
		scenery.decorate_stall(s, id)

## A fish cell: no mesh, no collider. It owns a stock of fish and a shoal of shadows you can see under the ice.
func _make_tile(c: Vector2i) -> void:
	var node := Node3D.new()
	node.position = _hex_pos(c)
	add_child(node)
	var t := {"c": c, "sector": model.tile_sector[c], "node": node, "state": "ice", "announced": false, "shadows": []}
	tiles[c] = t
	if c == Vector2i.ZERO:
		t.state = "platform"  # the Eye sits here
	else:
		_make_shadows(t)

## World position -> the hex cell under it (axial coordinates, same layout as _hex_pos).
func _cell_at(pos: Vector3) -> Vector2i:
	var rr := pos.z / (TILE * 1.5)
	var q := pos.x / (TILE * sqrt(3.0)) - rr / 2.0
	var x := q
	var z := rr
	var y := -x - z
	var rx := roundf(x)
	var ry := roundf(y)
	var rz := roundf(z)
	var dx := absf(rx - x)
	var dy := absf(ry - y)
	var dz := absf(rz - z)
	if dx > dy and dx > dz:
		rx = -ry - rz
	elif dy > dz:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector2i(int(rx), int(rz))

# dark fish silhouettes drifting under the ice: the more fish left in a cell, the bigger the shoal
func _make_shadows(t: Dictionary) -> void:
	if shadow_mat == null:
		shadow_mat = StandardMaterial3D.new()
		shadow_mat.albedo_color = Color(0.05, 0.16, 0.34, 0.55)
		shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 8:
		var m := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.5
		sp.height = 1.0
		sp.radial_segments = 8
		sp.rings = 4
		m.mesh = sp
		m.scale = Vector3(1.3, 0.03, 0.48)
		m.material_override = shadow_mat
		m.position = Vector3(0, 0.065, 0)
		t.node.add_child(m)
		t.shadows.append({"node": m, "r": randf_range(0.15, 0.8) * TILE, "a": randf() * TAU,
			"spd": randf_range(0.05, 0.14) * (1.0 if randf() < 0.5 else -1.0)})
	_update_shadows(t)

func _update_shadows(t: Dictionary) -> void:
	var n := 0
	if t.get("state", "") != "platform":
		n = mini(8, ceili(model.tile_left(t.c) / 2.0))
	for i in t.shadows.size():
		t.shadows[i].node.visible = i < n

func _emptied(t: Dictionary) -> bool:
	return t.state != "platform" and model.tile_left(t.c) == 0

func _paint_tile(_t: Dictionary) -> void:
	_update_sector_patches()

func _paint_all() -> void:
	for c in tiles:
		var t: Dictionary = tiles[c]
		t.announced = _emptied(t)
		_update_shadows(t)
	_update_sector_labels()

func tile_map_color(t: Dictionary) -> Color:
	if t.state == "platform":
		return Color(0.6, 0.45, 0.28)
	var sec: Dictionary = model.sectors[t.sector]
	if not sec.unlocked:
		return Color(0.2, 0.24, 0.36)
	if sec.cleared:
		return Color(0.95, 0.78, 0.3)
	if _emptied(t):
		return Color(0.88, 0.94, 1.0)
	var init: int = model.initial.get(t.c, 1)
	var f := clampf(float(model.tile_left(t.c)) / maxf(init, 1.0), 0.0, 1.0)
	return Color(0.62, 0.8, 0.95).lerp(Color(0.16, 0.38, 0.7), f)

func _make_sector_labels() -> void:
	for id in model.sectors:
		var sec: Dictionary = model.sectors[id]
		var pos: Vector3 = _hex_pos(sec.center) + Vector3(0, 4.5, 0)
		var l := _label3d(self, pos, "", 0.0011)
		l.fixed_size = true   # a sector's name is the same readable size wherever you stand
		l.font_size = 30
		l.outline_size = 8
		sector_labels[id] = {"label": l, "pos": pos}

## Locked sectors lie under a soft frost; cleared ones have thawed into dark open water. Both are feathered discs.
func _soft_disc(col: Color, plateau: float) -> ShaderMaterial:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, plateau, 1.0])
	grad.colors = PackedColorArray([col, col, Color(col.r, col.g, col.b, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	# the patch fades out near the Eye so frost/thaw never lies over its pupil
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform sampler2D tex : source_color;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec4 c = texture(tex, UV);
	float k = smoothstep(11.0, 14.0, length(wpos.xz));
	ALBEDO = c.rgb;
	ALPHA = c.a * k;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tex", tex)
	return m

func _make_sector_patches() -> void:
	var fm := _soft_disc(Color(0.95, 0.98, 1.0, 0.42), 0.35)
	var tm := _soft_disc(Color(0.02, 0.12, 0.26, 0.93), 0.75)
	for id in model.sectors:
		var wp := _hex_pos(model.sectors[id].center)
		var frost := MeshInstance3D.new()
		var fq := PlaneMesh.new()
		fq.size = Vector2(5.6, 5.6) * TILE
		frost.mesh = fq
		frost.material_override = fm
		frost.position = Vector3(wp.x, 0.04, wp.z)
		add_child(frost)
		var thaw := MeshInstance3D.new()
		var tq := PlaneMesh.new()
		tq.size = Vector2(4.5, 4.5) * TILE
		thaw.mesh = tq
		thaw.material_override = tm
		thaw.position = Vector3(wp.x, 0.05, wp.z)
		thaw.visible = false
		add_child(thaw)
		sector_patches[id] = {"frost": frost, "thaw": thaw}

func _update_sector_patches() -> void:
	for id in sector_patches:
		var sec: Dictionary = model.sectors[id]
		sector_patches[id].frost.visible = not sec.unlocked
		sector_patches[id].thaw.visible = sec.cleared

## One shore lantern per sector, placed in the direction of its sector, lit once that sector is cleared.
func _setup_lanterns() -> void:
	var ids: Array = model.sectors.keys()
	var bearings := []
	for id in ids:
		var wp := _hex_pos(model.sectors[id].center)
		bearings.append(rad_to_deg(atan2(wp.x, -wp.z)))
	scenery.place_lanterns(bearings)
	for i in ids.size():
		lantern_idx[ids[i]] = i

func _update_lanterns() -> void:
	for id in lantern_idx:
		scenery.set_lantern(lantern_idx[id], model.sectors[id].cleared)

func _update_sector_labels() -> void:
	_update_lanterns()
	_update_sector_patches()
	for id in sector_labels:
		var sec: Dictionary = model.sectors[id]
		var l: Label3D = sector_labels[id].label
		if not sec.unlocked:
			l.text = "LOCKED"
			l.modulate = Color(0.7, 0.75, 0.9, 0.6)
		elif sec.cleared:
			l.text = "%s\nCLEARED" % sec.name
			l.modulate = Color(1.0, 0.88, 0.45)
		else:
			l.text = "%s\n%d fish left" % [sec.name, sec.left]
			l.modulate = Color(1, 1, 1)

## True if p is a legal place to drill: on the ice, in an open sector, off the Eye, clear of other holes.
func _can_drill_at(p: Vector3) -> bool:
	var c := _cell_at(p)
	if not tiles.has(c) or tiles[c].state == "platform":
		return false
	if not model.sectors[tiles[c].sector].unlocked:
		return false
	if Vector2(p.x, p.z).length() < EYE_R + 1.2:
		return false
	return not _hole_near(p, MIN_HOLE_GAP)

func _hole_near(p: Vector3, radius: float) -> bool:
	for h in holes:
		if Vector2(h.pos.x - p.x, h.pos.z - p.z).length() < radius:
			return true
	return false

## Drills a hole at p. A hole is a "tile-like" dict: same keys the old per-tile code used, plus a position and index.
const HOLE_WATER := """
shader_type spatial;
render_mode cull_disabled;
void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float deep = smoothstep(1.0, 0.0, r);
	float rip = sin(r * 22.0 - TIME * 1.8) * 0.5 + 0.5;
	rip *= smoothstep(1.0, 0.2, r) * 0.18;
	vec3 shallow = vec3(0.1, 0.4, 0.5);
	vec3 deepc = vec3(0.01, 0.05, 0.12);
	ALBEDO = mix(shallow, deepc, deep);
	EMISSION = vec3(0.1, 0.45, 0.55) * (rip + (1.0 - deep) * 0.12);
	ROUGHNESS = 0.08;
	SPECULAR = 0.8;
}
"""
var hole_water_mat: ShaderMaterial

func _hole_water_material() -> ShaderMaterial:
	if hole_water_mat == null:
		var sh := Shader.new()
		sh.code = HOLE_WATER
		hole_water_mat = ShaderMaterial.new()
		hole_water_mat.shader = sh
	return hole_water_mat

func _make_hole(pos: Vector3, count := true) -> Dictionary:
	var c := _cell_at(pos)
	if not tiles.has(c) or tiles[c].state == "platform":
		return {}
	var node := Node3D.new()
	node.position = Vector3(pos.x, 0.0, pos.z)
	add_child(node)
	var t := {"c": c, "sector": tiles[c].sector, "pos": node.position, "node": node, "state": "hole", "prog": 0.0,
		"cast": 0, "timer": 0.0, "bobber": null, "mark": null, "extra": null, "announced": false, "shadows": [],
		"stash": [], "slot": [], "smoke_t": 0.0, "auto_t": 0.0, "tag": null, "arm": null, "belt": null, "idx": holes.size(),
		"hooked": [], "fight": 0.0, "fight_total": 1.0, "fight_i": 1.0, "nib": [], "dip": 0.0, "flying": false, "fx_t": 0.0}
	holes.append(t)
	if count:
		stats.holes += 1
	for k in 8:
		var ang := TAU * k / 8.0 + randf() * 0.4
		var chunk := _box(node, Vector3(cos(ang), 0.12, sin(ang)) * randf_range(0.75, 1.0), Vector3.ONE * randf_range(0.15, 0.3), Color(0.9, 0.95, 1.0))
		chunk.rotation = Vector3(randf(), randf(), randf())
	var disc := MeshInstance3D.new()
	var dc := CylinderMesh.new()
	dc.top_radius = 0.7
	dc.bottom_radius = 0.7
	dc.height = 0.04
	dc.radial_segments = 14
	disc.mesh = dc
	disc.material_override = _hole_water_material()
	disc.position = Vector3(0, 0.07, 0)
	node.add_child(disc)
	var lip := TorusMesh.new()   # the beaten rim of the hole: a pale lip of ice around the dark water
	lip.inner_radius = 0.66
	lip.outer_radius = 0.82
	lip.rings = 20
	lip.ring_segments = 5
	var lip_mi := MeshInstance3D.new()
	lip_mi.mesh = lip
	lip_mi.material_override = _mat(Color(0.82, 0.93, 1.0))
	lip_mi.position = Vector3(0, 0.07, 0)
	lip_mi.scale = Vector3(1.0, 0.45, 1.0)
	lip_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(lip_mi)
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.9
	cyl.height = 0.8
	_add_collider(disc, cyl, Vector3.ZERO, "hole:%d" % t.idx)
	var b := Node3D.new()  # a float: red top, white bottom, a thin antenna
	var top := MeshInstance3D.new()
	var tsm := SphereMesh.new()
	tsm.radius = 0.15
	tsm.height = 0.3
	tsm.radial_segments = 12
	tsm.rings = 6
	top.mesh = tsm
	top.material_override = _mat(Color(1, 0.3, 0.18), 0.5)
	top.scale = Vector3(1, 0.8, 1)
	top.position = Vector3(0, 0.05, 0)
	b.add_child(top)
	var bot := MeshInstance3D.new()
	var bsm := SphereMesh.new()
	bsm.radius = 0.12
	bsm.height = 0.24
	bsm.radial_segments = 12
	bsm.rings = 6
	bot.mesh = bsm
	bot.material_override = _mat(Color(0.96, 0.96, 1.0))
	bot.position = Vector3(0, -0.07, 0)
	b.add_child(bot)
	_box(b, Vector3(0, 0.26, 0), Vector3(0.02, 0.22, 0.02), Color(1.0, 0.9, 0.3), "", 0.6)
	b.position = Vector3(0, 0.18, 0)
	b.visible = false
	node.add_child(b)
	t.bobber = b
	var mark := _label3d(node, Vector3(0, 1.8, 0), "!", 0.016)
	mark.font_size = 96
	mark.modulate = Color(1, 1, 0.2)
	mark.visible = false
	t.mark = mark
	_update_shadows(tiles[c])
	_paint_tile(tiles[c])
	return t

func _build_auto(t: Dictionary, count := true) -> void:
	t.state = "auto"
	if count:
		stats.autos += 1
	t.auto_t = _auto_wait(t)
	t.extra = Node3D.new()
	t.node.add_child(t.extra)
	t.extra.scale = Vector3.ONE * 1.5
	_update_shadows(t)
	var parts: Dictionary = MachineModels.auto_rod(t.extra)   # a little drill derrick with a pumping beam and a stash crate
	t.arm = parts.arm
	_pop_in(t.extra)
	t.tag = _label3d(t.node, Vector3(0, 3.0, 0), "", 0.012)

func _build_smoker(t: Dictionary) -> void:
	t.state = "smoker"
	t.extra = Node3D.new()
	t.node.add_child(t.extra)
	t.extra.scale = Vector3.ONE * 1.5
	var sp: Dictionary = MachineModels.smoker(t.extra)
	t.smoke_fx = sp.smoke
	_pop_in(t.extra)
	t.tag = _label3d(t.node, Vector3(0, 3.0, 0), "Smoker", 0.012)

func _build_table(t: Dictionary) -> void:
	t.state = "table"
	t.extra = Node3D.new()
	t.node.add_child(t.extra)
	t.extra.scale = Vector3.ONE * 1.5
	MachineModels.gut_table(t.extra)
	_pop_in(t.extra)
	t.tag = _label3d(t.node, Vector3(0, 2.6, 0), "Gut Table", 0.012)

# ---------- UI ----------
func _label(parent: Node, pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", 7)
	parent.add_child(l)
	return l

func _panel(parent: Node, container: Container) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Style.card())
	p.add_child(container)
	parent.add_child(p)
	return p

## A card that sits in the middle of the screen, however tall it grows (a CenterContainer does the centring).
func _center_panel(parent: Node, container: Container) -> PanelContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cc)
	return _panel(cc, container)

func _plain(parent: Node, font_size: int, color := Style.CREAM) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

func _ignore_mouse(n: Node) -> void:
	# Controls under the (captured, frozen) cursor would swallow all mouse input otherwise
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)

func _dot(parent: Node, color: Color, d := 20) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(d, d)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_theme_stylebox_override("panel", Style.box(color, d / 2, color.lightened(0.45), 2, Vector2.ZERO))
	parent.add_child(p)
	return p

func _build_ui() -> void:
	var ui_layer: CanvasLayer = $UI
	$UI/Counter.queue_free()
	var ui := Control.new()  # themed root: everything below inherits the Hush Lake look
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.theme = Style.theme()
	ui_layer.add_child(ui)
	# a soft vignette, cold at the corners, under everything else: it frames the view and quiets the screen edges
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vsh := Shader.new()
	vsh.code = """
shader_type canvas_item;
void fragment() {
	vec2 p = UV - 0.5;
	p.x *= 1.15;
	float d = smoothstep(0.38, 0.95, length(p));
	COLOR = vec4(0.03, 0.06, 0.16, d * 0.42);
}
"""
	var vmat := ShaderMaterial.new()
	vmat.shader = vsh
	vig.material = vmat
	ui.add_child(vig)
	# top-left: coins, bucket, the Eye's progress, lake facts
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 3)
	var lp := _panel(ui, left)
	lp.position = Vector2(20, 16)
	lp.custom_minimum_size = Vector2(300, 0)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 10)
	left.add_child(crow)
	_dot(crow, Style.AMBER, 22)
	coins_label = _plain(crow, 36, Style.AMBER)
	carry_label = _plain(left, 17, Style.MUTED)
	carry_bar = Style.bar(Style.AMBER, 7.0)
	left.add_child(carry_bar)
	combo_label = _plain(left, 16, Style.AMBER)
	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.25)
	left.add_child(sep)
	eye_label = _plain(left, 17, Style.AQUA)
	eye_bar = Style.bar(Style.AQUA, 7.0)
	left.add_child(eye_bar)
	eye_next_label = _plain(left, 14, Style.CREAM)
	eye_next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	eye_next_label.custom_minimum_size = Vector2(270, 0)
	lake_label = _plain(left, 15, Style.MUTED)
	msg_label = Label.new()
	msg_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	msg_label.anchor_top = 1.0
	msg_label.offset_top = -190.0
	msg_label.offset_bottom = -92.0
	msg_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.add_theme_font_size_override("font_size", 19)
	msg_label.add_theme_constant_override("outline_size", 8)
	ui.add_child(msg_label)
	# top-right: goals
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	var rp := _panel(ui, right)
	rp.anchor_left = 1.0
	rp.anchor_right = 1.0
	rp.offset_left = -20.0
	rp.offset_right = -20.0
	rp.offset_top = 16.0
	rp.offset_bottom = 16.0
	rp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	rp.custom_minimum_size = Vector2(300, 0)
	_plain(right, 15, Style.AMBER).text = "GOALS"
	goals_label = _plain(right, 19)
	goals_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goals_label.custom_minimum_size = Vector2(270, 0)
	prompt_label = Label.new()
	prompt_label.set_anchors_preset(Control.PRESET_CENTER)
	prompt_label.position = Vector2(-300, 26)
	prompt_label.size = Vector2(600, 30)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 20)
	prompt_label.add_theme_constant_override("outline_size", 8)
	ui.add_child(prompt_label)
	crosshair = HudWidgets.Crosshair.new()   # reactive: neutral cream ring, amber when you can act, aqua on the Eye and kickable fish
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.size = Vector2(80, 80)
	crosshair.position = Vector2(-40, -40)
	ui.add_child(crosshair)
	work_bar = Style.bar(Style.AQUA, 10.0)
	work_bar.set_anchors_preset(Control.PRESET_CENTER)
	work_bar.position = Vector2(-70, 66)
	work_bar.size = Vector2(140, 10)
	work_bar.visible = false
	work_bar.modulate.a = 0.0   # the crosshair's ring shows this progress now
	ui.add_child(work_bar)
	# bottom: one card per tool, the active one ringed in amber
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top = -20.0
	bar.offset_bottom = -20.0
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui.add_child(bar)
	for i in TOOLS.size():
		var sp := PanelContainer.new()
		sp.custom_minimum_size = Vector2(108, 58)
		sp.add_theme_stylebox_override("panel", Style.slot(false, true))
		bar.add_child(sp)
		hotbar_panels.append(sp)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 4)
		sp.add_child(hb)
		var icon := HudWidgets.ToolIcon.new(i)
		hb.add_child(icon)
		hotbar_icons.append(icon)
		var hl := _plain(hb, 17)
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hotbar.append(hl)
	journal_label = Label.new()
	journal_label.add_theme_font_size_override("font_size", 24)
	var jbox := VBoxContainer.new()
	jbox.add_theme_constant_override("separation", 8)
	jbox.add_child(journal_label)
	journal_grid = GridContainer.new()
	journal_grid.columns = 5
	journal_grid.add_theme_constant_override("h_separation", 18)
	journal_grid.add_theme_constant_override("v_separation", 6)
	jbox.add_child(journal_grid)
	var jhint := Label.new()
	jhint.text = "Tab to close"
	jhint.add_theme_font_size_override("font_size", 14)
	jhint.add_theme_color_override("font_color", Style.MUTED)
	jbox.add_child(jhint)
	journal_panel = _center_panel(ui, jbox)
	journal_panel.visible = false
	# title card shown whenever the mouse is free
	var sbox := VBoxContainer.new()
	sbox.add_theme_constant_override("separation", 6)
	var title := _plain(sbox, 46, Style.AMBER)
	title.text = "HUSH LAKE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_label = _plain(sbox, 20)
	start_label.text = "Click to play   (Esc pauses)\n\nDrill a hole (1), fish it (2). Your catch drops onto the ice:\npush it into the Eye. Walk into fish, or hold right mouse\nand let go to kick them. E picks them up.\nLost? Press H and Olga points the way.\n\nWASD walk   V snowmobile   Tab journal   R refreeze\nM mute   F kick   N twice (paused): start over"
	start_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_settings(sbox)
	var start_center := CenterContainer.new()   # the card always sits in the middle of the screen, however tall it grows
	start_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(start_center)
	start_panel = _panel(start_center, sbox)
	map_ctrl = Control.new()
	map_ctrl.set_script(LakeMapScript)
	map_ctrl.game = self
	map_ctrl.anchor_top = 1.0
	map_ctrl.anchor_bottom = 1.0
	map_ctrl.offset_left = 20.0
	map_ctrl.offset_right = 260.0
	map_ctrl.offset_top = -260.0
	map_ctrl.offset_bottom = -20.0
	ui.add_child(map_ctrl)
	var ebox := VBoxContainer.new()
	var elabel := Label.new()
	ending_label = elabel
	elabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elabel.add_theme_font_size_override("font_size", 28)
	ebox.add_child(elabel)
	ending_panel = _center_panel(ui, ebox)
	ending_panel.visible = false
	refreeze_label = Label.new()
	refreeze_label.add_theme_font_size_override("font_size", 21)
	var rbox := VBoxContainer.new()
	rbox.add_child(refreeze_label)
	refreeze_panel = _center_panel(ui, rbox)
	refreeze_panel.visible = false
	var cbox := VBoxContainer.new()
	cbox.add_theme_constant_override("separation", 0)
	card_rarity = _plain(cbox, 14, Style.CREAM)
	card_rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_name = _plain(cbox, 34, Style.CREAM)
	card_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_info = _plain(cbox, 17, Style.MUTED)
	card_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_panel = _panel(ui, cbox)
	card_panel.anchor_left = 0.5
	card_panel.anchor_right = 0.5
	card_panel.anchor_top = 1.0
	card_panel.anchor_bottom = 1.0
	card_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card_panel.offset_top = -330.0
	card_panel.offset_bottom = -200.0
	card_panel.custom_minimum_size = Vector2(320, 0)
	card_panel.visible = false
	banner_label = Label.new()
	banner_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_label.position = Vector2(0, 150)
	banner_label.add_theme_font_size_override("font_size", 38)
	banner_label.add_theme_constant_override("outline_size", 12)
	banner_label.modulate.a = 0.0
	ui.add_child(banner_label)
	streak_label = Label.new()
	streak_label.set_anchors_preset(Control.PRESET_CENTER)
	streak_label.position = Vector2(-110, 88)
	streak_label.size = Vector2(220, 60)
	streak_label.pivot_offset = Vector2(110, 30)
	streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	streak_label.add_theme_font_size_override("font_size", 46)
	streak_label.add_theme_color_override("font_color", Style.AMBER)
	streak_label.add_theme_constant_override("outline_size", 12)
	streak_label.modulate.a = 0.0
	ui.add_child(streak_label)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1.0, 0.86, 0.55, 0.0)
	ui.add_child(flash_rect)
	reveal_title = Label.new()
	reveal_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	reveal_title.anchor_top = 0.18
	reveal_title.anchor_bottom = 0.30
	reveal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reveal_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reveal_title.add_theme_font_size_override("font_size", 58)
	reveal_title.add_theme_color_override("font_color", Color(0.75, 1.0, 0.95))
	reveal_title.add_theme_constant_override("outline_size", 16)
	reveal_title.add_theme_color_override("font_outline_color", Color(0.03, 0.07, 0.14, 0.95))
	reveal_title.modulate.a = 0.0
	ui.add_child(reveal_title)
	reveal_sub = Label.new()
	reveal_sub.set_anchors_preset(Control.PRESET_FULL_RECT)
	reveal_sub.anchor_top = 0.30
	reveal_sub.anchor_bottom = 0.37
	reveal_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reveal_sub.add_theme_font_size_override("font_size", 24)
	reveal_sub.add_theme_color_override("font_color", Style.CREAM)
	reveal_sub.add_theme_constant_override("outline_size", 12)
	reveal_sub.add_theme_color_override("font_outline_color", Color(0.03, 0.07, 0.14, 0.95))
	reveal_sub.modulate.a = 0.0
	ui.add_child(reveal_sub)
	guide = GuideScript.new()
	guide.game = self
	add_child(guide)
	guide.build(ui)
	_ignore_mouse(ui)
	for c in settings_ctrls:   # the pause card's sliders must take clicks (everything else lets them through to resume)
		c.mouse_filter = Control.MOUSE_FILTER_STOP

## Settings on the pause card: mouse sensitivity, volume, field of view, invert Y. Saved with the profile.
func _build_settings(parent: Node) -> void:
	var sv: Dictionary = GameState.meta.get("settings", {})
	var rows := [["Mouse", "sens", 0.0005, 0.006, float(sv.get("sens", 0.002))], ["Volume", "vol", 0.0, 1.0, float(sv.get("vol", 1.0))],
		["Field of view", "fov", 60.0, 100.0, float(sv.get("fov", BASE_FOV))]]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)
	for r in rows:
		var hb := HBoxContainer.new()
		box.add_child(hb)
		var l := _plain(hb, 17)
		l.text = r[0]
		l.custom_minimum_size = Vector2(130, 0)
		var sl := HSlider.new()
		sl.min_value = r[2]
		sl.max_value = r[3]
		sl.step = (r[3] - r[2]) / 100.0
		sl.value = r[4]
		sl.custom_minimum_size = Vector2(260, 22)
		sl.set_meta("key", r[1])
		sl.value_changed.connect(func(v: float): _set_setting(r[1], v))
		hb.add_child(sl)
		settings_ctrls.append(sl)
	var cb := CheckBox.new()
	cb.text = "Invert look (Y)"
	cb.button_pressed = bool(sv.get("inv", false))
	cb.toggled.connect(func(on: bool): _set_setting("inv", 1.0 if on else 0.0))
	box.add_child(cb)
	settings_ctrls.append(cb)
	var rb := Button.new()
	rb.text = "Resume"
	rb.pressed.connect(func(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	box.add_child(rb)
	settings_ctrls.append(rb)

func _set_setting(key: String, v: float) -> void:
	var sv: Dictionary = GameState.meta.get("settings", {})
	sv[key] = v
	GameState.meta["settings"] = sv
	_apply_settings()

func _apply_settings() -> void:
	var sv: Dictionary = GameState.meta.get("settings", {})
	var pl: Node = get_node_or_null("Player")
	if pl:
		pl.sensitivity = float(sv.get("sens", 0.002))
		pl.invert_y = float(sv.get("inv", 0.0)) > 0.5
	fov_base = float(sv.get("fov", BASE_FOV))
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(sv.get("vol", 1.0)), 0.0001)))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## One message line plus anything the Eye did while we were not looking.
func _say_notice(text: String) -> void:
	_say(text + ("\n" + quiet_notice if quiet_notice != "" else ""))
	quiet_notice = ""

func _cap() -> bool:
	return test_capture or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func _on_pause_changed() -> void:
	if kick_boot and sim_paused:
		kick_boot.position = BOOT_REST
	if not sim_paused:
		hold_block = true   # the press that resumed play is still down: it must not drill or work a table until released
	for tw in get_tree().get_processed_tweens():   # fish in flight must not land (and pay) while the lake is frozen
		if sim_paused:
			tw.pause()
		else:
			tw.play()
	if sim_paused:
		kick_charge = -1.0
		work_bar.visible = false
		prompt_label.text = ""
	_log("pause %s" % sim_paused)

func _banner(text: String, color := Color(1, 0.9, 0.4)) -> void:
	banner_label.text = text
	banner_label.modulate = color
	if banner_tween:
		banner_tween.kill()
	banner_tween = create_tween()
	banner_tween.tween_interval(2.2)
	banner_tween.tween_property(banner_label, "modulate:a", 0.0, 0.8)

# ---------- playtest log (user://playtest_log.txt) ----------
func _log(text: String) -> void:
	if GameState.save_slot.begins_with("test"):
		return
	var path := "user://playtest_log.txt"
	var f := FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) else FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line("[%6.0fs] coins=%d  %s" % [play_time, GameState.currency, text])

func _say(text: String) -> void:
	msg_label.text = text
	msg_time = 4.0

func _float_text(pos: Vector3, text: String, color := Color(1, 1, 1), px := 0.016) -> void:
	var l := _label3d(self, pos, text, px)
	l.modulate = color
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", pos.y + 2.0, 1.2)
	tw.tween_property(l, "modulate:a", 0.0, 1.2).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)

func capacity() -> int:
	var c: int = CAPACITIES[mini(GameState.level("bucket"), CAPACITIES.size() - 1)]
	if riding and GameState.level("snowmobile") >= 3:
		c += SLED_BONUS
	return c

func next_capacity() -> int: return CAPACITIES[mini(GameState.level("bucket") + 1, CAPACITIES.size() - 1)]
func lines() -> int: return 1 + GameState.level("lines")
func sale_mult() -> float:
	return (1.0 + 0.10 * GameState.level("market") + SECTOR_PERK * stats.sectors + 0.1 * perk_level("favour")
		+ TITHE_BONUS * stats.tithe + AWAKEN_BONUS * stats.awakened) * model.mod_info().value * depth_value()
func depth_value() -> float: return 1.0 + DEPTH_VALUE * _meta_int("lakes")
func rig_cap() -> int: return RIG_BASE_CAP + maxi(eye_stage() - 1, 0)
func tithe_cost() -> float: return ceil(TITHE_BASE * pow(TITHE_GROWTH, stats.tithe))
func bite_mult() -> float: return pow(0.88, GameState.level("bait"))
func ride_mult() -> float: return RIDE_SPEED[mini(GameState.level("snowmobile"), RIDE_SPEED.size() - 1)] if riding else 1.0
func walk_speed() -> float: return (6.0 + 1.6 * GameState.level("boots")) * ride_mult()
func work_speed() -> float: return 1.0 + 0.6 * GameState.level("drill")
func drill_time() -> float: return DRILL_BASE_TIME / work_speed()
func wait_time(t: Dictionary) -> float: return randf_range(2.0, 5.0) * bite_mult() * model.wait_factor(t.c)
func _auto_wait(t: Dictionary) -> float: return randf_range(AUTO_WAIT[0], AUTO_WAIT[1]) * bite_mult() * model.wait_factor(t.c)
func auto_cost() -> float: return ceil(AUTO_BASE * pow(AUTO_GROWTH, _count("auto")))
func smoker_cost() -> float: return ceil(90.0 * pow(1.5, _count("smoker")))
func table_cost() -> float: return ceil(60.0 * pow(1.5, _count("table")))
func free_space() -> int: return capacity() - carry.size()

func _count(state: String) -> int:
	var n := 0
	for t in holes:
		if t.state == state:
			n += 1
	return n

func carry_worth() -> float:
	var w := 0.0
	for f in carry:
		w += f.base * f.mult
	return w * sale_mult()

func roll_fish() -> Dictionary:
	var luck := 1.0 + 0.25 * GameState.level("luck")
	var total := 0.0
	for s in SPECIES:
		total += s.w * (luck if s.value >= 5.0 else 1.0)
	var r := randf() * total
	for s in SPECIES:
		r -= s.w * (luck if s.value >= 5.0 else 1.0)
		if r <= 0.0:
			return _make_fish(s)
	return _make_fish(SPECIES[0])

## cm range per species: purely cosmetic (shown on the catch card, kept as personal records)
const LENGTHS := {"Minnow": [6.0, 10.0], "Perch": [14.0, 28.0], "Silver Pike": [45.0, 90.0], "Golden Trout": [30.0, 55.0],
	"Old Boot": [27.0, 32.0], "Old Coin": [3.0, 4.0], "Glass Pearl": [2.0, 3.0], "Ancient Fish": [140.0, 220.0]}

func _make_fish(s: Dictionary) -> Dictionary:
	var r: Array = LENGTHS.get(s.name, [10.0, 20.0])
	var l := snappedf(lerpf(r[0], r[1], pow(randf(), 1.4)), 0.1)
	return {"name": s.name, "base": s.value, "color": s.color, "mult": 1.0, "gutted": false, "smoked": false,
		"len": l, "lenk": l / ((r[0] + r[1]) * 0.5)}

func _note_found(f: Dictionary) -> void:
	if not journal.has(f.name):
		_log("FOUND %s" % f.name)
		_banner("NEW DISCOVERY: %s  (%d coins)" % [f.name, _species_value(f.name)], f.color)
		if sfx:
			sfx.play("rare")
	journal[f.name] = journal.get(f.name, 0) + 1

func _species(n: String) -> Dictionary:
	for sp in SPECIES:
		if sp.name == n:
			return sp
	return SPECIES[0]

## Takes one fish out of the tile's finite stock. Returns {} if it's empty.
func _draw_fish(t: Dictionary) -> Dictionary:
	var n: String = model.draw(t.c)
	if n == "":
		return {}
	var f := _make_fish(_species(n))
	_note_found(f)
	return f

func _after_draw(t: Dictionary) -> void:
	var cell: Dictionary = tiles[t.c]
	_update_shadows(cell)
	if _emptied(cell) and not cell.announced:
		cell.announced = true
		_tile_emptied(cell, t)
	_update_sector_labels()

func _tile_emptied(cell: Dictionary, at: Dictionary) -> void:
	stats.tiles_cleared += 1
	_paint_tile(cell)
	_float_text(at.node.global_position + Vector3(0, 2.0, 0), "patch fished out!", Color(0.85, 0.95, 1.0))
	_burst(at.node.global_position + Vector3(0, 0.2, 0), Color(0.9, 0.97, 1.0), 12, 3.0, 0.8, 0.09)
	sfx.play("buy", 0.0, 1.3)
	if model.refresh_sector(cell.sector):
		_sector_cleared(cell.sector)
	_refresh()

func _sector_cleared(sid: Vector2i) -> void:
	var sec: Dictionary = model.sectors[sid]
	stats.sectors = model.cleared_count()
	var reward: int = SECTOR_REWARD[sec.ring]
	GameState.add(reward)
	_log("SECTOR CLEARED %s (%d/%d)" % [sec.name, stats.sectors, model.sectors.size()])
	sfx.play("goal")
	shake = maxf(shake, 0.08)
	_banner("SECTOR CLEARED: %s   +%d coins" % [sec.name, reward], Color(1.0, 0.88, 0.4))
	_say("Olga: %s is empty. The ice beyond it is open now. (%d / %d sectors)" % [sec.name, stats.sectors, model.sectors.size()])
	for tc in sec.tiles:
		_paint_tile(tiles[tc])
		_burst(tiles[tc].node.global_position + Vector3(0, 0.3, 0), Color(1.0, 0.85, 0.3), 10, 4.0, 1.0)
	for nb in model.neighbors(sid):
		for tc in model.sectors[nb].tiles:
			_paint_tile(tiles[tc])
	if model.cleared_count() >= model.sectors.size():
		_ending()

func _ending() -> void:
	if stats.ended > 0:
		return
	stats.ended = 1
	stats.ended_time = play_time
	_log("ENDING reached in %s" % _clock(play_time))
	var best := float(GameState.meta.get("best_time", 0.0))
	ending_label.text = "THE LAKE IS EMPTY\n\nEvery last fish is gone.\nBeneath the ice, something opens its eye...\n\nCleared in %s%s\n\nPress R to refreeze the lake:  +%d pearls" % [
		_clock(play_time), ("   (best %s)" % _clock(best)) if best > 0.0 else "", pearls_pending()]
	ending_panel.visible = true
	ending_panel.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(20.0)
	tw.tween_property(ending_panel, "modulate:a", 0.0, 2.0)
	tw.tween_callback(func(): ending_panel.visible = false)
	day_t = 0.5
	shake = 0.12
	sfx.play("rare")

func _species_value(n: String) -> float:
	for sp in SPECIES:
		if sp.name == n:
			return sp.value
	return 1.0

# ---------- goals ----------
func _stat(key: String) -> float:
	if key.begins_with("lvl:"):
		return GameState.level(key.substr(4))
	if key.begins_with("found:"):
		return 1.0 if journal.has(key.substr(6)) else 0.0
	if key == "journal":
		return journal.size()
	if key == "eye_stage":
		return eye_stage()
	return stats.get(key, 0.0)

func _check_goals() -> void:
	if order.is_empty() and goal_done[2]:
		_new_order()
	elif order.get("type", "") == "species" and model.species_left(order.species) + _species_held(order.species) < order.need - order.have:
		_new_order()  # the lake ran out of that species: don't leave an impossible order
	for i in GOALS.size():
		if goal_done[i]:
			continue
		var g: Dictionary = GOALS[i]
		if _stat(g.stat) >= g.target:
			goal_done[i] = true
			GameState.add(g.reward)
			for u in g.get("unlock", []):
				unlocked[u] = true
			_log("GOAL: %s" % g.text)
			sfx.play("goal")
			shake = maxf(shake, 0.04)
			_banner("GOAL COMPLETE: %s  +%d" % [g.text, g.reward], Color(1, 0.9, 0.4))
			_say("GOAL DONE: %s  (+%d coins)\n%s" % [g.text, g.reward, g.line])

func _goals_text() -> String:
	var lines_out := []
	var shown := 0
	for pass_opt in [false, true]:  # main-line goals first; optional side goals only fill the gaps
		for i in GOALS.size():
			if goal_done[i] or shown >= 3 or bool(GOALS[i].get("opt", false)) != pass_opt:
				continue
			var g: Dictionary = GOALS[i]
			var cur := mini(int(_stat(g.stat)), int(g.target))
			lines_out.append("%s  (%d/%d)" % [g.text, cur, int(g.target)])
			shown += 1
	if shown == 0:
		lines_out.append("All goals complete!")
	return "\n".join(lines_out)

## 0..1 progress from the last Eye stage threshold toward the next one.
func _eye_progress() -> float:
	var st := eye_stage()
	if st >= EYE_STAGES.size():
		return 1.0
	var lo: int = eye_stage_at(st - 1) if st > 0 else 0
	var hi: int = eye_stage_at(st)
	return clampf(float(stats.eye_fed - lo) / maxf(1.0, float(hi - lo)), 0.0, 1.0)

func _done_count() -> int:
	var n := 0
	for d in goal_done:
		if d:
			n += 1
	return n

# ---------- refresh ----------
func _tool_unlocked(i: int) -> bool:
	return TOOL_UNLOCK[i] == "" or unlocked.get(TOOL_UNLOCK[i], false)

func _upgrade_desc(id: String) -> String:
	if id == "bucket":
		return "carry %d at a time" % next_capacity()
	return UPGRADES[id].desc

func _refresh() -> void:
	_check_goals()
	coins_label.text = "%d" % floor(GameState.currency)
	carry_label.text = "Bucket %d / %d   worth %d%s" % [carry.size(), capacity(), floor(carry_worth()), ("   |   %d on the ice" % yard.count()) if yard.count() > 0 else ""]
	carry_bar.value = float(carry.size()) / maxf(1.0, float(capacity()))
	eye_label.text = "The Eye   stage %d / %d   %d fed" % [eye_stage(), EYE_STAGES.size(), stats.eye_fed]
	eye_bar.value = _eye_progress()
	var est := eye_stage()
	eye_next_label.text = ("Next: %s" % EYE_BOONS[est]) if est < EYE_STAGES.size() else "The Eye is awake.  Tithe Lv %d" % stats.tithe
	lake_label.text = "%d fish left  -  %d / %d sectors\n%s #%d  -  %d pearls  -  [R] refreeze" % [model.total_left(),
		model.cleared_count(), model.sectors.size(), model.mod_info().name, _meta_int("lakes") + 1, _meta_int("pearls")]
	combo_label.text = ("Combo x%d  (+%d%%)" % [combo, mini(combo - 1, 10) * 10]) if combo > 1 else ""
	goals_label.text = _goals_text() + ("\n\n" + _order_text() if not order.is_empty() else "")
	for id in UPGRADES:
		var u: Dictionary = UPGRADES[id]
		if not unlocked[id]:
			sign_labels[id].text = "???\ncomplete goals to unlock"
			continue
		var lvl := GameState.level(id)
		var cost_text := "%d coins" % GameState.cost(id, u.base, u.growth)
		if lvl >= u.max:
			cost_text = "MAX"
		sign_labels[id].text = "%s  Lv%d\n%s\n%s" % [u.name, lvl, _upgrade_desc(id), cost_text]
	for i in TOOLS.size():
		var label: String = TOOLS[i] if _tool_unlocked(i) else "???"
		if _tool_unlocked(i) and i == 0: label = DRILL_NAMES[mini(GameState.level("drill"), DRILL_NAMES.size() - 1)]
		if _tool_unlocked(i) and i == 1: label = ROD_NAMES[mini(GameState.level("lines"), ROD_NAMES.size() - 1)]
		var suffix := ""
		if _tool_unlocked(i):
			if i == 2: suffix = "\n%d" % auto_cost()
			if i == 3: suffix = "\n%d" % smoker_cost()
			if i == 4: suffix = "\n%d" % table_cost()
			if i == 5: suffix = "\n12+"
			if i == 6: suffix = "\n%s %d" % [BUILD_ITEMS[build_item], _build_cost(build_item)]
		hotbar[i].text = "%d  %s%s" % [i + 1, label, suffix]
		hotbar[i].add_theme_color_override("font_color", Style.AMBER if i == tool else (Style.CREAM if _tool_unlocked(i) else Style.MUTED))
		hotbar_panels[i].add_theme_stylebox_override("panel", Style.slot(i == tool, not _tool_unlocked(i)))
		hotbar_icons[i].lit = _tool_unlocked(i)
		hotbar_icons[i].active = i == tool
		hotbar_icons[i].queue_redraw()
	if scenery:
		scenery.set_eye_glow(float(model.cleared_count()) / model.sectors.size() * 1.4)
		scenery.set_eye_open(minf(eye_open_frac(), 0.8) if awaken_hold else eye_open_frac())
		scenery.set_eye_stage(eye_seen_stage - 1 if awaken_hold else eye_seen_stage)
		scenery.set_crane(GameState.level("conveyor") >= 2)
	if journal_panel.visible:
		_update_journal()
	map_ctrl.queue_redraw()
	_sync_tool_view()

func _update_journal() -> void:
	journal_label.text = "FIELD JOURNAL    %d / %d found" % [journal.size(), SPECIES.size()]
	journal_label.add_theme_color_override("font_color", Style.AMBER)
	for c in journal_grid.get_children():
		c.queue_free()
	for h in ["", "Species", "Caught", "Best", "Base"]:
		var hl := _plain(journal_grid, 14, Style.MUTED)
		hl.text = h
	for sp in SPECIES:
		var found := journal.has(sp.name)
		var sw := _dot(journal_grid, sp.color if found else Color(0.3, 0.33, 0.45), 16)
		sw.custom_minimum_size = Vector2(16, 16)
		var rar: Array = _rarity(sp.name)
		var nl := _plain(journal_grid, 19, rar[1] if found else Style.MUTED)
		nl.text = sp.name if found else "???"
		var cl := _plain(journal_grid, 18, Style.CREAM if found else Style.MUTED)
		cl.text = "x%d" % journal[sp.name] if found else ""
		var bl := _plain(journal_grid, 18, Style.CREAM if found else Style.MUTED)
		bl.text = "%.1f cm" % records.get(sp.name, 0.0) if found else ""
		var vl := _plain(journal_grid, 18, Style.AMBER if found else Style.MUTED)
		vl.text = "%d" % sp.value if found else ""
	var foot := _plain(journal_grid, 14, Style.MUTED)
	foot.text = ""

func _refresh_view() -> void:
	for c in view.get_children():
		c.queue_free()
	if capacity() > 1:
		var bucket := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.17
		cm.bottom_radius = 0.12
		cm.height = 0.28
		bucket.mesh = cm
		bucket.material_override = _mat(Color(0.55, 0.38, 0.22))
		view.add_child(bucket)
		var n := mini(carry.size(), 10)
		for i in n:
			var f := _fish_mesh(carry[i], view, 0.8)
			(f as FishNode).amp = 0.3
			f.position = Vector3(randf_range(-0.07, 0.07), 0.15 + 0.02 * i, randf_range(-0.07, 0.07))
			f.rotation = Vector3(randf_range(-0.4, 0.4), randf() * TAU, randf_range(-0.4, 0.4))
	elif carry.size() == 1:
		var f := _fish_mesh(carry[0], view, 1.2)
		(f as FishNode).amp = 0.9
		f.rotation = Vector3(0.3, 0.6, 0.2)
	view.rotation = Vector3(0.1, 0.3, 0.0)

func _add_carry(f: Dictionary) -> void:
	carry.append(f)

# ---------- tools in hand ----------
func _sync_tool_view() -> void:
	var sig := "%d-%d-%d" % [tool, GameState.level("drill"), GameState.level("lines")]
	if sig == tool_sig:
		return
	if tool_sig != "":   # not on the first build: the old tool drops away, the new one swings up
		tool_swap = 1.0
		sfx.play("tick", -8.0, 0.8 + 0.06 * tool)
	tool_sig = sig
	for c in tool_view.get_children():
		c.queue_free()
	tool_body = Node3D.new()
	tool_view.add_child(tool_body)
	tool_spin = null
	tool_line = null
	tool_tip = null
	match tool:
		0:  # auger: spins while you hold click
			var tier := mini(GameState.level("drill"), TIER_COLORS.size() - 1)
			tool_base_x = deg_to_rad(-22)
			var parts: Dictionary = ToolModels.auger(tool_body, TIER_COLORS[tier], tier)
			tool_spin = parts.spin
		1:  # rod, its line shows while a cast is active
			var tier := mini(GameState.level("lines"), TIER_COLORS.size() - 1)
			tool_base_x = deg_to_rad(30)
			var parts: Dictionary = ToolModels.rod(tool_body, TIER_COLORS[tier], tier)
			tool_tip = parts.tip
		_:  # the builder's kit: the accent says what you are placing
			tool_base_x = deg_to_rad(-10)
			var accents := [Color(1.0, 0.78, 0.35), Color(0.95, 0.5, 0.2), Color(0.55, 0.9, 0.95), Color(0.3, 0.75, 0.85), Color(1.0, 0.9, 0.6)]
			ToolModels.builder(tool_body, accents[clampi(tool - 2, 0, accents.size() - 1)])
	tool_body.rotation.x = tool_base_x

## First-person snowmobile: hood, windshield, handlebars and gloves at the bottom of the screen.
func _build_ride_view() -> void:
	ride_view = Node3D.new()
	cam.add_child(ride_view)
	ride_view.visible = false
	var orange := Color(0.95, 0.5, 0.12)
	var dark := Color(0.12, 0.12, 0.16)
	_box(ride_view, Vector3(0, -0.74, -1.25), Vector3(0.82, 0.2, 1.5), orange)      # hood, low in frame
	_box(ride_view, Vector3(0, -0.66, -2.05), Vector3(0.42, 0.14, 0.5), dark)
	_box(ride_view, Vector3(0, -0.66, -2.31), Vector3(0.22, 0.08, 0.04), Color(1.0, 0.92, 0.65), "", 3.0)
	_box(ride_view, Vector3(0, -0.5, -0.78), Vector3(0.84, 0.03, 0.03), dark)       # handlebar
	for sx in [-0.42, 0.42]:
		_box(ride_view, Vector3(sx, -0.52, -0.78), Vector3(0.08, 0.08, 0.12), Color(0.4, 0.28, 0.2))
		_box(ride_view, Vector3(sx * 1.15, -0.62, -0.7), Vector3(0.13, 0.1, 0.18), Color(0.45, 0.3, 0.22))
		_box(ride_view, Vector3(sx * 1.3, -0.72, -0.9), Vector3(0.05, 0.22, 0.06), dark)   # mirror stalk

func _toggle_ride() -> void:
	if GameState.level("snowmobile") < 1:
		_say("Buy a Snowmobile at its stall first.")
		sfx.play("deny")
		return
	riding = not riding
	ride_view.visible = riding
	stats.rides += 1
	_say("Snowmobile on. WASD to drive. V to hop off." if riding else "Hopped off.")
	sfx.play("buy", 0.0, 0.7)
	_refresh()

func _kick_tool(amount: float) -> void:
	tool_kick = amount

func _burst(pos: Vector3, color: Color, count := 10, speed := 3.0, life := 0.7, size := 0.06) -> void:
	var pt := CPUParticles3D.new()
	pt.one_shot = true
	pt.amount = count
	pt.lifetime = life
	pt.explosiveness = 1.0
	pt.direction = Vector3.UP
	pt.spread = 70.0
	pt.initial_velocity_min = speed * 0.5
	pt.initial_velocity_max = speed
	pt.gravity = Vector3(0, -9.0, 0)
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * size
	pt.mesh = bm
	pt.material_override = _mat(color, 0.6)
	add_child(pt)
	pt.global_position = pos
	pt.emitting = true
	get_tree().create_timer(life + 0.4).timeout.connect(pt.queue_free)

# ---------- orders (Olga's repeatable requests) ----------
func _species_held(sp: String) -> int:
	var n := 0
	for f in carry:
		if f.name == sp:
			n += 1
	for t in holes:
		for f in t.stash:
			if f.name == sp:
				n += 1
		if t.state == "hole" and t.cast == 3:
			for f in t.hooked:
				if f.name == sp:
					n += 1
	for e in yard.fish:   # fish on the ice, in the air toward the Eye, or riding a belt are out of the lake but not yet delivered
		if e.f.name == sp:
			n += 1
	for rec in flying:
		if rec.f.name == sp:
			n += 1
	for it in belt_fish:
		if it.f.name == sp:
			n += 1
	return n

## Orders must stay finishable in a finite lake: only ask for species that are still out there.
func _new_order() -> void:
	var sp_pool := []
	var wanted := ["Minnow", "Perch"]
	if orders_done >= 2: wanted.append("Silver Pike")
	if orders_done >= 6: wanted.append("Golden Trout")
	for sp in wanted:
		if model.species_left(sp) + _species_held(sp) >= 4:
			sp_pool.append(sp)
	var kinds := ["any"]
	if not sp_pool.is_empty():
		kinds.append_array(["species", "species"])
	if unlocked.get("t_table", false): kinds.append("gutted")
	if unlocked.get("t_smoker", false): kinds.append("smoked")
	var kind: String = kinds.pick_random()
	var o := {"type": kind, "have": 0, "species": ""}
	var unit := 2.0
	var step := int(orders_done / 2.0)
	match kind:
		"species":
			o.species = sp_pool.pick_random()
			unit = _species_value(o.species)
			o.need = maxi(2, 3 + step - (2 if unit >= 5.0 else 0))
		"any":
			o.need = 6 + orders_done * 2
		"gutted":
			unit = 3.0
			o.need = 3 + step
		"smoked":
			unit = 7.0
			o.need = 3 + step
	var avail: int = model.total_left() + carry.size()
	if avail < 3:
		order = {}  # nothing worth asking for; the lake is practically empty
		return
	o.need = mini(o.need, avail)
	if o.type == "species":
		o.need = mini(o.need, model.species_left(o.species) + _species_held(o.species))
	o.reward = int(ceil((o.need * unit * 2.2 + 8.0) * (1.0 + 0.1 * orders_done)))
	order = o

func _order_text() -> String:
	var what := "fish"
	match order.type:
		"species": what = order.species
		"gutted": what = "gutted fish"
		"smoked": what = "smoked fish"
	return "ORDER: deliver %d / %d %s  (+%d)" % [order.have, order.need, what, order.reward]

func _order_progress(f: Dictionary) -> void:
	if order.is_empty():
		return
	var ok := false
	match order.type:
		"species": ok = f.name == order.species
		"any": ok = true
		"gutted": ok = f.gutted
		"smoked": ok = f.smoked
	if not ok:
		return
	order.have += 1
	if order.have >= order.need:
		GameState.add(order.reward)
		orders_done += 1
		_log("ORDER done #%d" % orders_done)
		_banner("ORDER COMPLETE!  +%d coins" % order.reward, Color(0.5, 1.0, 0.7))
		sfx.play("goal")
		shake = maxf(shake, 0.04)
		_burst(hut_pos + Vector3(0, 0.5, 0), Color(1, 0.85, 0.3), 24, 5.0, 1.0)
		_new_order()
	_refresh()

func _process(delta: float) -> void:
	tithe_armed_t = maxf(tithe_armed_t - delta, 0.0)
	reset_armed_t = maxf(reset_armed_t - delta, 0.0)
	var cap_now := _cap()
	if cap_now:
		ever_captured = true
	# Esc frees the mouse and really pauses: no bites expire, no machines run, no timers tick (cutscenes play on)
	var want_pause := ever_captured and not cap_now and not guide.intro_active
	if want_pause != sim_paused:
		sim_paused = want_pause
		_on_pause_changed()
	if sim_paused:
		start_panel.visible = true
		if msg_time > 0.0:
			msg_time -= delta
			if msg_time <= 0.0:
				msg_label.text = ""
		return
	if msg_time > 0.0:
		msg_time -= delta
		if msg_time <= 0.0:
			msg_label.text = ""
	if feed_streak_t > 0.0:
		feed_streak_t -= delta
		if feed_streak_t <= 0.0:
			feed_streak = 0
	if feed_streak_t < 0.45:
		streak_label.modulate.a = clampf(feed_streak_t / 0.45, 0.0, 1.0)
	if combo_t > 0.0:
		combo_t -= delta
		if combo_t <= 0.0:
			combo = 0
			_refresh()
	for t in holes:
		_tick_hole(t, delta)
	_tick_rigs(delta)
	_update_belt_fish(delta)
	eye_burst_t -= delta
	eye_pending_t -= delta
	if eye_pending > 0.0 and eye_pending_t <= 0.0:
		_float_text(Vector3(0, 6.0, 0), "+%s" % _coins(eye_pending), Color(0.6, 1.0, 0.9), 0.034)
		eye_pending = 0.0
		eye_pending_t = 0.7
	var captured := _cap()
	start_panel.visible = not captured
	_walk(delta)
	var raw := _aim_raw()
	var a := raw if _in_range(raw) else ""
	if not captured:
		prompt_label.text = ""
	elif raw != "" and a == "":
		prompt_label.text = "" if raw == "ice" else "Too far - walk closer"
	else:
		prompt_label.text = _prompt_for(a)
	_tick_yard(delta, captured)
	if captured and a == "" and yard.near($Player.global_position, PICKUP_RADIUS + 1.0) > 0 and not guide.intro_active:
		prompt_label.text = _yard_hint()
	guide.tick(delta, captured)
	if guide.intro_active:
		prompt_label.text = ""
		msg_label.text = ""
		_animate(delta)
		return
	var pp3: Vector3 = $Player.global_position
	scenery.set_eye_offering(captured and not carry.is_empty() and Vector2(pp3.x, pp3.z).length() - EYE_R <= RANGE_EYE + 4.0, pp3)
	_update_hold(a, delta)
	if kick_charge >= 0.0:
		work_bar.visible = true
		work_bar.value = kick_charge
	_update_crosshair(a, captured)
	view.position.y = -0.4 + sin(Time.get_ticks_msec() * 0.002) * 0.005
	_animate(delta)

func _animate(delta: float) -> void:
	var tm := Time.get_ticks_msec() * 0.001
	play_time += delta
	day_t = fmod(day_t + delta / DAY_LENGTH, 1.0)
	sky_t -= delta
	if sky_t <= 0.0:  # re-lighting the sky every frame is wasteful; 5x a second is plenty
		sky_t = 0.2
		scenery.set_time(day_t)
	shake = move_toward(shake, 0.0, delta * 0.25)
	cam.h_offset = randf_range(-1.0, 1.0) * shake
	cam.v_offset = randf_range(-1.0, 1.0) * shake
	# walking: a soft head bob, the tool sways with it, and each footfall kicks up a pinch of snow
	if moving and not riding and not guide.intro_active:
		var prev_phase := sin(bob_t)
		bob_t += delta * 9.5
		cam.v_offset += sin(bob_t * 2.0) * 0.006
		cam.h_offset += sin(bob_t) * 0.004
		if prev_phase > 0.0 and sin(bob_t) <= 0.0:
			var pw: Vector3 = $Player.global_position
			_snow_fx(Vector3(pw.x, 0.03, pw.z) + (-$Player.global_basis.z) * 0.2, 2, 0.35)
			sfx.play("step", -8.0, randf_range(0.8, 1.2))
	else:
		bob_t = lerpf(bob_t, round(bob_t / PI) * PI, minf(1.0, delta * 8.0))
	fov_kick = lerpf(fov_kick, 0.0, delta * 6.0)
	ride_fov = lerpf(ride_fov, 8.0 if (riding and moving) else 0.0, delta * 3.0)
	if reveal_t > 0.0:
		reveal_t -= delta
		var rk := 1.0 - reveal_t / reveal_total
		reveal_fov = 13.0 * sin(clampf(rk * 2.4, 0.0, 1.0) * PI)
		var pl: Node3D = $Player
		var off := Vector2(pl.global_position.x, pl.global_position.z)
		if rk < 0.6 and not riding and off.length() > 3.0:  # turn toward the Eye (briefly, gently)
			pl.rotation.y = lerp_angle(pl.rotation.y, atan2(off.x, off.y), minf(1.0, delta * 2.4))
			cam.rotation.x = lerpf(cam.rotation.x, deg_to_rad(-12.0), minf(1.0, delta * 2.0))
	else:
		reveal_fov = 0.0
	cam.fov = fov_base + fov_kick + ride_fov + reveal_fov + cine_fov
	tool_kick = move_toward(tool_kick, 0.0, delta * 3.0)
	var any_cast := false
	for h in holes:
		if h.state == "hole" and h.cast > 0:
			any_cast = true
			break
	tool_swap = move_toward(tool_swap, 0.0, delta * 3.2)
	var swap_drop := pow(tool_swap, 2.0) * 0.45   # eases back up: quick drop, soft arrival
	tool_view.position = Vector3(0.38 + sin(tm * 1.3) * 0.004, -0.36 + sin(tm * 2.1) * 0.004 - swap_drop, -0.65)
	tool_view.rotation.x = swap_drop * 1.1
	if moving and not riding:
		tool_view.position += Vector3(sin(bob_t) * 0.012, absf(sin(bob_t)) * -0.012, 0.0)
	if working and tool == 0:
		tool_view.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.004
	var fight_target := 0.0
	for h in holes:
		if h.state == "hole" and h.cast == 3:
			fight_target = maxf(fight_target, h.fight_i)
	fight_amt = lerpf(fight_amt, fight_target, minf(1.0, delta * 12.0))
	view_pop = move_toward(view_pop, 0.0, delta * 3.5)
	view.scale = Vector3.ONE * (1.0 + 0.4 * sin(view_pop * PI))
	_update_fishing_lines()
	if tool_body:
		tool_body.rotation.x = tool_base_x + tool_kick * 0.6 + fight_amt * (0.12 + 0.1 * sin(Time.get_ticks_msec() * 0.035))
		tool_body.rotation.z = fight_amt * 0.05 * sin(Time.get_ticks_msec() * 0.027)
	if tool_spin and working and tool == 0:
		tool_spin.rotation.z += 16.0 * delta
	working = false
	var pp: Vector3 = $Player.global_position
	scenery.follow(pp)
	scenery.set_eye_look(Vector2(pp.x, pp.z), delta)
	for c in tiles:
		var t: Dictionary = tiles[c]
		if t.shadows.is_empty():
			continue
		var wp: Vector3 = t.node.global_position
		if absf(wp.x - pp.x) > 55.0 or absf(wp.z - pp.z) > 55.0:
			continue
		for sh in t.shadows:
			if not sh.node.visible:
				continue
			var ang: float = sh.a + tm * sh.spd
			sh.node.position = Vector3(cos(ang) * sh.r, 0.065, sin(ang * 1.7) * sh.r * 0.8)
			sh.node.rotation.y = -ang + PI * 0.5
	for id in sector_labels:
		var sp: Vector3 = sector_labels[id].pos
		var dist := Vector2(sp.x - pp.x, sp.z - pp.z).length()
		var lim: float = 62.0 if model.sectors[id].unlocked else 26.0
		var lab: Label3D = sector_labels[id].label
		lab.visible = reveal_t <= 0.0 and not guide.intro_active and dist < lim
		lab.modulate.a = (0.6 if not model.sectors[id].unlocked else 1.0) * (1.0 - smoothstep(lim * 0.55, lim, dist))

# ---------- fish on the ice ----------
func no_kicks_yet() -> bool:
	return kicks == 0

var snow_fx_budget := 0

## A throttled puff of powder snow (many fish can slide at once; only a few puffs per frame).
## Picked-up fish hop from where they lay into your hand.
func _fly_to_hand(fs: Array) -> void:
	for i in fs.size():
		var from: Vector3 = pickup_from[i] if i < pickup_from.size() else $Player.global_position
		var holder := Node3D.new()
		add_child(holder)
		var fm := _fish_mesh(fs[i], holder, 1.7)
		(fm as FishNode).amp = 2.0
		holder.global_position = from
		var tw := create_tween()
		tw.tween_interval(0.05 * i)
		tw.tween_method(func(k: float):
			var tgt := _hand_point()
			holder.global_position = from.lerp(tgt, k) + Vector3(0, sin(k * PI) * 0.8, 0)
			holder.rotation.z = k * 5.0
			holder.scale = Vector3.ONE * lerpf(1.0, 0.4, k), 0.0, 1.0, 0.3).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(holder.queue_free)
	pickup_from.clear()

## A new thing on the ice grows in with a little overshoot, so building feels like something happened.
func _pop_in(n: Node3D) -> void:
	if restoring or n == null:
		return
	var target := n.scale
	n.scale = target * 0.25
	var tw := n.create_tween()
	tw.tween_property(n, "scale", target * 1.08, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "scale", target, 0.14).set_trans(Tween.TRANS_SINE)
	_snow_fx(n.global_position + Vector3(0, 0.1, 0), 9, 1.2)

func _snow_fx(pos: Vector3, amount: int, power: float) -> void:
	if snow_fx_budget <= 0:
		return
	snow_fx_budget -= 1
	FishingFX.snow_puff(self, pos, amount, power)

func _kick_max() -> float:
	return KICK_BASE_MAX + 3.0 * GameState.level("kick")

func _yard_hint() -> String:
	var pl: Node3D = $Player
	var fwd := -pl.global_basis.z
	fwd.y = 0.0
	var n := yard.targets(pl.global_position, fwd.normalized(), KICK_REACH).size()
	return ("Kick: %d fish ahead   " % n if n > 0 else "") + "Right mouse / F: kick (hold = harder)   E: pick up   or walk into them"

func _tick_yard(delta: float, captured: bool) -> void:
	var pl: Node3D = $Player
	var ppos := pl.global_position
	yard.player_speed = Vector2(ppos.x - player_prev.x, ppos.z - player_prev.z).length() / maxf(delta, 0.0001) if player_prev != Vector3.ZERO else 0.0
	yard.player_speed = minf(yard.player_speed, 14.0)
	yard.player_vel = Vector3(ppos.x - player_prev.x, 0.0, ppos.z - player_prev.z) / maxf(delta, 0.0001) if player_prev != Vector3.ZERO else Vector3.ZERO
	player_prev = ppos
	snow_fx_budget = 5
	slide_snd_t -= delta
	yard.pull = 3.8 + 0.9 * eye_stage()
	yard.step(delta, ppos)
	_update_kick_rings(captured)
	if kick_charge >= 0.0:
		if captured and not guide.intro_active:
			kick_charge = minf(kick_charge + delta / KICK_CHARGE_TIME, 1.0)
			tool_kick = -0.35 * kick_charge
		else:
			kick_charge = -1.0

func _boot_move(pos: Vector3, rot: Vector3, dur: float) -> void:
	if boot_tween:
		boot_tween.kill()
	boot_tween = create_tween().set_parallel(true)
	boot_tween.tween_property(kick_boot, "position", pos, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	boot_tween.tween_property(kick_boot, "rotation_degrees", rot, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## The kick: the boot whips forward and up through the snow, then drops back out of sight.
func _boot_swing(power: float) -> void:
	if boot_tween:
		boot_tween.kill()
	var reach := 0.55 + 0.25 * clampf(power / _kick_max(), 0.0, 1.0)
	boot_tween = create_tween()
	boot_tween.tween_property(kick_boot, "position", Vector3(0.12, -0.22, -reach), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	boot_tween.parallel().tween_property(kick_boot, "rotation_degrees", Vector3(32, 30, 4), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	boot_tween.tween_interval(0.07)
	boot_tween.tween_property(kick_boot, "position", BOOT_REST, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	boot_tween.parallel().tween_property(kick_boot, "rotation_degrees", BOOT_ROT, 0.28)

## An amber ring on the ice under every fish a kick would hit right now (brighter while you charge).
func _update_kick_rings(captured: bool) -> void:
	var want: Array = []
	if captured and yard.count() > 0 and not guide.intro_active:
		var pl: Node3D = $Player
		var fwd := -pl.global_basis.z
		fwd.y = 0.0
		want = yard.targets(pl.global_position, fwd.normalized(), KICK_REACH)
	while kick_rings.size() < mini(want.size(), 8):
		var m := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.7
		tm.outer_radius = 0.76
		tm.rings = 24
		tm.ring_segments = 6
		m.mesh = tm
		var mt := StandardMaterial3D.new()
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mt.albedo_color = Color(1.0, 0.62, 0.1, 1.0)   # the old pale rings were fog washing them out, not the colour
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mt.disable_fog = true
		mt.render_priority = 2
		m.material_override = mt
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		kick_rings.append(m)
	var pulse := 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.012)
	for i in kick_rings.size():
		var ring: MeshInstance3D = kick_rings[i]
		ring.visible = i < want.size()
		if ring.visible:
			ring.global_position = Vector3(want[i].pos.x, 0.03, want[i].pos.z)
			ring.scale = Vector3.ONE * (want[i].r / 0.5) * 0.85 * (1.0 + 0.25 * maxf(kick_charge, 0.0)) * pulse
			(ring.material_override as StandardMaterial3D).albedo_color.a = 0.85 + 0.15 * maxf(kick_charge, 0.0)

func _update_crosshair(a: String, captured: bool) -> void:
	var kind := 0
	if captured and not guide.intro_active:
		if a == "eye":
			kind = 2
		elif a.begins_with("hole:") or a.begins_with("buy:") or a == "olga" or a.begins_with("depot:") or a.begins_with("rig:"):
			kind = 1
		elif a == "ice" and tool == 0 and _can_drill_at(Vector3(aim_pos.x, 0.0, aim_pos.z)):
			kind = 1
		if kind == 0 and yard.count() > 0:
			var pl: Node3D = $Player
			var fwd := -pl.global_basis.z
			fwd.y = 0.0
			if not yard.targets(pl.global_position, fwd.normalized(), KICK_REACH).is_empty():
				kind = 3
	crosshair.kind = kind
	crosshair.progress = work_bar.value if work_bar.visible else -1.0

func _start_kick() -> void:
	kick_charge = 0.0
	_boot_move(Vector3(0.28, -0.34, -0.3), Vector3(-18, 38, 6), 0.35)   # the foot draws back

## Release the right mouse button: everything in front of your boots flies off the way you are facing.
func _release_kick() -> void:
	if kick_charge < 0.0:
		return
	var power := lerpf(KICK_MIN, _kick_max(), kick_charge)
	kick_charge = -1.0
	var pl: Node3D = $Player
	var fwd := -pl.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var hit := yard.kick(pl.global_position, fwd, power, KICK_REACH)
	_kick_tool(1.4)
	_boot_swing(power)
	view_pop = 0.5
	if hit > 0:
		kicks += 1
		sfx.play("kick", -2.0, 0.85 + power * 0.015)
		shake = maxf(shake, 0.01 + 0.002 * power)
		fov_kick = maxf(fov_kick, 2.0)
	else:
		sfx.play("tick", -8.0, 0.6)

## E: scoop the loose fish around your feet into your bucket (as many as it holds).
func _pick_up_fish() -> void:
	var pp: Vector3 = $Player.global_position
	if yard.near(pp, PICKUP_RADIUS) == 0:
		_say("No fish within reach.")
		return
	if free_space() <= 0:
		_say("Your bucket is full - feed the Eye (click it) or buy a bigger bucket.")
		sfx.play("deny")
		return
	var got := yard.collect(pp, PICKUP_RADIUS, free_space())
	pickup_from = yard.last_collected.duplicate()
	for f in got:
		_add_carry(f)
	_fly_to_hand(got)
	sfx.play("plop", -2.0, 1.4)
	view_pop = 1.0
	_refresh_view()
	_refresh()

## More than MAX_LOOSE fish on the ice: the oldest is taken for half pay, no streak, and fades where it lay.
func _on_fish_overflow(f: Dictionary, holder: Node3D, _pos: Vector3) -> void:
	_settle_fish(f, EYE_MULT * 0.5, false)   # (a live stage-up gets its full reveal below)
	var tw := create_tween()
	tw.tween_property(holder, "scale", Vector3.ONE * 0.05, 0.6)
	tw.tween_callback(holder.queue_free)
	var st := eye_stage()
	if st > eye_seen_stage:
		eye_seen_stage = st
		_eye_stage_up(st)
	_refresh()

## A loose fish crossed into the pupil: the Eye eats it (pays now) and it spirals down the funnel.
func _on_fish_swallowed(f: Dictionary, holder: Node3D, pos: Vector3) -> void:
	if combo > 0:
		combo_t = COMBO_WINDOW   # pushing a catch home keeps the combo alive
	_feed_eye(f, EYE_MULT, true)
	var tw := create_tween()
	_spiral_into_eye(tw, holder, [pos, pos], 0.5)
	tw.tween_callback(holder.queue_free)

func _walk(delta: float) -> void:
	if guide.intro_active:
		moving = false
		return
	var d := Vector3(int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A)), 0,
		int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W)))
	moving = d != Vector3.ZERO and _cap()
	if not moving:
		return
	var p: Node3D = $Player
	var pos := p.global_position + p.global_basis * d.normalized() * walk_speed() * delta
	var flat := Vector2(pos.x, pos.z)
	if flat.length() > WALK_LIMIT:
		flat = flat.normalized() * WALK_LIMIT
	for o in scenery.obstacles:  # walls, stalls, stones: slide around them
		var off := flat - Vector2(o.x, o.y)
		if off.length() < o.z:
			flat = Vector2(o.x, o.y) + (off.normalized() if off.length() > 0.01 else Vector2.RIGHT) * o.z
	p.global_position = Vector3(flat.x, p.global_position.y, flat.y)

func _tick_hole(t: Dictionary, delta: float) -> void:
	match t.state:
		"hole":
			_tick_cast(t, delta)
		"auto":
			var working_rod: bool = model.tile_left(t.c) > 0
			if working_rod:
				t.auto_t -= delta
				if t.auto_t <= 0.0:
					if t.belt != null:
						var f := _draw_fish(t)
						if not f.is_empty():
							_belt_spawn(t, f)
							_after_draw(t)
						t.auto_t = _auto_wait(t)
					elif t.stash.size() < STASH_MAX:
						var f2 := _draw_fish(t)
						if not f2.is_empty():
							t.stash.append(f2)
							_after_draw(t)
						t.auto_t = _auto_wait(t)
					else:
						t.auto_t = 1.0
				t.arm.rotation.z = sin(Time.get_ticks_msec() * 0.004 + t.idx * 1.7) * 0.35
			if not working_rod and t.stash.is_empty():
				t.tag.text = "empty - click to move"
			elif t.belt != null:
				t.tag.text = ""
			else:
				t.tag.text = "%d / %d" % [t.stash.size(), STASH_MAX]
		"smoker":
			if t.has("smoke_fx") and is_instance_valid(t.smoke_fx):
				t.smoke_fx.emitting = not t.slot.is_empty() and t.smoke_t > 0.0
			if not t.slot.is_empty() and t.smoke_t > 0.0:
				t.smoke_t -= delta
				t.tag.text = "Smoking... %ds" % ceil(t.smoke_t)
				if t.smoke_t <= 0.0:
					t.tag.text = "DONE! Click"
			elif t.slot.is_empty():
				t.tag.text = "Smoker"

## One thin ribbon per active line, from the rod tip to the float: slack while you wait, taut and trembling on a bite.
func _update_fishing_lines() -> void:
	line_im.clear_surfaces()
	var anchor := _line_anchor()
	var cam_pos := cam.global_position
	var began := false
	var tm := Time.get_ticks_msec() * 0.001
	for h in holes:
		if h.state != "hole" or h.cast == 0 or not h.bobber.visible:
			continue
		var b: Vector3 = h.bobber.global_position + Vector3(0, 0.25, 0)
		var dist := anchor.distance_to(b)
		var slack := 1.0
		var vib := 0.0
		match h.cast:
			1: slack = 0.35 if h.dip > 0.0 else 1.0
			2:
				slack = 0.0
				vib = 0.7
			3:
				slack = 0.0
				vib = 1.2
		if h.flying:
			slack = 0.5
		var sag: float = clampf(dist * 0.07, 0.1, 1.0) * slack
		var n := 16
		if not began:
			line_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
			began = true
		else:
			# degenerate join between two lines
			pass
		var prev_left := Vector3.ZERO
		for i in n + 1:
			var k := float(i) / n
			var p := anchor.lerp(b, k) + Vector3(0, -sag * 4.0 * k * (1.0 - k), 0)
			p.y += sin(k * PI * 5.0 + tm * 45.0) * 0.012 * vib * sin(k * PI)
			var dir := (b - anchor).normalized()
			var view_dir := (p - cam_pos).normalized()
			var side := dir.cross(view_dir)
			side = side.normalized() if side.length() > 0.001 else Vector3.RIGHT
			var w := 0.006 + 0.0018 * p.distance_to(cam_pos)
			if i == 0:
				prev_left = p - side * w
				line_im.surface_add_vertex(prev_left)
				line_im.surface_add_vertex(prev_left)
			line_im.surface_add_vertex(p - side * w)
			line_im.surface_add_vertex(p + side * w)
			if i == n:
				line_im.surface_add_vertex(p + side * w)
				line_im.surface_add_vertex(p + side * w)
	if began:
		line_im.surface_end()

func _end_cast(t: Dictionary) -> void:
	t.cast = 0
	t.flying = false
	t.hooked = []
	t.nib = []
	t.dip = 0.0
	t.bobber.visible = false
	t.bobber.position = Vector3(0, 0.18, 0)
	t.mark.visible = false

## Where the line leaves the rod: the tip of the rod in hand, or a spot by your hand if you have put it away.
func _line_anchor() -> Vector3:
	if tool == 1 and is_instance_valid(tool_tip) and tool_tip.is_inside_tree():
		return tool_tip.global_position
	return cam.global_position + cam.global_basis * Vector3(0.38, -0.3, -0.9)

## Click on a hole with the rod: the float arcs out from the rod tip and lands with a plop.
func _cast(t: Dictionary) -> void:
	for h in holes:  # one line at a time: casting a new one reels the old one in
		if h != t and h.state == "hole" and h.cast in [1, 2]:
			_end_cast(h)
	t.cast = 1
	t.timer = wait_time(t)
	t.nib = []
	if t.timer > 1.6:
		t.nib.append(t.timer * 0.55)
	if t.timer > 3.2:
		t.nib.append(t.timer * 0.22)
	t.dip = 0.0
	t.flying = true
	t.bobber.visible = true
	var from := _line_anchor()
	var dest: Vector3 = t.node.global_position + Vector3(0, 0.18, 0)
	var dist := from.distance_to(dest)
	var arc := 1.0 + dist * 0.12
	sfx.play("cast")
	_kick_tool(1.1)
	var tw := create_tween()
	tw.tween_method(func(k: float):
		if t.flying and is_instance_valid(t.bobber):
			t.bobber.global_position = from.lerp(dest, k) + Vector3(0, sin(k * PI) * arc, 0), 0.0, 1.0, 0.32 + dist * 0.018).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		if t.cast == 1 and t.flying:
			t.flying = false
			t.bobber.position = Vector3(0, 0.18, 0)
			sfx.play("plop")
			FishingFX.splash(t.node, Vector3(0, 0.12, 0), 10, 0.8)
			FishingFX.ripple(t.node, Vector3(0, 0.1, 0), 1.3, Color(0.75, 0.95, 1.0), 1.0))

func _nibble(t: Dictionary) -> void:
	t.dip = 0.35
	sfx.play("tick", -3.0, randf_range(0.9, 1.25))
	FishingFX.ripple(t.node, Vector3(0, 0.1, 0), 0.7, Color(0.8, 0.95, 1.0), 0.7, 0.55)

func _bite(t: Dictionary) -> void:
	t.cast = 2
	t.timer = BITE_WINDOW
	t.mark.visible = true
	t.mark.scale = Vector3.ONE * 0.2
	var mt := create_tween()
	mt.tween_property(t.mark, "scale", Vector3.ONE * 1.35, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	mt.tween_property(t.mark, "scale", Vector3.ONE, 0.1)
	t.dip = 0.5
	sfx.play("bite")
	fov_kick = -5.0
	shake = maxf(shake, 0.015)
	_kick_tool(-1.0)
	FishingFX.splash(t.node, Vector3(0, 0.12, 0), 12, 0.9)
	FishingFX.ripple(t.node, Vector3(0, 0.1, 0), 1.6, Color(1.0, 0.95, 0.6), 0.8, 0.9)

## How hard a species fights, 0.6 (minnow) to 2.0 (the ancient one).
func _fight_intensity(f: Dictionary) -> float:
	var v := _species_value(f.name)
	if v < 2.5: return 0.6
	if v < 6.0: return 1.0
	if v < 20.0: return 1.35
	if v < 100.0: return 1.7
	return 2.0

## Click during the bite: the fish is hooked and the fight starts. What you hooked decides how long it lasts.
func _hook(t: Dictionary) -> void:
	var n := lines()
	var got := []
	for i in n:
		var f := _draw_fish(t)
		if f.is_empty():
			break
		got.append(f)
	if got.is_empty():
		_end_cast(t)
		_say("Nothing left to catch here.")
		_after_draw(t)
		_refresh()
		return
	var inten := 0.0
	for f in got:
		inten = maxf(inten, _fight_intensity(f))
	t.hooked = got
	t.cast = 3
	t.fight_i = inten
	t.fight_total = 0.5 + 0.3 * inten + (0.4 if inten >= 2.0 else 0.0)
	t.fight = t.fight_total
	t.fx_t = 0.0
	t.mark.visible = false
	t.dip = 0.0
	sfx.play("hook")
	fov_kick = -9.0
	shake = maxf(shake, 0.03)
	_kick_tool(-1.4)
	FishingFX.splash(t.node, Vector3(0, 0.12, 0), 16, 1.1)
	if inten >= 2.0:
		scenery.pulse_eye()
	_after_draw(t)
	_refresh()

func _tick_cast(t: Dictionary, delta: float) -> void:
	var ms := Time.get_ticks_msec()
	var bob_y := 0.18 + sin(ms * 0.004 + t.idx) * 0.012
	if t.dip > 0.0:
		t.dip -= delta
		bob_y -= sin(clampf(t.dip / 0.5, 0.0, 1.0) * PI) * 0.13
	match t.cast:
		1:
			t.timer -= delta
			if not t.nib.is_empty() and t.timer < t.nib[0]:
				t.nib.remove_at(0)
				_nibble(t)
			if t.timer <= 0.0:
				_bite(t)
			if not t.flying:
				t.bobber.position = Vector3(0, bob_y, 0)
		2:
			t.timer -= delta
			t.bobber.position = Vector3(sin(ms * 0.05) * 0.03, 0.09 + sin(ms * 0.045) * 0.05, cos(ms * 0.043) * 0.03)
			if t.timer <= 0.0:
				_end_cast(t)
				_say("It got away...")
		3:
			t.fight -= delta
			var inten: float = t.fight_i
			var p: float = 1.0 - t.fight / t.fight_total
			var ang := ms * 0.011 * (0.8 + inten * 0.4)
			var r := 0.3 * (0.6 + 0.3 * inten) * (1.0 - 0.4 * p)
			t.bobber.position = Vector3(cos(ang) * r, 0.1 + absf(sin(ang * 1.7)) * 0.1, sin(ang) * r)
			t.fx_t -= delta
			if t.fx_t <= 0.0:
				t.fx_t = 0.13 / inten
				FishingFX.splash(t.node, t.bobber.position, 5, 0.7)
				FishingFX.ripple(t.node, Vector3(t.bobber.position.x, 0.1, t.bobber.position.z), 0.9 + 0.3 * inten, Color(0.8, 0.95, 1.0), 0.6, 0.5)
				sfx.play("reel", -6.0, 0.85 + p * 0.6)
				if inten >= 1.35:
					FishingFX.ripple(t.node, Vector3(0, 0.1, 0), 1.8, t.hooked[0].color, 0.8, 0.6)
			shake = maxf(shake, 0.004 + 0.006 * inten)
			if t.fight <= 0.0:
				_catch(t)

## A fish arcs to the pupil's rim, pays and wakes the Eye as it crosses it, then spirals down the funnel.
func _fly_fish(f: Dictionary, from: Vector3, delay: float, _dest := "eye", eye_mult := EYE_MULT, hand := false) -> void:
	var holder := Node3D.new()
	holder.visible = delay <= 0.0
	add_child(holder)
	var fm := _fish_mesh(f, holder, 1.4)
	(fm as FishNode).amp = 2.0
	holder.global_position = from
	var pts := [from, scenery.eye_landing(from)]   # shared with the tween lambdas; a hand throw re-aims when it leaves the hand
	var rec := {"f": f, "m": eye_mult}
	flying.append(rec)
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_callback(func():
		if hand:
			pts[0] = _hand_origin()
			pts[1] = scenery.eye_landing(pts[0])
			_kick_tool(0.7)
			view_pop = 0.6
			sfx.play("cast", -9.0, 1.5)
		holder.visible = true)
	tw.tween_method(func(t: float):
		holder.global_position = pts[0].lerp(pts[1], t) + Vector3(0, sin(t * PI) * 4.0, 0)
		fm.rotation.z = t * 7.0, 0.0, 1.0, 0.8 if not hand else 0.62).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		flying.erase(rec)
		_feed_eye(f, eye_mult, hand))
	_spiral_into_eye(tw, holder, pts)
	tw.tween_callback(holder.queue_free)

func _hand_origin() -> Vector3:
	return cam.global_position + cam.global_basis * Vector3(-0.42, -0.4, -0.8)

## Appends the last part of a fish's trip to a tween: it circles the pupil rim and spirals down the funnel.
func _spiral_into_eye(tw: Tween, holder: Node3D, pts: Array, dur := 0.55) -> void:
	tw.tween_method(func(t: float):
		var a0 := atan2(pts[1].z, pts[1].x)
		var ang := a0 + t * TAU * 1.5
		var rad := lerpf(PUPIL_R * 0.72, 0.5, t)
		holder.global_position = Vector3(cos(ang) * rad, lerpf(0.6, -7.0, t * t), sin(ang) * rad)
		holder.scale = Vector3.ONE * lerpf(1.0, 0.1, t), 0.0, 1.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## A belt fish reaches the end of its belt: it hops the rim and dives down the funnel (the coins were paid already).
func _belt_dive(f: Dictionary, from: Vector3, dir: Vector3) -> void:
	if dive_live >= DIVE_MAX:
		return
	dive_live += 1
	var holder := Node3D.new()
	add_child(holder)
	var fm := _fish_mesh(f, holder, 1.0)
	(fm as FishNode).amp = 1.6
	holder.global_position = from
	holder.rotation.y = atan2(-dir.z, dir.x)
	var target: Vector3 = scenery.eye_landing(from)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		holder.global_position = from.lerp(target, t) + Vector3(0, sin(t * PI) * 1.1, 0), 0.0, 1.0, 0.24)
	_spiral_into_eye(tw, holder, [from, target], 0.5)
	tw.tween_callback(func():
		dive_live -= 1
		holder.queue_free())

func _coins(v: float) -> String:
	return str(snappedf(v, 0.1)) if v < 10.0 else str(int(v))

func earn(amount: float) -> void:
	GameState.add(amount)
	stats.earned += amount
	_refresh()

## Olga never takes fish. She nudges you toward the next goal, or muses about the Eye.
func _talk_olga() -> void:
	if not carry.is_empty():
		_say("Olga: Not to me, dear. It's the Eye that's hungry.")
		return
	if guide.is_early() or randf() < 0.75:
		_say(guide.olga_line())
	else:
		_say(OLGA_CHATTER.pick_random())
	sfx.play("coin", -8.0, 0.8)

## Coins offered to the Eye: an endless sink that raises the value of every fish.
func _tithe() -> void:
	if eye_stage() < TITHE_MIN_STAGE:
		_say("The Eye does not notice coins yet. Feed it fish first.")
		return
	if yard.near_eye(EYE_R + FishYard.PULL_RANGE + 4.0) > 0:
		_say("Push the fish in first: walk into them, or kick them (hold right mouse).")
		return
	if tithe_armed_t <= 0.0:
		tithe_armed_t = 2.0
		_say("Click the Eye again to offer %d coins." % tithe_cost())
		sfx.play("tick", -4.0, 0.8)
		return
	tithe_armed_t = 0.0
	if not _spend(tithe_cost()):
		return
	stats.tithe += 1
	scenery.eye_catch(Color(1.0, 0.82, 0.4), 1.0)
	scenery.eye.flare = maxf(scenery.eye.flare, 1.2)
	sfx.play("rare")
	shake = maxf(shake, 0.04)
	_burst(Vector3(0, 0.6, 0), Color(1.0, 0.82, 0.4), 18, 4.0, 1.0, 0.1)
	_banner("TITHE  Lv %d   fish are worth +%d%% more" % [stats.tithe, int(TITHE_BONUS * 100.0 * stats.tithe)], Color(1.0, 0.85, 0.45))
	_log("TITHE Lv%d" % stats.tithe)
	_refresh()

func _feed_by_hand() -> void:
	if carry.is_empty():
		_tithe()
		return
	var from := _hand_origin()
	var gap := 0.0
	for i in carry.size():  # one at a time, faster and faster: a rhythm you can feel
		_fly_fish(carry[i], from, gap, "eye", EYE_MULT, true)
		gap += maxf(0.27 * pow(0.84, i), 0.085)
	stats.deliveries += 1
	carry.clear()
	_refresh_view()
	_refresh()

# ---------- the Eye ----------
## Fish needed for stage i: later lakes are bigger, and so is the Eye's appetite.
func eye_stage_at(i: int) -> int:
	return int(round(EYE_STAGES[i] * (1.0 + 0.3 * _meta_int("lakes"))))

func eye_stage() -> int:
	var n := 0
	for i in EYE_STAGES.size():
		var s := eye_stage_at(i)
		if stats.eye_fed >= s:
			n += 1
	return n

func eye_open_frac() -> float:
	return clampf(sqrt(float(stats.eye_fed) / float(eye_stage_at(EYE_STAGES.size() - 1))), 0.0, 1.0)

func _belt_speed() -> float:
	return BELT_SPEED * (1.0 + 0.25 * GameState.level("conveyor"))

func _belt_mult() -> float:
	return EYE_MULT * (1.0 + 0.15 * GameState.level("conveyor"))

## A fish drops into the Eye (hand-fed or off a belt): pays coins, counts toward the Eye's stages.
func _feed_eye(f: Dictionary, mult: float, hand := false) -> void:
	var worth: float = f.base * f.mult * sale_mult() * mult
	stats.eye_fed += 1
	eye_pending += worth
	_order_progress(f)
	earn(worth)
	feed_streak = feed_streak + 1 if feed_streak_t > 0.0 else 1
	feed_streak_t = 1.3 if hand else 0.6
	if hand:
		_hand_feed_fx(worth)
	elif eye_burst_t <= 0.0:
		eye_burst_t = 0.12
		sfx.play("coin", 0.0, randf_range(0.7, 0.95))
	scenery.eye_catch(f.color, clampf(worth / 25.0 + (0.05 * feed_streak if hand else 0.0), 0.0, 1.0))
	var st := eye_stage()
	if st > eye_seen_stage:
		eye_seen_stage = st
		_eye_stage_up(st)

## The swallow itself: each fish in a hand-fed streak rings a higher note, and the Eye answers bigger and bigger.
func _hand_feed_fx(worth: float) -> void:
	var step := mini(feed_streak - 1, FEED_NOTES.size() - 1)
	sfx.play("coin", -1.0, 0.8 * pow(2.0, FEED_NOTES[step] / 12.0))
	eye_burst_t = 0.12
	fov_kick = maxf(fov_kick, 1.0 + minf(feed_streak, 8) * 0.35)
	if feed_streak >= 3:
		streak_label.text = "x%d" % feed_streak
		streak_label.modulate.a = 1.0
		streak_label.scale = Vector2.ONE * 1.35
		var tw := create_tween()
		tw.tween_property(streak_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if feed_streak >= 5 and feed_streak % 5 == 0:
		scenery.eye_gulp(minf(feed_streak / 10.0, 2.0))
		_float_text(Vector3(0, 8.0, 0), "STREAK x%d" % feed_streak, Style.AMBER, 0.05)
		sfx.play("rare", -7.0, 1.0 + minf(feed_streak * 0.02, 0.4))
		shake = maxf(shake, 0.03)

func _eye_stage_up(st: int) -> void:
	_log("EYE stage %d" % st)
	sfx.play("rare")
	shake = maxf(shake, 0.1)
	var first_awake: bool = st >= EYE_STAGES.size() and stats.awakened == 0
	if first_awake:
		stats.awakened = 1
		GameState.meta.pearls = _meta_int("pearls") + AWAKEN_PEARLS
		_log("EYE AWAKE")
	if first_awake and not GameState.meta.get("awaken_seen", false):
		awaken_hold = true
		if guide.play_awakening():
			GameState.meta["awaken_seen"] = true
			_refresh()
			return
		awaken_hold = false
	_stage_reveal(st)
	_say("Olga: %s\nNew: %s" % [EYE_LINES[st - 1], EYE_BOONS[st - 1]])
	scenery.set_eye_open(eye_open_frac())
	scenery.eye_stage_up(st)
	_refresh()

## The Eye wakes a stage: bars slide in, the view turns to it and pulls back, a flash, and the stage and its gift are named.
func _stage_reveal(st: int) -> void:
	var last := st >= EYE_STAGES.size()
	reveal_total = 3.8 if last else 3.0
	reveal_t = reveal_total
	guide.cinematic(reveal_total)
	reveal_title.text = "THE EYE AWAKENS" if last else "THE EYE STIRS"
	reveal_sub.text = "Stage %d of %d   -   %s" % [st, EYE_STAGES.size(), EYE_BOONS[st - 1]]
	var tw := create_tween()
	tw.tween_property(reveal_title, "modulate:a", 1.0, 0.5).set_delay(0.5)
	tw.tween_interval(reveal_total - 2.2)
	tw.tween_property(reveal_title, "modulate:a", 0.0, 0.9)
	var tw2 := create_tween()
	tw2.tween_property(reveal_sub, "modulate:a", 1.0, 0.5).set_delay(1.0)
	tw2.tween_interval(reveal_total - 2.7)
	tw2.tween_property(reveal_sub, "modulate:a", 0.0, 0.9)
	flash_rect.color.a = 0.4
	var fl := create_tween()
	fl.tween_property(flash_rect, "color:a", 0.0, 1.1)
	create_tween().tween_callback(func(): sfx.play("goal", -4.0, 0.75)).set_delay(0.45)

# ---------- belts ----------
func belt_cost(t: Dictionary) -> int:
	var d := maxf(Vector2(t.pos.x, t.pos.z).length() - PUPIL_R, 0.0)
	return int(ceil(12.0 + d * 0.9))

func _setup_belt_fish() -> void:
	belt_mm = MultiMesh.new()
	belt_mm.transform_format = MultiMesh.TRANSFORM_3D
	belt_mm.use_colors = true
	belt_mm.mesh = FishModel.bead_mesh()   # little real fish (body, tail, fins), not spheres
	belt_mm.instance_count = BELT_MAX_FISH
	belt_mm.visible_instance_count = 0
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.35
	m.emission_enabled = true
	m.emission = Color(0.3, 0.35, 0.4)
	m.emission_energy_multiplier = 0.25
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = belt_mm
	mi.material_override = m
	mi.custom_aabb = AABB(Vector3(-150, -5, -150), Vector3(300, 20, 300))
	add_child(mi)
	drill_marker = MeshInstance3D.new()
	var dc := CylinderMesh.new()
	dc.top_radius = 0.7
	dc.bottom_radius = 0.7
	dc.height = 0.03
	dc.radial_segments = 16
	drill_marker.mesh = dc
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.1, 0.25, 0.5, 0.7)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drill_marker.material_override = dm
	drill_marker.visible = false
	add_child(drill_marker)

## Lays a belt from an Auto-Rod straight to the Eye. Fish ride it (instanced) and drop in.
func _build_belt(t: Dictionary, pay := true) -> void:
	if t.belt != null or t.state != "auto":
		return
	var cost := belt_cost(t)
	if pay and not _spend(float(cost)):
		return
	var a := Vector3(t.pos.x, 0.0, t.pos.z)
	var dir := (-a).normalized()
	var b := dir * (PUPIL_R + 0.4)
	var blen := a.distance_to(b)
	var node := Node3D.new()
	add_child(node)
	var mid := (a + b) * 0.5
	node.look_at_from_position(Vector3(mid.x, 0.55, mid.z), Vector3(b.x, 0.55, b.z), Vector3.UP)
	MachineModels.belt(node, blen, _belt_speed())
	_pop_in(node)
	var belt := {"hole": t, "a": a, "b": b, "len": blen, "dir": dir, "node": node, "cost": cost}
	belts.append(belt)
	t.belt = belt
	stats.belts += 1
	if pay:
		_say("Belt laid. Watch the catch ride into the Eye.")
		_refresh()

# ---------- build tool (7): cannery, sorter, depot, ice-breaker. Q cycles. ----------
func _count_belts(flag: String) -> int:
	var n := 0
	for b in belts:
		if b.get(flag, false):
			n += 1
	return n

func _build_cost(item: int) -> int:
	match item:
		0: return int(ceil(120.0 * pow(1.9, _count_belts("cannery"))))
		1: return int(ceil(90.0 * pow(1.9, _count_belts("sorter"))))
		2: return int(ceil(70.0 * pow(1.5, depots.size())))
		_: return 0 if int(stats.get("rig_moves", 0)) > 0 else int(ceil(RIG_BASE * pow(RIG_GROWTH, rigs.size())))

## Is p a legal spot for a free-standing building (depot / ice-breaker)?
func _can_place_at(p: Vector3, radius: float) -> bool:
	var c := _cell_at(p)
	if not tiles.has(c) or tiles[c].state == "platform":
		return false
	if not model.sectors[tiles[c].sector].unlocked:
		return false
	var flat := Vector2(p.x, p.z)
	if flat.length() < EYE_R + 7.0 or flat.length() > scenery.edge_at(p.x, p.z) - 4.0:
		return false
	for o in scenery.obstacles:
		if flat.distance_to(Vector2(o.x, o.y)) < o.z + radius:
			return false
	for h in holes:
		if flat.distance_to(Vector2(h.pos.x, h.pos.z)) < radius + 1.0:
			return false
	for d in depots:
		if flat.distance_to(Vector2(d.pos.x, d.pos.z)) < radius + 2.0:
			return false
	for rg in rigs:
		if flat.distance_to(Vector2(rg.pos.x, rg.pos.z)) < radius + 5.0:
			return false
	return true

func _build_machine_visual(belt: Dictionary, kind: String) -> void:
	var node: Node3D = belt.node
	var mid_z: float = float(belt.len) * 0.5 * (0.2 if kind == "cannery" else -0.2)
	var m := Node3D.new()
	node.add_child(m)
	m.position = Vector3(0, 0, mid_z)
	_pop_in(m)
	if kind == "cannery":
		MachineModels.cannery(m)
		var l := _label3d(m, Vector3(0, 4.7, 0), "CANNERY x1.5", 0.012)
		l.modulate = Color(1.0, 0.9, 0.7)
	else:
		MachineModels.sorter(m)
		var l2 := _label3d(m, Vector3(0, 3.7, 0), "SORTER x1.6 (5+)", 0.012)
		l2.modulate = Color(0.7, 1.0, 0.85)

func _install_machine(t: Dictionary, kind: String, pay := true) -> void:
	if t.state != "auto" or t.belt == null:
		_say("Click an Auto-Rod that has a belt.")
		return
	if t.belt.get(kind, false):
		_say("That belt already has a %s." % kind)
		return
	var item := 0 if kind == "cannery" else 1
	if pay and not _spend(float(_build_cost(item))):
		return
	t.belt[kind] = true
	stats["cans" if kind == "cannery" else "sorters"] += 1
	_build_machine_visual(t.belt, kind)
	if pay:
		_say("%s built. Everything on this belt is worth more." % kind.capitalize())
		_refresh()

func _build_depot(pos: Vector3, pay := true) -> void:
	if pay and not _spend(float(_build_cost(2))):
		return
	var node := Node3D.new()
	node.position = Vector3(pos.x, 0.0, pos.z)
	add_child(node)
	var d := {"pos": node.position, "node": node, "idx": depots.size()}
	var hit := _box(node, Vector3(0, 0.6, 0), Vector3(2.8, 1.2, 1.8), Color.WHITE, "depot:%d" % d.idx)   # the click target (the model is MachineModels.depot)
	hit.visible = false
	MachineModels.depot(node)
	_pop_in(node)
	var l := _label3d(node, Vector3(0, 3.6, 0), "DEPOT", 0.014)
	l.modulate = Color(1.0, 0.9, 0.7)
	depots.append(d)
	scenery.obstacles.append(Vector3(pos.x, pos.z, 2.2))
	stats.depots += 1
	if pay:
		_say("Depot built. Drop fish here and a sled runs them to the Eye.")
		sfx.play("buy")
		_refresh()

func _use_depot(d: Dictionary) -> void:
	if carry.is_empty():
		_say("Drop fish here and a sled runs them to the Eye.")
		return
	var n := carry.size()
	var from: Vector3 = d.pos + Vector3(0, 1.8, 0)
	for i in n:
		_fly_fish(carry[i], from, 0.4 + i * 0.1, "eye", EYE_MULT * DEPOT_MULT)
	stats.deliveries += 1
	carry.clear()
	_refresh_view()
	_float_text(d.pos + Vector3(0, 3.4, 0), "%d fish sent" % n, Color(0.8, 1.0, 0.9))
	sfx.play("coin", 0.0, 0.85)
	_refresh()

func _build_rig(pos: Vector3, pay := true) -> void:
	if rigs.size() >= rig_cap():
		_say("The lake can bear %d ice-breakers for now. Wake the Eye further for more." % rig_cap())
		return
	var free_move: bool = pay and int(stats.get("rig_moves", 0)) > 0   # an Ice-Breaker you picked up goes down again for free
	if pay and not free_move and not _spend(float(_build_cost(3))):
		return
	if free_move:
		stats["rig_moves"] = int(stats.rig_moves) - 1
	var node := Node3D.new()
	node.position = Vector3(pos.x, 0.0, pos.z)
	add_child(node)
	node.look_at(Vector3(0, 0, 0), Vector3.UP, true)
	rig_serial += 1
	var idx := rig_serial
	var a := Vector3(pos.x, 0.0, pos.z)
	var dir := (-a).normalized()
	var b := dir * (PUPIL_R + 0.4)
	var rig := {"pos": node.position, "node": node, "idx": idx, "t": RIG_INTERVAL, "tag": null,
		"belt": {"a": a, "b": b, "len": a.distance_to(b), "dir": dir}}
	var hit := _box(node, Vector3(0, 0.7, 0), Vector3(5.6, 1.5, 11.0), Color.WHITE, "rig:%d" % idx)   # the click target
	hit.visible = false
	var rp: Dictionary = MachineModels.rig(node)
	rig.beacon = rp.beacon
	_pop_in(node)
	rig.tag = _label3d(node, Vector3(0, 8.4, 0), "ICE-BREAKER", 0.016)
	rig.tag.modulate = Color(0.9, 0.95, 1.0)
	rigs.append(rig)
	scenery.obstacles.append(Vector3(pos.x, pos.z, 6.0))
	if pay and not free_move:
		stats.rigs += 1
	if pay:
		_say("The ice-breaker rumbles to life. It feeds the Eye straight from the lake.")
		sfx.play("rare")
		shake = maxf(shake, 0.06)
		_refresh()

## The rig chews through the patch it sits on and its neighbours, and its catch rides a belt-line into the Eye.
## The fullest open cell within a rig's reach; (9999, 9999) if there is nothing left nearby.
func _rig_best(rg: Dictionary) -> Vector2i:
	var c0 := _cell_at(rg.pos)
	var best := Vector2i(9999, 9999)
	var best_n := 0
	var cand: Array = [c0]
	for d in HEX_DIRS:
		cand.append(c0 + d)
	for c in cand:
		if not tiles.has(c) or tiles[c].state == "platform":
			continue
		if not model.sectors[tiles[c].sector].unlocked:
			continue
		var n: int = model.tile_left(c)
		if n > best_n:
			best_n = n
			best = c
	return best

func _rig_of(a: String) -> Dictionary:
	var id := int(a.substr(4))
	for rg in rigs:
		if rg.idx == id:
			return rg
	return {}

## An Ice-Breaker with nothing left to chew can be lifted off the ice and placed again anywhere, for free.
func _pick_up_rig(rg: Dictionary) -> void:
	for i in scenery.obstacles.size():
		var o: Vector3 = scenery.obstacles[i]
		if absf(o.x - rg.pos.x) < 0.01 and absf(o.y - rg.pos.z) < 0.01:
			scenery.obstacles.remove_at(i)
			break
	rg.node.queue_free()
	rigs.erase(rg)
	stats["rig_moves"] = int(stats.get("rig_moves", 0)) + 1
	_say("Lifted the idle Ice-Breaker. Press 7, Q to Ice-Breaker, and set it down anywhere: it is free.")
	sfx.play("buy")
	_refresh()

func _tick_rigs(delta: float) -> void:
	for rg in rigs:
		if rg.has("beacon") and is_instance_valid(rg.beacon):
			rg.beacon.rotation.y += delta * 3.2   # the amber beacon turns while the rig stands
		rg.t -= delta
		if rg.t > 0.0:
			continue
		var best := _rig_best(rg)
		var best_n := 0 if best.x == 9999 else 1
		if best_n == 0:
			rg.t = 2.0
			rg.tag.text = "ICE-BREAKER (idle: nothing left nearby)"
			continue
		rg.tag.text = "ICE-BREAKER"
		var pseudo := {"c": best, "node": rg.node}
		var f := _draw_fish(pseudo)
		if not f.is_empty():
			_belt_push(rg.belt, f)
			_after_draw(pseudo)
		rg.t = RIG_INTERVAL * model.wait_factor(best) * 0.6 + 0.6

func _remove_belt(t: Dictionary) -> void:
	var belt: Dictionary = t.belt
	if belt == null:
		return
	for i in range(belt_fish.size() - 1, -1, -1):
		if belt_fish[i].belt == belt:
			belt_fish.remove_at(i)
	belts.erase(belt)
	belt.node.queue_free()
	t.belt = null

func _belt_spawn(t: Dictionary, f: Dictionary) -> void:
	_belt_push(t.belt, f)

func _belt_push(belt: Dictionary, f: Dictionary) -> void:
	if belt_fish.size() >= BELT_MAX_FISH:
		_feed_eye(f, _belt_mult() * _belt_flag_mult(belt, f))
		return
	belt_fish.append({"belt": belt, "d": 0.0, "f": f})

## Machines on a belt change what its fish are worth when they reach the Eye.
func _belt_flag_mult(belt: Dictionary, f: Dictionary) -> float:
	var m := 1.0
	if belt.get("cannery", false):
		m *= CANNERY_MULT
	if belt.get("sorter", false) and f.base * f.mult >= 5.0:
		m *= SORTER_MULT
	return m

func _update_belt_fish(delta: float) -> void:
	if belt_mm == null:
		return
	if belt_fish.is_empty():
		belt_mm.visible_instance_count = 0
		return
	var sp := _belt_speed()
	for i in range(belt_fish.size() - 1, -1, -1):
		var it: Dictionary = belt_fish[i]
		it.d += sp * delta
		if it.d >= it.belt.len:
			belt_fish.remove_at(i)
			_feed_eye(it.f, _belt_mult() * _belt_flag_mult(it.belt, it.f))
			_belt_dive(it.f, it.belt.b + Vector3(0, 0.78, 0), it.belt.dir)
	for k in belt_fish.size():
		var it2: Dictionary = belt_fish[k]
		var b: Dictionary = it2.belt
		var pos: Vector3 = b.a.lerp(b.b, it2.d / b.len) + Vector3(0, 0.78 + sin(it2.d * 3.0 + k) * 0.02, 0)
		var yaw := atan2(-b.dir.z, b.dir.x) + sin(it2.d * 4.0 + k * 1.7) * 0.12   # a little wriggle as it rides
		belt_mm.set_instance_transform(k, Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3.ONE * 0.95), pos))
		belt_mm.set_instance_color(k, it2.f.color)
	belt_mm.visible_instance_count = belt_fish.size()

func _aim_raw() -> String:
	var from := cam.global_position
	var to := from - cam.global_basis.z * REACH
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	aim_flat = 9999.0
	if hit and hit.collider.has_meta("action"):
		var hp: Vector3 = hit.position
		aim_pos = hp
		var pp: Vector3 = $Player.global_position
		aim_flat = Vector2(hp.x - pp.x, hp.z - pp.z).length()
		return hit.collider.get_meta("action")
	return ""

func _in_range(a: String) -> bool:
	if a == "olga": return aim_flat <= RANGE_HATCH
	if a.begins_with("depot:") or a.begins_with("rig:"): return aim_flat <= RANGE_BUILD
	if a == "eye":
		var pp: Vector3 = $Player.global_position
		return Vector2(pp.x, pp.z).length() - EYE_R <= RANGE_EYE
	if a.begins_with("buy:"): return aim_flat <= RANGE_SIGN
	if a == "ice" or a.begins_with("hole:"): return aim_flat <= RANGE_ICE
	return true

## What you can actually interact with right now (empty if too far away).
func _aim() -> String:
	var a := _aim_raw()
	return a if _in_range(a) else ""

## One line at a time: is another hole already fishing?
func _other_line(t: Dictionary) -> bool:
	for h in holes:
		if h != t and h.state == "hole" and h.cast > 0:
			return true
	return false

func _hole_of(a: String) -> Dictionary:
	if not a.begins_with("hole:"):
		return {}
	var i := int(a.substr(5))
	return holes[i] if i >= 0 and i < holes.size() else {}

func _below_text(t: Dictionary) -> String:
	var left: int = model.tile_left(t.c)
	var sonar := GameState.level("sonar")
	if left == 0:
		return "fished out"
	if sonar >= 1:
		var s := "~%d fish below" % left
		if sonar >= 2 and model.has_rare(t.c):
			s += "  * something rare"
		return s
	return "fish below: " + model.band(t.c)

func _tile_action_text(t: Dictionary) -> String:
	match t.state:
		"hole":
			if t.cast == 2: return "BITE! CLICK!"
			if t.cast == 1: return "Waiting... (click to reel in)"
			if _emptied(t):
				if tool == 3 and _tool_unlocked(3): return "Click: build Smoker (%d)" % smoker_cost()
				if tool == 4 and _tool_unlocked(4): return "Click: build Gut Table (%d)" % table_cost()
				return "Fished out (build a Smoker/Table here with 4/5)"
			if tool == 1: return "Click: cast line" if not _other_line(t) else "Click: cast here (reels in your other line)"
			if tool == 2: return "Click: build Auto-Rod (%d)" % auto_cost()
			if tool == 5: return "Build an Auto-Rod here first (3)"
			return "Hole (2: Rod)"
		"auto":
			if tool == 6 and _tool_unlocked(6):
				if t.belt == null: return "Lay a belt here first (tool 6)"
				if build_item <= 1:
					var kind0 := "cannery" if build_item == 0 else "sorter"
					if t.belt.get(kind0, false): return "This belt already has a %s" % kind0
					return "Click: build %s on this belt (%d)" % [BUILD_ITEMS[build_item], _build_cost(build_item)]
				return "Depots and ice-breakers go on open ice (Q to switch)"
			if tool == 5 and _tool_unlocked(5) and t.belt == null: return "Click: lay a belt to the Eye (%d)" % belt_cost(t)
			if not t.stash.is_empty():
				return "Click: collect %d fish (what does not fit spills onto the ice)" % t.stash.size()
			if model.tile_left(t.c) == 0:
				return "Click: pick up Auto-Rod (refund %d)" % _refund()
			if t.belt != null: return "Auto-Rod + belt (working)"
			return "Auto-Rod (working)"
		"smoker":
			if t.slot.is_empty():
				if carry.is_empty(): return "Smoker (carry fish here)"
				return "Click: smoke %d fish" % mini(carry.size(), SMOKER_SLOTS)
			if t.smoke_t > 0.0: return "Smoking..."
			return "Click: collect smoked fish"
		"table":
			var raw := 0
			for f in carry:
				if not f.gutted:
					raw += 1
			if raw > 0: return "Hold click: gut fish (%d to gut)" % raw
			return "Gut Table (carry fish here)"
	return ""

func _refund() -> int:
	return int(floor(0.6 * AUTO_BASE * pow(AUTO_GROWTH, maxi(_count("auto") - 1, 0))))

func _prompt_for(a: String) -> String:
	if a == "olga":
		return "Click: talk to Olga" if carry.is_empty() else "Olga doesn't buy fish: the Eye does"
	if a == "eye":
		if carry.is_empty():
			if eye_stage() >= TITHE_MIN_STAGE:
				if yard.near_eye(EYE_R + FishYard.PULL_RANGE + 4.0) > 0:
					return "Push the fish into the Eye (walk into them, or kick)"
				if tithe_armed_t > 0.0:
					return "Click again to offer %d coins  (Lv %d, +%d%% value)" % [tithe_cost(), stats.tithe, int(TITHE_BONUS * 100.0 * stats.tithe)]
				return "Click twice: tithe %d coins to the Eye  (Lv %d)" % [tithe_cost(), stats.tithe]
			return "The Eye: push fish into it (or click with a full bucket)"
		return "Click: feed %d fish to the Eye for %d coins" % [carry.size(), floor(carry_worth() * EYE_MULT)]
	if a.begins_with("depot:"):
		return "Click: send %d fish to the Eye by sled" % carry.size() if not carry.is_empty() else "Depot (carry fish here: a sled runs them to the Eye)"
	if a.begins_with("rig:"):
		var rg := _rig_of(a)
		if not rg.is_empty() and _rig_best(rg).x == 9999:
			return "Idle Ice-Breaker: click to pick it up (placing it again is free)"
		return "Ice-Breaker: feeding the Eye from the lake"
	if a.begins_with("buy:"):
		var id := a.substr(4)
		if not unlocked[id]:
			return "Locked - complete goals"
		return "Click: buy %s" % UPGRADES[id].name
	if a == "ice":
		var c := _cell_at(aim_pos)
		if not tiles.has(c):
			return "Barren ice"
		var cell: Dictionary = tiles[c]
		if cell.state == "platform":
			return "The Eye's rim"
		var sec: Dictionary = model.sectors[cell.sector]
		if not sec.unlocked:
			return "LOCKED - clear a neighbouring sector to open %s" % sec.name
		var head := "Solid ice (1: Drill)"
		if tool == 6 and _tool_unlocked(6):
			if build_item <= 1:
				head = "Click an Auto-Rod with a belt to add a %s (Q: switch)" % BUILD_ITEMS[build_item]
			else:
				var rad := 2.6 if build_item == 2 else 6.0
				var ok := _can_place_at(Vector3(aim_pos.x, 0, aim_pos.z), rad)
				if build_item == 3 and rigs.size() >= rig_cap():
					head = "The lake bears %d ice-breakers: wake the Eye for more" % rig_cap()
				elif ok:
					head = "Click: build %s (%d)  [Q: switch]" % [BUILD_ITEMS[build_item], _build_cost(build_item)]
				else:
					head = "Can't build %s here (needs open ice, clear of things, away from the Eye)" % BUILD_ITEMS[build_item]
		elif tool == 0:
			head = "Too close to another hole" if _hole_near(aim_pos, MIN_HOLE_GAP) else ("Too close to the Eye" if Vector2(aim_pos.x, aim_pos.z).length() < EYE_R + 1.2 else "Hold click: drill here")
		elif tool >= 2 and tool != 6:
			head = "Build that on a hole you've already drilled"
		return "%s\n[%s: %d fish left]  %s" % [head, sec.name, sec.left, _below_text(cell)]
	var t := _hole_of(a)
	if t.is_empty():
		return ""
	var sec2: Dictionary = model.sectors[t.sector]
	return "%s\n[%s: %d fish left]  %s" % [_tile_action_text(t), sec2.name, sec2.left, _below_text(t)]

func _update_hold(a: String, delta: float) -> void:
	var holding := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _cap()
	if hold_block:
		if holding:
			holding = false
		else:
			hold_block = false
	work_bar.visible = false
	if drill_marker:
		drill_marker.visible = false
	if holding and a == "ice" and tool == 0:
		_drill_step(delta)
		return
	drill_prog = 0.0
	var t := _hole_of(a)
	if holding and not t.is_empty() and t.state == "table":
		working = true
		var target: Dictionary = {}
		for f in carry:
			if not f.gutted:
				target = f
				break
		if not target.is_empty():
			t.prog += delta * work_speed() / GUT_TIME
			work_bar.visible = true
			work_bar.value = t.prog
			if t.prog >= 1.0:
				t.prog = 0.0
				target.gutted = true
				target.mult *= GUT_MULT
				stats.gutted += 1
				_float_text(t.node.global_position + Vector3(0, 1.8, 0), "gutted!", Color(0.9, 0.95, 1.0))
				sfx.play("drill", 0.0, 0.7)
				_refresh()

## Hold click on open ice to drill a hole exactly where you are aiming.
func _drill_step(delta: float) -> void:
	var p := Vector3(aim_pos.x, 0.0, aim_pos.z)
	if not _can_drill_at(p):
		drill_prog = 0.0
		return
	if p.distance_to(drill_pos) > 1.3:
		drill_pos = p
		drill_prog = 0.0
	drill_prog += delta / drill_time()
	working = true
	work_bar.visible = true
	work_bar.value = drill_prog
	drill_marker.visible = true
	drill_marker.position = Vector3(drill_pos.x, 0.06, drill_pos.z)
	drill_marker.scale = Vector3(1, 1, 1) * clampf(drill_prog, 0.05, 1.0)
	drill_snd_t -= delta
	if drill_snd_t <= 0.0:
		drill_snd_t = 0.16
		sfx.play("drill", 0.0, randf_range(0.85, 1.15))
		_burst(drill_pos + Vector3(0, 0.15, 0), Color(0.9, 0.97, 1.0), 3, 2.5, 0.5, 0.07)
	if drill_prog >= 1.0:
		_finish_drill(p)

func _finish_drill(p: Vector3) -> void:
	drill_prog = 0.0
	drill_pos = Vector3(9999, 0, 9999)
	work_bar.visible = false
	var t := _make_hole(p)
	if t.is_empty():
		return
	sfx.play("buy")
	shake = maxf(shake, 0.03)
	_burst(p + Vector3(0, 0.2, 0), Color(0.9, 0.97, 1.0), 18, 4.0, 0.9, 0.1)
	_wide_drill(t)
	_refresh()

func _wide_drill(t: Dictionary) -> void:
	var n := GameState.level("wide")
	if n <= 0:
		return
	var ang0 := randf() * TAU
	for k in 6:
		if n <= 0:
			break
		var a := ang0 + TAU * k / 6.0
		var wp: Vector3 = t.pos + Vector3(cos(a), 0, sin(a)) * 2.6
		if _can_drill_at(wp):
			_make_hole(wp)
			n -= 1

# ---------- refreeze: the repeatable layer ----------
func _meta_int(k: String) -> int:
	return int(GameState.meta.get(k, 0))

func perk_level(id: String) -> int:
	return int(GameState.meta.get("perks", {}).get(id, 0))

func perk_cost(id: String) -> int:
	return PERKS[id].cost * (perk_level(id) + 1)

## Pearls this lake would pay out if you refroze it now.
func pearls_pending() -> int:
	return model.cleared_count() + (EMPTY_LAKE_PEARLS if stats.ended > 0 else 0)

func _can_refreeze() -> bool:
	return model.cleared_count() >= REFREEZE_MIN_SECTORS or stats.ended > 0

func _clock(secs: float) -> String:
	return "%d:%02d" % [int(secs) / 60, int(secs) % 60]

func _toggle_refreeze() -> void:
	refreeze_armed = false
	refreeze_panel.visible = not refreeze_panel.visible
	if refreeze_panel.visible:
		journal_panel.visible = false
		_update_refreeze()

func _update_refreeze() -> void:
	var out := ["REFREEZE THE LAKE\n"]
	out.append("Pearls: %d     This lake is worth +%d more" % [_meta_int("pearls"), pearls_pending()])
	var best := float(GameState.meta.get("best_time", 0.0))
	out.append("Lakes finished: %d     Fastest clear: %s" % [_meta_int("lakes_cleared"), _clock(best) if best > 0.0 else "-"])
	out.append("Next lake: %d%% more fish, fish worth %d%% more\n" % [int(30.0 * (_meta_int("lakes") + 1)), int(DEPTH_VALUE * 100.0 * (_meta_int("lakes") + 1))])
	var i := 1
	for id in PERKS:
		var p: Dictionary = PERKS[id]
		var lvl := perk_level(id)
		out.append("%d  %s  Lv%d/%d   %s   %s" % [i, p.name, lvl, p.max, p.desc, "MAX" if lvl >= p.max else "%d pearls" % perk_cost(id)])
		i += 1
	out.append("")
	if refreeze_armed:
		out.append("Enter again to confirm: new lake, coins/upgrades/stations reset, pearls & perks kept")
	elif _can_refreeze():
		out.append("Enter: refreeze (new lake, resets coins/upgrades)    R: close")
	else:
		out.append("Clear %d sectors to refreeze (%d so far)    R: close" % [REFREEZE_MIN_SECTORS, model.cleared_count()])
	refreeze_label.text = "\n".join(out)

## Returns true if the key was used by the panel.
func _refreeze_key(key: int) -> bool:
	var k := key - KEY_1
	if k >= 0 and k < PERKS.size():
		var id: String = PERKS.keys()[k]
		var p: Dictionary = PERKS[id]
		if perk_level(id) >= p.max:
			_say("%s is maxed" % p.name)
		elif _meta_int("pearls") < perk_cost(id):
			_say("Need %d pearls" % perk_cost(id))
			sfx.play("deny")
		else:
			GameState.meta.pearls = _meta_int("pearls") - perk_cost(id)
			var perks: Dictionary = GameState.meta.get("perks", {})
			perks[id] = perk_level(id) + 1
			GameState.meta.perks = perks
			sfx.play("buy")
			_log("PERK %s -> Lv%d" % [id, perks[id]])
			_refresh()
		refreeze_armed = false
		_update_refreeze()
		return true
	if key == KEY_ENTER or key == KEY_KP_ENTER:
		if not _can_refreeze():
			sfx.play("deny")
		elif not refreeze_armed:
			refreeze_armed = true
		else:
			_refreeze()
		_update_refreeze()
		return true
	return false

func _refreeze() -> void:
	_bank_and_reset()
	get_tree().reload_current_scene()

## Banks pearls, rolls the next lake's modifier and writes a fresh run to disk (split out so tests can call it).
func _bank_and_reset() -> void:
	var gain := pearls_pending()
	var m := GameState.meta
	m.pearls = _meta_int("pearls") + gain
	m.lakes = _meta_int("lakes") + 1
	if stats.ended > 0:
		m.lakes_cleared = _meta_int("lakes_cleared") + 1
		var best := float(m.get("best_time", 0.0))
		var t := float(stats.get("ended_time", play_time))
		if best <= 0.0 or t < best:
			m.best_time = t
	var mods: Array = LakeModelScript.MODS.keys().filter(func(k): return k != "")
	m.next_mod = mods.pick_random()
	_log("REFREEZE: +%d pearls, lake %d done in %s" % [gain, _meta_int("lakes"), _clock(play_time)])
	GameState.autosave = false
	GameState.reset(true)
	GameState.upgrades["bucket"] = mini(perk_level("pockets"), UPGRADES.bucket.max)
	GameState.upgrades["drill"] = mini(perk_level("hands"), UPGRADES.drill.max)
	GameState.currency = 40.0 * perk_level("seed")
	GameState.save_game(false)

# ---------- save / load ----------
func _fish_to(f: Dictionary) -> Dictionary:
	return {"n": f.name, "b": f.base, "m": f.mult, "g": f.gutted, "s": f.smoked, "l": f.get("len", 10.0)}

func _fish_from(d: Dictionary) -> Dictionary:
	var f := _make_fish(SPECIES[0])
	for s in SPECIES:
		if s.name == d.get("n", ""):
			f = _make_fish(s)
	f.base = d.get("b", f.base)
	f.mult = d.get("m", 1.0)
	f.gutted = d.get("g", false)
	f.smoked = d.get("s", false)
	if d.has("l"):
		var rr: Array = LENGTHS.get(f.name, [10.0, 20.0])
		f.len = d.l
		f.lenk = d.l / ((rr[0] + rr[1]) * 0.5)
	return f

func _on_about_to_save() -> void:
	var hl := []
	for t in holes:
		hl.append({"p": [t.pos.x, t.pos.z], "s": t.state, "st": t.stash.map(_fish_to), "sl": t.slot.map(_fish_to),
			"sm": t.smoke_t, "b": t.belt != null, "cn": t.belt != null and t.belt.get("cannery", false),
			"so": t.belt != null and t.belt.get("sorter", false)})
	# fish already drawn from the lake must not vanish: a fight in progress lies on the ice by its hole, fish riding belts
	# and fish mid-throw are written down with the multiplier they were owed
	var loose: Array = yard.fish.map(func(e): return {"f": _fish_to(e.f), "p": [e.pos.x, e.pos.z]})
	for t in holes:
		if t.state == "hole" and t.cast == 3:
			var tp: Vector3 = t.node.global_position
			var to_eye := (-Vector3(tp.x, 0, tp.z)).normalized()
			for f in t.hooked:
				loose.append({"f": _fish_to(f), "p": [tp.x + to_eye.x * 1.5, tp.z + to_eye.z * 1.5]})
	var pend: Array = []
	for it in belt_fish:
		pend.append({"f": _fish_to(it.f), "m": _belt_mult() * _belt_flag_mult(it.belt, it.f)})
	for rec in flying:
		pend.append({"f": _fish_to(rec.f), "m": rec.m})
	var p: Node3D = $Player
	GameState.extra = {"holes": hl, "stats": stats, "goals": goal_done, "unlocked": unlocked, "journal": journal, "records": records, "tips": guide.to_dict(),
		"carry": carry.map(_fish_to), "loose": loose, "pending": pend, "tool": tool, "pos": [p.position.x, p.position.z],
		"yaw": p.rotation.y, "pitch": cam.rotation.x,
		"day": day_t, "time": play_time,
		"depots": depots.map(func(d): return [d.pos.x, d.pos.z]), "rigs": rigs.map(func(rg): return [rg.pos.x, rg.pos.z]),
		"order": order, "orders_done": orders_done, "lake": model.to_dict()}

func _restore(d: Dictionary) -> bool:
	restoring = true
	var ok := _restore_inner(d)
	restoring = false
	return ok

func _restore_inner(d: Dictionary) -> bool:
	if d.is_empty():
		return false
	if d.has("lake"):
		model.from_dict(d.lake)
	for k in d.get("stats", {}):
		stats[k] = d.stats[k]
	var st_saved := eye_stage()
	eye_seen_stage = st_saved   # so nothing restored below can look like a new stage
	var g: Array = d.get("goals", [])
	for i in mini(g.size(), goal_done.size()):
		goal_done[i] = g[i]
	for k in d.get("unlocked", {}):
		unlocked[k] = d.unlocked[k]
	guide.from_dict(d.get("tips", null))
	for k in d.get("records", {}):
		records[k] = float(d.records[k])
	for k in d.get("journal", {}):
		journal[k] = int(d.journal[k])
	for fd in d.get("carry", []):
		carry.append(_fish_from(fd))
	var od0: Dictionary = d.get("order", {})   # the open order is back before any restored fish is delivered
	if not od0.is_empty():
		order = od0
		order.have = int(order.get("have", 0))
		order.need = int(order.get("need", 3))
		order.reward = int(order.get("reward", 10))
	orders_done = int(d.get("orders_done", 0))
	for ld in d.get("loose", []):
		if yard.count() >= FishYard.MAX_LOOSE:   # a save can hold more than the ice does (fights, old saves): the rest are paid in full
			_settle_fish(_fish_from(ld.f), EYE_MULT)
			continue
		yard.spawn(_fish_from(ld.f), Vector3(ld.p[0], FishYard.GROUND, ld.p[1]), Vector3.ZERO)
	for hd in d.get("holes", []):
		var t := _make_hole(Vector3(hd.p[0], 0.0, hd.p[1]), false)
		if t.is_empty():
			continue
		match hd.get("s", ""):
			"auto":
				_build_auto(t, false)
				if hd.get("b", false):
					_build_belt(t, false)
					if hd.get("cn", false):
						_install_machine(t, "cannery", false)
					if hd.get("so", false):
						_install_machine(t, "sorter", false)
			"smoker": _build_smoker(t)
			"table": _build_table(t)
		for fd in hd.get("st", []):
			t.stash.append(_fish_from(fd))
		for fd in hd.get("sl", []):
			t.slot.append(_fish_from(fd))
		t.smoke_t = hd.get("sm", 0.0)
	for dp in d.get("depots", []):
		_build_depot(Vector3(dp[0], 0.0, dp[1]), false)
	for rp in d.get("rigs", []):
		_build_rig(Vector3(rp[0], 0.0, rp[1]), false)
	tool = clampi(int(d.get("tool", 0)), 0, TOOLS.size() - 1)
	day_t = d.get("day", 0.0)
	play_time = float(d.get("time", 0.0))
	for pd in d.get("pending", []):   # paid now, quietly: they were already out of the lake when the game was saved (orders first, so they count)
		_settle_fish(_fish_from(pd.f), float(pd.m))
	_reward_stages_quietly(st_saved, eye_stage())
	var pos: Array = d.get("pos", [0.0, 0.0])
	$Player.position = Vector3(pos[0], $Player.position.y, pos[1])
	$Player.rotation.y = d.get("yaw", 0.0)
	cam.rotation.x = d.get("pitch", cam.rotation.x)
	return true

## A fish that reaches the Eye with no ceremony (a save/restore or offline delivery): pays and counts, nothing more.
func _settle_fish(f: Dictionary, mult: float, quiet := true, count_order := true) -> float:
	var before := eye_stage()
	stats.eye_fed += 1
	var worth: float = f.base * f.mult * sale_mult() * mult
	if count_order:   # (offline deliveries do not feed Olga's orders: no burst of banners and sounds on load)
		_order_progress(f)   # first: paying coins refreshes the goals, which may drop an order this very fish completes
	GameState.add(worth)
	stats.earned += worth
	if quiet and eye_stage() > before:   # price the next fish with whatever this one just woke (the awakened bonus, for one)
		_reward_stages_quietly(before, eye_stage())
	return worth

## Eye stages crossed without being there to see them (offline, a restored save) still pay out exactly once.
func _reward_stages_quietly(from_stage: int, to_stage: int) -> void:
	if to_stage <= from_stage:
		return
	for st in range(from_stage + 1, to_stage + 1):
		_log("EYE stage %d (quiet)" % st)
		if st >= EYE_STAGES.size() and stats.awakened == 0:
			stats.awakened = 1
			GameState.meta.pearls = _meta_int("pearls") + AWAKEN_PEARLS
			_log("EYE AWAKE (quiet)")
			GameState.meta["awaken_seen"] = true
			quiet_notice = "The Eye woke while you were away!  +%d%% fish value, +%d pearls." % [int(AWAKEN_BONUS * 100.0), AWAKEN_PEARLS]
	eye_seen_stage = to_stage
	scenery.set_eye_stage(to_stage)
	scenery.set_eye_open(eye_open_frac())

# auto-rods keep working while you're away (capped at 8 hours)
func _offline(away: float) -> void:
	away = minf(away, 8.0 * 3600.0)
	if away < 30.0 or (stats.autos <= 0 and rigs.is_empty()):
		return
	var st0 := eye_stage()
	var earned := 0.0
	var stashed := 0
	for rg in rigs:  # ice-breakers keep working, at 40% of their live pace
		var rb := away
		while rb > 0.0:
			var best := _rig_best(rg)
			if best.x == 9999:
				break
			var pseudo := {"c": best, "node": rg.node}
			var rf := _draw_fish(pseudo)
			if rf.is_empty():
				break
			earned += _settle_fish(rf, _belt_mult() * _belt_flag_mult(rg.belt, rf), true, false)
			_after_draw(pseudo)
			rb -= (RIG_INTERVAL * model.wait_factor(best) * 0.6 + 0.6) * 2.5
	for t in holes:
		if t.state != "auto":
			continue
		var budget := away
		while budget > 0.0 and model.tile_left(t.c) > 0:
			budget -= (AUTO_WAIT[0] + AUTO_WAIT[1]) * 0.5 * bite_mult() * model.wait_factor(t.c)
			if t.belt != null:
				var f := _draw_fish(t)
				if f.is_empty():
					break
				earned += _settle_fish(f, _belt_mult() * _belt_flag_mult(t.belt, f), true, false)
				_after_draw(t)
			elif t.stash.size() < STASH_MAX:
				var f2 := _draw_fish(t)
				if f2.is_empty():
					break
				t.stash.append(f2)
				stashed += 1
				_after_draw(t)
			else:
				break
	if earned > 0.0:   # (each delivery was already paid by _settle_fish)
		_say_notice("Welcome back! Your belts and rigs fed the Eye while you were away: +%d coins." % floor(earned))
	elif stashed > 0:
		_say_notice("Welcome back! Your auto-rods stashed %d fish while you were away." % stashed)
	_reward_stages_quietly(st0, eye_stage())
	eye_seen_stage = eye_stage()
	scenery.set_eye_open(eye_open_frac())
	_refresh()

# ---------- input ----------
func _new_game() -> void:
	var keep: Dictionary = GameState.meta.get("settings", {})   # your sliders are not progress
	GameState.autosave = false
	GameState.delete_save()
	GameState.reset()
	if not keep.is_empty():
		GameState.meta["settings"] = keep
	get_tree().reload_current_scene()

func _unhandled_input(event: InputEvent) -> void:
	if guide.intro_active:
		if guide.intro_t > guide.skip_after and ((event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_E])):
			guide.skip_intro()
		return
	if event is InputEventKey and event.keycode == KEY_F and not event.echo and _cap():
		if event.pressed:
			_start_kick()
		else:
			_release_kick()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if refreeze_panel.visible:
			if _refreeze_key(event.keycode):
				return
		if event.keycode == KEY_R:
			_toggle_refreeze()
			return
		if event.keycode == KEY_TAB:
			refreeze_panel.visible = false
			journal_panel.visible = not journal_panel.visible
			if journal_panel.visible:
				_update_journal()
			return
		if event.keycode == KEY_F2:
			GameState.add(1000.0)
			_say("[debug] +1000 coins")
			return
		if event.keycode == KEY_F3:
			for u in unlocked:
				unlocked[u] = true
			_refresh()
			_say("[debug] everything unlocked")
			return
		if event.keycode == KEY_F4:
			day_t = fmod(day_t + 0.125, 1.0)
			_say("[debug] time of day skipped")
			return
		if event.keycode == KEY_H:
			guide.ping()
			return
		if event.keycode == KEY_V:
			_toggle_ride()
			return
		if event.keycode == KEY_E:
			_pick_up_fish()
			return
		if event.keycode == KEY_Q and tool == 6:
			build_item = (build_item + 1) % BUILD_ITEMS.size()
			_say("Build: %s (%d coins)" % [BUILD_ITEMS[build_item], _build_cost(build_item)])
			_refresh()
			return
		if event.keycode == KEY_M:
			_say("Sound off" if sfx.toggle_mute() else "Sound on")
			return
		if event.keycode == KEY_N and not _cap():
			if reset_armed_t > 0.0:
				_new_game()
			else:
				reset_armed_t = 4.0
				_say("Press N again to ERASE ALL progress (pearls and perks too) and start over.")
			return
		var k: int = event.keycode - KEY_1
		if k >= 0 and k < TOOLS.size():
			if _tool_unlocked(k):
				tool = k
				_refresh()
			else:
				_say("Locked - complete goals to unlock.")
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and _cap():
		if event.pressed:
			_start_kick()
		else:
			_release_kick()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and _cap() \
			and not refreeze_panel.visible:
		_click(_aim())

func _spend(cost: float) -> bool:
	if GameState.currency < cost:
		_say("Need %d coins" % cost)
		sfx.play("deny")
		return false
	sfx.play("buy")
	_kick_tool(1.0)
	GameState.currency -= cost
	GameState.currency_changed.emit(GameState.currency)
	return true

func _click(a: String) -> void:
	if a == "olga":
		_talk_olga()
		return
	if a == "eye":
		_feed_by_hand()
		return
	if a.begins_with("depot:"):
		var di := int(a.substr(6))
		if di >= 0 and di < depots.size():
			_use_depot(depots[di])
		return
	if a.begins_with("rig:"):
		var rg := _rig_of(a)
		if not rg.is_empty() and _rig_best(rg).x == 9999:
			_pick_up_rig(rg)
		else:
			_say("The ice-breaker is hard at work.")
		return
	if a.begins_with("buy:"):
		_buy(a.substr(4))
		return
	if a == "ice":
		var c := _cell_at(aim_pos)
		if tiles.has(c) and tiles[c].state != "platform" and not model.sectors[tiles[c].sector].unlocked:
			_say("Locked - clear a neighbouring sector first.")
			sfx.play("deny")
		elif tool == 6 and _tool_unlocked(6):
			var bp := Vector3(aim_pos.x, 0.0, aim_pos.z)
			if build_item <= 1:
				_say("Click an Auto-Rod that has a belt to add a %s." % BUILD_ITEMS[build_item])
			elif build_item == 2:
				if _can_place_at(bp, 2.6):
					_build_depot(bp)
				else:
					_say("Can't build a depot there.")
					sfx.play("deny")
			else:
				if _can_place_at(bp, 6.0):
					_build_rig(bp)
				else:
					_say("Can't build an ice-breaker there.")
					sfx.play("deny")
		elif tool >= 2:
			_say("Build that on a hole you've already drilled.")
		return
	var t := _hole_of(a)
	if t.is_empty():
		return
	match t.state:
		"hole":
			if t.cast == 3:
				return
			if t.cast == 2:
				_hook(t)
			elif t.cast == 1:
				_end_cast(t)
				_say("Too early!")
			elif _emptied(t) and tool == 3 and _tool_unlocked(3):
				if _spend(smoker_cost()):
					_build_smoker(t)
					_refresh()
			elif _emptied(t) and tool == 4 and _tool_unlocked(4):
				if _spend(table_cost()):
					_build_table(t)
					_refresh()
			elif tool == 1:
				if model.tile_left(t.c) == 0:
					_say("This patch is fished out.")
					return
				for h in holes:
					if h != t and h.state == "hole" and h.cast == 3:
						_say("Finish landing this fish first.")
						return
				_cast(t)
			elif tool == 2 and _tool_unlocked(2):
				if _spend(auto_cost()):
					_build_auto(t)
					_refresh()
			elif tool == 5:
				_say("Build an Auto-Rod on this hole first (tool 3), then lay a belt.")
		"auto":
			if tool == 6 and _tool_unlocked(6):
				if build_item <= 1:
					_install_machine(t, "cannery" if build_item == 0 else "sorter")
				else:
					_say("Depots and ice-breakers go on open ice.")
				return
			if tool == 5 and _tool_unlocked(5) and t.belt == null:
				_build_belt(t)
				return
			if t.stash.is_empty() and model.tile_left(t.c) == 0:
				_pickup_auto(t)
				return
			if t.stash.is_empty():
				_say("Belt running" if t.belt != null else "Stash is empty")
				return
			var hp: Vector3 = t.node.global_position
			var to_eye := (-Vector3(hp.x, 0.0, hp.z)).normalized()
			while not t.stash.is_empty():   # what fits goes in your hands; the rest spills onto the ice, toward the Eye
				var sf: Dictionary = t.stash.pop_front()
				if free_space() > 0:
					_add_carry(sf)
				else:
					yard.spawn(sf, hp + Vector3(0, 0.4, 0), to_eye.rotated(Vector3.UP, randf_range(-0.6, 0.6)) * randf_range(2.0, 3.2) + Vector3(0, 4.5, 0))
			_refresh_view()
			_refresh()
		"smoker":
			_use_smoker(t)

func _pickup_auto(t: Dictionary) -> void:
	var refund := _refund()
	if t.belt != null:
		refund += int(0.6 * t.belt.cost)
		_remove_belt(t)
	if t.extra:
		t.extra.queue_free()
		t.extra = null
	if t.tag:
		t.tag.queue_free()
		t.tag = null
	t.arm = null
	t.state = "hole"
	t.cast = 0
	GameState.add(refund)
	_say("Picked up the Auto-Rod (refund %d). Build it on a fresh hole." % refund)
	sfx.play("buy")
	_paint_tile(tiles[t.c])
	_update_shadows(tiles[t.c])
	_refresh()

func _use_smoker(t: Dictionary) -> void:
	if t.slot.is_empty():
		if carry.is_empty():
			_say("Carry fish here to smoke them")
			return
		var n := mini(carry.size(), SMOKER_SLOTS)
		for i in n:
			t.slot.append(carry.pop_back())
		t.smoke_t = SMOKE_TIME
		_refresh_view()
		_refresh()
	elif t.smoke_t <= 0.0:
		var n := mini(t.slot.size(), free_space())
		if n == 0:
			_say("Hands full")
			return
		for i in n:
			var f: Dictionary = t.slot.pop_front()
			if not f.smoked:
				f.smoked = true
				f.mult *= SMOKE_MULT
			carry.append(f)
		stats.smokes += 1
		_float_text(t.node.global_position + Vector3(0, 1.2, 0), "smoked x%.1f" % SMOKE_MULT, Color(1, 0.8, 0.5))
		_refresh_view()
		_refresh()

## The fight is over: the fish leaps out of the hole in an arc and lands in your hands.
func _catch(t: Dictionary) -> void:
	var got: Array = t.hooked
	_end_cast(t)
	if got.is_empty():
		return
	if combo_t > 0.0:
		combo += 1
	else:
		combo = 1
	combo_t = COMBO_WINDOW
	var bonus := 1.0 + 0.1 * mini(combo - 1, 10)
	var best: Dictionary = {}
	var new_record := false
	var new_species := false
	for f in got:
		f.base *= bonus
		stats.caught += 1
		if f.get("new", false) or journal.get(f.name, 0) == 1:
			new_species = new_species or journal.get(f.name, 0) == 1
		if f.get("len", 0.0) > records.get(f.name, 0.0):
			new_record = new_record or records.has(f.name)
			records[f.name] = f.len
		if best.is_empty() or f.base > best.base:
			best = f
	_launch_catch(t, got, best)
	_show_card(best, got.size(), new_species, new_record)
	sfx.play("rare" if best.base >= 5.0 else "catch")
	shake = maxf(shake, 0.07 if best.base >= 5.0 else 0.025)
	_kick_tool(-1.0)
	if best.name == "Old Boot":
		_say("Olga will love this... an Old Boot.")
	_after_draw(t)
	_refresh()

func _hand_point() -> Vector3:
	return cam.global_position + cam.global_basis * Vector3(0.1, -0.3, -0.7)

func _launch_catch(t: Dictionary, got: Array, best: Dictionary) -> void:
	var hole_pos: Vector3 = t.node.global_position
	var inten := _fight_intensity(best)
	FishingFX.splash(t.node, Vector3(0, 0.2, 0), int(18 + 10 * inten), 1.3)
	FishingFX.ripple(t.node, Vector3(0, 0.1, 0), 2.6, Color(0.85, 0.97, 1.0), 1.1, 0.9)
	sfx.play("splash")
	if _species_value(best.name) >= 14.0:
		FishingFX.beam(self, hole_pos, best.color, 5.0 + inten * 2.0)
		FishingFX.ripple(t.node, Vector3(0, 0.1, 0), 4.5, best.color, 1.4, 1.0)
		_burst(hole_pos + Vector3(0, 0.6, 0), best.color, 16, 4.5, 1.0, 0.07)
	var to_player: Vector3 = $Player.global_position - hole_pos
	to_player.y = 0.0
	to_player = to_player.normalized() if to_player.length() > 0.1 else Vector3.RIGHT
	# a catch tumbles out mostly toward the Eye (the lesson is "push it in"), a little toward you so it is never far from your boots
	var to_eye := (-Vector3(hole_pos.x, 0.0, hole_pos.z))
	to_eye = to_eye.normalized() if to_eye.length() > 0.1 else to_player
	to_player = (to_eye * 0.65 + to_player * 0.35).normalized()
	for i in got.size():
		var f: Dictionary = got[i]
		# out of the hole in an arc, toward you (a little wild), then it falls, bounces and slides
		var dir := to_player.rotated(Vector3.UP, randf_range(-0.5, 0.5) + 0.35 * (i % 3 - 1))
		var up := 6.0 + inten * 0.6
		var out := randf_range(2.2, 3.6) + 0.5 * i
		var e := yard.spawn(f, hole_pos + Vector3(0, 0.3, 0), dir * out + Vector3(0, up, 0))
		e.spin = randf_range(-12.0, 12.0)
	sfx.play("plop", -4.0, randf_range(1.0, 1.3))
	view_pop = 1.0

func _rarity(name: String) -> Array:
	var v := _species_value(name)
	if v < 2.5: return ["COMMON", Style.CREAM]
	if v < 6.0: return ["UNCOMMON", Color(0.62, 0.92, 0.5)]
	if v < 20.0: return ["RARE", Color(0.45, 0.78, 1.0)]
	if v < 100.0: return ["EPIC", Color(0.82, 0.58, 1.0)]
	return ["LEGENDARY", Style.AMBER]

func _show_card(best: Dictionary, count: int, new_species: bool, new_record: bool) -> void:
	var rar := _rarity(best.name)
	card_rarity.text = "%s%s" % [rar[0], "  -  NEW SPECIES" if new_species else ""]
	card_rarity.add_theme_color_override("font_color", rar[1])
	card_name.text = best.name
	card_name.add_theme_color_override("font_color", best.color.lerp(Color.WHITE, 0.35))
	var extra := ""
	if count > 1:
		extra = "   +%d more" % (count - 1)
	card_info.text = "%.1f cm  -  worth %d%s%s" % [best.get("len", 0.0), floor(best.base * best.mult * sale_mult()), "   NEW RECORD" if new_record else "", extra]
	card_panel.visible = true
	card_panel.pivot_offset = card_panel.size * 0.5
	if card_tween:
		card_tween.kill()
	card_panel.modulate.a = 0.0
	card_panel.scale = Vector2(0.85, 0.85)
	card_tween = create_tween().set_parallel(true)
	card_tween.tween_property(card_panel, "modulate:a", 1.0, 0.18)
	card_tween.tween_property(card_panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	card_tween.chain().tween_interval(2.3)
	card_tween.chain().tween_property(card_panel, "modulate:a", 0.0, 0.6)

func _buy(id: String) -> void:
	var u: Dictionary = UPGRADES[id]
	if not unlocked[id]:
		_say("Locked - complete goals to unlock.")
		return
	if GameState.level(id) >= u.max:
		_say("%s is maxed" % u.name)
		return
	if not GameState.try_buy(id, u.base, u.growth):
		_say("Not enough coins")
		sfx.play("deny")
		return
	sfx.play("buy")
	_log("BUY %s -> Lv%d" % [id, GameState.level(id)])
	if id == "bucket":
		_refresh_view()
		_say("Olga: Now you can carry %d at a time." % capacity())
	_refresh()
