extends Node3D

@export var stats:Stats

@onready var ui_layer: UILayer = $Scene/UI_layer as UILayer
@onready var player_handler: PlayerHandler = $Node/PlayerHandler as PlayerHandler

func _ready() -> void:
	var new_stats:Stats = stats.create_instance()
	ui_layer.stats = new_stats
	
	Events.player_turn_ended.connect(player_handler.end_turn)
	Events.player_hand_discarded.connect(player_handler.start_turn)
	
	start_game(new_stats)

func start_game(new_stats:Stats) -> void:
	player_handler.start_game(new_stats)
