extends GutTest

## Tests de AIDeckScorer: la valoración de carta para el mazo escrita UNA vez contra
## el puerto AIStateView (refactor C6 §1.6.5). Se usa una vista FALSA (stub) para
## probar la fórmula aislada de la representación de estado. La paridad byte-idéntica
## con el mundo vivo la cubre test_ai_heuristic* (a través del wrapper
## AIHeuristic.score_card_for_deck).


## Vista mínima parametrizable. Devuelve constantes para cada primitiva que el scorer
## consulta, de modo que cada test controla exactamente las entradas de la fórmula.
class _FakeView extends AIStateView:
	var w: HeuristicWeights
	var gu: float = 1.0
	var fu: float = 1.0
	var mu: float = 1.0
	var exp: float = 0.0
	var same_type: int = 1
	var colonizable: int = 0
	var upgradeable: int = 0
	var slots: int = 0
	var clt_targets: int = 0
	var food_val: int = 100
	var deck: int = 0
	var pool: Array[Troop] = []
	var recoverable: Array[Card] = []
	func weights() -> HeuristicWeights: return w
	func gold_urgency() -> float: return gu
	func food_urgency() -> float: return fu
	func military_urgency() -> float: return mu
	func expansion_factor() -> float: return exp
	func same_type_card_count(_card: Card) -> int: return same_type
	func colonizable_count() -> int: return colonizable
	func upgradeable_count() -> int: return upgradeable
	func buildable_slots() -> int: return slots
	func change_location_target_count(_target_type: int) -> int: return clt_targets
	func food() -> int: return food_val
	func deck_size() -> int: return deck
	func troop_pool() -> Array[Troop]: return pool
	func recoverable_cards() -> Array[Card]: return recoverable


func _view() -> _FakeView:
	var v := _FakeView.new()
	v.w = HeuristicWeights.new()
	return v


# ------------------------------------------------------------------
#  GenerateGold + saturación por tipo
# ------------------------------------------------------------------

func test_generate_gold_matches_formula() -> void:
	var v := _view()
	var card := GenerateGoldCard.new()
	card.amount = 100
	var expected := 100 * v.w.scd_gold_weight * 1.0 * 1.0
	assert_almost_eq(AIDeckScorer.score_card_for_deck(v, card), expected, 0.001)


func test_type_saturation_halves_second_copy() -> void:
	var v := _view()
	v.same_type = 2   # sat = clampf(0.5, type_sat_min, 1.0) = 0.5
	var card := GenerateGoldCard.new()
	card.amount = 100
	var expected := 100 * v.w.scd_gold_weight * 1.0 * 0.5
	assert_almost_eq(AIDeckScorer.score_card_for_deck(v, card), expected, 0.001)


func test_null_card_scores_zero() -> void:
	assert_almost_eq(AIDeckScorer.score_card_for_deck(_view(), null), 0.0, 0.001)


# ------------------------------------------------------------------
#  Ramas con recorrido de tiles
# ------------------------------------------------------------------

func test_colonize_empty_vs_available() -> void:
	var v := _view()
	var card := ColonizeCard.new()
	v.colonizable = 0
	assert_almost_eq(AIDeckScorer.score_card_for_deck(v, card), v.w.scd_colonize_empty, 0.001)
	v.colonizable = 3
	v.exp = 1.0   # lerpf(lo, hi, 1.0) = hi
	assert_almost_eq(AIDeckScorer.score_card_for_deck(v, card), v.w.scd_colonize_hi, 0.001)


func test_build_none_vs_slots() -> void:
	var v := _view()
	var card := BuildCard.new()
	v.slots = 0
	assert_almost_eq(AIDeckScorer.score_card_for_deck(v, card), v.w.scd_build_none, 0.001)
	v.slots = 999   # ratio satura a 1.0 → hi
	assert_almost_eq(AIDeckScorer.score_card_for_deck(v, card), v.w.scd_build_hi, 0.001)


func test_change_location_no_targets_is_invalid() -> void:
	var v := _view()
	var card := ChangeLocationTypeCard.new()
	card.location_type = LocationType.new()
	card.location_type.type = Tile.location_type.Town
	card.location_type.food_consumption = 0
	v.clt_targets = 0
	assert_almost_eq(AIDeckScorer.score_card_for_deck(v, card), v.w.scd_clt_invalid, 0.001)


# ------------------------------------------------------------------
#  Recruit (satura con el pool) + RecoverCard (recursión)
# ------------------------------------------------------------------

func test_recruit_scales_with_military_urgency() -> void:
	var v := _view()
	var card := RecruitCard.new()
	v.mu = 2.0
	var troop_sat := 1.0 / (1.0 + 0 * v.w.recruit_saturation_k)   # pool vacío → 1.0
	var expected := (v.w.scd_recruit_base + 2.0 * v.w.scd_recruit_mu) * troop_sat
	assert_almost_eq(AIDeckScorer.score_card_for_deck(v, card), expected, 0.001)


func test_recover_takes_best_recoverable() -> void:
	var v := _view()
	var gold := GenerateGoldCard.new()
	gold.amount = 100
	v.recoverable = [gold]
	var best := 100 * v.w.scd_gold_weight   # score de la mejor recuperable (gu=sat=1)
	var expected := clampf(best * v.w.scd_recover_frac, v.w.scd_recover_lo, v.w.scd_recover_hi)
	assert_almost_eq(AIDeckScorer.score_card_for_deck(v, RecoverCard.new()), expected, 0.001)
