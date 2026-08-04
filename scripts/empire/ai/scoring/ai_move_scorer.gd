extends RefCounted
class_name AIMoveScorer

## Scorers de jugada escritos UNA sola vez contra AIStateView.
## Sustituyen progresivamente a los _score_<tipo> duplicados en AIHeuristic (vivo) y
## AIRealEvalStrong (snapshot). El estado se lee por el puerto; los datos concretos
## de la jugada (cantidad, edificio, tropa, tile) se pasan aparte.
##
## Migración incremental: los 9 tipos PORTADOS = GENERATE_GOLD, CARD_DRAW,
## COLONIZE, BUILD (+ DIRECT_BUILD), UPGRADE, RECRUIT, OPEN_FRONT, TACTIC,
## CHANGE_LOCATION.


## TACTIC: valor táctico escalado por lo comprometido del frente (urgencia = cuánto lo
## estamos perdiendo), la urgencia militar, la fracción de tropas afectadas por la
## carta y el bioma relevante. Los datos del frente (tropas propias, marcador,
## umbral, casilla relevante) los extrae cada mundo (BattleFront vs FrontSnap).
static func score_tactic(view: AIStateView, tactic: TacticCard, own_troops: Array[Troop],
		ai_marker: float, threshold: float, relevant_tile) -> float:
	# Si la carta especifica tipos y ninguna tropa del bando los cumple → sin valor.
	var troop_ratio := 1.0
	if tactic != null and not tactic.affected_troop_types.is_empty():
		var affected_count := 0
		for t in own_troops:
			if t.type in tactic.affected_troop_types:
				affected_count += 1
		if affected_count == 0:
			return 0.0
		troop_ratio = float(affected_count) / float(maxi(own_troops.size(), 1))

	var biome_mod := 1.0
	if tactic != null and (tactic.attack_percent_per_type > 0.0 or tactic.attack_per_troop > 0.0):
		if relevant_tile != null:
			biome_mod = view.tile_attack_biome_factor(relevant_tile)

	var w := view.weights()
	var mu := view.military_urgency()
	var urgency := clampf(-ai_marker / threshold, 0.0, 1.0)
	return (w.tactic_base + urgency * w.tactic_urgency_scale) * mu * troop_ratio * biome_mod


## CHANGE_LOCATION: slots nuevos vs coste en comida (base compartida + veto por comida
## negativa); el ajuste por demolición y los bonos de recurso/desbloqueo los aplica
## cada mundo (el vivo completo; el snapshot una aproximación-suelo) vía la vista.
static func score_change_location(view: AIStateView, tile, new_loc: LocationType) -> float:
	var w := view.weights()
	var delta_consumption := new_loc.food_consumption - view.tile_food_consumption(tile)
	var delta_slots := new_loc.max_building - view.tile_max_buildings(tile)

	# Veto duro: la comida resultante no puede ser negativa.
	var new_food := view.food() - delta_consumption
	if new_food < 0:
		return w.changeloc_veto

	var gu := view.gold_urgency()
	var fu := view.food_urgency()
	var mu := view.military_urgency()
	var base := float(delta_slots) * w.changeloc_slot \
		- float(delta_consumption) * w.changeloc_consumption \
		* AIUrgency.food_urgency(new_food, view.phase(), w)
	return view.change_location_adjust(base, tile, new_loc, gu, fu, mu)


