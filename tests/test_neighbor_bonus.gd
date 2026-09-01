extends GutTest

## Mecánica de bonificación a las casillas VECINAS ([NeighborBonus]).
##
## Hasta ahora un edificio solo producía donde se construía. El molino estrena la otra
## forma: se levanta en una ciudad y la comida la reciben los pueblos de alrededor — el
## mismo coste llega a seis casillas en vez de a una.
##
## Lo que estos tests fijan no es el molino sino la MECÁNICA, porque es la parte
## reutilizable: qué condiciones puede declarar un bonus sobre a qué casillas alcanza, y
## que la producción de una casilla se recalcule cuando cambia el vecindario — construir,
## demoler, conquistar o urbanizar al lado.
##
## Y la paridad de los dos mundos, que aquí es especialmente fácil de romper: el mundo
## vivo recorre `Tile.neighbors` (referencias a nodos) y el snapshot `neighbor_ids`
## (enteros), así que son dos recorridos distintos de la misma regla.


const VILLAGE := Tile.location_type.Village
const TOWN := Tile.location_type.Town


func _bonus(food := 5, gold := 0, pct := 0.0) -> NeighborBonus:
	var b := NeighborBonus.new()
	b.food = food
	b.gold = gold
	b.food_percent = pct
	return b


func _molino(bonus: NeighborBonus) -> Building:
	var b := Building.new()
	b.name = "TestMolino"
	b.gold_produced = -2
	b.food_produced = 0
	var lista: Array[NeighborBonus] = []
	lista.append(bonus)
	b.neighbor_bonuses = lista
	return b


# ---------------------------------------------------------------------------
# Las condiciones, en aislamiento
# ---------------------------------------------------------------------------

func test_sin_condiciones_alcanza_a_cualquier_vecina_propia() -> void:
	var b := _bonus()
	assert_true(b.applies_to(true, VILLAGE, Tile.biome_type.Grassland, null),
		"una lista de condiciones vacía no debe restringir por ese eje")


func test_la_condicion_de_propiedad_excluye_al_rival() -> void:
	var b := _bonus()
	assert_true(b.only_same_owner, "por defecto no se regala producción al rival")
	assert_false(b.applies_to(false, VILLAGE, 0, null))
	b.only_same_owner = false
	assert_true(b.applies_to(false, VILLAGE, 0, null),
		"desactivada, la bonificación cruza fronteras")


func test_la_condicion_de_localizacion_filtra() -> void:
	var b := _bonus()
	b.allowed_locations = [VILLAGE] as Array[Tile.location_type]
	assert_true(b.applies_to(true, VILLAGE, 0, null), "el pueblo la recibe")
	assert_false(b.applies_to(true, TOWN, 0, null), "la ciudad no")


func test_la_condicion_de_bioma_filtra() -> void:
	var b := _bonus()
	b.allowed_biomes = [Tile.biome_type.Grassland] as Array[Tile.biome_type]
	assert_true(b.applies_to(true, VILLAGE, Tile.biome_type.Grassland, null))
	assert_false(b.applies_to(true, VILLAGE, Tile.biome_type.Desert, null))


func test_la_condicion_de_recurso_filtra() -> void:
	var trigo := NaturalResource.new()
	var hierro := NaturalResource.new()
	var b := _bonus()
	b.required_natural_resource = trigo
	assert_true(b.applies_to(true, VILLAGE, 0, trigo))
	assert_false(b.applies_to(true, VILLAGE, 0, hierro))
	assert_false(b.applies_to(true, VILLAGE, 0, null))


func test_las_condiciones_se_combinan_en_Y() -> void:
	# Cada eje puede vetar por su cuenta: basta que uno falle.
	var b := _bonus()
	b.allowed_locations = [VILLAGE] as Array[Tile.location_type]
	b.allowed_biomes = [Tile.biome_type.Grassland] as Array[Tile.biome_type]
	assert_true(b.applies_to(true, VILLAGE, Tile.biome_type.Grassland, null))
	assert_false(b.applies_to(true, TOWN, Tile.biome_type.Grassland, null))
	assert_false(b.applies_to(true, VILLAGE, Tile.biome_type.Desert, null))
	assert_false(b.applies_to(false, VILLAGE, Tile.biome_type.Grassland, null))


