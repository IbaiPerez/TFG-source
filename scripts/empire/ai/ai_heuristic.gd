extends RefCounted
class_name AIHeuristic

## Evaluador heurístico de AIPlayOption para el AIController (Fase B).
##
## Arquitectura de dos capas:
##   1. Señales de urgencia (gold/food/military/deck) dependientes de la fase:
##      lo que cuenta como "crisis" en mid game es muy distinto a early.
##   2. Valor intrínseco de cada opción × urgencia del recurso que aporta.
##
## PASS tiene score 0.0 por convenio. Cualquier acción con score positivo
## se prefiere sobre pasar. Acciones que empeoran el estado (edificios con
## stats negativos en situación de crisis) pueden puntuar negativo, con lo
## que PASS gana y la IA no las ejecuta.


## Punto de entrada principal. Devuelve el score de una opción en el contexto
## actual. Score más alto = más deseable.
static func score_option(option: AIPlayOption, ctx: AITurnContext) -> float:
	if option == null or option.is_pass:
		return 0.0

	var phase := AIGamePhase.detect(ctx.stats, ctx.total_map_tiles)

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
# Caché de decisión
# ---------------------------------------------------------------------------

## Precalcula todas las señales de urgencia y datos de estado una sola vez
## por decisión (antes del bucle que puntúa todas las opciones de una carta).
## Llamar ctx.invalidate_decision_cache() tras ejecutar la opción elegida.
static func prepare_decision_cache(ctx: AITurnContext) -> void:
	if ctx.stats == null:
		return
	var phase := AIGamePhase.detect(ctx.stats, ctx.total_map_tiles)
	var w := ctx.get_weights()

	ctx._cache_gu       = _gold_urgency(ctx.stats.gold_per_turn, phase, w)
	ctx._cache_fu       = _food_urgency(ctx.stats.food, phase, w)
	ctx._cache_surplus  = _resource_surplus_factor(ctx, phase)
	ctx._cache_expansion = _expansion_factor(ctx)

	# Frentes activos: calcular una sola vez y reutilizar en _military_urgency
	# y en _max_front_pressure para evitar la llamada repetida a get_active_instances().
	var raw_fronts := BattleFront.get_active_instances()
	ctx._cache_active_fronts.clear()
	for f in raw_fronts:
		if f != null and not f.is_resolved:
			ctx._cache_active_fronts.append(f)

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

	ctx._cache_valid = true


## Devuelve los frentes activos donde participa el empire de ctx.
## Solo se usa como fallback cuando el caché de decisión no está disponible.
static func _get_own_active_fronts(ctx: AITurnContext) -> Array[BattleFront]:
	var result: Array[BattleFront] = []
	if ctx.stats == null or ctx.stats.empire == null:
		return result
	for front in BattleFront.get_active_instances():
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
		var p := AIUrgency.front_pressure(ai_marker, front.threshold)
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
		for front in BattleFront.get_active_instances():
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
	for front in BattleFront.get_active_instances():
		if front == null or front.is_resolved:
			continue
		var is_attacker := front.attacker_empire == ctx.stats.empire
		var is_defender := front.defender_empire == ctx.stats.empire
		if not is_attacker and not is_defender:
			continue
		var ai_marker := front.marker if is_attacker else -front.marker
		var pressure := AIUrgency.front_pressure(ai_marker, front.threshold)
		max_p = maxf(max_p, pressure)
	return max_p


## Urgencia de mazo: cuánto necesitamos más cartas disponibles. El vivo mide el
## draw_pile; los umbrales viven en AIUrgency.deck_urgency (compartida).
static func _deck_urgency(ctx: AITurnContext) -> float:
	var draw_size := ctx.stats.draw_pile.cards.size() if ctx.stats.draw_pile else 0
	return AIUrgency.deck_urgency(draw_size, ctx.get_weights())


## Número total de cartas en el mazo activo (draw + discard pile).
## No incluye played_pile ni la mano corriente (drawn_cards).
static func _current_deck_size(ctx: AITurnContext) -> int:
	if ctx.stats == null:
		return 0
	var n := 0
	if ctx.stats.draw_pile:
		n += ctx.stats.draw_pile.cards.size()
	if ctx.stats.discard_pile:
		n += ctx.stats.discard_pile.cards.size()
	return n


