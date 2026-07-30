extends GutTest

## Tests para EmpireCreator.create_empires.
##
## Bug original: con configuraciones donde el filtro
## `ring_distance > settings.radius` deja `ia_tiles` vacia, el codigo
## hacia `pick_random()` sobre un array vacio (devuelve null) y emitia
## `change_tile_controller` con `tile == null`, lo que crashea en
## tiles_tracker.gd al hacer `tile.controller`.
##
## Reproducible con radius bajos (5-6): el anillo buffer es estrecho y
## puede que ninguna otra tile buffer este a > radius del player_initial.
##
## Fix v1 (parcial): fallback a la tile mas lejana entre las candidatas
## distintas de la del jugador, y push_error si no hay siquiera 1
## candidata.
##
## Fix v2 (Opcion B): bucle de hasta MAX_PLACEMENT_ATTEMPTS intentos con
## un player distinto cada vez antes de caer al fallback, y atomicidad
## fuerte — si no se puede colocar a los dos imperios no se coloca a
## ninguno (antes, en el caso "1 sola candidata" el jugador quedaba
## colocado y la IA no, dejando el estado a medias).


# ============================================================
#  Helpers
# ============================================================

func _make_tile(grid_x:int, grid_y:int, p_buffer:bool = true,
		p_biome:String = "Grassland", p_food:int = 1) -> Tile:
	var t := Tile.new()
	t.pos_data = PositionData.new()
	t.pos_data.grid_position = Vector2i(grid_x, grid_y)
	t.pos_data.buffer = p_buffer
	t.biome = p_biome
	t.food_production = p_food
	autofree(t)
	return t


func _make_empire(p_name:String) -> Empire:
	var e := Empire.new()
	e.name = p_name
	e.color = Color.WHITE
	e.controlled_tiles = []
	return e


func _make_settings(p_radius:int, p_empires:Array[Empire],
		p_player:Empire) -> GenerationSettings:
	var s := GenerationSettings.new()
	s.radius = p_radius
	s.empires = p_empires
	s.player_empire = p_player
	return s


## Listener generico para capturar emisiones de Events.change_tile_controller.
class _ControllerListener:
	var calls:Array = []

	func on_signal(tile, empire) -> void:
		calls.append({"tile": tile, "empire": empire})


func _spawn_listener() -> _ControllerListener:
	var l := _ControllerListener.new()
	Events.change_tile_controller.connect(l.on_signal)
	return l


func _drop_listener(l:_ControllerListener) -> void:
	if Events.change_tile_controller.is_connected(l.on_signal):
		Events.change_tile_controller.disconnect(l.on_signal)


## Limpia WorldMap entre tests porque es autoload y persiste.
func before_each() -> void:
	WorldMap.map = []
	WorldMap.map_as_dict = {}


func after_each() -> void:
	WorldMap.map = []
	WorldMap.map_as_dict = {}


# ============================================================
#  Caso normal: hay tiles lejanas, se elige una de ellas
# ============================================================

func test_normal_path_picks_one_distant_tile_for_ia() -> void:
	# Mapa con 5 tiles buffer en una linea. Player en x=0, tiles a x=10
	# estan a distancia 10 > radius=3, candidatas a IA.
	var tiles:Array[Tile] = [
		_make_tile(0, 0),
		_make_tile(10, 0),
		_make_tile(11, 0),
		_make_tile(12, 0),
		_make_tile(-15, 0),  # tambien lejana, opuesta
	]
	WorldMap.set_map(tiles)

	var p := _make_empire("Player")
	var ia := _make_empire("IA")
	var settings := _make_settings(3, [ia], p)

	var creator := EmpireCreator.new()
	creator.init_creator(settings)

	var listener := _spawn_listener()
	creator.create_empires()
	_drop_listener(listener)

	# Esperamos 2 emisiones: player + ia. Ninguna con tile null.
	assert_eq(listener.calls.size(), 2,
		"create_empires emite 2 cambios de controller (player + ia)")
	for c in listener.calls:
		assert_not_null(c["tile"], "tile en change_tile_controller no debe ser null")


# ============================================================
#  Fallback: ninguna tile cumple > radius → coge la mas lejana
# ============================================================

func test_fallback_when_no_tile_meets_distance_threshold() -> void:
	# 4 tiles buffer todas a distancias <= 2 entre si, radius = 10.
	# Ninguna pareja cumple ring_distance > 10. Sin el fix, ia_tiles
	# quedaba vacio y se emitia tile=null.
	var tiles:Array[Tile] = [
		_make_tile(0, 0),
		_make_tile(1, 0),
		_make_tile(2, 0),
		_make_tile(0, 2),
	]
	WorldMap.set_map(tiles)

	var p := _make_empire("Player")
	var ia := _make_empire("IA")
	var settings := _make_settings(10, [ia], p)

	var creator := EmpireCreator.new()
	creator.init_creator(settings)

	var listener := _spawn_listener()
	creator.create_empires()
	_drop_listener(listener)

	assert_eq(listener.calls.size(), 2,
		"con fallback, sigue emitiendo 2 cambios")
	for c in listener.calls:
		assert_not_null(c["tile"],
			"el fallback debe garantizar tile != null en toda emision")
	# Y las dos tiles deben ser distintas.
	assert_ne(listener.calls[0]["tile"], listener.calls[1]["tile"],
		"jugador e ia deben caer en tiles distintas")
	# El fallback emite un push_warning informativo. Lo "consumimos" con
	# assert_engine_error para que GUT no marque el test como Failed por
	# "Unexpected Errors".
	assert_engine_error("fallback")


