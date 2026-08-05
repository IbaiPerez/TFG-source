extends RefCounted
class_name AIRealEvalStrong

## Prior FUERTE sobre el snapshot: la heurística completa a TODA profundidad del árbol.
##
## Motivación (ver análisis de simulación): la fuerza medida del SO-ISMCTS viene de la
## CALIDAD de la guía heurística, no del lookahead en bruto — ISMCTS con rollout
## aleatorio NO supera a la heurística. Por eso la guía fuerte no puede quedarse solo
## en la raíz: este módulo la lleva a cada nodo, en lugar de la aproximación pobre
## AIRealEval.score_move.
##
## Este módulo NO contiene fórmulas de scoring. Se escriben una sola vez en
## AIMoveScorer, contra el puerto AIStateView. Lo que vive aquí son dos cosas:
##
##   (a) El BACKEND del snapshot: los recorridos sobre AIRealState (frentes, tiles,
##       edificios) que SnapshotStateView invoca por callback para responder a los
##       métodos de la vista. Son la mitad "cómo se lee este mundo" de la fórmula.
##   (b) Wrappers finos: guardas + construcción de la vista + dispatch por tipo de
##       jugada hacia el scorer compartido.
##
## Camino CALIENTE: cableado en AIRealMCTS, se evalúa por cada jugada legal en cada
## expansión y rollout, así que cualquier coste añadido aquí se multiplica por miles
## en cada decisión.

const OWNER_SELF := AIRealState.OWNER_SELF
const OWNER_RIVAL := AIRealState.OWNER_RIVAL
const OWNER_NONE := AIRealState.OWNER_NONE


## Prior fuerte de una jugada sobre el snapshot. Los tipos sin scorer propio
## (p.ej. RECOVER) caen al prior débil, AIRealEval.score_move.
static func score_move(move: AIRealOptions.Move, state: AIRealState,
		p_owner: int = OWNER_SELF, w: HeuristicWeights = null) -> float:
	if move == null or move.kind == &"PASS":
		return 0.0
	if w == null: w = HeuristicWeights.get_default()
	match move.kind:
		&"COLONIZE":
			return _score_colonize(move, state, p_owner, w)
		&"BUILD", &"DIRECT_BUILD":
			return _score_build(move, state, p_owner, w)
		&"UPGRADE":
			return _score_upgrade(move, state, p_owner, w)
		&"RECRUIT":
			return _score_recruit(move, state, p_owner, w)
		&"OPEN_FRONT":
			return _score_open_front(move, state, p_owner, w)
		&"TACTIC":
			return _score_tactic(move, state, p_owner, w)
		&"GENERATE_GOLD":
			return _score_generate_gold(move, state, p_owner, w)
		&"CARD_DRAW":
			return _score_card_draw(move, state, p_owner, w)
		&"CHANGE_LOCATION":
			return _score_change_location(move, state, p_owner, w)
		_:
			# Tipos raros no cubiertos (p.ej. RECOVER): fallback al prior débil.
			return AIRealEval.score_move(move, state, p_owner)


# ---------------------------------------------------------------------------
# Colonize: wrapper + backend de territorio de la vista
# ---------------------------------------------------------------------------

## Prior de COLONIZE. La fórmula (producción + presión de expansión + valor de
## frontera escalado por encierro + bonus de negación, todo por la carrera
## territorial) vive en AIMoveScorer.score_colonize.
static func _score_colonize(move: AIRealOptions.Move, state: AIRealState,
		p_owner: int, w: HeuristicWeights) -> float:
	# Guardas propias del snapshot (casilla objetivo válida + emp) antes de
	# construir la vista.
	var t := state.tiles.get(move.tile_id) as AIRealState.TileSnap
	if t == null:
		return 0.0
	var view := SnapshotStateView.new(state, p_owner, w)
	if not view.is_valid():
		return 0.0
	return AIMoveScorer.score_colonize(view, t)


# ---------------------------------------------------------------------------
# Build / Direct build: wrappers
# ---------------------------------------------------------------------------

## Prior de BUILD y DIRECT_BUILD, que comparten scorer. La fórmula (producción
## ponderada por urgencia + defensa + efectos del edificio, por el factor de coste,
## más micro-tie-breakers de casilla) vive en AIMoveScorer.score_build.
static func _score_build(move: AIRealOptions.Move, state: AIRealState,
		p_owner: int, w: HeuristicWeights) -> float:
	# El tie-breaker por casilla se omite si la casilla no existe (tile null).
	if move.building == null:
		return 0.0
	var view := SnapshotStateView.new(state, p_owner, w)
	if not view.is_valid():
		return 0.0
	return AIMoveScorer.score_build(view, move.building, state.tiles.get(move.tile_id))


