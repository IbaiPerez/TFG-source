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
	ctx._cache_buildable_slots  = _buildable_slots(ctx)
	ctx._cache_upgradeable      = _upgradeable_buildings(ctx)
	ctx._cache_deck_size        = _current_deck_size(ctx)

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

	var base := w.mil_urg_base_idle
	if ctx._cache_has_active_front:   base = w.mil_urg_base_active
	elif ctx._cache_has_adjacent_enemy: base = w.mil_urg_base_adjacent
	ctx._cache_mu = lerpf(base, w.mil_urg_max, ctx._cache_front_pressure)

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
		var p := clampf(-ai_marker / front.threshold, 0.0, 1.0)
		max_p = maxf(max_p, p)
	return max_p


# ---------------------------------------------------------------------------
# Señales de urgencia
# ---------------------------------------------------------------------------

## Urgencia de oro: cuánto necesitamos mejorar el gold_per_turn ahora.
## Los umbrales son distintos por fase: 50 gpt es crisis en mid game pero
## holgado en early (los edificios básicos cuestan 50-100, los upgrades 200-400,
## los lategame hasta 800).
## Nota: esta función recibe gpt y phase directamente, no ctx, por lo que
## el caché se usa en los sitios que la llaman pasando ctx._cache_gu.
static func _gold_urgency(gpt: int, phase: AIGamePhase.Phase,
		w: HeuristicWeights = null) -> float:
	if w == null: w = HeuristicWeights.get_default()
	match phase:
		AIGamePhase.Phase.EARLY:
			if gpt < w.gold_urg_early_t0:  return w.gold_urg_early_v0
			if gpt < w.gold_urg_early_t1:  return w.gold_urg_early_v1
			if gpt < w.gold_urg_early_t2:  return w.gold_urg_early_v2
			return w.gold_urg_early_v3
		AIGamePhase.Phase.MID:
			# Target mid: 300-400 gpt para construir/mejorar cada turno
			if gpt < w.gold_urg_mid_t0:  return w.gold_urg_mid_v0
			if gpt < w.gold_urg_mid_t1:  return w.gold_urg_mid_v1
			if gpt < w.gold_urg_mid_t2:  return w.gold_urg_mid_v2
			if gpt < w.gold_urg_mid_t3:  return w.gold_urg_mid_v3
			return w.gold_urg_mid_v4
		_: # LATE
			# Rendimiento decreciente: mucho GPT → invertir en militares, no en más oro.
			if gpt < w.gold_urg_late_t0:  return w.gold_urg_late_v0
			if gpt < w.gold_urg_late_t1:  return w.gold_urg_late_v1
			if gpt < w.gold_urg_late_t2:  return w.gold_urg_late_v2
			if gpt < w.gold_urg_late_t3:  return w.gold_urg_late_v3
			if gpt < w.gold_urg_late_t4:  return w.gold_urg_late_v4
			if gpt < w.gold_urg_late_t5:  return w.gold_urg_late_v5
			if gpt < w.gold_urg_late_t6:  return w.gold_urg_late_v6
			return w.gold_urg_late_v7   # gpt ≥ 2000: oro abundante, la economía ya no es la prioridad


## Urgencia de comida: cuánto necesitamos mejorar el balance de food.
## En mid game el margen debe ser mayor porque cada Town cuesta -5 food.
static func _food_urgency(food: int, phase: AIGamePhase.Phase,
		w: HeuristicWeights = null) -> float:
	if w == null: w = HeuristicWeights.get_default()
	match phase:
		AIGamePhase.Phase.EARLY:
			if food < w.food_urg_early_t0: return w.food_urg_early_v0
			if food < w.food_urg_early_t1: return w.food_urg_early_v1
			if food < w.food_urg_early_t2: return w.food_urg_early_v2
			return w.food_urg_early_v3
		AIGamePhase.Phase.MID:
			if food < w.food_urg_mid_t0:  return w.food_urg_mid_v0
			if food < w.food_urg_mid_t1:  return w.food_urg_mid_v1
			if food < w.food_urg_mid_t2:  return w.food_urg_mid_v2
			return w.food_urg_mid_v3
		_: # LATE
			if food < w.food_urg_late_t0:  return w.food_urg_late_v0
			if food < w.food_urg_late_t1:  return w.food_urg_late_v1
			if food < w.food_urg_late_t2:  return w.food_urg_late_v2
			return w.food_urg_late_v3


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

	var w := ctx.get_weights()
	var base := w.mil_urg_base_idle
	if has_active_front:    base = w.mil_urg_base_active
	elif has_adjacent_enemy: base = w.mil_urg_base_adjacent

	var pressure := _max_front_pressure(ctx)
	return lerpf(base, w.mil_urg_max, pressure)


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
		var pressure := clampf(-ai_marker / front.threshold, 0.0, 1.0)
		max_p = maxf(max_p, pressure)
	return max_p


