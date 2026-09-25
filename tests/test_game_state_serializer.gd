extends GutTest

## Tests de GameStateSerializer.apply_snapshot: la RESTAURACIÓN completa de una
## partida guardada (refactor §2.6.a).
##
## Cubre el hueco que el plan marcaba como el más crítico: los otros tests de
## serialización prueban cada serializador POR SEPARADO (to_dict/from_dict), pero
## ninguno tocaba `apply_snapshot`, que es quien orquesta las 8 fases de la carga y
## el sitio donde un fallo se traduce en "cargar partida deja el mundo a medias".
##
## LIMITACIÓN CONOCIDA: no es un round-trip completo `build_snapshot → apply →
## build_snapshot`. `build_snapshot()` exige que `tree.current_scene` se llame "Map",
## lo que obligaría a instanciar la escena real del juego dentro del runner. Aquí se
## parte de un snapshot CONSTRUIDO A MANO con el mismo formato que produce
## `TileSerializer.to_dict` + `_serialize_empires`, y se verifica que el mundo queda
## reconstruido. La otra dirección (mundo → dict) ya la cubren los tests por
## serializador.

const GRASSLAND := "res://resources/tiles/grassland.tres"
const EMPIRE_A := "res://resources/empires/medici.tres"
const EMPIRE_B := "res://resources/empires/mongol.tres"
## Tile.set_parameters() exige un natural_resource con imagen (crea el Sprite3D del
## recurso), asi que toda casilla del snapshot debe traer uno.
const WHEAT := "res://resources/natural_resources/wheat.tres"
const UNCOLONIZED := "res://resources/location_type/uncolonized.tres"


## Raíz mínima equivalente a la escena Map: solo los contenedores que
## `apply_snapshot` busca por MapScenePaths (Scene/TileParent y Node).
## El UI_layer se omite a propósito: su lookup está guardado con
## `get_node_or_null`, así que la carga debe funcionar sin interfaz.
func _make_map_node() -> Node3D:
	var map_node := add_child_autofree(Node3D.new()) as Node3D
	map_node.name = "Map"

	var scene := Node3D.new()
	scene.name = MapScenePaths.SCENE
	map_node.add_child(scene)

	var tile_parent := Node3D.new()
	tile_parent.name = "TileParent"
	scene.add_child(tile_parent)

	var node_container := Node.new()
	node_container.name = MapScenePaths.NODE
	map_node.add_child(node_container)
	return map_node


func _tile_entry(grid_x: int, grid_y: int, controller_path: String = "") -> Dictionary:
	return {
		"pos": [grid_x, grid_y],
		"world_position": [float(grid_x), 0.0, float(grid_y)],
		"mesh_data": GRASSLAND,
		"natural_resource": WHEAT,
		"biome": "Grassland",
		"location": UNCOLONIZED,
		"controller_path": controller_path,
		"buffer": false,
		"water": false,
		"mountain": false,
		"buildings": [],
		"province_name": "TestProvincia",
	}


func _empire_entry(empire_path: String, is_player: bool, gold: int) -> Dictionary:
	return {
		"empire_path": empire_path,
		"is_player": is_player,
		"stats": {"total_gold": gold, "gold_per_turn": 7, "food": 3, "turn_number": 4},
		"modifiers": [],
		"hand_cards": [],
		"cards_played_this_turn": 0,
	}


func _snapshot(tiles: Array, empires: Array, round_number: int = 5) -> Dictionary:
	return {
		"version": SaveConstants.SAVE_FORMAT_VERSION,
		"tiles": tiles,
		"empires": empires,
		"turn_manager": {"round_number": round_number, "current_index": 1},
		"battle_fronts": [],
	}


func before_each() -> void:
	TestWorld.reset()


func after_each() -> void:
	TestWorld.reset()


# ------------------------------------------------------------------
#  Guardas de entrada
# ------------------------------------------------------------------

func test_empty_snapshot_is_rejected() -> void:
	assert_false(GameStateSerializer.apply_snapshot({}, _make_map_node()),
		"Un snapshot vacío no debe aplicarse")



func test_snapshot_without_player_reports_failure() -> void:
	# Sin imperio del jugador no hay partida jugable: debe devolver false aunque
	# el resto del mundo se haya reconstruido.
	var snap := _snapshot([_tile_entry(0, 0)], [_empire_entry(EMPIRE_B, false, 50)])
	assert_false(GameStateSerializer.apply_snapshot(snap, _make_map_node()),
		"Un snapshot sin jugador no se considera una carga válida")


# ------------------------------------------------------------------
#  Reconstrucción del mundo
# ------------------------------------------------------------------

func test_apply_snapshot_rebuilds_tiles_into_world_map() -> void:
	var snap := _snapshot(
		[_tile_entry(0, 0), _tile_entry(1, 0), _tile_entry(0, 1)],
		[_empire_entry(EMPIRE_A, true, 100)])
	assert_true(GameStateSerializer.apply_snapshot(snap, _make_map_node()),
		"La carga con jugador debe reportar éxito")
	assert_eq(WorldMap.map.size(), 3, "Las 3 casillas del snapshot deben estar en WorldMap")
	assert_not_null(WorldMap.map_as_dict.get(Vector2(1, 0)),
		"Las casillas deben quedar indexadas por su posición de rejilla")


