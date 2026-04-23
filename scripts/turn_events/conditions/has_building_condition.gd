extends TurnEventCondition
class_name HasBuildingCondition

## Comprueba si alguna casilla controlada tiene un edificio con el nombre dado.

var building_name:String


func _init(p_building_name:String):
	building_name = p_building_name


func is_met(context:EventContext) -> bool:
	for tile in context.controlled_tiles:
		for building in tile.buildings:
			if building.name == building_name:
				return true
	return false