## Urgencia de mazo: cuánto necesitamos más cartas disponibles.
static func _deck_urgency(ctx: AITurnContext) -> float:
	var w := ctx.get_weights()
	var draw_size := ctx.stats.draw_pile.cards.size() if ctx.stats.draw_pile else 0
	if draw_size < w.deck_urg_t0: return w.deck_urg_v0
	if draw_size < w.deck_urg_t1: return w.deck_urg_v1
	return w.deck_urg_v2


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
	var w := ctx.get_weights()
	if ctx.stats == null or ctx.stats.food < w.surplus_min_food:
		return 1.0
	var gpt := ctx.stats.gold_per_turn
	var comfortable_gpt: float
	match phase:
		AIGamePhase.Phase.EARLY: comfortable_gpt = w.surplus_comfortable_early
		AIGamePhase.Phase.MID:   comfortable_gpt = w.surplus_comfortable_mid
		_:                       comfortable_gpt = w.surplus_comfortable_late  # LATE: alineado con el umbral de entrada a LATE
	if gpt <= comfortable_gpt:
		return 1.0
	# 1.0 en el umbral → surplus_max cuando gpt duplica ese umbral
	return lerpf(1.0, w.surplus_max, clampf(float(gpt - comfortable_gpt) / comfortable_gpt, 0.0, 1.0))


## Factor de presión expansionista [0.0, 1.0] basado en tiles colonizables
## adyacentes al territorio actual. Independiente de la fase (turno).
## 1.0 = muchas tiles libres alrededor (expansión plena)
## 0.0 = sin tiles colonizables (mapa saturado)
## Cuando colonizable_tiles_count == -1 (tests sin mapa) → 0.5 neutro.
static func _expansion_factor(ctx: AITurnContext) -> float:
	var w := ctx.get_weights()
	var avail := ctx.colonizable_tiles_count
	if avail < 0:   # desconocido / test sin mapa
		return w.expansion_unknown
	if avail == 0:
		return 0.0
	# expansion_reference+ tiles adyacentes = presión expansionista máxima
	return minf(float(avail) / w.expansion_reference, 1.0)



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
		phase: AIGamePhase.Phase) -> float:
	if option.building == null:
		return 0.0
	var b := option.building
	var w := ctx.get_weights()
	var gu := ctx._cache_gu if ctx._cache_valid else _gold_urgency(ctx.stats.gold_per_turn, phase, w)
	var fu := ctx._cache_fu if ctx._cache_valid else _food_urgency(ctx.stats.food, phase, w)
	var mu := ctx._cache_mu if ctx._cache_valid else _military_urgency(ctx, phase)
	# Los edificios con mantenimiento (gold_produced < 0) reciben un peso reducido
	# para evitar que el coste anule el valor estratégico de sus efectos.
	var gold_weight := w.gold_weight_pos if b.gold_produced >= 0 else w.gold_weight_maint
	var score := b.gold_produced * gold_weight * gu \
		 + b.food_produced * w.food_weight * fu \
		 + b.flat_defense_bonus * w.defense_weight * mu \
		 + _score_building_effects(b.effects, ctx, phase)
	score *= _build_cost_factor(b.get_effective_construction_cost(ctx.stats), ctx.stats.total_gold, w)

	# D2: tie-breaker por tile concreta — desempata entre el mismo edificio en N tiles.
	var tile := option.targets[0] as Tile if not option.targets.is_empty() else null
	if tile != null:
		# Micro-bonus si el edificio explota el recurso natural de esta tile específica.
		if b.required_natural_resource != null \
				and b.required_natural_resource == tile.natural_resource:
			score += w.build_resource_match
		# Micro-bonus por posición fronteriza (valor defensivo/estratégico).
		for nb in tile.neighbors:
			var nt := nb as Tile
			if nt != null and nt.controller != null \
					and nt.controller != ctx.stats.empire:
				score += w.build_border
				break

	return score


static func _score_upgrade(option: AIUpgradeBuildingOption, ctx: AITurnContext,
		phase: AIGamePhase.Phase) -> float:
	if option.old_building == null or option.new_building == null:
		return 0.0
	var w := ctx.get_weights()
	var gu := ctx._cache_gu if ctx._cache_valid else _gold_urgency(ctx.stats.gold_per_turn, phase, w)
	var fu := ctx._cache_fu if ctx._cache_valid else _food_urgency(ctx.stats.food, phase, w)
	var mu := ctx._cache_mu if ctx._cache_valid else _military_urgency(ctx, phase)
	var dg := option.new_building.gold_produced - option.old_building.gold_produced
	var df := option.new_building.food_produced - option.old_building.food_produced
	var dd := option.new_building.flat_defense_bonus - option.old_building.flat_defense_bonus
	var dg_weight := w.gold_weight_pos if dg >= 0 else w.gold_weight_maint
	var score := dg * dg_weight * gu + df * w.food_weight * fu + dd * w.defense_weight * mu \
		 + _score_building_effects(option.new_building.effects, ctx, phase) \
		 - _score_building_effects(option.old_building.effects, ctx, phase)
	return score * _build_cost_factor(
		option.new_building.get_effective_construction_cost(ctx.stats), ctx.stats.total_gold, w)


