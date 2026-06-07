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

	var phase := AIGamePhase.detect(ctx.stats)

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
# Señales de urgencia
# ---------------------------------------------------------------------------

## Urgencia de oro: cuánto necesitamos mejorar el gold_per_turn ahora.
## Los umbrales son distintos por fase: 50 gpt es crisis en mid game pero
## holgado en early (los edificios básicos cuestan 50-100, los upgrades 200-400,
## los lategame hasta 800).
static func _gold_urgency(gpt: int, phase: AIGamePhase.Phase) -> float:
	match phase:
		AIGamePhase.Phase.EARLY:
			if gpt < 10:  return 3.0
			if gpt < 30:  return 1.8
			if gpt < 60:  return 1.0
			return 0.7
		AIGamePhase.Phase.MID:
			# Target mid: 300-400 gpt para construir/mejorar cada turno
			if gpt < 50:  return 3.0
			if gpt < 150: return 2.0
			if gpt < 250: return 1.3
			if gpt < 400: return 1.0
			return 0.7
		_: # LATE
			# En late queda poco que construir; el superávit importa menos
			if gpt < 0:   return 3.0
			if gpt < 50:  return 2.0
			if gpt < 100: return 1.3
			if gpt < 200: return 1.0
			return 0.8


## Urgencia de comida: cuánto necesitamos mejorar el balance de food.
## En mid game el margen debe ser mayor porque cada Town cuesta -5 food.
static func _food_urgency(food: int, phase: AIGamePhase.Phase) -> float:
	match phase:
		AIGamePhase.Phase.EARLY:
			if food < 0: return 3.0
			if food < 2: return 1.8
			if food < 5: return 1.0
			return 0.8
		AIGamePhase.Phase.MID:
			if food < 0:  return 3.0
			if food < 5:  return 2.0
			if food < 10: return 1.2
			return 1.0
		_: # LATE
			if food < 0:  return 3.0
			if food < 5:  return 2.0
			if food < 10: return 1.2
			return 1.0


## Urgencia militar: combina un baseline según la amenaza real con la
## presión de frentes activos. El baseline ya no depende del turno/fase,
## sino del estado militar concreto (enemigos adyacentes, frentes activos).
static func _military_urgency(ctx: AITurnContext, _phase: AIGamePhase.Phase) -> float:
	# Detectar si hay un frente activo en el que participa el empire.
	var has_active_front := false
	if ctx.stats != null and ctx.stats.empire != null:
		for front in BattleFront.get_active_instances():
			if front == null or front.is_resolved:
				continue
			if front.attacker_empire == ctx.stats.empire \
					or front.defender_empire == ctx.stats.empire:
				has_active_front = true
				break

	# Detectar si hay un empire enemigo adyacente al territorio.
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

	# Baseline según amenaza observable, no según el número de turno.
	var base := 0.4   # sin amenazas conocidas: prioridad militar baja
	if has_active_front:
		base = 1.5    # conflicto activo: alta prioridad militar
	elif has_adjacent_enemy:
		base = 0.9    # enemigo fronterizo: amenaza potencial inminente

	var pressure := _max_front_pressure(ctx)
	return lerpf(base, 3.0, pressure)


## Devuelve la presión máxima de los frentes donde participa la IA (0.0–1.0).
## Presión = qué tan cerca estamos de perder el frente más comprometido.
static func _max_front_pressure(ctx: AITurnContext) -> float:
	var max_p := 0.0
	for front in BattleFront.get_active_instances():
		if front == null or front.is_resolved:
			continue
		var is_attacker := front.attacker_empire == ctx.stats.empire
		var is_defender := front.defender_empire == ctx.stats.empire
		if not is_attacker and not is_defender:
			continue
		# ai_marker > 0 → ganando; ai_marker < 0 → perdiendo
		var ai_marker := front.marker if is_attacker else -front.marker
		var pressure := clampf(-ai_marker / front.threshold, 0.0, 1.0)
		max_p = maxf(max_p, pressure)
	return max_p


