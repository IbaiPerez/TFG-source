extends Effect
class_name ColonizeEffect

var controller:Empire


func execute(targets: Array[Node]) -> void:
	if not controller:
		return
	for target in targets:
		if not target:
			return
		if target is Tile:
			Events.change_tile_controller.emit(target,controller)
