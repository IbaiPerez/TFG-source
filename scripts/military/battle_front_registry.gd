extends Node
class_name BattleFrontRegistrySingleton

## Registro global centralizado de todos los frentes activos (no resueltos).
## Reemplaza el anti-patrón de static var en BattleFront.

var _active_instances: Array[BattleFront] = []


## Registra un nuevo frente activo.
func register(front: BattleFront) -> void:
	if front not in _active_instances:
		_active_instances.append(front)


## Desregistra un frente resuelto.
func unregister(front: BattleFront) -> void:
	_active_instances.erase(front)


## Comprueba si una tile está participando en algún frente activo.
func is_tile_in_active_front(tile: Tile) -> bool:
	for front in _active_instances:
		if front.attacker_tile == tile or front.defender_tile == tile:
			return true
	return false


## Devuelve una copia de la lista de frentes activos.
func get_active_instances() -> Array[BattleFront]:
	return _active_instances.duplicate()


## Limpia el registro (útil para tests).
func clear() -> void:
	_active_instances.clear()
