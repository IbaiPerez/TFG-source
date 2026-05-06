extends Condition
class_name EnemyAdjacentCondition

## Condición que filtra tiles controladas por otro imperio
## y adyacentes a tiles del imperio propio.

var empire: Empire
var battle_front_manager: BattleFrontManager


func valid_targets() -> Array[Node]:
	var seen: Dictionary[Node, bool] = {}

	for tile: Tile in empire.controlled_tiles:
		for target: Tile in tile.neighbors:
			if target and target.controller != null and target.controller != empire:
				# Verificar que no existe ya un frente en estas tiles
				if battle_front_manager == null or battle_front_manager.get_front_for_tile(target) == null:
					seen[target] = true
	return seen.keys()


func is_valid_target(target: Node) -> bool:
	if not target is Tile:
		return false
	if target.controller == null or target.controller == empire:
		return false
	# Verificar adyacencia con alguna tile propia
	for neighbor in target.neighbors:
		if neighbor != null and neighbor.controller == empire:
			# Verificar que no hay frente activo en esta tile
			if battle_front_manager == null or battle_front_manager.get_front_for_tile(target) == null:
				return true
	return false