## Urgencia de mazo: cuánto necesitamos más cartas disponibles.
static func _deck_urgency(ctx: AITurnContext) -> float:
	var draw_size := ctx.stats.draw_pile.cards.size() if ctx.stats.draw_pile else 0
	if draw_size < 3: return 2.0
	if draw_size < 6: return 1.4
	return 1.0


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
	return clampf(1.0 / float(_card_type_count(card, ctx)), 0.25, 1.0)


## Factor de excedente económico [1.0, 3.0].
## Cuando el empire tiene oro y comida muy por encima de los umbrales cómodos
## para su fase, el coste de oportunidad de reclutar o abrir frentes es mínimo
## y estas acciones se potencian. Requiere food >= 5 (sin margen de comida no
## se pueden sostener tropas aunque el oro sobre).
static func _resource_surplus_factor(ctx: AITurnContext, phase: AIGamePhase.Phase) -> float:
	if ctx.stats == null or ctx.stats.food < 5:
		return 1.0
	var gpt := ctx.stats.gold_per_turn
	var comfortable_gpt: int
	match phase:
		AIGamePhase.Phase.EARLY: comfortable_gpt = 80
		AIGamePhase.Phase.MID:   comfortable_gpt = 200
		_:                       comfortable_gpt = 350  # LATE: alineado con el umbral de entrada a LATE
	if gpt <= comfortable_gpt:
		return 1.0
	# 1.0 en el umbral → 3.0 cuando gpt duplica ese umbral
	return lerpf(1.0, 3.0, clampf(float(gpt - comfortable_gpt) / float(comfortable_gpt), 0.0, 1.0))


## Factor de presión expansionista [0.0, 1.0] basado en tiles colonizables
## adyacentes al territorio actual. Independiente de la fase (turno).
## 1.0 = muchas tiles libres alrededor (expansión plena)
## 0.0 = sin tiles colonizables (mapa saturado)
## Cuando colonizable_tiles_count == -1 (tests sin mapa) → 0.5 neutro.
static func _expansion_factor(ctx: AITurnContext) -> float:
	const REFERENCE := 15  # 15+ tiles adyacentes = presión expansionista máxima
	var avail := ctx.colonizable_tiles_count
	if avail < 0:   # desconocido / test sin mapa
		return 0.5
	if avail == 0:
		return 0.0
	return minf(float(avail) / float(REFERENCE), 1.0)



## Valor de adelgazar el mazo en una carta, proporcional al tamaño del mazo.
## Mazo pequeño (≤DECK_SMALL): el ciclo ya es rápido, purgar aporta poco.
## Mazo grande (≥DECK_LARGE): el ciclo es lento, purgar acelera las cartas clave.
static func _deck_thinning_value(ctx: AITurnContext) -> float:
	const DECK_SMALL := 5
	const DECK_LARGE := 20
	const VALUE_SMALL := 2.0  # mazo pequeño: purgar no es urgente
	const VALUE_LARGE := 9.0  # mazo grande/saturado: purgar es muy beneficioso
	var ratio := clampf(
		float(_current_deck_size(ctx) - DECK_SMALL) / float(DECK_LARGE - DECK_SMALL),
		0.0, 1.0)
	return lerpf(VALUE_SMALL, VALUE_LARGE, ratio)


## Umbral dinámico de puntuación mínima para purgar una carta del mazo en tienda.
## Mazo pequeño: umbral bajo → solo eliminar cartas casi inútiles.
## Mazo grande/saturado: umbral alto → eliminar hasta cartas de utilidad moderada
## para acelerar el ciclo de las más valiosas.
## Es public porque lo usa también AIEventResolver.
static func dynamic_purge_threshold(ctx: AITurnContext) -> float:
	const DECK_SMALL := 5
	const DECK_LARGE := 20
	const THRESHOLD_SMALL := 3.0   # mazo pequeño: conservar casi todo
	const THRESHOLD_LARGE := 10.0  # mazo grande: purgar hasta utilidad moderada
	var ratio := clampf(
		float(_current_deck_size(ctx) - DECK_SMALL) / float(DECK_LARGE - DECK_SMALL),
		0.0, 1.0)
	return lerpf(THRESHOLD_SMALL, THRESHOLD_LARGE, ratio)


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
		total += b.gold_produced * 3.0 * gu \
			   + b.food_produced * 2.5 * fu \
			   + b.flat_defense_bonus * 5.0 * mu
	return minf(total, 15.0)


