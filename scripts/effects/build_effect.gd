extends Effect
class_name  BuildEffect


var buildings:Array[Building] = []
var stats:Stats

func execute(targets: Array[Node]) -> void:
	if buildings.is_empty():
		return
	for target in targets:
		if not target:
			return
		if target is Tile:
			if buildings.size() == 1:
				target.build(buildings.get(0),stats)
			if buildings.size() > 1:
				Events.try_to_build.emit(target,target.get_valid_buildings(buildings))
	
