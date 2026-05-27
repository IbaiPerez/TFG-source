extends Node

# Dependencies
@export var settings : GenerationSettings
@export_category("Dependencies")
@export var tile_parent : Node3D

## Si es true (default), `_ready()` dispara init_seed + generate_world
## automaticamente al entrar al arbol. Es lo que necesita la escena de
## juego real (`map.tscn`), donde el WorldGenerator es un nodo declarado
## y queremos que arranque solo.
##
## Los harnesses headless (p.ej. `tests/simulation/game_sim_harness.gd`)
## deben ponerlo a false antes de `add_child(generator)`: el harness
## conduce manualmente init_seed + generate_world para controlar el
## seeding y evitar la doble generacion. Si quedara a true, `_ready`
## generaria un mapa, el harness generaria otro encima, y `EmpireCreator`
## se ejecutaria dos veces sobre WorldMaps distintos: si el segundo
## falla por mapa degenerado, un imperio queda colocado en el primer
## mapa (huerfano) y el otro acaba con 0 tiles.
@export var auto_generate_on_ready : bool = true

## Starting point: Generate a random seed, create the tiles, place POI's
func _ready() -> void:
	if not auto_generate_on_ready:
		return
	# Si hay un snapshot pendiente, no generamos nada: Map._ready() se
	# encargará de reconstruir el mundo desde el save tras nosotros.
	if not GameSaveManager.pending_snapshot.is_empty():
		return
	init_seed()
	generate_world()


# Randomize if no seed has been set
func init_seed():
	if settings.map_seed == 0 or settings.map_seed == null:
		GameLogger.debug("Randomizing seed")
		settings.biome_noise.seed = randi() #New map_seed for this generation
		settings.mountain_noise.seed = randi()
		settings.ocean_noise.seed = randi()
	else:
		settings.biome_noise.seed = settings.map_seed
		settings.mountain_noise.seed = settings.map_seed
		settings.ocean_noise.seed = settings.map_seed

## Start of world_generation, time each step
func generate_world():
	var starttime = Time.get_ticks_msec()
	var interval = {"Start of Generation!" : starttime}
	
	## Get all positions through the gridmapper
	var mapper = GridMapper.new()
	var positions = mapper.calculate_map_positions(settings)
	interval["Calculate Map Positions -- "] = Time.get_ticks_msec()
	
	## Create the tiles
	var factory = TileFactory.new()
	factory.init_factory(settings, tile_parent)
	var map = factory.create_map(positions)
	WorldMap.set_map(map)
	interval["Create Map -- "] = Time.get_ticks_msec()
	
	set_neighbors()
	interval["Set Neighbors -- "] = Time.get_ticks_msec()
	
	var empire_creator = EmpireCreator.new()
	empire_creator.init_creator(settings)
	empire_creator.create_empires()
	interval["Create Empires -- "] = Time.get_ticks_msec()

	
	print_generation_results(starttime, interval)


func set_neighbors():
	for t in WorldMap.map:
		t.neighbors = WorldMap.get_tile_neighbors(t)

## This mess of a function loops through the timing results of generate_world and prints them
func print_generation_results(start : float, dict : Dictionary):
	GameLogger.debug("\n")
	var last_val = start
	var total = 0
	for key in dict:
		var val = dict[key]
		if val == start:
			GameLogger.debug(key)
			continue
		var passed = val - last_val
		GameLogger.debug(key + str(passed) + "ms")
		last_val = val
		total += passed
	var s = "ms"
	if total > 999: 
		s = "s"
		total *= 0.001
	GameLogger.info("Total completion time: " + str(total) + s)



func _on_ui_control_generate_world(new_settings: GenerationSettings) -> void:
	settings = new_settings
	for child in tile_parent.get_children():
		child.queue_free()
	_ready()
