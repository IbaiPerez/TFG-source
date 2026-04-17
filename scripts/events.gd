extends Node

signal generate_world(settings:GenerationSettings, stats:Stats)

signal navigate_to_empire_selection
signal navigate_to_generation(empire:Empire)
signal navigate_to_main_menu


signal change_tile_controller(tile:Tile, empire:Empire)
signal tile_controller_changed(tile:Tile)
signal change_tile_location_type(tile:Tile, location_type:LocationType)
signal tile_location_type_changed(tile:Tile)


signal tile_selected(tile:Tile)
signal tile_deselected()

enum map_mode {PoliticalMode, BiomesMode, NaturalResourcesMode, LocationTypeMode}
signal change_map_mode(map_mode)


signal card_aim_started(card_ui:CardUI)
signal card_aim_ended(card_ui:CardUI)
signal card_played(card:Card)

signal build_card_confirm_started(card:BuildCard,targets:Array[Node], stats:Stats)
signal upgrade_building_card_confirm_started(card:UpgradeBuildingCard,targets:Array[Node], stats:Stats)

signal player_hand_drawn
signal player_hand_discarded
signal player_turn_ended

signal turn_event_triggered(event:TurnEvent, context:EventContext)
signal turn_event_resolved()
