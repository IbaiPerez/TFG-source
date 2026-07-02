extends RefCounted
class_name GameStateSerializer

## Construye el snapshot completo de la partida y lo aplica al cargar.
##
## Punto único donde se decide qué entra en un save y en qué orden se
## restaura. Delega los detalles por bloque en serializadores específicos
## (TileSerializer, StatsSerializer, ModifierSerializer, ...).


## --- Construcción del snapshot ------------------------------------------

## Recorre el árbol de la escena actual y produce un Dictionary serializable
## a JSON con todo lo que necesitamos para reconstruir la partida.
##
## Devuelve {} si no hay partida activa (p.ej. estamos en el menú principal).
static func build_snapshot() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return {}

	var map_node := tree.current_scene
	# El nodo raíz del mapa se llama "Map" (ver scenes/world_generation/map.tscn).
	if map_node == null or map_node.name != "Map":
		return {}

	var player_handler := tree.get_first_node_in_group("player_handler") as PlayerHandler
	if player_handler == null:
		return {}

	var turn_manager_node := map_node.get_node_or_null(MapScenePaths.TURN_MANAGER) as TurnManager
	if turn_manager_node == null:
		return {}

	var snapshot := {
		"version": SaveConstants.SAVE_FORMAT_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"generation_settings": _resource_path_or_empty(map_node.get("generation_settings")),
		"map_seed": _read_map_seed(map_node),
		"tiles": _serialize_tiles(),
		"empires": _serialize_empires(turn_manager_node),
		"turn_manager": {
			"round_number": turn_manager_node.round_number,
			"current_index": turn_manager_node.current_index,
			"controller_order": _serialize_controller_order(turn_manager_node),
		},
		"battle_fronts": _serialize_battle_fronts(turn_manager_node),
	}
	return snapshot


## --- Aplicación del snapshot a la escena --------------------------------

