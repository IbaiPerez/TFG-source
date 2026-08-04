extends RefCounted
class_name AIShopPolicy

## Política de tienda (comprar / purgar), escrita UNA sola vez
## contra el puerto AIStateView. Antes vivía DUPLICADA:
##   - AIHeuristic.should_buy_shop_item / dynamic_purge_threshold / pick_card_to_remove
##     (mundo vivo, con pesos shop_thresh_* / purge_thresh_* / deck_*).
##   - AIRealEvents._should_buy / _purge_threshold / _pick_weakest_card
##     (snapshot, con 5.0/12.0 y 3.0/10.0 HARDCODEADOS y la banda (deck−5)/15).
##
## Los pesos ya existían: el espejo simplemente no los usaba. Al unificar, el
## snapshot pasa a respetarlos → [CAMBIA COMPORTAMIENTO] en el snapshot.
##
## Sin efectos secundarios: solo decide. Cada mundo aplica el resultado a su manera
## (ShopItem.purchase/purge_card en vivo; mutar emp.deck/gold en el snapshot).


## Umbral mínimo de valor para COMPRAR una carta. Mazo pequeño → comprar casi todo
## lo útil; mazo saturado → solo lo realmente valioso.
static func buy_threshold(view: AIStateView) -> float:
	var w := view.weights()
	return lerpf(w.shop_thresh_small, w.shop_thresh_large, _deck_ratio(view, w))


## ¿Merece la pena comprar esta carta? (no comprueba precio ni oro: eso es del mundo)
static func should_buy(view: AIStateView, card: Card) -> bool:
	if card == null:
		return false
	return AIDeckScorer.score_card_for_deck(view, card) >= buy_threshold(view)


## Umbral por debajo del cual una carta merece ser PURGADA. Mazo pequeño → conservar
## casi todo; mazo grande → purgar hasta utilidad moderada para acelerar el ciclo.
static func purge_threshold(view: AIStateView) -> float:
	var w := view.weights()
	return lerpf(w.purge_thresh_small, w.purge_thresh_large, _deck_ratio(view, w))


## Carta más prescindible de `candidates` (menor valor para el mazo actual).
##
## Protección de expansión: si aún quedan casillas colonizables y solo hay UNA
## ColonizeCard entre las candidatas, se excluye de la selección, para que un evento
## de eliminación no bloquee el crecimiento territorial. Si todas las candidatas eran
## ColonizeCards protegidas (o ya no queda nada que colonizar), se elige la peor sin
## protección.
static func pick_weakest(view: AIStateView, candidates: Array[Card]) -> Card:
	if candidates.is_empty():
		return null

	var colonize_count := 0
	for c in candidates:
		if c is ColonizeCard:
			colonize_count += 1
	var protect_colonize := view.colonizable_count() != 0 and colonize_count <= 1

	var worst := _worst_of(view, candidates, protect_colonize)
	if worst == null and protect_colonize:
		# Todas eran ColonizeCards protegidas → repetir sin protección.
		worst = _worst_of(view, candidates, false)
	return worst


static func _worst_of(view: AIStateView, candidates: Array[Card],
		protect_colonize: bool) -> Card:
	var worst: Card = null
	var worst_score := INF
	for card in candidates:
		if protect_colonize and card is ColonizeCard:
			continue
		var s := AIDeckScorer.score_card_for_deck(view, card)
		if s < worst_score:
			worst_score = s
			worst = card
	return worst


## Posición del mazo en la banda [deck_small, deck_large], recortada a [0,1].
static func _deck_ratio(view: AIStateView, w: HeuristicWeights) -> float:
	return clampf((float(view.deck_size()) - w.deck_small) / (w.deck_large - w.deck_small),
		0.0, 1.0)