## Cuenta cuántas cartas del mismo tipo (misma clase GDScript) hay en el mazo
## activo (draw + discard). Devuelve al menos 1 para que el factor nunca sea 0.
static func _card_type_count(card: Card, ctx: AITurnContext) -> int:
	if ctx.stats == null:
		return 1
	var script: Script = card.get_script() as Script
	var count := 0
	if ctx.stats.draw_pile:
		for c in ctx.stats.draw_pile.cards:
			if c != null and c.get_script() == script:
				count += 1
	if ctx.stats.discard_pile:
		for c in ctx.stats.discard_pile.cards:
			if c != null and c.get_script() == script:
				count += 1
	return maxi(count, 1)


## Factor de saturación por tipo de carta [0.25, 1.0].
## La primera copia vale el 100 %; las siguientes tienen rendimiento decreciente.
## Ejemplos: 1 copia → 1.0 | 2 → 0.67 | 3 → 0.50 | 4 → 0.40 | 5 → 0.33 (mín 0.25)
## Así la IA evita acumular muchas copias del mismo tipo cuando el mazo ya las
## tiene cubiertas, incluso si el estado del mapa las favorece.
static func _type_saturation(card: Card, ctx: AITurnContext) -> float:
	return clampf(1.0 / float(_card_type_count(card, ctx)), ctx.get_weights().type_sat_min, 1.0)


## Factor de excedente económico [1.0, 3.0].
## Cuando el empire tiene oro y comida muy por encima de los umbrales cómodos
## para su fase, el coste de oportunidad de reclutar o abrir frentes es mínimo
## y estas acciones se potencian. Requiere food >= 5 (sin margen de comida no
## se pueden sostener tropas aunque el oro sobre).
static func _resource_surplus_factor(ctx: AITurnContext, phase: AIGamePhase.Phase) -> float:
	if ctx.stats == null:
		return 1.0
	return AIEconomy.resource_surplus_factor(
		ctx.stats.food, ctx.stats.gold_per_turn, phase, ctx.get_weights())


## Factor de presión expansionista [0.0, 1.0] basado en tiles colonizables
## adyacentes al territorio actual. Independiente de la fase (turno).
## 1.0 = muchas tiles libres alrededor (expansión plena)
## 0.0 = sin tiles colonizables (mapa saturado)
## Cuando colonizable_tiles_count == -1 (tests sin mapa) → 0.5 neutro.
static func _expansion_factor(ctx: AITurnContext) -> float:
	# El vivo usa el conteo precomputado del contexto (puede ser -1 en tests sin mapa).
	return AITerritory.expansion_factor(ctx.colonizable_tiles_count, ctx.get_weights())



## Valor de adelgazar el mazo en una carta, proporcional al tamaño del mazo.
## Mazo pequeño (≤DECK_SMALL): el ciclo ya es rápido, purgar aporta poco.
## Mazo grande (≥DECK_LARGE): el ciclo es lento, purgar acelera las cartas clave.
static func _deck_thinning_value(ctx: AITurnContext) -> float:
	var w := ctx.get_weights()
	# deck_thin_small: mazo pequeño, purgar no es urgente.
	# deck_thin_large: mazo grande/saturado, purgar es muy beneficioso.
	var ratio := clampf(
		(float(_current_deck_size(ctx)) - w.deck_small) / (w.deck_large - w.deck_small),
		0.0, 1.0)
	return lerpf(w.deck_thin_small, w.deck_thin_large, ratio)


## Umbral dinámico de puntuación mínima para purgar una carta del mazo en tienda.
## Mazo pequeño: umbral bajo → solo eliminar cartas casi inútiles.
## Mazo grande/saturado: umbral alto → eliminar hasta cartas de utilidad moderada
## para acelerar el ciclo de las más valiosas.
## Es public porque lo usa también AIEventResolver.
static func dynamic_purge_threshold(ctx: AITurnContext) -> float:
	var w := ctx.get_weights()
	# purge_thresh_small: mazo pequeño, conservar casi todo.
	# purge_thresh_large: mazo grande, purgar hasta utilidad moderada.
	var ratio := clampf(
		(float(_current_deck_size(ctx)) - w.deck_small) / (w.deck_large - w.deck_small),
		0.0, 1.0)
	return lerpf(w.purge_thresh_small, w.purge_thresh_large, ratio)


