extends Node

var _transitioning := false

const MAP = preload("uid://dxw5gc7xqbkqj")
const BUILDING_PANEL = preload("uid://d4kc0x1wj7vrm")
const TURN_EVENT_PANEL = preload("uid://dt9hturneventpnl")
const SHOP_PANEL = preload("res://scenes/UI/shop/shop_panel.tscn")
const RECOVER_CARD_PANEL = preload("res://scenes/UI/card/recover_card_panel.tscn")
const EVENT_CARD_SELECTION_PANEL = preload("res://scenes/UI/turn_events/event_card_selection_panel.tscn")
const MAIN_MENU = preload("res://scenes/UI/menus/main_menu.tscn")
const EMPIRE_SELECTION = preload("res://scenes/UI/menus/empire_selection.tscn")
const GENERATION_UI = preload("res://scenes/UI/generation_ui.tscn")
const BATTLE_FRONT_PANEL = preload("res://scenes/UI/military/battle_front_panel.tscn")

func _ready() -> void:
	Events.generate_world.connect(_on_events_generate_world)
	Events.navigate_to_empire_selection.connect(_on_navigate_to_empire_selection)
	Events.navigate_to_generation.connect(_on_navigate_to_generation)
	Events.navigate_to_main_menu.connect(_on_navigate_to_main_menu)
	Events.build_card_confirm_started.connect(_on_build_card_confirm_started)
	Events.upgrade_building_card_confirm_started.connect(_on_upgrade_building_card_confirm_started)
	Events.recover_card_confirm_started.connect(_on_recover_card_confirm_started)
	Events.turn_event_triggered.connect(_on_turn_event_triggered)
	Events.turn_event_resolved.connect(_on_event_resolved)
	Events.shop_event_resolved.connect(_on_event_resolved)
	Events.recruit_card_confirm_started.connect(_on_recruit_card_confirm_started)
	Events.open_front_card_confirm_started.connect(_on_open_front_card_confirm_started)
	Events.battle_front_selected.connect(_on_battle_front_selected)

	# Cuando GameSaveManager prepara un snapshot, navegamos al mapa para que
	# Map._ready() lo aplique. La instancia del initial_stats es solo una
	# plantilla — los Stats reales vienen del propio snapshot.
	GameSaveManager.load_requested.connect(_on_load_requested)


func _change_scene(new_scene: Node) -> void:
	if _transitioning:
		new_scene.queue_free()
		return
	_transitioning = true
	await SceneTransition.fade_out()
	var scene_to_remove = get_tree().current_scene
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene
	if scene_to_remove:
		scene_to_remove.queue_free()
	await SceneTransition.fade_in()
	_transitioning = false


func _on_navigate_to_main_menu() -> void:
	var new_scene = MAIN_MENU.instantiate()
	await _change_scene(new_scene)


func _on_navigate_to_empire_selection() -> void:
	var new_scene = EMPIRE_SELECTION.instantiate()
	await _change_scene(new_scene)


func _on_navigate_to_generation(empire: Empire) -> void:
	var new_scene = GENERATION_UI.instantiate()
	new_scene.selected_empire = empire
	await _change_scene(new_scene)


func _on_events_generate_world(settings: GenerationSettings, stats: Stats) -> void:
	var loading := LoadingScreen.new()
	loading.seed_value = settings.map_seed
	await _change_scene(loading)

	# Bloquear nuevas transiciones mientras generamos + transicionamos.
	_transitioning = true
	# Esperar 2 frames para que el jugador vea la pantalla de carga antes de
	# que WorldGenerator bloquee el hilo principal.
	await get_tree().process_frame
	await get_tree().process_frame

	var new_scene = MAP.instantiate()
	var world_generator: Node = new_scene.get_node("%WorldGenerator")
	world_generator.settings = settings
	world_generator.auto_generate_on_ready = false
	new_scene.auto_start_game = false
	new_scene.stats = stats
	new_scene.generation_settings = settings

	# Añadir el mapa al árbol SIN que genere ni inicie el juego todavía.
	# LoadingScreen (layer 99) cubre todo el contenido del mapa.
	get_tree().root.add_child(new_scene)

	# Generar el mundo AHORA: el hilo bloquea pero la pantalla de carga
	# fue el último frame renderizado, por lo que el jugador la ve.
	world_generator.init_seed()
	world_generator.generate_world()

	# Transición visual: fade out → intercambiar escena → iniciar juego → fade in.
	await SceneTransition.fade_out()
	var old_scene := get_tree().current_scene
	get_tree().current_scene = new_scene
	if old_scene:
		old_scene.queue_free()
	new_scene.start_game()
	await SceneTransition.fade_in()
	_transitioning = false


