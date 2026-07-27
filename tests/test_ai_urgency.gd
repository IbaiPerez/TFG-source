extends GutTest

## Tests de AIUrgency: las señales de urgencia por recurso unificadas (refactor C4
## §1.3.a). Antes vivían duplicadas en AIHeuristic (estado vivo) y AIRealEvalStrong
## (snapshot). Además de fijar los umbrales por fase, se documenta la CLAVE de
## paridad: bajo los pesos por defecto la comida en MID y LATE coincide (por eso el
## espejo podía colapsarlas), pero la fórmula unificada honra food_urg_late_* si el
## optimizador los separa — corrigiendo la divergencia latente.


func _w() -> HeuristicWeights:
	return HeuristicWeights.new()


# ------------------------------------------------------------------
#  Urgencia de oro
# ------------------------------------------------------------------

func test_gold_urgency_early_bands() -> void:
	var w := _w()
	assert_almost_eq(AIUrgency.gold_urgency(5, AIGamePhase.Phase.EARLY, w), 3.0, 0.001)
	assert_almost_eq(AIUrgency.gold_urgency(20, AIGamePhase.Phase.EARLY, w), 1.8, 0.001)
	assert_almost_eq(AIUrgency.gold_urgency(45, AIGamePhase.Phase.EARLY, w), 1.0, 0.001)
	assert_almost_eq(AIUrgency.gold_urgency(80, AIGamePhase.Phase.EARLY, w), 0.7, 0.001)


func test_gold_urgency_mid_and_late_bands() -> void:
	var w := _w()
	assert_almost_eq(AIUrgency.gold_urgency(300, AIGamePhase.Phase.MID, w), 1.0, 0.001)
	assert_almost_eq(AIUrgency.gold_urgency(-5, AIGamePhase.Phase.LATE, w), 3.0, 0.001)
	assert_almost_eq(AIUrgency.gold_urgency(600, AIGamePhase.Phase.LATE, w), 0.5, 0.001)
	assert_almost_eq(AIUrgency.gold_urgency(2500, AIGamePhase.Phase.LATE, w), 0.35, 0.001)


# ------------------------------------------------------------------
#  Urgencia de comida
# ------------------------------------------------------------------

func test_food_urgency_bands() -> void:
	var w := _w()
	assert_almost_eq(AIUrgency.food_urgency(-1, AIGamePhase.Phase.EARLY, w), 3.0, 0.001)
	assert_almost_eq(AIUrgency.food_urgency(3, AIGamePhase.Phase.EARLY, w), 1.0, 0.001)
	assert_almost_eq(AIUrgency.food_urgency(3, AIGamePhase.Phase.MID, w), 2.0, 0.001)
	assert_almost_eq(AIUrgency.food_urgency(7, AIGamePhase.Phase.MID, w), 1.2, 0.001)


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
	w.food_urg_late_v1 = 9.9   # antes: LATE reutilizaba food_urg_mid_v1 (2.0)
	assert_almost_eq(AIUrgency.food_urgency(3, AIGamePhase.Phase.LATE, w), 9.9, 0.001,
		"LATE usa sus propios pesos")
	assert_almost_eq(AIUrgency.food_urgency(3, AIGamePhase.Phase.MID, w), 2.0, 0.001,
		"MID no se ve afectado por los pesos de LATE")


# ------------------------------------------------------------------
#  Urgencia de mazo
# ------------------------------------------------------------------

func test_deck_urgency_bands() -> void:
	var w := _w()
	assert_almost_eq(AIUrgency.deck_urgency(2, w), 2.0, 0.001)
	assert_almost_eq(AIUrgency.deck_urgency(3, w), 1.4, 0.001)   # frontera: 3 no es < 3
	assert_almost_eq(AIUrgency.deck_urgency(4, w), 1.4, 0.001)
	assert_almost_eq(AIUrgency.deck_urgency(6, w), 1.0, 0.001)   # frontera: 6 no es < 6
	assert_almost_eq(AIUrgency.deck_urgency(10, w), 1.0, 0.001)


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


## Baseline por amenaza (activo > adyacente > tranquilo) interpolado hacia el techo
## por la presión máxima. Con presión 0 devuelve el baseline exacto.
func test_military_urgency_baselines() -> void:
	var w := _w()   # idle=0.4, adjacent=0.9, active=1.5, max=3.0
	assert_almost_eq(AIUrgency.military_urgency_from(false, false, 0.0, w), 0.4, 0.001)
	assert_almost_eq(AIUrgency.military_urgency_from(false, true, 0.0, w), 0.9, 0.001)
	assert_almost_eq(AIUrgency.military_urgency_from(true, false, 0.0, w), 1.5, 0.001)
	# Frente activo tiene prioridad sobre "enemigo adyacente".
	assert_almost_eq(AIUrgency.military_urgency_from(true, true, 0.0, w), 1.5, 0.001)


func test_military_urgency_interpolates_with_pressure() -> void:
	var w := _w()
	# Frente activo perdiéndose del todo → techo.
	assert_almost_eq(AIUrgency.military_urgency_from(true, false, 1.0, w), 3.0, 0.001)
	# Tranquilo pero con media presión → interpolación lerpf(0.4, 3.0, 0.5).
	assert_almost_eq(AIUrgency.military_urgency_from(false, false, 0.5, w), 1.7, 0.001)
