extends Effect
class_name  BuildEffect


var building:Building
var stats:Stats

func execute(targets: Array[Node]) -> void:
	if not building:
		return
	for target in targets:
		if not target:
			return
		if target is Tile:
			target.build(building,stats)
