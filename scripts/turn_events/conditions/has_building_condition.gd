extends TurnEventCondition
class_name HasBuildingCondition

## Comprueba si alguna casilla controlada tiene un edificio con el nombre dado.
## Lee los agregados de EventContext (C6 §1.6.2).

var building_name:String


func _init(p_building_name:String):
	building_name = p_building_name


func is_met(context:EventContext) -> bool:
	for tf in context.tile_facts:
		if building_name in tf.building_names:
			return true
	return false
