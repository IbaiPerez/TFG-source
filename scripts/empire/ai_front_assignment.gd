extends RefCounted
class_name AIFrontAssignment

## Asigna tropas del pool a los frentes propios con prioridad por urgencia.
##
## Heurística v2:
##   1. Calcula urgency_score para cada frente (posición del marker vs umbral).
##      Frentes sin tropas reciben urgencia × 2: sin resistencia el marker cae libre.
##   2. Ordena frentes por urgencia DESC.
##   3. Primera pasada: llenar hasta MIN_TROOPS_PER_FRONT empezando por el más urgente.
##      Tropa elegida: defensor → max defense; atacante → max attack.
##   4. Segunda pasada: reforzar hasta MIN + 2 los frentes donde se pierde
##      activamente (base_urgency > 1.5, es decir, marker negativo).
##
## Pre: solo lo llama AIController; el jugador asigna via BattleFrontPanel.
## El algoritmo (urgencia + dos pasadas) vive en TroopAssignmentPolicy, compartido
## con el simulador MCTS; aquí solo construimos los slots sobre los BattleFront reales.
static func assign(bfm: BattleFrontManager, stats: Stats) -> void:
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

	TroopAssignmentPolicy.assign(slots)


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

	func assign_best() -> bool:
		if stats.troop_pool.is_empty():
			return false
		var sorted_pool := stats.troop_pool.duplicate()
		if side == BattleFront.Side.DEFENDER:
			sorted_pool.sort_custom(func(a: Troop, b: Troop) -> bool: return a.defense > b.defense)
		else:
			sorted_pool.sort_custom(func(a: Troop, b: Troop) -> bool: return a.attack > b.attack)
		return bfm.assign_troop_to_front(front, sorted_pool[0], side)
