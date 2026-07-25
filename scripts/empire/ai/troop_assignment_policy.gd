extends RefCounted
class_name TroopAssignmentPolicy

## Política de asignación de tropas del pool a los frentes propios, compartida por
## el juego real (AIController) y el simulador MCTS (AIRealSimulator) — antes
## estaba escrita dos veces con los mismos umbrales.
##
## Prioriza por urgencia (lo comprometido que está el marcador) y rellena en dos
## pasadas: hasta MIN_TROOPS_PER_FRONT en todos los frentes, y luego hasta MIN+2 en
## los que se pierden activamente. Opera sobre "slots" (duck typing) que exponen:
##   - base_urgency: float     # urgencia base del frente (ver base_urgency())
##   - troop_count() -> int    # tropas propias ya asignadas al frente
##   - assign_best() -> bool   # asigna la mejor tropa del pool al frente; false si
##                             #   el pool está vacío o no se pudo asignar

const MIN_TROOPS_PER_FRONT: int = 3


## Urgencia base de un frente para un bando según lo comprometido que está el
## marcador (en perspectiva propia: + = ganando) respecto al umbral efectivo.
## 3.0 = perdiendo gravemente | 2.0 = perdiendo | 1.5 = equilibrio
## 0.8 = ganando | 0.3 = casi resuelto
static func base_urgency(own_marker: float, threshold: float) -> float:
	if own_marker < -threshold * 0.5: return 3.0
	if own_marker < 0.0:              return 2.0
	if own_marker < threshold * 0.4:  return 1.5
	if own_marker < threshold * 0.7:  return 0.8
	return 0.3


## Reparte las tropas del pool entre los slots (todos del mismo imperio),
## priorizando por urgencia. Cada slot ya trae su base_urgency calculada.
static func assign(slots: Array) -> void:
	if slots.is_empty():
		return

	# Urgencia total = base × 2 si el frente está vacío (sin resistencia el marker
	# cae libre). Se calcula sobre el recuento INICIAL, antes de asignar nada.
	var ranked: Array = []
	for slot in slots:
		var full_urg: float = slot.base_urgency * (2.0 if slot.troop_count() == 0 else 1.0)
		ranked.append({"slot": slot, "full_urg": full_urg})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.full_urg > b.full_urg)

	# Primera pasada: llenar hasta MIN_TROOPS_PER_FRONT (assign_best devuelve false
	# cuando el pool se agota, cortando el bucle).
	for e in ranked:
		var slot = e.slot
		while slot.troop_count() < MIN_TROOPS_PER_FRONT:
			if not slot.assign_best():
				break

	# Segunda pasada: reforzar hasta MIN+2 los frentes que se pierden activamente.
	for e in ranked:
		var slot = e.slot
		if slot.base_urgency <= 1.5:
			continue
		while slot.troop_count() < MIN_TROOPS_PER_FRONT + 2:
			if not slot.assign_best():
				break
