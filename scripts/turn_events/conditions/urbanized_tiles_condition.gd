extends ThresholdCondition
class_name UrbanizedTilesCondition

## Cuenta las casillas urbanizadas (Town o Megalopolis) controladas y las compara
## con el umbral. Lee los agregados de EventContext.


func _value(context: EventContext) -> int:
	var matching := 0
	for tf in context.tile_facts:
		if tf.location_type >= Tile.location_type.Town:
			matching += 1
	return matching