## Aplica un snapshot a la escena Map. Se invoca desde Map._ready() cuando
## detecta `pending_snapshot` no vacío.
##
## Hace TODO el trabajo: reconstruye tiles, empires, controllers, stats,
## modifiers, battle fronts y configura el TurnManager.
##
## Devuelve true si todo se aplicó sin abortar.
static func apply_snapshot(snapshot:Dictionary, map_node:Node3D) -> bool:
	if snapshot.is_empty():
		return false

	var tile_parent := map_node.get_node_or_null(MapScenePaths.TILE_PARENT) as Node3D
	if tile_parent == null:
		push_warning("[GameStateSerializer] No se encontró Scene/TileParent")
		return false

	# 1) Reconstruir mapa.
	var tiles_data:Array = snapshot.get("tiles", [])
	var settings_path:String = snapshot.get("generation_settings", "")
	var settings:GenerationSettings = null
	if settings_path != "" and ResourceLoader.exists(settings_path):
		settings = load(settings_path) as GenerationSettings

	# Limpia cualquier registro residual de frentes
	BattleFront.clear_active_instances()

	var tiles := TileSerializer.rebuild_tiles(tiles_data, tile_parent, settings)
	WorldMap.set_map(tiles)
	for t in WorldMap.map:
		t.neighbors = WorldMap.get_tile_neighbors(t)

	# 2) Crear instancias frescas de Empire (por nombre).
	var empires_data:Array = snapshot.get("empires", [])
	var empires_by_name:Dictionary = _instantiate_empires(empires_data)

	# 3) Asignar controllers (Empire) a tiles.
	for entry in tiles_data:
		var pos := Vector2(entry["pos"][0], entry["pos"][1])
		var tile:Tile = WorldMap.map_as_dict.get(pos)
		if tile == null:
			continue
		var controller_path:String = entry.get("controller_path", "")
		if controller_path != "" and empires_by_name.has(controller_path):
			var emp:Empire = empires_by_name[controller_path]
			emp.add_tile(tile)

	# 4) Reaplicar buildings (sin descontar coste; efectos se aplican luego).
	for entry in tiles_data:
		var pos := Vector2(entry["pos"][0], entry["pos"][1])
		var tile:Tile = WorldMap.map_as_dict.get(pos)
		if tile == null:
			continue
		TileSerializer.apply_buildings_pending(tile, entry.get("buildings", []))

	# 5) Crear PlayerHandler y AIControllers, asignándoles sus stats restaurados.
	var turn_manager:TurnManager = _setup_turn_manager(map_node)
	var player_stats:Stats = null

	for empire_entry in empires_data:
		var emp_path:String = empire_entry.get("empire_path", "")
		var empire:Empire = empires_by_name.get(emp_path)
		if empire == null:
			continue
		var stats_data:Dictionary = empire_entry.get("stats", {})
		var stats:Stats = StatsSerializer.from_dict(stats_data, empire)
		if stats == null:
			continue

		# El reglamento de eventos vive en res://resources/turn_events/.
		# Mismo punto de carga que usa map.gd en el flujo normal.
		stats.available_events = TurnEventLoader.load_all()

		var is_player:bool = empire_entry.get("is_player", false)
		var controller:EmpireController = _spawn_controller(map_node, is_player)
		controller.restore_from_save(stats)
		turn_manager.register_controller(controller)

		# Reaplicar modifiers tras restore_from_save (orden importante:
		# las stats ya están enlazadas).
		ModifierSerializer.apply_to_manager(controller.modifier_manager,
				empire_entry.get("modifiers", []), stats)

		if is_player:
			player_stats = stats
			# Conectar la mano del jugador a su stats restaurada.
			var ui_layer := map_node.get_node_or_null(MapScenePaths.UI_LAYER)
			if ui_layer:
				ui_layer.set("stats", stats)
			# Restaurar la mano y el contador de cartas jugadas.
			var ph:PlayerHandler = controller as PlayerHandler
			if ph and ph.hand:
				ph.hand.stats = stats
				_restore_player_hand(ph.hand, empire_entry.get("hand_cards", []), stats)
				ph.hand.cards_played_this_turn = int(empire_entry.get("cards_played_this_turn", 0))

	# 5b) Reaplicar efectos de buildings que sí deben reactivarse al cargar
	# (los que conectan señales runtime, p.ej. GoldOnCard). Los efectos que
	# producen modifiers (`should_reapply_on_load() == false`) NO se
	# reaplican: sus modifiers ya vinieron restaurados desde el snapshot.
	for entry in tiles_data:
		var pos2 := Vector2(entry["pos"][0], entry["pos"][1])
		var tile2:Tile = WorldMap.map_as_dict.get(pos2)
		if tile2 == null or tile2.controller == null:
			continue
		var owner_stats:Stats = _stats_for_empire(tile2.controller, turn_manager)
		if owner_stats == null:
			continue
		for b in tile2.buildings:
			for e in b.effects:
				if e.should_reapply_on_load():
					e.apply_effect(tile2, owner_stats)

	# 6) Restaurar battle fronts.
	# Replica el contrato de BattleFrontManager.open_front: solo el manager
	# del bando ATACANTE registra el frente en su `active_fronts` y conecta
	# `front_resolved`/`marker_changed`. El defensor no participa de esa
	# gestión local — únicamente paga mantenimiento (calculado en el flujo
	# de turno con `BattleFront.get_active_instances()` como fuente de
	# verdad global).
	for front_data in snapshot.get("battle_fronts", []):
		var front:BattleFront = BattleFrontSerializer.from_dict(front_data, empires_by_name)
		if front == null:
			continue
		# El BattleFront ya se autoregistra en _active_instances via _init.
		var atk_ctrl:EmpireController = _controller_for_empire(turn_manager, front.attacker_empire)
		if atk_ctrl != null and atk_ctrl.battle_front_manager != null:
			if front not in atk_ctrl.battle_front_manager.active_fronts:
				atk_ctrl.battle_front_manager.active_fronts.append(front)
			front.front_resolved.connect(atk_ctrl.battle_front_manager._on_front_resolved)
			front.marker_changed.connect(atk_ctrl.battle_front_manager._on_marker_changed)

	# 7) Restaurar TurnManager.
	var tm_data:Dictionary = snapshot.get("turn_manager", {})
	turn_manager.round_number = int(tm_data.get("round_number", 1))
	turn_manager.current_index = int(tm_data.get("current_index", 0))

	# 8) UI inicial (igual que en flujo normal post-generación).
	var ui_layer:UILayer = map_node.get_node_or_null(MapScenePaths.UI_LAYER)
	if ui_layer and ui_layer.ui:
		ui_layer.ui.initialize_card_pile_ui()

	return player_stats != null


## --- Helpers privados ---------------------------------------------------

static func _resource_path_or_empty(resource:Variant) -> String:
	if resource is Resource:
		return (resource as Resource).resource_path
	return ""


static func _read_map_seed(map_node:Node) -> int:
	var wg:Node = map_node.get_node_or_null(MapScenePaths.WORLD_GENERATOR)
	if wg == null:
		return 0
	var settings:Variant = wg.get("settings")
	if settings is GenerationSettings:
		return (settings as GenerationSettings).map_seed
	return 0


static func _serialize_tiles() -> Array:
	var out:Array = []
	for tile in WorldMap.map:
		out.append(TileSerializer.to_dict(tile))
	return out


