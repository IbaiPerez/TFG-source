extends GutTest

## `Empire.combat_multiplier` es la penalización de combate por déficit económico: si
## no puedes pagar el mantenimiento de tus tropas, luchan peor. `BattleFront` la
## aplica al ataque y a la defensa, así que decide combates.
##
## La calculaba `EmpireController._update_combat_multiplier` y **no la cubría ningún
## test**. El único que existía (`test_combat_multiplier_drops_on_deficit`) es del
## SNAPSHOT y usa una tropa del pool, así que el camino del juego real —y en concreto
## el de las tropas GUARNECIDAS— estaba sin guardas.
##
## Eso importaba especialmente ahora: las tropas asignadas a un frente ya no salen del
## cómputo de mantenimiento (antes su coste base desaparecía y el frente cobraba un
## recargo plano), de modo que tanto el déficit como el denominador de la penalización
## cambiaron. Estos tests fijan el contrato de extremo a extremo, pasando por
## `_process_turn_start` → `ProductionCalculator` → `_update_combat_multiplier`.
##
## La regla: `multiplicador = clamp(1 − (déficit_oro + déficit_comida) / mantenimiento_total, 0.1, 1)`


const SUELO := 0.1
const NEUTRO := 1.0


func before_each() -> void:
	BattleFront.clear_active_instances()


func after_each() -> void:
	BattleFront.clear_active_instances()


# ---------------------------------------------------------------------------
# Escenario
# ---------------------------------------------------------------------------

## Imperio con una casilla que produce `oro`/`comida`, `pool` tropas en reserva y
## `guarnicion` tropas metidas en un frente propio. Ejecuta el arranque de turno
## completo y devuelve el multiplicador resultante.
func _multiplicador(oro: int, comida: int, pool: Array, guarnicion: Array) -> float:
	var ctrl := EmpireController.new()
	add_child_autofree(ctrl)
	# `_init_managers` no lo llama EmpireController: lo hace cada subclase desde su
	# `_ready` (AIController, PlayerHandler). Aquí se prueba la clase base, así que se
	# invoca a mano — si no, sus managers quedan en null.
	ctrl._init_managers()

	var tile := TestBuilders.tile().with_resource(oro, comida).build()
	add_child_autofree(tile)
	var stats := TestBuilders.stats().with_tiles([tile]).with_troop_pool(pool) \
		.with_event_chance(0.0).build()
	ctrl.start_game(stats)

	if not guarnicion.is_empty():
		var enemiga := TestBuilders.tile().build()
		add_child_autofree(enemiga)
		var rival := Empire.new()
		rival.name = "Rival"
		var front := BattleFront.new(tile, enemiga, stats.empire, rival)
		for t in guarnicion:
			front.assign_troop(t as Troop, BattleFront.Side.ATTACKER)
		ctrl.battle_front_manager.stats = stats
		ctrl.battle_front_manager.active_fronts.append(front)

	ctrl._process_turn_start()
	return stats.empire.combat_multiplier


func _tropas(n: int, maint_oro: int, maint_comida: int) -> Array:
	var out: Array = []
	for i in range(n):
		out.append(TestBuilders.troop().with_maintenance(maint_oro, maint_comida).build())
	return out


# ---------------------------------------------------------------------------
# Los dos extremos
# ---------------------------------------------------------------------------

func test_sin_tropas_no_hay_penalizacion_aunque_la_economia_este_en_negativo() -> void:
	# `total_troop_maint == 0` → no hay mantenimiento que dejar sin cubrir. Sin este
	# caso, dividir por cero.
	assert_almost_eq(_multiplicador(0, 0, [], []), NEUTRO, 0.001,
		"sin tropas no hay nada que penalizar")


func test_con_la_economia_holgada_las_tropas_luchan_al_maximo() -> void:
	assert_almost_eq(_multiplicador(500, 500, _tropas(3, 12, 1), []), NEUTRO, 0.001,
		"cubriendo el mantenimiento no debe haber penalización")


func test_un_superavit_enorme_no_da_bonus() -> void:
	# Clamp superior: el multiplicador es una PENALIZACIÓN, nunca un premio.
	assert_lte(_multiplicador(9999, 9999, _tropas(2, 12, 1), []), NEUTRO,
		"el multiplicador nunca debe superar 1.0")


func test_el_colapso_absoluto_se_queda_en_el_suelo() -> void:
	# Clamp inferior: ni en la ruina total las tropas quedan a cero.
	var m := _multiplicador(0, 0, _tropas(8, 25, 3), [])
	assert_almost_eq(m, SUELO, 0.001, "el suelo del multiplicador es 0.1")