## Número total de huecos de edificio vacíos en las tiles controladas.
## Un hueco es un slot donde se puede construir (tile.max_buildings - tile.buildings.size()).
## Usado para escalar BuildCard: si no hay huecos la carta es inútil.
static func _buildable_slots(ctx: AITurnContext) -> int:
	if ctx.stats == null or ctx.stats.empire == null:
		return 0
	var total := 0
	for tile in ctx.stats.empire.controlled_tiles:
		total += maxi(0, tile.max_buildings - tile.buildings.size())
	return total


## Número de edificios construidos que tienen al menos una mejora disponible
## (upgrades_to no vacío). Usado para escalar UpgradeBuildingCard.
static func _upgradeable_buildings(ctx: AITurnContext) -> int:
	if ctx.stats == null or ctx.stats.empire == null:
		return 0
	var count := 0
	for tile in ctx.stats.empire.controlled_tiles:
		for building in tile.buildings:
			if building != null and not building.upgrades_to.is_empty():
				count += 1
	return count


## Devuelve true si un edificio quedará demolido al asignar new_loc a la tile.
## Replica la lógica de ChangeLocationTypeEffect: se destruye si
## allowed_location_type no está vacío y no contiene new_loc (comparando por
## valor de enum, no por referencia, para robustez en la heurística).
static func _building_demolished_by(building: Building, new_loc: LocationType) -> bool:
	if building.allowed_location_type.is_empty():
		return false          # sin restricción de location → sobrevive siempre
	for allowed in building.allowed_location_type:
		if allowed.type == new_loc.type:
			return false      # el nuevo tipo está en la lista → sobrevive
	return true               # new_loc no está → se demolerá


## Devuelve true si el edificio explota el recurso natural de la tile
## Y es una versión mejorada (no el edificio base): algún edificio en
## stats.possible_buildings lo tiene en su lista upgrades_to.
static func _is_upgraded_resource_building(building: Building, tile: Tile,
		ctx: AITurnContext) -> bool:
	if building.required_natural_resource == null:
		return false
	if building.required_natural_resource != tile.natural_resource:
		return false
	if ctx.stats == null or ctx.stats.possible_buildings == null:
		return false
	for possible in ctx.stats.possible_buildings:
		if building in possible.upgrades_to:
			return true   # `building` es el resultado de un upgrade → está mejorado
	return false


## Puntúa los edificios que se DESBLOQUEAN al pasar de old_loc a new_loc
## en una tile concreta. Solo se cuentan edificios que:
##  - requieren new_loc (su allowed_location_type lo incluye)
##  - NO podían construirse en old_loc (nuevo con este tier)
##  - son compatibles con el bioma y el recurso natural de la tile
##  - aún no están construidos en la tile
## Devuelve la suma de su valor económico, topada en 15.0 para evitar dominancia.
static func _score_unlocked_buildings(tile: Tile, old_loc: LocationType,
		new_loc: LocationType, ctx: AITurnContext,
		gu: float, fu: float, mu: float) -> float:
	if ctx.stats == null or ctx.stats.possible_buildings == null:
		return 0.0
	var w := ctx.get_weights()
	var total := 0.0
	for b in ctx.stats.possible_buildings:
		if b == null or b.allowed_location_type.is_empty():
			continue
		# El edificio debe encajar en new_loc pero NO en old_loc.
		var fits_new := false
		var fits_old := false
		for allowed in b.allowed_location_type:
			if allowed.type == new_loc.type: fits_new = true
			if allowed.type == old_loc.type: fits_old = true
		if not fits_new or fits_old:
			continue
		# Compatibilidad de bioma.
		if not b.allowed_biomes.is_empty() \
				and tile.mesh_data.type not in b.allowed_biomes:
			continue
		# Compatibilidad de recurso natural.
		if b.required_natural_resource != null \
				and b.required_natural_resource != tile.natural_resource:
			continue
		# Ya construido: no aporta desbloqueado nuevo.
		if b in tile.buildings:
			continue
		total += b.gold_produced * w.unlock_gold * gu \
			   + b.food_produced * w.unlock_food * fu \
			   + b.flat_defense_bonus * w.unlock_defense * mu
	return minf(total, w.unlock_cap)


# ---------------------------------------------------------------------------
# Scoring por tipo de opción
# ---------------------------------------------------------------------------

static func _score_build(option: AIBuildOption, ctx: AITurnContext,
		_phase: AIGamePhase.Phase) -> float:
	# Portado al scorer compartido (§1.3.g). El tie-breaker por casilla se omite si
	# no hay target (tile null).
	if option.building == null:
		return 0.0
	var tile := option.targets[0] as Tile if not option.targets.is_empty() else null
	return AIMoveScorer.score_build(LiveStateView.new(ctx), option.building, tile)