# ============================================================
#  Mapa degenerado: 0 tiles candidatas → no emite, log error
# ============================================================

func test_empty_possible_tiles_does_not_emit_and_errors() -> void:
	# Mapa completamente vacio o solo agua → ninguna candidata terrestre.
	# Con los fallbacks, esto solo ocurre si TODAS las tiles son Ocean/Water.
	var tiles:Array[Tile] = [
		_make_tile(0, 0, true, "Ocean", 0),
		_make_tile(1, 0, true, "Water", 0),
		_make_tile(2, 0, true, "Ocean", 1),
	]
	WorldMap.set_map(tiles)

	var p := _make_empire("Player")
	var ia := _make_empire("IA")
	var settings := _make_settings(5, [ia], p)

	var creator := EmpireCreator.new()
	creator.init_creator(settings)

	var listener := _spawn_listener()
	creator.create_empires()
	_drop_listener(listener)

	assert_eq(listener.calls.size(), 0,
		"sin candidatas terrestres no se debe emitir ningun change_tile_controller")
	# Consumir el push_error esperado para que GUT no marque "Unexpected".
	assert_push_error("possible_tiles vacio")


# ============================================================
#  Mapa con 1 sola candidata: NO se coloca ningun imperio
# ============================================================

func test_single_candidate_no_empires_are_placed() -> void:
	# Con 1 sola tile candidata no hay forma de colocar dos imperios
	# distintos. El comportamiento correcto es atomico: o se colocan los
	# dos o no se coloca ninguno. Antes este caso dejaba al jugador
	# colocado y a la IA sin tiles, situacion irrecuperable en runtime.
	var tiles:Array[Tile] = [_make_tile(0, 0)]
	WorldMap.set_map(tiles)

	var p := _make_empire("Player")
	var ia := _make_empire("IA")
	var settings := _make_settings(5, [ia], p)

	var creator := EmpireCreator.new()
	creator.init_creator(settings)

	var listener := _spawn_listener()
	creator.create_empires()
	_drop_listener(listener)

	assert_eq(listener.calls.size(), 0,
		"con 1 sola candidata, no se emite ningun cambio de controller")
	assert_eq(p.controlled_tiles.size(), 0,
		"el jugador NO debe quedar colocado si la IA no tiene tile disponible")
	assert_eq(ia.controlled_tiles.size(), 0,
		"la IA queda sin colocar (mapa demasiado pequeño)")
	# Consumir el push_error esperado.
	assert_push_error("No se pudo elegir un par")


# ============================================================
#  Reset defensivo: empires SI se resetean si la generacion aborta
# ============================================================

func test_aborted_placement_resets_empires_to_empty() -> void:
	# Contrato actualizado: `create_empires` hace un reset defensivo de
	# ambos imperios al INICIO, antes de validar el mapa. Si la
	# colocacion aborta despues, los imperios quedan vacios, no con
	# basura del run anterior.
	#
	# La razon: los recursos Empire son singletons cacheados por Godot.
	# En harnesses multi-run, una Empire reutilizada conserva refs a
	# tiles que ya hicieron `queue_free` entre runs. Sin este reset, el
	# siguiente snapshot crashearia al intentar leer `tile.location` de
	# una instancia freed. Si no quieres perder estado por agarrar
	# resources cacheadas, usa instancias propias (Empire.new()) en lugar
	# de las del archivo .tres.
	WorldMap.set_map([])  # Sin tiles: imposible colocar nada.

	var preexisting_tile := _make_tile(99, 99)
	var p := _make_empire("Player")
	var ia := _make_empire("IA")
	p.controlled_tiles = [preexisting_tile]
	ia.controlled_tiles = [preexisting_tile]
	var settings := _make_settings(5, [ia], p)

	var creator := EmpireCreator.new()
	creator.init_creator(settings)
	creator.create_empires()

	assert_eq(p.controlled_tiles.size(), 0,
		"el jugador se resetea aunque la colocacion aborte (fresh-start contract)")
	assert_eq(ia.controlled_tiles.size(), 0,
		"la IA tambien se resetea (cubre IA empires reusadas en harnesses multi-run)")
	assert_push_error("possible_tiles vacio")


# ============================================================
#  Retry: si un player aleatorio no funciona, prueba con otros
# ============================================================

