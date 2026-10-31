extends Node3D

@onready var label: Label = $UI/Counter

func _ready() -> void:
	GameState.currency_changed.connect(func(v): label.text = "Kelp: %d" % v)
	label.text = "Kelp: 0"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		GameState.add(1.0 + GameState.level("sickle"))