## Navega al mapa con un snapshot ya cargado en GameSaveManager. El
## snapshot contiene su propia referencia a generation_settings y stats,
## así que solo necesitamos instanciar la escena: Map.start_game() lo aplicará.
func _on_load_requested(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return

	var loading := LoadingScreen.new()
	await _change_scene(loading)

	_transitioning = true
	await get_tree().process_frame
	await get_tree().process_frame

	var new_scene = MAP.instantiate()

	# Si el snapshot trae la ruta del GenerationSettings, la fijamos para
	# que cualquier sistema que la consulte la tenga disponible.
	var settings_path:String = snapshot.get("generation_settings", "")
	if settings_path != "" and ResourceLoader.exists(settings_path):
		var settings:GenerationSettings = load(settings_path) as GenerationSettings
		new_scene.generation_settings = settings
		var wg:Node = new_scene.get_node_or_null("%WorldGenerator")
		if wg:
			wg.settings = settings

	# El campo `stats` de Map se usa solo en el flujo nuevo. En carga, las
	# Stats reales se reconstruyen desde el snapshot. Pasamos la plantilla
	# por si algún consumidor del árbol la necesita antes de la carga.
	new_scene.stats = load("res://resources/stats/initial_stats.tres") as Stats
	new_scene.auto_start_game = false

	# Añadir el mapa al árbol sin que arranque el juego todavía.
	get_tree().root.add_child(new_scene)

	# apply_snapshot reconstruye el mundo mientras la pantalla de carga es visible.
	new_scene.start_game()

	await SceneTransition.fade_out()
	var old_scene := get_tree().current_scene
	get_tree().current_scene = new_scene
	if old_scene:
		old_scene.queue_free()
	await SceneTransition.fade_in()
	_transitioning = false

func _on_build_card_confirm_started(card:BuildCard,targets:Array[Node],stats:Stats):
	card.menu = BUILDING_PANEL.instantiate()
	for t in targets:
		card.menu.tile = t
		card.menu.stats = stats
		card.menu.action = card.menu.possible_action.BUILD
		card.menu.buildings = card.buildings
	get_tree().get_first_node_in_group("ui_layer").add_child(card.menu)

func _on_upgrade_building_card_confirm_started(card:UpgradeBuildingCard,targets:Array[Node],stats:Stats):
	card.menu = BUILDING_PANEL.instantiate()
	for t in targets:
		card.menu.tile = t
		card.menu.stats = stats
		card.menu.action = card.menu.possible_action.SHOW
		card.menu.buildings = []
		card.menu.building_to_upgrade_selected.connect(
			func(building): card.old_building = building
			)
	get_tree().get_first_node_in_group("ui_layer").add_child(card.menu)

func _on_recover_card_confirm_started(card:RecoverCard, stats:Stats) -> void:
	card.menu = RECOVER_CARD_PANEL.instantiate()
	card.menu.card_pile = stats.played_pile
	get_tree().get_first_node_in_group("ui_layer").add_child(card.menu)

## Mientras hay un menú de evento abierto pausamos el árbol para que el
## jugador no pueda seguir interactuando con el resto del juego (otras
## tiles, fin de turno, paneles colaterales). Los nodos que SÍ deben
## seguir respondiendo durante la pausa (las propias scenes de evento,
## InteractionTracker para selección de tiles, EventTileSelector y la
## cámara) llevan process_mode = PROCESS_MODE_ALWAYS.
##
## El unpause se dispara desde turn_event_resolved / shop_event_resolved
## (los emite la propia scene de evento al cerrarse), via
## `_on_event_resolved`.
func _on_turn_event_triggered(event:TurnEvent, context:EventContext) -> void:
	var ui_layer := get_tree().get_first_node_in_group("ui_layer")
	var player_handler:PlayerHandler = get_tree().get_first_node_in_group("player_handler")

	get_tree().paused = true

	if event is ShopEvent:
		var shop_event := event as ShopEvent
		var shop_panel:ShopPanel = SHOP_PANEL.instantiate()
		ui_layer.add_child(shop_panel)
		var config := shop_event.generate_shop(context.stats)
		shop_panel.setup(config, context.stats, event.title, event.description)
		# Marcar evento unico si aplica
		if event.unique:
			player_handler.turn_event_manager.stats.used_unique_events.append(event.id)
	else:
		# Añadir panel de selección de carta si no existe ya
		if not ui_layer.has_node("EventCardSelectionPanel"):
			var card_sel := EVENT_CARD_SELECTION_PANEL.instantiate()
			ui_layer.add_child(card_sel)

		var panel:TurnEventPanel = TURN_EVENT_PANEL.instantiate()
		ui_layer.add_child(panel)
		panel.setup(event, context, player_handler.turn_event_manager)


## Conectado tanto a turn_event_resolved como a shop_event_resolved
## porque ambos cierran un menú de evento. Idempotente: si ya estaba
## sin pausar (p.ej. tests headless donde nunca se pausó) no rompe nada.
func _on_event_resolved() -> void:
	get_tree().paused = false


func _on_recruit_card_confirm_started(card: RecruitCard, stats: Stats) -> void:
	var recruit_panel := RecruitPanel.new()
	card.menu = recruit_panel
	recruit_panel.stats = stats
	recruit_panel.available_troops = card.available_troops
	get_tree().get_first_node_in_group("ui_layer").add_child(recruit_panel)


func _on_open_front_card_confirm_started(card: OpenFrontCard, _target_tile: Tile, own_tiles: Array[Tile], _stats: Stats) -> void:
	# OpenFrontCard es un Resource y no puede acceder al árbol de escenas por sí
	# mismo. Inyectamos battle_front_manager desde el PlayerHandler para que
	# apply_effects() pueda llamar a open_front() cuando la carta se juegue.
	# Sin esta inyección apply_effects() retorna en el null-check y nunca se
	# crea el frente ni su visual.
	var player_handler: PlayerHandler = get_tree().get_first_node_in_group("player_handler")
	if player_handler != null:
		card.battle_front_manager = player_handler.battle_front_manager

	var panel := OpenFrontPanel.new()
	card.menu = panel
	panel.setup(card, own_tiles)
	get_tree().get_first_node_in_group("ui_layer").add_child(panel)


func _on_battle_front_selected(front: BattleFront) -> void:
	var ui_layer := get_tree().get_first_node_in_group("ui_layer")
	var player_handler: PlayerHandler = get_tree().get_first_node_in_group("player_handler")
	if player_handler == null:
		return

	var existing := ui_layer.get_node_or_null("BattleFrontPanel")
	if existing != null:
		existing.queue_free()

	var panel: BattleFrontPanel = BATTLE_FRONT_PANEL.instantiate()
	panel.setup(front, player_handler.stats.empire)
	panel.assign_troop_requested.connect(_on_assign_troop_requested.bind(player_handler))
	ui_layer.add_child(panel)


func _on_assign_troop_requested(front: BattleFront, player_handler: PlayerHandler) -> void:
	var ui_layer := get_tree().get_first_node_in_group("ui_layer")

	var assign_panel := AssignTroopsPanel.new()
	assign_panel.setup(front, player_handler.stats)
	assign_panel.troop_assigned.connect(
		func(troop: Troop):
			var side: BattleFront.Side
			if front.attacker_empire == player_handler.stats.empire:
				side = BattleFront.Side.ATTACKER
			else:
				side = BattleFront.Side.DEFENDER
			player_handler.battle_front_manager.assign_troop_to_front(front, troop, side)
	)
	ui_layer.add_child(assign_panel)
