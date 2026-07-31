extends GutTest

## Tests de AIUrgency: las señales de urgencia por recurso unificadas (refactor C4
## §1.3.a). Antes vivían duplicadas en AIHeuristic (estado vivo) y AIRealEvalStrong
## (snapshot).
##
## MÉTODO (refactor §4.4): estas pruebas afirman contra los CAMPOS de pesos, no
## contra el número que hoy tienen. Escribir `assert(gold_urgency(5, EARLY) == 3.0)`
## cuando `gold_urg_early_v0` VALE 3.0 no comprueba la función: repite el peso. No
## puede cazar un bug —solo detectar que alguien cambió una constante— y obliga a
## editar el literal en cada reajuste.
##
## Afirmando `== w.gold_urg_early_v0` se comprueba lo que de verdad decide la
## función: EN QUÉ BANDA cae un gpt dado. Eso sí caza fronteras mal puestas, bandas
## invertidas y `<` donde debía ir `<=`, y sobrevive a que se reajusten los pesos.
##
## A eso se suman los invariantes ESTRUCTURALES (monotonía, fronteras, orden entre
## fases), que son la propiedad de diseño y no dependen de ningún valor concreto.


func _w() -> HeuristicWeights:
	return HeuristicWeights.new()


# ------------------------------------------------------------------
#  Urgencia de oro — qué banda aplica
# ------------------------------------------------------------------

func test_gold_urgency_early_selecciona_su_banda() -> void:
	var w := _w()
	assert_almost_eq(AIUrgency.gold_urgency(5, AIGamePhase.Phase.EARLY, w),
		w.gold_urg_early_v0, 0.001, "por debajo del primer umbral")
	assert_almost_eq(AIUrgency.gold_urgency(20, AIGamePhase.Phase.EARLY, w),
		w.gold_urg_early_v1, 0.001)
	assert_almost_eq(AIUrgency.gold_urgency(45, AIGamePhase.Phase.EARLY, w),
		w.gold_urg_early_v2, 0.001)
	assert_almost_eq(AIUrgency.gold_urgency(80, AIGamePhase.Phase.EARLY, w),
		w.gold_urg_early_v3, 0.001, "por encima del último umbral")


func test_gold_urgency_mid_y_late_seleccionan_su_banda() -> void:
	var w := _w()
	assert_almost_eq(AIUrgency.gold_urgency(300, AIGamePhase.Phase.MID, w),
		w.gold_urg_mid_v3, 0.001)
	assert_almost_eq(AIUrgency.gold_urgency(-5, AIGamePhase.Phase.LATE, w),
		w.gold_urg_late_v0, 0.001, "gpt negativo cae en la banda mas urgente")
	assert_almost_eq(AIUrgency.gold_urgency(600, AIGamePhase.Phase.LATE, w),
		w.gold_urg_late_v5, 0.001)
	assert_almost_eq(AIUrgency.gold_urgency(2500, AIGamePhase.Phase.LATE, w),
		w.gold_urg_late_v7, 0.001, "por encima del ultimo umbral")


func test_gold_urgency_las_fronteras_son_exclusivas() -> void:
	# Las comparaciones son `<`, no `<=`: un gpt EXACTAMENTE igual al umbral cae en
	# la banda SIGUIENTE. Es la clase de detalle que un literal no distingue.
	var w := _w()
	var justo_debajo := AIUrgency.gold_urgency(
		int(w.gold_urg_early_t0) - 1, AIGamePhase.Phase.EARLY, w)
	var en_el_umbral := AIUrgency.gold_urgency(
		int(w.gold_urg_early_t0), AIGamePhase.Phase.EARLY, w)
	assert_almost_eq(justo_debajo, w.gold_urg_early_v0, 0.001)
	assert_almost_eq(en_el_umbral, w.gold_urg_early_v1, 0.001,
		"gpt == umbral pertenece a la banda siguiente")


func test_gold_urgency_no_crece_con_mas_produccion() -> void:
	# Invariante de diseño: más oro por turno nunca puede ser MÁS urgente. Sobrevive
	# a cualquier reajuste de pesos porque no menciona ningún valor.
	var w := _w()
	for phase in [AIGamePhase.Phase.EARLY, AIGamePhase.Phase.MID, AIGamePhase.Phase.LATE]:
		var previo := AIUrgency.gold_urgency(-50, phase, w)
		for gpt in [0, 10, 30, 60, 100, 250, 500, 1200, 3000]:
			var actual := AIUrgency.gold_urgency(gpt, phase, w)
			assert_true(actual <= previo + 0.0001,
				"urgencia de oro subio al pasar a gpt=%d en fase %d" % [gpt, phase])
			previo = actual