static func _score_recruit(option: AIRecruitOption, ctx: AITurnContext,
		phase: AIGamePhase.Phase) -> float:
	if option.troop == null:
		return 0.0
	var w := ctx.get_weights()
	# No reclutar si el mantenimiento hundiría la comida o el gpt en negativo.
	# ctx.stats.food y gold_per_turn ya incluyen el mantenimiento actual;
	# restamos el coste adicional de esta tropa para ver el estado resultante.
	if ctx.stats.food - option.troop.maintenance_food < w.recruit_food_veto_margin:
		return w.recruit_veto_score
	if ctx.stats.gold_per_turn - option.troop.maintenance_gold < 0:
		return w.recruit_veto_score

	# D6b: proyección de recargo cuadrático de frente.
	# Con n tropas en un bando el coste es 5·n·(n+1)/2 de comida/turno.
	# Si hay frentes activos y la nueva tropa aumentaría el recargo hasta
	# dejar la comida por debajo del margen de seguridad, vetar el reclutamiento.
	var fronts := ctx._cache_active_fronts if ctx._cache_valid \
		else _get_own_active_fronts(ctx)
	if not fronts.is_empty():
		var max_own_troops := 0
		for front in fronts:
			var is_att := front.attacker_empire == ctx.stats.empire
			var is_def := front.defender_empire == ctx.stats.empire
			if not is_att and not is_def:
				continue
			var side_troops: Array[Troop] = front.attacker_troops if is_att else front.defender_troops
			max_own_troops = maxi(max_own_troops, side_troops.size())
		var n_after := max_own_troops + 1
		var n_before := max_own_troops
		var delta_charge := w.recruit_front_charge_per_troop * n_after * (n_after + 1) / 2.0 \
						  - w.recruit_front_charge_per_troop * n_before * (n_before + 1) / 2.0
		if ctx.stats.food - delta_charge < w.recruit_front_food_margin:
			return w.recruit_veto_score
	var mu := ctx._cache_mu if ctx._cache_valid else _military_urgency(ctx, phase)
	var comp := _complement_bonus(option.troop, ctx.stats.troop_pool, ctx)
	# Rendimiento decreciente: pool grande (sin frentes) reduce el valor de seguir reclutando.
	# 0 tropas → ×1.0 | 25 tropas → ×0.5 | 50 tropas → ×0.33
	var saturation := 1.0 / (1.0 + ctx.stats.troop_pool.size() * w.recruit_saturation_k)
	var surplus := ctx._cache_surplus if ctx._cache_valid else _resource_surplus_factor(ctx, phase)
	# Factor de coste-eficiencia: favorece tropas baratas relativas al precio base.
	# maxi(..., 1) evita división por cero con tropas de test que tienen coste = 0.
	var cost_eff := sqrt(w.recruit_cost_eff_base / float(maxi(option.troop.recruitment_cost_gold, 1)))
	# Penalización por saturación de tipo: evita monocultura.
	# 0 de ese tipo → ×1.0 | 5 de ese tipo → ×0.50 | 10 de ese tipo → ×0.33
	var type_count := 0
	for t in ctx.stats.troop_pool:
		if t.type == option.troop.type:
			type_count += 1
	var type_diversity := 1.0 / (1.0 + float(type_count) * w.recruit_type_diversity_k)
	return float(option.troop.attack + option.troop.defense) * w.recruit_atkdef_weight * mu * comp * saturation * surplus * cost_eff * type_diversity


## Bonus de complementariedad: favorece tropas que equilibran el pool actual
## y además contrarrestan la composición visible del rival en frentes activos.
## ctx puede ser null (tests o llamadas sin info de rival → solo balance interno).
static func _complement_bonus(troop: Troop, pool: Array[Troop],
		ctx: AITurnContext = null) -> float:
	var w := ctx.get_weights() if ctx != null else HeuristicWeights.get_default()
	# Base: balance atk/def del pool propio.
	var base_bonus := 1.0
	if not pool.is_empty():
		var total_atk := 0
		var total_def := 0
		for t in pool:
			total_atk += t.attack
			total_def += t.defense
		var pool_ratio := float(total_atk) / maxf(float(total_def), 1.0)
		var troop_ratio := float(troop.attack) / maxf(float(troop.defense), 1.0)
		if pool_ratio > w.complement_pool_hi and troop_ratio < w.complement_troop_lo:   base_bonus = w.complement_bonus_hi
		elif pool_ratio > w.complement_pool_mid and troop_ratio < w.complement_troop_mid: base_bonus = w.complement_bonus_mid
		elif pool_ratio < w.complement_pool_lo and troop_ratio > w.complement_troop_hi: base_bonus = w.complement_bonus_hi
		elif pool_ratio < w.complement_pool_lomid and troop_ratio > w.complement_troop_mid: base_bonus = w.complement_bonus_mid

	# D7: counter-bonus — si esta tropa es FUERTE contra algún tipo visible del rival.
	# Usa TroopEffectiveness para no duplicar la tabla de matchups.
	var counter_bonus := 1.0
	if ctx != null and ctx.world_view != null:
		var rival := ctx.world_view.get_rival_view()
		if rival != null and rival.empire != null:
			# Recolectar tipos de tropa del rival visibles en frentes activos.
			var all_fronts := ctx._cache_active_fronts if ctx._cache_valid \
				else BattleFront.get_active_instances()
			var rival_types: Array[int] = []
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
			# Aplicar counter_bonus si esta tropa tiene ventaja (×1.5) contra algún tipo.
			for rt in rival_types:
				if TroopEffectiveness.get_multiplier(troop.type, rt) \
						>= TroopEffectiveness.MULTIPLIER_STRONG:
					counter_bonus = w.counter_bonus
					break

	return base_bonus * counter_bonus


