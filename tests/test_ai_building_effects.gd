extends GutTest

## Tests de AIBuildingEffects: puntuación de efectos de edificio unificada (refactor
## C4 §1.3.f). Antes vivía duplicada en AIHeuristic (estado vivo) y AIRealEvalStrong
## (snapshot). Aquí se fijan las fórmulas con pesos sobre los defaults; los dos casos
## dependientes de estado (CARDS_PER_TURN, TROOPS_PER_RECRUIT) se prueban con su
## escalar ya calculado (my_share / current_bonus), que es como los llama cada mundo.


func _w() -> HeuristicWeights:
	return HeuristicWeights.new()


# ------------------------------------------------------------------
#  Casos simples de AddStatModifierEffect
# ------------------------------------------------------------------

func test_stat_effect_simple_flat_and_percent() -> void:
	var w := _w()   # se_flat_gold=5, se_percent_gold=5, se_flat_food=4, se_percent_food=4
	assert_almost_eq(AIBuildingEffects.stat_effect_simple(
		StatModifier.StatType.FLAT_GOLD, 2.0, 0, 0, 0, 1.0, 1.0, 1.0, w), 10.0, 0.001)
	assert_almost_eq(AIBuildingEffects.stat_effect_simple(
		StatModifier.StatType.PERCENT_GOLD, 10.0, 100, 0, 0, 1.0, 1.0, 1.0, w), 50.0, 0.001)
	assert_almost_eq(AIBuildingEffects.stat_effect_simple(
		StatModifier.StatType.FLAT_FOOD, 3.0, 0, 0, 0, 1.0, 1.0, 1.0, w), 12.0, 0.001)
	assert_almost_eq(AIBuildingEffects.stat_effect_simple(
		StatModifier.StatType.PERCENT_FOOD, 10.0, 0, 50, 0, 1.0, 1.0, 1.0, w), 20.0, 0.001)


func test_stat_effect_simple_tiles_draw_and_maintenance() -> void:
	var w := _w()   # se_tile_gold=5, se_tile_food=4, se_card_draw=8, se_maint=0.3
	assert_almost_eq(AIBuildingEffects.stat_effect_simple(
		StatModifier.StatType.TILE_RESOURCE_GOLD, 2.0, 0, 0, 0, 1.0, 1.0, 1.0, w), 10.0, 0.001)
	assert_almost_eq(AIBuildingEffects.stat_effect_simple(
		StatModifier.StatType.CARD_DRAW_BONUS, 1.0, 0, 0, 0, 1.0, 1.0, 1.0, w), 8.0, 0.001)
	# TROOP_MAINTENANCE_PERCENT: pool_size 4 * |−10| * 0.3 * mu 1 = 12.
	assert_almost_eq(AIBuildingEffects.stat_effect_simple(
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT, -10.0, 0, 0, 4, 1.0, 1.0, 1.0, w), 12.0, 0.001)


func test_stat_effect_simple_returns_zero_for_state_dependent_cases() -> void:
	# CARDS_PER_TURN / TROOPS_PER_RECRUIT los resuelve el llamante → aquí 0.0.
	var w := _w()
	assert_almost_eq(AIBuildingEffects.stat_effect_simple(
		StatModifier.StatType.CARDS_PER_TURN, 1.0, 0, 0, 0, 1.0, 1.0, 1.0, w), 0.0, 0.001)
	assert_almost_eq(AIBuildingEffects.stat_effect_simple(
		StatModifier.StatType.TROOPS_PER_RECRUIT, 1.0, 0, 0, 0, 1.0, 1.0, 1.0, w), 0.0, 0.001)


# ------------------------------------------------------------------
#  Cartas por turno (valor de flujo con horizonte)
# ------------------------------------------------------------------

func test_cards_per_turn_horizon_falls_near_victory() -> void:
	var w := _w()   # horizon_lo=5, horizon_hi=40, share_target=0.70, base=8, scale=0.6
	# Lejos de ganar (my_share 0) → horizonte máximo → v*(8+40*0.6)=v*32.
	assert_almost_eq(AIBuildingEffects.cards_per_turn_score(1.0, 0.0, w), 32.0, 0.001)
	# En el umbral de victoria (0.70) → horizonte mínimo → v*(8+5*0.6)=v*11.
	assert_almost_eq(AIBuildingEffects.cards_per_turn_score(1.0, 0.70, w), 11.0, 0.001)
	# A medio camino (0.35) → horizonte 22.5 → v*(8+13.5)=v*21.5.
	assert_almost_eq(AIBuildingEffects.cards_per_turn_score(1.0, 0.35, w), 21.5, 0.001)


# ------------------------------------------------------------------
#  Tropas por reclutamiento (rendimiento decreciente)
# ------------------------------------------------------------------

func test_troops_per_recruit_scales_with_mu_and_decays() -> void:
	var w := _w()   # base=5, mu_w=20, dr_k=0.12
	# Sin bonus previo, mu=1 → (5+20)*1 = 25.
	assert_almost_eq(AIBuildingEffects.troops_per_recruit_score(1.0, 1.0, 0, w), 25.0, 0.001)
	# Sin urgencia militar (mu=0) → base 5.
	assert_almost_eq(AIBuildingEffects.troops_per_recruit_score(1.0, 0.0, 0, w), 5.0, 0.001)
	# Con bonus acumulado 4 → dr = 1/(1+0.48) → 25*0.67567.
	assert_almost_eq(AIBuildingEffects.troops_per_recruit_score(1.0, 1.0, 4, w),
		25.0 / 1.48, 0.001)


# ------------------------------------------------------------------
#  Descuento de coste y oro por carta
# ------------------------------------------------------------------

func test_build_cost_modifier_by_phase() -> void:
	var w := _w()   # early=0.5, mid=1.5, late=1.0
	assert_almost_eq(AIBuildingEffects.build_cost_modifier_score(10.0, AIGamePhase.Phase.EARLY, w), 5.0, 0.001)
	assert_almost_eq(AIBuildingEffects.build_cost_modifier_score(10.0, AIGamePhase.Phase.MID, w), 15.0, 0.001)
	assert_almost_eq(AIBuildingEffects.build_cost_modifier_score(10.0, AIGamePhase.Phase.LATE, w), 10.0, 0.001)


func test_gold_on_card_score() -> void:
	var w := _w()   # bce_gold_on_card=0.5
	assert_almost_eq(AIBuildingEffects.gold_on_card_score(20.0, 1.0, w), 10.0, 0.001)
