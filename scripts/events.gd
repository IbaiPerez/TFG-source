extends Node

signal generate_world(settings:GenerationSettings)


signal change_tile_controller(tile:Tile, empire:Empire)
signal tile_controller_changed(tile:Tile)
signal tile_location_type_changed(tile:Tile)


signal tile_selected(tile:Tile)
signal tile_deselected()

enum map_mode {PoliticalMode, BiomesMode, NaturalResourcesMode, LocationTypeMode}
signal change_map_mode(map_mode)
