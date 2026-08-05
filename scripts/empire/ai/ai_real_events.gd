extends RefCounted
class_name AIRealEvents

## Chance node de eventos de turno para la simulación MCTS.
##
## Ejecuta, SOBRE EL SNAPSHOT (AIRealState) y desacoplado del bus global `Events`,
## el pipeline de eventos del juego: TurnEventManager (curva de probabilidad +
## pesos por categoría + prioridad CORE), evaluación de condiciones, selección de
## choice y aplicación de efectos + costes.
##
## Casi nada aquí está escrito dos veces:
##   · CONDICIONES: se evalúan las clases REALES sobre un EventContext construido
##     con `EventContext.from_snapshot`.
##   · CHOICE y TIENDA: AIChoiceScorer / AIShopPolicy, compartidos con el mundo
##     vivo a través del puerto AIStateView.
##   · VALOR DE CARTA: AIDeckScorer, también compartido.
## Lo que SIGUE siendo propio del snapshot es la APLICACIÓN de efectos de casilla
## (`_apply_colonize_adjacent`, `_apply_urbanize_megalopolis`): los efectos reales
## mutan vía el bus `Events`, que en vivo dispararía el TilesTracker y corrompería
## la partida, y además difieren en el RNG (global `pick_random` vs el inyectado y
## determinista del MCTS) y en quién elige la casilla.
##
## Se REUSAN además los recursos puros: TurnEvent/Condition/Effect (se leen sus
## parámetros), EventCategoryWeights, UnlockedCardEntry, Comparison.
##
## Es un CHANCE NODE: muestrea su propia tirada por iteración (rng inyectado);
## promediar sobre iteraciones integra la estocasticidad (paridad distribucional,
## no exacta).





## Punto de entrada: evalúa y resuelve (si dispara) el evento de fin de turno de
## `p_owner` sobre el snapshot. Devuelve el TurnEvent disparado o null.
## Espejo de TurnEventManager.evaluate + AIEventResolver.resolve.
## `w` alimenta el valorador de carta unificado que usa la tienda. Es
## opcional: sin pesos explícitos se usa el default cacheado, igual que el MCTS.
static func process_turn_event(state: AIRealState, p_owner: int,
		rng: RandomNumberGenerator, w: HeuristicWeights = null) -> TurnEvent:
	var emp := state.empire(p_owner)
	if emp == null or emp.available_events.is_empty():
		return null

	# Paso 1: probabilidad global de evento.
	if rng.randf() > _event_chance(emp, state.turn_number):
		return null

	# Candidatos disponibles agrupados por categoría. El contexto agregado se
	# construye UNA vez por evaluación y se comparte por todas las condiciones.
	var by_category := _collect_available_by_category(emp, EventContext.from_snapshot(state, p_owner))
	if by_category.is_empty():
		return null

	# Paso 2: prioridad CORE_PROGRESSION.
	var picked: TurnEvent = null
	if by_category.has(EventCategory.Type.CORE_PROGRESSION):
		if rng.randf() < _core_priority_chance(emp):
			picked = _weighted_pick_event(by_category[EventCategory.Type.CORE_PROGRESSION], rng)

	# Paso 3: pickeo ponderado por categoría.
	if picked == null:
		var category := _pick_category(by_category, state.turn_number, emp.category_weights, rng)
		if category < 0:
			return null
		picked = _weighted_pick_event(by_category[category], rng)

	if picked != null:
		_resolve_event(picked, state, p_owner, rng, w)
	return picked


# ============================================================
#  Manager (espejo de TurnEventManager)
# ============================================================

static func _event_chance(emp: AIRealState.EmpireSnap, turn: int) -> float:
	if emp.category_weights == null:
		return emp.event_chance
	return emp.category_weights.get_event_chance(turn)


static func _core_priority_chance(emp: AIRealState.EmpireSnap) -> float:
	if emp.category_weights == null:
		return 0.9
	return emp.category_weights.core_priority_chance


static func _collect_available_by_category(emp: AIRealState.EmpireSnap,
		ctx: EventContext) -> Dictionary:
	var by_category := {}
	for event in emp.available_events:
		if event.unique and event.id in emp.used_unique_events:
			continue
		if not conditions_met(event, ctx):
			continue
		if not by_category.has(event.category):
			by_category[event.category] = []
		by_category[event.category].append(event)
	return by_category