## OPEN_FRONT: valor de la casilla enemiga × P(ganar) − valor de la casilla origen ×
## P(perder), todo escalado por seguridad económica, urgencia militar, bioma, factor
## de pool, excedente y carrera territorial. `enemy_tile`/`source_tile` son handles
## (source_tile puede ser null). La ganabilidad (con la divergencia por mundo) la
## resuelve view.open_front_win_factor.
static func score_open_front(view: AIStateView, enemy_tile, source_tile) -> float:
	var w := view.weights()
	# Sin tropas libres no tiene sentido abrir un frente.
	var free_troops := view.troop_pool().size()
	if free_troops == 0:
		return 0.0
	var pool_factor := clampf(float(free_troops) / w.openfront_pool_divisor, 0.0, w.openfront_pool_cap)
	var mu := view.military_urgency()

	var base_strategic := w.openfront_base_strategic + mu * w.openfront_base_mu
	var tile_val := float(view.tile_resource_gold(enemy_tile)) * w.openfront_gold \
		+ float(view.tile_resource_food(enemy_tile)) * w.openfront_food + base_strategic

	# Seguridad económica: abrir frente añade recargo de oro Y comida cada turno.
	var gpt := view.gold_per_turn()
	var food := view.food()
	var econ_safety := 1.0
	if gpt < 0 or food < 0:
		econ_safety = w.openfront_econ_unsafe
	else:
		match view.phase():
			AIGamePhase.Phase.EARLY:
				if gpt < w.openfront_econ_early_gpt or food < w.openfront_econ_early_food: econ_safety = w.openfront_econ_caution
			AIGamePhase.Phase.MID:
				if gpt < w.openfront_econ_mid_gpt or food < w.openfront_econ_mid_food: econ_safety = w.openfront_econ_caution
			AIGamePhase.Phase.LATE:
				if gpt < w.openfront_econ_late_gpt or food < w.openfront_econ_late_food: econ_safety = w.openfront_econ_caution

	var biome_factor := view.tile_attack_biome_factor(enemy_tile)
	var surplus := view.resource_surplus_factor()
	var win_factor := view.open_front_win_factor(enemy_tile, biome_factor)

	# Valor de la casilla origen (riesgo del atacante si pierde). Per-mundo: el orden
	# de suma difiere entre vivo (a + (b+c)) y snapshot ((a+b)+c) → byte-identidad.
	var source_value := view.open_front_source_value(source_tile)

	return (tile_val * win_factor - source_value * (1.0 - win_factor)) \
		* econ_safety * mu * biome_factor * pool_factor * surplus \
		* view.territory_race_factor(&"open_front")


## RECRUIT: poder de la tropa escalado por urgencia militar, complementariedad con el
## pool y la composición rival, excedente económico, coste-eficiencia y diversidad de
## tipo; con vetos si el mantenimiento (o el recargo cuadrático de frente) hundiría la
## comida/gpt.
static func score_recruit(view: AIStateView, troop: Troop) -> float:
	if troop == null:
		return 0.0
	var w := view.weights()
	# Vetos de mantenimiento (comida/gpt resultante en negativo).
	if view.food() - troop.maintenance_food < w.recruit_food_veto_margin:
		return w.recruit_veto_score
	if view.gold_per_turn() - troop.maintenance_gold < 0:
		return w.recruit_veto_score

	# Veto por recargo cuadrático de frente: con n tropas en un bando el coste es
	# charge·n·(n+1)/2 de comida/turno. -1 = el veto no aplica en este mundo/estado.
	var max_own := view.recruit_front_max_troops()
	if max_own >= 0:
		var n_after := max_own + 1
		var delta_charge := w.recruit_front_charge_per_troop * n_after * (n_after + 1) / 2.0 \
			- w.recruit_front_charge_per_troop * max_own * (max_own + 1) / 2.0
		if view.food() - delta_charge < w.recruit_front_food_margin:
			return w.recruit_veto_score

	var mu := view.military_urgency()
	var comp := view.complement_bonus(troop)
	var pool := view.troop_pool()
	var saturation := 1.0 / (1.0 + pool.size() * w.recruit_saturation_k)
	var surplus := view.resource_surplus_factor()
	var cost_eff := sqrt(w.recruit_cost_eff_base / float(maxi(troop.recruitment_cost_gold, 1)))
	var type_count := 0
	for tt in pool:
		if tt.type == troop.type:
			type_count += 1
	var type_diversity := 1.0 / (1.0 + float(type_count) * w.recruit_type_diversity_k)
	return float(troop.attack + troop.defense) * w.recruit_atkdef_weight * mu * comp \
		* saturation * surplus * cost_eff * type_diversity


