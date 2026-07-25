extends RefCounted
class_name ScaledValue

## Valor escalado por el turno y por una magnitud de referencia:
##   base + turno · turn_factor + reference · ref_percent
##
## La misma fórmula la usaban, reescrita, los efectos y costes escalados de evento
## (ScaledGoldEffect, ScaledFoodEffect, ScaledStatModifierEffect,
## ScaledBuildCostModifierEffect, ScaledGoldCost) y su espejo en AIRealEvents. Aquí
## vive una sola vez.
##
## El término de referencia es opcional: para escalados que solo dependen del turno
## (BuildCost) basta con dejar `reference` en 0.
static func evaluate(base: float, turn_factor: float, ref_percent: float,
		turn: int, reference: float = 0.0) -> float:
	return base + float(turn) * turn_factor + reference * ref_percent
