extends RefCounted
class_name AIEventResolver

## Resuelve TurnEvents y ShopEvents headless para la IA, replicando la
## lógica que TurnEventPanel y ShopPanel aplican al jugador pero sin abrir
## ningún panel.
##
## Versión 2 (Fase B): todas las decisiones que requieren criterio usan
## AIHeuristic en lugar de azar:
##  - TurnEvent: se puntúa cada choice y se elige la de mayor valor esperado.
##  - Eliminación de carta (card_input): se elimina la más prescindible
##    según score_card_for_deck (pick_card_to_remove).
##  - ShopEvent: se compran las cartas con score >= umbral y se purgan
##    las más débiles si el coste es asequible.
##  - Tile input: sigue siendo random (no hay heurística de posición aún).
##
## Marca el evento como `unique` en stats.used_unique_events si aplica.


## Umbral de purga de tienda: ahora es dinámico (ver AIHeuristic.dynamic_purge_threshold).
## La constante ya no se usa; se mantiene como referencia de diseño.
## const PURGE_SCORE_THRESHOLD := 8.0  # ← reemplazado por umbral dinámico


## Punto de entrada. Llama desde AIController tras evaluar el evento.
static func resolve(event: TurnEvent, context: EventContext,
		rng: RandomNumberGenerator, manager: TurnEventManager) -> void:
	if event == null or context == null:
		return

	# Contexto mínimo para la heurística: solo necesita stats y los frentes
	# globales (BattleFront.get_active_instances() es estático, no requiere bfm).
	var hctx := AITurnContext.new()
	hctx.stats = context.stats
	# Calcular tiles colonizables reales para que score_card_for_deck y
	# pick_card_to_remove tomen decisiones informadas sobre ColonizeCard.
	# Sin esto, colonizable_tiles_count queda en -1 (unknown) y ColonizeCard
	# puede ser eliminada erróneamente por eventos en fase LATE.
	if context.stats != null and context.stats.empire != null:
		var adj := AdjacentCondition.new()
		adj.empire = context.stats.empire
		hctx.colonizable_tiles_count = adj.valid_targets().size()

	if event is ShopEvent:
		_resolve_shop_event(event as ShopEvent, context.stats, hctx)
		_mark_unique_if_applicable(event, context.stats)
		GameLogger.debug("    [IA-Event] resuelto ShopEvent '%s'%s" % [event.id,
			" (marcado unique)" if event.unique else ""])
		return

	_resolve_turn_event(event, context, rng, manager, hctx)


# ============================================================
#  TurnEvent (normal)
# ============================================================

static func _resolve_turn_event(event: TurnEvent, context: EventContext,
		rng: RandomNumberGenerator, manager: TurnEventManager,
		hctx: AITurnContext) -> void:
	# 1. Filtrar choices affordable (igual que el panel).
	var available: Array[TurnEventChoice] = []
	for c in event.choices:
		if c != null and c.is_affordable(context):
			available.append(c)

	# 2. Añadir skip choice si el evento lo permite.
	var skip_choice: TurnEventChoice = null
	if event.allow_skip:
		skip_choice = TurnEventChoice.new()
		skip_choice.label = "No hacer nada"
		skip_choice.description = "Declinar el evento."
		available.append(skip_choice)

	# 3. Si no hay nada elegible, marcar unique y salir.
	if available.is_empty():
		_mark_unique_if_applicable(event, context.stats)
		return

	# 4. Elegir la opción con mayor valor esperado.
	#    Skip tiene score 0 implícito (sin efectos). Si ninguna opción
	#    supera 0, se elige skip (o la menos mala).
	var picked: TurnEventChoice = available[0]
	var best_score := AIHeuristic.score_choice(available[0], hctx)
	for i in range(1, available.size()):
		var s := AIHeuristic.score_choice(available[i], hctx)
		if s > best_score:
			best_score = s
			picked = available[i]

	var choice_label: String = picked.label if picked.label != "" else "<sin etiqueta>"

	# 5. Despachar según el tipo de input que requiera.
	if picked.needs_tile_input():
		_execute_choice_with_tile_input(event, picked, context, rng)
		GameLogger.debug("    [IA-Event] '%s' → choice '%s' (tile input)%s" % [event.id,
			choice_label, " | marcado unique" if event.unique else ""])
	elif picked.needs_player_input():
		_execute_choice_with_card_input(event, picked, context, hctx)
		GameLogger.debug("    [IA-Event] '%s' → choice '%s' (card input)%s" % [event.id,
			choice_label, " | marcado unique" if event.unique else ""])
	else:
		manager.resolve(event, picked, context)
		GameLogger.debug("    [IA-Event] '%s' → choice '%s'%s" % [event.id, choice_label,
			" | marcado unique" if event.unique else ""])