# ------------------------------------------------------------------
#  Urgencia de comida
# ------------------------------------------------------------------

func test_food_urgency_selecciona_su_banda() -> void:
	var w := _w()
	assert_almost_eq(AIUrgency.food_urgency(-1, AIGamePhase.Phase.EARLY, w),
		w.food_urg_early_v0, 0.001)
	assert_almost_eq(AIUrgency.food_urgency(3, AIGamePhase.Phase.EARLY, w),
		w.food_urg_early_v2, 0.001)
	assert_almost_eq(AIUrgency.food_urgency(3, AIGamePhase.Phase.MID, w),
		w.food_urg_mid_v1, 0.001)
	assert_almost_eq(AIUrgency.food_urgency(7, AIGamePhase.Phase.MID, w),
		w.food_urg_mid_v2, 0.001)


func test_food_urgency_no_crece_con_mas_comida() -> void:
	var w := _w()
	for phase in [AIGamePhase.Phase.EARLY, AIGamePhase.Phase.MID, AIGamePhase.Phase.LATE]:
		var previo := AIUrgency.food_urgency(-10, phase, w)
		for food in [-3, -1, 0, 2, 3, 5, 7, 10, 15, 40]:
			var actual := AIUrgency.food_urgency(food, phase, w)
			assert_true(actual <= previo + 0.0001,
				"urgencia de comida subio al pasar a food=%d en fase %d" % [food, phase])
			previo = actual


## Paridad byte-idéntica: con los pesos por defecto, MID y LATE dan el mismo valor
## para todo el rango relevante. Justifica que el espejo pudiera colapsarlas y que
## esta unificación sea behaviour-preserving con el campeón actual.
func test_food_urgency_mid_equals_late_under_defaults() -> void:
	var w := _w()
	for food in [-3, -1, 0, 3, 5, 7, 10, 15, 40]:
		assert_almost_eq(
			AIUrgency.food_urgency(food, AIGamePhase.Phase.MID, w),
			AIUrgency.food_urgency(food, AIGamePhase.Phase.LATE, w),
			0.0001, "MID y LATE coinciden bajo defaults para food=%d" % food)


## La corrección de la divergencia latente: si el optimizador separa los umbrales de
## LATE, la fórmula unificada YA los honra (el espejo antiguo los ignoraba).
func test_food_urgency_late_honors_late_weights() -> void:
	var w := _w()
	var mid_esperado := w.food_urg_mid_v1
	w.food_urg_late_v1 = 9.9   # antes: LATE reutilizaba food_urg_mid_v1
	assert_almost_eq(AIUrgency.food_urgency(3, AIGamePhase.Phase.LATE, w), 9.9, 0.001,
		"LATE usa sus propios pesos")
	assert_almost_eq(AIUrgency.food_urgency(3, AIGamePhase.Phase.MID, w),
		mid_esperado, 0.001, "MID no se ve afectado por los pesos de LATE")


# ------------------------------------------------------------------
#  Urgencia de mazo
# ------------------------------------------------------------------

func test_deck_urgency_selecciona_su_banda() -> void:
	var w := _w()
	assert_almost_eq(AIUrgency.deck_urgency(2, w), w.deck_urg_v0, 0.001)
	assert_almost_eq(AIUrgency.deck_urgency(4, w), w.deck_urg_v1, 0.001)
	assert_almost_eq(AIUrgency.deck_urgency(10, w), w.deck_urg_v2, 0.001)


func test_deck_urgency_las_fronteras_son_exclusivas() -> void:
	var w := _w()
	assert_almost_eq(AIUrgency.deck_urgency(int(w.deck_urg_t0), w), w.deck_urg_v1, 0.001,
		"tamano == t0 ya no es la banda mas urgente")
	assert_almost_eq(AIUrgency.deck_urgency(int(w.deck_urg_t1), w), w.deck_urg_v2, 0.001,
		"tamano == t1 ya no es la banda intermedia")


