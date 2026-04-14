extends Node3D

@export var stats:Stats

@onready var ui_layer: UILayer = $Scene/UI_layer as UILayer
@onready var player_handler: PlayerHandler = $Node/PlayerHandler as PlayerHandler

func _ready() -> void:
	var new_stats:Stats = stats.create_instance()
	ui_layer.stats = new_stats

	# TEMPORAL: cargar eventos de prueba
	new_stats.available_events = TurnEventFactory.create_test_events()

	Events.player_turn_ended.connect(player_handler.end_turn)
	Events.player_hand_discarded.connect(player_handler.evaluate_end_of_turn)

	start_game(new_stats)
	ui_layer.ui.initialize_card_pile_ui()

func start_game(new_stats:Stats) -> void:
	player_handler.start_game(new_stats)
