extends GutTest

## Tests de AIEconomy: los factores económicos unificados (refactor C4 §1.3.d).
## Antes vivían duplicados en AIHeuristic (estado vivo) y AIRealEvalStrong (snapshot).
## Fijan las bandas de excedente y de coste de construcción sobre los pesos por defecto.


func _w() -> HeuristicWeights:
	return HeuristicWeights.new()


# ------------------------------------------------------------------
#  Excedente de recursos
# ------------------------------------------------------------------

func test_surplus_requires_food_margin() -> void:
	var w := _w()   # surplus_min_food=5
	# Sin margen de comida, no hay excedente aunque sobre el oro.
	assert_almost_eq(AIEconomy.resource_surplus_factor(3, 500, AIGamePhase.Phase.MID, w),
		1.0, 0.001)


func test_surplus_neutral_below_comfortable() -> void:
	var w := _w()   # comfortable MID=200
	assert_almost_eq(AIEconomy.resource_surplus_factor(10, 200, AIGamePhase.Phase.MID, w),
		1.0, 0.001)   # gpt == umbral → aún neutro


func test_surplus_scales_above_comfortable() -> void:
	var w := _w()   # comfortable MID=200, surplus_max=3.0
	# gpt duplica el umbral → máximo.
	assert_almost_eq(AIEconomy.resource_surplus_factor(10, 400, AIGamePhase.Phase.MID, w),
		3.0, 0.001)
	# gpt a mitad de camino → lerp(1, 3, 0.5) = 2.0.
	assert_almost_eq(AIEconomy.resource_surplus_factor(10, 300, AIGamePhase.Phase.MID, w),
		2.0, 0.001)


func test_surplus_uses_phase_thresholds() -> void:
	var w := _w()   # comfortable EARLY=80, LATE=350
	assert_almost_eq(AIEconomy.resource_surplus_factor(10, 80, AIGamePhase.Phase.EARLY, w),
		1.0, 0.001)   # justo en el umbral early
	assert_almost_eq(AIEconomy.resource_surplus_factor(10, 700, AIGamePhase.Phase.LATE, w),
		3.0, 0.001)   # doble del umbral late


# ------------------------------------------------------------------
#  Coste de construcción
# ------------------------------------------------------------------

func test_build_cost_factor_zero_gold_returns_minimum() -> void:
	var w := _w()   # build_cost_min=0.6
	assert_almost_eq(AIEconomy.build_cost_factor(50, 0, w), 0.6, 0.001)


func test_build_cost_factor_full_spend_returns_minimum() -> void:
	var w := _w()
	assert_almost_eq(AIEconomy.build_cost_factor(100, 100, w), 0.6, 0.001)


func test_build_cost_factor_half_spend() -> void:
	var w := _w()
	assert_almost_eq(AIEconomy.build_cost_factor(50, 100, w), 0.8, 0.001)   # lerp(1, 0.6, 0.5)


func test_build_cost_factor_residual_spend_near_one() -> void:
	var w := _w()
	assert_gt(AIEconomy.build_cost_factor(1, 10000, w), 0.99)
