extends RefCounted
class_name AIRealEvalStrong

## Prior FUERTE sobre el snapshot (Fase C v2 — F3c, "heurística a toda profundidad").
##
## Motivación (ver análisis de simulación): la fuerza medida del SO-ISMCTS viene
## de la CALIDAD de la guía heurística, no del lookahead en bruto (ISMCTS con
## rollout aleatorio NO supera a la heurística). Hoy esa guía fuerte solo actúa en
## la RAÍZ (AIController pasa root_priors calculados con AIHeuristic.score_option
## real); a profundidad ≥1 y en el rollout se usa la aproximación pobre
## AIRealEval.score_move. Este módulo reimplementa score_option SOBRE EL SNAPSHOT
## para poder usarlo como prior/política en TODO el árbol, no solo arriba.
##
## Espejo de AIHeuristic (acoplada a Stats/Tile/BattleFront de escena) sobre
## AIRealState (datos puros). Mismo patrón "espejo con paridad" que AIRealSimulator
## y AIRealEvents. La paridad de fórmulas se valida en test_ai_real_eval_strong.gd
## con las propiedades DISCRIMINANTES que score_move (débil) no captura.
##
## ALCANCE F3c (en curso): COLONIZE (F3c.1) + BUILD/DIRECT_BUILD/UPGRADE/RECRUIT
## (F3c.2) portados fielmente, con sus helpers compartidos (urgencias por fase,
## expansión, carrera territorial, urgencia militar, excedente, efectos de
## edificio, complementariedad de tropas). El resto de tipos DELEGA en
## AIRealEval.score_move (fallback sin regresión) hasta portarse: OPEN_FRONT/TACTIC
## y simples (F3c.3). NO está cableado aún en AIRealMCTS (eso es F3c.4).

const OWNER_SELF := AIRealState.OWNER_SELF
const OWNER_RIVAL := AIRealState.OWNER_RIVAL
const OWNER_NONE := AIRealState.OWNER_NONE


## Prior fuerte de una jugada. Espejo de AIHeuristic.score_option sobre el
## snapshot. Los tipos aún no portados delegan en el prior débil (score_move).
static func score_move(move: AIRealOptions.Move, state: AIRealState,
		p_owner: int = OWNER_SELF) -> float:
	if move == null or move.kind == &"PASS":
		return 0.0
	match move.kind:
		&"COLONIZE":
			return _score_colonize(move, state, p_owner)
		&"BUILD", &"DIRECT_BUILD":
			return _score_build(move, state, p_owner)
		&"UPGRADE":
			return _score_upgrade(move, state, p_owner)
		&"RECRUIT":
			return _score_recruit(move, state, p_owner)
		&"OPEN_FRONT":
			return _score_open_front(move, state, p_owner)
		&"TACTIC":
			return _score_tactic(move, state, p_owner)
		&"GENERATE_GOLD":
			return _score_generate_gold(move, state, p_owner)
		&"CARD_DRAW":
			return _score_card_draw(move, state, p_owner)
		&"CHANGE_LOCATION":
			return _score_change_location(move, state, p_owner)
		_:
			# Tipos raros no cubiertos (p.ej. RECOVER): fallback al prior débil.
			return AIRealEval.score_move(move, state, p_owner)


# ---------------------------------------------------------------------------
# Colonize (espejo de AIHeuristic._score_colonize + helpers)
# ---------------------------------------------------------------------------

