extends Node3D
## First-person ice fishing on a hex lake.
##
## STORY: Olga has watched the Eye under Hush Lake for most of her life. She does not buy fish:
## she talks, hints and remembers. YOU feed the Eye, which pays in coins as it wakes.
## You carry three things at a time (three slots: tools, fish, buckets). Buckets (shop) hold many fish and can be set down anywhere;
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
const CANNERY_MULT := 1.5                   # a cannery on a belt: every fish riding it is worth x1.5
const SORTER_MULT := 1.6                    # a sorter: fish worth 5+ get x1.6
const DEPOT_MULT := 1.05                    # a depot's sled run pays a little less than hand-feeding the Eye
const BUILD_ITEMS := ["Cannery", "Sorter", "Depot", "Ice-Breaker", "Bait Grinder", "Wind Fan"]
const BAIT_SECS := 12.0      # a fish ground into bait: 12 s of faster bites, plus 1.5 s per coin of base value (up to 30 s a fish)
const BAIT_MAX := 180.0
const BAIT_MULT := 0.6       # bites come in 60% of the time while there is bait
const FAN_REACH := 11.0      # a fan blows this far along the ice
const FAN_PUSH := 11.0
const MAX_GRINDERS := 3
const MAX_FANS := 4
const FEED_NOTES := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21]   # semitones: a hand-fed streak climbs a pentatonic scale
const KICK_MIN := 7.0                                    # a tap kick sends a fish ~8 m over the ice
const KICK_BASE_MAX := 16.0                               # a fully charged kick (more with Kick Power)
const KICK_CHARGE_TIME := 0.9
const KICK_REACH := 3.6
const GRAB_REACH := 5.5          # you can grab a fish this far away, in front of the crosshair
const THROW_MIN := 7.0
const THROW_BASE_MAX := 30.0
const THROW_LIFT := 0.38         # radians added to your look pitch: a throw leaves the hand on a lob (0.38 rad = 22 degrees)
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
	"pockets": {"name": "Warm Pockets", "desc": "start each lake with +1 bucket", "cost": 2, "max": 3},
	"seed":    {"name": "Seed Money",   "desc": "start each lake with +40 coins",      "cost": 1, "max": 5},
	"favour":  {"name": "Olga's Favour", "desc": "+10% sale value, always",            "cost": 3, "max": 5},
	"hands":   {"name": "Quick Hands",  "desc": "start with +1 drill speed level",     "cost": 2, "max": 3},
	"lantern": {"name": "Lantern Lore", "desc": "visitor fish come 25% more often",    "cost": 3, "max": 3},
	"ears":    {"name": "Keen Ears",    "desc": "keepsakes surface 20% more often",    "cost": 2, "max": 3},
	"coils":   {"name": "Spare Coils",  "desc": "start each lake with +1 Overdrive",   "cost": 4, "max": 3},
}
const SECTOR_PERK := 0.02   # +2% sale value per cleared sector
const COMBO_WINDOW := 14.0   # long enough to push a catch to the Eye between casts
const BUCKET_CAPS := [4, 6, 9, 13, 18, 25]   # fish one bucket holds, by Bucket Size level
const RANGE_ITEM := 5.5     # you can pick up a tool or bucket this far away (looking at it)
const DROP_REACH := 1.7     # Q puts what is in your hand down this far in front of you
const SWEEP_REACH := 3.5
const RACK_BEARING := -46.0   # the tool rack stands by Olga's hut
const RACK_RADIUS := 24.0
const TOOLS := ["Drill", "Rod", "Auto-Rod", "Smoker", "Gut Table", "Belt", "Build"]
const TOOL_UNLOCK := ["", "", "t_auto", "t_smoker", "t_table", "t_belt", "t_build"]

const SPECIES := [
	{"name": "Minnow",       "value": 1.0,   "w": 60.0, "color": Color(0.75, 0.8, 0.85)},
	{"name": "Perch",        "value": 2.0,   "w": 22.0, "color": Color(0.55, 0.84, 0.88)},
	{"name": "Silver Pike",  "value": 5.0,   "w": 9.0,  "color": Color(0.85, 0.9, 1.0)},
	{"name": "Golden Trout", "value": 14.0,  "w": 3.0,  "color": Color(1.0, 0.8, 0.25)},
	{"name": "Old Boot",     "value": 0.5,   "w": 3.0,  "color": Color(0.4, 0.28, 0.2)},
	{"name": "Old Coin",     "value": 30.0,  "w": 1.8,  "color": Color(0.95, 0.75, 0.2)},
	{"name": "Glass Pearl",  "value": 90.0,  "w": 0.7,  "color": Color(0.7, 0.95, 1.0)},
	{"name": "Ancient Fish", "value": 250.0, "w": 0.5,  "color": Color(0.4, 1.0, 0.8)},
	# visitors (visitors.gd): never in the lake's stock; the right hour or weather swaps one in when you draw a fish
	{"name": "Dawn Salmon",  "value": 11.0,  "w": 0.0,  "color": Color(1.0, 0.55, 0.45)},
	{"name": "Ghost Carp",   "value": 9.0,   "w": 0.0,  "color": Color(0.85, 0.92, 0.95)},
	{"name": "Lantern Eel",  "value": 12.0,  "w": 0.0,  "color": Color(1.0, 0.72, 0.3)},
	{"name": "Frost Gar",    "value": 20.0,  "w": 0.0,  "color": Color(0.7, 0.85, 1.0)},
	{"name": "Aurora Char",  "value": 55.0,  "w": 0.0,  "color": Color(0.5, 1.0, 0.75)},
	{"name": "Eye Tetra",    "value": 40.0,  "w": 0.0,  "color": Color(0.3, 1.0, 0.95)},
]

# shop: "start" = available from the beginning, otherwise unlocked by a goal
const UPGRADES := {
	"bucket":   {"name": "Bucket",      "base": 6.0,   "growth": 1.9,  "max": 5, "start": true, "desc": "another bucket: place them around"},
	"pail":     {"name": "Bucket Size", "base": 35.0,  "growth": 2.1,  "max": 5, "desc": "every bucket holds more"},
	"bait":     {"name": "Bait",        "base": 10.0,  "growth": 1.6,  "max": 8, "start": true, "desc": "bites come sooner"},
	"boots":    {"name": "Boots",       "base": 12.0,  "growth": 1.8,  "max": 5, "start": true, "desc": "walk faster"},
	"drill":    {"name": "Drill Speed", "base": 18.0,  "growth": 1.6,  "max": 6, "start": true, "desc": "drill & gut faster"},
	"lines":    {"name": "Extra Line",  "base": 14.0,  "growth": 1.9,  "max": 4, "desc": "+1 fish per bite"},
	"market":   {"name": "Lure Polish", "base": 25.0,  "growth": 1.85, "max": 12, "desc": "+10% fish value"},
	"sonar":    {"name": "Sonar",       "base": 40.0,  "growth": 2.0,  "max": 3, "desc": "see the fish under the ice"},
	"wide":     {"name": "Wide Drill",  "base": 60.0,  "growth": 2.2,  "max": 3, "desc": "drilling opens neighbours"},
	"snowmobile": {"name": "Snowmobile", "base": 90.0, "growth": 2.6, "max": 3, "desc": "V to ride: faster and faster"},
	"kick":     {"name": "Kick Power", "base": 20.0,  "growth": 1.8,  "max": 5, "start": true, "desc": "kicks send fish farther"},
	"overdrive": {"name": "Overdrive Coils", "base": 900.0, "growth": 2.4, "max": 5, "desc": "auto-rods and Ice-Breakers work 20% faster"},
	"conveyor": {"name": "Belt Motor",  "base": 140.0, "growth": 2.3,  "max": 4, "desc": "belts run faster, +15% value"},
}

# goals: stat keys are counters (stats[...]), "lvl:<upgrade>", "found:<species>", or "journal"
const GOALS := [
	{"text": "Drill your first hole", "stat": "holes", "target": 1, "reward": 4,
		"line": "Olga: Every last fish out of this lake, dear. Start with the Shallows. Cast a line with the Rod (2)."},
	{"text": "Catch a fish", "stat": "caught", "target": 1, "reward": 4,
		"line": "Olga: Now get it to the Eye, dear. Walk into it, kick it (right mouse), or grab it and throw."},
	{"text": "Feed a fish to the Eye", "stat": "eye_fed", "target": 1, "reward": 5,
		"line": "Olga: There. It looked at you, didn't it? Save up for a bucket at the stalls."},
	{"text": "Buy a Bucket", "stat": "lvl:bucket", "target": 1, "reward": 10,
		"line": "Olga: A bucket! Click fish into it, or throw them in. Buy more and set them around the ice.", "unlock": ["lines", "market", "pail"]},
	{"text": "Earn 50 coins", "stat": "earned", "target": 50, "reward": 15,
		"line": "Olga: A Builder's Kit now hangs on my rack. Its Auto-Rod will fish a hole for you. Click it to collect.", "unlock": ["t_auto"]},
	{"text": "Fish a patch empty", "stat": "tiles_cleared", "target": 1, "reward": 20,
		"line": "Olga: That patch is fished out. Sonar shows what's still under the ice.", "unlock": ["sonar"]},
	{"text": "Build an Auto-Rod", "stat": "autos", "target": 1, "reward": 30,
		"line": "Olga: Now the kit can lay a belt (B switches what it builds) to carry its catch straight into the Eye.", "unlock": ["t_belt"]},
	{"text": "Lay a belt to the Eye", "stat": "belts", "target": 1, "reward": 40,
		"line": "Olga: Watch them go. It is always hungry, that one."},
	{"text": "Feed the Eye 25 fish", "stat": "eye_fed", "target": 25, "reward": 60,
		"line": "Olga: ...Did it just blink? There's a snowmobile at the stalls now, and the kit builds bigger machines.", "unlock": ["snowmobile", "t_build"]},
	{"text": "Buy a Snowmobile", "stat": "lvl:snowmobile", "target": 1, "reward": 80,
		"line": "Olga: Press V to ride. Mind the ice, dear."},
	{"text": "Build a Cannery on a belt", "stat": "cans", "target": 1, "reward": 90,
		"line": "Olga: Canned fish fetch half again. B cycles what the kit builds."},
	{"text": "Build a Depot", "stat": "depots", "target": 1, "reward": 80,
		"line": "Olga: Drop fish at a depot and a sled runs them to the Eye. Less walking."},
	{"text": "Build an Ice-Breaker", "stat": "rigs", "target": 1, "reward": 400,
		"line": "Olga: ...That is a very large machine. It is eating the lake faster than I can count."},
	{"opt": true, "text": "Build a Bait Grinder", "stat": "grinders", "target": 1, "reward": 100,
		"line": "Olga: Throw it a fish and every bite comes sooner. Cheap fish, quick fish."},
	{"opt": true, "text": "Build a Wind Fan", "stat": "fans", "target": 1, "reward": 120,
		"line": "Olga: A fan out here blows them home for you. Put it where the walk is longest."},
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
		"line": "Olga: Its eyelid is all the way up now. Build more rigs. It wants more. And a man at the stalls sells coils: they make the machines work harder.", "unlock": ["overdrive"]},
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
var sector_view: SectorView
var sector_hud: Control
var sector_hud_label: Label
var sector_hud_dot: Panel
var sector_hud_t := 0.0
var sector_hud_last := ""
var lantern_idx := {}
var shadow_mat: StandardMaterial3D
var shoal_mesh: ArrayMesh
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
var tool_base_z := 0.0
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
var dressing: CampDressing   # props and lamp pools round the camp (camp_dressing.gd)
var hut_pos := Vector3.ZERO
var hut_node: Node3D
var weather: Weather
var living: LivingLake
var world_label: Label
var title: TitleScreen
var title_active := false
var title_t := 0.0
var title_hidden: Array = []
var title_resumed := false
var title_leave_t := 0.0
var title_mouse := Vector2.ZERO
var cine_eye := 0.0           # the Eye's lid during the opening scene (0 .. 0.1)
var opening: Opening
var sky_clock: HudWidgets.SkyClock
var world_t := 0.0
var session_t := 0.0
var inv := Inventory.new()   # your three slots and the one in your hand (see inventory.gd)
var tool := -1             # what the item in your hand lets you do: 0 drill, 1 rod, 2..6 a build mode (the builder's kit), -1 nothing
var bmode := 2             # which build the builder's kit is set to (an index into TOOLS, 2..6)
var return_slot := -1      # grabbing a fish puts it in your hand; when it leaves your hand you go back to this slot
var ground: Array = []     # tools and buckets lying on the ice: {id, item, node, pos, yaw}
var ground_serial := 0
var rack_mounts: Array = []   # the rack's three mounted tools (shown while the tool is on the rack)
var rack_pos := Vector3.ZERO
var journal := {}          # species name -> count
var stats := {"holes": 0, "caught": 0, "deliveries": 0, "earned": 0.0, "autos": 0, "smokes": 0, "gutted": 0, "tiles_cleared": 0, "sectors": 0, "ended": 0, "eye_fed": 0, "belts": 0, "cans": 0, "sorters": 0, "depots": 0, "rigs": 0, "rides": 0, "tithe": 0, "awakened": 0, "grinders": 0, "fans": 0, "grinds": 0, "ajar": 0}
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
var props: Array = []      # bait grinders and wind fans: {kind, pos, node, idx, part}
var bait_t := 0.0          # seconds of bait left: every bite (yours and the auto-rods') comes sooner
var bait_label: Label
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
var sign_descs := {}
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
var dock_panels: Array[PanelContainer] = []
var dock_icons: Array = []
var dock_keys: Array[Label] = []
var dock_badges: Array[Label] = []
var dock_name: Label
var dock_sig := ""
var dock_active_last := -1
var crosshair: HudWidgets.Crosshair
var carry_bar: ProgressBar
var eye_bar: ProgressBar
var eye_label: Label
var eye_next_label: Label
var start_panel: Control
var menu: MenuUI
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
var fx_shake := 1.0
var fx_bob := 1.0
var fx_punch := 1.0
var sun_light: DirectionalLight3D
var vignette_rect: ColorRect
var saved_label: Label
var saved_t := 0.0
var coins_shown := -1.0
var coins_target := 0.0
var eye_pulse_t := 0.0
var test_capture := false     # headless tools cannot capture the mouse: they ask the game to behave as if it were
var kick_rings: Array = []
var hold_block := false
var hold_node: Node3D           # the fish or bucket in your hand, in front of the camera
var hold_sig := ""              # what hold_node shows right now
var hold_sway := Vector2.ZERO   # the held fish lags behind when you turn
var prev_look := Vector2.ZERO
var arc_dots: Array = []        # the throw preview: dots along the arc
var arc_ring: MeshInstance3D    # ...and a ring where it will land
var tool_swap := 0.0
var pickup_from: Array = []
var restoring := false
var slide_snd_t := 0.0
var kick_boot: Node3D
var boot_tween: Tween
const HOLD_REST := Vector3(0.14, -0.34, -0.8)
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
	story = _story_from_meta()
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
	hold_node = Node3D.new()
	hold_node.position = HOLD_REST
	cam.add_child(hold_node)
	kick_boot = ToolModels.boot(cam)
	kick_boot.position = BOOT_REST
	_no_shadows(kick_boot)
	kick_boot.scale = Vector3.ONE * 0.55
	kick_boot.rotation_degrees = BOOT_ROT
	model = LakeModelScript.new()
	var fresh_lake := GameState.extra.is_empty()
	model.generate(randi(), String(GameState.meta.get("next_mod", "")) if fresh_lake else "", _meta_int("lakes") if fresh_lake else 0)
	_build_world()
	weather = Weather.new()
	living = LivingLake.new()
	add_child(living)
	living.setup(scenery, weather, hut_node)
	living.cracked.connect(_on_crack)
	living.sfx_cb = func(n): sfx.play(n, -9.0, randf_range(0.9, 1.1))
	living.owl_called.connect(func(): sfx.play("owl", -12.0, randf_range(0.9, 1.1)))
	living.crow_called.connect(func(): sfx.play("caw", -14.0, randf_range(0.85, 1.15)))
	yard = YardScript.new()
	add_child(yard)
	yard.obstacles = scenery.obstacles
	yard.eye_r = EYE_R
	yard.pupil_r = PUPIL_R
	yard.swallowed.connect(_on_fish_swallowed)
	yard.overflowed.connect(_on_fish_overflow)
	yard.sunk.connect(_on_fish_sunk)
	yard.edge_fn = scenery.edge_at
	yard.touched.connect(func(pos: Vector3, impact: float): _snow_fx(pos, 4 + int(impact), 0.5 + impact * 0.12))
	yard.trail.connect(func(pos: Vector3, speed: float):
		_snow_fx(pos + Vector3(0, 0.05, 0), 2, 0.4 + speed * 0.04)
		if slide_snd_t <= 0.0:
			slide_snd_t = 0.18
			sfx.play("slide", -10.0 + minf(speed, 14.0) * 0.4, randf_range(0.9, 1.15)))
	yard.kicked.connect(func(pos: Vector3, dir: Vector3, power: float): _snow_fx(pos - dir * 0.3, 7, 0.9 + power * 0.06))
	yard.touched.connect(func(p, impact): if impact > 3.0 and living: living.companion_notice(p))   # a fish hitting the ice: Juniper goes to look
	yard.landed.connect(func(_f, impact): sfx.play("thud", -12.0 + minf(impact, 9.0) * 0.8, randf_range(0.85, 1.25)))
	_build_ui()
	for c in model.tile_sector:
		_make_tile(c)
	_make_sector_patches()
	_setup_lanterns()
	var resumed := _restore(GameState.extra)
	if not resumed:
		_start_kit()
	_paint_all()
	GameState.currency_changed.connect(_on_currency_changed)
	_apply_settings()
	_refresh_view()
	_build_ride_view()
	_setup_belt_fish()
	eye_seen_stage = eye_stage()
	_refresh()
	sector_hud_t = 0.0
	_update_sector_hud(1.0)
	sfx.start_ambient()
	_log("--- session start (resumed=%s) ---" % resumed)
	var with_title := (not GameState.save_slot.begins_with("test") and (resumed or _meta_int("lakes") == 0)) or has_meta("force_title")
	if not resumed and _meta_int("lakes") > 0:
		stats["ajar"] = 1   # (a refrozen lake: you have seen the Eye open; no title, no sled)
	if resumed:
		_say_notice("Welcome back!")
		_offline(away)
		if with_title:
			_open_title(true)
	else:
		if _meta_int("lakes") > 0:
			_banner("%s #%d: %s" % [model.mod_info().name, _meta_int("lakes") + 1, model.mod_info().desc], Color(0.7, 0.9, 1.0))
		if not with_title:
			_say("Olga: The Eye wants feeding, dear. Hold click anywhere on the ice with the drill. Get what you catch into the Eye.")
		else:
			_open_title(false)

