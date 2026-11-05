class_name CameraDirector
extends RefCounted
## A tiny camera director for scripted shots. A "pose" is {pos, look, fov, roll, shake}; shots are functions of time that return poses.
## The director only knows how to put a pose on a camera, blend two poses (a dissolve between shots), add handheld sway and ease.

static func smooth(k: float) -> float:
	var x := clampf(k, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

static func smoother(k: float) -> float:
	var x := clampf(k, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)

## 0..1 progress of t inside [a, b].
static func span(t: float, a: float, b: float) -> float:
	return clampf((t - a) / maxf(b - a, 0.0001), 0.0, 1.0)

static func pose(pos: Vector3, look: Vector3, fov := 70.0, roll := 0.0, shake := 0.0) -> Dictionary:
	return {"pos": pos, "look": look, "fov": fov, "roll": roll, "shake": shake}

static func blend(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var e := smooth(k)
	return {"pos": (a.pos as Vector3).lerp(b.pos, e), "look": (a.look as Vector3).lerp(b.look, e), "fov": lerpf(a.fov, b.fov, e),
		"roll": lerpf(a.roll, b.roll, e), "shake": lerpf(a.shake, b.shake, e)}

## Smooth pseudo-noise (sum of sines): handheld sway with no random jumps.
static func sway(t: float, seed_v := 0.0) -> Vector3:
	return Vector3(sin(t * 1.3 + seed_v) + 0.5 * sin(t * 2.9 + seed_v * 2.1), sin(t * 1.7 + seed_v * 1.3) + 0.4 * sin(t * 3.7 + seed_v), sin(t * 1.1 + seed_v * 0.7)) * 0.5

## Puts a pose on a camera. `fov_base` is the game's field of view (the game adds cine_fov on top of it, so we return the delta).
static func apply(cam: Camera3D, p: Dictionary, t: float, fov_base := 75.0) -> float:
	var sh: float = p.shake
	var off := sway(t, 1.7) * sh
	var pos: Vector3 = p.pos + off
	var dir: Vector3 = (p.look as Vector3) - pos
	if dir.length() < 0.001:
		dir = Vector3(0, 0, -1)
	var up := Vector3.UP
	if absf(dir.normalized().y) > 0.99:
		up = Vector3(0, 0, -1)
	var basis := Basis.looking_at(dir.normalized(), up)
	var roll_total: float = float(p.roll) + sway(t, 5.3).z * sh * 0.05
	basis = basis * Basis(Vector3(0, 0, 1), roll_total)
	cam.global_transform = Transform3D(basis, pos)
	return float(p.fov) - fov_base

## A point `dist` metres along bearing/height, for building shots around the lake centre.
static func orbit(centre: Vector3, bearing_deg: float, radius: float, height: float) -> Vector3:
	var a := deg_to_rad(bearing_deg)
	return centre + Vector3(sin(a) * radius, height, -cos(a) * radius)