# ---------------------------------------------------------------------------
# Scoring por tipo de opción
# ---------------------------------------------------------------------------

static func _score_build(option: AIBuildOption, ctx: AITurnContext,
		phase: AIGamePhase.Phase) -> float:
	if option.building == null:
		return 0.0
	var b := option.building
	var gu := _gold_urgency(ctx.stats.gold_per_turn, phase)
	var fu := _food_urgency(ctx.stats.food, phase)
	var mu := _military_urgency(ctx, phase)
	var score := b.gold_produced * 5.0 * gu \
		 + b.food_produced * 4.0 * fu \
		 + b.flat_defense_bonus * 8.0 * mu \
		 + _score_building_effects(b.effects, ctx, phase)
	return score * _build_cost_factor(b.get_effective_construction_cost(ctx.stats), ctx.stats.total_gold)


static func _score_upgrade(option: AIUpgradeBuildingOption, ctx: AITurnContext,
		phase: AIGamePhase.Phase) -> float:
	if option.old_building == null or option.new_building == null:
		return 0.0
	var gu := _gold_urgency(ctx.stats.gold_per_turn, phase)
	var fu := _food_urgency(ctx.stats.food, phase)
	var mu := _military_urgency(ctx, phase)
	var dg := option.new_building.gold_produced - option.old_building.gold_produced
	var df := option.new_building.food_produced - option.old_building.food_produced
	var dd := option.new_building.flat_defense_bonus - option.old_building.flat_defense_bonus
	var score := dg * 5.0 * gu + df * 4.0 * fu + dd * 8.0 * mu \
		 + _score_building_effects(option.new_building.effects, ctx, phase) \
		 - _score_building_effects(option.old_building.effects, ctx, phase)
	return score * _build_cost_factor(
		option.new_building.get_effective_construction_cost(ctx.stats), ctx.stats.total_gold)


static func _score_recruit(option: AIRecruitOption, ctx: AITurnContext,
		phase: AIGamePhase.Phase) -> float:
	if option.troop == null:
		return 0.0
	# No reclutar si el mantenimiento hundiría la comida o el gpt en negativo.
	# ctx.stats.food y gold_per_turn ya incluyen el mantenimiento actual;
	# restamos el coste adicional de esta tropa para ver el estado resultante.
	if ctx.stats.food - option.troop.maintenance_food < -5:
		return -10.0
	if ctx.stats.gold_per_turn - option.troop.maintenance_gold < 0:
		return -10.0
	var mu := _military_urgency(ctx, phase)
	var comp := _complement_bonus(option.troop, ctx.stats.troop_pool)
	# Rendimiento decreciente: pool grande (sin frentes) reduce el valor de seguir reclutando.
	# 0 tropas → ×1.0 | 25 tropas → ×0.5 | 50 tropas → ×0.33
	var saturation := 1.0 / (1.0 + ctx.stats.troop_pool.size() * 0.04)
	var surplus := _resource_surplus_factor(ctx, phase)
	return float(option.troop.attack + option.troop.defense) * 3.0 * mu * comp * saturation * surplus


## Bonus de complementariedad: favorece tropas que equilibran el pool actual.
## Si el pool es muy ofensivo (ratio atk/def > 2), las tropas defensivas
## valen el doble aunque sus stats brutos sean menores.
static func _complement_bonus(troop: Troop, pool: Array[Troop]) -> float:
	if pool.is_empty():
		return 1.0
	var total_atk := 0
	var total_def := 0
	for t in pool:
		total_atk += t.attack
		total_def += t.defense
	var pool_ratio := float(total_atk) / maxf(float(total_def), 1.0)
	var troop_ratio := float(troop.attack) / maxf(float(troop.defense), 1.0)

	if pool_ratio > 2.0 and troop_ratio < 0.8:   return 2.0
	if pool_ratio > 1.5 and troop_ratio < 1.0:   return 1.5
	if pool_ratio < 0.5 and troop_ratio > 1.2:   return 2.0
	if pool_ratio < 0.8 and troop_ratio > 1.0:   return 1.5
	return 1.0