# ---------------------------------------------------------------------------
# La penalización responde al déficit
# ---------------------------------------------------------------------------

func test_el_deficit_baja_el_multiplicador() -> void:
	assert_lt(_multiplicador(0, 0, _tropas(3, 12, 1), []), NEUTRO,
		"sin producción y con tropas que mantener, deben luchar peor")


func test_mas_deficit_significa_menos_multiplicador() -> void:
	var previo := NEUTRO + 1.0
	for tropas in [1, 2, 4, 6]:
		var m := _multiplicador(20, 5, _tropas(tropas, 12, 1), [])
		assert_lte(m, previo, "con %d tropas el multiplicador no bajó" % tropas)
		previo = m


func test_el_deficit_de_comida_penaliza_igual_que_el_de_oro() -> void:
	# Los dos déficits se SUMAN en el numerador. Con la misma tropa, faltar comida
	# debe penalizar tanto como faltar oro.
	var falta_oro := _multiplicador(0, 500, _tropas(3, 20, 0), [])
	var falta_comida := _multiplicador(500, 0, _tropas(3, 0, 20), [])
	assert_lt(falta_oro, NEUTRO, "un déficit de oro debe penalizar")
	assert_lt(falta_comida, NEUTRO, "un déficit de comida debe penalizar")
	assert_almost_eq(falta_oro, falta_comida, 0.001,
		"a igual magnitud, los dos recursos deben pesar lo mismo")


# ---------------------------------------------------------------------------
# Tropas GUARNECIDAS: el camino que no cubría nada
# ---------------------------------------------------------------------------

func test_una_guarnicion_impagable_penaliza() -> void:
	# EL caso nuevo. Las tropas de un frente pagan su base por la curva del frente;
	# si eso deja la economía en negativo, el malus debe activarse igual que con las
	# del pool. Antes su coste base desaparecía al asignarlas.
	assert_lt(_multiplicador(10, 2, [], _tropas(4, 25, 3)), NEUTRO,
		"una guarnición que no se puede pagar debe penalizar el combate")


func test_guarnecer_no_es_una_via_para_esquivar_el_malus() -> void:
	# Con la regla anterior, sacar las tropas del pool las libraba de su coste base:
	# mover tropas a un frente ALIVIABA el déficit. Ya no.
	var en_reserva := _multiplicador(10, 2, _tropas(3, 25, 3), [])
	var guarnecidas := _multiplicador(10, 2, [], _tropas(3, 25, 3))
	assert_lt(guarnecidas, NEUTRO,
		"guarnecer no puede dejar al imperio sin penalización")
	assert_lte(guarnecidas, en_reserva,
		"guarnecer cuesta MÁS que tener las tropas en reserva, no menos")


func test_una_guarnicion_mas_grande_penaliza_mas() -> void:
	var dos := _multiplicador(30, 6, [], _tropas(2, 25, 3))
	var cuatro := _multiplicador(30, 6, [], _tropas(4, 25, 3))
	assert_lt(cuatro, dos,
		"el recargo progresivo del frente debe traducirse en más penalización")


# ---------------------------------------------------------------------------
# Paridad con el snapshot del MCTS
# ---------------------------------------------------------------------------

func test_el_snapshot_calcula_el_mismo_malus_que_el_juego() -> void:
	# Si divergieran, el árbol simularía combates con tropas de otra fuerza que las
	# del juego real. Mismo escenario en los dos mundos.
	var vivo := _multiplicador(10, 2, [], _tropas(3, 25, 3))

	var s := AIRealState.new()
	s.total_map_tiles = 10
	var t := AIRealState.TileSnap.new()
	t.id = 0
	t.owner = AIRealState.OWNER_SELF
	t.resource_gold = 10
	t.resource_food = 2
	s.tiles[0] = t
	var fs := AIRealState.FrontSnap.new()
	fs.attacker_owner = AIRealState.OWNER_SELF
	fs.defender_owner = AIRealState.OWNER_RIVAL
	fs.attacker_tile_id = 0
	var tropas: Array[Troop] = []
	for x in _tropas(3, 25, 3):
		tropas.append(x as Troop)
	fs.attacker_troops = tropas
	s.fronts = [fs]
	AIRealSimulator.recompute_own_economy(s)

	assert_almost_eq(s.own.combat_multiplier, vivo, 0.001,
		"los dos mundos deben derivar el mismo malus del mismo déficit")