# ---------- the title screen ----------
## Hush Lake at dusk behind a frosted glass: the camera drifts, the Eye hums, the title forms. Play fades to black and starts the opening
## (a new game) or the "previously" beat (a save).
func _open_title(resumed: bool) -> void:
	title_active = true
	title_t = 0.0
	title_resumed = resumed
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # the cursor is free for the title buttons (the Player rig captures the mouse on its own at launch)
	$Player.set_process_unhandled_input(false)
	if not resumed:
		GameState.autosave = false   # a new game is not a save until the opening has finished: quitting early must not leave a half-started run
	guide.cam_home = cam.position   # (taken now: the title camera is about to take over)
	guide.cam_pitch = cam.rotation.x
	guide.cam_preset = true
	if not resumed:
		day_t = Opening.DUSK   # a new lake opens at the start of dusk and stays there through the opening
	title = TitleScreen.new()
	guide.ui_root.add_child(title)
	guide.ui_root.move_child(title, menu.get_index())   # (the settings and controls cards open above it)
	title.build(self, resumed)
	title.settings_pressed.connect(func(): menu.open_page("settings"))
	title.controls_pressed.connect(func(): menu.open_page("controls"))
	title.quit_pressed.connect(func():
		if GameState.autosave:
			GameState.save_game()
		get_tree().quit())
	title.left.connect(_title_go)
	title_hidden.clear()
	for c in guide.ui_root.get_children():   # a clean glass: no HUD behind the title
		if c is Control and c.visible and c != menu and c != title and not guide.own_controls().has(c):
			c.visible = false
			title_hidden.append(c)
	if not resumed:
		scenery.eye_prelude(true)   # the Eye holds its breath until the lid lifts in the opening
	view.visible = false   # (the first-person props belong to the player, not to the title camera)
	tool_view.visible = false
	sfx.set_hum(0.5)
	scenery.set_time(day_t)

func _title_go() -> void:
	title_active = false
	title_leave_t = 0.0
	guide.hidden_hud = title_hidden.duplicate()
	guide.hud_preset = true
	title_hidden.clear()
	if title_resumed:
		guide.want_previously = true
	else:
		guide.want_intro = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## Per frame while the title is up (and while it hands over to the opening).
func _tick_title(delta: float) -> void:
	if title_active:
		title_t += delta
		for c in title_hidden:
			if is_instance_valid(c):
				c.visible = false
		var vp := get_viewport().get_visible_rect().size
		var mp := get_viewport().get_mouse_position() / maxf(vp.x, 1.0)
		title_mouse = title_mouse.lerp(Vector2(clampf((mp.x - 0.5) * 2.0, -1.0, 1.0), clampf((get_viewport().get_mouse_position().y / maxf(vp.y, 1.0) - 0.5) * 2.0, -1.0, 1.0)), minf(1.0, delta * 3.0))
		var pose := opening.title_pose(title_t, title_mouse)
		cine_fov = CameraDirector.apply(cam, pose, title_t, fov_base)
		cam.fov = fov_base + cine_fov
		if int(title_t * 0.3) != int((title_t - delta) * 0.3):   # the Eye pulses with its own hum, softly
			scenery.eye_catch(Color(0.45, 0.9, 1.0), 0.1)
	elif title != null:
		title_leave_t += delta
		if guide.intro_active or title_leave_t > 4.0:   # the opening has taken over (or never started): the black cover can go
			title.queue_free()
			title = null

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
		l.no_depth_test = false   # a label behind a wall or a card stays behind it
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
	sm.sky_top_color = Color(0.08, 0.27, 0.42)
	sm.sky_horizon_color = Color(1.0, 0.64, 0.40)
	sm.ground_horizon_color = Color(0.98, 0.62, 0.5)
	sm.ground_bottom_color = Color(0.2, 0.45, 0.6)
	sm.sky_curve = 0.07          # the warm band hugs the horizon and the sky above it deepens into teal
	sm.ground_curve = 0.1
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR   # cool blue fill from the fog colour (set per hour in scenery): a sky-sourced fill took the orange horizon and turned the snow pink
	env.ambient_light_color = Color(0.4, 0.6, 0.75)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun_light = sun
	sun.light_color = Color(1.0, 0.75, 0.6)
	sun.shadow_enabled = true
	add_child(sun)
	# Olga's hut: local +Z faces the lake centre
	var hut := Node3D.new()
	hut.position = Vector3(sin(deg_to_rad(HUT_BEARING)) * HUT_RADIUS, 0.0, -cos(deg_to_rad(HUT_BEARING)) * HUT_RADIUS)
	add_child(hut)
	hut.look_at(Vector3(0, 0, 0), Vector3.UP, true)
	hut_pos = hut.global_position + hut.global_basis.z * 2.3 + Vector3(0, 1.1, 0)
	hut_node = hut
	_box(hut, Vector3(0, 1.5, 0), Vector3(5, 3, 4), Color(0.5, 0.31, 0.23))   # warm wood: the lit windows and door are the amber
	_box(hut, Vector3(0, 1.0, 2.05), Vector3(1.3, 2.0, 0.15), Color(1.0, 0.75, 0.35), "olga", 1.2)
	_box(hut, Vector3(0, 1.05, 2.45), Vector3(1.8, 0.12, 0.8), Color(0.3, 0.19, 0.13))  # her window counter
	_label3d(hut, Vector3(0, 2.7, 2.2), "OLGA'S FISH HUT", 0.011, false)
	_label3d(hut, Vector3(0, 2.3, 2.2), "knock to chat", 0.006, false)
	scenery = SceneryScript.new()
	add_child(scenery)
	scenery.build(env, sun, hut)
	dressing = CampDressing.new()
	dressing.build(self, scenery, hut, SceneryScript.SHOP_SPOTS)
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
		var l := Label3D.new()   # name, level and price: big enough to read from the next stall
		l.pixel_size = 0.0068
		l.font_size = 46
		l.autowrap_mode = TextServer.AUTOWRAP_OFF   # a title never wraps into the price row
		l.outline_size = 10
		l.line_spacing = -2.0
		l.position = Vector3(0, 0.42, 0.14)
		s.add_child(l)
		sign_labels[id] = l
		var ld := Label3D.new()   # the small print
		ld.pixel_size = 0.0068
		ld.font_size = 24
		ld.width = 520.0
		ld.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ld.outline_size = 8
		ld.modulate = Color(0.85, 0.88, 0.96)
		ld.line_spacing = -4.0
		ld.position = Vector3(0, -0.56, 0.14)
		s.add_child(ld)
		sign_descs[id] = ld
		scenery.decorate_stall(s, id)
	_build_rack()

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
		shadow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED   # (the silhouette is flat and seen from above or below)
	if shoal_mesh == null:   # a flat fish silhouette (body and forked tail): the shoal under the ice used to be shapeless dark blobs
		var pts := [Vector2(0.5, 0.0), Vector2(0.3, 0.14), Vector2(0.0, 0.19), Vector2(-0.25, 0.12), Vector2(-0.38, 0.04), Vector2(-0.56, 0.17),
			Vector2(-0.48, 0.0), Vector2(-0.56, -0.17), Vector2(-0.38, -0.04), Vector2(-0.25, -0.12), Vector2(0.0, -0.19), Vector2(0.3, -0.14)]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for k in pts.size():
			var q0: Vector2 = pts[k]
			var q1: Vector2 = pts[(k + 1) % pts.size()]
			for v in [Vector3.ZERO, Vector3(q1.x, 0, q1.y), Vector3(q0.x, 0, q0.y)]:
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
		shoal_mesh = st.commit()
	for i in 8:
		var m := MeshInstance3D.new()
		m.mesh = shoal_mesh
		m.scale = Vector3(1.5, 1.0, 1.5)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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

func _make_sector_patches() -> void:
	sector_view = SectorView.new()
	add_child(sector_view)
	sector_view.build(self)
	sector_patches = sector_view.patches

func _update_sector_patches() -> void:
	if sector_view:
		sector_view.refresh()

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

## The pill under the left card: the sector under the crosshair when you look at the ice, otherwise the one you stand on.
func _update_sector_hud(delta: float) -> void:
	sector_hud_t -= delta
	if sector_hud_t > 0.0:
		return
	sector_hud_t = 0.12
	var at: Vector3 = $Player.global_position
	if aim_flat < 60.0 and aim_pos != Vector3.ZERO:
		at = aim_pos
	var c := _cell_at(Vector3(at.x, 0.0, at.z))
	var id: Variant = model.tile_sector.get(c, null)
	var txt := ""
	var col := Style.AMBER
	if id == null:
		txt = "Open ice" if Vector2(at.x, at.z).length() < EYE_R + 2.0 else "Shore"
		col = Style.MUTED
	else:
		var sec: Dictionary = model.sectors[id]
		if not sec.unlocked:
			txt = "LOCKED  -  %s" % sec.name
			col = Color(0.92, 0.97, 1.0)
		elif sec.cleared:
			txt = "%s  -  cleared" % sec.name
			col = Color(0.95, 0.84, 0.55)
		else:
			txt = "%s  -  %d fish left" % [sec.name, sec.left]
			col = Style.AMBER
	if txt != sector_hud_last:
		sector_hud_last = txt
		sector_hud_label.text = txt
		(sector_hud_dot.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = col
		(sector_hud_dot.get_theme_stylebox("panel") as StyleBoxFlat).border_color = col.lightened(0.4)
	sector_hud.visible = not guide.intro_active and not title_active and reveal_t <= 0.0

func _update_sector_labels() -> void:   # (name kept: it refreshes everything that shows sector state)
	_update_lanterns()
	_update_sector_patches()

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
		var chunk := _box(node, Vector3(cos(ang), 0.12, sin(ang)) * randf_range(0.75, 1.0), Vector3.ONE * randf_range(0.15, 0.3), Color(0.78, 0.92, 1.0))
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
	t.tag.visibility_range_end = 14.0

func _build_smoker(t: Dictionary) -> void:
	t.state = "smoker"
	t.extra = Node3D.new()
	t.node.add_child(t.extra)
	t.extra.scale = Vector3.ONE * 1.5
	scenery.obstacles.append(Vector3(t.pos.x, t.pos.z, 1.5))   # the camera must not slide inside the walls
	yard.sinks.append({"pos": Vector3(t.pos.x, 0, t.pos.z), "r": 2.2, "h": 2.2, "id": "smoker:%d" % t.idx,
		"accept": func(): return t.state == "smoker" and t.slot.size() < SMOKER_SLOTS and (t.slot.is_empty() or t.smoke_t > 0.0)})
	var sp: Dictionary = MachineModels.smoker(t.extra)
	t.smoke_fx = sp.smoke
	_pop_in(t.extra)
	t.tag = _label3d(t.node, Vector3(0, 3.0, 0), "Smoker", 0.012)

func _build_table(t: Dictionary) -> void:
	t.state = "table"
	t.extra = Node3D.new()
	t.node.add_child(t.extra)
	t.extra.scale = Vector3.ONE * 1.5
	scenery.obstacles.append(Vector3(t.pos.x, t.pos.z, 1.3))
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
	vignette_rect = vig
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
	bait_label = _plain(left, 16, Style.AQUA)
	sky_clock = HudWidgets.SkyClock.new()
	left.add_child(sky_clock)
	world_label = _plain(left, 15, Style.MUTED)
	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.25)
	left.add_child(sep)
	eye_label = _plain(left, 17, Style.AQUA)
	eye_bar = Style.bar(Style.AQUA, 7.0)
	left.add_child(eye_bar)
	eye_next_label = _plain(left, 15, Style.CREAM)
	eye_next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	eye_next_label.custom_minimum_size = Vector2(270, 0)
	lake_label = _plain(left, 15, Style.MUTED)
	lake_label.custom_minimum_size = Vector2(270, 0)
	# the sector pill: always says which sector the crosshair (or your feet) is on, and whether it is open
	var pill_row := HBoxContainer.new()
	pill_row.add_theme_constant_override("separation", 8)
	sector_hud_dot = _dot(pill_row, Style.AMBER, 14)
	sector_hud_label = _plain(pill_row, 16, Style.CREAM)
	var sec_sep := HSeparator.new()
	sec_sep.modulate = Color(1, 1, 1, 0.25)
	left.add_child(sec_sep)
	left.add_child(pill_row)   # a row in the left card, so it can never overlap it
	sector_hud = pill_row
	left.move_child(lake_label, left.get_child_count() - 1)   # facts last, the sector row above them
	saved_label = Label.new()   # a small "Saved" tick in the corner after each autosave
	saved_label.text = "saved"
	saved_label.add_theme_font_size_override("font_size", 14)
	saved_label.add_theme_color_override("font_color", Style.MUTED)
	saved_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	saved_label.offset_left = -90.0
	saved_label.offset_top = -34.0
	saved_label.offset_right = -20.0
	saved_label.offset_bottom = -12.0
	saved_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	saved_label.modulate.a = 0.0
	ui.add_child(saved_label)
	msg_label = Label.new()
	msg_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	msg_label.anchor_top = 1.0
	msg_label.offset_top = -240.0
	msg_label.offset_bottom = -142.0
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
	# bottom middle: your three slots. The one in your hand is raised and ringed in amber, its name floats above
	var dock := VBoxContainer.new()
	dock.add_theme_constant_override("separation", 6)
	dock.anchor_left = 0.5
	dock.anchor_right = 0.5
	dock.anchor_top = 1.0
	dock.anchor_bottom = 1.0
	dock.offset_top = -20.0
	dock.offset_bottom = -20.0
	dock.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui.add_child(dock)
	dock_name = _plain(dock, 18, Style.AMBER)
	dock_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	dock.add_child(row)
	for i in Inventory.SLOTS:
		var sp := PanelContainer.new()
		sp.custom_minimum_size = Vector2(84, 80)
		sp.add_theme_stylebox_override("panel", Style.slot(false, true))
		row.add_child(sp)
		dock_panels.append(sp)
		var box := Control.new()
		box.custom_minimum_size = Vector2(64, 60)
		sp.add_child(box)
		var icon := HudWidgets.ItemIcon.new()
		icon.position = Vector2(9, 8)
		box.add_child(icon)
		dock_icons.append(icon)
		var kl := _plain(box, 14, Style.MUTED)
		kl.text = str(i + 1)
		kl.position = Vector2(0, -4)
		dock_keys.append(kl)
		var bl := _plain(box, 14, Style.CREAM)
		bl.position = Vector2(26, 42)
		bl.size = Vector2(38, 18)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		dock_badges.append(bl)
	journal_label = Label.new()
	journal_label.add_theme_font_size_override("font_size", 24)
	var jbox := VBoxContainer.new()
	jbox.add_theme_constant_override("separation", 8)
	jbox.add_child(journal_label)
	journal_grid = GridContainer.new()
	journal_grid.columns = 5
	journal_grid.add_theme_constant_override("h_separation", 18)
	journal_grid.add_theme_constant_override("v_separation", 4)
	var jscroll := ScrollContainer.new()   # fourteen species with a note each: scroll rather than overflow a small window
	jscroll.custom_minimum_size = Vector2(0, 520)
	jscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	jscroll.add_child(journal_grid)
	jbox.add_child(jscroll)
	var jhint := Label.new()
	jhint.text = "Tab to close"
	jhint.add_theme_font_size_override("font_size", 14)
	jhint.add_theme_color_override("font_color", Style.MUTED)
	jbox.add_child(jhint)
	journal_panel = _center_panel(ui, jbox)
	journal_panel.visible = false
	letters_panel = LettersPanel.new()
	var lcc := CenterContainer.new()
	lcc.set_anchors_preset(Control.PRESET_FULL_RECT)
	lcc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lcc.add_child(letters_panel)
	ui.add_child(lcc)
	letters_panel.read_letter.connect(_on_letter_read)
	peer = PeerView.new()
	for sp in SPECIES:
		peer.colors[sp.name] = sp.color
	ui.add_child(peer)
	ledger_panel = LedgerPanel.new()
	var lgc := CenterContainer.new()
	lgc.set_anchors_preset(Control.PRESET_FULL_RECT)
	lgc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lgc.add_child(ledger_panel)
	ui.add_child(lgc)
	dream = DreamOverlay.new()
	add_child(dream)
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
	opening = Opening.new()
	add_child(opening)
	opening.setup(self, guide)
	guide.opening = opening
	_ignore_mouse(ui)
	menu = MenuUI.new()   # the title / pause menu sits on top of everything and takes clicks
	ui.add_child(menu)
	menu.build(self)
	start_panel = menu
	menu.resume_requested.connect(func(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	menu.new_run_requested.connect(_new_game)
	menu.quit_requested.connect(func():
		GameState.save_game()
		get_tree().quit())

## Writes the settings to disk right away (they live in the permanent meta, so they survive starting a new run).
func save_settings() -> void:
	if GameState.autosave:
		GameState.save_game(false)

func _fmt_num(v: float) -> String:   # 12345 -> "12,345"
	var n := int(v)
	var t := str(absi(n))
	var out := ""
	for i in t.length():
		if i > 0 and (t.length() - i) % 3 == 0:
			out += ","
		out += t[i]
	return ("-" if n < 0 else "") + out

func _set_setting(key: String, v: float) -> void:
	GameSettings.set_value(key, v)
	_apply_settings()

func _apply_settings() -> void:
	if scenery != null and scenery.cinematic != GameSettings.on("cinematic"):
		scenery.apply_cinematic(GameSettings.on("cinematic"))
	var pl: Node = get_node_or_null("Player")
	if pl:
		pl.sensitivity = GameSettings.get_value("sens")
		pl.invert_y = GameSettings.on("inv")
	fov_base = GameSettings.get_value("fov")
	fx_shake = GameSettings.get_value("shake")
	fx_bob = GameSettings.get_value("bob")
	fx_punch = GameSettings.get_value("punch")
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(GameSettings.get_value("vol"), 0.0001)))
	if sfx:
		sfx.set_levels(GameSettings.get_value("sfx"), GameSettings.get_value("amb"))
		sfx.score.set_level(GameSettings.get_value("music"))
	get_window().content_scale_factor = GameSettings.get_value("ui")
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if GameSettings.on("full") else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if GameSettings.on("vsync") else DisplayServer.VSYNC_DISABLED)
	if sun_light:
		sun_light.shadow_enabled = GameSettings.on("shadows")
	if scenery and scenery.snow_node:
		scenery.snow_node.visible = GameSettings.on("snow")
	if vignette_rect:
		vignette_rect.visible = GameSettings.on("vignette")

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

