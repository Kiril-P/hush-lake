class_name MachineFX
extends RefCounted
## Spectacle for the machines. Two things:
##  * Overdrive Coils made visible: every Auto-Rod and Ice-Breaker wears an amber coil ring that spins faster and glows harder per level, with sparks
##    leaping off it (none at level 0). The numbers come from od_params(level), pure and tested.
##  * The Ice-Breaker at work: while it chews it throws ice chunks and spray; it rumbles and shakes the view as you get close (rumble_for(dist)).
## All visual: no gameplay or economy effect beyond what Overdrive already does.

const AMBER := Color(1.0, 0.78, 0.35)

## ---- machine tiers (aim at an Auto-Rod or an Ice-Breaker and press U) ----
const TIER_MAX := 3

## Work speed of a machine at a tier: x1.0, x1.3, x1.6.
static func tier_speed(tier: int) -> float:
	return 1.0 + 0.3 * float(clampi(tier, 1, TIER_MAX) - 1)

## Coins to take a machine from `tier` to tier + 1; -1 at the top. Auto-Rod 250 / 750, Ice-Breaker 4000 / 12000.
static func upgrade_cost(kind: String, tier: int) -> int:
	if tier >= TIER_MAX or tier < 1:
		return -1
	var base := 250.0 if kind == "auto" else 4000.0
	return int(ceil(base * pow(3.0, tier - 1)))

## Coins spent getting a machine to `tier` (what a pickup refunds a share of).
static func invested(kind: String, tier: int) -> int:
	var n := 0
	for t in range(1, clampi(tier, 1, TIER_MAX)):
		n += upgrade_cost(kind, t)
	return n

## Gold trim for tier 2 and 3: a gold band round the base and, at tier 3, a lamp crown. Replaces any earlier trim (idempotent).
static func sync_tier(machine: Node3D, tier: int, size := 1.0) -> void:
	var old: Node = machine.get_node_or_null("tier_trim")
	if old != null:
		machine.remove_child(old)
		old.queue_free()
	if tier < 2:
		return
	var trim := Node3D.new()
	trim.name = "tier_trim"
	machine.add_child(trim)
	var gold := Color(1.0, 0.82, 0.38)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = gold
	mat.metallic = 0.7
	mat.roughness = 0.35
	mat.emission_enabled = true
	mat.emission = gold
	mat.emission_energy_multiplier = 0.6
	var band := TorusMesh.new()
	band.inner_radius = 0.85 * size
	band.outer_radius = 0.93 * size
	band.rings = 20
	band.ring_segments = 5
	var bm := MeshInstance3D.new()
	bm.mesh = band
	bm.position = Vector3(0, 0.12 * size, 0)
	bm.material_override = mat
	bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trim.add_child(bm)
	for i in 4:   # four gold corner studs
		var s := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(0.14, 0.5, 0.14) * size
		s.mesh = sb
		var a := TAU * i / 4.0 + PI * 0.25
		s.position = Vector3(cos(a) * 0.9 * size, 0.3 * size, sin(a) * 0.9 * size)
		s.material_override = mat
		trim.add_child(s)
	if tier >= 3:
		var crown := MeshInstance3D.new()
		var cm := SphereMesh.new()
		cm.radius = 0.2 * size
		cm.height = 0.4 * size
		crown.mesh = cm
		crown.position = Vector3(0, 2.6 * size, 0)
		var lamp := StandardMaterial3D.new()
		lamp.albedo_color = gold
		lamp.emission_enabled = true
		lamp.emission = gold
		lamp.emission_energy_multiplier = 3.0
		crown.material_override = lamp
		crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		trim.add_child(crown)
	trim.set_meta("tier", tier)

## What the coil aura looks like at an Overdrive level (0..5).
static func od_params(level: int) -> Dictionary:
	var l := clampi(level, 0, 5)
	return {"visible": l > 0, "glow": 0.6 + 0.9 * l, "spin": 1.2 + 1.1 * l, "sparks": 4 * l, "spark_speed": 1.6 + 0.5 * l}

## How loud a working Ice-Breaker is for a listener `dist` metres away: {vol_db, shake}. Silent beyond 45 m, loudest right beside it.
static func rumble_for(dist: float) -> Dictionary:
	var k := clampf(1.0 - dist / 45.0, 0.0, 1.0)
	if k <= 0.0:
		return {"vol_db": -80.0, "shake": 0.0}
	return {"vol_db": lerpf(-26.0, -8.0, k * k), "shake": 0.05 * k * k}