static func _score_open_front(option: AIOpenFrontOption, ctx: AITurnContext,
		phase: AIGamePhase.Phase) -> float:
	if option.enemy_tile == null:
		return 0.0

	# Sin tropas libres no tiene sentido abrir un frente: nadie lo defiende.
	# troop_pool contiene solo las tropas NO asignadas a frentes activos.
	var free_troops := ctx.stats.troop_pool.size()
	if free_troops == 0:
		return 0.0
	var w := ctx.get_weights()
	# Con pocas tropas el score se reduce; con muchas se amplifica (agresividad).
	# 3 tropas → ×0.5 | 6 tropas → ×1.0 | 9+ tropas → ×1.5 (capped)
	var pool_factor := clampf(float(free_troops) / w.openfront_pool_divisor, 0.0, w.openfront_pool_cap)

	var enemy := option.enemy_tile
	var gold_val := 0
	var food_val := 0
	if enemy.natural_resource != null:
		gold_val = enemy.natural_resource.gold_produced
		food_val = enemy.natural_resource.food_produced

	var mu := ctx._cache_mu if ctx._cache_valid else _military_urgency(ctx, phase)
	# Valor base territorial: evita que tiles sin producción directa (Salt, Iron,
	# Stone, Sand…) puntúen 0 y PASS gane por empate en _pick_best_option.
	var base_strategic := w.openfront_base_strategic + mu * w.openfront_base_mu
	var tile_val := gold_val * w.openfront_gold + food_val * w.openfront_food + base_strategic

	# Abrir un frente añade recargos de oro Y comida cada turno.
	# Si ya estamos ajustados en cualquiera de los dos, es muy arriesgado.
	var gpt := ctx.stats.gold_per_turn
	var food := ctx.stats.food
	var econ_safety := 1.0
	if gpt < 0 or food < 0:
		econ_safety = w.openfront_econ_unsafe
	else:
		match phase:
			AIGamePhase.Phase.EARLY:
				if gpt < w.openfront_econ_early_gpt or food < w.openfront_econ_early_food: econ_safety = w.openfront_econ_caution
			AIGamePhase.Phase.MID:
				if gpt < w.openfront_econ_mid_gpt or food < w.openfront_econ_mid_food: econ_safety = w.openfront_econ_caution
			AIGamePhase.Phase.LATE:
				if gpt < w.openfront_econ_late_gpt or food < w.openfront_econ_late_food: econ_safety = w.openfront_econ_caution

	var biome_factor := _attack_biome_factor(enemy)
	var surplus := ctx._cache_surplus if ctx._cache_valid else _resource_surplus_factor(ctx, phase)

	# D4: estimación de ganabilidad basada en info pública del rival.
	# win_factor = P(ganar este frente) estimada según ataque propio vs defensa visible.
	var win_factor := w.openfront_win_default  # default neutro (leve ventaja del atacante por elegir cuándo/dónde)
	if ctx.world_view != null:
		var rival := ctx.world_view.get_rival_view()
		if rival != null and rival.empire != null:
			# Ataque propio: suma de fuerza de tropas libres × bioma de ataque.
			var own_atk := 0.0
			for t in ctx.stats.troop_pool:
				own_atk += float(t.attack)
			own_atk *= biome_factor

			# Defensa del rival: edificios defensivos + bioma de la tile enemiga.
			var rival_def := 0.0
			for b in enemy.buildings:
				if b != null:
					rival_def += float(b.flat_defense_bonus)
			if enemy.mesh_data != null:
				rival_def *= _get_biome_cfg().get_defense_multiplier(enemy.mesh_data.type)
			# Tropas del rival ya asignadas a un frente en esa tile (visibles).
			var all_fronts := ctx._cache_active_fronts if ctx._cache_valid \
				else BattleFront.get_active_instances()
			for front in all_fronts:
				if front.is_resolved:
					continue
				if front.defender_tile == enemy \
						and front.defender_empire == rival.empire:
					for t in front.defender_troops:
						rival_def += float(t.defense)
					break

			if own_atk + rival_def > 0.0:
				var ratio := own_atk / maxf(rival_def, 1.0)
				win_factor = clampf(ratio / (ratio + 1.0), w.openfront_win_min, w.openfront_win_max)
			else:
				win_factor = w.openfront_win_neutral

	# Valor de la tile origen (riesgo del atacante si pierde el frente).
	var source_value := 0.0
	var source := option.source_tile
	if source != null:
		source_value = float(source.buildings.size()) * w.openfront_source_building
		if source.natural_resource != null:
			source_value += source.natural_resource.gold_produced * w.openfront_source_gold \
						  + source.natural_resource.food_produced * w.openfront_source_food

	# D2+D4+D3a: score final integra ganabilidad, riesgo de origen y carrera territorial.
	# P(win)×valor_enemigo − P(lose)×valor_origen captura el riesgo/beneficio real.
	return (tile_val * win_factor - source_value * (1.0 - win_factor)) \
		* econ_safety * mu * biome_factor * pool_factor * surplus \
		* _territory_race_factor(ctx, &"open_front")


