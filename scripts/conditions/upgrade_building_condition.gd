extends Condition
class_name UpgradeBuildingCondition

var stats:Stats

func is_valid_target(target:Node) -> bool:
	if target is not Tile:
		return false
	
	if target.controller == stats.empire and target.has_upgradable_buildings(stats):
		return true
	
	return false

func valid_targets() -> Array[Node]:
	var res:Array[Node] = []
	for tile in stats.empire.controlled_tiles:
		if is_valid_target(tile):
			res.append(tile)
	return res