static func _score_upgrade(option: AIUpgradeBuildingOption, ctx: AITurnContext,
		_phase: AIGamePhase.Phase) -> float:
	# Portado al scorer compartido (§1.3.g).
	if option.old_building == null or option.new_building == null:
		return 0.0
	return AIMoveScorer.score_upgrade(
		LiveStateView.new(ctx), option.old_building, option.new_building)


static func _score_recruit(option: AIRecruitOption, ctx: AITurnContext,
		_phase: AIGamePhase.Phase) -> float:
	# Portado al scorer compartido (§1.3.g).
	if option.troop == null:
		return 0.0
	return AIMoveScorer.score_recruit(LiveStateView.new(ctx), option.troop)


## Bonus de complementariedad: favorece tropas que equilibran el pool actual
## y además contrarrestan la composición visible del rival en frentes activos.
## ctx puede ser null (tests o llamadas sin info de rival → solo balance interno).
static func _complement_bonus(troop: Troop, pool: Array[Troop],
		ctx: AITurnContext = null) -> float:
	var w := ctx.get_weights() if ctx != null else HeuristicWeights.get_default()
	# D7: recolectar tipos de tropa del rival visibles en frentes activos. Sin
	# world_view/rival (tests) → lista vacía → counter neutro. La fórmula del
	# complemento y del counter viven en AIMilitary (compartidas con el snapshot).
	var rival_types: Array[int] = []
	if ctx != null and ctx.world_view != null:
		var rival := ctx.world_view.get_rival_view()
		if rival != null and rival.empire != null:
			var all_fronts := ctx._cache_active_fronts if ctx._cache_valid \
				else BattleFront.get_active_instances()
			for front in all_fronts:
				if front.is_resolved:
					continue
				var rival_side_troops: Array[Troop] = front.attacker_troops \
					if front.attacker_empire == rival.empire else front.defender_troops
				if front.attacker_empire != rival.empire \
						and front.defender_empire != rival.empire:
					continue
				for t in rival_side_troops:
					if t.type not in rival_types:
						rival_types.append(t.type)

	return AIMilitary.complement_bonus(troop, pool, w) \
		* AIMilitary.counter_bonus(troop.type, rival_types, w)


static func _score_open_front(option: AIOpenFrontOption, ctx: AITurnContext,
		_phase: AIGamePhase.Phase) -> float:
	# Portado al scorer compartido (§1.3.g). El veto por 0 tropas libres vive dentro
	# del scorer; la ganabilidad/valor-origen (con sus divergencias) los resuelve la vista.
	if option.enemy_tile == null:
		return 0.0
	return AIMoveScorer.score_open_front(
		LiveStateView.new(ctx), option.enemy_tile, option.source_tile)


static func _score_tactic(option: AITacticOption, ctx: AITurnContext,
		_phase: AIGamePhase.Phase) -> float:
	# Portado al scorer compartido (§1.3.g). El wrapper descompone el BattleFront de
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
		own_troops, ai_marker, option.front.threshold, relevant_tile)


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
	# Portado al scorer compartido (§1.3.g). El wrapper conserva los guardas
	# (hay target y es Tile) y construye la vista viva; la fase la calcula la vista.
	if option.targets.is_empty():
		return 0.0
	var tile := option.targets[0] as Tile
	if tile == null:
		return 0.0
	return AIMoveScorer.score_colonize(LiveStateView.new(ctx), tile)


## Tiles nuevas que se volverían colonizables exclusivamente gracias a colonizar
## `tile`. Una vecina libre cuenta como "nueva" solo si ningún otro tile del
## territorio actual ya la hace accesible. Cuanto mayor, más abre esta tile
## rutas de expansión hacia espacio libre (difícil de rodear).
static func _frontier_value(tile: Tile, ctx: AITurnContext) -> int:
	if ctx.stats == null or ctx.stats.empire == null:
		return 0
	var count := 0
	for nb in tile.neighbors:
		var t := nb as Tile
		if t == null or t.controller != null:
			continue
		var already_reachable := false
		for nn in t.neighbors:
			var nt := nn as Tile
			if nt == null or nt == tile:
				continue
			if nt.controller == ctx.stats.empire:
				already_reachable = true
				break
		if not already_reachable:
			count += 1
	return count