func capacity() -> int:   # fish you can carry kitted out for hauling: two buckets (the third slot is a tool), or one fish in your hand
	return maxi(mini(GameState.level("bucket"), 2) * _bucket_cap(), 1)

func _bucket_cap() -> int:
	return BUCKET_CAPS[mini(GameState.level("pail"), BUCKET_CAPS.size() - 1)]

func next_capacity() -> int: return BUCKET_CAPS[mini(GameState.level("pail") + 1, BUCKET_CAPS.size() - 1)]
func lines() -> int: return 1 + GameState.level("lines")
func sale_mult() -> float:
	return (1.0 + 0.10 * GameState.level("market") + SECTOR_PERK * stats.sectors + 0.1 * perk_level("favour")
		+ TITHE_BONUS * stats.tithe + AWAKEN_BONUS * stats.awakened) * model.mod_info().value * depth_value()
func depth_value() -> float: return 1.0 + DEPTH_VALUE * _meta_int("lakes")
func rig_cap() -> int: return RIG_BASE_CAP + maxi(eye_stage() - 1, 0)
func tithe_cost() -> float: return ceil(TITHE_BASE * pow(TITHE_GROWTH, stats.tithe))
func bite_mult() -> float: return bite_mult_base() * world_bite()
## The bite pace without the sky's mood (offline progress must not depend on what the weather was when you quit).
func bite_mult_base() -> float: return pow(0.88, GameState.level("bait")) * (BAIT_MULT if bait_t > 0.0 else 1.0)
func ride_mult() -> float: return RIDE_SPEED[mini(GameState.level("snowmobile"), RIDE_SPEED.size() - 1)] if riding else 1.0
func walk_speed() -> float: return (6.0 + 1.6 * GameState.level("boots")) * ride_mult()
func work_speed() -> float: return 1.0 + 0.6 * GameState.level("drill")
func drill_time() -> float: return DRILL_BASE_TIME / work_speed()
func wait_time(t: Dictionary) -> float: return randf_range(2.0, 5.0) * bite_mult() * model.wait_factor(t.c)
func overdrive_mult() -> float: return 1.0 + 0.2 * GameState.level("overdrive")
func _auto_wait(t: Dictionary) -> float: return randf_range(AUTO_WAIT[0], AUTO_WAIT[1]) * bite_mult() * model.wait_factor(t.c) / overdrive_mult()
func auto_cost() -> float: return ceil(AUTO_BASE * pow(AUTO_GROWTH, _count("auto")))
func smoker_cost() -> float: return ceil(90.0 * pow(1.5, _count("smoker")))
func table_cost() -> float: return ceil(60.0 * pow(1.5, _count("table")))
func free_space() -> int: return inv.room(_bucket_cap())   # fish that still fit in your buckets and empty slots
func carrying() -> bool: return inv.cargo_count() > 0

func _count(state: String) -> int:
	var n := 0
	for t in holes:
		if t.state == state:
			n += 1
	return n

func carry_worth() -> float:
	var w := 0.0
	for f in inv.cargo():
		w += f.base * f.mult
	return w * sale_mult()

func roll_fish() -> Dictionary:
	var luck := (1.0 + 0.25 * GameState.level("luck")) * (weather.rare_mult() if weather else 1.0)
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
	"Old Boot": [27.0, 32.0], "Old Coin": [3.0, 4.0], "Glass Pearl": [2.0, 3.0], "Ancient Fish": [140.0, 220.0],
	"Lantern Eel": [60.0, 110.0], "Ghost Carp": [30.0, 62.0], "Dawn Salmon": [50.0, 85.0], "Frost Gar": [80.0, 140.0], "Aurora Char": [35.0, 60.0], "Eye Tetra": [3.0, 6.0]}

func _make_fish(s: Dictionary) -> Dictionary:
	var r: Array = LENGTHS.get(s.name, [10.0, 20.0])
	var l := snappedf(lerpf(r[0], r[1], pow(randf(), 1.4)), 0.1)
	return {"name": s.name, "base": s.value, "color": s.color, "mult": 1.0, "gutted": false, "smoked": false,
		"len": l, "lenk": l / ((r[0] + r[1]) * 0.5)}

func _note_found(f: Dictionary) -> void:
	var ls: Array = GameState.meta.get("life_species", [])
	if not ls.has(f.name):
		ls.append(f.name)
		GameState.meta["life_species"] = ls
	if not journal.has(f.name):
		_log("FOUND %s" % f.name)
		_banner("NEW DISCOVERY: %s  (%d coins)" % [f.name, _species_value(f.name)], Style.AMBER)
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
	if n in ["Minnow", "Perch"]:   # the right hour or weather may swap in a visitor for a COMMON fish (never a rare, never junk: the stock and the keepsakes stay whole)
		var vn := Visitors.roll(visitor_ctx(), visitor_rng)
		if vn != "" and int(visit_count.get(vn, 0)) < VISIT_CAP:   # a handful per species per lake keeps the economy where it was
			n = vn
			visit_count[vn] = int(visit_count.get(vn, 0)) + 1
	var f := _make_fish(_species(n))
	if n in ["Old Boot", "Old Coin", "Glass Pearl"] and keep_rng.randf() < KEEP_CHANCE * (1.0 + 0.2 * perk_level("ears")):
		var kp := Story.roll_keep(n, story, keep_rng)
		if not kp.is_empty():
			f["keep"] = kp.id
			_found_keep(kp)
	_note_found(f)
	return f

var visitor_rng := RandomNumberGenerator.new()
var visit_count := {}   # visitor species -> how many came this lake (saved)
const VISIT_CAP := 10   # per species per lake: <= ~1800 coins of visitors in a lake worth hundreds of thousands

# ---------- the story (story.gd): letters, keepsakes, dreams, the ending ----------
var story: Dictionary = Story.blank()
var ledger_panel: LedgerPanel
var peer: PeerView            # the round window into the water under a hole (peer_view.gd)
var peer_test_hold := false   # tests cannot press keys: they hold C with this
const PEER_RANGE := 4.5
var letters_panel: LettersPanel
var dream: DreamOverlay
var keep_rng := RandomNumberGenerator.new()
const KEEP_CHANCE := 0.3   # of the junk you draw, this share hides a keepsake (until you have them all)

func _story_from_meta() -> Dictionary:
	var s: Dictionary = GameState.meta.get("story", {})
	var b := Story.blank()
	for k in b:
		if not s.has(k):
			s[k] = b[k]
	GameState.meta["story"] = s
	return s

func story_ctx() -> Dictionary:
	var vis := 0
	for n in journal:
		if Visitors.is_visitor(n):
			vis += 1
	var keeps: int = story.keeps.size()
	return {"eye_fed": int(stats.eye_fed), "stage": eye_stage(), "sectors": int(stats.sectors), "tithe": int(stats.tithe), "lakes": _meta_int("lakes"),
		"keeps": keeps, "visitors": vis, "keeps_all": 1 if (keeps >= Story.KEEPS.size() and eye_stage() >= EYE_STAGES.size()) else 0}

## New letters arrive in the mailbox as you reach milestones (several at once when a late save loads: one toast for all).
func _check_story() -> void:
	if restoring or title_active or guide.intro_active:
		return
	var fresh := Story.due(story_ctx(), story)
	for id in fresh:
		story.got.append(id)
	if not fresh.is_empty():
		_log("LETTER %s" % ",".join(fresh))
		_banner("A letter from Olga is in the mailbox" if fresh.size() == 1 else "%d letters from Olga are in the mailbox" % fresh.size(), Style.AMBER)
		sfx.play("bells", -10.0, 0.9)
		sfx.score.hit("catch")
		living.companion_bark()
	_sync_story_world()

func _sync_story_world() -> void:
	if dressing == null:
		return
	dressing.set_unread(Story.unread(story).size())
	dressing.set_keeps(story.keeps)
	scenery.light_village(bool(story.ending))

func _open_letters() -> void:
	if story.got.is_empty():
		_say("The mailbox is empty. Olga writes when there is something to say.")
		return
	letters_panel.open(story.got, story.read, story.keeps.size(), Story.KEEPS.size())
	sfx.play("tick", -6.0, 0.7)

func _on_letter_read(id: String) -> void:
	if not story.read.has(id):
		story.read.append(id)
	_sync_story_world()

func _letters_input(event: InputEvent) -> bool:
	if not letters_panel.visible:
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_A, KEY_LEFT]:
			letters_panel.nav(-1)
		elif event.keycode in [KEY_D, KEY_RIGHT]:
			letters_panel.nav(1)
		elif event.keycode in [KEY_E, KEY_ESCAPE, KEY_ENTER, KEY_SPACE, KEY_Q]:
			_close_letters()
	elif event is InputEventMouseButton and event.pressed:
		_close_letters()
	return true

func _close_letters() -> void:
	var last := letters_panel.current_id()
	if letters_panel.dismiss() and Story.letter(last).get("ending", false) and not story.ending:
		_play_ending()

## Anton's letter read: the Eye closes like a book, the windows of Kestrel Landing light, and the winter goes on.
func _play_ending() -> void:
	story.ending = true
	GameState.meta["pearls"] = _meta_int("pearls") + 10
	_log("ENDING")
	if test_capture or dream == null:
		_sync_story_world()
		return
	dream.play(Story.ENDING_LINES, "THE EYE REMEMBERS", 1.0, 4.4)
	await dream.finished
	_sync_story_world()
	_say("Across the lake the windows of Kestrel Landing are lit. +10 pearls. The lake is still yours.")
	_banner("THE EYE REMEMBERS", Style.AMBER)

## A keepsake rises with the junk: found for good (it stays across lakes) and put on Olga's shelf.
func _found_keep(k: Dictionary) -> void:
	story.keeps.append(k.id)
	_log("KEEPSAKE %s" % k.id)
	_banner("KEEPSAKE: %s" % k.name, Style.AMBER)
	_say("%s\nOlga: %s" % [k.text, "Bring it to me when you are done. I will find a place." if story.keeps.size() == 1 else "On the shelf with the others."])
	sfx.play("rare", -4.0, 1.1)
	living.companion_bark()
	_check_story()

func visitor_ctx() -> Dictionary:
	return {"night": scenery._night, "weather": weather.cur if weather else "clear", "aurora": weather.aurora_on() if weather else false,
		"dawn": Visitors.is_dawn(day_t), "eye_stage": eye_stage(), "stages": EYE_STAGES.size(),
		"mult": (1.0 + 0.25 * perk_level("lantern")) * float(model.mod_info().get("visitors", 1.0))}
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
			_pulse(goals_label, 1.08)
			_say(String(g.line))   # (the banner already says what was done: the bottom line is just Olga)

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
		return "another bucket (holds %d). Place them around" % _bucket_cap()
	if id == "pail":
		return "every bucket holds %d" % next_capacity()
	return UPGRADES[id].desc

func _sync_machine_fx() -> void:
	var lv := GameState.level("overdrive")
	for t in holes:
		if t.state == "auto" and t.get("node") != null and is_instance_valid(t.node):
			var aura: Node = (t.node as Node3D).get_node_or_null("od_aura")
			if (aura == null and lv > 0) or (aura != null and int(aura.get_meta("level", -1)) != lv):
				MachineFX.sync_overdrive(t.node, lv, 1.3)
	for rg in rigs:
		var ra: Node = (rg.node as Node3D).get_node_or_null("od_aura")
		if (ra == null and lv > 0) or (ra != null and int(ra.get_meta("level", -1)) != lv):
			MachineFX.sync_overdrive(rg.node, lv, 3.4)

func _refresh() -> void:
	_sync_machine_fx()
	_sync_active()
	_check_goals()
	_check_story()
	_check_ledger()
	coins_target = floor(GameState.currency)
	if coins_shown < 0.0:
		coins_shown = coins_target
		coins_label.text = _fmt_num(coins_shown)
	var cc := inv.cargo_count()
	carry_label.text = "%s%s" % [("Carrying %d fish   worth %d" % [cc, floor(carry_worth())]) if cc > 0 else "Carrying nothing", ("   |   %d on the ice" % yard.count()) if yard.count() > 0 else ""]
	carry_bar.value = float(cc) / maxf(1.0, float(cc + free_space()))
	eye_label.text = "The Eye   stage %d / %d   %d fed" % [eye_stage(), EYE_STAGES.size(), stats.eye_fed]
	eye_bar.value = _eye_progress()
	var est := eye_stage()
	eye_next_label.text = ("Next: %s" % String(EYE_BOONS[est]).split(":")[0]) if est < EYE_STAGES.size() else "The Eye is awake.  Tithe Lv %d" % stats.tithe
	lake_label.text = "%d fish left  -  %d / %d sectors\n%s #%d  -  %d pearls  -  [R] refreeze" % [model.total_left(),
		model.cleared_count(), model.sectors.size(), model.mod_info().name, _meta_int("lakes") + 1, _meta_int("pearls")]
	combo_label.text = ("Combo x%d  (+%d%%)" % [combo, mini(combo - 1, 10) * 10]) if combo > 1 else ""
	goals_label.text = _goals_text() + ("\n\n" + _order_text() if not order.is_empty() else "")
	for id in UPGRADES:
		var u: Dictionary = UPGRADES[id]
		if not unlocked[id]:
			sign_labels[id].text = "???"
			sign_descs[id].text = "complete goals to unlock"
			continue
		var lvl := GameState.level(id)
		var cost_text := "%d coins" % GameState.cost(id, u.base, u.growth)
		if lvl >= u.max:
			cost_text = "MAX"
		sign_labels[id].text = "%s  Lv%d\n%s" % [u.name, lvl, cost_text]
		sign_descs[id].text = _upgrade_desc(id)
	if scenery:
		scenery.set_eye_glow(float(model.cleared_count()) / model.sectors.size() * 1.4)
		scenery.set_eye_open(minf(eye_open_frac(), 0.8) if awaken_hold else eye_open_frac())
		scenery.set_eye_stage(eye_seen_stage - 1 if awaken_hold else eye_seen_stage)
		scenery.set_crane(GameState.level("conveyor") >= 2)
	if journal_panel.visible:
		_update_journal()
	map_ctrl.queue_redraw()
	if living:
		living.set_camp_level(eye_stage(), session_t > 3.0)
		weather.always_aurora = eye_stage() >= EYE_STAGES.size()
	_sync_tool_view()
	_refresh_dock()
	_refresh_rack()

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
		var ic := HudWidgets.FishIcon.new(sp.name, found)   # the fish itself, drawn from its model: a dark silhouette until you meet it
		journal_grid.add_child(ic)
		var rar: Array = _rarity(sp.name)
		var nbox := VBoxContainer.new()
		nbox.add_theme_constant_override("separation", 0)
		journal_grid.add_child(nbox)
		var nl := _plain(nbox, 19, rar[1] if found else Style.MUTED)
		nl.text = sp.name if found else "???"
		var visitor: bool = Visitors.is_visitor(sp.name)
		var sub := _plain(nbox, 12, Style.MUTED)
		sub.custom_minimum_size = Vector2(330, 0)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if found:
			sub.text = ("Visitor.  " if visitor else "") + (Visitors.note_of(sp.name) if visitor else _journal_note(sp.name))
		elif visitor:
			sub.text = Visitors.clue_of(sp.name)
		var cl := _plain(journal_grid, 18, Style.CREAM if found else Style.MUTED)
		cl.text = "x%d" % journal[sp.name] if found else ""
		var bl := _plain(journal_grid, 18, Style.CREAM if found else Style.MUTED)
		bl.text = "%.1f cm" % records.get(sp.name, 0.0) if found else ""
		var vl := _plain(journal_grid, 18, Style.AMBER if found else Style.MUTED)
		vl.text = "%d" % sp.value if found else ""
	var foot := _plain(journal_grid, 14, Style.MUTED)
	foot.text = ""

## Things held in front of the camera must not cast shadows: they showed up as dark polygons on the ice that belong to no object.
func _no_shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadows(c)

# ---------- tools in hand ----------
func _sync_tool_view() -> void:
	var sig := "%d-%d-%d-%d" % [tool, GameState.level("drill"), GameState.level("lines"), bmode]
	if sig == tool_sig:
		return
	if tool_sig != "":   # not on the first build: the old tool drops away, the new one swings up
		tool_swap = 1.0
		sfx.play("tick", -8.0, 0.8 + 0.06 * maxi(tool, 0))
	tool_sig = sig
	for c in tool_view.get_children():
		c.queue_free()
	tool_body = Node3D.new()
	tool_view.add_child(tool_body)
	tool_spin = null
	tool_line = null
	tool_tip = null
	tool_base_z = 0.0
	tool_view.visible = tool >= 0
	match tool:
		-1:  # a fish, a bucket or empty hands: nothing in the tool hand
			pass
		0:  # auger: spins while you hold click
			var tier := mini(GameState.level("drill"), TIER_COLORS.size() - 1)
			tool_base_x = deg_to_rad(-12)   # shaft out front, slightly down, leaning across the screen on a diagonal so it reads as a drill and not a log
			tool_base_z = deg_to_rad(24)
			var parts: Dictionary = ToolModels.auger(tool_body, TIER_COLORS[tier], tier)
			tool_spin = parts.spin
		1:  # rod, its line shows while a cast is active
			var tier := mini(GameState.level("lines"), TIER_COLORS.size() - 1)
			tool_base_x = deg_to_rad(30)
			var parts: Dictionary = ToolModels.rod(tool_body, TIER_COLORS[tier], tier)
			tool_tip = parts.tip
		_:  # the builder's kit: the accent says what you are placing
			tool_base_x = deg_to_rad(-10)
			ToolModels.builder(tool_body, _kit_accent())
	tool_body.rotation.x = tool_base_x
	tool_body.rotation.z = tool_base_z
	_no_shadows(tool_body)

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
	for f in inv.cargo():
		if f.name == sp:
			n += 1
	for g in ground:   # a bucket lying on the ice still holds fish that are out of the lake
		if g.item.k == "bucket":
			for f in g.item.fish:
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
	var avail: int = model.total_left() + inv.cargo_count()
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

