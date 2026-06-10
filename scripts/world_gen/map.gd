extends Node3D

@export var stats:Stats

var generation_settings:GenerationSettings

## Si es false, _ready() solo limpia BattleFront y no inicia la partida.
## SceneManager lo pone a false cuando necesita generar el mundo con la
## pantalla de carga visible antes de que el juego arranque.
var auto_start_game: bool = true

@onready var ui_layer: UILayer = $Scene/UI_layer as UILayer
@onready var player_handler: PlayerHandler = $Node/PlayerHandler as PlayerHandler

var turn_manager:TurnManager
var ai_controllers:Array[AIController] = []

func _ready() -> void:
	# Limpiar el registro global de frentes por si quedaron instancias
	# de una partida anterior (cambio de escena → menú → nueva partida).
	BattleFront.clear_active_instances()

	if not auto_start_game:
		return

	# Si hay un snapshot pendiente, cargamos en lugar de generar.
	var pending:Dictionary = GameSaveManager.consume_pending_snapshot()
	if not pending.is_empty():
		_start_from_save(pending)
		return

	_start_new_game()


## Inicia la partida después de que el mundo ya ha sido generado/cargado.
## Llamado por SceneManager cuando auto_start_game es false.
func start_game() -> void:
	var pending:Dictionary = GameSaveManager.consume_pending_snapshot()
	if not pending.is_empty():
		_start_from_save(pending)
		return
	_start_new_game()


## --- Flujo de partida nueva (sin save) ---------------------------------

func _start_new_game() -> void:
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
	Events.game_over.connect(_on_game_over)

	# Selector de tiles para eventos (Megalópolis, etc.)
	# Debe responder durante la pausa porque los eventos pausan el árbol
	# y el selector necesita seguir escuchando tile_selected.
	var tile_selector := EventTileSelector.new()
	tile_selector.name = "EventTileSelector"
	tile_selector.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(tile_selector)

	# Registrar jugador como primer controlador
	player_handler.start_game(new_stats)
	turn_manager.register_controller(player_handler)

	# Crear controladores de IA para cada imperio no-jugador
	_create_ai_controllers()

	# Feedback visual de las acciones de la IA (Fase 5):
	# - AIActionFeedback spawnea floating labels 3D sobre las tiles.
	# - AIActionLog mantiene un mini-log lateral con las últimas acciones.
	_install_ai_feedback()

	# Iniciar el primer turno a traves del TurnManager
	ui_layer.ui.initialize_card_pile_ui()
	turn_manager.start_first_round()


## Instancia los nodos de feedback de la IA. Llamar tanto al iniciar
## partida nueva como al cargar de save.
func _install_ai_feedback() -> void:
	# Floating labels 3D — viven en el mundo, hijo del map.
	if get_node_or_null("AIActionFeedback") == null:
		var feedback := AIActionFeedback.new()
		feedback.name = "AIActionFeedback"
		add_child(feedback)
	# AIActionLog está definido como nodo en general_ui.tscn — no se instancia aquí.

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
		ai.turn_manager = turn_manager
		ai_controllers.append(ai)

		# Conectar las stats del primer rival al panel de stats del rival en la UI.
		# El juego es siempre 1v1, así que solo aplica al primer (y único) AIController.
		if ai_controllers.size() == 1 and ui_layer != null:
			ui_layer.rival_stats = ai_stats

		GameLogger.info("[Map] IA registrada: %s" % empire.name)


## --- Flujo de carga desde save -----------------------------------------

func _start_from_save(snapshot:Dictionary) -> void:
	# Apaga el WorldGenerator: en carga reemplazamos su trabajo.
	var wg:Node = get_node_or_null("Node/WorldGenerator")
	if wg:
		wg.set_process(false)
		wg.set_physics_process(false)
		# WorldGenerator hace su trabajo en _ready(); como Map._ready() corre
		# antes, lo neutralizamos sustituyendo settings por null y desconectando.
		# Para evitar que ejecute generate_world, lo eliminamos del árbol antes
		# de que se invoque su _ready(). En la práctica, dado que add_child de
		# WorldGenerator ya ocurrió al instanciar la escena, su _ready() ya
		# se habrá disparado. La forma robusta es comprobar al final si
		# el TileParent tiene tiles "fantasma" generados y limpiarlos.
		pass

	# Limpia tiles que el WorldGenerator pueda haber creado antes de que
	# llegáramos aquí. En la práctica tu _ready() corre primero por orden
	# de árbol, pero es defensivo.
	var tile_parent:Node3D = $Scene/TileParent
	for child in tile_parent.get_children():
		child.queue_free()

	# Aplica el snapshot completo. Esto crea TurnManager, controllers,
	# stats restauradas, modifiers y battle fronts.
	GameStateSerializer.apply_snapshot(snapshot, self)

	# Recuperar el TurnManager creado por apply_snapshot.
	turn_manager = get_node_or_null("TurnManager") as TurnManager

	# Inyectar la referencia al TurnManager en cada AIController para que
	# puedan construir AIWorldView en sus turnos.
	if turn_manager != null:
		for ctrl in turn_manager.controllers:
			if ctrl is AIController:
				(ctrl as AIController).turn_manager = turn_manager

	# Conectar las stats del primer rival al panel de stats del rival en la UI.
	if turn_manager != null and ui_layer != null:
		for ctrl in turn_manager.controllers:
			if ctrl is AIController and ctrl.stats != null:
				ui_layer.rival_stats = ctrl.stats
				break

	# El selector de tiles para eventos también debe existir en partidas
	# cargadas (lo crea map.gd en flujo normal). PROCESS_MODE_ALWAYS para
	# que siga escuchando clicks de tile mientras el árbol está pausado
	# por un evento (mismo motivo que en el flujo de partida nueva).
	if get_node_or_null("EventTileSelector") == null:
		var tile_selector := EventTileSelector.new()
		tile_selector.name = "EventTileSelector"
		tile_selector.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(tile_selector)

	# Feedback visual de las acciones de la IA (Fase 5).
	_install_ai_feedback()

	# Continuar el turno actual del controlador que tocaba.
	if turn_manager and turn_manager.controllers.size() > 0:
		turn_manager.resume_turn()


func _on_game_over(winner: Empire) -> void:
	GameLogger.info("[Map] Partida finalizada. Ganador: %s" % winner.name)
	Events.player_turn_ended.disconnect(turn_manager.on_player_turn_ended)
	Events.player_hand_discarded.disconnect(turn_manager.on_player_hand_discarded)
	Events.game_over.disconnect(_on_game_over)

	var is_player_winner := (player_handler.stats != null
			and player_handler.stats.empire == winner)
	var dialog := AcceptDialog.new()
	dialog.title = "Fin de partida"
	dialog.dialog_text = ("¡Victoria!\n%s ha dominado el mapa." % winner.name
			if is_player_winner
			else "Derrota.\n%s ha ganado la partida." % winner.name)
	dialog.confirmed.connect(func(): Events.navigate_to_main_menu.emit())
	add_child(dialog)
	dialog.popup_centered()


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