## Multiplicador del bonus de frontera según el grado de encierro.
## Ratio = tiles_colonizables / tiles_controladas.
## Ratio bajo → la IA está quedando rodeada → escalar el incentivo de escapar.
static func _encirclement_pressure(ctx: AITurnContext) -> float:
	var w := ctx.get_weights()
	# Sin empire o sin conteo de mapa (tests): valor neutro. La fórmula por ratio
	# vive en AITerritory.encirclement_pressure (compartida con el snapshot).
	if ctx.stats == null or ctx.stats.empire == null:
		return w.encircle_default
	var avail := ctx.colonizable_tiles_count
	if avail < 0:
		return w.encircle_default
	var controlled := maxi(ctx.stats.empire.controlled_tiles.size(), 1)
	return AITerritory.encirclement_pressure(avail, controlled, w)


## Village→Town: +5 food_consumption y +2 building slots.
## Town→Megalópolis: +5 food_consumption adicional y +2 building slots más.
## El delta real de food_consumption se lee de los recursos, no está hardcodeado.
static func _score_change_location(option: AIPlayOption, ctx: AITurnContext,
		_phase: AIGamePhase.Phase) -> float:
	# Portado al scorer compartido (§1.3.g). La fórmula COMPLETA (penalización por
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
	# Portado al scorer compartido (§1.3.g): mismo scorer que BUILD, sin casilla
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
	if card == null:
		return 0.0
	var w := ctx.get_weights()
	var phase := AIGamePhase.detect(ctx.stats, ctx.total_map_tiles)
	var gu  := _gold_urgency(ctx.stats.gold_per_turn, phase, w)
	var fu  := _food_urgency(ctx.stats.food, phase, w)
	var mu  := _military_urgency(ctx, phase)
	var exp := _expansion_factor(ctx)  # presión expansionista: tiles adj. libres
	# Rendimiento decreciente por copias: la n-ésima copia del mismo tipo vale
	# menos aunque el estado del mapa la favorezca. Se multiplica en todos los
	# returns para que la saturación de mazo afecte a cualquier tipo de carta.
	var sat := _type_saturation(card, ctx)

	if card is ColonizeCard:
		# Sin tiles colonizables: carta inútil, eliminar primero.
		var avail := ctx.colonizable_tiles_count
		if avail == 0:
			return w.scd_colonize_empty * sat
		return lerpf(w.scd_colonize_lo, w.scd_colonize_hi, exp) * sat

	if card is DirectBuildCard:
		var db := card as DirectBuildCard
		if not db.buildings.is_empty() and db.buildings[0] != null:
			var b := db.buildings[0]
			return (b.gold_produced * w.scd_db_gold * gu \
				  + b.food_produced * w.scd_db_food * fu \
				  + b.flat_defense_bonus * w.scd_db_defense * mu) * sat
		return w.scd_db_default * sat

	if card is UpgradeBuildingCard:
		var upgrades := _upgradeable_buildings(ctx)
		if upgrades == 0:
			return w.scd_upg_none * sat
		return lerpf(w.scd_upg_lo, w.scd_upg_hi, clampf(float(upgrades) / w.scd_upg_ref, 0.0, 1.0)) * sat

	# BuildCard genérica: valioso solo si hay huecos de edificio libres.
	if card is BuildCard:
		var slots := _buildable_slots(ctx)
		if slots == 0:
			return w.scd_build_none * sat
		return lerpf(w.scd_build_lo, w.scd_build_hi, clampf(float(slots) / w.scd_build_ref, 0.0, 1.0)) * sat

	if card is RecruitCard:
		# troop_sat: rendimiento decreciente por pool grande (diferente a sat por copias).
		var troop_sat := 1.0 / (1.0 + ctx.stats.troop_pool.size() * w.recruit_saturation_k)
		return (w.scd_recruit_base + mu * w.scd_recruit_mu) * troop_sat * sat

	if card is OpenFrontCard:
		return (w.scd_openfront_base + mu * w.scd_openfront_mu) * sat

	if card is TacticCard:
		return (w.scd_tactic_base + mu * w.scd_tactic_mu) * sat

	if card is ChangeLocationTypeCard:
		var clt_card := card as ChangeLocationTypeCard
		if clt_card.location_type == null:
			return w.scd_clt_invalid * sat
		var valid_count := 0
		for t in ctx.stats.empire.controlled_tiles:
			if t.location != null \
					and t.location.type + 1 == clt_card.location_type.type:
				valid_count += 1
		if valid_count == 0:
			return w.scd_clt_invalid * sat
		var tile_factor := clampf(float(valid_count) / w.scd_clt_ref, 0.0, 1.0)
		if ctx.stats.food < clt_card.location_type.food_consumption:
			return lerpf(w.scd_clt_poor_lo, w.scd_clt_poor_hi, tile_factor) * sat
		return lerpf(w.scd_clt_lo, w.scd_clt_hi, tile_factor) * sat

	if card is CardDrawCard:
		var deck_ratio := clampf(float(_current_deck_size(ctx)) / w.scd_draw_ref, 0.0, 1.0)
		return lerpf(w.scd_draw_lo, w.scd_draw_hi, deck_ratio) * sat

	if card is RecoverCard:
		var best_score := 0.0
		if ctx.stats != null:
			var all_cards: Array[Card] = []
			if ctx.stats.draw_pile:
				all_cards.append_array(ctx.stats.draw_pile.cards)
			if ctx.stats.discard_pile:
				all_cards.append_array(ctx.stats.discard_pile.cards)
			for c in all_cards:
				if c == null or c is RecoverCard:
					continue
				var s := score_card_for_deck(c, ctx)
				if s > best_score:
					best_score = s
		# scd_recover_frac del valor de la mejor carta recuperable, entre lo y hi.
		return clampf(best_score * w.scd_recover_frac, w.scd_recover_lo, w.scd_recover_hi) * sat

	if card is GenerateGoldCard:
		return (card as GenerateGoldCard).amount * w.scd_gold_weight * gu * sat

	return w.scd_unknown * sat  # tipo desconocido: valor neutro


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
	if candidates.is_empty():
		return null

	var avail := ctx.colonizable_tiles_count
	# Contar cuántas ColonizeCards hay entre los candidatos.
	var colonize_count := 0
	for c in candidates:
		if c is ColonizeCard:
			colonize_count += 1
	# Proteger la última ColonizeCard si quedan tiles por colonizar.
	var protect_colonize := avail != 0 and colonize_count <= 1

	var worst: Card = null
	var worst_score := INF
	for card in candidates:
		if protect_colonize and card is ColonizeCard:
			continue
		var s := score_card_for_deck(card, ctx)
		if s < worst_score:
			worst_score = s
			worst = card

	# Fallback: si todos los candidatos eran ColonizeCards protegidas,
	# elegir la peor sin restricción (avail==0 o no había alternativas).
	if worst == null:
		worst_score = INF
		for card in candidates:
			var s := score_card_for_deck(card, ctx)
			if s < worst_score:
				worst_score = s
				worst = card

	return worst


