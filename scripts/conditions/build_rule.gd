extends TargetRule
class_name BuildRule

var buildings:Array[Building] = []
var stats:Stats

func is_valid_target(target:Node) -> bool:
	if target is not Tile:
		return false
	
	if target.controller == stats.empire:
		if buildings.is_empty():
			return false
		elif buildings.size() == 1:
			# is_affordable usa el coste EFECTIVO: si Banca Florentina o eventos
			# abaratan, el tile pasa a ser valid aunque el coste raw no entrara
			# en el oro disponible.
			return target.can_build(buildings.get(0)) \
					and buildings.get(0).is_affordable(stats)
		else:
			for building:Building in buildings:
				if building.is_affordable(stats) and target.can_build(building):
					return true
	return false


func valid_targets() -> Array[Node]:
	var res:Array[Node] = []
	for tile:Tile in stats.empire.controlled_tiles:
		if is_valid_target(tile):
			res.append(tile)
	
	return res
