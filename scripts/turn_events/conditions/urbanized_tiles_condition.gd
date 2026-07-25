extends ThresholdCondition
class_name UrbanizedTilesCondition

## Cuenta las casillas urbanizadas (Town o Megalopolis) controladas y las compara
## con el umbral.


func _value(context: EventContext) -> int:
	var matching := 0
	for tile in context.controlled_tiles:
		if tile.location.type >= Tile.location_type.Town:
			matching += 1
	return matching