## Espejo de AIHeuristic._score_colonize: producción de la casilla + presión de
## expansión + valor de frontera (escalado por encierro) + bonus de negación
## (colonizar junto al rival), todo escalado por la carrera territorial.
static func _score_colonize(move: AIRealOptions.Move, state: AIRealState,
		p_owner: int) -> float:
	var t := state.tiles.get(move.tile_id) as AIRealState.TileSnap
	if t == null:
		return 0.0
	var emp := _empire_of(state, p_owner)
	if emp == null:
		return 0.0
	var phase := AIRealEval.detect_phase(state, p_owner)
	var gu := _gold_urgency(emp.gold_per_turn, phase)
	var fu := _food_urgency(emp.food, phase)

	# Bonus territorial por presión de expansión (tiles adyacentes libres).
	var expansion_bonus := _expansion_factor(state, p_owner) * 3.0
	# Bonus de frontera: tiles que esta colonización abre, escalado por encierro.
	var frontier_bonus := float(_frontier_value(state, move.tile_id, p_owner)) \
		* _encirclement_pressure(state, p_owner)
	# Bonus de negación: colonizar junto al rival le resta espacio (suma cero).
	var denial_bonus := 0.0
	var rival := OWNER_RIVAL if p_owner == OWNER_SELF else OWNER_SELF
	for nid in t.neighbor_ids:
		var nb := state.tiles.get(nid) as AIRealState.TileSnap
		if nb != null and nb.owner == rival:
			denial_bonus = 3.0
			break

	var base_score := float(t.gold_production()) * 4.0 * gu \
		 + float(t.food_production()) * 5.0 * fu \
		 + expansion_bonus \
		 + frontier_bonus \
		 + denial_bonus
	return base_score * _territory_race_factor(state, p_owner, &"colonize")


## Espejo de AIHeuristic._frontier_value: tiles libres que colonizar `tile_id`
## haría accesibles por primera vez (no alcanzables ya desde el territorio).
static func _frontier_value(state: AIRealState, tile_id: int, p_owner: int) -> int:
	var t := state.tiles.get(tile_id) as AIRealState.TileSnap
	if t == null:
		return 0
	var count := 0
	for nid in t.neighbor_ids:
		var nt := state.tiles.get(nid) as AIRealState.TileSnap
		if nt == null or nt.owner != OWNER_NONE:
			continue
		var already_reachable := false
		for nnid in nt.neighbor_ids:
			if nnid == tile_id:
				continue
			var nnt := state.tiles.get(nnid) as AIRealState.TileSnap
			if nnt != null and nnt.owner == p_owner:
				already_reachable = true
				break
		if not already_reachable:
			count += 1
	return count


## Espejo de AIHeuristic._encirclement_pressure: ratio colonizables/controladas.
## Ratio bajo → la IA se está quedando rodeada → escalar el incentivo de escapar.
static func _encirclement_pressure(state: AIRealState, p_owner: int) -> float:
	var avail := _colonizable_count(state, p_owner)
	var controlled := maxi(state.count_tiles(p_owner), 1)
	var ratio := float(avail) / float(controlled)
	if ratio >= 2.0: return 1.5
	if ratio >= 1.0: return 2.5
	if ratio >= 0.5: return 4.0
	return 5.0


## Espejo de AIHeuristic._expansion_factor: presión expansionista [0.0, 1.0] por
## número de tiles colonizables adyacentes (REFERENCE = 15 → presión máxima).
static func _expansion_factor(state: AIRealState, p_owner: int) -> float:
	const REFERENCE := 15
	var avail := _colonizable_count(state, p_owner)
	if avail == 0:
		return 0.0
	return minf(float(avail) / float(REFERENCE), 1.0)


## Espejo de AIHeuristic._territory_race_factor: amplifica jugadas que acercan a
## la dominación (o bloquean al rival cerca de su límite de victoria).
static func _territory_race_factor(state: AIRealState, p_owner: int,
		mode: StringName = &"colonize") -> float:
	var rival := OWNER_RIVAL if p_owner == OWNER_SELF else OWNER_SELF
	var my_tiles := state.count_tiles(p_owner)
	var rival_tiles := state.count_tiles(rival)
	var colonizable := _colonizable_count(state, p_owner)
	var total := maxi(my_tiles + rival_tiles + colonizable, 1)
	var my_share := float(my_tiles) / float(total)
	var rival_share := float(rival_tiles) / float(total)

	if mode == &"colonize" or mode == &"open_front":
		if my_share >= 0.60:
			return 2.0
		if my_share >= 0.50:
			return 1.5
		if rival_share >= 0.55:
			return 1.5
	elif mode == &"economy":
		if my_share >= 0.60:
			return 0.7
	return 1.0


## Tiles sin colonizar adyacentes al territorio de `p_owner` (espejo del conteo de
## AdjacentCondition.valid_targets que AIController pasa como colonizable_tiles_count).
static func _colonizable_count(state: AIRealState, p_owner: int) -> int:
	var seen := {}
	for id in state.tiles:
		var t := state.tiles[id] as AIRealState.TileSnap
		if t.owner != p_owner:
			continue
		for nid in t.neighbor_ids:
			if seen.has(nid):
				continue
			var nb := state.tiles.get(nid) as AIRealState.TileSnap
			if nb != null and nb.owner == OWNER_NONE:
				seen[nid] = true
	return seen.size()


