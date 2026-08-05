extends RefCounted
class_name AIRealCombat

## Frentes de batalla sobre el snapshot: reparto de tropas, tick del marcador,
## resolución, bajas y conquista. Espejo de BattleFront / BattleFrontManager.
##
## Es espejo A PROPÓSITO y no reuso: el motor real vive en nodos y emite por el
## bus `Events`, que en una simulación dispararía los trackers del juego. Las
## FÓRMULAS sí se comparten — viven en CombatMath, escritas una sola vez.
##
## La conquista la decide ConquestResolver, también compartido, para que la IA
## prevea exactamente lo que va a ocurrir en la partida real.

# ---------------------------------------------------------------------------
# Asignación de tropas a frentes (espejo de AIController._assign_troops_to_fronts)
# ---------------------------------------------------------------------------

## Reparte las tropas del pool de `p_owner` entre sus frentes usando la política
## compartida TroopAssignmentPolicy (misma urgencia y dos pasadas que el juego
## real); aquí solo construimos los slots sobre los FrontSnap del estado.
static func assign_troops_to_fronts(state: AIRealState,
		p_owner: int = AIRealState.OWNER_SELF) -> void:
	var emp := state.empire(p_owner)
	if emp == null or emp.troop_pool.is_empty():
		return

	var slots: Array = []
	for f in state.fronts:
		var front := f as AIRealState.FrontSnap
		if front.is_resolved:
			continue
		var side := front.side_of(p_owner)
		if side == BattleFront.Side.NONE:
			continue
		var own_marker := front.marker if side == BattleFront.Side.ATTACKER else -front.marker
		var slot := _SnapFrontSlot.new(emp, front, side)
		slot.base_urgency = TroopAssignmentPolicy.base_urgency(
			own_marker, front.current_threshold())
		slots.append(slot)

	TroopAssignmentPolicy.assign(slots)


## Slot de asignación sobre un FrontSnap (ver TroopAssignmentPolicy). Extrae la
## mejor tropa del pool del EmpireSnap y la añade al bando correspondiente.
class _SnapFrontSlot extends RefCounted:
	var emp: AIRealState.EmpireSnap
	var front: AIRealState.FrontSnap
	var side: BattleFront.Side
	var base_urgency: float = 0.0

	func _init(p_emp: AIRealState.EmpireSnap, p_front: AIRealState.FrontSnap,
			p_side: BattleFront.Side) -> void:
		emp = p_emp
		front = p_front
		side = p_side

	func troop_count() -> int:
		var troops := front.attacker_troops if side == BattleFront.Side.ATTACKER \
			else front.defender_troops
		return troops.size()

	func assign_best() -> bool:
		if emp.troop_pool.is_empty():
			return false
		var sorted_pool := emp.troop_pool.duplicate()
		if side == BattleFront.Side.DEFENDER:
			sorted_pool.sort_custom(func(a: Troop, b: Troop) -> bool: return a.defense > b.defense)
		else:
			sorted_pool.sort_custom(func(a: Troop, b: Troop) -> bool: return a.attack > b.attack)
		var best: Troop = sorted_pool[0]
		var idx := emp.troop_pool.find(best)
		if idx < 0:
			return false
		emp.troop_pool.remove_at(idx)
		if side == BattleFront.Side.ATTACKER:
			front.attacker_troops.append(best)
		else:
			front.defender_troops.append(best)
		return true



# ---------------------------------------------------------------------------
# Resolución de frentes (espejo de BattleFront)
# ---------------------------------------------------------------------------

## Tickea todos los frentes activos y purga los resueltos del estado
## (espejo de BattleFrontManager.tick_all_fronts + erase al resolverse).
static func _tick_all_fronts(state: AIRealState) -> void:
	for f in state.fronts.duplicate():
		var front := f as AIRealState.FrontSnap
		if not front.is_resolved:
			_tick_front(state, front)
	var survivors: Array = []
	for f in state.fronts:
		if not (f as AIRealState.FrontSnap).is_resolved:
			survivors.append(f)
	state.fronts = survivors


