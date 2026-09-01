extends GutTest

## `TroopAssignmentPolicy` repartía las tropas del pool entre los frentes con dos
## números fijos: rellenar hasta MIN_TROOPS_PER_FRONT (3) y reforzar hasta MIN+2 (5)
## los que se estuvieran perdiendo. Un suelo y un techo, iguales en toda partida.
##
## El problema no es que 3 y 5 sean malos números: es que el coste de una tropa en un
## frente NO es constante. La n-ésima paga SU mantenimiento base multiplicado por la
## curva del frente, que además es distinta por recurso: suave en oro (cruza el
## crecimiento lineal en la quinta) y empinada en comida (cruza en la segunda).
##
## Lo que AÑADE cada tropa es `base · (multiplicador(n) − 1)`, así que la primera sale
## gratis y a partir de ahí se encarece rápido — y es la COMIDA la que acaba poniendo
## el techo. Cuántas compensan depende de los dos recursos, de lo urgente que sea el
## frente y de la tropa concreta: una infantería pesada satura antes que una milicia.
##
## Ahora se decide por VALOR MARGINAL: se asigna mientras meter una más aporte más de
## lo que cuesta. El límite existe, pero es económico, no un suelo ni un techo fijos.
##
## Limitación conocida y no modelada: comprometer tropas arriesga perderlas al
## resolverse el frente (el perdedor pierde 60–100 %). El valor marginal no lo cotiza.


func _w() -> HeuristicWeights:
	return HeuristicWeights.new()


func before_each() -> void:
	BattleFront.clear_active_instances()


func after_each() -> void:
	BattleFront.clear_active_instances()


# ---------------------------------------------------------------------------
# Escenario sobre el snapshot (más barato de montar y es el mismo algoritmo)
# ---------------------------------------------------------------------------

## Estado con UN frente propio (atacamos), `n_tropas` en el pool, y la economía dada.
func _estado(n_tropas: int, comida: int, gpt: int, marker: float,
		maint_oro := 18, maint_comida := 2) -> AIRealState:
	var s := AIRealState.new()
	s.total_map_tiles = 127
	s.own.food = comida
	s.own.gold_per_turn = gpt
	var pool: Array[Troop] = []
	for i in range(n_tropas):
		pool.append(TestBuilders.troop().with_attack(6).with_defense(1) \
			.with_maintenance(maint_oro, maint_comida).build())
	s.own.troop_pool = pool

	var f := AIRealState.FrontSnap.new()
	f.attacker_owner = AIRealState.OWNER_SELF
	f.defender_owner = AIRealState.OWNER_RIVAL
	f.marker = marker
	s.fronts = [f]
	return s


func _asignadas(n_tropas: int, comida: int, gpt: int, marker: float) -> int:
	var s := _estado(n_tropas, comida, gpt, marker)
	AIRealCombat.assign_troops_to_fronts(s, AIRealState.OWNER_SELF, _w())
	return (s.fronts[0] as AIRealState.FrontSnap).attacker_troops.size()


# ---------------------------------------------------------------------------
# Sin techo
# ---------------------------------------------------------------------------

func test_no_hay_ningun_tope_estructural() -> void:
	# EL test que discrimina por arriba. Ojo con lo que afirma: NO dice "el equilibrio
	# está por encima de 5" —con tropas normales cae en 4-5, que es el punto de diseño
	# de las curvas—, sino que ese límite es ECONÓMICO y no un clamp. Se demuestra
	# anulando el coste que lo impone: una tropa sin mantenimiento de comida escapa
	# de la curva empinada y el frente admite muchas más.
	var s := _estado(16, 400, 3000, -9.0, 1, 0)
	AIRealCombat.assign_troops_to_fronts(s, AIRealState.OWNER_SELF, _w())
	var n := (s.fronts[0] as AIRealState.FrontSnap).attacker_troops.size()
	assert_gt(n, 5, "sin coste de comida no debe haber ningún tope cerca de 5, dio %d" % n)


func test_la_comida_es_la_que_pone_el_techo() -> void:
	# La contrapartida del test anterior, y la razón de que la curva de comida sea más
	# empinada que la de oro: con la MISMA economía y urgencia, lo único que cambia es
	# que la tropa consuma comida o no.
	var sin_comida := _estado(16, 400, 3000, -9.0, 1, 0)
	AIRealCombat.assign_troops_to_fronts(sin_comida, AIRealState.OWNER_SELF, _w())
	var con_comida := _estado(16, 400, 3000, -9.0, 1, 1)
	AIRealCombat.assign_troops_to_fronts(con_comida, AIRealState.OWNER_SELF, _w())

	assert_gt((sin_comida.fronts[0] as AIRealState.FrontSnap).attacker_troops.size(),
		(con_comida.fronts[0] as AIRealState.FrontSnap).attacker_troops.size(),
		"un solo punto de comida por tropa debe recortar la guarnición")