# ---------------------------------------------------------------------------
# Build / Direct build (espejo de AIHeuristic._score_build / _score_direct_build)
# ---------------------------------------------------------------------------

## Producción (oro/comida ponderada por urgencia) + defensa + efectos del edificio,
## escalado por el factor de coste; más micro-tie-breakers por tile (recurso
## explotado + posición fronteriza). DIRECT_BUILD comparte la misma valoración de
## edificio (su fórmula real es equivalente sobre el snapshot).
static func _score_build(move: AIRealOptions.Move, state: AIRealState,
		p_owner: int) -> float:
	var b := move.building
	if b == null:
		return 0.0
	var emp := _empire_of(state, p_owner)
	if emp == null:
		return 0.0
	var phase := AIRealEval.detect_phase(state, p_owner)
	var gu := _gold_urgency(emp.gold_per_turn, phase)
	var fu := _food_urgency(emp.food, phase)
	var mu := _military_urgency(state, p_owner)
	# Edificios con mantenimiento (gold_produced < 0) reciben peso reducido.
	var gold_weight := 5.0 if b.gold_produced >= 0 else 2.5
	var score := float(b.gold_produced) * gold_weight * gu \
		 + float(b.food_produced) * 4.0 * fu \
		 + float(b.flat_defense_bonus) * 8.0 * mu \
		 + _score_building_effects(b.effects, state, p_owner, emp, phase, gu, fu, mu)
	score *= _build_cost_factor(AIRealSimulator._effective_build_cost(b, emp), emp.gold)

	# Tie-breaker por tile concreta (desempata el mismo edificio en varias tiles).
	var t := state.tiles.get(move.tile_id) as AIRealState.TileSnap
	if t != null:
		if b.required_natural_resource != null \
				and b.required_natural_resource == t.natural_resource:
			score += 2.0
		var enemy := OWNER_RIVAL if p_owner == OWNER_SELF else OWNER_SELF
		for nid in t.neighbor_ids:
			var nb := state.tiles.get(nid) as AIRealState.TileSnap
			if nb != null and nb.owner == enemy:
				score += 1.0
				break
	return score


## Espejo de AIHeuristic._score_upgrade: valora el DELTA de producción/defensa y
## de efectos entre el edificio nuevo y el viejo, escalado por el factor de coste.
static func _score_upgrade(move: AIRealOptions.Move, state: AIRealState,
		p_owner: int) -> float:
	var ob := move.old_building
	var nb := move.new_building
	if ob == null or nb == null:
		return 0.0
	var emp := _empire_of(state, p_owner)
	if emp == null:
		return 0.0
	var phase := AIRealEval.detect_phase(state, p_owner)
	var gu := _gold_urgency(emp.gold_per_turn, phase)
	var fu := _food_urgency(emp.food, phase)
	var mu := _military_urgency(state, p_owner)
	var dg := nb.gold_produced - ob.gold_produced
	var df := nb.food_produced - ob.food_produced
	var dd := nb.flat_defense_bonus - ob.flat_defense_bonus
	var dg_weight := 5.0 if dg >= 0 else 2.5
	var score := float(dg) * dg_weight * gu + float(df) * 4.0 * fu + float(dd) * 8.0 * mu \
		 + _score_building_effects(nb.effects, state, p_owner, emp, phase, gu, fu, mu) \
		 - _score_building_effects(ob.effects, state, p_owner, emp, phase, gu, fu, mu)
	return score * _build_cost_factor(
		AIRealSimulator._effective_build_cost(nb, emp), emp.gold)


# ---------------------------------------------------------------------------
# Recruit (espejo de AIHeuristic._score_recruit)
# ---------------------------------------------------------------------------