static func _score_tactic(option: AITacticOption, ctx: AITurnContext,
		phase: AIGamePhase.Phase) -> float:
	if option.front == null:
		return 0.0
	var tactic := option.card as TacticCard
	var is_attacker := option.front.attacker_empire == ctx.stats.empire
	var own_troops: Array[Troop] = option.front.attacker_troops \
		if is_attacker else option.front.defender_troops

	# D1: si la carta especifica tipos concretos, comprobar cuántas tropas
	# del bando los cumplen. Si ninguna coincide → PASS gana.
	# Si affected_troop_types está vacío la táctica afecta a todas → ratio 1.0.
	var troop_ratio := 1.0
	if tactic != null and not tactic.affected_troop_types.is_empty():
		var affected_count := 0
		for t in own_troops:
			if t.type in tactic.affected_troop_types:
				affected_count += 1
		if affected_count == 0:
			return 0.0
		troop_ratio = float(affected_count) / float(maxi(own_troops.size(), 1))

	# Bioma relevante: ATK mira la tile enemiga, DEF la propia.
	var relevant_tile: Tile = option.front.defender_tile \
		if is_attacker else option.front.attacker_tile
	var biome_mod := 1.0
	if tactic != null and (tactic.attack_percent_per_type > 0.0 or tactic.attack_per_troop > 0.0):
		biome_mod = _attack_biome_factor(relevant_tile)

	var w := ctx.get_weights()
	var mu := ctx._cache_mu if ctx._cache_valid else _military_urgency(ctx, phase)
	var ai_marker := option.front.marker if is_attacker else -option.front.marker
	var urgency := clampf(-ai_marker / option.front.threshold, 0.0, 1.0)
	return (w.tactic_base + urgency * w.tactic_urgency_scale) * mu * troop_ratio * biome_mod


static func _score_draw(option: AIDrawCardOption, ctx: AITurnContext) -> float:
	return option.amount * ctx.get_weights().draw_weight * _deck_urgency(ctx)


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
		var w := ctx.get_weights()
		var gu := _gold_urgency(ctx.stats.gold_per_turn, phase, w)
		# Oro inmediato vale menos que gold_per_turn (es one-shot)
		return (card as GenerateGoldCard).amount * w.simple_gold_weight * gu

	if card is ChangeLocationTypeCard:
		return _score_change_location(option, ctx, phase)

	if card is DirectBuildCard:
		return _score_direct_build(option, ctx, phase)

	return 1.0  # tipo de carta desconocido: valor neutro-positivo mínimo


## Colonizar no tiene coste de food_consumption al pasar de Uncolonized a Village
## (ambos tienen food_consumption = 0). El delta es exactamente el food_production
## del recurso natural. Por eso usamos tile.food_production directamente.
static func _score_colonize(option: AIPlayOption, ctx: AITurnContext,
		phase: AIGamePhase.Phase) -> float:
	if option.targets.is_empty():
		return 0.0
	var tile := option.targets[0] as Tile
	if tile == null:
		return 0.0
	var w := ctx.get_weights()
	var gu := ctx._cache_gu if ctx._cache_valid else _gold_urgency(ctx.stats.gold_per_turn, phase, w)
	var fu := ctx._cache_fu if ctx._cache_valid else _food_urgency(ctx.stats.food, phase, w)
	# Bonus territorial: escala con la presión de expansión real (tiles adyacentes
	# libres), sin depender de la fase. En un mapa grande con muchas tiles libres
	# el bonus sigue siendo alto aunque el número de turno sea elevado.
	# 0.0 cuando no hay tiles (PASS dominará); colonize_expansion cuando hay muchas (max bonus).
	var expansion_bonus := (ctx._cache_expansion if ctx._cache_valid else _expansion_factor(ctx)) * w.colonize_expansion
	# Bonus de frontera: cada tile nueva que esta colonización desbloquea
	# puntúa extra, escalado por la presión de encierro. Las tiles que abren
	# corredores hacia espacio libre dominan a las que solo rellenan huecos.
	var frontier_bonus := float(_frontier_value(tile, ctx)) * _encirclement_pressure(ctx)

	# D3b: bonus de negación — colonizar una tile adyacente al rival reduce su
	# espacio de expansión (suma cero territorial). Amplificado en modo cierre.
	var denial_bonus := 0.0
	if ctx.world_view != null:
		var rival := ctx.world_view.get_rival_view()
		if rival != null and rival.empire != null:
			for nb in tile.neighbors:
				var nt := nb as Tile
				if nt != null and nt.controller == rival.empire:
					denial_bonus = w.colonize_denial
					break

	# D3a: escalar toda la colonización según la carrera territorial.
	var base_score := tile.gold_production * w.colonize_gold * gu \
		 + tile.food_production * w.colonize_food * fu \
		 + expansion_bonus \
		 + frontier_bonus \
		 + denial_bonus
	return base_score * _territory_race_factor(ctx, &"colonize")


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
	if ctx.stats == null or ctx.stats.empire == null:
		return w.encircle_default
	var avail := ctx.colonizable_tiles_count
	if avail < 0:
		return w.encircle_default
	var controlled := maxi(ctx.stats.empire.controlled_tiles.size(), 1)
	var ratio := float(avail) / float(controlled)
	if ratio >= w.encircle_r2: return w.encircle_high
	if ratio >= w.encircle_r1: return w.encircle_mid
	if ratio >= w.encircle_r05: return w.encircle_low
	return w.encircle_min


