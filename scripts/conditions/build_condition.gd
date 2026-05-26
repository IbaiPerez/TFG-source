extends Condition
class_name BuildCondition

var buildings:Array[Building] = []
var stats:Stats

func is_valid_target(target:Node) -> bool:
	if target is not Tile:
		return false
	
	if target.controller == stats.empire:
		if buildings.is_empty():
			return false
		elif buildings.size() == 1:
			# Coste efectivo: si Banca Florentina o eventos abaratan, el
			# tile pasa a ser valid aunque el coste raw no entrara en el
			# oro disponible.
			return target.can_build(buildings.get(0)) \
					and stats.total_gold >= buildings.get(0).get_effective_construction_cost(stats)
		else:
			for building:Building in buildings:
				if building.get_effective_construction_cost(stats) <= stats.total_gold \
						and target.can_build(building):
					return true
	return false


func valid_targets() -> Array[Node]:
	var res:Array[Node] = []
	for tile:Tile in stats.empire.controlled_tiles:
		if is_valid_target(tile):
			res.append(tile)
	
	return res