## Poder de la tropa escalado por urgencia militar, complementariedad con el pool
## y la composición rival visible, excedente económico, coste-eficiencia y
## diversidad de tipo; con vetos si el mantenimiento (o el recargo cuadrático de
## frente) hundiría la comida/gpt.
static func _score_recruit(move: AIRealOptions.Move, state: AIRealState,
		p_owner: int) -> float:
	var troop := move.troop
	if troop == null:
		return 0.0
	var emp := _empire_of(state, p_owner)
	if emp == null:
		return 0.0
	var phase := AIRealEval.detect_phase(state, p_owner)

	# Vetos de mantenimiento (comida/gpt resultante en negativo).
	if emp.food - troop.maintenance_food < -5:
		return -10.0
	if emp.gold_per_turn - troop.maintenance_gold < 0:
		return -10.0

	# Proyección del recargo cuadrático de frente: con n tropas en un bando el
	# coste es 5·n·(n+1)/2 de comida/turno. Veto si dejaría la comida bajo margen.
	var max_own_troops := 0
	var has_front := false
	for f in state.fronts:
		var front := f as AIRealState.FrontSnap
		if front.is_resolved:
			continue
		var side := front.side_of(p_owner)
		if side == BattleFront.Side.NONE:
			continue
		has_front = true
		var side_troops := front.attacker_troops if side == BattleFront.Side.ATTACKER else front.defender_troops
		max_own_troops = maxi(max_own_troops, side_troops.size())
	if has_front:
		var n_after := max_own_troops + 1
		var n_before := max_own_troops
		var delta_charge := 5 * n_after * (n_after + 1) / 2 - 5 * n_before * (n_before + 1) / 2
		if emp.food - delta_charge < 5:
			return -10.0

	var mu := _military_urgency(state, p_owner)
	var comp := _complement_bonus(troop, emp.troop_pool, state, p_owner)
	var saturation := 1.0 / (1.0 + emp.troop_pool.size() * 0.04)
	var surplus := _resource_surplus_factor(emp, phase)
	var cost_eff := sqrt(30.0 / float(maxi(troop.recruitment_cost_gold, 1)))
	var type_count := 0
	for tt in emp.troop_pool:
		if tt.type == troop.type:
			type_count += 1
	var type_diversity := 1.0 / (1.0 + float(type_count) * 0.2)
	return float(troop.attack + troop.defense) * 3.0 * mu * comp * saturation \
		* surplus * cost_eff * type_diversity


## Espejo de AIHeuristic._complement_bonus: balance atk/def del pool + counter-bonus
## si la tropa es fuerte contra algún tipo visible del rival en los frentes.
static func _complement_bonus(troop: Troop, pool: Array[Troop], state: AIRealState,
		p_owner: int) -> float:
	var base_bonus := 1.0
	if not pool.is_empty():
		var total_atk := 0
		var total_def := 0
		for t in pool:
			total_atk += t.attack
			total_def += t.defense
		var pool_ratio := float(total_atk) / maxf(float(total_def), 1.0)
		var troop_ratio := float(troop.attack) / maxf(float(troop.defense), 1.0)
		if pool_ratio > 2.0 and troop_ratio < 0.8:   base_bonus = 2.0
		elif pool_ratio > 1.5 and troop_ratio < 1.0: base_bonus = 1.5
		elif pool_ratio < 0.5 and troop_ratio > 1.2: base_bonus = 2.0
		elif pool_ratio < 0.8 and troop_ratio > 1.0: base_bonus = 1.5

	var counter_bonus := 1.0
	var enemy := OWNER_RIVAL if p_owner == OWNER_SELF else OWNER_SELF
	var rival_types: Array[int] = []
	for f in state.fronts:
		var front := f as AIRealState.FrontSnap
		if front.is_resolved:
			continue
		var eside := front.side_of(enemy)
		if eside == BattleFront.Side.NONE:
			continue
		var rtroops := front.attacker_troops if eside == BattleFront.Side.ATTACKER else front.defender_troops
		for t in rtroops:
			if t.type not in rival_types:
				rival_types.append(t.type)
	for rt in rival_types:
		if TroopEffectiveness.get_multiplier(troop.type, rt) >= TroopEffectiveness.MULTIPLIER_STRONG:
			counter_bonus = 1.5
			break
	return base_bonus * counter_bonus