static func _score_open_front(option: AIOpenFrontOption, ctx: AITurnContext,
		phase: AIGamePhase.Phase) -> float:
	if option.enemy_tile == null:
		return 0.0

	# Sin tropas libres no tiene sentido abrir un frente: nadie lo defiende.
	# troop_pool contiene solo las tropas NO asignadas a frentes activos.
	var free_troops := ctx.stats.troop_pool.size()
	if free_troops == 0:
		return 0.0
	# Con pocas tropas el score se reduce; con muchas se amplifica (agresividad).
	# 3 tropas → ×0.5 | 6 tropas → ×1.0 | 9+ tropas → ×1.5 (capped)
	var pool_factor := clampf(float(free_troops) / 6.0, 0.0, 1.5)

	var enemy := option.enemy_tile
	var gold_val := 0
	var food_val := 0
	if enemy.natural_resource != null:
		gold_val = enemy.natural_resource.gold_produced
		food_val = enemy.natural_resource.food_produced

	var mu := _military_urgency(ctx, phase)
	# Valor base territorial: evita que tiles sin producción directa (Salt, Iron,
	# Stone, Sand…) puntúen 0 y PASS gane por empate en _pick_best_option.
	var base_strategic := 3.0 + mu * 3.0
	var tile_val := gold_val * 4.0 + food_val * 2.0 + base_strategic

	# Abrir un frente añade recargos de oro Y comida cada turno.
	# Si ya estamos ajustados en cualquiera de los dos, es muy arriesgado.
	var gpt := ctx.stats.gold_per_turn
	var food := ctx.stats.food
	var econ_safety := 1.0
	if gpt < 0 or food < 0:
		econ_safety = 0.15
	else:
		match phase:
			AIGamePhase.Phase.EARLY:
				if gpt < 30 or food < 2: econ_safety = 0.5
			AIGamePhase.Phase.MID:
				if gpt < 150 or food < 5: econ_safety = 0.5
			AIGamePhase.Phase.LATE:
				if gpt < 50 or food < 5: econ_safety = 0.5

	var biome_factor := _attack_biome_factor(enemy)
	var surplus := _resource_surplus_factor(ctx, phase)
	return tile_val * econ_safety * mu * biome_factor * pool_factor * surplus


static func _score_tactic(option: AITacticOption, ctx: AITurnContext,
		phase: AIGamePhase.Phase) -> float:
	if option.front == null:
		return 0.0
	var mu := _military_urgency(ctx, phase)
	var is_attacker := option.front.attacker_empire == ctx.stats.empire
	var ai_marker := option.front.marker if is_attacker else -option.front.marker
	# urgency → 1.0 cuando estamos al límite de perder el frente
	var urgency := clampf(-ai_marker / option.front.threshold, 0.0, 1.0)
	return (12.0 + urgency * 18.0) * mu