func test_retry_loop_finds_strict_pair_even_with_close_neighbors() -> void:
	# Composicion: dos clusters separados a distancia > radius. Cualquiera
	# de los player que pruebe el shuffle deberia encontrar el otro
	# cluster en far_enough. Confirmamos que el resultado es siempre un
	# par estricto (no fallback) y por tanto no se emite push_warning.
	var tiles:Array[Tile] = [
		_make_tile(0, 0),
		_make_tile(0, 1),
		_make_tile(1, 0),
		_make_tile(20, 0),
		_make_tile(20, 1),
		_make_tile(21, 0),
	]
	WorldMap.set_map(tiles)

	var p := _make_empire("Player")
	var ia := _make_empire("IA")
	var settings := _make_settings(8, [ia], p)

	var creator := EmpireCreator.new()
	creator.init_creator(settings)

	var listener := _spawn_listener()
	creator.create_empires()
	_drop_listener(listener)

	assert_eq(listener.calls.size(), 2,
		"con dos clusters separados, debe colocar a ambos imperios")
	# Las dos tiles emitidas deben pertenecer a clusters distintos.
	var t0:Tile = listener.calls[0]["tile"]
	var t1:Tile = listener.calls[1]["tile"]
	var d:int = EmpireCreator._ring_distance(t0, t1)
	assert_gt(d, settings.radius,
		"la retry estricta debe garantizar ring_distance > radius (=%d, obtenido %d)" % [
			settings.radius, d
		])


# ============================================================
#  Cascada de criterios para elegir candidatas (§2.8)
# ============================================================
#
# `_collect_candidate_tiles` prueba 4 criterios en orden y se queda con el PRIMERO
# que deje al menos 2 candidatas (hacen falta dos imperios). Es la red de seguridad
# que permite empezar partida en un mapa degenerado, y no tenia cobertura directa.

func _creator_for(tiles:Array[Tile]) -> EmpireCreator:
	WorldMap.set_map(tiles)
	var creator := EmpireCreator.new()
	creator.init_creator(_make_settings(4, [_make_empire("IA")], _make_empire("Player")))
	return creator


func test_candidates_prefer_buffer_tiles_with_food() -> void:
	# Criterio 1: buffer + no oceanica + comida > 0. Las que no cumplen quedan fuera.
	var good_a := _make_tile(0, 0, true, "Grassland", 2)
	var good_b := _make_tile(1, 0, true, "Forest", 1)
	var no_food := _make_tile(2, 0, true, "Desert", 0)
	var no_buffer := _make_tile(3, 0, false, "Grassland", 5)
	var picked := _creator_for([good_a, good_b, no_food, no_buffer] as Array[Tile]) \
		._collect_candidate_tiles()
	assert_eq(picked, [good_a, good_b] as Array[Tile],
		"con suficientes tiles buffer con comida, no se relaja el criterio")


func test_candidates_relax_food_when_not_enough() -> void:
	# Criterio 2: si no hay 2 con comida, se admiten buffer sin comida.
	var with_food := _make_tile(0, 0, true, "Grassland", 3)
	var no_food := _make_tile(1, 0, true, "Desert", 0)
	var picked := _creator_for([with_food, no_food] as Array[Tile])._collect_candidate_tiles()
	assert_eq(picked.size(), 2, "se relaja la exigencia de comida antes que la de buffer")
	assert_true(no_food in picked, "la tile sin comida entra al relajar el criterio")


func test_candidates_drop_buffer_requirement_when_needed() -> void:
	# Criterio 3: sin suficientes tiles de buffer, vale cualquier no oceanica.
	var buffered := _make_tile(0, 0, true, "Grassland", 1)
	var inland := _make_tile(1, 0, false, "Forest", 1)
	var picked := _creator_for([buffered, inland] as Array[Tile])._collect_candidate_tiles()
	assert_eq(picked.size(), 2, "se abandona el requisito de buffer como tercer recurso")


func test_candidates_exclude_ocean_always() -> void:
	var land_a := _make_tile(0, 0, false, "Grassland", 1)
	var land_b := _make_tile(1, 0, false, "Forest", 1)
	var sea := _make_tile(2, 0, false, "Ocean", 0)
	var picked := _creator_for([land_a, land_b, sea] as Array[Tile])._collect_candidate_tiles()
	assert_false(sea in picked, "una tile oceanica nunca es candidata a inicio")


func test_candidates_empty_when_map_is_all_ocean() -> void:
	var sea_a := _make_tile(0, 0, false, "Ocean", 0)
	var sea_b := _make_tile(1, 0, false, "Ocean", 0)
	var picked := _creator_for([sea_a, sea_b] as Array[Tile])._collect_candidate_tiles()
	assert_eq(picked.size(), 0, "sin tierra no hay candidatas y create_empires aborta")


func test_collect_does_not_accumulate_between_calls() -> void:
	# `possible_tiles` es estado de instancia: antes se rellenaba acumulando, asi que
	# reusar el creator arrastraba las candidatas del run anterior.
	var a := _make_tile(0, 0, true, "Grassland", 1)
	var b := _make_tile(1, 0, true, "Forest", 1)
	var creator := _creator_for([a, b] as Array[Tile])
	var first := creator._collect_candidate_tiles()
	var second := creator._collect_candidate_tiles()
	assert_eq(second.size(), first.size(),
		"dos recolecciones seguidas sobre el mismo mapa dan lo mismo, no el doble")