## Espejo de AIHeuristic._resource_surplus_factor: [1.0, 3.0]; potencia lo militar
## cuando el oro/comida están muy por encima del umbral cómodo de la fase.
static func _resource_surplus_factor(emp: AIRealState.EmpireSnap,
		phase: AIGamePhase.Phase) -> float:
	if emp.food < 5:
		return 1.0
	var gpt := emp.gold_per_turn
	var comfortable := 350
	match phase:
		AIGamePhase.Phase.EARLY: comfortable = 80
		AIGamePhase.Phase.MID:   comfortable = 200
		_:                       comfortable = 350
	if gpt <= comfortable:
		return 1.0
	return lerpf(1.0, 3.0, clampf(float(gpt - comfortable) / float(comfortable), 0.0, 1.0))


# ---------------------------------------------------------------------------
# Urgencia militar (espejo de AIHeuristic._military_urgency / _max_front_pressure)
# ---------------------------------------------------------------------------

## Baseline por amenaza real (frente activo > enemigo adyacente > tranquilo)
## interpolado hacia 3.0 según la presión del frente más comprometido.
static func _military_urgency(state: AIRealState, p_owner: int) -> float:
	var has_active_front := false
	for f in state.fronts:
		var front := f as AIRealState.FrontSnap
		if not front.is_resolved and front.involves(p_owner):
			has_active_front = true
			break

	var has_adjacent_enemy := false
	if not has_active_front:
		var enemy := OWNER_RIVAL if p_owner == OWNER_SELF else OWNER_SELF
		for id in state.tiles:
			var t := state.tiles[id] as AIRealState.TileSnap
			if t.owner != p_owner:
				continue
			for nid in t.neighbor_ids:
				var nb := state.tiles.get(nid) as AIRealState.TileSnap
				if nb != null and nb.owner == enemy:
					has_adjacent_enemy = true
					break
			if has_adjacent_enemy:
				break

	var base := 0.4
	if has_active_front:     base = 1.5
	elif has_adjacent_enemy: base = 0.9
	return lerpf(base, 3.0, _max_front_pressure(state, p_owner))


## Presión máxima [0.0, 1.0] de los frentes donde participa p_owner (qué tan cerca
## de perder el más comprometido).
static func _max_front_pressure(state: AIRealState, p_owner: int) -> float:
	var max_p := 0.0
	for f in state.fronts:
		var front := f as AIRealState.FrontSnap
		if front.is_resolved:
			continue
		var side := front.side_of(p_owner)
		if side == BattleFront.Side.NONE:
			continue
		var ai_marker := front.marker if side == BattleFront.Side.ATTACKER else -front.marker
		var pressure := clampf(-ai_marker / front.threshold, 0.0, 1.0)
		max_p = maxf(max_p, pressure)
	return max_p


# ---------------------------------------------------------------------------
# Efectos de edificio (espejo de AIHeuristic._score_building_effects / _score_stat_effect)
# ---------------------------------------------------------------------------

static func _score_building_effects(effects: Array[BuildingEffect], state: AIRealState,
		p_owner: int, emp: AIRealState.EmpireSnap, phase: AIGamePhase.Phase,
		gu: float, fu: float, mu: float) -> float:
	if effects.is_empty():
		return 0.0
	var score := 0.0
	for effect in effects:
		if effect == null:
			continue
		if effect is AddStatModifierEffect:
			score += _score_stat_effect(effect as AddStatModifierEffect, state, p_owner,
				emp, gu, fu, mu)
		elif effect is AddBuildCostModifierEffect:
			var pct := (effect as AddBuildCostModifierEffect).percent
			match phase:
				AIGamePhase.Phase.EARLY: score += pct * 0.5
				AIGamePhase.Phase.MID:   score += pct * 1.5
				_:                       score += pct * 1.0
		elif effect is AddCardToDeckEffect:
			var card_added := (effect as AddCardToDeckEffect).card
			if card_added != null:
				# Reusa la aproximación-suelo ya existente sobre el snapshot.
				score += AIRealEvents._score_card_for_deck(card_added, emp)
		elif effect is GoldOnCard:
			score += (effect as GoldOnCard).gold_reward * 0.5 * gu
	return score