static func _score_draw(option: AIDrawCardOption, ctx: AITurnContext) -> float:
	return option.amount * 4.0 * _deck_urgency(ctx)


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
		var gu := _gold_urgency(ctx.stats.gold_per_turn, phase)
		# Oro inmediato vale menos que gold_per_turn (es one-shot)
		return (card as GenerateGoldCard).amount * 0.4 * gu

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
	var gu := _gold_urgency(ctx.stats.gold_per_turn, phase)
	var fu := _food_urgency(ctx.stats.food, phase)
	# Bonus territorial: escala con la presión de expansión real (tiles adyacentes
	# libres), sin depender de la fase. En un mapa grande con muchas tiles libres
	# el bonus sigue siendo alto aunque el número de turno sea elevado.
	# 0.0 cuando no hay tiles (PASS dominará); 3.0 cuando hay muchas (max bonus).
	var expansion_bonus := _expansion_factor(ctx) * 3.0
	# Bonus de frontera: cada tile nueva que esta colonización desbloquea
	# puntúa extra, escalado por la presión de encierro. Las tiles que abren
	# corredores hacia espacio libre dominan a las que solo rellenan huecos.
	var frontier_bonus := float(_frontier_value(tile, ctx)) * _encirclement_pressure(ctx)
	# food_production de una tile no colonizada = natural_resource.food_produced
	# gold_production de una tile no colonizada = natural_resource.gold_produced
	return tile.gold_production * 4.0 * gu \
		 + tile.food_production * 5.0 * fu \
		 + expansion_bonus \
		 + frontier_bonus


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
	if ctx.stats == null or ctx.stats.empire == null:
		return 1.5
	var avail := ctx.colonizable_tiles_count
	if avail < 0:
		return 1.5
	var controlled := maxi(ctx.stats.empire.controlled_tiles.size(), 1)
	var ratio := float(avail) / float(controlled)
	if ratio >= 2.0: return 1.5
	if ratio >= 1.0: return 2.5
	if ratio >= 0.5: return 4.0
	return 5.0


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

	# Veto duro: la comida resultante no puede ser negativa.
	var new_food := ctx.stats.food - delta_consumption
	if new_food < 0:
		return -20.0

	var gu := _gold_urgency(ctx.stats.gold_per_turn, phase)
	var fu := _food_urgency(ctx.stats.food, phase)
	var mu := _military_urgency(ctx, phase)

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
			demolished_penalty += building.gold_produced * 4.0 * gu \
								+ building.food_produced * 3.0 * fu \
								+ float(building.flat_defense_bonus) * 6.0
		else:
			# El edificio sobrevive: ¿explota el recurso natural de la tile
			# y además es una versión mejorada (no el edificio base)?
			if _is_upgraded_resource_building(building, tile, ctx):
				resource_building_survives = true

	# --- 2. Bonus por edificio de recurso mejorado que sobrevive al upgrade ---
	# Si ese edificio se demoliera, el bonus no aplica (cubierto en demolished_penalty).
	var resource_bonus := 8.0 if resource_building_survives else 0.0

	# --- 3. Bonus por edificios desbloqueados en el nuevo tier ---
	# Solo cuenta los que NO se podían construir en old_loc pero sí en new_loc,
	# ponderados por las necesidades actuales del imperio.
	var unlock_bonus := _score_unlocked_buildings(tile, old_loc, new_loc, ctx, gu, fu, mu)

	# --- 4. Score base: slots nuevos vs coste en comida ---
	var base := delta_slots * 10.0 \
			  - delta_consumption * 3.0 * _food_urgency(new_food, phase)

	return base - demolished_penalty + resource_bonus + unlock_bonus


static func _score_direct_build(option: AIPlayOption, ctx: AITurnContext,
		phase: AIGamePhase.Phase) -> float:
	var card := option.card as DirectBuildCard
	if card == null or card.buildings.is_empty() or card.buildings[0] == null:
		return 0.0
	var b := card.buildings[0]
	var gu := _gold_urgency(ctx.stats.gold_per_turn, phase)
	var fu := _food_urgency(ctx.stats.food, phase)
	var mu := _military_urgency(ctx, phase)
	var score := b.gold_produced * 5.0 * gu \
		 + b.food_produced * 4.0 * fu \
		 + b.flat_defense_bonus * 8.0 * mu \
		 + _score_building_effects(b.effects, ctx, phase)
	return score * _build_cost_factor(b.get_effective_construction_cost(ctx.stats), ctx.stats.total_gold)


# ---------------------------------------------------------------------------
# Decisiones de eventos: mazo y tienda
# ---------------------------------------------------------------------------