## The coin counter rolls up (or down) to the real value and pops a little when you earn; "Saved" fades after an autosave.
# ---------- the lake's moods ----------
## The sky's phase by name, from the day clock (0 golden hour, .25 dusk, .5 night, .75 dawn).
func day_phase(t := -1.0) -> String:
	var x := day_t if t < 0.0 else t
	if x < 0.07 or x >= 0.93:
		return "Golden hour"
	if x < 0.38:
		return "Dusk"
	if x < 0.62:
		return "Night"
	if x < 0.88:
		return "Dawn"
	return "Golden hour"

## Fish bite sooner at the edges of the day (golden hour, dawn) and in snowfall: the weather's own number times the hour's.
func hour_bite() -> float:
	var x := day_t
	return 0.92 if (x < 0.07 or x >= 0.93 or (x >= 0.72 and x < 0.82)) else 1.0

func world_bite() -> float:
	return (weather.vals.bite if weather else 1.0) * hour_bite()

## -6 C by day, colder at night, the weather adds its own chill.
func temperature() -> int:
	return int(round(-6.0 - 11.0 * (scenery._night if scenery else 0.0) + (weather.temp_offset() if weather else 0.0)))

func world_text() -> String:
	var s := "%s   %d C   %s" % [day_phase(), temperature(), weather.label()]
	if weather.aurora_on() and scenery._night > 0.5:
		s += "\nAurora night: rare fish stir"
	elif world_bite() < 0.95:
		s += "\nBites come sooner"
	if float(weather.vals.fog) > 3.0:
		s += ("\n" if not s.contains("\n") else "   ") + "You cannot see far"
	return s

func _on_crack(pos: Vector3, near: float) -> void:
	sfx.play("creak", -17.0 + 9.0 * near, randf_range(0.7, 1.2))
	if near > 0.55:
		shake = maxf(shake, 0.006 * near)

func _tick_hud_feel(delta: float) -> void:
	eye_pulse_t -= delta
	if coins_shown >= 0.0 and absf(coins_shown - coins_target) > 0.4:
		var gap := coins_target - coins_shown
		var step := maxf(absf(gap) * minf(1.0, delta * 9.0), 1.0 * delta * 60.0 * 0.2)
		var before := int(coins_shown)
		coins_shown = move_toward(coins_shown, coins_target, step)
		if int(coins_shown) != before:
			coins_label.text = _fmt_num(coins_shown)
		if gap > 0.0:
			coins_label.pivot_offset = Vector2(0, coins_label.size.y * 0.5)
			coins_label.scale = coins_label.scale.lerp(Vector2.ONE * 1.12, minf(1.0, delta * 18.0))
	else:
		if coins_shown >= 0.0 and coins_label.text != _fmt_num(coins_target):
			coins_shown = coins_target
			coins_label.text = _fmt_num(coins_target)
		coins_label.scale = coins_label.scale.lerp(Vector2.ONE, minf(1.0, delta * 12.0))
	if saved_t > 0.0:
		saved_t -= delta
		saved_label.modulate.a = clampf(saved_t / 0.8, 0.0, 1.0) if saved_t < 0.8 else 1.0

func _process(delta: float) -> void:
	_tick_hud_feel(delta)
	tithe_armed_t = maxf(tithe_armed_t - delta, 0.0)
	reset_armed_t = maxf(reset_armed_t - delta, 0.0)
	var cap_now := _cap()
	if cap_now and not title_active:
		ever_captured = true
	# Esc frees the mouse and really pauses: no bites expire, no machines run, no timers tick (cutscenes play on)
	var want_pause := ever_captured and not cap_now and not guide.intro_active and title == null
	if title_active:
		cap_now = false
		want_pause = false
	if want_pause != sim_paused:
		sim_paused = want_pause
		_on_pause_changed()
	if sim_paused:
		menu.set_open(true)
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
	if bait_t > 0.0:
		bait_t = maxf(bait_t - delta, 0.0)
	var bt := int(ceil(bait_t))
	bait_label.text = ("Bait %d:%02d   bites come sooner" % [bt / 60, bt % 60]) if bt > 0 else ""
	for pr in props:   # the fan's rotor and the grinder's crank
		var part: Node3D = pr.part
		if pr.kind == "fan":
			part.rotation.z -= delta * 11.0
		else:
			pr["work"] = maxf(float(pr.get("work", 0.0)) - delta, 0.0)
			part.rotation.x += delta * (1.5 + 12.0 * minf(pr.work, 1.0))
	if eye_pending > 0.0 and eye_pending_t <= 0.0:
		_float_text(Vector3(0, 6.0, 0), "+%s" % _coins(eye_pending), Color(0.6, 1.0, 0.9), 0.034)
		eye_pending = 0.0
		eye_pending_t = 0.7
	var captured := _cap()
	if not title_active:
		menu.set_open(not captured and not guide.intro_active and title == null)
	_walk(delta)
	var raw := _aim_raw()
	var a := raw if _in_range(raw) else ""
	if not captured:
		prompt_label.text = ""
	elif journal_panel.visible or refreeze_panel.visible or letters_panel.visible or ledger_panel.visible:
		prompt_label.text = ""   # (the tithe prompt used to print across the journal)
	elif raw != "" and a == "":
		prompt_label.text = "" if raw == "ice" else "Too far - walk closer"
	else:
		prompt_label.text = _prompt_for(a)
		if a.begins_with("hole:") and aim_flat <= PEER_RANGE and not peer.want_open:
			prompt_label.text += "     [hold C: peer in]"
	_update_peer(delta, raw)
	_tick_yard(delta, captured)
	var in_hand := _held_kind() in ["fish", "bucket"]
	if captured and (a == "" or (a == "ice" and in_hand)) and (in_hand or yard.near($Player.global_position, PICKUP_RADIUS + 1.0) > 0) and not guide.intro_active:
		prompt_label.text = _yard_hint()
	guide.tick(delta, captured)
	if guide.intro_active:
		prompt_label.text = ""
		msg_label.text = ""
		_animate(delta)
		return
	var pp3: Vector3 = $Player.global_position
	scenery.set_eye_offering(captured and _hands_have_fish() and Vector2(pp3.x, pp3.z).length() - EYE_R <= RANGE_EYE + 4.0, pp3)
	_update_hold(a, delta)
	if kick_charge >= 0.0:
		work_bar.visible = true
		work_bar.value = kick_charge
	if not GameSettings.on("prompts"):
		prompt_label.text = ""
	_update_crosshair(a, captured)
	view.position.y = -0.4 + sin(Time.get_ticks_msec() * 0.002) * 0.005
	_animate(delta)

func _animate(delta: float) -> void:
	var tm := Time.get_ticks_msec() * 0.001
	if not title_active:
		play_time += delta
	if not title_active and not (guide.intro_active and guide.scene == "intro"):   # the clock waits through the title and the opening
		day_t = fmod(day_t + delta / DAY_LENGTH, 1.0)
	sky_t -= delta
	if sky_t <= 0.0:  # re-lighting the sky every frame is wasteful; 5x a second is plenty
		sky_t = 0.2
		scenery.set_time(day_t)
		dressing.fade(scenery._night, clampf(1.0 - minf(minf(absf(day_t - 0.25), absf(day_t - 0.75)), minf(day_t, 1.0 - day_t)) * 5.0, 0.0, 1.0))
	weather.enabled = GameSettings.on("weather")
	if not title_active:   # (the weather's calm start and the run timer are for play, not for the title)
		weather.tick(delta, scenery._night, not guide.intro_active)
	living.dawn = Visitors.is_dawn(day_t)
	living.update(delta, scenery._night, $Player.global_position, guide.intro_active)
	sfx.set_weather(weather.vals.wind, weather.vals.snow, scenery._night)
	sfx.score.set_mood(scenery._night, weather.vals.gloom, weather.vals.wind, eye_stage(), eye_open_frac(), weather.aurora_on())
	sfx.score.set_scene(guide.intro_active or reveal_t > 0.0)
	sfx.score.set_title(title_active)
	session_t += delta
	world_t -= delta
	if world_t <= 0.0:
		world_t = 0.5
		world_label.text = world_text()
	sky_clock.set_time(day_t, scenery._night)
	shake = move_toward(shake, 0.0, delta * 0.25)
	cam.h_offset = randf_range(-1.0, 1.0) * shake * fx_shake
	cam.v_offset = randf_range(-1.0, 1.0) * shake * fx_shake
	# walking: a soft head bob, the tool sways with it, and each footfall kicks up a pinch of snow
	if moving and not riding and not guide.intro_active:
		var prev_phase := sin(bob_t)
		bob_t += delta * 9.5
		cam.v_offset += sin(bob_t * 2.0) * 0.006 * fx_bob
		cam.h_offset += sin(bob_t) * 0.004 * fx_bob
		if prev_phase > 0.0 and sin(bob_t) <= 0.0:
			var pw: Vector3 = $Player.global_position
			_snow_fx(Vector3(pw.x, 0.03, pw.z) + (-$Player.global_basis.z) * 0.2, 2, 0.35)
			sfx.play("step_ice" if pw.length() < scenery.edge_at(pw.x, pw.z) else "step_snow", -8.0, randf_range(0.8, 1.2))
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
	cam.fov = fov_base + fov_kick * fx_punch + ride_fov + reveal_fov + cine_fov
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
		tool_view.position += Vector3(sin(bob_t) * 0.012, absf(sin(bob_t)) * -0.012, 0.0) * fx_bob
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
		tool_body.rotation.z = tool_base_z + fight_amt * 0.05 * sin(Time.get_ticks_msec() * 0.027)
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
	_update_sector_hud(delta)
	_tick_title(delta)
	if kick_boot:
		kick_boot.visible = not (title_active or guide.intro_active)

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
	match _held_kind():
		"fish":
			return "Click: drop   Right mouse (hold): throw   Q: put down   Click the Eye or a bucket: put it in"
		"bucket":
			return "Click: set the bucket down   Click a fish: scoop it   E: sweep up   Z: take one out   Kick tips a bucket over"
	if _aim_fish() != null:
		return "Click: grab this fish   Right mouse / F: kick   E: sweep up"
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
	_update_hand(delta)
	_update_arc()
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
	if captured and yard.count() > 0 and not guide.intro_active and GameSettings.on("rings"):
		var pl: Node3D = $Player
		var fwd := -pl.global_basis.z
		fwd.y = 0.0
		want = yard.targets(pl.global_position, fwd.normalized(), KICK_REACH)
	while kick_rings.size() < mini(want.size(), 8):
		var m := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.64
		tm.outer_radius = 0.76
		tm.rings = 24
		tm.ring_segments = 6
		m.mesh = tm
		var mt := StandardMaterial3D.new()
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mt.albedo_color = Color(0.95, 0.56, 0.08, 1.0)   # the old pale rings were fog washing them out, not the colour
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mt.disable_fog = true
		mt.render_priority = 2
		m.material_override = mt
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		kick_rings.append(m)
	var pulse := 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.012)
	var prime := -1   # the fish most in front of you gets the full ring; the others a small one (five big rings made one blob)
	if not want.is_empty():
		var pl2: Node3D = $Player
		var fw2 := -pl2.global_basis.z
		fw2.y = 0.0
		fw2 = fw2.normalized()
		var best_d := -2.0
		for i in mini(want.size(), kick_rings.size()):
			var off: Vector3 = want[i].pos - pl2.global_position
			off.y = 0.0
			var dd := off.normalized().dot(fw2) - off.length() * 0.05
			if dd > best_d:
				best_d = dd
				prime = i
	for i in kick_rings.size():
		var ring: MeshInstance3D = kick_rings[i]
		ring.visible = i < want.size()
		if ring.visible:
			ring.global_position = Vector3(want[i].pos.x, 0.03, want[i].pos.z)
			var big := 1.0 if i == prime else 0.5
			ring.scale = Vector3.ONE * (want[i].r / 0.5) * 0.85 * big * (1.0 + 0.25 * maxf(kick_charge, 0.0)) * pulse
			(ring.material_override as StandardMaterial3D).albedo_color.a = 0.85 + 0.15 * maxf(kick_charge, 0.0)

func _update_crosshair(a: String, captured: bool) -> void:
	var kind := 0
	if captured and not guide.intro_active:
		if a == "eye":
			kind = 2
		elif a.begins_with("hole:") or a.begins_with("buy:") or a == "olga" or a.begins_with("depot:") or a.begins_with("rig:") or a.begins_with("item:") or a.begins_with("rack:") or a.begins_with("prop:") or a == "mailbox":
			kind = 1
		elif a == "ice" and tool == 0 and _can_drill_at(Vector3(aim_pos.x, 0.0, aim_pos.z)):
			kind = 1
		if kind == 0 and yard.count() > 0 and _aim_fish() != null:
			kind = 3   # a fish you can grab
		if kind == 0 and yard.count() > 0:
			var pl: Node3D = $Player
			var fwd := -pl.global_basis.z
			fwd.y = 0.0
			if not yard.targets(pl.global_position, fwd.normalized(), KICK_REACH).is_empty():
				kind = 3
	crosshair.kind = kind
	crosshair.progress = work_bar.value if work_bar.visible else -1.0

# ---------- hands: grab, hold, drop, throw, stow ----------
# Free, physical handling (after Project P.I.T.T.): click a fish to grab it, carry it in your hand (it sways as you turn),
# click to drop it, hold the right mouse to charge a throw with an arc preview, let go to throw. E stows it in your bucket
# (or sweeps up everything at your feet), Z takes one out again. Clicking the Eye with a fish in hand lobs it in.

## The fish under the crosshair (within reach), or null.
func _aim_fish() -> Variant:
	return yard.pick(cam.global_position, -cam.global_basis.z, GRAB_REACH)

func _held_kind() -> String:
	return String(inv.cur().get("k", ""))

## The fish in your hand ({} when your hand holds a tool, a bucket or nothing).
func _held_fish() -> Dictionary:
	var it := inv.cur()
	return it.f if it.get("k", "") == "fish" else {}

func _hands_have_fish() -> bool:
	return inv.cargo_count() > 0

# the builder's kit does one thing at a time: [tool id, build item], cycled with B through whatever is unlocked
const KIT := [[2, -1], [3, -1], [4, -1], [5, -1], [6, 0], [6, 1], [6, 2], [6, 3], [6, 4], [6, 5]]

func _kit_modes() -> Array:
	var out := []
	for i in KIT.size():
		if _tool_unlocked(KIT[i][0]):
			out.append(i)
	return out

func _kit_name(i: int) -> String:
	var k: Array = KIT[i]
	return TOOLS[k[0]] if k[0] != 6 else BUILD_ITEMS[k[1]]

func _sync_active() -> void:
	var m := _kit_modes()
	if not m.is_empty() and not m.has(bmode):
		bmode = m[0]
	var it := inv.cur()
	var nt := -1
	if it.get("k", "") == "tool":
		nt = int(it.t) if int(it.t) < 2 else int(KIT[bmode][0])
	tool = nt

## Something in your hands changed (a pickup, a drop, a swap, a delivery): the held model, the slots and everything that reads them follow.
func _hands_changed() -> void:
	if inv.cur().is_empty() and return_slot >= 0 and return_slot != inv.active and not inv.slots[return_slot].is_empty():
		inv.active = return_slot   # a fish left your hand: back to what you were holding
	return_slot = -1 if inv.cur().is_empty() or inv.cur().get("k", "") != "fish" else return_slot
	_sync_active()
	_refresh_view()
	_refresh()

func _select_slot(i: int) -> void:
	if inv.select(i):
		return_slot = -1
		sfx.play("tick", -8.0, 0.9 + 0.08 * i)
		_sync_active()
		_refresh_view()
		_refresh()

func _cycle_slot(dir: int) -> void:
	_select_slot(posmod(inv.active + dir, Inventory.SLOTS))

func _cycle_build() -> void:
	var m := _kit_modes()
	if m.is_empty() or inv.cur().get("k", "") != "tool" or int(inv.cur().t) != 2:
		return
	bmode = m[(m.find(bmode) + 1) % m.size()]
	if KIT[bmode][0] == 6:
		build_item = int(KIT[bmode][1])
	sfx.play("tick", -6.0, 1.2)
	_sync_active()
	_say("Kit: %s%s" % [_kit_name(bmode), ("  (%d coins)" % _build_cost(build_item)) if tool == 6 else ""])
	_refresh()

## Puts a tool in your hand whatever it takes (tests, debug and cutscenes: players take tools from the rack). 0 drill, 1 rod,
## 2..6 a build mode of the kit (for 6, `build` picks Cannery/Sorter/Depot/Ice-Breaker).
func equip(t: int, build := 0) -> void:
	var slot_t := mini(t, 2)
	var si := inv.find_tool(slot_t)
	if si < 0:
		for gr in ground.duplicate():   # (one of each tool in the world: a copy on the ice comes back to your hand)
			if gr.item.k == "tool" and int(gr.item.t) == slot_t:
				_remove_ground(gr)
		si = inv.free_slot()
		if si < 0:
			si = inv.active
			for want_kind in ["tool", "fish", "bucket"]:   # full: a tool makes room (a loose fish before a bucket)
				var found := -1
				for i in Inventory.SLOTS:
					if inv.slots[i].get("k", "") == want_kind:
						found = i
						break
				if found >= 0:
					si = found
					break
		inv.slots[si] = Inventory.tool_item(slot_t)
	inv.active = si
	if t >= 2:
		for i in KIT.size():
			if KIT[i][0] == t and (t != 6 or KIT[i][1] == build):
				bmode = i
		if t == 6:
			build_item = build
	return_slot = -1
	_hands_changed()