static func _score_stat_effect(effect: AddStatModifierEffect, state: AIRealState,
		p_owner: int, emp: AIRealState.EmpireSnap, gu: float, fu: float, mu: float) -> float:
	var v := effect.value
	match effect.stat_type:
		StatModifier.StatType.FLAT_GOLD:
			return v * 5.0 * gu
		StatModifier.StatType.PERCENT_GOLD:
			return emp.gold_per_turn * v / 100.0 * 5.0 * gu
		StatModifier.StatType.FLAT_FOOD:
			return v * 4.0 * fu
		StatModifier.StatType.PERCENT_FOOD:
			return emp.food * v / 100.0 * 4.0 * fu
		StatModifier.StatType.TILE_RESOURCE_GOLD:
			return v * 5.0 * gu
		StatModifier.StatType.TILE_RESOURCE_FOOD:
			return v * 4.0 * fu
		StatModifier.StatType.CARDS_PER_TURN:
			# Valor de FLUJO: el horizonte cae al acercarse a la victoria territorial.
			var enemy := OWNER_RIVAL if p_owner == OWNER_SELF else OWNER_SELF
			var colonizable := _colonizable_count(state, p_owner)
			var total := maxi(state.count_tiles(p_owner) + state.count_tiles(enemy) + colonizable, 1)
			var my_share := float(state.count_tiles(p_owner)) / float(total)
			var horizon := lerpf(5.0, 40.0, clampf(1.0 - my_share / 0.70, 0.0, 1.0))
			return v * (8.0 + horizon * 0.6)
		StatModifier.StatType.CARD_DRAW_BONUS:
			return v * 8.0
		StatModifier.StatType.TROOPS_PER_RECRUIT:
			var current_bonus := _current_troops_per_recruit_bonus(state, p_owner)
			var dr_factor := 1.0 / (1.0 + float(current_bonus) * 0.12)
			return v * (5.0 + 20.0 * mu) * dr_factor
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT:
			return emp.troop_pool.size() * absf(v) * 0.3 * mu
	return 0.0


## Suma el bonus TROOPS_PER_RECRUIT ya activo en los edificios propios (para el
## rendimiento decreciente al valorar un nuevo cuartel).
static func _current_troops_per_recruit_bonus(state: AIRealState, p_owner: int) -> int:
	var total := 0
	for id in state.tiles:
		var t := state.tiles[id] as AIRealState.TileSnap
		if t.owner != p_owner:
			continue
		for building in t.buildings:
			if building == null:
				continue
			for effect in building.effects:
				if effect is AddStatModifierEffect:
					var sme := effect as AddStatModifierEffect
					if sme.stat_type == StatModifier.StatType.TROOPS_PER_RECRUIT:
						total += int(sme.value)
	return total


## Espejo de AIHeuristic._build_cost_factor: penaliza edificios que consumen una
## fracción alta del oro disponible. Rango 0.6 (gasto total) → 1.0 (residual).
static func _build_cost_factor(cost: int, total_gold: int) -> float:
	if total_gold <= 0:
		return 0.6
	return lerpf(1.0, 0.6, clampf(float(cost) / float(total_gold), 0.0, 1.0))


# ---------------------------------------------------------------------------
# Open front (espejo de AIHeuristic._score_open_front)
# ---------------------------------------------------------------------------

