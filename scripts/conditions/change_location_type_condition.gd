extends Condition
class_name ChangeLocationTypeCondition

var location_type:LocationType
var stats:Stats

func is_valid_target(target:Node) -> bool:
	if not target is Tile:
		return false
	if target.controller == stats.empire and location_type.type == (
		target.location.type + 1
		) and stats.food >= location_type.food_consumption:
		return true
	return false

func valid_targets() -> Array[Node]:
	var res:Array[Node]= []
	for tile in stats.empire.controlled_tiles:
		if is_valid_target(tile):
			res.append(tile)
	return res
