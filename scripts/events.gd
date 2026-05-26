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
## Las cartas llevan dueño implícito vía la stats con la que se juegan.
## Los listeners filtran por owner_stats para no actuar sobre cartas de
## otros imperios (jugador no reacciona a cartas IA y viceversa).
signal card_played(card:Card, owner_stats:Stats)
signal card_returned_to_hand(card:Card, owner_stats:Stats)

signal build_card_confirm_started(card:BuildCard,targets:Array[Node], stats:Stats)
signal upgrade_building_card_confirm_started(card:UpgradeBuildingCard,targets:Array[Node], stats:Stats)
signal recover_card_confirm_started(card:RecoverCard, stats:Stats)

signal player_hand_drawn
signal player_hand_discarded
signal player_turn_ended

signal turn_event_triggered(event:TurnEvent, context:EventContext)
signal turn_event_resolved()

signal shop_event_triggered(shop_config:ShopConfig, context:EventContext)
signal shop_event_resolved()

# Señales genericas de turno (para cualquier imperio)
signal empire_turn_started(controller:EmpireController)
signal empire_turn_ended(controller:EmpireController)

# Señales para que los BuildingEffect puedan añadir/quitar modificadores
signal request_add_modifier(modifier:Modifier, stats:Stats)
signal request_remove_modifier(modifier:Modifier)

# Señales para selección de tile desde eventos
signal request_tile_selection(eligible_tiles:Array[Tile])
signal tile_selection_made(tile:Tile)
signal tile_selection_cancelled()

# Señales para selección de carta desde eventos
signal request_card_selection(candidates:Array[Card])
signal card_selection_made(card:Card)
signal card_selection_cancelled()

# Señales de confirmación de cartas militares
signal recruit_card_confirm_started(card:RecruitCard, stats:Stats)
signal open_front_card_confirm_started(card:OpenFrontCard, target_tile:Tile, own_tiles:Array[Tile], stats:Stats)
signal open_front_source_selected(card:OpenFrontCard, source_tile:Tile)
signal open_front_source_cancelled(card:OpenFrontCard)

# Señales específicas de feedback de la IA. Existen aparte de
# empire_turn_started/ended porque las usa la capa de presentación
# (floating labels, log lateral) y queremos poder cambiar su contrato
# sin tocar el flujo de turno general.
#
# ai_card_played se emite cada vez que la IA ejecuta una AIPlayOption
# (excluyendo PASS). `anchor_tile` puede ser null si la opción no tiene
# una tile clara (p.ej. RecruitCard SELF). `payload` lleva sub-decisiones
# para enriquecer el texto del feedback (building elegido, tropa, etc.).
signal ai_card_played(card:Card, anchor_tile:Tile, empire:Empire, payload:Dictionary)
signal ai_turn_started(controller:EmpireController)
signal ai_turn_ended(controller:EmpireController)

# Señales de frentes de batalla
signal battle_front_opened(front:BattleFront)
signal battle_front_resolved(front:BattleFront, attacker_won:bool)
signal battle_front_marker_changed(front:BattleFront, new_value:float)
signal troop_assigned_to_front(front:BattleFront, troop:Troop, side:StringName)
signal battle_front_bonus_applied(front:BattleFront, side:StringName)
signal battle_front_selected(front:BattleFront)
