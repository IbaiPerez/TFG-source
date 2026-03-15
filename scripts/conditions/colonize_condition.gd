extends Condition
class_name ColonizeCondition


func valid_targets(targets:Array[Node]) -> Array[Node]:
	
	var res:Array[Node] = []
	
	for tile:Tile in targets:
		for neighbor:Tile in tile.neighbors:
			if neighbor.controller:
				res.append(neighbor)
				break
	return res
