class_name Companion
extends Node3D
## Juniper, Olga's sled dog. She sleeps curled by the camp fire; walk close and she wakes, then trots along behind you, sits when you
## stand still, trots over to sniff a fish you drop or a catch that lands, barks when a letter arrives, and goes home to sleep when
## you wander far off or the night is deep and you are near the camp. She is company only: she never carries, blocks or collects anything,
## so the economy and the physics are untouched. All decisions live in CompanionBrain (pure data, tested headless); this node poses the model.

## --- the brain: no scene nodes, just numbers ---
class Brain extends RefCounted:
	const WAKE_DIST := 6.0
	const WAKE_TIME := 0.9
	const FOLLOW_GAP := 2.6      # she walks this far behind you
	const SIT_DIST := 3.4        # closer than this and she settles
	const LOSE_DIST := 70.0      # farther than this she gives up and goes home
	const SNIFF_RANGE := 14.0
	const MAX_SPEED := 7.5

	var home := Vector3.ZERO
	var pos := Vector3.ZERO
	var yaw := 0.0
	var state := "sleep"         # sleep, follow, sit, sniff, home
	var speed := 0.0
	var wake_t := 0.0
	var idle_t := 0.0
	var sniff_t := 0.0
	var sniff_at := Vector3.ZERO
	var bark_req := false        # set when she wants to bark (the node plays the sound and clears it)
	var t := 0.0

	func _init(home_in := Vector3.ZERO) -> void:
		home = home_in
		pos = home_in

	## Something dropped or landed at `at`: she may go and look (only in follow or sit, only if it is close).
	func notice(at: Vector3, player: Vector3) -> void:
		if state in ["follow", "sit"] and Vector2(at.x - pos.x, at.z - pos.z).length() < SNIFF_RANGE and Vector2(at.x - player.x, at.z - player.z).length() < SNIFF_RANGE:
			state = "sniff"
			sniff_at = at
			sniff_t = 0.0

	func bark() -> void:
		if state != "sleep":
			bark_req = true

	## One step. `player_vel` is the player's velocity (for walking ahead of the heading), `night` 0..1, `cutscene` freezes her where she is.
	func step(delta: float, player: Vector3, player_vel: Vector3, night: float, cutscene := false) -> void:
		t += delta
		if cutscene:
			speed = 0.0
			return
		var dp := Vector2(player.x - pos.x, player.z - pos.z)
		var dist := dp.length()
		var dhome := Vector2(home.x - pos.x, home.z - pos.z).length()
		match state:
			"sleep":
				speed = 0.0
				if dist < WAKE_DIST:
					wake_t += delta
					if wake_t >= WAKE_TIME:
						state = "follow"
						wake_t = 0.0
						bark_req = true   # a wake-up woof
				else:
					wake_t = maxf(wake_t - delta, 0.0)
			"follow", "sit":
				var behind := Vector3(player.x, 0.0, player.z)
				var v2 := Vector2(player_vel.x, player_vel.z)
				if v2.length() > 0.5:   # she trots on the side you are heading from
					var back := -v2.normalized() * FOLLOW_GAP
					behind += Vector3(back.x, 0.0, back.y)
				else:
					behind += Vector3(1.6, 0.0, 1.8)   # standing still: a spot at your side
				if dist > LOSE_DIST or (night > 0.8 and Vector2(player.x - home.x, player.z - home.z).length() < 14.0 and dist < 9.0 and v2.length() < 0.3 and idle_t > 12.0):
					state = "home"
				elif dist < SIT_DIST and v2.length() < 0.5:
					idle_t += delta
					speed = move_toward(speed, 0.0, delta * 14.0)
					if idle_t > 1.5:
						state = "sit"
				else:
					idle_t = 0.0
					state = "follow"
				if state == "follow":
					_goto(behind, delta, minf(MAX_SPEED, 1.5 + dist * 1.1))
			"sniff":
				var to := Vector2(sniff_at.x - pos.x, sniff_at.z - pos.z)
				if to.length() > 1.1:
					_goto(sniff_at, delta, 6.0)
				else:
					speed = move_toward(speed, 0.0, delta * 14.0)
					sniff_t += delta
					if sniff_t > 1.6:
						state = "follow"
			"home":
				_goto(home, delta, 5.5)
				if dhome < 0.8:
					state = "sleep"
					speed = 0.0
	func _goto(target: Vector3, delta: float, want_speed: float) -> void:
		var d := Vector2(target.x - pos.x, target.z - pos.z)
		var dist := d.length()
		if dist < 0.05:
			speed = 0.0
			return
		speed = move_toward(speed, minf(want_speed, dist / maxf(delta, 0.001)), delta * 18.0)
		var dir := d / dist
		pos += Vector3(dir.x, 0.0, dir.y) * speed * delta
		yaw = lerp_angle(yaw, atan2(-dir.x, -dir.y), minf(1.0, delta * 9.0))   # the model faces -Z

