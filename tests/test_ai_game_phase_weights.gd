extends GutTest

## Las FRONTERAS entre fases de partida (EARLY / MID / LATE) eran constantes en
## `GameBalance`, el fichero de reglas. No lo son: ninguna regla del juego depende de
## la fase —no cambia el combate, ni la producción, ni la condición de victoria—. Es
## solo la lectura con la que la IA elige qué curva de urgencia y qué pesos aplica.
##
## Estar en el sitio equivocado tenía una consecuencia concreta: el optimizador no
## podía tocarlas. SA/GA ajustaba con precisión CUÁNTO vale cada cosa en cada fase
## mientras DÓNDE empieza cada fase seguía clavado a mano. Ahora son pesos.
##
## Estos tests afirman la REGLA, no los números: derivan las entradas del propio
## campo de peso, así que siguen midiendo la frontera aunque el campeón la mueva.


const TOTAL := 100      ## tamaño de mapa cómodo para razonar en porcentajes


func _w() -> HeuristicWeights:
	return HeuristicWeights.new()


# ---------------------------------------------------------------------------
# Los dos mundos
# ---------------------------------------------------------------------------

func _fase_snapshot(propias: int, total: int, gpt: int,
		w: HeuristicWeights) -> AIGamePhase.Phase:
	var s := AIRealState.new()
	s.total_map_tiles = total
	s.own.gold_per_turn = gpt
	for i in range(propias):
		var t := AIRealState.TileSnap.new()
		t.id = i
		t.owner = AIRealState.OWNER_SELF
		s.tiles[i] = t
	return SnapshotStateView.new(s, AIRealState.OWNER_SELF, w).phase()


func _fase_viva(propias: int, total: int, gpt: int,
		w: HeuristicWeights) -> AIGamePhase.Phase:
	var tiles: Array = []
	for i in range(propias):
		var t := TestBuilders.tile().build()
		add_child_autofree(t)
		tiles.append(t)
	var stats := TestBuilders.stats().with_tiles(tiles).with_gpt(gpt) \
		.with_event_chance(0.0).build()
	return AIGamePhase.detect(stats, total, w)


# ---------------------------------------------------------------------------
# La frontera está donde dice el peso
# ---------------------------------------------------------------------------

func test_la_frontera_de_late_esta_en_la_cuota_que_dice_el_peso() -> void:
	# Entradas DERIVADAS del umbral: si el campeón lo mueve, el test se mueve con él.
	var w := _w()
	var justo := int(ceil(w.phase_late_share * TOTAL))
	assert_eq(_fase_snapshot(justo, TOTAL, 0, w), AIGamePhase.Phase.LATE,
		"con la cuota del umbral debe ser LATE")
	assert_ne(_fase_snapshot(justo - 1, TOTAL, 0, w), AIGamePhase.Phase.LATE,
		"una casilla por debajo del umbral todavía no es LATE")


func test_la_frontera_de_early_esta_donde_dicen_los_dos_pesos() -> void:
	# EARLY exige AMBAS condiciones: poca cuota Y economía inicial.
	var w := _w()
	var pocas := int(w.phase_early_share * TOTAL) - 1
	assert_eq(_fase_snapshot(pocas, TOTAL, int(w.phase_early_gpt) - 1, w),
		AIGamePhase.Phase.EARLY, "poca cuota y poco gpt es EARLY")
	assert_eq(_fase_snapshot(pocas, TOTAL, int(w.phase_early_gpt), w),
		AIGamePhase.Phase.MID,
		"alcanzar el gpt del umbral saca de EARLY aunque el imperio siga siendo pequeño")


func test_bajar_el_peso_de_late_adelanta_la_fase() -> void:
	# EL test que discrimina: el mismo estado, dos pesos, dos fases. Sin esto, el
	# código podía seguir leyendo la constante y nadie se enteraría.
	var propias := 20
	assert_eq(_fase_snapshot(propias, TOTAL, 0, _w()), AIGamePhase.Phase.MID,
		"precondición: con los pesos por defecto este estado es MID")

	var w := _w()
	w.phase_late_share = float(propias) / float(TOTAL) - 0.01
	assert_eq(_fase_snapshot(propias, TOTAL, 0, w), AIGamePhase.Phase.LATE,
		"bajar la cuota de LATE debe adelantar la fase")


func test_subir_el_peso_de_early_retrasa_la_fase() -> void:
	var propias := 20
	var w := _w()
	w.phase_early_share = float(propias) / float(TOTAL) + 0.01
	w.phase_early_gpt = 60.0
	assert_eq(_fase_snapshot(propias, TOTAL, 50, w), AIGamePhase.Phase.EARLY,
		"subir la cuota de EARLY debe retrasar la fase")