## Prior de UPGRADE; la fórmula vive en AIMoveScorer.score_upgrade.
static func _score_upgrade(move: AIRealOptions.Move, state: AIRealState,
		p_owner: int, w: HeuristicWeights) -> float:
	if move.old_building == null or move.new_building == null:
		return 0.0
	var view := SnapshotStateView.new(state, p_owner, w)
	if not view.is_valid():
		return 0.0
	return AIMoveScorer.score_upgrade(view, move.old_building, move.new_building)


# ---------------------------------------------------------------------------
# Recruit: wrapper + backend militar y económico de la vista
# ---------------------------------------------------------------------------

## Prior de RECRUIT. La fórmula (poder de la tropa por urgencia militar,
## complementariedad con el pool y la composición rival visible, excedente
## económico, coste-eficiencia y diversidad de tipo, con vetos si el mantenimiento
## o el recargo cuadrático de frente hundirían la comida/gpt) vive en
## AIMoveScorer.score_recruit.
static func _score_recruit(move: AIRealOptions.Move, state: AIRealState,
		p_owner: int, w: HeuristicWeights) -> float:
	if move.troop == null:
		return 0.0
	var view := SnapshotStateView.new(state, p_owner, w)
	if not view.is_valid():
		return 0.0
	return AIMoveScorer.score_recruit(view, move.troop)



# ---------------------------------------------------------------------------
# Efectos de edificio: backend de la vista
# ---------------------------------------------------------------------------

## Backend de `AIStateView.score_building_effects`. `view` es la SnapshotStateView
## que ya construyó el llamante: se reutiliza para la rama AddCardToDeckEffect sin
## asignar otra en el camino caliente.
static func _score_building_effects(effects: Array[BuildingEffect], state: AIRealState,
		p_owner: int, emp: AIRealState.EmpireSnap, phase: AIGamePhase.Phase,
		gu: float, fu: float, mu: float, w: HeuristicWeights,
		view: AIStateView = null) -> float:
	if effects.is_empty():
		return 0.0
	var score := 0.0
	for effect in effects:
		if effect == null:
			continue
		if effect is AddStatModifierEffect:
			score += _score_stat_effect(effect as AddStatModifierEffect, state, p_owner,
				emp, gu, fu, mu, w)
		elif effect is AddBuildCostModifierEffect:
			score += AIBuildingEffects.build_cost_modifier_score(
				(effect as AddBuildCostModifierEffect).percent, phase, w)
		elif effect is AddCardToDeckEffect:
			var card_added := (effect as AddCardToDeckEffect).card
			if card_added != null and view != null:
				score += AIDeckScorer.score_card_for_deck(view, card_added)
		elif effect is GoldOnCard:
			score += AIBuildingEffects.gold_on_card_score(
				(effect as GoldOnCard).gold_reward, gu, w)
	return score


static func _score_stat_effect(effect: AddStatModifierEffect, state: AIRealState,
		p_owner: int, emp: AIRealState.EmpireSnap, gu: float, fu: float, mu: float,
		w: HeuristicWeights) -> float:
	var v := effect.value
	# Los dos casos dependientes de estado calculan su escalar SOLO en su rama
	# (recorridos caros); el resto delega en el helper puro compartido.
	match effect.stat_type:
		StatModifier.StatType.CARDS_PER_TURN:
			var enemy := OWNER_RIVAL if p_owner == OWNER_SELF else OWNER_SELF
			var colonizable := AISnapshotFacts._colonizable_count(state, p_owner)
			var total := maxi(state.count_tiles(p_owner) + state.count_tiles(enemy) + colonizable, 1)
			var my_share := float(state.count_tiles(p_owner)) / float(total)
			return AIBuildingEffects.cards_per_turn_score(v, my_share, w)
		StatModifier.StatType.TROOPS_PER_RECRUIT:
			return AIBuildingEffects.troops_per_recruit_score(v, mu,
				AISnapshotFacts._current_troops_per_recruit_bonus(state, p_owner), w)
		_:
			return AIBuildingEffects.stat_effect_simple(effect.stat_type, v,
				emp.gold_per_turn, emp.food, emp.troop_pool.size(), gu, fu, mu, w)




# ---------------------------------------------------------------------------
# Open front: wrapper
# ---------------------------------------------------------------------------

