extends GutTest

## Tests de ConquestResolver: qué edificios destruye la conquista de una casilla
## (§2.2). Antes esta regla estaba sin definir —un TODO con un bucle vacío y, como
## placeholder, "destruir el último del array"—, así que el resultado dependía del
## ORDEN DE CONSTRUCCIÓN. Ahora se destruye el edificio MÁS CARO.
##
## La regla la comparten el juego (BattleFrontManager) y la simulación del MCTS
## (AIRealSimulator), de modo que la IA prevé exactamente lo que va a perder el
## defensor. Aquí se fija el criterio; la paridad entre mundos la da el hecho de que
## ambos llamen a esta misma función.


func _building(name: String, cost: int) -> Building:
	var b := Building.new()
	b.name = name
	b.construction_cost = cost
	return b


func _names(buildings: Array[Building]) -> Array:
	var out := []
	for b in buildings:
		out.append(b.name)
	return out


func test_empty_tile_destroys_nothing() -> void:
	var none: Array[Building] = []
	assert_eq(ConquestResolver.buildings_to_destroy(none).size(), 0,
		"Una casilla sin edificios no pierde nada al ser conquistada")


func test_single_building_is_destroyed() -> void:
	var only: Array[Building] = [_building("Granero", 40)]
	assert_eq(_names(ConquestResolver.buildings_to_destroy(only)), ["Granero"],
		"Con un solo edificio, ese es el que cae")


func test_destroys_the_most_expensive_building() -> void:
	var buildings: Array[Building] = [
		_building("Granero", 40),
		_building("Catedral", 300),
		_building("Molino", 60),
	]
	assert_eq(_names(ConquestResolver.buildings_to_destroy(buildings)), ["Catedral"],
		"Se destruye el edificio de mayor coste de construcción")


func test_result_does_not_depend_on_build_order() -> void:
	# La regla vieja destruía el ÚLTIMO del array: con estos dos ordenamientos daba
	# resultados distintos. Ahora ambos pierden la Catedral.
	var forward: Array[Building] = [_building("Catedral", 300), _building("Granero", 40)]
	var backward: Array[Building] = [_building("Granero", 40), _building("Catedral", 300)]
	assert_eq(_names(ConquestResolver.buildings_to_destroy(forward)), ["Catedral"])
	assert_eq(_names(ConquestResolver.buildings_to_destroy(backward)), ["Catedral"],
		"El orden de construcción no debe cambiar qué se destruye")


func test_ties_resolve_to_the_first_building() -> void:
	# Ante empate de coste gana el primero del array: el desempate debe ser
	# determinista para que juego y simulación coincidan.
	var tied: Array[Building] = [_building("Primero", 100), _building("Segundo", 100)]
	assert_eq(_names(ConquestResolver.buildings_to_destroy(tied)), ["Primero"],
		"El empate se resuelve de forma determinista por el primero del array")


func test_null_entries_are_ignored() -> void:
	var with_nulls: Array[Building] = [null, _building("Puerto", 120), null]
	assert_eq(_names(ConquestResolver.buildings_to_destroy(with_nulls)), ["Puerto"],
		"Las entradas nulas no deben romper la selección")
