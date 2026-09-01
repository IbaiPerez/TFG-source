extends RefCounted
class_name AIHeuristic

## Evaluador heurístico de AIPlayOption para el AIController: punto de entrada
## y despacho por tipo de jugada.
##
## Las FÓRMULAS de scoring no están aquí. Se escriben una sola vez en
## AIMoveScorer, contra el puerto AIStateView; lo que queda son wrappers finos
## que aplican las guardas del mundo vivo y construyen la LiveStateView.
## Las señales de urgencia y su caché viven en [AIDecisionCache], y los
## recorridos sobre el mundo vivo en [AILiveFacts].
##
## PASS tiene score 0.0 por convenio. Cualquier acción con score positivo se
## prefiere sobre pasar. Acciones que empeoran el estado (edificios con stats
## negativos en situación de crisis) pueden puntuar negativo, con lo que PASS
## gana y la IA no las ejecuta.

## Punto de entrada principal. Devuelve el score de una opción en el contexto
## actual. Score más alto = más deseable.
static func score_option(option: AIPlayOption, ctx: AITurnContext) -> float:
	if option == null or option.is_pass:
		return 0.0

	var phase := AIGamePhase.detect(ctx.stats, ctx.total_map_tiles, ctx.get_weights())

	if option is AIBuildOption:
		return _score_build(option as AIBuildOption, ctx, phase)
	if option is AIUpgradeBuildingOption:
		return _score_upgrade(option as AIUpgradeBuildingOption, ctx, phase)
	if option is AIRecruitOption:
		return _score_recruit(option as AIRecruitOption, ctx, phase)
	if option is AIOpenFrontOption:
		return _score_open_front(option as AIOpenFrontOption, ctx, phase)
	if option is AITacticOption:
		return _score_tactic(option as AITacticOption, ctx, phase)
	if option is AIDrawCardOption:
		return _score_draw(option as AIDrawCardOption, ctx)
	if option is AIRecoverOption:
		return _score_recover(option as AIRecoverOption, ctx)

	# Opciones simples: ColonizeCard, GenerateGoldCard,
	# ChangeLocationTypeCard, DirectBuildCard
	return _score_simple(option, ctx, phase)



# ---------------------------------------------------------------------------
# Scoring por tipo de opción
# ---------------------------------------------------------------------------

static func _score_build(option: AIBuildOption, ctx: AITurnContext,
		_phase: AIGamePhase.Phase) -> float:
	# Portado al scorer compartido. El tie-breaker por casilla se omite si
	# no hay target (tile null).
	if option.building == null:
		return 0.0
	var tile := option.targets[0] as Tile if not option.targets.is_empty() else null
	return AIMoveScorer.score_build(LiveStateView.new(ctx), option.building, tile)


static func _score_upgrade(option: AIUpgradeBuildingOption, ctx: AITurnContext,
		_phase: AIGamePhase.Phase) -> float:
	# Portado al scorer compartido.
	if option.old_building == null or option.new_building == null:
		return 0.0
	return AIMoveScorer.score_upgrade(
		LiveStateView.new(ctx), option.old_building, option.new_building)


static func _score_recruit(option: AIRecruitOption, ctx: AITurnContext,
		_phase: AIGamePhase.Phase) -> float:
	# Portado al scorer compartido.
	if option.troop == null:
		return 0.0
	return AIMoveScorer.score_recruit(LiveStateView.new(ctx), option.troop)




static func _score_open_front(option: AIOpenFrontOption, ctx: AITurnContext,
		_phase: AIGamePhase.Phase) -> float:
	# Portado al scorer compartido. El veto por 0 tropas libres vive dentro
	# del scorer; la ganabilidad/valor-origen (con sus divergencias) los resuelve la vista.
	if option.enemy_tile == null:
		return 0.0
	return AIMoveScorer.score_open_front(
		LiveStateView.new(ctx), option.enemy_tile, option.source_tile)


static func _score_tactic(option: AITacticOption, ctx: AITurnContext,
		_phase: AIGamePhase.Phase) -> float:
	# Portado al scorer compartido. El wrapper descompone el BattleFront de
	# la opción (tropas propias, marcador, umbral, casilla relevante: ATK mira la tile
	# enemiga, DEF la propia).
	if option.front == null:
		return 0.0
	var is_attacker := option.front.attacker_empire == ctx.stats.empire
	var own_troops: Array[Troop] = option.front.attacker_troops \
		if is_attacker else option.front.defender_troops
	var relevant_tile: Tile = option.front.defender_tile \
		if is_attacker else option.front.attacker_tile
	var ai_marker := option.front.marker if is_attacker else -option.front.marker
	return AIMoveScorer.score_tactic(LiveStateView.new(ctx), option.card as TacticCard,
		own_troops, ai_marker, option.front.get_current_threshold(), relevant_tile)