## Adds (or updates) the coil aura on a machine node. `size` scales it (1.0 for an Auto-Rod, ~2.6 for an Ice-Breaker).
static func sync_overdrive(machine: Node3D, level: int, size := 1.0) -> void:
	var aura: Node3D = machine.get_node_or_null("od_aura")
	var p := od_params(level)
	if not p.visible:
		if aura != null:
			machine.remove_child(aura)
			aura.queue_free()
		return
	if aura == null:
		aura = Node3D.new()
		aura.name = "od_aura"
		machine.add_child(aura)
		var ring := TorusMesh.new()
		ring.inner_radius = 1.0 * size
		ring.outer_radius = 1.08 * size
		ring.rings = 24
		ring.ring_segments = 6
		var rm := MeshInstance3D.new()
		rm.name = "ring"
		rm.mesh = ring
		rm.position = Vector3(0, 0.25 * size, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = AMBER
		mat.emission_enabled = true
		mat.emission = AMBER
		rm.material_override = mat
		rm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		aura.add_child(rm)
		var sparks := CPUParticles3D.new()
		sparks.name = "sparks"
		sparks.lifetime = 0.9
		sparks.direction = Vector3.UP
		sparks.spread = 28.0
		sparks.gravity = Vector3(0, -2.0, 0)
		sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		sparks.emission_ring_radius = 1.0 * size
		sparks.emission_ring_inner_radius = 0.8 * size
		sparks.emission_ring_height = 0.1
		sparks.emission_ring_axis = Vector3.UP
		sparks.position = Vector3(0, 0.3 * size, 0)
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * 0.09 * size
		sparks.mesh = bm
		var sm := StandardMaterial3D.new()
		sm.albedo_color = AMBER
		sm.emission_enabled = true
		sm.emission = AMBER
		sm.emission_energy_multiplier = 3.0
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sparks.material_override = sm
		sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		aura.add_child(sparks)
	var rmesh: MeshInstance3D = aura.get_node("ring")
	(rmesh.material_override as StandardMaterial3D).emission_energy_multiplier = p.glow
	var sp: CPUParticles3D = aura.get_node("sparks")
	sp.amount = maxi(int(p.sparks), 1)
	sp.initial_velocity_min = p.spark_speed * 0.6
	sp.initial_velocity_max = p.spark_speed
	sp.emitting = true
	aura.set_meta("level", level)
	aura.set_meta("spin", p.spin)

## Spins every aura under `machine` (called from the game's frame loop for the few machines in view).
## With `viewer` given, the sparks only run while the machine is within SPARK_RANGE of it (hundreds of rods must not all run particles at once).
const SPARK_RANGE := 70.0
static func spin(machine: Node3D, delta: float, viewer := Vector3.INF) -> void:
	var aura: Node3D = machine.get_node_or_null("od_aura")
	if aura != null:
		aura.rotation.y += delta * float(aura.get_meta("spin", 1.0))
		if viewer != Vector3.INF:
			var sp: CPUParticles3D = aura.get_node_or_null("sparks")
			if sp != null:
				var near := machine.global_position.distance_to(viewer) < SPARK_RANGE
				if sp.emitting != near:
					sp.emitting = near

## The Ice-Breaker's working effects: ice chunks thrown up beside the hull and a low spray. Returns the particle node (toggle `.emitting`).
static func rig_fx(rig: Node3D) -> CPUParticles3D:
	var chunks := CPUParticles3D.new()
	chunks.name = "chew"
	chunks.amount = 22
	chunks.lifetime = 1.4
	chunks.direction = Vector3(0, 1, 0)
	chunks.spread = 40.0
	chunks.initial_velocity_min = 4.0
	chunks.initial_velocity_max = 8.5
	chunks.gravity = Vector3(0, -12.0, 0)
	chunks.angular_velocity_min = -240.0
	chunks.angular_velocity_max = 240.0
	chunks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	chunks.emission_box_extents = Vector3(2.4, 0.1, 3.4)
	chunks.position = Vector3(0, 0.4, -5.2)   # at the cutting edge, toward the Eye
	var bm := BoxMesh.new()
	bm.size = Vector3(0.45, 0.22, 0.35)
	chunks.mesh = bm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.82, 0.95, 1.0)
	cm.roughness = 0.3
	cm.emission_enabled = true
	cm.emission = Color(0.35, 0.8, 0.95)
	cm.emission_energy_multiplier = 0.5
	chunks.material_override = cm
	chunks.emitting = false
	rig.add_child(chunks)
	return chunks