## Devuelve el valor de tener esta carta en el mazo dado el estado actual.
## Usado para decidir qué comprar en tienda, qué purgar y qué eliminar
## cuando un evento pide eliminar una carta.
static func score_card_for_deck(card: Card, ctx: AITurnContext) -> float:
	if card == null:
		return 0.0
	var phase := AIGamePhase.detect(ctx.stats)
	var gu  := _gold_urgency(ctx.stats.gold_per_turn, phase)
	var fu  := _food_urgency(ctx.stats.food, phase)
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
			return 0.5 * sat
		return lerpf(8.0, 15.0, exp) * sat

	if card is DirectBuildCard:
		var db := card as DirectBuildCard
		if not db.buildings.is_empty() and db.buildings[0] != null:
			var b := db.buildings[0]
			return (b.gold_produced * 5.0 * gu \
				  + b.food_produced * 4.0 * fu \
				  + b.flat_defense_bonus * 8.0 * mu) * sat
		return 5.0 * sat

	if card is UpgradeBuildingCard:
		var upgrades := _upgradeable_buildings(ctx)
		if upgrades == 0:
			return 2.0 * sat
		return lerpf(5.0, 18.0, clampf(float(upgrades) / 5.0, 0.0, 1.0)) * sat

	# BuildCard genérica: valioso solo si hay huecos de edificio libres.
	if card is BuildCard:
		var slots := _buildable_slots(ctx)
		if slots == 0:
			return 1.0 * sat
		return lerpf(5.0, 20.0, clampf(float(slots) / 10.0, 0.0, 1.0)) * sat

	if card is RecruitCard:
		# troop_sat: rendimiento decreciente por pool grande (diferente a sat por copias).
		var troop_sat := 1.0 / (1.0 + ctx.stats.troop_pool.size() * 0.04)
		return (8.0 + mu * 5.0) * troop_sat * sat

	if card is OpenFrontCard:
		return (5.0 + mu * 4.0) * sat

	if card is TacticCard:
		return (4.0 + mu * 3.0) * sat

	if card is ChangeLocationTypeCard:
		var clt_card := card as ChangeLocationTypeCard
		if clt_card.location_type == null:
			return 2.0 * sat
		var valid_count := 0
		for t in ctx.stats.empire.controlled_tiles:
			if t.location != null \
					and t.location.type + 1 == clt_card.location_type.type:
				valid_count += 1
		if valid_count == 0:
			return 2.0 * sat
		var tile_factor := clampf(float(valid_count) / 5.0, 0.0, 1.0)
		if ctx.stats.food < clt_card.location_type.food_consumption:
			return lerpf(2.0, 7.0, tile_factor) * sat
		return lerpf(5.0, 14.0, tile_factor) * sat

	if card is CardDrawCard:
		var deck_ratio := clampf(float(_current_deck_size(ctx)) / 20.0, 0.0, 1.0)
		return lerpf(8.0, 14.0, deck_ratio) * sat

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
		# 60 % del valor de la mejor carta recuperable, entre 4.0 y 12.0.
		return clampf(best_score * 0.6, 4.0, 12.0) * sat

	if card is GenerateGoldCard:
		return (card as GenerateGoldCard).amount * 0.3 * gu * sat

	return 5.0 * sat  # tipo desconocido: valor neutro


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
	var phase := AIGamePhase.detect(ctx.stats)
	var gu := _gold_urgency(ctx.stats.gold_per_turn, phase)
	var fu := _food_urgency(ctx.stats.food, phase)
	var score := 0.0

	for effect in choice.effects:
		if effect == null:
			continue
		if effect is AddCardEffect:
			score += score_card_for_deck((effect as AddCardEffect).card, ctx)
		elif effect is GoldEventEffect:
			score += (effect as GoldEventEffect).amount * 0.4 * gu
		elif effect is FoodEventEffect:
			score += (effect as FoodEventEffect).amount * 0.5 * fu
		elif effect is RemoveCardEventEffect:
			# Eliminar carta: beneficio variable según el tamaño del mazo.
			# Mazo pequeño → el ciclo ya es rápido, purgar aporta poco.
			# Mazo grande/saturado → purgar acelera el acceso a las mejores cartas.
			score += _deck_thinning_value(ctx)
		elif effect is AddRandomPoolCardEffect:
			# Carta aleatoria del pool: valor medio estimado
			score += 8.0
		else:
			# Efecto desconocido: valor neutro-positivo
			score += 3.0

	# Penalización leve si tiene coste (ya verificado como asequible,
	# pero un coste siempre supone una restricción)
	if choice.cost != null:
		score -= 2.0

	return score