## Procesa un turno del frente (espejo de BattleFront.tick): mueve el marcador
## por presión, decrementa la duración de los bonuses y resuelve si procede.
## Devuelve true si el frente se resolvió.
static func _tick_front(state: AIRealState, front: AIRealState.FrontSnap) -> bool:
	if front.is_resolved:
		return false
	front.turns_elapsed += 1
	var atk_pressure := _front_pressure(state, front, BattleFront.Side.ATTACKER)
	var def_pressure := _front_pressure(state, front, BattleFront.Side.DEFENDER)
	front.marker += atk_pressure - def_pressure
	_tick_bonuses(front.attacker_bonuses)
	_tick_bonuses(front.defender_bonuses)
	if _front_can_resolve(front):
		_resolve_front(state, front)
		return true
	return false


## Decrementa la duración de los bonuses temporales y elimina los expirados
## (espejo de BattleFront._tick_bonuses).
static func _tick_bonuses(bonuses: Array) -> void:
	var i := bonuses.size() - 1
	while i >= 0:
		var b := bonuses[i] as TacticBonus
		if b != null and b.duration >= 0:
			b.duration -= 1
			if b.duration <= 0:
				bonuses.remove_at(i)
		i -= 1


## Espejo de BattleFront.can_resolve: duración mínima cumplida + |marker| ≥ umbral.
static func _front_can_resolve(front: AIRealState.FrontSnap) -> bool:
	if front.is_resolved:
		return false
	if front.turns_elapsed < front.min_duration:
		return false
	return absf(front.marker) >= front.current_threshold()


## Presión de un bando (delega en CombatMath.pressure).
static func _front_pressure(state: AIRealState, front: AIRealState.FrontSnap,
		side: BattleFront.Side) -> float:
	var atk: float
	var enemy_def: float
	if side == BattleFront.Side.ATTACKER:
		atk = _front_total_attack(state, front, BattleFront.Side.ATTACKER)
		enemy_def = _front_total_defense(state, front, BattleFront.Side.DEFENDER)
	else:
		atk = _front_total_attack(state, front, BattleFront.Side.DEFENDER)
		enemy_def = _front_total_defense(state, front, BattleFront.Side.ATTACKER)
	return CombatMath.pressure(atk, enemy_def)


## Ataque total de un bando: resuelve bioma/combat_mult desde el snapshot y delega
## el cálculo en CombatMath (mismo motor que el juego real). Edificios de ataque: 0.
static func _front_total_attack(state: AIRealState, front: AIRealState.FrontSnap,
		side: BattleFront.Side) -> float:
	var troops: Array[Troop]
	var enemy_troops: Array[Troop]
	var enemy_tile_id: int
	var bonuses: Array[TacticBonus]
	var owner: int
	if side == BattleFront.Side.ATTACKER:
		troops = front.attacker_troops
		enemy_troops = front.defender_troops
		enemy_tile_id = front.defender_tile_id
		bonuses = front.attacker_bonuses
		owner = front.attacker_owner
	else:
		troops = front.defender_troops
		enemy_troops = front.attacker_troops
		enemy_tile_id = front.attacker_tile_id
		bonuses = front.defender_bonuses
		owner = front.defender_owner

	return CombatMath.total_attack(troops, enemy_troops, bonuses,
		_biome().get_attack_multiplier(_biome_of(state, enemy_tile_id)),
		_combat_multiplier_of(state, owner))


## Defensa total de un bando: resuelve edificios/bioma/combat_mult desde el
## snapshot y delega el cálculo en CombatMath.
static func _front_total_defense(state: AIRealState, front: AIRealState.FrontSnap,
		side: BattleFront.Side) -> float:
	var troops: Array[Troop]
	var own_tile_id: int
	var bonuses: Array[TacticBonus]
	var owner: int
	if side == BattleFront.Side.ATTACKER:
		troops = front.attacker_troops
		own_tile_id = front.attacker_tile_id
		bonuses = front.attacker_bonuses
		owner = front.attacker_owner
	else:
		troops = front.defender_troops
		own_tile_id = front.defender_tile_id
		bonuses = front.defender_bonuses
		owner = front.defender_owner

	return CombatMath.total_defense(troops, bonuses,
		_biome().get_defense_multiplier(_biome_of(state, own_tile_id)),
		_combat_multiplier_of(state, owner),
		_building_defense_of(state, own_tile_id))


