extends GutTest

## Tests de AIBuildingEffects: puntuación de efectos de edificio.
##
## Las aserciones expresan la FÓRMULA en términos de los campos de peso
## (`2.0 * w.se_flat_gold`), no su resultado numérico (`10.0`). Sigue siendo una
## comprobación real —el test falla si la fórmula cambia— pero deja de romperse
## cuando el optimizador reajusta un default, que es ruido, no información.
##
## Los dos casos dependientes de estado (CARDS_PER_TURN, TROOPS_PER_RECRUIT) se
## prueban con su escalar ya calculado, que es como los llama cada mundo.


func _w() -> HeuristicWeights:
	return HeuristicWeights.new()


# ------------------------------------------------------------------
#  Casos simples de AddStatModifierEffect
# ------------------------------------------------------------------

func test_stat_effect_simple_flat_and_percent() -> void:
	var w := _w()
	# Los planos escalan con el valor y la urgencia del recurso; los porcentuales,
	# además, con la producción actual (un +10% no vale nada sin producción).
	assert_almost_eq(AIBuildingEffects.stat_effect_simple(
		StatModifier.StatType.FLAT_GOLD, 2.0, 0, 0, 0, 1.0, 1.0, 1.0, w),
		2.0 * w.se_flat_gold, 0.001)
	assert_almost_eq(AIBuildingEffects.stat_effect_simple(
		StatModifier.StatType.PERCENT_GOLD, 10.0, 100, 0, 0, 1.0, 1.0, 1.0, w),
		100 * 10.0 / 100.0 * w.se_percent_gold, 0.001)
	assert_almost_eq(AIBuildingEffects.stat_effect_simple(
		StatModifier.StatType.FLAT_FOOD, 3.0, 0, 0, 0, 1.0, 1.0, 1.0, w),
		3.0 * w.se_flat_food, 0.001)
	assert_almost_eq(AIBuildingEffects.stat_effect_simple(
		StatModifier.StatType.PERCENT_FOOD, 10.0, 0, 50, 0, 1.0, 1.0, 1.0, w),
		50 * 10.0 / 100.0 * w.se_percent_food, 0.001)


func test_stat_effect_simple_escala_con_la_urgencia() -> void:
	# La urgencia es lo que hace que el MISMO edificio valga distinto según la
	# situación; sin este caso, un fallo que ignorase gu/fu pasaría desapercibido.
	var w := _w()
	var sin_urgencia := AIBuildingEffects.stat_effect_simple(
		StatModifier.StatType.FLAT_GOLD, 2.0, 0, 0, 0, 1.0, 1.0, 1.0, w)
	var con_urgencia := AIBuildingEffects.stat_effect_simple(
		StatModifier.StatType.FLAT_GOLD, 2.0, 0, 0, 0, 3.0, 1.0, 1.0, w)
	assert_almost_eq(con_urgencia, sin_urgencia * 3.0, 0.001,
		"el oro vale el triple cuando la urgencia de oro es 3")


func test_stat_effect_simple_tiles_draw_and_maintenance() -> void:
	var w := _w()
	assert_almost_eq(AIBuildingEffects.stat_effect_simple(
		StatModifier.StatType.TILE_RESOURCE_GOLD, 2.0, 0, 0, 0, 1.0, 1.0, 1.0, w),
		2.0 * w.se_tile_gold, 0.001)
	assert_almost_eq(AIBuildingEffects.stat_effect_simple(
		StatModifier.StatType.CARD_DRAW_BONUS, 1.0, 0, 0, 0, 1.0, 1.0, 1.0, w),
		1.0 * w.se_card_draw, 0.001)
	# El ahorro de mantenimiento vale en proporción al pool: sin tropas no ahorra nada.
	assert_almost_eq(AIBuildingEffects.stat_effect_simple(
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT, -10.0, 0, 0, 4, 1.0, 1.0, 1.0, w),
		4 * 10.0 * w.se_maint, 0.001)
	assert_almost_eq(AIBuildingEffects.stat_effect_simple(
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT, -10.0, 0, 0, 0, 1.0, 1.0, 1.0, w),
		0.0, 0.001, "sin tropas, reducir su mantenimiento no aporta")


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
	var w := _w()
	# Una carta por turno vale por los turnos que QUEDAN. Lejos de ganar, el
	# horizonte es máximo; en el umbral de victoria, mínimo.
	var lejos := w.se_cpt_base + w.se_cpt_horizon_hi * w.se_cpt_horizon_scale
	var cerca := w.se_cpt_base + w.se_cpt_horizon_lo * w.se_cpt_horizon_scale
	assert_almost_eq(AIBuildingEffects.cards_per_turn_score(1.0, 0.0, w), lejos, 0.001)
	assert_almost_eq(AIBuildingEffects.cards_per_turn_score(
		1.0, w.se_cpt_share_target, w), cerca, 0.001)
	assert_gt(lejos, cerca, "el flujo vale más cuanto más partida queda")