## BUILD / DIRECT_BUILD: producción (oro/comida/defensa ponderada por urgencia) +
## efectos del edificio, escalado por el factor de coste; más micro-desempates por
## casilla (recurso explotado + posición fronteriza). `tile` es el handle de la
## casilla destino, o null (DIRECT_BUILD y builds sin casilla concreta) → sin
## desempate. DIRECT_BUILD comparte la misma valoración de edificio.
static func score_build(view: AIStateView, b: Building, tile) -> float:
	if b == null:
		return 0.0
	var w := view.weights()
	var gu := view.gold_urgency()
	var fu := view.food_urgency()
	var mu := view.military_urgency()
	# Los edificios con mantenimiento (gold_produced < 0) reciben peso reducido.
	var gold_weight := w.gold_weight_pos if b.gold_produced >= 0 else w.gold_weight_maint
	var score := float(b.gold_produced) * gold_weight * gu \
		+ float(b.food_produced) * w.food_weight * fu \
		+ float(b.flat_defense_bonus) * w.defense_weight * mu \
		+ view.score_building_effects(b.effects, gu, fu, mu)
	score *= AIEconomy.build_cost_factor(view.effective_build_cost(b), view.gold(), w)

	if tile != null:
		if b.required_natural_resource != null \
				and b.required_natural_resource == view.tile_natural_resource(tile):
			score += w.build_resource_match
		if view.tile_adjacent_to_enemy(tile):
			score += w.build_border
	return score


## UPGRADE: valora el DELTA de producción/defensa y de efectos entre el edificio
## nuevo y el viejo, escalado por el factor de coste.
static func score_upgrade(view: AIStateView, ob: Building, nb: Building) -> float:
	if ob == null or nb == null:
		return 0.0
	var w := view.weights()
	var gu := view.gold_urgency()
	var fu := view.food_urgency()
	var mu := view.military_urgency()
	var dg := nb.gold_produced - ob.gold_produced
	var df := nb.food_produced - ob.food_produced
	var dd := nb.flat_defense_bonus - ob.flat_defense_bonus
	var dg_weight := w.gold_weight_pos if dg >= 0 else w.gold_weight_maint
	var score := float(dg) * dg_weight * gu + float(df) * w.food_weight * fu \
		+ float(dd) * w.defense_weight * mu \
		+ view.score_building_effects(nb.effects, gu, fu, mu) \
		- view.score_building_effects(ob.effects, gu, fu, mu)
	return score * AIEconomy.build_cost_factor(view.effective_build_cost(nb), view.gold(), w)


## COLONIZE: producción de la casilla + presión de expansión + valor de frontera
## (escalado por encierro) + bonus de negación (colonizar junto al rival), todo
## escalado por la carrera territorial. `tile` es el handle opaco de la casilla
## objetivo (Tile en el vivo, TileSnap en el snapshot).
static func score_colonize(view: AIStateView, tile) -> float:
	var w := view.weights()
	var gu := view.gold_urgency()
	var fu := view.food_urgency()
	var expansion_bonus := view.expansion_factor() * w.colonize_expansion
	var frontier_bonus := float(view.frontier_value(tile)) * view.encirclement_pressure()
	var denial_bonus := w.colonize_denial if view.tile_adjacent_to_rival(tile) else 0.0
	var base_score := float(view.tile_gold_production(tile)) * w.colonize_gold * gu \
		+ float(view.tile_food_production(tile)) * w.colonize_food * fu \
		+ expansion_bonus \
		+ frontier_bonus \
		+ denial_bonus
	return base_score * view.territory_race_factor(&"colonize")


## GENERATE_GOLD: oro inmediato one-shot; vale menos que gold_per_turn (por eso el
## peso simple_gold_weight < 1), escalado por la urgencia de oro de la fase.
static func score_generate_gold(view: AIStateView, amount: int) -> float:
	var w := view.weights()
	return float(amount) * w.simple_gold_weight \
		* AIUrgency.gold_urgency(view.gold_per_turn(), view.phase(), w)


## CARD_DRAW: robar cartas escalado por la urgencia de mazo (cada mundo mide el
## tamaño de mazo a su manera; ver AIStateView.deck_urgency_size).
static func score_card_draw(view: AIStateView, amount: int) -> float:
	var w := view.weights()
	return float(amount) * w.draw_weight * AIUrgency.deck_urgency(view.deck_urgency_size(), w)
