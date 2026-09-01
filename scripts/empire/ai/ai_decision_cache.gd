extends RefCounted
class_name AIDecisionCache

## Señales de urgencia de la IA sobre el mundo vivo, y su caché por decisión.
##
## Las urgencias (oro / comida / militar / mazo) responden a "qué necesita este
## imperio AHORA", dependen de la fase y las consulta CADA opción que se puntúa.
## Calcularlas una vez por decisión, y no una vez por opción, es lo que hace
## viable puntuar decenas de jugadas por turno: `_cache_fronts` sola evita
## repetir el recorrido del registro de frentes en cada scoring.
##
## Las FÓRMULAS viven en AIUrgency, compartidas con el snapshot; aquí está el
## recorrido del mundo vivo que las alimenta y el ciclo de vida de la caché
## (la invalida `ctx.invalidate_decision_cache()` tras ejecutar la jugada).

# ---------------------------------------------------------------------------
# Caché de decisión
# ---------------------------------------------------------------------------

## Precalcula todas las señales de urgencia y datos de estado una sola vez
## por decisión (antes del bucle que puntúa todas las opciones de una carta).
## Llamar ctx.invalidate_decision_cache() tras ejecutar la opción elegida.
static func prepare_decision_cache(ctx: AITurnContext) -> void:
	if ctx.stats == null:
		return
	var w := ctx.get_weights()
	var phase := AIGamePhase.detect(ctx.stats, ctx.total_map_tiles, w)

	_cache_urgencies(ctx, phase, w)
	_cache_fronts(ctx)
	_cache_threat(ctx, w)

	ctx._cache_valid = true


## Urgencias económicas y de expansión (puras sobre stats + pesos).
static func _cache_urgencies(ctx: AITurnContext, phase: AIGamePhase.Phase,
		w: HeuristicWeights) -> void:
	ctx._cache_gu        = _gold_urgency(ctx.stats.gold_per_turn, phase, w)
	ctx._cache_fu        = _food_urgency(ctx.stats.food, phase, w)
	ctx._cache_surplus   = AILiveFacts._resource_surplus_factor(ctx, phase)
	ctx._cache_expansion = AILiveFacts._expansion_factor(ctx)


## Frentes activos: se recogen una sola vez y los reutilizan _military_urgency y
## _max_front_pressure, evitando repetir get_active_instances() en cada scoring.
static func _cache_fronts(ctx: AITurnContext) -> void:
	var raw_fronts := ctx.get_front_registry().get_active_instances()
	ctx._cache_active_fronts.clear()
	for f in raw_fronts:
		if f != null and not f.is_resolved:
			ctx._cache_active_fronts.append(f)


## Amenaza militar: si participamos en algún frente, si hay enemigo adyacente (solo
## se comprueba cuando NO hay frente: un frente abierto ya domina la urgencia), y la
## presión máxima resultante.
static func _cache_threat(ctx: AITurnContext, w: HeuristicWeights) -> void:
	ctx._cache_has_active_front   = false
	ctx._cache_has_adjacent_enemy = false
	if ctx.stats.empire != null:
		for front in ctx._cache_active_fronts:
			if front.attacker_empire == ctx.stats.empire \
					or front.defender_empire == ctx.stats.empire:
				ctx._cache_has_active_front = true
				break
		if not ctx._cache_has_active_front:
			for tile in ctx.stats.empire.controlled_tiles:
				for nb in tile.neighbors:
					var t := nb as Tile
					if t != null and t.controller != null \
							and t.controller != ctx.stats.empire:
						ctx._cache_has_adjacent_enemy = true
						break
				if ctx._cache_has_adjacent_enemy:
					break

	ctx._cache_front_pressure = _max_front_pressure_from_list(
		ctx._cache_active_fronts, ctx.stats.empire)
	ctx._cache_mu = AIUrgency.military_urgency_from(
		ctx._cache_has_active_front, ctx._cache_has_adjacent_enemy,
		ctx._cache_front_pressure, w)


## Devuelve los frentes activos donde participa el empire de ctx.
## Solo se usa como fallback cuando el caché de decisión no está disponible.
static func _get_own_active_fronts(ctx: AITurnContext) -> Array[BattleFront]:
	var result: Array[BattleFront] = []
	if ctx.stats == null or ctx.stats.empire == null:
		return result
	for front in ctx.get_front_registry().get_active_instances():
		if front == null or front.is_resolved:
			continue
		if front.attacker_empire == ctx.stats.empire \
				or front.defender_empire == ctx.stats.empire:
			result.append(front)
	return result


