extends TurnEventCondition
class_name ThresholdCondition

## Base para las condiciones de la forma:
##   Comparison.evaluate(valor(context), op, threshold)
##
## Las subclases solo implementan `_value(context)`; el operador, el umbral y el
## `is_met` viven aquí. Antes cada condición reescribía las mismas 4 líneas de
## ceremonia (campo op, campo umbral, _init, is_met), con la inconsistencia extra
## de que unas llamaban al umbral `threshold` y otras `count`. Ahora es `threshold`
## en todas.

var threshold: int
var op: Comparison.Type


func _init(p_threshold: int, p_op: Comparison.Type) -> void:
	threshold = p_threshold
	op = p_op


func is_met(context: EventContext) -> bool:
	return Comparison.evaluate(_value(context), op, threshold)


## Valor concreto a comparar contra el umbral. Lo implementa cada subclase.
func _value(_context: EventContext) -> int:
	return 0