## Evalúa el valor esperado de una TurnEventChoice sumando el aporte de
## cada efecto que la compone. Los efectos con input del jugador
## (RemoveCardEventEffect) se puntúan con un valor fijo positivo: asumimos
## que la IA elegirá la carta más prescindible (pick_card_to_remove), así
## que la elección es beneficiosa.
static func score_choice(choice: TurnEventChoice, ctx: AITurnContext) -> float:
	if choice == null:
		return 0.0
	var w := ctx.get_weights()
	var phase := AIGamePhase.detect(ctx.stats, ctx.total_map_tiles)
	var gu := _gold_urgency(ctx.stats.gold_per_turn, phase, w)
	var fu := _food_urgency(ctx.stats.food, phase, w)
	var score := 0.0

	for effect in choice.effects:
		if effect == null:
			continue
		if effect is AddCardEffect:
			score += score_card_for_deck((effect as AddCardEffect).card, ctx)
		elif effect is GoldEventEffect:
			score += (effect as GoldEventEffect).amount * w.choice_gold * gu
		elif effect is FoodEventEffect:
			score += (effect as FoodEventEffect).amount * w.choice_food * fu
		elif effect is RemoveCardEventEffect:
			# Eliminar carta: beneficio variable según el tamaño del mazo.
			# Mazo pequeño → el ciclo ya es rápido, purgar aporta poco.
			# Mazo grande/saturado → purgar acelera el acceso a las mejores cartas.
			score += _deck_thinning_value(ctx)
		elif effect is AddRandomPoolCardEffect:
			# Carta aleatoria del pool: valor medio estimado
			score += w.choice_random_pool
		elif effect is UrbanizeToMegalopolisEffect:
			# Megalópolis: +2 slots de edificio y desbloquea edificios de ciudad.
			# Valor conservador pero realista: mucho mejor que +3 genérico.
			score += w.choice_megalopolis
		else:
			# Efecto desconocido: valor neutro-positivo
			score += w.choice_unknown

	# Penalización leve si tiene coste (ya verificado como asequible,
	# pero un coste siempre supone una restricción)
	if choice.cost != null:
		score -= w.choice_cost_penalty

	return score