## Puts a fish where your hands can take it: into the bucket you hold, else an empty slot (it is in your hand now), else another bucket.
## `bucket_first` flips that for a sweep. False when you have no room at all.
func _add_fish_to_hands(f: Dictionary, bucket_first := false) -> bool:
	var before := inv.active
	var si := inv.add_fish(f, _bucket_cap(), bucket_first)
	if si < 0:
		return false
	if inv.slots[si].get("k", "") == "fish" and si != inv.active:
		if return_slot < 0:   # (only the first grab remembers what was in your hand: a second grab must not forget it)
			return_slot = before if not inv.slots[before].is_empty() and inv.slots[before].get("k", "") != "fish" else -1
		inv.active = si
	return true

func _grab_fish(target: Variant = null) -> bool:
	var e: Variant = target if target != null else _aim_fish()
	if e == null:
		return false
	if free_space() <= 0:
		_say("Hands full. Q puts what you hold down, or keep the fish in a bucket.")
		sfx.play("deny")
		return false
	var at: Vector3 = e.pos
	var f := yard.take(e)
	_add_fish_to_hands(f)
	_hands_changed()
	hold_node.position = HOLD_REST + Vector3(0, -0.25, 0.2)   # it comes up from below
	_snow_fx(at, 4, 0.5)
	sfx.play("plop", -2.0, 1.5)
	view_pop = 0.8
	return true

func _set_hold_visual() -> void:
	var it := inv.cur()
	var k := String(it.get("k", ""))
	var sig := ""
	match k:
		"fish": sig = "fish:%s:%.1f" % [it.f.name, float(it.f.get("len", 0.0))]
		"bucket": sig = "bucket:%d:%d" % [it.fish.size(), _bucket_cap()]
	if sig == hold_sig:
		return
	var fresh := hold_sig == "" or not hold_sig.begins_with(k)   # a new thing grows in; the same bucket just gains a fish
	hold_sig = sig
	for c in hold_node.get_children():
		c.queue_free()
	hold_node.scale = Vector3.ONE
	if k == "":
		return
	if k == "fish":
		var fm := _fish_mesh(it.f, hold_node, 0.95)
		(fm as FishNode).amp = 1.8
		fm.rotation = Vector3(0.15, PI * 0.5 + 0.7, 0.25)   # across the lower right of the view, its side showing
	elif k == "bucket":
		var parts: Dictionary = ItemModels.bucket(hold_node)
		var root: Node3D = parts.root
		root.scale = Vector3.ONE * 0.36
		root.position = Vector3(0.05, -0.2, 0.0)
		root.rotation = Vector3(0.12, 0.5, 0.0)
		ItemModels.set_pile(parts.pile, it.fish.map(func(f): return f.color), float(it.fish.size()) / float(_bucket_cap()))
	else:
		return
	_no_shadows(hold_node)
	if fresh:
		hold_node.scale = Vector3.ONE * 0.4
		var tw := hold_node.create_tween()
		tw.tween_property(hold_node, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _throw_dir() -> Vector3:
	return (-cam.global_basis.z).rotated(cam.global_basis.x, THROW_LIFT).normalized()

func _throw_origin() -> Vector3:
	return cam.global_position + (-cam.global_basis.z) * 0.95 + Vector3(0, -0.3, 0)

func _throw_power(frac: float) -> float:
	return lerpf(THROW_MIN, THROW_BASE_MAX + 3.0 * GameState.level("kick"), clampf(frac, 0.0, 1.0))

func _throw_velocity(frac: float) -> Vector3:
	return _throw_dir() * _throw_power(frac) + Vector3(yard.player_vel.x, 0, yard.player_vel.z) * 0.6

func _throw_held(frac: float) -> bool:
	var f := _held_fish()
	if f.is_empty():
		return false
	inv.slots[inv.active] = {}
	var e := yard.spawn(f, _throw_origin(), _throw_velocity(frac))
	e.spin = randf_range(-14.0, 14.0)
	sfx.play("cast", -3.0, 0.85 + frac * 0.5)
	_kick_tool(1.1)
	view_pop = 0.5
	fov_kick = maxf(fov_kick, 1.5 + frac * 3.0)
	shake = maxf(shake, 0.004 + 0.01 * frac)
	_hands_changed()
	return true

## Where Q (or a click on empty ice with a bucket) puts something down.
func _drop_spot(at_aim: bool) -> Vector3:
	var pl: Node3D = $Player
	var fwd := -pl.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var p := pl.global_position + fwd * DROP_REACH
	if at_aim and aim_flat <= RANGE_ICE:
		p = Vector3(aim_pos.x, 0.0, aim_pos.z)
	return _valid_spot(p)

## Things never end up inside the Eye, on the shore, inside a stall or on top of each other.
func _valid_spot(p: Vector3) -> Vector3:
	var q := Vector2(p.x, p.z)
	for pass_i in 4:   # each rule can undo another, so settle them together
		var q0 := q
		q = _valid_pass(q)
		if q.distance_to(q0) < 0.01:
			break
	return Vector3(q.x, 0.0, q.y)

func _valid_pass(q: Vector2) -> Vector2:
	var lim: float = scenery.edge_at(q.x, q.y) - 2.5
	if q.length() > lim:
		q = q.normalized() * lim
	if q.length() < EYE_R + 1.6:
		q = (q.normalized() if q.length() > 0.01 else Vector2.RIGHT) * (EYE_R + 1.6)
	for o in scenery.obstacles:
		var off := q - Vector2(o.x, o.y)
		if off.length() < o.z + 0.9:
			q = Vector2(o.x, o.y) + (off.normalized() if off.length() > 0.01 else Vector2.RIGHT) * (o.z + 0.9)
	for h in holes:   # a thing lying on a hole would hide it from your crosshair
		var offh := q - Vector2(h.pos.x, h.pos.z)
		if offh.length() < 1.9:
			q = Vector2(h.pos.x, h.pos.z) + (offh.normalized() if offh.length() > 0.01 else Vector2.RIGHT) * 1.9
	for g in ground:
		var off2 := q - Vector2(g.pos.x, g.pos.z)
		if off2.length() < 1.3:
			q = Vector2(g.pos.x, g.pos.z) + (off2.normalized() if off2.length() > 0.01 else Vector2.RIGHT) * 1.3
	return q

## Q: puts what is in your hand down in front of you. A fish slides off; a tool or bucket lands and stays where it lands.
func _drop_active(at_aim := false) -> bool:
	var it := inv.cur()
	if it.is_empty():
		return false
	if it.k == "fish":
		inv.slots[inv.active] = {}
		var fwd := -cam.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		yard.spawn(it.f, cam.global_position + fwd * 0.9 + Vector3(0, -0.8, 0), fwd * 2.0 + Vector3(0, 1.2, 0))
		sfx.play("plop", -4.0, 1.1)
	else:
		var item := inv.take(inv.active)
		_place_ground(item, _drop_spot(at_aim), true)
		sfx.play("plop", -3.0, 0.8)
	_hands_changed()
	return true

## Z: takes one fish out of the bucket in your hand and holds it (it needs a free slot).
func _take_from_bucket() -> bool:
	var it := inv.cur()
	if it.get("k", "") != "bucket" or it.fish.is_empty():
		return false
	var fs := inv.free_slot()
	if fs < 0:
		_say("No free slot: put something down (Q) to hold a fish.")
		sfx.play("deny")
		return false
	var f: Dictionary = it.fish.pop_back()
	inv.slots[fs] = Inventory.fish_item(f)
	return_slot = inv.active
	inv.active = fs
	sfx.play("plop", -3.0, 1.4)
	_hands_changed()
	return true

# ---------- things lying on the ice: tools and buckets ----------
func _tool_tier(t: int) -> int:
	return mini(GameState.level("drill" if t == 0 else "lines"), TIER_COLORS.size() - 1)

func _kit_accent() -> Color:
	var accents := [Color(1.0, 0.78, 0.35), Color(0.95, 0.5, 0.2), Color(0.55, 0.9, 0.95), Color(0.3, 0.75, 0.85), Color(1.0, 0.9, 0.6)]
	return accents[clampi(int(KIT[bmode][0]) - 2, 0, accents.size() - 1)]

func _ground_by_id(id: int) -> Dictionary:
	for g in ground:
		if g.id == id:
			return g
	return {}

func _ground_has_tool(t: int) -> bool:
	for g in ground:
		if g.item.k == "tool" and int(g.item.t) == t:
			return true
	return false

func _make_ground_node(g: Dictionary) -> void:
	var it: Dictionary = g.item
	var root := Node3D.new()
	add_child(root)
	root.position = g.pos
	root.rotation.y = g.yaw
	g["node"] = root
	var shadow := MeshInstance3D.new()   # a soft disc keeps a pale thing grounded on pale ice
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.01
	cm.radial_segments = 14
	shadow.mesh = cm
	shadow.material_override = _shadow_material()
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shadow)
	var shape: Shape3D
	var cpos := Vector3(0, 0.4, 0)
	if it.k == "bucket":
		var parts: Dictionary = ItemModels.bucket(root)
		g["pile"] = parts.pile
		shadow.scale = Vector3(0.75, 1.0, 0.75)
		shadow.position = Vector3(0, -0.03, 0)
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.6
		cyl.height = 0.9
		shape = cyl
		_refresh_bucket_node(g)
	else:
		var t := int(it.t)
		ItemModels.ground_tool(root, t, _tool_tier(t), TIER_COLORS[_tool_tier(t)], _kit_accent())
		shadow.scale = Vector3(0.7, 1.0, 1.1)
		shadow.position = Vector3(0, -0.03, -0.35)
		var bx := BoxShape3D.new()
		bx.size = Vector3(1.0, 0.7, 2.0)
		shape = bx
		cpos = Vector3(0, 0.3, -0.35)
		var ring := MeshInstance3D.new()   # an amber ring says "yours, pick me up"
		var tm := TorusMesh.new()
		tm.inner_radius = 0.95
		tm.outer_radius = 1.05
		tm.rings = 24
		tm.ring_segments = 4
		ring.mesh = tm
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.albedo_color = Color(1.0, 0.7, 0.2, 0.75)
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.disable_fog = true
		ring.material_override = rm
		ring.position = Vector3(0, 0.03, -0.35)
		ring.scale = Vector3(1.0, 1.0, 1.5)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ring)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	body.position = cpos
	body.set_meta("action", "item:%d" % g.id)
	root.add_child(body)

var _shadow_mat_cache: StandardMaterial3D
func _shadow_material() -> StandardMaterial3D:
	if _shadow_mat_cache == null:
		_shadow_mat_cache = StandardMaterial3D.new()
		_shadow_mat_cache.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shadow_mat_cache.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shadow_mat_cache.albedo_color = Color(0.05, 0.1, 0.3, 0.3)
		_shadow_mat_cache.disable_fog = true
	return _shadow_mat_cache

func _refresh_bucket_node(g: Dictionary) -> void:
	if g.has("pile") and is_instance_valid(g.pile):
		ItemModels.set_pile(g.pile, g.item.fish.map(func(f): return f.color), float(g.item.fish.size()) / float(_bucket_cap()))

## Sets a tool or bucket down on the ice (it stays until you pick it up). `toss` hops it from your hands to the spot.
func _place_ground(item: Dictionary, pos: Vector3, toss := false) -> Dictionary:
	ground_serial += 1
	var g := {"id": ground_serial, "item": item, "pos": pos, "yaw": randf() * TAU}
	_make_ground_node(g)
	ground.append(g)
	if item.k == "bucket":
		yard.sinks.append({"pos": Vector3(pos.x, 0, pos.z), "r": 0.62, "h": 1.0, "id": "bucket:%d" % g.id,
			"accept": func(): return g.item.fish.size() < _bucket_cap()})
	if toss and not restoring:
		var node: Node3D = g.node
		var from := cam.global_position + (-cam.global_basis.z) * 0.8 + Vector3(0, -0.5, 0)
		node.global_position = from
		var tw := node.create_tween()
		tw.tween_method(func(k: float): node.global_position = from.lerp(pos, k) + Vector3(0, sin(k * PI) * 0.9, 0), 0.0, 1.0, 0.28)
		tw.tween_callback(func():
			node.global_position = pos
			_snow_fx(pos + Vector3(0, 0.1, 0), 6, 1.0)
			sfx.play("thud", -10.0, 1.0)
			if item.k == "bucket":
				sfx.play("clank", -8.0, randf_range(0.9, 1.1)))
	return g

func _remove_ground(g: Dictionary) -> void:
	ground.erase(g)
	if g.has("node") and is_instance_valid(g.node):
		(g.node as Node).queue_free()
	for i in range(yard.sinks.size() - 1, -1, -1):
		if yard.sinks[i].id == "bucket:%d" % g.id:
			yard.sinks.remove_at(i)

## Gives you an item: in a free slot if there is one, else on the ice at your feet.
func _give_item(item: Dictionary) -> void:
	var fs := inv.free_slot()
	if fs >= 0:
		inv.slots[fs] = item
		inv.active = fs
		return_slot = -1
	else:
		_place_ground(item, _drop_spot(false), true)

## Pick something up off the ice. With every slot full, it swaps with what is in your hand (that goes down where it lay).
func _take_ground(g: Dictionary) -> bool:
	var item: Dictionary = g.item
	if item.k == "bucket":
		sfx.play("clank", -12.0, randf_range(1.1, 1.3))
	var spot: Vector3 = g.pos
	var fs := inv.free_slot()
	var old := {}
	if fs >= 0:
		inv.slots[fs] = item
		inv.active = fs
	else:
		old = inv.cur()
		inv.slots[inv.active] = item
	return_slot = -1
	_remove_ground(g)
	if not old.is_empty():
		if old.k == "fish":
			yard.spawn(old.f, spot + Vector3(0, 0.5, 0), Vector3(0, 2.0, 0))
		else:
			_place_ground(old, spot, false)
	sfx.play("plop", -3.0, 1.2)
	view_pop = 0.6
	_hands_changed()
	return true

## Take one fish out of a bucket lying on the ice.
func _take_from_ground_bucket(g: Dictionary) -> bool:
	var fl: Array = g.item.fish
	if fl.is_empty():
		return false
	if free_space() <= 0:
		_say("Hands full. Q puts what you hold down.")
		sfx.play("deny")
		return false
	var f: Dictionary = fl.pop_back()
	_add_fish_to_hands(f)
	_refresh_bucket_node(g)
	sfx.play("plop", -3.0, 1.4)
	_hands_changed()
	hold_node.position = HOLD_REST + Vector3(0, -0.25, 0.2)
	return true

func _click_ground(g: Dictionary) -> void:
	if g.is_empty():
		return
	var it: Dictionary = g.item
	if it.k == "bucket":
		var hf := _held_fish()
		if not hf.is_empty():
			if it.fish.size() >= _bucket_cap():
				_say("That bucket is full.")
				sfx.play("deny")
				return
			it.fish.append(hf)
			inv.slots[inv.active] = {}
			_refresh_bucket_node(g)
			sfx.play("plop", -2.0, 1.1)
			_hands_changed()
			return
		if not it.fish.is_empty():
			_take_from_ground_bucket(g)
			return
	_take_ground(g)

func _ground_text(g: Dictionary) -> String:
	if g.is_empty():
		return ""
	var it: Dictionary = g.item
	if it.k == "bucket":
		var n: int = it.fish.size()
		if not _held_fish().is_empty() and n < _bucket_cap():
			return "Click: put the fish in  (%d / %d)" % [n, _bucket_cap()]
		if n > 0:
			return "Click: take a fish out  (%d / %d)   E: pick the bucket up   Kick: tip it over" % [n, _bucket_cap()]
		return "Click or E: pick up the bucket  (empty)"
	return "Click or E: pick up the %s" % _tool_name(int(it.t))

func _tool_name(t: int) -> String:
	match t:
		0: return DRILL_NAMES[mini(GameState.level("drill"), DRILL_NAMES.size() - 1)]
		1: return ROD_NAMES[mini(GameState.level("lines"), ROD_NAMES.size() - 1)]
	return "Builder's Kit"

## Kicking a bucket tips it over: everything inside spills out ahead of the boot. Returns how many buckets tipped.
func _kick_buckets(pos: Vector3, fwd: Vector3, power: float) -> int:
	var n := 0
	for g in ground:
		if g.item.k != "bucket" or g.item.fish.is_empty():
			continue
		var off: Vector3 = g.pos - pos
		off.y = 0.0
		if off.length() > KICK_REACH + 0.4 or off.normalized().dot(fwd) < 0.45:
			continue
		var spilled: Array = g.item.fish
		g.item.fish = []
		for f in spilled:
			var dirf := fwd.rotated(Vector3.UP, randf_range(-0.55, 0.55))
			# (they leave from just outside the bucket's own mouth, or the bucket would swallow them straight back)
			var e := yard.spawn(f, g.pos + dirf * 0.95 + Vector3(0, 0.9, 0), dirf * (power * 0.45 + randf_range(0.5, 3.0)) + Vector3(0, randf_range(3.5, 6.0), 0))
			e.spin = randf_range(-10.0, 10.0)
		_refresh_bucket_node(g)
		_snow_fx(g.pos + Vector3(0, 0.3, 0), 8, 1.2)
		sfx.play("kick", -4.0, 0.7)
		sfx.play("clank", -6.0, randf_range(0.75, 0.95))
		n += 1
	return n

# ---------- the tool rack ----------
func _click_rack(t: int) -> void:
	if t == 2 and _kit_modes().is_empty():
		_say("The kit is empty: complete goals to get the tools to put in it.")
		return
	var si := inv.find_tool(t)
	if si >= 0:
		_select_slot(si)
		_say("You already carry the %s." % _tool_name(t))
		return
	for g in ground.duplicate():   # it lies out on the ice: it comes back to the rack (and then to your hands)
		if g.item.k == "tool" and int(g.item.t) == t:
			_remove_ground(g)
			_say("The %s flew back to the rack." % _tool_name(t))
	var item := Inventory.tool_item(t)
	var fs := inv.free_slot()
	if fs >= 0:
		inv.slots[fs] = item
		inv.active = fs
	else:
		var old := inv.cur()
		inv.slots[inv.active] = item
		if old.k == "bucket":
			_place_ground(old, _drop_spot(false), true)
		elif old.k == "fish":
			yard.spawn(old.f, cam.global_position + Vector3(0, -1.0, 0) + (-cam.global_basis.z) * 0.9, Vector3(0, 2.0, 0))
		# (a tool you swap out simply hangs back on the rack)
	return_slot = -1
	sfx.play("buy", -8.0, 1.2)
	view_pop = 0.6
	_hands_changed()