static func _score_draw(option: AIDrawCardOption, ctx: AITurnContext) -> float:
	return AIMoveScorer.score_card_draw(LiveStateView.new(ctx), option.amount)


## Valora recuperar una carta concreta del played_pile.
## La carta recuperada vuelve a la mano y puede jugarse en la misma iteración.
static func _score_recover(option: AIRecoverOption, ctx: AITurnContext) -> float:
	if option.chosen_card == null:
		return 0.0
	return score_card_for_deck(option.chosen_card, ctx)


# ---------------------------------------------------------------------------
# Opciones simples (card-type dispatch)
# ---------------------------------------------------------------------------

static func _score_simple(option: AIPlayOption, ctx: AITurnContext,
		phase: AIGamePhase.Phase) -> float:
	var card := option.card
	if card == null:
		return 0.0

	if card is ColonizeCard:
		return _score_colonize(option, ctx, phase)

	if card is GenerateGoldCard:
		# Oro inmediato vale menos que gold_per_turn (es one-shot).
		return AIMoveScorer.score_generate_gold(
			LiveStateView.new(ctx), (card as GenerateGoldCard).amount)

	if card is ChangeLocationTypeCard:
		return _score_change_location(option, ctx, phase)

	if card is DirectBuildCard:
		return _score_direct_build(option, ctx, phase)

	return 1.0  # tipo de carta desconocido: valor neutro-positivo mínimo


## Colonizar no tiene coste de food_consumption al pasar de Uncolonized a Village
## (ambos tienen food_consumption = 0). El delta es exactamente el food_production
## del recurso natural. Por eso usamos tile.food_production directamente.
static func _score_colonize(option: AIPlayOption, ctx: AITurnContext,
		_phase: AIGamePhase.Phase) -> float:
	# Portado al scorer compartido. El wrapper conserva los guardas
	# (hay target y es Tile) y construye la vista viva; la fase la calcula la vista.
	if option.targets.is_empty():
		return 0.0
	var tile := option.targets[0] as Tile
	if tile == null:
		return 0.0
	return AIMoveScorer.score_colonize(LiveStateView.new(ctx), tile)




## El delta real de food_consumption se lee de los recursos, no está hardcodeado.
static func _score_change_location(option: AIPlayOption, ctx: AITurnContext,
		_phase: AIGamePhase.Phase) -> float:
	# Portado al scorer compartido. La fórmula COMPLETA (penalización por
	# demolición + bonus de recurso mejorado que sobrevive + bonus de desbloqueo) vive
	# en LiveStateView.change_location_adjust.
	if option.targets.is_empty():
		return 0.0
	var tile := option.targets[0] as Tile
	var card := option.card as ChangeLocationTypeCard
	if tile == null or card == null or card.location_type == null or tile.location == null:
		return 0.0
	return AIMoveScorer.score_change_location(LiveStateView.new(ctx), tile, card.location_type)


static func _score_direct_build(option: AIPlayOption, ctx: AITurnContext,
		_phase: AIGamePhase.Phase) -> float:
	# Portado al scorer compartido: mismo scorer que BUILD, sin casilla
	# concreta (tile null → sin tie-breaker), igual que el cuerpo original.
	var card := option.card as DirectBuildCard
	if card == null or card.buildings.is_empty() or card.buildings[0] == null:
		return 0.0
	return AIMoveScorer.score_build(LiveStateView.new(ctx), card.buildings[0], null)


# ---------------------------------------------------------------------------
# Decisiones de eventos: mazo y tienda
# ---------------------------------------------------------------------------

## Devuelve el valor de tener esta carta en el mazo dado el estado actual.
## Usado para decidir qué comprar en tienda, qué purgar y qué eliminar
## cuando un evento pide eliminar una carta.
static func score_card_for_deck(card: Card, ctx: AITurnContext) -> float:
	# Fórmula unificada contra el puerto: AIDeckScorer la escribe una vez;
	# LiveStateView reproduce exactamente los helpers vivos (urgencias cacheadas de la
	# decisión, conteos de tiles) → byte-idéntico a la versión inline anterior.
	return AIDeckScorer.score_card_for_deck(LiveStateView.new(ctx), card)


## De entre los candidatos, devuelve la carta con menor valor para el mazo
## actual (la más prescindible, la que se debería eliminar/purgear primero).
##
## Protección de expansión: si quedan tiles colonizables (avail != 0) y
## solo hay una ColonizeCard entre los candidatos, esa carta se excluye de
## la selección. Así el empire siempre conserva al menos una ColonizeCard
## cuando el mapa todavía no está completo, evitando que eventos de
## eliminación bloqueen el crecimiento territorial.
## Si todos los candidatos son ColonizeCards (o avail == 0), se elige la
## peor sin protección (fallback normal).
static func pick_card_to_remove(candidates: Array[Card],
		ctx: AITurnContext) -> Card:
	# Política compartida con el snapshot.
	return AIShopPolicy.pick_weakest(LiveStateView.new(ctx), candidates)