## --- the node ---
var brain: Brain
var dogm: Dictionary
var phase := 0.0
var _player := Vector3.ZERO
var last_player := Vector3.ZERO
var vel := Vector3.ZERO
var barks := 0
var sfx_cb: Callable        # called as sfx_cb("bark") when she barks

func setup(home: Vector3) -> void:
	brain = Brain.new(home)
	dogm = NpcModels.dog(Color(0.72, 0.58, 0.42), Color(0.38, 0.28, 0.2))
	add_child(dogm.root)
	position = home
	_pose(0.0)

## Called each frame by the living lake. `player` is the camera/feet position (y ignored).
func update(delta: float, player: Vector3, night: float, cutscene := false) -> void:
	if brain == null:
		return
	if delta > 0.0:
		vel = vel.lerp((player - last_player) / delta, minf(1.0, delta * 6.0))
	last_player = player
	_player = player
	var was := brain.pos
	brain.step(delta, player, vel, night, cutscene)
	position = Vector3(brain.pos.x, 0.0, brain.pos.z)
	rotation.y = brain.yaw
	phase += brain.speed * delta * 1.7
	if brain.bark_req:
		brain.bark_req = false
		barks += 1
		if sfx_cb.is_valid():
			sfx_cb.call("bark")
	_pose(delta)

func notice(at: Vector3) -> void:
	if brain:
		brain.notice(at, _player)

func bark() -> void:
	if brain:
		brain.bark()

func _pose(_delta: float) -> void:
	if dogm.is_empty():
		return
	var body: Node3D = dogm.body
	var head: Node3D = dogm.head
	var legs: Array = dogm.legs
	var tail: Node3D = dogm.tail
	var t := brain.t
	match brain.state:
		"sleep":   # curled: low, legs folded, head down, a slow breath
			body.position.y = -0.3 + 0.01 * sin(t * 1.7)
			body.rotation.x = 0.0
			for l in legs:
				(l as Node3D).rotation.x = 1.45 * (1.0 if legs.find(l) < 2 else -1.0)
			head.rotation.x = 0.7
			head.rotation.y = 0.5
			tail.rotation.y = 0.9
		"sit", "sniff":
			if brain.state == "sit":   # sitting: the haunches down, the head up, looking at you, the tail sweeping
				body.position.y = -0.14
				body.rotation.x = -0.32
				for i in legs.size():
					(legs[i] as Node3D).rotation.x = 0.0 if i < 2 else -1.1
				var to := Vector2(_player.x - global_position.x, _player.z - global_position.z)
				head.rotation.y = clampf(wrapf(atan2(-to.x, -to.y) - rotation.y, -PI, PI), -0.9, 0.9)
				head.rotation.x = 0.0 + 0.04 * sin(t * 2.0)
				tail.rotation.y = sin(t * 5.0) * 0.5
			else:   # sniffing: nose to the ice
				NpcModels.dog_run(dogm, phase, brain.speed)
				head.rotation.x = 0.5 + 0.12 * sin(t * 9.0)
				tail.rotation.y = sin(t * 7.0) * 0.4
		_:
			body.rotation.x = 0.0
			NpcModels.dog_run(dogm, phase, brain.speed)
			head.rotation.y = 0.0
			tail.rotation.y = sin(t * 6.0) * 0.45 if brain.speed < 2.0 else tail.rotation.y