func test_apply_snapshot_restores_tile_controllers() -> void:
	var snap := _snapshot(
		[_tile_entry(0, 0, EMPIRE_A), _tile_entry(1, 0)],
		[_empire_entry(EMPIRE_A, true, 100)])
	GameStateSerializer.apply_snapshot(snap, _make_map_node())

	var owned: Tile = WorldMap.map_as_dict.get(Vector2(0, 0))
	var free_tile: Tile = WorldMap.map_as_dict.get(Vector2(1, 0))
	assert_not_null(owned.controller, "La casilla guardada con dueño debe recuperarlo")
	assert_null(free_tile.controller, "La casilla sin dueño debe seguir libre")


func test_apply_snapshot_restores_stats_and_turn_manager() -> void:
	var map_node := _make_map_node()
	var snap := _snapshot(
		[_tile_entry(0, 0, EMPIRE_A)],
		[_empire_entry(EMPIRE_A, true, 321), _empire_entry(EMPIRE_B, false, 99)],
		12)
	GameStateSerializer.apply_snapshot(snap, map_node)

	var tm := map_node.get_node_or_null(MapScenePaths.TURN_MANAGER) as TurnManager
	assert_not_null(tm, "apply_snapshot debe crear el TurnManager")
	assert_eq(tm.round_number, 12, "La ronda guardada debe restaurarse")
	assert_eq(tm.current_index, 1, "El turno en curso debe restaurarse")

	# Un controller por imperio del snapshot (jugador + IA).
	assert_eq(tm.controllers.size(), 2,
		"Cada imperio del snapshot debe tener su controller registrado")


func test_apply_snapshot_restores_player_gold() -> void:
	var map_node := _make_map_node()
	var snap := _snapshot([_tile_entry(0, 0, EMPIRE_A)],
		[_empire_entry(EMPIRE_A, true, 321)])
	GameStateSerializer.apply_snapshot(snap, map_node)

	var ph := map_node.get_node_or_null(MapScenePaths.PLAYER_HANDLER) as PlayerHandler
	assert_not_null(ph, "Debe crearse el PlayerHandler del jugador")
	assert_eq(ph.stats.total_gold, 321, "El oro guardado debe restaurarse en las stats")


func test_apply_snapshot_starts_from_a_clean_front_registry() -> void:
	# La carga limpia los frentes residuales de la partida anterior: si no, un
	# frente viejo seguiría contando como activo en el mundo recién cargado.
	var stale := BattleFront.new(null, null, null, null)
	assert_eq(BattleFront.get_active_instances().size(), 1, "Precondición: hay un frente residual")
	var snap := _snapshot([_tile_entry(0, 0)], [_empire_entry(EMPIRE_A, true, 10)])
	GameStateSerializer.apply_snapshot(snap, _make_map_node())
	assert_eq(BattleFront.get_active_instances().size(), 0,
		"apply_snapshot debe vaciar el registro de frentes antes de restaurar")
	assert_not_null(stale)   # mantener la referencia viva hasta el final del test


# ------------------------------------------------------------------
#  Presentación tras cargar
# ------------------------------------------------------------------

class OpenedListener extends RefCounted:
	var fronts: Array = []
	func on_opened(front: BattleFront) -> void:
		fronts.append(front)


## Los frentes restaurados se anuncian como al abrirlos: de ese aviso cuelga su
## visual en el mapa, y sin él seguían activos pero no se veían ni se podían abrir.
func test_los_frentes_restaurados_se_anuncian_para_dibujarse() -> void:
	var snap := _snapshot(
		[_tile_entry(0, 0, EMPIRE_A), _tile_entry(1, 0, EMPIRE_B)],
		[_empire_entry(EMPIRE_A, true, 290), _empire_entry(EMPIRE_B, false, 50)])
	snap["battle_fronts"] = [{
		"attacker_pos": [0, 0], "defender_pos": [1, 0],
		"attacker_empire": EMPIRE_A, "defender_empire": EMPIRE_B,
		"marker": 2.5, "turns_elapsed": 2, "min_duration": 3, "threshold": 10.0,
		"campaign_step": 2, "attacker_troops": [], "defender_troops": [],
		"attacker_bonuses": [], "defender_bonuses": [],
	}]
	var listener := OpenedListener.new()
	Events.battle_front_opened.connect(listener.on_opened)
	GameStateSerializer.apply_snapshot(snap, _make_map_node())
	Events.battle_front_opened.disconnect(listener.on_opened)

	var restored := BattleFront.get_active_instances()
	assert_eq(restored.size(), 1, "el frente vuelve al registro")
	assert_eq(listener.fronts.size(), 1, "y se anuncia una vez para que se dibuje")
	if restored.size() == 1 and listener.fronts.size() == 1:
		assert_same(listener.fronts[0], restored[0])
		assert_eq(restored[0].campaign_step, 2, "con su casilla de la ofensiva")


## Al cargar, el turno se reanuda sin producción y no llega ningún cambio de stats
## hasta el turno siguiente: el panel tiene que mostrar ya las restauradas.
func test_el_panel_muestra_las_stats_restauradas_sin_esperar_al_turno() -> void:
	var ui: Control = load("res://scenes/UI/general_ui.tscn").instantiate()
	add_child_autofree(ui)
	var stats := Stats.new()
	stats.total_gold = 290
	stats.gold_per_turn = 205
	stats.food = 16
	ui.stats = stats
	assert_eq(ui.stats_ui.gold.text, "290", "oro guardado, no el de la plantilla")
	# Suelta, fuera de la escena del mapa, CardPileViews no encuentra Hand ni UI: son
	# errores del montaje de la prueba, no de lo que se mide.
	for e in get_errors():
		e.handled = true