func _rack_text(t: int) -> String:
	if t == 2 and _kit_modes().is_empty():
		return "Builder's Kit: complete goals to fill it"
	if inv.find_tool(t) >= 0:
		return "You carry the %s (slot %d)" % [_tool_name(t), inv.find_tool(t) + 1]
	if _ground_has_tool(t):
		return "Click: call your %s back from the ice" % _tool_name(t)
	return "Click: take the %s%s" % [_tool_name(t), "  (your hands swap)" if inv.free_slot() < 0 else ""]

func _build_rack() -> void:
	var bp: Vector3 = SceneryScript.bearing_pos(RACK_BEARING, RACK_RADIUS)
	var r := Node3D.new()
	r.position = Vector3(bp.x, 0.0, bp.z)
	add_child(r)
	r.look_at(Vector3(0, 0, 0), Vector3.UP, true)
	rack_pos = r.global_position
	var slots: Array = ItemModels.rack(r)
	_label3d(r, Vector3(0, 3.55, 0.25), "TOOL RACK", 0.012, false)
	var names := ["DRILL", "ROD", "BUILDER'S KIT"]
	for t in 3:
		var mount := Node3D.new()
		mount.position = slots[t]
		r.add_child(mount)
		var tp := mini(GameState.level("drill" if t == 0 else "lines"), TIER_COLORS.size() - 1)
		var m := ItemModels.ground_tool(mount, t, tp, TIER_COLORS[tp], Color(1.0, 0.78, 0.35))
		m.rotation_degrees.y = 90.0
		m.position = Vector3(0.55, -0.12, 0.12)
		m.scale = Vector3.ONE * 1.15
		_no_shadows(m)
		rack_mounts.append(mount)
		var lb := _label3d(r, slots[t] + Vector3(0, -0.36, 0.0), names[t], 0.0045, false)   # (the name stays when the tool is away: you know what hangs there)
		lb.modulate = Color(0.95, 0.85, 0.62)
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(3.2, 0.72, 0.6)
		cs.shape = bx
		body.add_child(cs)
		body.position = slots[t] + Vector3(0, -0.05, 0.1)
		body.set_meta("action", "rack:%d" % t)
		r.add_child(body)
	scenery.obstacles.append(Vector3(bp.x, bp.z, 2.9))

func _refresh_rack() -> void:
	for t in rack_mounts.size():
		var here: bool = (t < 2 or not _kit_modes().is_empty()) and inv.find_tool(t) < 0 and not _ground_has_tool(t)
		(rack_mounts[t] as Node3D).visible = here

# ---------- the slots (a compact dock in the middle of the bottom of the screen) ----------
func _item_name(it: Dictionary) -> String:
	match String(it.get("k", "")):
		"tool":
			var t := int(it.t)
			if t < 2:
				return _tool_name(t)
			return "Builder's Kit: %s" % _kit_name(bmode)
		"fish": return String(it.f.name)
		"bucket": return "Bucket  %d / %d" % [it.fish.size(), _bucket_cap()]
	return ""