static func _pick_category(by_category: Dictionary, turn: int,
		weights: EventCategoryWeights, rng: RandomNumberGenerator) -> int:
	var total_weight := 0.0
	var category_weights := {}
	for category in by_category.keys():
		var w := 1.0
		if weights != null:
			w = weights.get_weight(category, turn)
		if w <= 0.0:
			continue
		category_weights[category] = w
		total_weight += w
	if total_weight <= 0.0:
		return -1
	var roll := rng.randf() * total_weight
	var cumulative := 0.0
	var last_category := -1
	for category in category_weights.keys():
		cumulative += category_weights[category]
		last_category = category
		if roll <= cumulative:
			return category
	return last_category


static func _weighted_pick_event(events: Array, rng: RandomNumberGenerator) -> TurnEvent:
	if events.is_empty():
		return null
	var total_weight := 0.0
	for e in events:
		total_weight += (e as TurnEvent).weight
	if total_weight <= 0.0:
		return events[0]
	var roll := rng.randf() * total_weight
	var cumulative := 0.0
	for e in events:
		cumulative += (e as TurnEvent).weight
		if roll <= cumulative:
			return e
	return events.back()


# ============================================================
#  Condiciones (se REUSAN las clases reales)
# ============================================================

## True si TODAS las condiciones del evento se cumplen. Ya no hay espejo: las
## condiciones REALES se evalúan sobre un EventContext construido desde el snapshot
## (`EventContext.from_snapshot`), así que existe una sola implementación de cada
## regla y el polimorfismo de TurnEventCondition sustituye al viejo `if cond is X`
## encadenado.
static func conditions_met(event: TurnEvent, ctx: EventContext) -> bool:
	for cond in event.conditions:
		if not cond.is_met(ctx):
			return false
	return true


# ============================================================
#  Resolución (espejo de AIEventResolver sobre el snapshot)
# ============================================================

static func _resolve_event(event: TurnEvent, state: AIRealState, p_owner: int,
		rng: RandomNumberGenerator, w: HeuristicWeights = null) -> void:
	var emp := state.empire(p_owner)

	# La tienda se resuelve aparte (compras/purgas), igual que AIEventResolver.
	if event is ShopEvent:
		AIRealShop._resolve_shop(event as ShopEvent, state, p_owner, emp, state.turn_number, rng, w)
		_mark_unique(event, emp)
		return

	# Choices asequibles + skip.
	var available: Array[TurnEventChoice] = []
	for c in event.choices:
		if c != null and _choice_affordable(c, emp, state):
			available.append(c)
	var skip_choice: TurnEventChoice = null
	if event.allow_skip:
		skip_choice = TurnEventChoice.new()
		available.append(skip_choice)

	if available.is_empty():
		_mark_unique(event, emp)
		return

	# Elegir la de mayor valor (skip = 0). Vista construida UNA vez para todas las
	# comparaciones (el scorer es el mismo que el del mundo vivo).
	var view := SnapshotStateView.new(state, p_owner,
		w if w != null else HeuristicWeights.get_default())
	var picked: TurnEventChoice = available[0]
	var best := AIChoiceScorer.score_choice(view, available[0])
	for i in range(1, available.size()):
		var s := AIChoiceScorer.score_choice(view, available[i])
		if s > best:
			best = s
			picked = available[i]

	if picked != skip_choice:
		AIRealEventEffects._apply_choice(picked, state, p_owner, rng)
	_mark_unique(event, emp)


static func _mark_unique(event: TurnEvent, emp: AIRealState.EmpireSnap) -> void:
	if event.unique and event.id not in emp.used_unique_events:
		emp.used_unique_events.append(event.id)


static func _choice_affordable(choice: TurnEventChoice, emp: AIRealState.EmpireSnap,
		state: AIRealState) -> bool:
	if choice.cost == null:
		return true
	var cost := choice.cost
	var gold_needed := AIRealEventEffects._cost_gold(cost, emp, state)
	if gold_needed > 0 and emp.gold < gold_needed:
		return false
	if cost.food > 0 and emp.food < cost.food:
		return false
	if cost.auto_remove_filter != null and not AIRealEventEffects._filter_has_match(cost.auto_remove_filter, emp):
		return false
	if cost.player_remove_filter != null and AIRealEventEffects._filter_candidates(cost.player_remove_filter, emp).is_empty():
		return false
	return true