static func _serialize_empires(turn_manager:TurnManager) -> Array:
	var out:Array = []
	for ctrl in turn_manager.controllers:
		var entry := {
			"name": ctrl.stats.empire.name if ctrl.stats and ctrl.stats.empire else "",
			"empire_path": ctrl.stats.empire.resource_path if ctrl.stats and ctrl.stats.empire else "",
			"is_player": ctrl is PlayerHandler,
			"stats": StatsSerializer.to_dict(ctrl.stats),
			"modifiers": ModifierSerializer.serialize_manager(ctrl.modifier_manager),
		}
		# Estado específico del jugador: mano actual y contador del turno.
		# Sin esto, guardar a media partida pierde las cartas robadas y
		# rompe modificadores que dependen de cards_played_this_turn.
		if ctrl is PlayerHandler:
			var ph:PlayerHandler = ctrl
			entry["hand_cards"] = _serialize_hand(ph.hand)
			entry["cards_played_this_turn"] = ph.hand.cards_played_this_turn if ph.hand else 0
		out.append(entry)
	return out


static func _serialize_hand(hand:Hand) -> Array:
	var out:Array = []
	if hand == null:
		return out
	for child in hand.get_children():
		if child is CardUI and child.card != null:
			out.append(SaveResourceRegistry.card_key(child.card))
	return out


static func _serialize_controller_order(turn_manager:TurnManager) -> Array:
	var paths:Array = []
	for ctrl in turn_manager.controllers:
		paths.append(ctrl.stats.empire.resource_path if ctrl.stats and ctrl.stats.empire else "")
	return paths


static func _serialize_battle_fronts(_turn_manager:TurnManager) -> Array:
	# BattleFront.get_active_instances() es la fuente de verdad global.
	var out:Array = []
	for front in BattleFront.get_active_instances():
		var d := BattleFrontSerializer.to_dict(front)
		if not d.is_empty():
			out.append(d)
	return out


static func _instantiate_empires(empires_data:Array) -> Dictionary:
	var by_path:Dictionary = {}
	for entry in empires_data:
		var path:String = entry.get("empire_path", "")
		if path == "" or not ResourceLoader.exists(path):
			continue
		var template:Empire = load(path) as Empire
		if template == null:
			continue
		var fresh:Empire = template.create_instance()
		by_path[path] = fresh
	return by_path


static func _setup_turn_manager(map_node:Node3D) -> TurnManager:
	var turn_manager := TurnManager.new()
	turn_manager.name = MapScenePaths.TURN_MANAGER
	map_node.add_child(turn_manager)

	# Reconectar las señales de fin de turno del jugador.
	if not Events.player_turn_ended.is_connected(turn_manager.on_player_turn_ended):
		Events.player_turn_ended.connect(turn_manager.on_player_turn_ended)
	if not Events.player_hand_discarded.is_connected(turn_manager.on_player_hand_discarded):
		Events.player_hand_discarded.connect(turn_manager.on_player_hand_discarded)
	return turn_manager


static func _spawn_controller(map_node:Node3D, is_player:bool) -> EmpireController:
	if is_player:
		var existing:Node = map_node.get_node_or_null(MapScenePaths.PLAYER_HANDLER)
		if existing is PlayerHandler:
			return existing as PlayerHandler
		var ph := PlayerHandler.new()
		ph.name = MapScenePaths.PLAYER_HANDLER_NAME
		map_node.get_node(MapScenePaths.NODE).add_child(ph)
		return ph
	else:
		var existing: Node = map_node.get_node_or_null(MapScenePaths.AI_CONTROLLER)
		if existing is AIController:
			return existing as AIController
		var ai := AIController.new()
		ai.name = "AIController_%d" % map_node.get_node(MapScenePaths.NODE).get_child_count()
		map_node.get_node(MapScenePaths.NODE).add_child(ai)
		return ai


## Repuebla la mano del jugador con las cartas serializadas. Limpia primero
## cualquier CardUI residual de la escena (al cargar partida fresca o al
## cambiar de save sobre la misma partida).
static func _restore_player_hand(hand:Hand, card_keys:Array, stats:Stats) -> void:
	# Limpia la mano (queue_free es asíncrono, suficiente para una transición
	# de carga porque add_card crea instancias nuevas en este mismo frame).
	for child in hand.get_children():
		if child is CardUI:
			child.queue_free()

	for key in card_keys:
		var template:Card = SaveResourceRegistry.load_card(key)
		if template == null:
			continue
		var card:Card = template.duplicate(true)
		stats.sync_card_buildings(card)
		hand.add_card(card)


## Devuelve las Stats del controller cuyo empire coincide.
static func _stats_for_empire(empire:Empire, turn_manager:TurnManager) -> Stats:
	if empire == null or turn_manager == null:
		return null
	for ctrl in turn_manager.controllers:
		if ctrl.stats and ctrl.stats.empire == empire:
			return ctrl.stats
	return null


## Devuelve el EmpireController cuyo empire coincide (o null).
static func _controller_for_empire(turn_manager:TurnManager, empire:Empire) -> EmpireController:
	if empire == null or turn_manager == null:
		return null
	for ctrl in turn_manager.controllers:
		if ctrl.stats and ctrl.stats.empire == empire:
			return ctrl
	return null