## Village→Town: +5 food_consumption y +2 building slots.
## Town→Megalópolis: +5 food_consumption adicional y +2 building slots más.
## El delta real de food_consumption se lee de los recursos, no está hardcodeado.
static func _score_change_location(option: AIPlayOption, ctx: AITurnContext,
		phase: AIGamePhase.Phase) -> float:
	if option.targets.is_empty():
		return 0.0
	var tile := option.targets[0] as Tile
	var card := option.card as ChangeLocationTypeCard
	if tile == null or card == null or card.location_type == null or tile.location == null:
		return 0.0

	var new_loc := card.location_type
	var old_loc := tile.location
	var delta_consumption := new_loc.food_consumption - old_loc.food_consumption
	var delta_slots     := new_loc.max_building  - old_loc.max_building

	var w := ctx.get_weights()
	# Veto duro: la comida resultante no puede ser negativa.
	var new_food := ctx.stats.food - delta_consumption
	if new_food < 0:
		return w.changeloc_veto

	var gu := ctx._cache_gu if ctx._cache_valid else _gold_urgency(ctx.stats.gold_per_turn, phase, w)
	var fu := ctx._cache_fu if ctx._cache_valid else _food_urgency(ctx.stats.food, phase, w)
	var mu := ctx._cache_mu if ctx._cache_valid else _military_urgency(ctx, phase)

	# --- 1. Penalización por edificios que serán demolidos ---
	# Un edificio se destruye si su allowed_location_type no está vacío
	# y no incluye el nuevo tipo (replica lógica de ChangeLocationTypeEffect).
	var demolished_penalty := 0.0
	var resource_building_survives := false
	for building in tile.buildings:
		if building == null:
			continue
		if _building_demolished_by(building, new_loc):
			# Penalizar por el valor económico que se pierde con la demolición.
			demolished_penalty += building.gold_produced * w.changeloc_demo_gold * gu \
								+ building.food_produced * w.changeloc_demo_food * fu \
								+ float(building.flat_defense_bonus) * w.changeloc_demo_defense
		else:
			# El edificio sobrevive: ¿explota el recurso natural de la tile
			# y además es una versión mejorada (no el edificio base)?
			if _is_upgraded_resource_building(building, tile, ctx):
				resource_building_survives = true

	# --- 2. Bonus por edificio de recurso mejorado que sobrevive al upgrade ---
	# Si ese edificio se demoliera, el bonus no aplica (cubierto en demolished_penalty).
	var resource_bonus := w.changeloc_resource_bonus if resource_building_survives else 0.0

	# --- 3. Bonus por edificios desbloqueados en el nuevo tier ---
	# Solo cuenta los que NO se podían construir en old_loc pero sí en new_loc,
	# ponderados por las necesidades actuales del imperio.
	var unlock_bonus := _score_unlocked_buildings(tile, old_loc, new_loc, ctx, gu, fu, mu)

	# --- 4. Score base: slots nuevos vs coste en comida ---
	var base := delta_slots * w.changeloc_slot \
			  - delta_consumption * w.changeloc_consumption * _food_urgency(new_food, phase, w)

	return base - demolished_penalty + resource_bonus + unlock_bonus


static func _score_direct_build(option: AIPlayOption, ctx: AITurnContext,
		phase: AIGamePhase.Phase) -> float:
	var card := option.card as DirectBuildCard
	if card == null or card.buildings.is_empty() or card.buildings[0] == null:
		return 0.0
	var b := card.buildings[0]
	var w := ctx.get_weights()
	var gu := ctx._cache_gu if ctx._cache_valid else _gold_urgency(ctx.stats.gold_per_turn, phase, w)
	var fu := ctx._cache_fu if ctx._cache_valid else _food_urgency(ctx.stats.food, phase, w)
	var mu := ctx._cache_mu if ctx._cache_valid else _military_urgency(ctx, phase)
	var gold_weight := w.gold_weight_pos if b.gold_produced >= 0 else w.gold_weight_maint
	var score := b.gold_produced * gold_weight * gu \
		 + b.food_produced * w.food_weight * fu \
		 + b.flat_defense_bonus * w.defense_weight * mu \
		 + _score_building_effects(b.effects, ctx, phase)
	return score * _build_cost_factor(b.get_effective_construction_cost(ctx.stats), ctx.stats.total_gold, w)


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
			var pct := (effect as AddBuildCostModifierEffect).percent
			match phase:
				AIGamePhase.Phase.EARLY: score += pct * w.bce_buildcost_early
				AIGamePhase.Phase.MID:   score += pct * w.bce_buildcost_mid
				_:                       score += pct * w.bce_buildcost_late
		elif effect is AddCardToDeckEffect:
			var card_added := (effect as AddCardToDeckEffect).card
			if card_added != null:
				score += score_card_for_deck(card_added, ctx)
		elif effect is GoldOnCard:
			# Frecuencia desconocida: estimación conservadora (~3 plays/turno).
			score += (effect as GoldOnCard).gold_reward * w.bce_gold_on_card * gu
	return score


