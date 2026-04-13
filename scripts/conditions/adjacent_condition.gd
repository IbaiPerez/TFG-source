extends Condition
class_name AdjacentCondition

var empire:Empire

func valid_targets() -> Array[Node]:
	
	var seen:Dictionary[Node,bool] = {}
	
	for tile:Tile in empire.controlled_tiles:
		for target:Tile in tile.neighbors:
			if target and target.controller == null:
				seen[target] = true
	return seen.keys()
	
func is_valid_target(target:Node) -> bool:
	if not target is Tile:
		return false
	if not target.controller == null:
		return false
	for neighbor in target.neighbors:
		if (not neighbor == null) and neighbor.controller == empire:
			return true
	return false
