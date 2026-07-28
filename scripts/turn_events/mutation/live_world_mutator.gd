extends WorldMutator
class_name LiveWorldMutator

## Muta el mundo VIVO emitiendo por el bus `Events` (el comportamiento actual de los
## efectos). Byte-idéntico a las llamadas directas que sustituye.

func set_controller(tile, empire) -> void:
	Events.change_tile_controller.emit(tile, empire)


func set_location_type(tile, location_type) -> void:
	Events.change_tile_location_type.emit(tile, location_type)


func demolish(tile, building, stats) -> void:
	tile.demolish(building, stats)
