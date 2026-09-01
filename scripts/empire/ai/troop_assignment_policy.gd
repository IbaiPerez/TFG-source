extends RefCounted
class_name TroopAssignmentPolicy

## Política de asignación de tropas del pool a los frentes propios, compartida por
## el juego real (AIFrontAssignment) y el simulador MCTS (AIRealSimulator).
##
## Decide por VALOR MARGINAL: en cada paso se evalúa, para cada frente, cuánto
## aportaría meter una tropa más frente a lo que cuesta, y se asigna la mejor pareja
## (frente, tropa) mientras el saldo sea positivo. Sin suelo ni techo.
##
## Antes había dos números fijos —rellenar hasta 3 y reforzar hasta 5— y el problema
## no era que estuvieran mal elegidos, sino que el coste de una tropa NO es constante:
## la n-ésima paga su mantenimiento base multiplicado por la curva del frente
## (`CombatMath.front_gold/food_upkeep_multiplier`), convexa y MAS EMPINADA en
## comida que en oro: es la comida la que limita las guarniciones grandes.
##
## Lo que AÑADE cada tropa es por tanto `base · (multiplicador(n) − 1)`: la primera
## sale gratis y a partir de ahí se encarece rápido. Cuántas compensan depende del
## oro y la comida disponibles, de lo urgente que sea el frente y de la tropa
## concreta —una infantería pesada satura el frente antes que una milicia—, que es
## justo lo que un par de constantes no puede expresar.
##
## Opera sobre "slots" (duck typing) que exponen:
##   - base_urgency: float     # urgencia del frente (ver base_urgency())
##   - troop_count() -> int    # tropas propias ya asignadas
##   - peek_best() -> Troop    # la tropa que se asignaría, SIN asignarla
##   - assign_best() -> bool   # asigna esa tropa; false si no se pudo
##
## Se usa la curva de `CombatMath` (la REGLA) y no una estimación ajustable: aquí el
## coste es inmediato y conocido, y esta política la comparte el simulador, que
## aplica la regla real al recalcular la economía.
##
## Limitación no modelada: comprometer tropas arriesga perderlas al resolverse el
## frente (el perdedor pierde 60–100 %). El valor marginal no cotiza ese riesgo.


## Urgencia base de un frente para un bando según lo comprometido que esté el
## marcador (en perspectiva propia: + = ganando) respecto al umbral efectivo.
## 3.0 = perdiendo gravemente | 2.0 = perdiendo | 1.5 = equilibrio
## 0.8 = ganando | 0.3 = casi resuelto
static func base_urgency(own_marker: float, threshold: float) -> float:
	if own_marker < -threshold * 0.5: return 3.0
	if own_marker < 0.0:              return 2.0
	if own_marker < threshold * 0.4:  return 1.5
	if own_marker < threshold * 0.7:  return 0.8
	return 0.3


## Coste marginal en ORO por turno de meter la tropa como n-ésima del bando (n ≥ 1).
##
## La tropa ya pagaba su base estando en el pool, así que lo que AÑADE es solo el
## recargo del frente: `base · (multiplicador(n) − 1)`. De ahí que la primera sea
## GRATIS y que a partir de la segunda crezca de forma convexa. Nunca es negativo.
static func marginal_gold_cost(n: int, troop: Troop) -> float:
	return float(troop.maintenance_gold) * (CombatMath.front_gold_upkeep_multiplier(n) - 1.0)


## Coste marginal en COMIDA por turno. Misma curva sobre el mantenimiento de comida.
static func marginal_food_cost(n: int, troop: Troop) -> float:
	return float(troop.maintenance_food) * (CombatMath.front_food_upkeep_multiplier(n) - 1.0)


## Saldo de meter `troop` como n-ésima tropa de un frente con `urgency`. Positivo =
## compensa. El beneficio usa el poder relevante del bando; el coste convierte
## oro y comida por turno a unidades de score con los MISMOS pesos que valoran la
## producción de un edificio, que es exactamente la misma magnitud.
static func marginal_value(n: int, troop: Troop, power: int, urgency: float,
		gold_urgency: float, food_urgency: float, w: HeuristicWeights) -> float:
	var benefit := float(power) * w.assign_power_weight * urgency
	var cost := marginal_gold_cost(n, troop) * w.gold_weight_pos * gold_urgency \
		+ marginal_food_cost(n, troop) * w.food_weight * food_urgency
	return benefit - cost


## Reparte las tropas del pool entre los slots (todos del mismo imperio).
##
## Greedy global reevaluado en cada paso: no reparte por rondas ni por cuotas, sino
## que en cada iteración busca la asignación de mayor valor marginal entre TODOS los
## frentes. Como el recargo del frente que va recibiendo tropas crece, su valor
## marginal cae solo y el reparto se equilibra sin necesidad de un tope.
static func assign(slots: Array, w: HeuristicWeights,
		gold_urgency: float, food_urgency: float) -> void:
	if slots.is_empty() or w == null:
		return
	var guard := 0
	while guard < 256:
		guard += 1
		var best_slot = null
		var best_value := 0.0
		for slot in slots:
			var troop: Troop = slot.peek_best()
			if troop == null:
				continue
			var value := marginal_value(slot.troop_count() + 1, troop,
				_power_of(slot, troop), _urgency_of(slot),
				gold_urgency, food_urgency, w)
			if value > best_value:
				best_value = value
				best_slot = slot
		if best_slot == null:
			return
		if not best_slot.assign_best():
			return


## Poder relevante de la tropa en ese frente: ataque si atacamos, defensa si
## defendemos. El slot expone `is_attacker()`.
static func _power_of(slot, troop: Troop) -> int:
	return troop.attack if slot.is_attacker() else troop.defense


## Urgencia efectiva: un frente VACÍO vale el doble, porque sin resistencia el
## marcador cae libre. Antes esto solo ordenaba; ahora entra en la valoración, que es
## lo que sustituye al antiguo suelo de tropas por frente.
static func _urgency_of(slot) -> float:
	return slot.base_urgency * (2.0 if slot.troop_count() == 0 else 1.0)
