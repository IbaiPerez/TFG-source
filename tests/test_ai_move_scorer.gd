extends GutTest

## Tests de AIMoveScorer: los scorers de jugada escritos UNA vez contra el puerto
## AIStateView (refactor C4 §1.3.g). Se usa una vista FALSA (stub) para probar los
## scorers de forma aislada del estado vivo/snapshot. La paridad real entre mundos la
## cubren test_ai_heuristic* (vivo) y test_ai_real_eval_strong (snapshot).
##
## Portados hasta ahora: GENERATE_GOLD, CARD_DRAW.


## Vista mínima parametrizable para aislar los scorers de la representación de estado.
class _FakeView extends AIStateView:
	var w: HeuristicWeights
	var gpt: int
	var deck: int
	var ph: AIGamePhase.Phase
	func weights() -> HeuristicWeights: return w
	func gold_per_turn() -> int: return gpt
	func phase() -> AIGamePhase.Phase: return ph
	func deck_urgency_size() -> int: return deck


func _view(gpt: int, ph: AIGamePhase.Phase, deck: int) -> _FakeView:
	var v := _FakeView.new()
	v.w = HeuristicWeights.new()
	v.gpt = gpt
	v.deck = deck
	v.ph = ph
	return v


func test_generate_gold_matches_formula_and_scales() -> void:
	var v := _view(300, AIGamePhase.Phase.MID, 10)
	var w := v.w
	var expected := 100.0 * w.simple_gold_weight \
		* AIUrgency.gold_urgency(300, AIGamePhase.Phase.MID, w)
	assert_almost_eq(AIMoveScorer.score_generate_gold(v, 100), expected, 0.001)
	# Más oro inmediato puntúa más.
	assert_gt(AIMoveScorer.score_generate_gold(_view(300, AIGamePhase.Phase.MID, 10), 200),
		AIMoveScorer.score_generate_gold(_view(300, AIGamePhase.Phase.MID, 10), 20))


func test_card_draw_matches_formula_and_deck_urgency() -> void:
	var v := _view(0, AIGamePhase.Phase.MID, 2)
	var w := v.w
	var expected := 3.0 * w.draw_weight * AIUrgency.deck_urgency(2, w)
	assert_almost_eq(AIMoveScorer.score_card_draw(v, 3), expected, 0.001)
	# Mazo pequeño (urgencia de robo alta) puntúa más que mazo grande, igual cantidad.
	assert_gt(AIMoveScorer.score_card_draw(_view(0, AIGamePhase.Phase.MID, 2), 3),
		AIMoveScorer.score_card_draw(_view(0, AIGamePhase.Phase.MID, 20), 3))