# ---------------------------------------------------------------------------
# Mundo vivo
# ---------------------------------------------------------------------------

var _imperio: Empire
var _rival: Empire


func before_each() -> void:
	_imperio = Empire.new()
	_imperio.name = "Propio"
	_rival = Empire.new()
	_rival.name = "Rival"


## Ciudad con `edificios` y un pueblo pegado. Devuelve [ciudad, pueblo] ya enlazados
## en los dos sentidos y recalculados.
func _ciudad_y_pueblo(edificios: Array, duenyo_pueblo: Empire,
		loc_pueblo := VILLAGE) -> Array:
	var ciudad := TestBuilders.tile().with_location(TOWN, 3).with_resource(1, 1) \
		.with_controller(_imperio).with_buildings(edificios).build()
	var pueblo := TestBuilders.tile().with_location(loc_pueblo, 1).with_resource(1, 4) \
		.with_controller(duenyo_pueblo).build()
	add_child_autofree(ciudad)
	add_child_autofree(pueblo)
	ciudad.neighbors = [pueblo]
	pueblo.neighbors = [ciudad]
	ciudad.recalculate_modifiers()
	pueblo.recalculate_modifiers()
	return [ciudad, pueblo]


func test_el_pueblo_vecino_recibe_la_comida_del_molino() -> void:
	var bonus := _bonus(5)
	bonus.allowed_locations = [VILLAGE] as Array[Tile.location_type]
	var par := _ciudad_y_pueblo([_molino(bonus)], _imperio)
	var pueblo := par[1] as Tile
	# El pueblo produce 4 de su recurso; el molino le añade 5.
	assert_eq(pueblo.food_production, 9,
		"el pueblo debe sumar su recurso (4) y la bonificación del molino (5)")


func test_el_molino_no_produce_comida_en_su_propia_casilla() -> void:
	# Es lo que cambia respecto al diseño anterior: la ciudad paga el edificio y no
	# ve nada; toda la salida está en el vecindario.
	var bonus := _bonus(5)
	bonus.allowed_locations = [VILLAGE] as Array[Tile.location_type]
	var par := _ciudad_y_pueblo([_molino(bonus)], _imperio)
	var ciudad := par[0] as Tile
	assert_eq(ciudad.food_production, 1, "la ciudad se queda con su recurso, sin extra")
	assert_eq(ciudad.gold_production, -1, "y paga el mantenimiento del molino")


func test_una_ciudad_vecina_no_recibe_la_bonificacion() -> void:
	# La intención de diseño: que la comida se concentre en los pueblos.
	var bonus := _bonus(5)
	bonus.allowed_locations = [VILLAGE] as Array[Tile.location_type]
	var par := _ciudad_y_pueblo([_molino(bonus)], _imperio, TOWN)
	assert_eq((par[1] as Tile).food_production, 4,
		"una ciudad vecina no cumple la condición de localización")


func test_no_se_alimenta_al_rival() -> void:
	var bonus := _bonus(5)
	bonus.allowed_locations = [VILLAGE] as Array[Tile.location_type]
	var par := _ciudad_y_pueblo([_molino(bonus)], _rival)
	assert_eq((par[1] as Tile).food_production, 4,
		"un pueblo del rival pegado a mi molino no debe recibir nada")


func test_el_porcentaje_se_aplica_al_recurso_de_la_vecina() -> void:
	# Mismo criterio que `Building.food_percent_bonus`: sobre el recurso natural de
	# quien lo recibe, no sobre su producción total.
	var bonus := _bonus(0, 0, 50.0)
	bonus.allowed_locations = [VILLAGE] as Array[Tile.location_type]
	var par := _ciudad_y_pueblo([_molino(bonus)], _imperio)
	assert_eq((par[1] as Tile).food_production, 6,
		"4 de recurso + 50%% de 4 = 6")


# ---------------------------------------------------------------------------
# El vecindario se recalcula cuando cambia
# ---------------------------------------------------------------------------