## Replica TurnEventPanel._on_tile_selected: paga el coste, ejecuta el
## tile_effect con la tile elegida random, ejecuta los demás effects que
## no requieran tile input, y marca el evento como unique.
static func _execute_choice_with_tile_input(event: TurnEvent, choice: TurnEventChoice,
		context: EventContext, rng: RandomNumberGenerator) -> void:
	if choice.cost != null:
		choice.cost.pay(context)

	var tile_effect: TurnEventEffect = choice.get_tile_effect()
	if tile_effect != null and tile_effect.has_method("get_eligible_tiles"):
		var eligible: Array = tile_effect.get_eligible_tiles(context)
		if not eligible.is_empty():
			var picked_tile = eligible[rng.randi_range(0, eligible.size() - 1)]
			if tile_effect.has_method("execute_with_tile"):
				tile_effect.execute_with_tile(picked_tile, context.stats)

	# Ejecutar los effects restantes (los que no son de tile input).
	for effect in choice.effects:
		if effect != null and not effect.needs_tile_input():
			effect.execute(context)

	_mark_unique_if_applicable(event, context.stats)


## Replica TurnEventPanel._on_card_selected: identifica el primer
## RemoveCardEventEffect en effects, pide candidatas, elige la más
## prescindible con AIHeuristic y ejecuta los effects.
static func _execute_choice_with_card_input(event: TurnEvent, choice: TurnEventChoice,
		context: EventContext, hctx: AITurnContext) -> void:
	# Buscar el effect que requiere selección de carta.
	var candidates: Array[Card] = []
	for effect in choice.effects:
		if effect != null and effect.needs_player_input() and effect is RemoveCardEventEffect:
			candidates = effect.get_candidates(context.stats)
			break

	if candidates.is_empty():
		_mark_unique_if_applicable(event, context.stats)
		return

	# Elegir la carta con menor valor para el mazo actual (la más prescindible).
	var chosen_card := AIHeuristic.pick_card_to_remove(candidates, hctx)

	# Ejecutar todos los effects, pasando la carta elegida a los que la pidan.
	for i in choice.effects.size():
		var effect: TurnEventEffect = choice.effects[i]
		if effect == null:
			continue
		if effect.needs_player_input():
			effect.execute(context, chosen_card)
		else:
			effect.execute(context)

	_mark_unique_if_applicable(event, context.stats)


# ============================================================
#  ShopEvent
# ============================================================

static func _resolve_shop_event(event: ShopEvent, stats: Stats,
		hctx: AITurnContext) -> void:
	var config := event.generate_shop(stats)
	if config == null:
		return

	# --- Compras ---
	# Comprar un item si la carta tiene valor suficiente para el estado actual.
	for item in config.items.duplicate():
		if item == null:
			continue
		if not item.is_available():
			continue
		if not item.can_afford(stats.total_gold):
			continue
		if AIHeuristic.should_buy_shop_item(item, hctx):
			item.purchase(stats)
			GameLogger.debug("    [IA-Shop] compra carta '%s' (precio %d)" % [
				item.card.id if item.card else "?", item.price])

	# --- Purga ---
	# Eliminar la carta más débil del mazo si su valor cae por debajo del
	# umbral y podemos permitir el coste. Se purga hasta agotar los usos
	# disponibles o hasta que el peor sea suficientemente bueno.
	if not config.allow_purge:
		return

	var purgeable: Array[Card] = []
	purgeable.append_array(stats.draw_pile.cards)
	purgeable.append_array(stats.discard_pile.cards)

	while not purgeable.is_empty() and config.can_purge(stats.total_gold):
		var worst := AIHeuristic.pick_card_to_remove(purgeable, hctx)
		if worst == null:
			break
		var worst_score := AIHeuristic.score_card_for_deck(worst, hctx)
		if worst_score >= AIHeuristic.dynamic_purge_threshold(hctx):
			break  # todas las cartas son suficientemente valiosas para el mazo actual
		if config.purge_card(worst, stats):
			GameLogger.debug("    [IA-Shop] purga carta '%s' (score %.1f)" % [
				worst.id if worst else "?", worst_score])
			purgeable.erase(worst)
		else:
			break


# ============================================================
#  Helpers
# ============================================================

static func _mark_unique_if_applicable(event: TurnEvent, stats: Stats) -> void:
	if event.unique and event.id not in stats.used_unique_events:
		stats.used_unique_events.append(event.id)