func test_deck_urgency_no_crece_con_mazos_mas_grandes() -> void:
	var w := _w()
	var previo := AIUrgency.deck_urgency(0, w)
	for size in [1, 2, 3, 4, 5, 6, 8, 12, 30]:
		var actual := AIUrgency.deck_urgency(size, w)
		assert_true(actual <= previo + 0.0001, "urgencia de mazo subio con size=%d" % size)
		previo = actual


# ------------------------------------------------------------------
#  Presión de frente y urgencia militar (§1.3.b)
# ------------------------------------------------------------------

## `ai_marker` negativo = estamos perdiendo el frente → presión positiva; positivo
## (ganando) → 0. Se satura a 1.0 cuando el marcador supera el umbral.
func test_front_pressure_perspective_and_clamp() -> void:
	assert_almost_eq(AIUrgency.front_pressure(0.0, 20.0), 0.0, 0.001)
	assert_almost_eq(AIUrgency.front_pressure(-10.0, 20.0), 0.5, 0.001)   # perdiendo a medias
	assert_almost_eq(AIUrgency.front_pressure(-40.0, 20.0), 1.0, 0.001)   # saturado (perdiendo)
	assert_almost_eq(AIUrgency.front_pressure(10.0, 20.0), 0.0, 0.001)    # ganando → sin presión


func test_front_pressure_siempre_en_rango_unitario() -> void:
	# El clamp es lo que garantiza que la interpolación militar no se dispare.
	for marker in [-1000.0, -40.0, -5.0, 0.0, 5.0, 1000.0]:
		var p := AIUrgency.front_pressure(marker, 20.0)
		assert_between(p, 0.0, 1.0, "presion fuera de [0,1] con marker=%.1f" % marker)


func test_military_urgency_ordena_las_amenazas() -> void:
	# El orden entre baselines es la decisión de diseño: un frente activo apremia más
	# que un enemigo al lado, y este más que la calma. Los números concretos no.
	var w := _w()
	var tranquilo := AIUrgency.military_urgency_from(false, false, 0.0, w)
	var adyacente := AIUrgency.military_urgency_from(false, true, 0.0, w)
	var activo := AIUrgency.military_urgency_from(true, false, 0.0, w)
	assert_lt(tranquilo, adyacente, "enemigo adyacente apremia mas que la calma")
	assert_lt(adyacente, activo, "un frente activo apremia mas que un enemigo adyacente")


func test_military_urgency_baselines() -> void:
	var w := _w()
	assert_almost_eq(AIUrgency.military_urgency_from(false, false, 0.0, w),
		w.mil_urg_base_idle, 0.001)
	assert_almost_eq(AIUrgency.military_urgency_from(false, true, 0.0, w),
		w.mil_urg_base_adjacent, 0.001)
	assert_almost_eq(AIUrgency.military_urgency_from(true, false, 0.0, w),
		w.mil_urg_base_active, 0.001)
	# Frente activo tiene prioridad sobre "enemigo adyacente".
	assert_almost_eq(AIUrgency.military_urgency_from(true, true, 0.0, w),
		w.mil_urg_base_active, 0.001)


func test_military_urgency_interpolates_with_pressure() -> void:
	var w := _w()
	# Presión máxima lleva al techo, venga de donde venga la amenaza.
	assert_almost_eq(AIUrgency.military_urgency_from(true, false, 1.0, w),
		w.mil_urg_max, 0.001)
	assert_almost_eq(AIUrgency.military_urgency_from(false, false, 1.0, w),
		w.mil_urg_max, 0.001, "el techo no depende del baseline")
	# Media presión interpola entre el baseline y el techo.
	assert_almost_eq(AIUrgency.military_urgency_from(false, false, 0.5, w),
		lerpf(w.mil_urg_base_idle, w.mil_urg_max, 0.5), 0.001)


func test_military_urgency_no_baja_con_mas_presion() -> void:
	var w := _w()
	var previo := AIUrgency.military_urgency_from(false, false, 0.0, w)
	for p in [0.1, 0.25, 0.5, 0.75, 0.9, 1.0]:
		var actual := AIUrgency.military_urgency_from(false, false, p, w)
		assert_true(actual >= previo - 0.0001, "la urgencia militar bajo con presion=%.2f" % p)
		previo = actual
