extends RefCounted
class_name AIChoiceScorer

## Valoración de una opción (TurnEventChoice) de evento, escrita UNA sola vez
## (refactor C6 §1.6.3) contra el puerto AIStateView. Antes vivía DUPLICADA:
##   - AIHeuristic.score_choice        → con pesos, pero solo 6 ramas de efecto.
##   - AIRealEvents._score_choice      → literales hardcodeados, pero MÁS ramas.
##
## HALLAZGO: no era un caso de "el snapshot aproxima al vivo". Cada mundo cubría
## cosas distintas, así que la unificación es la UNIÓN de ambos:
##   · del VIVO se toma la valoración real de AddCardEffect (AIDeckScorer, ya
##     compartido desde §1.6.5) y las urgencias con fase/pesos;
##   · del ESPEJO se toman las ramas que el vivo no distinguía y trataba como
##     "efecto desconocido": Scaled(Gold|Food)Effect, ColonizeAdjacentEffect,
##     AddToCardPool/UnlockBuilding y los modifiers. Sus literales pasan a pesos
##     (choice_colonize / choice_unlock / choice_modifier), con default = el
##     literal del espejo.
## [CAMBIA COMPORTAMIENTO] en LOS DOS mundos, a propósito: el vivo gana
## discriminación que no tenía y el snapshot gana pesos y fase.


static func score_choice(view: AIStateView, choice: TurnEventChoice) -> float:
	if choice == null:
		return 0.0
	var w := view.weights()
	var score := 0.0

	for effect in choice.effects:
		if effect == null:
			continue

		if effect is GoldEventEffect:
			score += (effect as GoldEventEffect).amount * w.choice_gold * view.gold_urgency()

		elif effect is FoodEventEffect:
			score += (effect as FoodEventEffect).amount * w.choice_food * view.food_urgency()

		elif effect is ScaledGoldEffect:
			var eg := effect as ScaledGoldEffect
			var amt_g := ScaledValue.evaluate(eg.base, eg.turn_factor, eg.gpt_percent,
				view.turn_number(), view.gold_per_turn())
			score += amt_g * w.choice_gold * view.gold_urgency()

		elif effect is ScaledFoodEffect:
			var ef := effect as ScaledFoodEffect
			var amt_f := ScaledValue.evaluate(ef.base, ef.turn_factor, ef.food_percent,
				view.turn_number(), view.food())
			score += amt_f * w.choice_food * view.food_urgency()

		elif effect is AddCardEffect:
			# Valor REAL de la carta para el mazo (el espejo usaba un plano 8.0).
			score += AIDeckScorer.score_card_for_deck(view, (effect as AddCardEffect).card)

		elif effect is AddRandomPoolCardEffect:
			# Carta aleatoria del pool: valor medio estimado.
			score += w.choice_random_pool

		elif effect is AddToCardPoolEffect or effect is UnlockBuildingEffect:
			# Desbloqueos: amplían el espacio de acciones futuras.
			score += w.choice_unlock

		elif effect is UrbanizeToMegalopolisEffect:
			# Megalópolis: +slots de edificio y desbloquea edificios de ciudad.
			score += w.choice_megalopolis

		elif effect is ColonizeAdjacentEffect:
			score += w.choice_colonize

		elif effect is RemoveCardEventEffect:
			# Adelgazar el mazo: beneficio proporcional a lo saturado que esté.
			score += deck_thinning_value(view)

		elif effect is ScaledStatModifierEffect or effect is ScaledBuildCostModifierEffect \
				or effect is ApplyModifierEffect:
			score += w.choice_modifier

		else:
			score += w.choice_unknown

	# Penalización leve por tener coste (ya verificado asequible, pero restringe).
	if choice.cost != null:
		score -= w.choice_cost_penalty

	return score


## Valor de adelgazar el mazo en una carta, proporcional a su tamaño. Mazo pequeño:
## el ciclo ya es rápido y purgar aporta poco; mazo grande: purgar acelera el acceso
## a las cartas clave. Unifica la versión con pesos del vivo con el
## `clampf((deck−10)·0.5, 0, 8)` que usaba el espejo.
static func deck_thinning_value(view: AIStateView) -> float:
	var w := view.weights()
	return lerpf(w.deck_thin_small, w.deck_thin_large, _deck_ratio(view, w))


## Posición del mazo en la banda [deck_small, deck_large], recortada a [0,1].
## Compartida por el valor de adelgazamiento y por los umbrales de tienda.
static func _deck_ratio(view: AIStateView, w: HeuristicWeights) -> float:
	return clampf((float(view.deck_size()) - w.deck_small) / (w.deck_large - w.deck_small),
		0.0, 1.0)