## Versión de _max_front_pressure que recibe la lista de frentes ya filtrada,
## evitando rellamar get_active_instances() dentro del mismo ciclo de scoring.
static func _max_front_pressure_from_list(
		fronts: Array[BattleFront], empire: Empire) -> float:
	if empire == null:
		return 0.0
	var max_p := 0.0
	for front in fronts:
		var is_att := front.attacker_empire == empire
		var is_def := front.defender_empire == empire
		if not is_att and not is_def:
			continue
		var ai_marker := front.marker if is_att else -front.marker
		# Umbral EFECTIVO (decae con los turnos), no el de configuración: es contra
		# él contra el que el frente se resuelve de verdad.
		var p := AIUrgency.front_pressure(ai_marker, front.get_current_threshold())
		max_p = maxf(max_p, p)
	return max_p


# ---------------------------------------------------------------------------
# Señales de urgencia
# ---------------------------------------------------------------------------

## Urgencia de oro: cuánto necesitamos mejorar el gold_per_turn ahora. La fórmula
## y los umbrales por fase viven en AIUrgency.gold_urgency (compartida con el
## snapshot). Este wrapper solo aplica el default de pesos y delega.
## Nota: recibe gpt y phase directamente, no ctx, por lo que el caché se usa en los
## sitios que la llaman pasando ctx._cache_gu.
static func _gold_urgency(gpt: int, phase: AIGamePhase.Phase,
		w: HeuristicWeights = null) -> float:
	if w == null: w = HeuristicWeights.get_default()
	return AIUrgency.gold_urgency(gpt, phase, w)


## Urgencia de comida: cuánto necesitamos mejorar el balance de food. Delega en
## AIUrgency.food_urgency (compartida con el snapshot).
static func _food_urgency(food: int, phase: AIGamePhase.Phase,
		w: HeuristicWeights = null) -> float:
	if w == null: w = HeuristicWeights.get_default()
	return AIUrgency.food_urgency(food, phase, w)


## Urgencia militar: combina un baseline según la amenaza real con la
## presión de frentes activos. El baseline ya no depende del turno/fase,
## sino del estado militar concreto (enemigos adyacentes, frentes activos).
## Usa el caché de decisión cuando está disponible para evitar recorrer
## todos los frentes y tiles en cada llamada dentro del mismo ciclo de scoring.
static func _military_urgency(ctx: AITurnContext, _phase: AIGamePhase.Phase) -> float:
	if ctx._cache_valid:
		return ctx._cache_mu

	# Fallback sin caché (usado en tests y en AIEventResolver).
	var has_active_front := false
	if ctx.stats != null and ctx.stats.empire != null:
		for front in ctx.get_front_registry().get_active_instances():
			if front == null or front.is_resolved:
				continue
			if front.attacker_empire == ctx.stats.empire \
					or front.defender_empire == ctx.stats.empire:
				has_active_front = true
				break

	var has_adjacent_enemy := false
	if not has_active_front and ctx.stats != null and ctx.stats.empire != null:
		for tile in ctx.stats.empire.controlled_tiles:
			for neighbor in tile.neighbors:
				if neighbor is Tile \
						and neighbor.controller != null \
						and neighbor.controller != ctx.stats.empire:
					has_adjacent_enemy = true
					break
			if has_adjacent_enemy:
				break

	var pressure := _max_front_pressure(ctx)
	return AIUrgency.military_urgency_from(has_active_front, has_adjacent_enemy,
		pressure, ctx.get_weights())


## Devuelve la presión máxima de los frentes donde participa la IA (0.0–1.0).
## Presión = qué tan cerca estamos de perder el frente más comprometido.
static func _max_front_pressure(ctx: AITurnContext) -> float:
	if ctx._cache_valid:
		return ctx._cache_front_pressure
	# Fallback sin caché.
	var max_p := 0.0
	for front in ctx.get_front_registry().get_active_instances():
		if front == null or front.is_resolved:
			continue
		var is_attacker := front.attacker_empire == ctx.stats.empire
		var is_defender := front.defender_empire == ctx.stats.empire
		if not is_attacker and not is_defender:
			continue
		var ai_marker := front.marker if is_attacker else -front.marker
		var pressure := AIUrgency.front_pressure(ai_marker, front.get_current_threshold())
		max_p = maxf(max_p, pressure)
	return max_p


## Urgencia de mazo: cuánto necesitamos más cartas disponibles. El vivo mide el
## draw_pile; los umbrales viven en AIUrgency.deck_urgency (compartida).
static func _deck_urgency(ctx: AITurnContext) -> float:
	var draw_size := ctx.stats.draw_pile.cards.size() if ctx.stats.draw_pile else 0
	return AIUrgency.deck_urgency(draw_size, ctx.get_weights())