## Valor de la tile enemiga × P(ganar) − valor de la tile origen × P(perder), todo
## escalado por seguridad económica, urgencia militar, bioma, factor de pool,
## excedente y carrera territorial. La ganabilidad usa solo info pública del rival
## (edificios defensivos + tropas visibles en frentes sobre esa tile).
static func _score_open_front(move: AIRealOptions.Move, state: AIRealState,
		p_owner: int) -> float:
	var emp := _empire_of(state, p_owner)
	if emp == null:
		return 0.0
	var enemy_tile := state.tiles.get(move.def_tile_id) as AIRealState.TileSnap
	if enemy_tile == null:
		return 0.0
	# Sin tropas libres no tiene sentido abrir un frente.
	var free_troops := emp.troop_pool.size()
	if free_troops == 0:
		return 0.0
	var pool_factor := clampf(float(free_troops) / 6.0, 0.0, 1.5)
	var phase := AIRealEval.detect_phase(state, p_owner)
	var mu := _military_urgency(state, p_owner)

	var base_strategic := 3.0 + mu * 3.0
	var tile_val := float(enemy_tile.resource_gold) * 4.0 \
		+ float(enemy_tile.resource_food) * 2.0 + base_strategic

	# Seguridad económica: abrir frente añade recargo de oro Y comida cada turno.
	var gpt := emp.gold_per_turn
	var food := emp.food
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

	var biome_factor := AIRealSimulator._biome().get_attack_multiplier(enemy_tile.biome)
	var surplus := _resource_surplus_factor(emp, phase)

	# Ganabilidad estimada (info pública): ataque propio vs defensa visible del rival.
	var enemy := OWNER_RIVAL if p_owner == OWNER_SELF else OWNER_SELF
	var win_factor := 0.7
	var own_atk := 0.0
	for t in emp.troop_pool:
		own_atk += float(t.attack)
	own_atk *= biome_factor
	var rival_def := 0.0
	for b in enemy_tile.buildings:
		if b != null:
			rival_def += float(b.flat_defense_bonus)
	rival_def *= AIRealSimulator._biome().get_defense_multiplier(enemy_tile.biome)
	for f in state.fronts:
		var front := f as AIRealState.FrontSnap
		if front.is_resolved:
			continue
		if front.defender_tile_id == move.def_tile_id and front.defender_owner == enemy:
			for t in front.defender_troops:
				rival_def += float(t.defense)
			break
	if own_atk + rival_def > 0.0:
		var ratio := own_atk / maxf(rival_def, 1.0)
		win_factor = clampf(ratio / (ratio + 1.0), 0.2, 0.9)
	else:
		win_factor = 0.5

	# Valor de la tile origen (riesgo del atacante si pierde).
	var source_value := 0.0
	var source := state.tiles.get(move.tile_id) as AIRealState.TileSnap
	if source != null:
		source_value = float(source.buildings.size()) * 3.0 \
			+ float(source.resource_gold) * 2.0 + float(source.resource_food) * 1.5

	return (tile_val * win_factor - source_value * (1.0 - win_factor)) \
		* econ_safety * mu * biome_factor * pool_factor * surplus \
		* _territory_race_factor(state, p_owner, &"open_front")


# ---------------------------------------------------------------------------
# Tactic (espejo de AIHeuristic._score_tactic)
# ---------------------------------------------------------------------------

## Valor táctico escalado por lo comprometido del frente (urgencia = cuánto lo
## estamos perdiendo), la urgencia militar, la fracción de tropas afectadas por la
## carta y el bioma relevante.
static func _score_tactic(move: AIRealOptions.Move, state: AIRealState,
		p_owner: int) -> float:
	if move.front_idx < 0 or move.front_idx >= state.fronts.size():
		return 0.0
	var front := state.fronts[move.front_idx] as AIRealState.FrontSnap
	if front == null or front.is_resolved:
		return 0.0
	var side := front.side_of(p_owner)
	if side == BattleFront.Side.NONE:
		return 0.0
	var is_attacker := side == BattleFront.Side.ATTACKER
	var tactic := move.card as TacticCard
	var own_troops := front.attacker_troops if is_attacker else front.defender_troops

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
		var relevant_tile_id := front.defender_tile_id if is_attacker else front.attacker_tile_id
		var rt := state.tiles.get(relevant_tile_id) as AIRealState.TileSnap
		if rt != null:
			biome_mod = AIRealSimulator._biome().get_attack_multiplier(rt.biome)

	var mu := _military_urgency(state, p_owner)
	var ai_marker := front.marker if is_attacker else -front.marker
	var urgency := clampf(-ai_marker / front.threshold, 0.0, 1.0)
	return (12.0 + urgency * 18.0) * mu * troop_ratio * biome_mod


# ---------------------------------------------------------------------------
# Opciones simples (espejo de AIHeuristic._score_simple / _score_draw / _score_change_location)
# ---------------------------------------------------------------------------

## GENERATE_GOLD: oro inmediato one-shot; vale menos que gold_per_turn.
static func _score_generate_gold(move: AIRealOptions.Move, state: AIRealState,
		p_owner: int) -> float:
	var emp := _empire_of(state, p_owner)
	if emp == null:
		return 0.0
	var phase := AIRealEval.detect_phase(state, p_owner)
	return float(move.amount) * 0.4 * _gold_urgency(emp.gold_per_turn, phase)


