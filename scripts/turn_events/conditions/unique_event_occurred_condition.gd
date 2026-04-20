extends TurnEventCondition
class_name UniqueEventOccurredCondition

## Comprueba si un evento unico ya ha ocurrido en la partida.
## Util para desbloquear eventos que dependen de que otro haya pasado primero.

var event_id:String


func _init(p_event_id:String):
	event_id = p_event_id


func is_met(context:EventContext) -> bool:
	return event_id in context.stats.used_unique_events
