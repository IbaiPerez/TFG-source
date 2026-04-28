extends TurnEventEffect
class_name UrbanizeToMegalopolisEffect

## Efecto que permite al jugador elegir una Town con 3+ edificios
## para urbanizarla a Megalópolis.

const MEGALOPOLIS_TYPE = preload("res://resources/location_type/megalopolis.tres")

var min_buildings: int = 3


func needs_player_input() -> bool:
	return true


func needs_tile_input() -> bool:
	return true


func get_eligible_tiles(context: EventContext) -> Array[Tile]:
	var eligible: Array[Tile] = []
	for tile in context.controlled_tiles:
		if tile.location.type == Tile.location_type.Town:
			if tile.buildings.size() >= min_buildings:
				eligible.append(tile)
	return eligible


func execute(context: EventContext, _chosen_card: Card = null) -> void:
	# La ejecución real se hace en execute_with_tile(), llamado por el panel
	pass


func execute_with_tile(tile: Tile, stats: Stats) -> void:
	if tile == null or tile.location.type != Tile.location_type.Town:
		return

	Events.change_tile_location_type.emit(tile, MEGALOPOLIS_TYPE)

	# Demoler edificios incompatibles con Megalópolis
	for building: Building in tile.buildings:
		if not building.allowed_location_type.is_empty():
			if MEGALOPOLIS_TYPE not in building.allowed_location_type:
				tile.demolish(building, stats)