func test_una_guarnicion_de_tropas_caras_se_estabiliza_antes() -> void:
	# La otra cara: el coste escala con la tropa, así que la infantería cara satura
	# el frente mucho antes que la milicia, con la MISMA economía y urgencia.
	var baratas := _estado(14, 400, 3000, -9.0, 1, 1)
	AIRealCombat.assign_troops_to_fronts(baratas, AIRealState.OWNER_SELF, _w())
	var caras := _estado(14, 400, 3000, -9.0, 25, 3)
	AIRealCombat.assign_troops_to_fronts(caras, AIRealState.OWNER_SELF, _w())

	assert_gt((baratas.fronts[0] as AIRealState.FrontSnap).attacker_troops.size(),
		(caras.fronts[0] as AIRealState.FrontSnap).attacker_troops.size(),
		"guarnecer tropas caras debe saturar el frente antes")


func test_mas_comida_nunca_asigna_menos_tropas() -> void:
	# Monotonía en el recurso que de verdad restringe.
	var previo := 0
	for comida in [0, 20, 60, 150, 400]:
		var n := _asignadas(12, comida, 800, -9.0)
		assert_gte(n, previo, "con %d de comida asignó menos que con menos comida" % comida)
		previo = n


# ---------------------------------------------------------------------------
# Sin suelo
# ---------------------------------------------------------------------------

func test_sin_comida_no_se_rellena_hasta_el_antiguo_minimo() -> void:
	# EL test que discrimina por abajo. Con la comida en negativo, meter tropas en un
	# frente que además vamos ganando es tirar comida.
	var n := _asignadas(12, -10, 800, 9.0)
	assert_lt(n, 3, "con hambruna y el frente ganado no debe rellenar hasta 3, dio %d" % n)


func test_un_frente_muy_urgente_recibe_mas_que_uno_tranquilo() -> void:
	# La urgencia sigue mandando en el reparto, ahora como valoración y no como
	# umbral de dos pasadas.
	var perdiendo := _asignadas(12, 200, 800, -9.0)
	var ganando := _asignadas(12, 200, 800, 9.0)
	assert_gt(perdiendo, ganando,
		"el frente que se pierde debe atraer más tropas que el que se gana")


# ---------------------------------------------------------------------------
# El reparto entre frentes no se rompe
# ---------------------------------------------------------------------------

func test_no_deja_sin_nada_al_segundo_frente_cuando_ambos_urgen() -> void:
	# Riesgo del greedy: que el primer frente se coma el pool entero. Al reevaluar el
	# coste marginal tras cada asignación, el recargo progresivo del primero acaba
	# haciendo más rentable el segundo.
	var s := _estado(10, 300, 800, -9.0)
	var f2 := AIRealState.FrontSnap.new()
	f2.attacker_owner = AIRealState.OWNER_SELF
	f2.defender_owner = AIRealState.OWNER_RIVAL
	f2.marker = -9.0
	s.fronts.append(f2)

	AIRealCombat.assign_troops_to_fronts(s, AIRealState.OWNER_SELF, _w())
	var a := (s.fronts[0] as AIRealState.FrontSnap).attacker_troops.size()
	var b := (s.fronts[1] as AIRealState.FrontSnap).attacker_troops.size()
	assert_gt(b, 0, "el segundo frente igual de urgente no puede quedarse a cero (%d/%d)" % [a, b])


func test_nunca_asigna_mas_tropas_de_las_que_hay() -> void:
	var s := _estado(2, 500, 900, -9.0)
	AIRealCombat.assign_troops_to_fronts(s, AIRealState.OWNER_SELF, _w())
	assert_eq((s.fronts[0] as AIRealState.FrontSnap).attacker_troops.size(), 2)
	assert_eq(s.own.troop_pool.size(), 0, "el pool debe quedar vacío, no negativo")


# ---------------------------------------------------------------------------
# La regla marginal, aislada
# ---------------------------------------------------------------------------

func test_el_coste_marginal_espeja_la_curva_del_frente() -> void:
	# Lo que AÑADE la n-ésima tropa es su base por (multiplicador − 1), porque la
	# base ya la pagaba estando en el pool. Se afirma contra la regla compartida.
	var t := TestBuilders.troop().with_maintenance(18, 2).build()
	assert_almost_eq(TroopAssignmentPolicy.marginal_gold_cost(1, t), 0.0, 0.001,
		"la primera tropa no añade coste: ya pagaba su base")
	for n in range(1, 7):
		var esperado := 18.0 * (CombatMath.front_gold_upkeep_multiplier(n) - 1.0)
		assert_almost_eq(TroopAssignmentPolicy.marginal_gold_cost(n, t), esperado, 0.001,
			"n=%d debe seguir la curva de CombatMath" % n)


func test_una_tropa_cara_satura_el_frente_antes_que_una_barata() -> void:
	# Consecuencia de que el recargo escale el coste BASE: guarnecer infantería
	# pesada se encarece más rápido que guarnecer milicia.
	var cara := TestBuilders.troop().with_maintenance(25, 3).build()
	var barata := TestBuilders.troop().with_maintenance(12, 1).build()
	for n in range(2, 7):
		assert_gt(TroopAssignmentPolicy.marginal_gold_cost(n, cara),
			TroopAssignmentPolicy.marginal_gold_cost(n, barata),
			"en n=%d la tropa cara debe añadir más coste" % n)


func test_el_coste_marginal_crece_con_la_posicion() -> void:
	var t := TestBuilders.troop().with_maintenance(18, 2).build()
	var previo := -INF
	for n in range(1, 10):
		var c := TroopAssignmentPolicy.marginal_food_cost(n, t)
		assert_gt(c, previo, "el coste marginal debe crecer con n")
		previo = c
