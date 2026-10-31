extends Node3D

@onready var label: Label = $UI/Counter

func _ready() -> void:
	GameState.currency_changed.connect(func(v): label.text = "Fish: %d" % v)
	label.text = "Fish: 0"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		GameState.add(1.0 + GameState.level("rod"))