func test_construir_el_molino_actualiza_al_vecino_sin_tocarlo() -> void:
	# EL riesgo de la mecánica: la producción de una casilla ya no depende solo de
	# ella, así que construir en A tiene que repasar B. Si no, B se queda con la
	# cifra vieja hasta que algo la toque.
	var par := _ciudad_y_pueblo([], _imperio)
	var ciudad := par[0] as Tile
	var pueblo := par[1] as Tile
	assert_eq(pueblo.food_production, 4, "precondición: sin molino")

	var bonus := _bonus(5)
	bonus.allowed_locations = [VILLAGE] as Array[Tile.location_type]
	var stats := TestBuilders.stats().with_gold(500).build()
	ciudad.build(_molino(bonus), stats)

	assert_eq(pueblo.food_production, 9,
		"al construir el molino, el pueblo debe recalcularse solo")


func test_demoler_el_molino_le_quita_la_comida_al_vecino() -> void:
	var bonus := _bonus(5)
	bonus.allowed_locations = [VILLAGE] as Array[Tile.location_type]
	var par := _ciudad_y_pueblo([], _imperio)
	var ciudad := par[0] as Tile
	var pueblo := par[1] as Tile
	var stats := TestBuilders.stats().with_gold(500).build()
	ciudad.build(_molino(bonus), stats)
	assert_eq(pueblo.food_production, 9, "precondición: construido")

	ciudad.demolish(ciudad.buildings[0], stats)
	assert_eq(pueblo.food_production, 4, "demoler debe devolver al vecino a su cifra")


func test_conquistar_el_pueblo_enciende_la_bonificacion() -> void:
	var bonus := _bonus(5)
	bonus.allowed_locations = [VILLAGE] as Array[Tile.location_type]
	var par := _ciudad_y_pueblo([_molino(bonus)], _rival)
	var pueblo := par[1] as Tile
	assert_eq(pueblo.food_production, 4, "precondición: es del rival")

	pueblo.set_controller(_imperio)
	assert_eq(pueblo.food_production, 9,
		"al conquistarlo pasa a cumplir la condición de propiedad")


func test_urbanizar_el_pueblo_pierde_la_bonificacion() -> void:
	# Consecuencia de diseño que conviene tener escrita: crecer un pueblo a ciudad
	# le quita la comida del molino.
	var bonus := _bonus(5)
	bonus.allowed_locations = [VILLAGE] as Array[Tile.location_type]
	var par := _ciudad_y_pueblo([_molino(bonus)], _imperio)
	var pueblo := par[1] as Tile
	assert_eq(pueblo.food_production, 9, "precondición: es un pueblo")

	var ciudad_loc := LocationType.new()
	ciudad_loc.type = TOWN
	ciudad_loc.max_building = 3
	ciudad_loc.food_consumption = 5
	pueblo.location = ciudad_loc
	assert_eq(pueblo.food_production, -1,
		"de ciudad ya no cumple la condición: 4 de recurso − 5 de consumo")


# ---------------------------------------------------------------------------
# Paridad vivo ↔ snapshot
# ---------------------------------------------------------------------------

func test_los_dos_mundos_calculan_la_misma_bonificacion() -> void:
	# El vivo recorre referencias a nodos y el snapshot enteros: son dos recorridos
	# distintos de la misma regla, y divergir aquí haría que el MCTS simulase una
	# economía que el juego no tiene.
	var bonus := _bonus(5)
	bonus.allowed_locations = [VILLAGE] as Array[Tile.location_type]
	var par := _ciudad_y_pueblo([_molino(bonus)], _imperio)
	var vivo: int = (par[1] as Tile).food_production

	var s := AIRealState.new()
	var ciudad := AIRealState.TileSnap.new()
	ciudad.id = 0
	ciudad.owner = AIRealState.OWNER_SELF
	ciudad.location_type = TOWN
	ciudad.resource_food = 1
	ciudad.resource_gold = 1
	ciudad.neighbor_ids = [1] as Array[int]
	var lista: Array[Building] = []
	lista.append(_molino(bonus))
	ciudad.buildings = lista

	var pueblo := AIRealState.TileSnap.new()
	pueblo.id = 1
	pueblo.owner = AIRealState.OWNER_SELF
	pueblo.location_type = VILLAGE
	pueblo.resource_food = 4
	pueblo.resource_gold = 1
	pueblo.neighbor_ids = [0] as Array[int]
	s.tiles[0] = ciudad
	s.tiles[1] = pueblo

	var extra := s.incoming_neighbor_bonus(pueblo)
	var snapshot: int = pueblo.food_production() + int(extra["food"])
	assert_eq(snapshot, vivo,
		"los dos mundos deben dar la misma comida (vivo %d, snapshot %d)" % [vivo, snapshot])


