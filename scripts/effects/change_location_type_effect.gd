extends Effect
class_name ChangeLocationTypeEffect

var location_type:LocationType
var stats:Stats

func execute(targets: Array[Node]) -> void:
	if not location_type:
		return
	for target in targets:
		if not target:
			return
		if target is Tile:
			Events.change_tile_location_type.emit(target,location_type)
			for building:Building in target.buildings:
				if location_type not in building.allowed_location_type:
					target.demolish(building,stats)