## Resuelve un frente (espejo de BattleFront._resolve +
## BattleFrontManager._on_front_resolved): determina ganador, conquista la tile
## del perdedor,
## calcula bajas y devuelve los supervivientes al pool de cada imperio.
static func _resolve_front(state: AIRealState, front: AIRealState.FrontSnap) -> void:
	front.is_resolved = true
	var attacker_won := front.marker >= front.current_threshold()
	var casualties := _calculate_casualties(state, front)

	if attacker_won:
		_apply_conquest(state, front.defender_tile_id, front.attacker_owner)
	else:
		_apply_conquest(state, front.attacker_tile_id, front.defender_owner)

	_return_surviving_troops(state, front, casualties)


## Bajas al resolver el frente: computa las presiones desde el snapshot y delega
## en CombatMath.casualties (mismo motor que el juego real).
static func _calculate_casualties(state: AIRealState,
		front: AIRealState.FrontSnap) -> Dictionary:
	var effective_threshold := front.current_threshold()
	var atk_pressure := _front_pressure(state, front, BattleFront.Side.ATTACKER)
	var def_pressure := _front_pressure(state, front, BattleFront.Side.DEFENDER)
	return CombatMath.casualties(front.marker, effective_threshold,
		front.attacker_troops.size(), front.defender_troops.size(),
		atk_pressure, def_pressure)


## Aplica la conquista de una casilla (espejo de BattleFrontManager._apply_conquest):
## demuele el último edificio (placeholder del juego) y cambia el propietario.
## Las casillas colonizadas conservan su location/edificios restantes al conquistarse.
static func _apply_conquest(state: AIRealState, tile_id: int, winner_owner: int) -> void:
	if not state.tiles.has(tile_id):
		return
	var t := AIRealEffects._writable(state, tile_id)   # COW antes de mutar
	# Misma regla que el juego: la comparte ConquestResolver, así que lo que
	# el MCTS predice al conquistar es lo que ocurrirá de verdad.
	for b in ConquestResolver.buildings_to_destroy(t.buildings):
		t.buildings.erase(b)
	t.owner = winner_owner


## Devuelve las tropas supervivientes al pool de cada imperio (espejo de
## BattleFrontManager._return_surviving_troops: elimina las bajas desde el final).
static func _return_surviving_troops(state: AIRealState,
		front: AIRealState.FrontSnap, casualties: Dictionary) -> void:
	var atk_losses: int = casualties["attacker_losses"]
	var def_losses: int = casualties["defender_losses"]

	var atk_survivors := front.attacker_troops.duplicate()
	for _i in range(mini(atk_losses, atk_survivors.size())):
		atk_survivors.pop_back()
	var def_survivors := front.defender_troops.duplicate()
	for _i in range(mini(def_losses, def_survivors.size())):
		def_survivors.pop_back()

	var atk_emp := state.empire(front.attacker_owner)
	if atk_emp != null:
		atk_emp.troop_pool.append_array(atk_survivors)
	var def_emp := state.empire(front.defender_owner)
	if def_emp != null:
		def_emp.troop_pool.append_array(def_survivors)



# --- Internals del combate ------------------------------------------------


## combat_multiplier del imperio dueño de un bando (1.0 si no hay imperio).
static func _combat_multiplier_of(state: AIRealState, p_owner: int) -> float:
	var emp := state.empire(p_owner)
	return emp.combat_multiplier if emp != null else 1.0


## Bioma de una casilla (Grassland=0 por defecto si no existe).
static func _biome_of(state: AIRealState, tile_id: int) -> int:
	var t := state.tiles.get(tile_id) as AIRealState.TileSnap
	return t.biome if t != null else 0


## Suma del flat_defense_bonus de los edificios de una casilla.
static func _building_defense_of(state: AIRealState, tile_id: int) -> float:
	var t := state.tiles.get(tile_id) as AIRealState.TileSnap
	if t == null:
		return 0.0
	var total := 0.0
	for b in t.buildings:
		total += float(b.flat_defense_bonus)
	return total


## Instancia compartida de BiomeConfig (multiplicadores inmutables).
static func _biome() -> BiomeConfig:
	return BiomeConfig.shared()