## Traduce un AddStatModifierEffect a un score usando las escalas de urgencia.
static func _score_stat_effect(effect: AddStatModifierEffect,
		ctx: AITurnContext, gu: float, fu: float, mu: float) -> float:
	var w := ctx.get_weights()
	var v := effect.value
	match effect.stat_type:
		StatModifier.StatType.FLAT_GOLD:
			return v * w.se_flat_gold * gu
		StatModifier.StatType.PERCENT_GOLD:
			return ctx.stats.gold_per_turn * v / 100.0 * w.se_percent_gold * gu
		StatModifier.StatType.FLAT_FOOD:
			return v * w.se_flat_food * fu
		StatModifier.StatType.PERCENT_FOOD:
			return ctx.stats.food * v / 100.0 * w.se_percent_food * fu
		StatModifier.StatType.TILE_RESOURCE_GOLD:
			return v * w.se_tile_gold * gu
		StatModifier.StatType.TILE_RESOURCE_FOOD:
			return v * w.se_tile_food * fu
		StatModifier.StatType.CARDS_PER_TURN:
			# D8: carta extra por turno como valor de FLUJO, no de estado.
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
			# horizon: hi (muy lejos de ganar) → lo (a punto de ganar al 70%)
			var horizon := lerpf(w.se_cpt_horizon_lo, w.se_cpt_horizon_hi,
				clampf(1.0 - my_share_h / w.se_cpt_share_target, 0.0, 1.0))
			return v * (w.se_cpt_base + horizon * w.se_cpt_horizon_scale)
			# Ejemplos: horizon=40 → v*32 | horizon=20 → v*20 | horizon=5 → v*11
		StatModifier.StatType.CARD_DRAW_BONUS:
			return v * w.se_card_draw
		StatModifier.StatType.TROOPS_PER_RECRUIT:
			# Escalado lineal con urgencia militar, con rendimiento decreciente SUAVE
			# según el bonus de throughput ya acumulado en el empire.
			# Los primeros cuarteles tienen valor pleno; a partir del 5.º baja gradualmente.
			# 0 bonus → ×1.0 | 4 bonus → ×0.55 | 8 bonus → ×0.38 | 12 bonus → ×0.29
			var current_bonus := _current_troops_per_recruit_bonus(ctx)
			var dr_factor := 1.0 / (1.0 + float(current_bonus) * w.se_tpr_dr_k)
			return v * (w.se_tpr_base + w.se_tpr_mu * mu) * dr_factor
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT:
			return ctx.stats.troop_pool.size() * absf(v) * w.se_maint * mu
	return 0.0


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
	var w := ctx.get_weights()
	var my_tiles := ctx.stats.empire.controlled_tiles.size() \
		if ctx.stats.empire != null else 0
	var rival_tiles := rival.empire.controlled_tiles.size()
	var colonizable := maxi(ctx.colonizable_tiles_count, 0)
	var total := maxi(my_tiles + rival_tiles + colonizable, 1)
	var my_share := float(my_tiles) / float(total)
	var rival_share := float(rival_tiles) / float(total)

	if mode == &"colonize" or mode == &"open_front":
		if my_share >= w.tr_close_share:
			return w.tr_close_factor  # modo cierre: escalar todo lo que acerca al 70%
		if my_share >= w.tr_lead_share:
			return w.tr_lead_factor
		if rival_share >= w.tr_block_share:
			return w.tr_block_factor  # modo bloqueo: el rival se acerca al límite de victoria
	elif mode == &"economy":
		if my_share >= w.tr_close_share:
			return w.tr_econ_factor  # con ventaja territorial, la economía importa menos
	return 1.0


## Factor de coste: penaliza edificios que consumen una fracción alta del oro.
## Rango build_cost_min (gasto total) → 1.0 (gasto residual). Suaviza la
## preferencia por edificios baratos cuando el gold disponible es ajustado.
static func _build_cost_factor(cost: int, total_gold: int,
		w: HeuristicWeights = null) -> float:
	if w == null: w = HeuristicWeights.get_default()
	if total_gold <= 0:
		return w.build_cost_min
	return lerpf(1.0, w.build_cost_min, clampf(float(cost) / float(total_gold), 0.0, 1.0))


## Multiplicador de dificultad de ataque según el bioma de la tile enemiga.
## Montaña 0.60, Pantano 0.70, Bosque 0.80 … Pradera 1.20.
static func _attack_biome_factor(tile: Tile) -> float:
	if tile == null or tile.mesh_data == null:
		return 1.0
	return _get_biome_cfg().get_attack_multiplier(tile.mesh_data.type)


static var _biome_cfg: BiomeConfig = null

static func _get_biome_cfg() -> BiomeConfig:
	if _biome_cfg == null:
		_biome_cfg = BiomeConfig.new()
	return _biome_cfg


# ---------------------------------------------------------------------------
# API para MCTS (Fase 3)
# ---------------------------------------------------------------------------