## Prior de OPEN_FRONT. La fórmula (valor de la tile enemiga × P(ganar) − valor de
## la tile origen × P(perder), escalado por seguridad económica, urgencia militar,
## bioma, factor de pool, excedente y carrera territorial) vive en
## AIMoveScorer.score_open_front.
static func _score_open_front(move: AIRealOptions.Move, state: AIRealState,
		p_owner: int, w: HeuristicWeights) -> float:
	# Guardas: emp válido + la casilla enemiga existe. El veto por 0 tropas libres
	# vive dentro del scorer.
	var view := SnapshotStateView.new(state, p_owner, w)
	if not view.is_valid():
		return 0.0
	var enemy_tile := state.tiles.get(move.def_tile_id) as AIRealState.TileSnap
	if enemy_tile == null:
		return 0.0
	return AIMoveScorer.score_open_front(view, enemy_tile, state.tiles.get(move.tile_id))


# ---------------------------------------------------------------------------
# Tactic: wrapper
# ---------------------------------------------------------------------------

## Prior de TACTIC. La fórmula (valor táctico por lo comprometido del frente, la
## urgencia militar, la fracción de tropas afectadas y el bioma relevante) vive en
## AIMoveScorer.score_tactic.
static func _score_tactic(move: AIRealOptions.Move, state: AIRealState,
		p_owner: int, w: HeuristicWeights) -> float:
	# El frente se resuelve por índice y se descompone aquí: BattleFront y FrontSnap
	# difieren demasiado para que el scorer reciba el frente entero.
	if move.front_idx < 0 or move.front_idx >= state.fronts.size():
		return 0.0
	var front := state.fronts[move.front_idx] as AIRealState.FrontSnap
	if front == null or front.is_resolved:
		return 0.0
	var side := front.side_of(p_owner)
	if side == BattleFront.Side.NONE:
		return 0.0
	var is_attacker := side == BattleFront.Side.ATTACKER
	var own_troops := front.attacker_troops if is_attacker else front.defender_troops
	var relevant_tile_id := front.defender_tile_id if is_attacker else front.attacker_tile_id
	var ai_marker := front.marker if is_attacker else -front.marker
	return AIMoveScorer.score_tactic(SnapshotStateView.new(state, p_owner, w),
		move.card as TacticCard, own_troops, ai_marker, front.threshold,
		state.tiles.get(relevant_tile_id))


# ---------------------------------------------------------------------------
# Opciones simples: wrappers
# ---------------------------------------------------------------------------

## Prior de GENERATE_GOLD; la fórmula vive en AIMoveScorer.score_generate_gold.
## Aquí solo el guarda emp==null (vía is_valid) y la construcción de la vista.
static func _score_generate_gold(move: AIRealOptions.Move, state: AIRealState,
		p_owner: int, w: HeuristicWeights) -> float:
	var view := SnapshotStateView.new(state, p_owner, w)
	if not view.is_valid():
		return 0.0
	return AIMoveScorer.score_generate_gold(view, move.amount)


## Prior de CARD_DRAW; la fórmula vive en AIMoveScorer.score_card_draw.
static func _score_card_draw(move: AIRealOptions.Move, state: AIRealState,
		p_owner: int, w: HeuristicWeights) -> float:
	var view := SnapshotStateView.new(state, p_owner, w)
	if not view.is_valid():
		return 0.0
	return AIMoveScorer.score_card_draw(view, move.amount)


## CHANGE_LOCATION: slots nuevos vs coste en comida, con veto si la comida
## resultante es negativa y penalización por edificios demolidos. APROXIMACIÓN-SUELO:
## se omiten los términos resource_bonus (edificio de recurso mejorado que sobrevive)
## y unlock_bonus (edificios desbloqueados en el nuevo tier) de la heurística real —
## dependen de _is_upgraded_resource_building/_score_unlocked_buildings, acoplados a
## escena. Candidato a port completo si las sims muestran CHANGE_LOCATION infravalorado.
static func _score_change_location(move: AIRealOptions.Move, state: AIRealState,
		p_owner: int, w: HeuristicWeights) -> float:
	# La aproximación-suelo del snapshot (sin bonos de recurso/desbloqueo) vive en
	# SnapshotStateView.change_location_adjust.
	var t := state.tiles.get(move.tile_id) as AIRealState.TileSnap
	var new_loc := move.location
	if t == null or new_loc == null:
		return 0.0
	var view := SnapshotStateView.new(state, p_owner, w)
	if not view.is_valid():
		return 0.0
	return AIMoveScorer.score_change_location(view, t, new_loc)