func test_el_umbral_de_gpt_de_late_escala_con_el_tamano_del_mapa() -> void:
	# El mismo gpt no significa lo mismo en un mapa el doble de grande: producir 350
	# con el doble de sitio donde crecer no es estar igual de avanzado.
	var w := _w()
	var referencia := GameBalance.DEFAULT_MAP_TILE_COUNT
	var gpt := int(w.phase_late_gpt)
	assert_eq(_fase_snapshot(1, referencia, gpt, w), AIGamePhase.Phase.LATE,
		"al tamaño de referencia, el gpt del umbral es LATE")
	assert_ne(_fase_snapshot(2, referencia * 2, gpt, w), AIGamePhase.Phase.LATE,
		"en un mapa del doble de grande, el mismo gpt aún no es LATE")


# ---------------------------------------------------------------------------
# Paridad vivo ↔ snapshot
# ---------------------------------------------------------------------------

func test_los_dos_mundos_leen_los_mismos_pesos() -> void:
	# Ojo con lo que exige: la paridad se comprueba con pesos NO por defecto. Con los
	# de serie pasaría igual aunque los dos mundos ignorasen `w`, que es exactamente
	# el fallo que había.
	var w := _w()
	w.phase_late_share = 0.15
	w.phase_early_share = 0.05
	w.phase_early_gpt = 40.0
	for propias in [2, 6, 14, 20]:
		assert_eq(_fase_viva(propias, TOTAL, 30, w), _fase_snapshot(propias, TOTAL, 30, w),
			"con %d casillas los dos mundos deben coincidir" % propias)


func test_sin_pesos_se_usan_los_por_defecto() -> void:
	# Contextos sin pesos (enumeración de jugadas, logs de simulación) siguen
	# funcionando: `null` no puede significar "sin fase".
	for propias in [2, 12, 40]:
		assert_eq(AIGamePhase.detect_from(80, propias, TOTAL, null),
			AIGamePhase.detect_from(80, propias, TOTAL, HeuristicWeights.get_default()),
			"con w nulo debe decidir como el default")


# ---------------------------------------------------------------------------
# El optimizador
# ---------------------------------------------------------------------------

const CLAVES_FASE := ["phase_late_share", "phase_early_share",
	"phase_early_gpt", "phase_late_gpt"]


func test_las_fronteras_de_fase_entran_en_el_espacio_de_busqueda() -> void:
	var keys := HeuristicWeightsSpec.OPTIMIZABLE_KEYS
	for k in CLAVES_FASE:
		assert_true(keys.has(k), "%s debe ser optimizable" % k)


func test_las_claves_nuevas_van_al_final_y_no_desplazan_el_layout() -> void:
	# El orden de OPTIMIZABLE_KEYS ES el layout del vector. Insertarlas en su grupo
	# temático habría corrido los índices de todas las posteriores y dejado sin
	# sentido los vectores guardados de las tandas anteriores.
	var keys := HeuristicWeightsSpec.OPTIMIZABLE_KEYS
	var ultimas: Array = []
	for i in range(keys.size() - CLAVES_FASE.size(), keys.size()):
		ultimas.append(keys[i])
	assert_eq(ultimas, CLAVES_FASE,
		"las fronteras de fase deben ocupar las últimas dimensiones del vector")


func test_las_cuotas_se_buscan_dentro_de_cero_uno() -> void:
	# Son FRACCIONES del mapa. La regla general de rangos ([d·0.25, d·4]) llevaría el
	# umbral de LATE por encima de 1: una cuota inalcanzable que apagaría la rama
	# entera y dejaría al optimizador quemando partidas en una dimensión muerta.
	assert_gt(HeuristicWeights.get_default().phase_late_share * 4.0, 1.0,
		"precondición: la regla general se saldría de [0,1]")
	for k in ["phase_late_share", "phase_early_share"]:
		assert_eq(HeuristicWeightsSpec.get_bounds(k), Vector2(0.0, 1.0),
			"%s debe buscarse en [0,1]" % k)


func test_el_vector_lleva_y_trae_las_fronteras() -> void:
	var w := _w()
	w.phase_late_share = 0.22
	w.phase_late_gpt = 500.0
	var v := HeuristicWeightsSpec.to_vector(w)
	var destino := HeuristicWeights.new()
	HeuristicWeightsSpec.apply_vector(destino, v)
	assert_almost_eq(destino.phase_late_share, 0.22, 0.0001)
	assert_almost_eq(destino.phase_late_gpt, 500.0, 0.0001)


func test_validate_rechaza_fronteras_cruzadas() -> void:
	# El optimizador mueve las cuatro por separado, así que PUEDE cruzarlas. Cruzadas
	# la detección no falla: devuelve una fase que ya no significa lo que dice.
	assert_eq(HeuristicWeightsSpec.validate(_w()).size(), 0,
		"los pesos por defecto deben validar")

	var cruzado := _w()
	cruzado.phase_early_share = cruzado.phase_late_share + 0.1
	assert_gt(HeuristicWeightsSpec.validate(cruzado).size(), 0,
		"una cuota EARLY por encima de la de LATE debe rechazarse")

	var cruzado_gpt := _w()
	cruzado_gpt.phase_early_gpt = cruzado_gpt.phase_late_gpt + 1.0
	assert_gt(HeuristicWeightsSpec.validate(cruzado_gpt).size(), 0,
		"un gpt EARLY por encima del de LATE debe rechazarse")