## CARD_DRAW: robar cartas escalado por urgencia de mazo. APROXIMACIÓN: la
## heurística usa el tamaño del draw_pile; el snapshot solo tiene el mazo combinado
## (draw+discard), que se usa como proxy.
static func _score_card_draw(move: AIRealOptions.Move, state: AIRealState,
		p_owner: int) -> float:
	var emp := _empire_of(state, p_owner)
	if emp == null:
		return 0.0
	return float(move.amount) * 4.0 * _deck_urgency(emp)


static func _deck_urgency(emp: AIRealState.EmpireSnap) -> float:
	var deck_size := emp.deck.size()
	if deck_size < 3: return 2.0
	if deck_size < 6: return 1.4
	return 1.0


## CHANGE_LOCATION: slots nuevos vs coste en comida, con veto si la comida
## resultante es negativa y penalización por edificios demolidos. APROXIMACIÓN-SUELO:
## se omiten los términos resource_bonus (edificio de recurso mejorado que sobrevive)
## y unlock_bonus (edificios desbloqueados en el nuevo tier) de la heurística real —
## dependen de _is_upgraded_resource_building/_score_unlocked_buildings, acoplados a
## escena. Candidato a port completo si las sims muestran CHANGE_LOCATION infravalorado.
static func _score_change_location(move: AIRealOptions.Move, state: AIRealState,
		p_owner: int) -> float:
	var t := state.tiles.get(move.tile_id) as AIRealState.TileSnap
	var new_loc := move.location
	if t == null or new_loc == null:
		return 0.0
	var emp := _empire_of(state, p_owner)
	if emp == null:
		return 0.0
	var phase := AIRealEval.detect_phase(state, p_owner)
	var delta_consumption := new_loc.food_consumption - t.food_consumption
	var delta_slots := new_loc.max_building - t.max_buildings

	# Veto duro: la comida resultante no puede ser negativa.
	var new_food := emp.food - delta_consumption
	if new_food < 0:
		return -20.0

	var gu := _gold_urgency(emp.gold_per_turn, phase)
	var fu := _food_urgency(emp.food, phase)

	# Penalización por edificios que se demolerían (no compatibles con el nuevo tier).
	var demolished_penalty := 0.0
	for building in t.buildings:
		if building == null:
			continue
		if not AIRealSimulator._building_survives(building, new_loc.type):
			demolished_penalty += float(building.gold_produced) * 4.0 * gu \
				+ float(building.food_produced) * 3.0 * fu \
				+ float(building.flat_defense_bonus) * 6.0

	var base := float(delta_slots) * 10.0 \
		- float(delta_consumption) * 3.0 * _food_urgency(new_food, phase)
	return base - demolished_penalty


# ---------------------------------------------------------------------------
# Urgencias por fase (espejo EXACTO de AIHeuristic — difieren de las simplificadas
# de AIRealEval, que no dependen de fase; por eso se reimplementan aquí)
# ---------------------------------------------------------------------------

static func _gold_urgency(gpt: int, phase: AIGamePhase.Phase) -> float:
	match phase:
		AIGamePhase.Phase.EARLY:
			if gpt < 10: return 3.0
			if gpt < 30: return 1.8
			if gpt < 60: return 1.0
			return 0.7
		AIGamePhase.Phase.MID:
			if gpt < 50:  return 3.0
			if gpt < 150: return 2.0
			if gpt < 250: return 1.3
			if gpt < 400: return 1.0
			return 0.7
		_: # LATE
			if gpt < 0:    return 3.0
			if gpt < 50:   return 2.0
			if gpt < 100:  return 1.3
			if gpt < 200:  return 1.0
			if gpt < 500:  return 0.7
			if gpt < 1000: return 0.5
			if gpt < 2000: return 0.35
			return 0.35


static func _food_urgency(food: int, phase: AIGamePhase.Phase) -> float:
	match phase:
		AIGamePhase.Phase.EARLY:
			if food < 0: return 3.0
			if food < 2: return 1.8
			if food < 5: return 1.0
			return 0.8
		_: # MID / LATE (mismos umbrales en el original)
			if food < 0:  return 3.0
			if food < 5:  return 2.0
			if food < 10: return 1.2
			return 1.0


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

static func _empire_of(state: AIRealState, p_owner: int) -> AIRealState.EmpireSnap:
	if p_owner == OWNER_SELF:
		return state.own
	if p_owner == OWNER_RIVAL:
		return state.rival
	return null
