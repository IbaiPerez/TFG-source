extends TurnEventCondition
class_name ThresholdCondition

## Base para las condiciones de la forma:
##   Comparison.evaluate(valor(context), op, threshold)
##
## Las subclases solo implementan `_value(context)`; el operador, el umbral y el
## `is_met` viven aquí. El operador por defecto es "al menos": es el de 50 de los
## 52 usos del catálogo.

var threshold: int
var op: Comparison.Type


func _init(p_threshold: int, p_op: Comparison.Type = Comparison.Type.GREATER_EQUAL) -> void:
	threshold = p_threshold
	op = p_op


func is_met(context: EventContext) -> bool:
	return Comparison.evaluate(_value(context), op, threshold)


## Valor concreto a comparar contra el umbral. Lo implementa cada subclase.
func _value(_context: EventContext) -> int:
	return 0