## Evaluación diferencial de ESTADO para SO-ISMCTS: [-1.0, 1.0] via tanh.
## +1.0 = victoria segura propia | -1.0 = derrota segura.
## Condiciones terminales se resuelven antes de aplicar pesos.
## Pesos por fase (datos empíricos de 80 sims):
##   EARLY: territorio 40%, economía 40%, militar 15%, mazo 5%
##   MID:   territorio 30%, economía 35%, militar 25%, mazo 10%
##   LATE:  territorio 30%, economía 20%, militar 40%, mazo 10%
static func score_state(own_stats: Stats, world_view: AIWorldView,
		total_map_tiles: int = 0, w: HeuristicWeights = null) -> float:
	if own_stats == null or own_stats.empire == null:
		return 0.0
	if w == null: w = HeuristicWeights.get_default()

	var rival := world_view.get_rival_view() if world_view != null else null
	var my_tiles := own_stats.empire.controlled_tiles.size()
	var rival_tiles := rival.empire.controlled_tiles.size() \
		if rival != null and rival.empire != null else 0
	var total := maxi(total_map_tiles, my_tiles + rival_tiles + 1)
	var my_share := float(my_tiles) / float(total)
	var rival_share := float(rival_tiles) / float(total)

	# Condiciones terminales.
	if my_share >= w.state_victory_share: return 1.0
	if rival_share >= w.state_victory_share: return -1.0
	if rival_tiles == 0: return 1.0
	if my_tiles == 0: return -1.0

	var phase := AIGamePhase.detect(own_stats, total_map_tiles)

	var w_t := w.state_w_t_early; var w_e := w.state_w_e_early
	var w_m := w.state_w_m_early; var w_k := w.state_w_k_early
	match phase:
		AIGamePhase.Phase.MID:
			w_t = w.state_w_t_mid; w_e = w.state_w_e_mid; w_m = w.state_w_m_mid; w_k = w.state_w_k_mid
		AIGamePhase.Phase.LATE:
			w_t = w.state_w_t_late; w_e = w.state_w_e_late; w_m = w.state_w_m_late; w_k = w.state_w_k_late

	# Dimensión territorial: diferencial normalizado por umbral de victoria.
	var t_score := (my_share - rival_share) / w.state_t_norm

	# Dimensión económica: GPT diferencial + estabilidad de comida.
	var my_gpt := own_stats.gold_per_turn
	var rival_gpt := rival.gold_per_turn if rival != null else 0
	var e_score := clampf(float(my_gpt - rival_gpt) / w.state_e_norm, -1.0, 1.0)
	var food_stability := clampf(float(own_stats.food) / w.state_food_norm, -1.0, w.state_food_stability_cap)

	# Dimensión militar: poder de tropas propias vs tropas visibles del rival.
	var my_power := 0.0
	for t in own_stats.troop_pool:
		my_power += float(t.attack + t.defense)
	var rival_power := 0.0
	if rival != null and rival.empire != null:
		for front in BattleFront.get_active_instances():
			if front == null or front.is_resolved:
				continue
			if front.attacker_empire != rival.empire \
					and front.defender_empire != rival.empire:
				continue
			var rt: Array[Troop] = front.attacker_troops \
				if front.attacker_empire == rival.empire else front.defender_troops
			for t in rt:
				rival_power += float(t.attack + t.defense)
	var m_score := clampf((my_power - rival_power) / w.state_m_norm, -1.0, 1.0)

	# Dimensión de mazo: cartas/turno diferencial.
	var my_cpt := own_stats.cards_per_turn
	var rival_cpt := rival.hand_size if rival != null else int(w.state_rival_cpt_default)
	var k_score := clampf(float(my_cpt - rival_cpt) / w.state_k_norm, -1.0, 1.0)

	var raw := w_t * t_score \
			 + w_e * (e_score + food_stability * w.state_food_stability_weight) \
			 + w_m * m_score \
			 + w_k * k_score

	return tanh(raw * w.state_tanh_scale)


## Selecciona una opción usando muestreo softmax sobre los scores.
## temperature = 0 → argmax determinista (igual que _pick_best_option).
## temperature > 0 → distribución ponderada (exploración en rollouts MCTS).
## top_k: considerar solo las top_k opciones por score antes del muestreo.
static func pick_option_softmax(options: Array[AIPlayOption],
		ctx: AITurnContext, temperature: float = 0.3,
		top_k: int = 10, rng: RandomNumberGenerator = null) -> AIPlayOption:
	if options.is_empty():
		return null

	# Puntuar y ordenar descendente.
	var scored: Array[Dictionary] = []
	for opt in options:
		scored.append({"option": opt, "score": score_option(opt, ctx)})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["score"] > b["score"])

	if scored.size() > top_k:
		scored = scored.slice(0, top_k)

	if temperature <= 0.0:
		return scored[0]["option"]

	# Softmax estabilizado: shift por max_score evita overflow en exp().
	var max_score: float = scored[0]["score"]
	var weights: Array[float] = []
	var total_weight := 0.0
	for entry in scored:
		var w := exp((entry["score"] - max_score) / temperature)
		weights.append(w)
		total_weight += w

	# Muestreo por inversión de CDF.
	var r := (rng.randf() if rng != null else randf()) * total_weight
	var cum := 0.0
	for i in range(weights.size()):
		cum += weights[i]
		if r <= cum:
			return scored[i]["option"]

	return scored[0]["option"]