## Decide si la IA debe comprar un item de tienda.
## El umbral escala con el tamaño del mazo: con el mazo pequeño casi todo
## vale la pena añadir; con el mazo saturado solo se compra lo realmente bueno.
static func should_buy_shop_item(item: ShopItem, ctx: AITurnContext) -> bool:
	if item == null or item.card == null:
		return false
	var w := ctx.get_weights()
	# shop_thresh_small: mazo pequeño, comprar casi cualquier carta útil.
	# shop_thresh_large: mazo grande, solo cartas realmente valiosas.
	var ratio := clampf(
		(float(_current_deck_size(ctx)) - w.deck_small) / (w.deck_large - w.deck_small),
		0.0, 1.0)
	var threshold := lerpf(w.shop_thresh_small, w.shop_thresh_large, ratio)
	return score_card_for_deck(item.card, ctx) >= threshold


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
	var gu := _gold_urgency(ctx.stats.gold_per_turn, phase, w)
	var fu := _food_urgency(ctx.stats.food, phase, w)
	var mu := _military_urgency(ctx, phase)
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
				_current_troops_per_recruit_bonus(ctx), w)
		_:
			return AIBuildingEffects.stat_effect_simple(effect.stat_type, v,
				ctx.stats.gold_per_turn, ctx.stats.food, ctx.stats.troop_pool.size(),
				gu, fu, mu, w)


## Suma el bonus TROOPS_PER_RECRUIT ya activo en los edificios construidos del empire.
## Usado para calcular el rendimiento decreciente al valorar un nuevo cuartel.
static func _current_troops_per_recruit_bonus(ctx: AITurnContext) -> int:
	if ctx.stats == null or ctx.stats.empire == null:
		return 0
	var total := 0
	for tile in ctx.stats.empire.controlled_tiles:
		for building in tile.buildings:
			if building == null:
				continue
			for effect in building.effects:
				if effect is AddStatModifierEffect:
					var sme := effect as AddStatModifierEffect
					if sme.stat_type == StatModifier.StatType.TROOPS_PER_RECRUIT:
						total += int(sme.value)
	return total


## Factor de carrera territorial [0.5, 2.0] basado en la distribución de tiles.
## mode &"colonize"/"open_front": amplifica acciones expansivas cuando la carrera
## es ajustada o el rival se acerca al 55% del territorio conocido.
## mode &"economy": reduce el valor de mejoras económicas cuando ya dominamos.
## Devuelve 1.0 si world_view es null (tests sin info de rival).
static func _territory_race_factor(ctx: AITurnContext,
		mode: StringName = &"colonize") -> float:
	if ctx.world_view == null:
		return 1.0
	var rival := ctx.world_view.get_rival_view()
	if rival == null or rival.empire == null:
		return 1.0
	var my_tiles := ctx.stats.empire.controlled_tiles.size() \
		if ctx.stats.empire != null else 0
	var rival_tiles := rival.empire.controlled_tiles.size()
	var colonizable := maxi(ctx.colonizable_tiles_count, 0)
	return AITerritory.territory_race_factor(
		my_tiles, rival_tiles, colonizable, mode, ctx.get_weights())


## Factor de coste: penaliza edificios que consumen una fracción alta del oro.
## Rango build_cost_min (gasto total) → 1.0 (gasto residual). Suaviza la
## preferencia por edificios baratos cuando el gold disponible es ajustado.
static func _build_cost_factor(cost: int, total_gold: int,
		w: HeuristicWeights = null) -> float:
	if w == null: w = HeuristicWeights.get_default()
	return AIEconomy.build_cost_factor(cost, total_gold, w)


## Multiplicador de dificultad de ataque según el bioma de la tile enemiga.
## Montaña 0.60, Pantano 0.70, Bosque 0.80 … Pradera 1.20.
static func _attack_biome_factor(tile: Tile) -> float:
	if tile == null or tile.mesh_data == null:
		return 1.0
	return BiomeConfig.shared().get_attack_multiplier(tile.mesh_data.type)