## Decide si la IA debe comprar un item de tienda.
## El umbral escala con el tamaño del mazo: con el mazo pequeño casi todo
## vale la pena añadir; con el mazo saturado solo se compra lo realmente bueno.
static func should_buy_shop_item(item: ShopItem, ctx: AITurnContext) -> bool:
	if item == null or item.card == null:
		return false
	const DECK_SMALL    := 5
	const DECK_LARGE    := 20
	const THRESH_SMALL  := 5.0   # mazo pequeño: comprar casi cualquier carta útil
	const THRESH_LARGE  := 12.0  # mazo grande: solo cartas realmente valiosas
	var ratio := clampf(
		float(_current_deck_size(ctx) - DECK_SMALL) / float(DECK_LARGE - DECK_SMALL),
		0.0, 1.0)
	var threshold := lerpf(THRESH_SMALL, THRESH_LARGE, ratio)
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
	var score := 0.0
	var gu := _gold_urgency(ctx.stats.gold_per_turn, phase)
	var fu := _food_urgency(ctx.stats.food, phase)
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
				AIGamePhase.Phase.EARLY: score += pct * 0.5
				AIGamePhase.Phase.MID:   score += pct * 1.5
				_:                       score += pct * 1.0
		elif effect is AddCardToDeckEffect:
			var card_added := (effect as AddCardToDeckEffect).card
			if card_added != null:
				score += score_card_for_deck(card_added, ctx)
		elif effect is GoldOnCard:
			# Frecuencia desconocida: estimación conservadora (~3 plays/turno).
			score += (effect as GoldOnCard).gold_reward * 0.5 * gu
	return score


## Traduce un AddStatModifierEffect a un score usando las escalas de urgencia.
static func _score_stat_effect(effect: AddStatModifierEffect,
		ctx: AITurnContext, gu: float, fu: float, mu: float) -> float:
	var v := effect.value
	match effect.stat_type:
		StatModifier.StatType.FLAT_GOLD:
			return v * 5.0 * gu
		StatModifier.StatType.PERCENT_GOLD:
			return ctx.stats.gold_per_turn * v / 100.0 * 5.0 * gu
		StatModifier.StatType.FLAT_FOOD:
			return v * 4.0 * fu
		StatModifier.StatType.PERCENT_FOOD:
			return ctx.stats.food * v / 100.0 * 4.0 * fu
		StatModifier.StatType.TILE_RESOURCE_GOLD:
			return v * 5.0 * gu
		StatModifier.StatType.TILE_RESOURCE_FOOD:
			return v * 4.0 * fu
		StatModifier.StatType.CARDS_PER_TURN:
			# Carta extra por turno: valor equivalente a una CardDrawCard (12.0)
			return v * 12.0
		StatModifier.StatType.CARD_DRAW_BONUS:
			return v * 8.0
		StatModifier.StatType.TROOPS_PER_RECRUIT:
			return v * 6.0 * mu
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT:
			return ctx.stats.troop_pool.size() * absf(v) * 0.3 * mu
	return 0.0


## Factor de coste: penaliza edificios que consumen una fracción alta del oro.
## Rango 0.6 (gasto total) → 1.0 (gasto residual). Suaviza la preferencia
## por edificios baratos cuando el gold disponible es ajustado.
static func _build_cost_factor(cost: int, total_gold: int) -> float:
	if total_gold <= 0:
		return 0.6
	return lerpf(1.0, 0.6, clampf(float(cost) / float(total_gold), 0.0, 1.0))


## Multiplicador de dificultad de ataque según el bioma de la tile enemiga.
## Montaña 0.60, Pantano 0.70, Bosque 0.80 … Pradera 1.20.
static func _attack_biome_factor(tile: Tile) -> float:
	if tile == null or tile.mesh_data == null:
		return 1.0
	return BiomeConfig.new().get_attack_multiplier(tile.mesh_data.type)