func _refresh_dock() -> void:
	if dock_panels.is_empty():
		return
	var sig := "%d|%d|%d|%d|%d" % [inv.active, bmode, GameState.level("drill"), GameState.level("lines"), _bucket_cap()]
	for s in inv.slots:
		sig += "|" + _item_name(s)
	if sig == dock_sig:
		return
	dock_sig = sig
	for i in Inventory.SLOTS:
		var it: Dictionary = inv.slots[i]
		var act := i == inv.active
		dock_panels[i].add_theme_stylebox_override("panel", Style.slot(act, it.is_empty()))
		var kind := -1
		if it.get("k", "") == "tool":
			kind = int(it.t) if int(it.t) < 2 else int(KIT[bmode][0])
		dock_icons[i].set_item(it, kind)
		dock_icons[i].active = act
		dock_icons[i].queue_redraw()
		match String(it.get("k", "")):
			"bucket": dock_badges[i].text = "%d/%d" % [it.fish.size(), _bucket_cap()]
			_: dock_badges[i].text = ""
		dock_keys[i].add_theme_color_override("font_color", Style.AMBER if act else Style.MUTED)
		if act and dock_active_last != inv.active:
			dock_panels[i].pivot_offset = dock_panels[i].size * 0.5
			dock_panels[i].scale = Vector2.ONE * 1.14
			dock_panels[i].create_tween().tween_property(dock_panels[i], "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		elif not act:
			dock_panels[i].scale = Vector2.ONE
	dock_active_last = inv.active
	var nm := _item_name(inv.cur())
	if tool == 6:
		nm += "  (%d)" % _build_cost(build_item)
	elif tool == 2:
		nm += "  (%d)" % auto_cost()
	elif tool == 3:
		nm += "  (%d)" % smoker_cost()
	elif tool == 4:
		nm += "  (%d)" % table_cost()
	elif tool == 5:
		nm += "  (12+)"
	dock_name.text = nm if nm != "" else "Empty hands"
	if tool >= 2 and _kit_modes().size() > 1:
		dock_name.text += "     B: switch"

func _refresh_view() -> void:
	_set_hold_visual()
	_refresh_dock()

## Each frame: the held fish hangs in front of you, lags when you turn, bobs when you walk and draws back while you charge a throw.
func _update_hand(delta: float) -> void:
	var hk := _held_kind()
	if hk != "fish" and hk != "bucket":
		hold_node.visible = false
		return
	hold_node.visible = not guide.intro_active and not title_active
	var pl: Node3D = $Player
	var look := Vector2(pl.rotation.y, cam.rotation.x)
	var dl := Vector2(wrapf(look.x - prev_look.x, -PI, PI), look.y - prev_look.y)
	prev_look = look
	hold_sway += Vector2(dl.x * 2.2, -dl.y * 2.2)
	hold_sway *= exp(-9.0 * delta)
	hold_sway = hold_sway.clamp(Vector2(-0.22, -0.22), Vector2(0.22, 0.22))
	var c := maxf(kick_charge, 0.0) if hk == "fish" else 0.0   # only a fish is thrown; a charge with a bucket in hand is a kick
	var tm := Time.get_ticks_msec() * 0.001
	var bob := Vector3(sin(bob_t) * 0.012, absf(sin(bob_t)) * -0.014, 0.0) if moving else Vector3(0, sin(tm * 2.0) * 0.004, 0)
	hold_node.position = hold_node.position.lerp(HOLD_REST + Vector3(hold_sway.x, hold_sway.y, 0.0) + bob + Vector3(0.12, 0.1, 0.2) * c, minf(1.0, delta * 16.0))
	hold_node.rotation = Vector3(-0.25 * c + hold_sway.y * 0.6, -hold_sway.x * 1.2, hold_sway.x * 0.8)
	if hk == "fish" and hold_node.get_child_count() > 0:
		var fm: FishNode = hold_node.get_child(0) as FishNode
		if fm:
			fm.amp = 1.6 + 2.0 * c   # it wriggles harder the more you wind up

## The throw preview: dots along the arc and a ring where it will come down (aqua when that is the Eye's pull).
func _update_arc() -> void:
	var show := not _held_fish().is_empty() and kick_charge >= 0.0 and _cap() and not guide.intro_active and GameSettings.on("arc")
	while arc_dots.size() < 14:
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.09
		sm.height = 0.18
		sm.radial_segments = 6
		sm.rings = 3
		m.mesh = sm
		var mt := StandardMaterial3D.new()
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mt.albedo_color = Color(0.95, 0.6, 0.15)
		mt.disable_fog = true
		m.material_override = mt
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
		arc_dots.append(m)
	if arc_ring == null:
		arc_ring = MeshInstance3D.new()
		var tm2 := TorusMesh.new()
		tm2.inner_radius = 0.8
		tm2.outer_radius = 1.0
		tm2.rings = 24
		tm2.ring_segments = 6
		arc_ring.mesh = tm2
		var mt2 := StandardMaterial3D.new()
		mt2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mt2.albedo_color = Color(0.95, 0.6, 0.15)
		mt2.disable_fog = true
		mt2.render_priority = 2
		arc_ring.material_override = mt2
		arc_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arc_ring.visible = false
		add_child(arc_ring)
	arc_ring.visible = show
	for d in arc_dots:
		d.visible = show
	if not show:
		return
	var from := _throw_origin()
	var v := _throw_velocity(kick_charge)
	var tt := FishYard.flight_time(from, v)
	var cam_pos := cam.global_position
	for i in arc_dots.size():
		var dp := FishYard.arc_point(from, v, tt * float(i + 1) / float(arc_dots.size() + 1))
		arc_dots[i].global_position = dp
		arc_dots[i].scale = Vector3.ONE * clampf(dp.distance_to(cam_pos) / 7.0, 1.0, 5.0)   # far dots grow so the arc reads at any range
	var land := FishYard.arc_point(from, v, tt)
	arc_ring.global_position = Vector3(land.x, 0.05, land.z)
	var into_eye := Vector2(land.x, land.z).length() < EYE_R + FishYard.PULL_RANGE
	var col := Color(0.35, 0.9, 0.85) if into_eye else Color(0.95, 0.6, 0.15)
	(arc_ring.material_override as StandardMaterial3D).albedo_color = col
	for d in arc_dots:
		(d.material_override as StandardMaterial3D).albedo_color = col
	arc_ring.scale = Vector3.ONE * clampf(land.distance_to(cam_pos) / 9.0, 1.0, 3.5) * (1.0 + 0.1 * sin(Time.get_ticks_msec() * 0.012))

func _start_kick() -> void:
	kick_charge = 0.0
	if _held_fish().is_empty():
		_boot_move(Vector3(0.28, -0.34, -0.3), Vector3(-18, 38, 6), 0.35)   # the foot draws back (with a fish in hand the arm winds up instead)

## Release the right mouse button: everything in front of your boots flies off the way you are facing.
func _release_kick() -> void:
	if kick_charge < 0.0:
		return
	if not _held_fish().is_empty():   # a fish in hand: the charge is a throw
		var frac := kick_charge
		kick_charge = -1.0
		_throw_held(frac)
		return
	var power := lerpf(KICK_MIN, _kick_max(), kick_charge)
	kick_charge = -1.0
	var pl: Node3D = $Player
	var fwd := -pl.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var hit := yard.kick(pl.global_position, fwd, power, KICK_REACH)
	hit += _kick_buckets(pl.global_position, fwd, power)
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
func _pick_up() -> void:
	# the thing you are looking at first (a tool or bucket on the ice), then fish around your feet, then the nearest thing within reach
	var raw := _aim()
	if raw.begins_with("item:"):
		var g := _ground_by_id(int(raw.substr(5)))
		if not g.is_empty():
			_take_ground(g)
			return
	var pp: Vector3 = $Player.global_position
	if yard.near(pp, PICKUP_RADIUS) > 0:
		_sweep_fish()
		return
	var best := {}
	var bd := SWEEP_REACH
	for g in ground:
		var d := Vector2(g.pos.x - pp.x, g.pos.z - pp.z).length()
		if d < bd:
			bd = d
			best = g
	if not best.is_empty():
		_take_ground(best)
		return
	_say("Nothing within reach.")

## E: scoop the loose fish around your feet into your buckets first, then your hands.
func _sweep_fish() -> void:
	var pp: Vector3 = $Player.global_position
	if yard.near(pp, PICKUP_RADIUS) == 0:
		_say("No fish within reach.")
		return
	if free_space() <= 0:
		_say("Your hands and buckets are full: feed the Eye, or buy another bucket.")
		sfx.play("deny")
		return
	var got := yard.collect(pp, PICKUP_RADIUS, free_space())
	pickup_from = yard.last_collected.duplicate()
	for f in got:
		_add_fish_to_hands(f, true)
	_fly_to_hand(got)
	sfx.play("plop", -2.0, 1.4)
	view_pop = 1.0
	_hands_changed()

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

## A fish thrown into a machine goes in: a depot sends it to the Eye by sled, a smoker starts (or joins) a smoking batch.
func _on_fish_sunk(f: Dictionary, holder: Node3D, pos: Vector3, id: String) -> void:
	var tw := create_tween()
	tw.tween_property(holder, "scale", Vector3.ONE * 0.1, 0.2)
	tw.tween_callback(holder.queue_free)
	if id.begins_with("depot:"):
		var di := int(id.substr(6))
		if di >= 0 and di < depots.size():
			var d: Dictionary = depots[di]
			_fly_fish(f, d.pos + Vector3(0, 1.8, 0), 0.25, "eye", EYE_MULT * DEPOT_MULT)
			stats.deliveries += 1
			_float_text(d.pos + Vector3(0, 3.4, 0), "in!", Color(0.8, 1.0, 0.9))
			sfx.play("coin", -4.0, 0.85)
	elif id.begins_with("grinder:"):
		var gi := int(id.substr(8))
		if gi >= 0 and gi < props.size():
			_grind(f, props[gi].pos)
	elif id.begins_with("bucket:"):
		var bg := _ground_by_id(int(id.substr(7)))
		if not bg.is_empty() and bg.item.fish.size() < _bucket_cap():
			bg.item.fish.append(f)
			_refresh_bucket_node(bg)
			sfx.play("plop", -2.0, 0.9)
			_float_text(bg.pos + Vector3(0, 1.3, 0), "%d / %d" % [bg.item.fish.size(), _bucket_cap()], Color(0.85, 0.95, 1.0), 0.012)
		else:   # it filled in the same instant: the fish bounces back out
			yard.spawn(f, pos + Vector3(0, 0.6, 0), Vector3(randf_range(-2, 2), 4.0, randf_range(-2, 2)))
	elif id.begins_with("smoker:"):
		var ti := int(id.substr(7))
		if ti >= 0 and ti < holes.size() and holes[ti].state == "smoker":
			var t: Dictionary = holes[ti]
			if t.slot.is_empty():
				t.smoke_t = SMOKE_TIME
			t.slot.append(f)
			sfx.play("plop", -2.0, 0.8)
	_refresh()

## A loose fish crossed into the pupil: the Eye eats it (pays now) and it spirals down the funnel.
func _on_fish_swallowed(f: Dictionary, holder: Node3D, pos: Vector3) -> void:
	if combo > 0:
		combo_t = COMBO_WINDOW   # pushing a catch home keeps the combo alive
	_feed_eye(f, EYE_MULT, true)
	var tw := create_tween()
	_spiral_into_eye(tw, holder, [pos, pos], 0.5)
	tw.tween_callback(holder.queue_free)

## Would a world point land under one of the HUD cards? (3D labels ghosted through the NEXT card and the goal cards.)
func _under_hud(world: Vector3) -> bool:
	if cam.is_position_behind(world):
		return false
	var sp := cam.unproject_position(world)
	var vp := get_viewport().get_visible_rect().size
	return Rect2(Vector2(vp.x * 0.5 - 340.0, 0.0), Vector2(680.0, 130.0)).has_point(sp) \
		or Rect2(Vector2(0.0, 0.0), Vector2(340.0, 230.0)).has_point(sp) \
		or Rect2(Vector2(vp.x - 340.0, 0.0), Vector2(340.0, 190.0)).has_point(sp)

## A full-screen panel or scene that owns the keyboard and the mouse (photo mode only owns the mouse: you can still walk to frame a shot).
func _overlay_blocks_walk() -> bool:
	return letters_panel.visible or ledger_panel.visible or (dream != null and dream.active) or (peer != null and peer.want_open)

func _overlay_blocks_click() -> bool:
	return refreeze_panel.visible or letters_panel.visible or ledger_panel.visible or photo or (dream != null and dream.active) or (peer != null and peer.want_open)

## Hold C over a hole within reach: a round window opens on the water under it (what is really left in that tile). Releasing C closes it.
func _hole_of_action(a: String) -> Dictionary:
	if not a.begins_with("hole:"):
		return {}
	for t in holes:
		if "hole:%d" % t.idx == a:
			return t
	return {}

func _update_peer(delta: float, raw: String) -> void:
	if peer == null:
		return
	var hold := (Input.is_physical_key_pressed(KEY_C) or peer_test_hold) and _cap() and not title_active and not guide.intro_active and not photo \
		and not refreeze_panel.visible and not journal_panel.visible and not letters_panel.visible and not ledger_panel.visible and not (dream != null and dream.active)
	if hold and not peer.want_open:
		var t := _hole_of_action(raw)
		if not t.is_empty() and aim_flat <= PEER_RANGE:
			var hp: Vector3 = t.node.global_position if t.get("node") != null else Vector3.ZERO
			peer.open(model.stock.get(t.c, {}), Vector2(hp.x, hp.z).length() < 30.0, "")
			peer_cell = t.c
	elif not hold and peer.want_open:
		peer.close()
	peer.update(delta)

var peer_cell := Vector2i.ZERO

func _walk(delta: float) -> void:
	if guide.intro_active or _overlay_blocks_walk():
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
				MachineFX.spin(t.node, delta)
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
	msg_label.text = ""   # a leftover "Cast a line" must not sit on the screen during the fight
	msg_time = 0.0
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
	if carrying():
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
	var fs := inv.take_cargo()   # everything you carry: loose fish and whole buckets
	if fs.is_empty():
		_tithe()
		return
	var from := _hand_origin()
	var gap := 0.0
	for i in fs.size():  # one at a time, faster and faster: a rhythm you can feel
		_fly_fish(fs[i], from, gap, "eye", EYE_MULT, true)
		gap += maxf(0.27 * pow(0.84, i), 0.085)
	stats.deliveries += 1
	_hands_changed()

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
	var base := clampf(sqrt(float(stats.eye_fed) / float(eye_stage_at(EYE_STAGES.size() - 1))), 0.0, 1.0)
	if int(stats.get("ajar", 0)) > 0 or int(stats.eye_fed) > 0:   # after the opening the Eye never quite closes again
		base = maxf(base, 0.10)
	return maxf(base, cine_eye)

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
	if eye_pulse_t <= 0.0:   # the Eye's progress bar nudges when it eats (not on every single belt fish)
		eye_pulse_t = 0.22
		eye_bar.pivot_offset = eye_bar.size * 0.5
		eye_bar.scale = Vector2(1.0, 1.9)
		eye_bar.create_tween().tween_property(eye_bar, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var st := eye_stage()
	if st > eye_seen_stage:
		eye_seen_stage = st
		_eye_stage_up(st)

## The swallow itself: each fish in a hand-fed streak rings a higher note, and the Eye answers bigger and bigger.
## A quick pulse on a HUD control (scale up, ease back).
func _pulse(c: Control, amount := 1.1) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2.ONE * amount
	c.create_tween().tween_property(c, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
	sfx.score.hit("awaken" if st >= EYE_STAGES.size() else "stage")
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

# ---------- the builder's kit: cannery, sorter, depot, ice-breaker (B cycles what it builds) ----------
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
		4: return int(ceil(110.0 * pow(1.6, _prop_count("grinder"))))
		5: return int(ceil(140.0 * pow(1.6, _prop_count("fan"))))
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
	for pr in props:
		if flat.distance_to(Vector2(pr.pos.x, pr.pos.z)) < radius + 2.0:
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
		l.visibility_range_end = 20.0
		l.no_depth_test = false
		l.modulate = Color(1.0, 0.9, 0.7)
	else:
		MachineModels.sorter(m)
		var l2 := _label3d(m, Vector3(0, 3.7, 0), "SORTER x1.6 (5+)", 0.012)
		l2.visibility_range_end = 20.0
		l2.no_depth_test = false
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
	l.visibility_range_end = 22.0
	l.no_depth_test = false
	l.modulate = Color(1.0, 0.9, 0.7)
	depots.append(d)
	scenery.obstacles.append(Vector3(pos.x, pos.z, 2.2))
	yard.sinks.append({"pos": Vector3(pos.x, 0, pos.z), "r": 3.0, "h": 2.2, "id": "depot:%d" % d.idx, "accept": func(): return true})
	stats.depots += 1
	if pay:
		_say("Depot built. Drop fish here and a sled runs them to the Eye.")
		sfx.play("buy")
		_refresh()

func _prop_count(kind: String) -> int:
	var n := 0
	for pr in props:
		if pr.kind == kind:
			n += 1
	return n

## A bait grinder or a wind fan on open ice (the kit's last two builds). The fan always faces the Eye.
func _build_prop(pos: Vector3, kind: String, pay := true) -> void:
	if pay and not _spend(float(_build_cost(4 if kind == "grinder" else 5))):
		return
	var node := Node3D.new()
	node.position = Vector3(pos.x, 0.0, pos.z)
	add_child(node)
	node.look_at(Vector3(0, 0, 0), Vector3.UP, true)   # local +Z faces the Eye
	var pr := {"kind": kind, "pos": node.position, "node": node, "idx": props.size(), "part": null}
	var hit := _box(node, Vector3(0, 1.1, 0), Vector3(2.4, 2.2, 2.0), Color.WHITE, "prop:%d" % pr.idx)   # the click target
	hit.visible = false
	if kind == "grinder":
		pr.part = MachineModels.grinder(node).wheel
		yard.sinks.append({"pos": Vector3(pos.x, 0, pos.z), "r": 1.5, "h": 3.0, "id": "grinder:%d" % pr.idx, "accept": func(): return true})
		if pay:
			stats.grinders += 1
	else:
		pr.part = MachineModels.fan(node).rotor
		var dir := Vector2(-pos.x, -pos.z).normalized()
		yard.fans.append({"pos": Vector2(pos.x, pos.z), "dir": dir, "r": FAN_REACH, "k": FAN_PUSH, "idx": pr.idx})
		if pay:
			stats.fans += 1
	_pop_in(node)
	var lb := _label3d(node, Vector3(0, 3.7 if kind == "grinder" else 3.4, 0), "BAIT GRINDER" if kind == "grinder" else "WIND FAN", 0.013)
	lb.visibility_range_end = 22.0
	lb.modulate = Color(1.0, 0.9, 0.7)
	props.append(pr)
	scenery.obstacles.append(Vector3(pos.x, pos.z, 1.5))
	if pay:
		_say("Bait Grinder built. Throw fish in: each one is bait, and every bite comes sooner." if kind == "grinder" else "Wind Fan built. It blows loose fish along the ice toward the Eye.")
		sfx.play("buy")
		_refresh()

## A fish into a grinder (thrown, kicked or clicked in): it becomes bait.
func _grind(f: Dictionary, at: Vector3) -> void:
	var secs := minf(BAIT_SECS + 1.5 * f.base * f.mult, 30.0)
	bait_t = minf(bait_t + secs, BAIT_MAX)
	stats.grinds += 1
	_float_text(at + Vector3(0, 3.0, 0), "+%d s bait" % int(secs), Color(0.6, 0.95, 1.0), 0.016)
	sfx.play("drill", -6.0, 0.6)
	for pr in props:
		if pr.kind == "grinder" and (pr.pos as Vector3).distance_to(at) < 3.0:
			pr["work"] = 1.2
	_refresh()

func _click_prop(pr: Dictionary) -> void:
	if pr.is_empty():
		return
	if pr.kind == "grinder":
		var hf := _held_fish()
		if not hf.is_empty():
			inv.slots[inv.active] = {}
			_hands_changed()
			_grind(hf, pr.pos)
		else:
			_say("Bait Grinder: click or throw a single fish in. Buckets stay safe: take a fish out first.")
	else:
		_say("Wind Fan: it blows loose fish along the ice toward the Eye.")

func _prop_text(pr: Dictionary) -> String:
	if pr.is_empty():
		return ""
	if pr.kind == "grinder":
		if not _held_fish().is_empty():
			return "Click: grind this fish into bait"
		return "Bait Grinder: throw a fish in (bait %d s)" % int(bait_t)
	return "Wind Fan: blows fish toward the Eye"

func _use_depot(d: Dictionary) -> void:
	var fs := inv.take_cargo()
	if fs.is_empty():
		_say("Drop fish here and a sled runs them to the Eye.")
		return
	var n := fs.size()
	var from: Vector3 = d.pos + Vector3(0, 1.8, 0)
	for i in n:
		_fly_fish(fs[i], from, 0.4 + i * 0.1, "eye", EYE_MULT * DEPOT_MULT)
	stats.deliveries += 1
	_float_text(d.pos + Vector3(0, 3.4, 0), "%d fish sent" % n, Color(0.8, 1.0, 0.9))
	sfx.play("coin", 0.0, 0.85)
	_hands_changed()

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
	rig["fx"] = MachineFX.rig_fx(node)
	rig["rumble_t"] = randf_range(0.0, 3.0)
	_pop_in(node)
	rig.tag = _label3d(node, Vector3(0, 8.4, 0), "ICE-BREAKER", 0.016)
	rig.tag.visibility_range_end = 45.0
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
	_say("Lifted the idle Ice-Breaker. Take the kit, switch it to Ice-Breaker (B) and set it down anywhere: it is free.")
	sfx.play("buy")
	_refresh()

func _tick_rigs(delta: float) -> void:
	var ppos: Vector3 = $Player.global_position
	for rg in rigs:
		if rg.has("beacon") and is_instance_valid(rg.beacon):
			rg.beacon.rotation.y += delta * 3.2   # the amber beacon turns while the rig stands
		MachineFX.spin(rg.node, delta)
		if rg.has("fx") and is_instance_valid(rg.fx):   # chewing: chunks fly, the hull rumbles, the view shakes as you come close
			var working: bool = _rig_best(rg).x != 9999 if int(Engine.get_process_frames()) % 20 == int(rg.idx) % 20 else rg.fx.emitting
			rg.fx.emitting = working
			rg["rumble_t"] = float(rg.get("rumble_t", 0.0)) - delta
			if working and rg.rumble_t <= 0.0:
				rg.rumble_t = 4.5
				var rb := MachineFX.rumble_for(ppos.distance_to(rg.node.global_position))
				if rb.shake > 0.0:
					sfx.play("rumble", float(rb.vol_db), 1.25)
					shake = maxf(shake, float(rb.shake))
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
		rg.t = (RIG_INTERVAL * model.wait_factor(best) * 0.6 + 0.6) / overdrive_mult()

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
	if a.begins_with("depot:") or a.begins_with("rig:") or a.begins_with("prop:"): return aim_flat <= RANGE_BUILD
	if a == "eye":
		var pp: Vector3 = $Player.global_position
		return Vector2(pp.x, pp.z).length() - EYE_R <= RANGE_EYE
	if a.begins_with("buy:") or a.begins_with("rack:") or a == "mailbox": return aim_flat <= RANGE_SIGN
	if a.begins_with("item:"): return aim_flat <= RANGE_ITEM
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

func _hole_with_fight() -> bool:
	for h in holes:
		if h.state == "hole" and h.cast == 3:
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
			if _hole_with_fight():
				return "Hold on! Landing the fish..."
			if t.cast == 2: return "BITE! CLICK!"
			if t.cast == 1: return "Waiting... (click to reel in)"
			if _emptied(t):
				if tool == 3 and _tool_unlocked(3): return "Click: build Smoker (%d)" % smoker_cost()
				if tool == 4 and _tool_unlocked(4): return "Click: build Gut Table (%d)" % table_cost()
				return "Fished out (build a Smoker or a Gut Table here with the kit)"
			if tool == 1: return "Click: cast line" if not _other_line(t) else "Click: cast here (reels in your other line)"
			if tool == 2: return "Click: build Auto-Rod (%d)" % auto_cost()
			if tool == 5: return "Build an Auto-Rod here first (kit: Auto-Rod)"
			return "Hole (hold the Rod to cast)"
		"auto":
			if tool == 6 and _tool_unlocked(6):
				if t.belt == null: return "Lay a belt here first (kit: Belt)"
				if build_item <= 1:
					var kind0 := "cannery" if build_item == 0 else "sorter"
					if t.belt.get(kind0, false): return "This belt already has a %s" % kind0
					return "Click: build %s on this belt (%d)" % [BUILD_ITEMS[build_item], _build_cost(build_item)]
				return "Depots and ice-breakers go on open ice (B to switch)"
			if tool == 5 and _tool_unlocked(5) and t.belt == null: return "Click: lay a belt to the Eye (%d)" % belt_cost(t)
			if not t.stash.is_empty():
				return "Click: collect %d fish (what does not fit spills onto the ice)" % t.stash.size()
			if model.tile_left(t.c) == 0:
				return "Click: pick up Auto-Rod (refund %d)" % _refund()
			if t.belt != null: return "Auto-Rod + belt (working)"
			return "Auto-Rod (working)"
		"smoker":
			if t.slot.is_empty():
				if not carrying(): return "Smoker (carry fish here, or throw them in)"
				return "Click: smoke %d fish" % mini(inv.cargo_count(), SMOKER_SLOTS)
			if t.smoke_t > 0.0: return "Smoking..."
			return "Click: collect smoked fish"
		"table":
			var raw := 0
			for f in inv.cargo():
				if not f.gutted:
					raw += 1
			if raw > 0: return "Hold click: gut fish (%d to gut)" % raw
			return "Gut Table (carry fish here)"
	return ""

func _refund() -> int:
	return int(floor(0.6 * AUTO_BASE * pow(AUTO_GROWTH, maxi(_count("auto") - 1, 0))))

func _prompt_for(a: String) -> String:
	if a == "olga":
		return "Click: talk to Olga" if not _hands_have_fish() else "Olga doesn't buy fish: the Eye does"
	if a == "eye":
		var cn := inv.cargo_count()
		if cn == 1 and not _held_fish().is_empty():
			return "Click: put it in (or hold right mouse and aim a lob)"
		if cn == 0:
			if eye_stage() >= TITHE_MIN_STAGE:
				if yard.near_eye(EYE_R + FishYard.PULL_RANGE + 4.0) > 0:
					return "Push the fish into the Eye (walk into them, or kick)"
				if tithe_armed_t > 0.0:
					return "Click again to offer %d coins  (Lv %d, +%d%% value)" % [tithe_cost(), stats.tithe, int(TITHE_BONUS * 100.0 * stats.tithe)]
				return "Click twice: tithe %d coins to the Eye  (Lv %d)" % [tithe_cost(), stats.tithe]
			return "The Eye: push fish into it (or click while carrying fish)"
		return "Click: feed the %d fish you carry to the Eye for %d coins" % [cn, floor(carry_worth() * EYE_MULT)]
	if a.begins_with("depot:"):
		return "Click: send %d fish to the Eye by sled" % inv.cargo_count() if carrying() else "Depot (carry fish here, or throw them in: a sled runs them to the Eye)"
	if a.begins_with("rig:"):
		var rg := _rig_of(a)
		if not rg.is_empty() and _rig_best(rg).x == 9999:
			return "Idle Ice-Breaker: click to pick it up (placing it again is free)"
		return "Ice-Breaker: feeding the Eye from the lake"
	if a.begins_with("prop:"):
		var ppi := int(a.substr(5))
		return _prop_text(props[ppi]) if ppi >= 0 and ppi < props.size() else ""
	if a.begins_with("item:"):
		return _ground_text(_ground_by_id(int(a.substr(5))))
	if a.begins_with("rack:"):
		return _rack_text(int(a.substr(5)))
	if a == "mailbox":
		var nu := Story.unread(story).size()
		return "Click: read Olga's letters (%d new)" % nu if nu > 0 else ("Click: reread Olga's letters" if not story.got.is_empty() else "Olga's mailbox (empty)")
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
			if yard.near($Player.global_position, PICKUP_RADIUS + 1.0) > 0:
				return _yard_hint()   # fish to push beats a lecture about the locked ice under them
			return "LOCKED - clear a neighbouring sector to open %s" % sec.name
		var head := "Solid ice (hold the Drill to dig)"
		if tool == 6 and _tool_unlocked(6):
			if build_item <= 1:
				head = "Click an Auto-Rod with a belt to add a %s (B: switch)" % BUILD_ITEMS[build_item]
			else:
				var rad := 2.6 if build_item == 2 else (2.2 if build_item >= 4 else 6.0)
				var ok := _can_place_at(Vector3(aim_pos.x, 0, aim_pos.z), rad)
				if build_item == 3 and rigs.size() >= rig_cap():
					head = "The lake bears %d ice-breakers: wake the Eye for more" % rig_cap()
				elif build_item >= 4 and _prop_count("grinder" if build_item == 4 else "fan") >= (MAX_GRINDERS if build_item == 4 else MAX_FANS):
					head = "You have enough of those out on the ice"
				elif ok:
					head = "Click: build %s (%d)  [B: switch]" % [BUILD_ITEMS[build_item], _build_cost(build_item)]
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
	var holding := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _cap() and not _overlay_blocks_click()
	if _overlay_blocks_click():
		hold_block = true   # a press that closes a panel (or takes a photo) must not drill when the panel is gone
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
		for f in inv.cargo():
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

## Adds this lake's totals to the lifetime record (called as the lake is banked).
func _bank_life() -> void:
	var life: Dictionary = GameState.meta.get("life", {})
	life["fed"] = int(life.get("fed", 0)) + int(stats.eye_fed)
	life["caught"] = int(life.get("caught", 0)) + int(stats.caught)
	life["sectors"] = int(life.get("sectors", 0)) + model.cleared_count()
	life["tithe"] = int(life.get("tithe", 0)) + int(stats.tithe)
	life["rigs"] = int(life.get("rigs", 0)) + int(stats.rigs)
	GameState.meta["life"] = life

## Lifetime value of a ledger entry: what earlier lakes banked plus the lake in progress.
func ledger_value(key: String) -> float:
	var life: Dictionary = GameState.meta.get("life", {})
	match key:
		"fed": return float(life.get("fed", 0)) + float(stats.eye_fed)
		"caught": return float(life.get("caught", 0)) + float(stats.caught)
		"lakes": return float(_meta_int("lakes"))
		"sectors": return float(life.get("sectors", 0)) + float(model.cleared_count())
		"tithe": return float(life.get("tithe", 0)) + float(stats.tithe)
		"rigs": return float(life.get("rigs", 0)) + float(stats.rigs)
		"species":
			var sp: Array = GameState.meta.get("life_species", [])
			var n := sp.size()
			for k in journal:
				if not sp.has(k):
					n += 1
			return float(n)
		"visitors":
			var sv: Array = GameState.meta.get("life_species", [])
			var seen := {}
			for k in sv:
				if Visitors.is_visitor(k):
					seen[k] = true
			for k in journal:
				if Visitors.is_visitor(k):
					seen[k] = true
			return float(seen.size())
		"keeps": return float(story.keeps.size())
		"letters": return float(story.read.size())
		"ending": return 1.0 if story.ending else 0.0
	return 0.0

## Pays out any ledger tiers passed (pearls, once each). Cheap: eleven comparisons.
func _check_ledger() -> void:
	if restoring or title_active:
		return
	var claimed: Dictionary = GameState.meta.get("ledger", {})
	var pay := Ledger.claimable(ledger_value, claimed)
	if pay.is_empty():
		return
	var total := 0
	for p in pay:
		claimed[p.id] = maxi(int(claimed.get(p.id, 0)), int(p.tier))
		total += int(p.pearls)
	GameState.meta["ledger"] = claimed
	GameState.meta["pearls"] = _meta_int("pearls") + total
	GameState.meta["ledger_pearls"] = _meta_int("ledger_pearls") + total
	var first: Dictionary = pay[0]
	_banner("LEDGER: %s  +%d pearls" % [first.name, total], Style.AMBER)
	_log("LEDGER +%d pearls (%s)" % [total, ",".join(pay.map(func(p): return "%s%d" % [p.id, p.tier]))])
	sfx.play("goal", -6.0)
	if ledger_panel.visible:
		_update_ledger()

func _update_ledger() -> void:
	ledger_panel.show_rows(Ledger.rows(ledger_value), _meta_int("pearls"), _meta_int("ledger_pearls"), Ledger.total_pearls())

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
		ledger_panel.visible = false
		_update_refreeze()

func _update_refreeze() -> void:
	var out := ["REFREEZE THE LAKE\n"]
	out.append("Pearls: %d     This lake is worth +%d more" % [_meta_int("pearls"), pearls_pending()])
	var best := float(GameState.meta.get("best_time", 0.0))
	out.append("Lakes finished: %d     Fastest clear: %s" % [_meta_int("lakes_cleared"), _clock(best) if best > 0.0 else "-"])
	out.append("Next lake: %d%% more fish, fish worth %d%% more" % [int(30.0 * (_meta_int("lakes") + 1)), int(DEPTH_VALUE * 100.0 * (_meta_int("lakes") + 1))])
	out.append("Choose its character (Z X C):")
	var offs := lake_offers()
	for oi in offs.size():
		var mi: Dictionary = LakeModelScript.MODS[offs[oi]]
		out.append("   %s %s   %s" % ["[%s]" % "ZXC"[oi], ("> " if oi == lake_pick() else "  ") + String(mi.name), mi.desc])
	out.append("")
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
## Three lake characters to choose from for the next winter (rolled once per lake, kept in the meta so closing the panel does not reroll).
func lake_offers() -> Array:
	var m := GameState.meta
	var offs: Array = m.get("offers", [])
	if offs.size() != 3 or int(m.get("offers_for", -1)) != _meta_int("lakes") or offs.any(func(o): return not LakeModelScript.MODS.has(o)):
		var pool: Array = LakeModelScript.MODS.keys().filter(func(k): return k != "")
		pool.shuffle()
		offs = pool.slice(0, 3)
		m["offers"] = offs
		m["offers_for"] = _meta_int("lakes")
		m["pick"] = 0
	return offs

func lake_pick() -> int:
	lake_offers()
	return clampi(int(GameState.meta.get("pick", 0)), 0, 2)

func _refreeze_key(key: int) -> bool:
	if key in [KEY_Z, KEY_X, KEY_C]:
		lake_offers()
		GameState.meta["pick"] = [KEY_Z, KEY_X, KEY_C].find(key)
		sfx.play("tick", -4.0, 1.2)
		refreeze_armed = false
		_update_refreeze()
		return true
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
	refreeze_panel.visible = false
	if not test_capture and dream != null:   # the Eye dreams of the winter you just finished, then the lake freezes again
		dream.play(Story.dream_lines(_meta_int("lakes"), int(stats.eye_fed)), "THE EYE DREAMS")
		await dream.finished
	story.dreams = int(story.dreams) + 1   # (counted after: a quit during the dream must not count it twice)
	_bank_and_reset()
	get_tree().reload_current_scene()

## Banks pearls, rolls the next lake's modifier and writes a fresh run to disk (split out so tests can call it).
func _bank_and_reset() -> void:
	var gain := pearls_pending()
	var chosen: String = lake_offers()[lake_pick()]   # (read before the lake count moves on: the offers belong to this lake)
	var m := GameState.meta
	m.pearls = _meta_int("pearls") + gain
	m.lakes = _meta_int("lakes") + 1
	if stats.ended > 0:
		m.lakes_cleared = _meta_int("lakes_cleared") + 1
		var best := float(m.get("best_time", 0.0))
		var t := float(stats.get("ended_time", play_time))
		if best <= 0.0 or t < best:
			m.best_time = t
	m.next_mod = chosen   # the lake you picked (the first offer if you did not pick)
	m.erase("offers")
	_bank_life()
	_log("REFREEZE: +%d pearls, lake %d done in %s" % [gain, _meta_int("lakes"), _clock(play_time)])
	GameState.autosave = false
	GameState.reset(true)
	GameState.upgrades["bucket"] = mini(perk_level("pockets"), UPGRADES.bucket.max)
	GameState.upgrades["drill"] = mini(perk_level("hands"), UPGRADES.drill.max)
	GameState.upgrades["overdrive"] = mini(perk_level("coils"), UPGRADES.overdrive.max)
	GameState.currency = 40.0 * perk_level("seed")
	GameState.save_game(false)

# ---------- save / load ----------
func _item_to(it: Dictionary) -> Dictionary:
	match String(it.get("k", "")):
		"tool": return {"k": "tool", "t": int(it.t)}
		"fish": return {"k": "fish", "f": _fish_to(it.f)}
		"bucket": return {"k": "bucket", "fish": it.fish.map(_fish_to)}
	return {}

func _item_from(d: Dictionary) -> Dictionary:
	match String(d.get("k", "")):
		"tool": return Inventory.tool_item(int(d.t))
		"fish": return Inventory.fish_item(_fish_from(d.f))
		"bucket":
			var fl := []
			for fd in d.get("fish", []):
				fl.append(_fish_from(fd))
			return Inventory.bucket_item(fl)
	return {}

## A fresh run: the drill and the rod in the first two slots (a perk can add buckets: one in the third slot, the rest on the ice).
func _start_kit() -> void:
	inv.clear()
	inv.slots[0] = Inventory.tool_item(Inventory.TOOL_DRILL)
	inv.slots[1] = Inventory.tool_item(Inventory.TOOL_ROD)
	var nb := GameState.level("bucket")
	var pl: Node3D = $Player
	var right := pl.global_basis.x
	for i in nb:
		if i == 0:
			inv.slots[2] = Inventory.bucket_item()
		else:
			_place_ground(Inventory.bucket_item(), _valid_spot(pl.global_position + right * 2.2 * float(i) + (-pl.global_basis.z) * 2.0), false)
	inv.active = 0
	bmode = 0
	_sync_active()

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
	if saved_label:
		saved_t = 2.0
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
		"slots": inv.slots.map(_item_to), "active": inv.active, "bmode": bmode,
		"ground": ground.map(func(g): return {"item": _item_to(g.item), "p": [g.pos.x, g.pos.z], "yaw": g.yaw}),
		"loose": loose, "pending": pend, "pos": [p.position.x, p.position.z],
		"yaw": p.rotation.y, "pitch": cam.rotation.x,
		"day": day_t, "time": play_time, "weather": weather.to_dict(),
		"depots": depots.map(func(d): return [d.pos.x, d.pos.z]), "props": props.map(func(pr): return [pr.kind, pr.pos.x, pr.pos.z]), "bait": bait_t, "rigs": rigs.map(func(rg): return [rg.pos.x, rg.pos.z]),
		"order": order, "orders_done": orders_done, "visits": visit_count, "lake": model.to_dict()}

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
	for gi in mini(goal_done.size(), GOALS.size()):   # goals finished in an older version may have gained an unlock since: re-apply them
		if goal_done[gi]:
			for uid in GOALS[gi].get("unlock", []):
				unlocked[uid] = true
	guide.from_dict(d.get("tips", null))
	for k in d.get("records", {}):
		records[k] = float(d.records[k])
	for k in d.get("journal", {}):
		journal[k] = int(d.journal[k])
	if d.has("slots"):
		inv.clear()
		var sl: Array = d.slots
		for i in mini(sl.size(), Inventory.SLOTS):
			inv.slots[i] = _item_from(sl[i])
		inv.active = clampi(int(d.get("active", 0)), 0, Inventory.SLOTS - 1)
		bmode = clampi(int(d.get("bmode", 0)), 0, KIT.size() - 1)
		if KIT[bmode][0] == 6:
			build_item = int(KIT[bmode][1])
		for gd in d.get("ground", []):
			var it := _item_from(gd.item)
			if not it.is_empty():
				var gg := _place_ground(it, Vector3(gd.p[0], 0.0, gd.p[1]), false)
				gg.yaw = float(gd.get("yaw", 0.0))
				(gg.node as Node3D).rotation.y = gg.yaw
	else:   # a save from before the three slots: the old bucket list becomes loose fish at your feet
		GameState.upgrades["bucket"] = mini(GameState.level("bucket"), UPGRADES.bucket.max)
		_start_kit()
		for fd in d.get("carry", []):
			var op: Array = d.get("pos", [0.0, 0.0])
			yard.spawn(_fish_from(fd), Vector3(op[0] + randf_range(-1.5, 1.5), FishYard.GROUND, op[1] + randf_range(-1.5, 1.5)), Vector3.ZERO)
	var od0: Dictionary = d.get("order", {})   # the open order is back before any restored fish is delivered
	if not od0.is_empty():
		order = od0
		order.have = int(order.get("have", 0))
		order.need = int(order.get("need", 3))
		order.reward = int(order.get("reward", 10))
	orders_done = int(d.get("orders_done", 0))
	visit_count = d.get("visits", {}).duplicate()
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
	for pd in d.get("props", []):
		_build_prop(Vector3(pd[1], 0.0, pd[2]), String(pd[0]), false)
	bait_t = float(d.get("bait", 0.0))
	for rp in d.get("rigs", []):
		_build_rig(Vector3(rp[0], 0.0, rp[1]), false)
	_sync_active()
	day_t = d.get("day", 0.0)
	play_time = float(d.get("time", 0.0))
	weather.from_dict(d.get("weather", {}))
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
			rb -= (RIG_INTERVAL * model.wait_factor(best) * 0.6 + 0.6) / overdrive_mult() * 2.5
	for t in holes:
		if t.state != "auto":
			continue
		var budget := away
		while budget > 0.0 and model.tile_left(t.c) > 0:
			budget -= (AUTO_WAIT[0] + AUTO_WAIT[1]) * 0.5 * bite_mult_base() * model.wait_factor(t.c) / overdrive_mult()
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

## Esc closes a panel or photo mode instead of pausing: `_input` runs before the Player's own handler would free the mouse.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		return
	if title_active or (dream != null and dream.active) or guide.intro_active:
		return
	if letters_panel.visible:
		_close_letters()
	elif photo:
		_toggle_photo()
	elif ledger_panel.visible:
		ledger_panel.visible = false
	elif journal_panel.visible:
		journal_panel.visible = false
	elif refreeze_panel.visible:
		refreeze_panel.visible = false
	else:
		return
	get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if title_active or (title != null and not guide.intro_active):   # the title owns the keyboard (its own Enter handler); nothing leaks into the world behind it
		return
	if dream != null and dream.active:
		return
	if _letters_input(event):
		get_viewport().set_input_as_handled()
		return
	if guide.intro_active:
		if guide.intro_t > guide.skip_after and ((event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_E])):
			guide.skip_intro()
		return
	if photo:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_P, KEY_ESCAPE]:
			_toggle_photo()
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			take_photo()
		elif event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				take_photo()
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				fov_base = clampf(fov_base - 4.0, 25.0, 100.0)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				fov_base = clampf(fov_base + 4.0, 25.0, 100.0)
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
		if event.keycode == KEY_P and _cap() and not journal_panel.visible and not refreeze_panel.visible:
			_toggle_photo()
			return
		if event.keycode == KEY_L and _cap() and not refreeze_panel.visible and not journal_panel.visible:
			ledger_panel.visible = not ledger_panel.visible
			if ledger_panel.visible:
				_update_ledger()
			return
		if event.keycode == KEY_TAB:
			ledger_panel.visible = false
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
		if event.keycode == KEY_F5:
			var order_w := ["clear", "flurry", "snowfall", "blizzard", "fog"]
			weather.elapsed = Weather.CALM_START + 1.0
			weather.force(order_w[(order_w.find(weather.cur) + 1) % order_w.size()])
			_say("[debug] weather: %s" % weather.label())
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
		if event.keycode in [KEY_E, KEY_Z, KEY_Q, KEY_B]:   # the hand keys do nothing while the menu is up (the world is paused behind it)
			if not _cap():
				return
			match event.keycode:
				KEY_E: _pick_up()
				KEY_Z: _take_from_bucket()
				KEY_Q: _drop_active()
				KEY_B: _cycle_build()
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
		if k >= 0 and k < Inventory.SLOTS and _cap():
			_select_slot(k)
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and _cap():
		_cycle_slot(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and _cap():
		if event.pressed:
			_start_kick()
		else:
			_release_kick()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and _cap() \
			and not _overlay_blocks_click():
		var a_click := _aim()
		if a_click in ["", "ice"]:
			if _aim_fish() != null:
				_grab_fish()
				hold_block = true   # the click that grabbed must not also start a drill
				return
			var hk := _held_kind()
			if hk == "fish" or hk == "bucket":   # a fish slides off your hand; a bucket is set down where you aim
				_drop_active(hk == "bucket")
				hold_block = true
				return
		_click(a_click)

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
	if a == "mailbox":
		_open_letters()
		return
	if a.begins_with("item:"):
		_click_ground(_ground_by_id(int(a.substr(5))))
		return
	if a.begins_with("rack:"):
		_click_rack(int(a.substr(5)))
		return
	if a.begins_with("prop:"):
		var pi := int(a.substr(5))
		if pi >= 0 and pi < props.size():
			_click_prop(props[pi])
		return
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
			elif build_item >= 4:
				var kind := "grinder" if build_item == 4 else "fan"
				if _prop_count(kind) >= (MAX_GRINDERS if kind == "grinder" else MAX_FANS):
					_say("You have enough of those out on the ice.")
					sfx.play("deny")
				elif _can_place_at(bp, 2.2):
					_build_prop(bp, kind)
				else:
					_say("Can't build that there.")
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
				_say("Build an Auto-Rod on this hole first (the kit), then lay a belt.")
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
				if not _add_fish_to_hands(sf, true):
					yard.spawn(sf, hp + Vector3(0, 0.4, 0), to_eye.rotated(Vector3.UP, randf_range(-0.6, 0.6)) * randf_range(2.0, 3.2) + Vector3(0, 4.5, 0))
			_hands_changed()
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
		var have := inv.cargo_count()
		if have == 0:
			_say("Carry fish here to smoke them, or throw them in")
			return
		var n := mini(have, SMOKER_SLOTS)
		for i in n:
			t.slot.append(inv.pop_fish())
		t.smoke_t = SMOKE_TIME
		_hands_changed()
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
			_add_fish_to_hands(f, true)
		stats.smokes += 1
		_float_text(t.node.global_position + Vector3(0, 1.2, 0), "smoked x%.1f" % SMOKE_MULT, Color(1, 0.8, 0.5))
		_hands_changed()

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
	if (new_species or _species_value(best.name) >= 14.0) and not test_capture:
		_hero_moment(new_species)
	_kick_tool(-1.0)
	if best.name == "Old Boot":
		_say("Olga will love this... an Old Boot.")
	_after_draw(t)
	_refresh()

## A big catch (or a first of its kind) gets a beat: time slows for half a second, the view eases wide, the music answers.
func _hero_moment(first: bool) -> void:
	sfx.score.hit("stage" if first else "catch")
	if not GameSettings.on("hero"):
		return
	Engine.time_scale = 0.35
	fov_kick = 5.0 * fx_punch if first else 3.0 * fx_punch
	get_tree().create_timer(0.5 if first else 0.35, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)

func _exit_tree() -> void:
	Engine.time_scale = 1.0

# ---------- photo mode ----------
var photo := false
var photo_layer: CanvasLayer
var photo_hint: Label
var photo_flash: ColorRect

func _toggle_photo() -> void:
	photo = not photo
	$UI.visible = not photo
	tool_view.visible = not photo and tool >= 0
	if photo_layer == null:
		photo_layer = CanvasLayer.new()
		photo_layer.layer = 50
		add_child(photo_layer)
		photo_hint = Label.new()
		photo_hint.text = "PHOTO MODE      click or Enter: take a picture      scroll: zoom      walk to frame it      P: back"
		photo_hint.add_theme_font_size_override("font_size", 16)
		photo_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		photo_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		photo_hint.offset_top = -40
		photo_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		photo_layer.add_child(photo_hint)
		photo_flash = ColorRect.new()
		photo_flash.color = Color(1, 1, 1, 0)
		photo_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		photo_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		photo_layer.add_child(photo_flash)
	photo_layer.visible = true
	photo_hint.visible = photo
	if photo:
		photo_hint.modulate.a = 1.0
		create_tween().tween_property(photo_hint, "modulate:a", 0.0, 1.0).set_delay(4.0)
	else:
		fov_base = GameSettings.get_value("fov")
		_refresh_dock()
		_sync_tool_view()

## Saves the frame without the interface to user://photos/ and flashes. Returns the saved path ("" in headless runs).
func take_photo() -> String:
	photo_hint.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return ""
	DirAccess.make_dir_recursive_absolute("user://photos")
	var path := "user://photos/hush_%s.png" % Time.get_datetime_string_from_system().replace(":", "-")
	img.save_png(path)
	sfx.play("tick", -4.0, 0.6)
	sfx.play("thud", -12.0, 1.8)
	photo_flash.color = Color(1, 1, 1, 0.7)
	create_tween().tween_property(photo_flash, "color:a", 0.0, 0.4)
	photo_hint.visible = photo
	return ProjectSettings.globalize_path(path)

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

## Olga's margin notes for the lake's own fish (visitors have theirs in visitors.gd).
const JOURNAL_NOTES := {
	"Minnow": "Plenty. The Eye does not mind plenty.",
	"Perch": "Stripes like a little prisoner. Good eating, they say.",
	"Silver Pike": "All teeth and no opinions.",
	"Golden Trout": "Keep it out of the sun. Or do not: it looks better there.",
	"Old Boot": "Somebody's. Somebody's whole winter.",
	"Old Coin": "Older than the village. Older than the lake, maybe.",
	"Glass Pearl": "Do not hold it up to the Eye. I did once.",
	"Ancient Fish": "Runes on the scales. It looked at me like it knew my name.",
}

func _journal_note(n: String) -> String:
	return String(JOURNAL_NOTES.get(n, ""))

func _rarity(name: String) -> Array:   # rarity colours stay inside the palette: cream, teal, sky, warm amber, bright amber
	var v := _species_value(name)
	if v < 2.5: return ["COMMON", Style.CREAM]
	if v < 6.0: return ["UNCOMMON", Color(0.5, 0.92, 0.84)]
	if v < 20.0: return ["RARE", Color(0.55, 0.8, 1.0)]
	if v < 100.0: return ["EPIC", Color(1.0, 0.72, 0.45)]
	return ["LEGENDARY", Style.AMBER]

func _show_card(best: Dictionary, count: int, new_species: bool, new_record: bool) -> void:
	var rar := _rarity(best.name)
	card_rarity.text = "%s%s%s" % [rar[0], "  -  VISITOR" if Visitors.is_visitor(best.name) else "", "  -  NEW SPECIES" if new_species else ""]
	card_rarity.add_theme_color_override("font_color", rar[1])
	var kp: Dictionary = Story.keep(String(best.get("keep", "")))
	card_name.text = String(kp.name) if not kp.is_empty() else best.name
	if not kp.is_empty():
		card_rarity.text = "KEEPSAKE"
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
		_give_item(Inventory.bucket_item())
		_hands_changed()
		_say("Olga: A bucket! Click fish into it, E sweeps them up, Q sets it down. Buy more and set them around.")
	elif id == "pail":
		for g in ground:
			_refresh_bucket_node(g)
		_hands_changed()
		_say("Olga: Every bucket holds %d now." % _bucket_cap())
	_refresh()