## Evalúa el valor esperado de una TurnEventChoice sumando el aporte de
## cada efecto que la compone. Los efectos con input del jugador
## (RemoveCardEventEffect) se puntúan con un valor fijo positivo: asumimos
## que la IA elegirá la carta más prescindible (pick_card_to_remove), así
## que la elección es beneficiosa.
static func score_choice(choice: TurnEventChoice, ctx: AITurnContext) -> float:
	# Fórmula unificada contra el puerto. Ahora distingue efectos que
	# antes caían en "desconocido": escalados, colonización y desbloqueos.
	return AIChoiceScorer.score_choice(LiveStateView.new(ctx), choice)


## Decide si la IA debe comprar un item de tienda.
## El umbral escala con el tamaño del mazo: con el mazo pequeño casi todo
## vale la pena añadir; con el mazo saturado solo se compra lo realmente bueno.
static func should_buy_shop_item(item: ShopItem, ctx: AITurnContext) -> bool:
	if item == null or item.card == null:
		return false
	# Política compartida con el snapshot.
	return AIShopPolicy.should_buy(LiveStateView.new(ctx), item.card)



# ---------------------------------------------------------------------------
# Efectos de edificio
# ---------------------------------------------------------------------------

## Puntúa el array de BuildingEffect de un edificio traduciéndolo a las
## mismas unidades que el resto de señales de urgencia.
## Cubre: AddStatModifierEffect, AddBuildCostModifierEffect,
##        AddCardToDeckEffect y GoldOnCard.
static func _score_building_effects(effects: Array[BuildingEffect],
		ctx: AITurnContext, phase: AIGamePhase.Phase) -> float:
	if effects.is_empty():
		return 0.0
	var w := ctx.get_weights()
	var score := 0.0
	var gu := AIDecisionCache._gold_urgency(ctx.stats.gold_per_turn, phase, w)
	var fu := AIDecisionCache._food_urgency(ctx.stats.food, phase, w)
	var mu := AIDecisionCache._military_urgency(ctx, phase)
	for effect in effects:
		if effect == null:
			continue
		if effect is AddStatModifierEffect:
			score += _score_stat_effect(effect as AddStatModifierEffect, ctx, gu, fu, mu)
		elif effect is AddBuildCostModifierEffect:
			# Descuento en todas las construcciones futuras: más valioso en mid.
			score += AIBuildingEffects.build_cost_modifier_score(
				(effect as AddBuildCostModifierEffect).percent, phase, w)
		elif effect is AddCardToDeckEffect:
			var card_added := (effect as AddCardToDeckEffect).card
			if card_added != null:
				score += score_card_for_deck(card_added, ctx)
		elif effect is GoldOnCard:
			# Frecuencia desconocida: estimación conservadora (~3 plays/turno).
			score += AIBuildingEffects.gold_on_card_score(
				(effect as GoldOnCard).gold_reward, gu, w)
	return score


## Traduce un AddStatModifierEffect a un score usando las escalas de urgencia.
static func _score_stat_effect(effect: AddStatModifierEffect,
		ctx: AITurnContext, gu: float, fu: float, mu: float) -> float:
	var w := ctx.get_weights()
	var v := effect.value
	# Los dos casos dependientes de estado calculan su escalar SOLO en su rama; el
	# resto delega en el helper puro compartido (AIBuildingEffects, con el snapshot).
	match effect.stat_type:
		StatModifier.StatType.CARDS_PER_TURN:
			# Horizon estima los turnos restantes: cerca de la victoria (my_share → 0.70)
			# el horizonte cae (la carta ya no tiene tiempo de componer).
			var my_share_h := 0.0
			if ctx.stats.empire != null and ctx.world_view != null:
				var rival_h := ctx.world_view.get_rival_view()
				if rival_h != null and rival_h.empire != null:
					var rival_tiles_h := rival_h.empire.controlled_tiles.size()
					var colonizable_h := maxi(ctx.colonizable_tiles_count, 0)
					var total_h := maxi(
						ctx.stats.empire.controlled_tiles.size() + rival_tiles_h \
						+ colonizable_h, 1)
					my_share_h = float(ctx.stats.empire.controlled_tiles.size()) \
						/ float(total_h)
			return AIBuildingEffects.cards_per_turn_score(v, my_share_h, w)
		StatModifier.StatType.TROOPS_PER_RECRUIT:
			return AIBuildingEffects.troops_per_recruit_score(v, mu,
				AILiveFacts._current_troops_per_recruit_bonus(ctx), w)
		_:
			return AIBuildingEffects.stat_effect_simple(effect.stat_type, v,
				ctx.stats.gold_per_turn, ctx.stats.food, ctx.stats.troop_pool.size(),
				gu, fu, mu, w)
