extends CanvasLayer
class_name UILayer

@export var stats:Stats : set = _set_stats

@onready var hand: Hand = $Hand as Hand
@onready var ui: Control = $UI as UI

func _set_stats(value:Stats) -> void:
	stats = value
	hand.stats = stats
	ui.stats = stats
