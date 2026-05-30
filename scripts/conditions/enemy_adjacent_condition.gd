extends Condition
class_name EnemyAdjacentCondition

## Condición que filtra tiles controladas por otro imperio
## y adyacentes a tiles del imperio propio.

var empire: Empire
var battle_front_manager: BattleFrontManager


func valid_targets() -> Array[Node]:
	var seen: Dictionary[Node, bool] = {}

	for tile: Tile in empire.controlled_tiles:
		# Una tile propia ya en un frente no puede ser origen de otro ataque
		if BattleFront.is_tile_in_active_front(tile):
			continue
		for target: Tile in tile.neighbors:
			if target and target.controller != null and target.controller != empire:
				# Usar el registro global para detectar frentes tanto en tiles
				# atacantes como en tiles defensoras de cualquier imperio
				if not BattleFront.is_tile_in_active_front(target):
					seen[target] = true
	return seen.keys()


func is_valid_target(target: Node) -> bool:
	if not target is Tile:
		return false
	if target.controller == null or target.controller == empire:
		return false
	if BattleFront.is_tile_in_active_front(target):
		return false
	# Verificar adyacencia con alguna tile propia libre de frentes activos
	for neighbor in target.neighbors:
		if neighbor != null and neighbor.controller == empire:
			if not BattleFront.is_tile_in_active_front(neighbor):
				return true
	return false