# ---------------------------------------------------------------------------
# La IA tiene que verlo
# ---------------------------------------------------------------------------

func test_la_ia_valora_el_molino_por_sus_vecinos() -> void:
	# Sin el término de vecindad, el molino puntúa por su `food_produced` local, que
	# es CERO: la IA no lo construiría nunca y la mecánica quedaría muerta.
	var bonus := _bonus(5)
	bonus.allowed_locations = [VILLAGE] as Array[Tile.location_type]
	var molino := _molino(bonus)

	var par := _ciudad_y_pueblo([], _imperio)
	var con_vecino: Vector2i = AILiveFacts._neighbor_bonus_yield(molino, par[0] as Tile)
	assert_eq(con_vecino.y, 5, "un pueblo propio al lado vale 5 de comida")

	var aislada := TestBuilders.tile().with_location(TOWN, 3).with_controller(_imperio).build()
	add_child_autofree(aislada)
	assert_eq(AILiveFacts._neighbor_bonus_yield(molino, aislada), Vector2i.ZERO,
		"sin vecinos que cumplan, el molino no aporta nada")


func test_seis_pueblos_valen_seis_veces_uno() -> void:
	# Es el argumento de la mecánica: el mismo coste llega a seis casillas.
	var bonus := _bonus(5)
	bonus.allowed_locations = [VILLAGE] as Array[Tile.location_type]
	var molino := _molino(bonus)
	var ciudad := TestBuilders.tile().with_location(TOWN, 3).with_controller(_imperio).build()
	add_child_autofree(ciudad)
	var vecinos: Array = []
	for i in range(6):
		var p := TestBuilders.tile().with_location(VILLAGE, 1).with_controller(_imperio).build()
		add_child_autofree(p)
		vecinos.append(p)
	ciudad.neighbors = vecinos

	assert_eq(AILiveFacts._neighbor_bonus_yield(molino, ciudad).y, 30,
		"seis pueblos propios deben valer 30 de comida")


# ---------------------------------------------------------------------------
# El molino real del catálogo
# ---------------------------------------------------------------------------

func test_el_molino_del_catalogo_carga_con_su_bonificacion() -> void:
	# Un `.tres` con un sub-recurso tipado es justo lo que en este proyecto ha
	# devuelto null en ejecución sin error de parseo.
	var b := load("res://resources/buildings/molino.tres") as Building
	assert_not_null(b, "molino.tres debe cargar")
	assert_true(b.has_neighbor_bonuses(), "y traer su bonificación de vecindad")
	assert_eq(b.food_produced, 0, "ya no produce comida en su casilla")
	var bonus: NeighborBonus = b.neighbor_bonuses[0]
	assert_eq(bonus.food, 5, "reparte 5 de comida")
	assert_true(bonus.only_same_owner, "solo a casillas propias")
	assert_true(VILLAGE in bonus.allowed_locations, "solo a pueblos")


func test_el_molino_solo_se_puede_construir_en_ciudad_o_megalopolis() -> void:
	# Ojo: `Tile.can_build` compara la localizacion POR REFERENCIA al recurso, no por
	# valor de enum, asi que hay que cargar los `.tres` reales. (El snapshot de la IA
	# compara por enum — su propia cabecera lo documenta —, de modo que aqui los dos
	# mundos ya se comportaban distinto antes de esta mecanica.)
	var b := load("res://resources/buildings/molino.tres") as Building
	var loc_pueblo := load("res://resources/location_type/village.tres") as LocationType
	var loc_ciudad := load("res://resources/location_type/town.tres") as LocationType
	assert_not_null(loc_pueblo)
	assert_not_null(loc_ciudad)

	var pueblo := TestBuilders.tile().build()
	var ciudad := TestBuilders.tile().build()
	add_child_autofree(pueblo)
	add_child_autofree(ciudad)
	pueblo.location = loc_pueblo
	ciudad.location = loc_ciudad
	assert_false(pueblo.can_build(b), "en un pueblo ya no se puede levantar")
	assert_true(ciudad.can_build(b), "en una ciudad si")
