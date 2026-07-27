extends GutTest

## Tests de AITerritory: los factores territoriales unificados (refactor C4 §1.3.c).
## Antes vivían duplicados en AIHeuristic (estado vivo) y AIRealEvalStrong (snapshot).
## Fijan las bandas de expansión, encierro y carrera territorial sobre los pesos por
## defecto. La paridad de comportamiento entre ambos mundos la cubren además, a alto
## nivel, test_ai_heuristic* y test_ai_real_eval_strong.


func _w() -> HeuristicWeights:
	return HeuristicWeights.new()


# ------------------------------------------------------------------
#  Expansión
# ------------------------------------------------------------------

func test_expansion_factor_unknown_zero_and_saturation() -> void:
	var w := _w()   # expansion_reference=15, expansion_unknown=0.5
	assert_almost_eq(AITerritory.expansion_factor(-1, w), 0.5, 0.001)   # desconocido
	assert_almost_eq(AITerritory.expansion_factor(0, w), 0.0, 0.001)
	assert_almost_eq(AITerritory.expansion_factor(3, w), 0.2, 0.001)    # 3/15
	assert_almost_eq(AITerritory.expansion_factor(15, w), 1.0, 0.001)   # satura
	assert_almost_eq(AITerritory.expansion_factor(30, w), 1.0, 0.001)   # sigue saturado


# ------------------------------------------------------------------
#  Encierro
# ------------------------------------------------------------------

func test_encirclement_pressure_ratio_bands() -> void:
	var w := _w()   # r2=2.0/high=1.5, r1=1.0/mid=2.5, r05=0.5/low=4.0, min=5.0
	assert_almost_eq(AITerritory.encirclement_pressure(20, 10, w), 1.5, 0.001)  # ratio 2.0
	assert_almost_eq(AITerritory.encirclement_pressure(10, 10, w), 2.5, 0.001)  # ratio 1.0
	assert_almost_eq(AITerritory.encirclement_pressure(5, 10, w), 4.0, 0.001)   # ratio 0.5
	assert_almost_eq(AITerritory.encirclement_pressure(2, 10, w), 5.0, 0.001)   # ratio 0.2 (rodeado)


# ------------------------------------------------------------------
#  Carrera territorial
# ------------------------------------------------------------------

func test_territory_race_colonize_modes() -> void:
	var w := _w()  # close_share=0.60/×2.0, lead_share=0.50/×1.5, block_share=0.55/×1.5
	# Dominando (share ≈0.857 ≥ 0.60) → cierre ×2.0.
	assert_almost_eq(AITerritory.territory_race_factor(6, 1, 0, &"colonize", w), 2.0, 0.001)
	# Liderando (share 0.50, < 0.60) → lead ×1.5.
	assert_almost_eq(AITerritory.territory_race_factor(5, 4, 1, &"colonize", w), 1.5, 0.001)
	# Rival cerca de su límite (rival_share 0.60 ≥ 0.55) → bloqueo ×1.5.
	assert_almost_eq(AITerritory.territory_race_factor(2, 6, 2, &"colonize", w), 1.5, 0.001)
	# Reparto equilibrado con espacio libre → neutro ×1.0.
	assert_almost_eq(AITerritory.territory_race_factor(3, 3, 4, &"colonize", w), 1.0, 0.001)


func test_territory_race_open_front_shares_colonize_logic() -> void:
	var w := _w()
	assert_almost_eq(AITerritory.territory_race_factor(6, 1, 0, &"open_front", w), 2.0, 0.001)


func test_territory_race_economy_mode() -> void:
	var w := _w()  # economy: solo aplica el descuento en modo cierre (tr_econ_factor=0.7)
	assert_almost_eq(AITerritory.territory_race_factor(6, 1, 0, &"economy", w), 0.7, 0.001)
	assert_almost_eq(AITerritory.territory_race_factor(3, 3, 4, &"economy", w), 1.0, 0.001)
