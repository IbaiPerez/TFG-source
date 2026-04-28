extends Node3D

@export var stats:Stats

var generation_settings:GenerationSettings

@onready var ui_layer: UILayer = $Scene/UI_layer as UILayer
@onready var player_handler: PlayerHandler = $Node/PlayerHandler as PlayerHandler

var turn_manager:TurnManager
var ai_controllers:Array[AIController] = []

func _ready() -> void:
	var new_stats:Stats = stats.create_instance()
	ui_layer.stats = new_stats

	# Cargar eventos reales desde recursos
	new_stats.available_events = _load_turn_events()

	# Crear TurnManager
	turn_manager = TurnManager.new()
	turn_manager.name = "TurnManager"
	add_child(turn_manager)

	# Conectar señales del jugador al TurnManager
	Events.player_turn_ended.connect(turn_manager.on_player_turn_ended)
	Events.player_hand_discarded.connect(turn_manager.on_player_hand_discarded)

	# Selector de tiles para eventos (Megalópolis, etc.)
	var tile_selector := EventTileSelector.new()
	tile_selector.name = "EventTileSelector"
	add_child(tile_selector)

	# Registrar jugador como primer controlador
	player_handler.start_game(new_stats)
	turn_manager.register_controller(player_handler)

	# Crear controladores de IA para cada imperio no-jugador
	_create_ai_controllers()

	# Iniciar el primer turno a traves del TurnManager
	ui_layer.ui.initialize_card_pile_ui()
	turn_manager.start_first_round()

func _create_ai_controllers() -> void:
	if generation_settings == null:
		push_warning("[Map] No hay generation_settings, no se crean IAs")
		return

	var initial_stats_template:Stats = stats

	for empire in generation_settings.empires:
		# Crear una instancia de Stats para cada IA
		# Usamos el mismo empire que EmpireCreator ya coloco en el mapa
		var ai_stats:Stats = initial_stats_template.create_instance()
		ai_stats.empire = empire
		ai_stats.available_events = _load_turn_events()

		# Crear y registrar el AIController
		var ai := AIController.new()
		ai.name = "AIController_%s" % empire.name
		$Node.add_child(ai)
		ai.start_game(ai_stats)
		turn_manager.register_controller(ai)
		ai_controllers.append(ai)

		print("[Map] IA registrada: %s" % empire.name)


static func _load_turn_events() -> Array[TurnEvent]:
	var events:Array[TurnEvent] = []
	var dir := DirAccess.open("res://resources/turn_events/")
	if dir == null:
		push_warning("[Map] No se pudo abrir el directorio de eventos")
		return events

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var event := load("res://resources/turn_events/" + file_name) as TurnEvent
			if event:
				events.append(event)
		file_name = dir.get_next()
	dir.list_dir_end()

	return events
