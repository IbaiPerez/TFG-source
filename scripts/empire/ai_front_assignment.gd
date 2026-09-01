extends RefCounted
class_name AIFrontAssignment

## Asigna tropas del pool a los frentes propios con prioridad por urgencia.
##
## No hay suelo ni techo de tropas por frente: se asigna mientras meter una más
## aporte más de lo que cuesta. El coste marginal no es constante —el recargo del
## frente crece con cada tropa, pero la asignada deja de pagar mantenimiento base—,
## así que cuántas compensan depende de la comida, de la urgencia del frente y de la
## tropa concreta. La tropa elegida sigue siendo la mejor del pool para ese bando:
## defensor → max defense; atacante → max attack.
##
## Pre: solo lo llama AIController; el jugador asigna via BattleFrontPanel.
## El algoritmo (urgencia + dos pasadas) vive en TroopAssignmentPolicy, compartido
## con el simulador MCTS; aquí solo construimos los slots sobre los BattleFront reales.
static func assign(bfm: BattleFrontManager, stats: Stats,
		w: HeuristicWeights = null, total_map_tiles: int = 0) -> void:
	if w == null:
		w = HeuristicWeights.get_default()
	if bfm == null:
		return
	if stats == null or stats.troop_pool.is_empty():
		return

	var slots: Array = []
	for front in bfm.get_registry().get_active_instances():
		if front == null or front.is_resolved:
			continue
		var side: BattleFront.Side
		if front.attacker_empire == stats.empire:
			side = BattleFront.Side.ATTACKER
		elif front.defender_empire == stats.empire:
			side = BattleFront.Side.DEFENDER
		else:
			continue
		var own_marker := front.marker if side == BattleFront.Side.ATTACKER else -front.marker
		var slot := _LiveFrontSlot.new(front, side, stats, bfm)
		slot.base_urgency = TroopAssignmentPolicy.base_urgency(
			own_marker, front.get_current_threshold())
		slots.append(slot)

	# El coste marginal de cada tropa se valora con la escasez ACTUAL de oro y comida.
	var phase := AIGamePhase.detect(stats, total_map_tiles, w)
	TroopAssignmentPolicy.assign(slots, w,
		AIUrgency.gold_urgency(stats.gold_per_turn, phase, w),
		AIUrgency.food_urgency(stats.food, phase, w))


## Slot de asignación sobre un BattleFront real (ver TroopAssignmentPolicy).
## Defensor → max defense; Atacante → max attack. Asigna vía el BattleFrontManager.
class _LiveFrontSlot extends RefCounted:
	var front: BattleFront
	var side: BattleFront.Side
	var stats: Stats
	var bfm: BattleFrontManager
	var base_urgency: float = 0.0

	func _init(p_front: BattleFront, p_side: BattleFront.Side, p_stats: Stats,
			p_bfm: BattleFrontManager) -> void:
		front = p_front
		side = p_side
		stats = p_stats
		bfm = p_bfm

	func troop_count() -> int:
		var troops := front.attacker_troops if side == BattleFront.Side.ATTACKER \
			else front.defender_troops
		return troops.size()

	func is_attacker() -> bool:
		return side == BattleFront.Side.ATTACKER

	## Tropa que se asignaría, SIN asignarla: la política la valora antes de
	## comprometerla. null si el pool está vacío.
	func peek_best() -> Troop:
		if stats.troop_pool.is_empty():
			return null
		var sorted_pool := stats.troop_pool.duplicate()
		if side == BattleFront.Side.DEFENDER:
			sorted_pool.sort_custom(func(a: Troop, b: Troop) -> bool: return a.defense > b.defense)
		else:
			sorted_pool.sort_custom(func(a: Troop, b: Troop) -> bool: return a.attack > b.attack)
		return sorted_pool[0]

	func assign_best() -> bool:
		var best := peek_best()
		if best == null:
			return false
		return bfm.assign_troop_to_front(front, best, side)