func test_cards_per_turn_es_decreciente_con_la_cuota() -> void:
	# La regla es la MONOTONÍA, no el valor exacto en el punto medio: fijar ese
	# número obligaría a recalcularlo a mano en cada reajuste de pesos.
	var w := _w()
	var objetivo := w.se_cpt_share_target
	var previo := INF
	for frac in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var actual := AIBuildingEffects.cards_per_turn_score(1.0, objetivo * frac, w)
		assert_lt(actual, previo, "a más cuota propia, menos horizonte")
		previo = actual


# ------------------------------------------------------------------
#  Tropas por reclutamiento (rendimiento decreciente)
# ------------------------------------------------------------------

func test_troops_per_recruit_scales_with_mu_and_decays() -> void:
	var w := _w()
	# Sin bonus previo: base + la parte que aporta la urgencia militar.
	assert_almost_eq(AIBuildingEffects.troops_per_recruit_score(1.0, 1.0, 0, w),
		w.se_tpr_base + w.se_tpr_mu, 0.001)
	# Sin urgencia militar queda solo la base.
	assert_almost_eq(AIBuildingEffects.troops_per_recruit_score(1.0, 0.0, 0, w),
		w.se_tpr_base, 0.001)
	# Con bonus ya acumulado, rendimiento decreciente.
	var acumulado := 4
	assert_almost_eq(AIBuildingEffects.troops_per_recruit_score(1.0, 1.0, acumulado, w),
		(w.se_tpr_base + w.se_tpr_mu) / (1.0 + acumulado * w.se_tpr_dr_k), 0.001)


func test_troops_per_recruit_decae_monotonamente() -> void:
	# El segundo cuartel debe valer menos que el primero, y el tercero menos aún.
	var w := _w()
	var previo := INF
	for acumulado in [0, 1, 2, 4, 8]:
		var actual := AIBuildingEffects.troops_per_recruit_score(1.0, 1.0, acumulado, w)
		assert_lt(actual, previo, "cada cuartel extra aporta menos que el anterior")
		previo = actual


# ------------------------------------------------------------------
#  Descuento de coste y oro por carta
# ------------------------------------------------------------------

func test_build_cost_modifier_by_phase() -> void:
	var w := _w()
	assert_almost_eq(AIBuildingEffects.build_cost_modifier_score(
		10.0, AIGamePhase.Phase.EARLY, w), 10.0 * w.bce_buildcost_early, 0.001)
	assert_almost_eq(AIBuildingEffects.build_cost_modifier_score(
		10.0, AIGamePhase.Phase.MID, w), 10.0 * w.bce_buildcost_mid, 0.001)
	assert_almost_eq(AIBuildingEffects.build_cost_modifier_score(
		10.0, AIGamePhase.Phase.LATE, w), 10.0 * w.bce_buildcost_late, 0.001)
	# La intención del balance: el descuento vale MÁS en mid, cuando queda mucho
	# por construir y el oro aún aprieta.
	assert_gt(w.bce_buildcost_mid, w.bce_buildcost_early)
	assert_gt(w.bce_buildcost_mid, w.bce_buildcost_late)


func test_gold_on_card_score() -> void:
	var w := _w()
	assert_almost_eq(AIBuildingEffects.gold_on_card_score(20.0, 1.0, w),
		20.0 * w.bce_gold_on_card, 0.001)
	# Y escala con la urgencia de oro, igual que el resto de efectos económicos.
	assert_almost_eq(AIBuildingEffects.gold_on_card_score(20.0, 2.0, w),
		20.0 * w.bce_gold_on_card * 2.0, 0.001)
