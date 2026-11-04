extends Node3D
## Stationary first-person rig: mouse look only (you stand at your workspot). Esc frees the mouse.
@export var sensitivity := 0.002
@export var pitch_limit := 80.0
var invert_y := false
@onready var cam: Camera3D = $Camera3D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * sensitivity)
		cam.rotation.x = clamp(cam.rotation.x - event.relative.y * sensitivity * (-1.0 if invert_y else 1.0),
			deg_to_rad(-pitch_limit), deg_to_rad(pitch_limit))
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED \
			and not (get_parent() != null and get_parent().has_method("_cap") and get_parent()._cap()):   # (tools can ask the game to count as captured)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()   # the click that resumes play is not also a click on whatever you are looking at
