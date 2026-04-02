extends Effect
class_name UpgradeBuildingEffect

var old_building:Building
var new_building:Building
var stats:Stats

func execute(targets: Array[Node]) -> void:
	if not new_building or not old_building:
		return
	for target in targets:
		if not target:
			return
		if target is Tile:
			target.upgrade(old_building, new_building,stats)
