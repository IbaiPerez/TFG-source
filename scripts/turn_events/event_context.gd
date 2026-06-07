extends RefCounted
class_name EventContext

var stats:Stats
var modifier_manager:ModifierManager

var total_gold:int
var gold_per_turn:int
var food:int
var turn_number:int
var active_modifier_count:int

var cards_in_deck:Array[Card]
var card_count_by_id:Dictionary
var card_count_by_type:Dictionary

var controlled_tiles:Array[Tile]
var tiles_by_resource:Dictionary
var tiles_by_biome:Dictionary
var tiles_by_location:Dictionary

## Datos militares
var troop_pool_size:int = 0
var active_front_count:int = 0
var has_adjacent_enemy:bool = false


static func build(p_stats:Stats, p_modifier_manager:ModifierManager, p_turn_number:int,
		p_battle_front_manager:BattleFrontManager = null) -> EventContext:
	var ctx = EventContext.new()
	ctx.stats = p_stats
	ctx.modifier_manager = p_modifier_manager
	ctx.turn_number = p_turn_number

	ctx.total_gold = p_stats.total_gold
	ctx.gold_per_turn = p_stats.gold_per_turn
	ctx.food = p_stats.food
	ctx.controlled_tiles = p_stats.empire.controlled_tiles
	ctx.active_modifier_count = p_modifier_manager.active_modifiers.size()

	# Recopilar todas las cartas del mazo (draw + discard)
	var all_cards:Array[Card] = []
	all_cards.append_array(p_stats.draw_pile.cards)
	all_cards.append_array(p_stats.discard_pile.cards)
	ctx.cards_in_deck = all_cards

	# Contar cartas por id
	ctx.card_count_by_id = {}
	for card in all_cards:
		ctx.card_count_by_id[card.id] = ctx.card_count_by_id.get(card.id, 0) + 1

	# Contar cartas por tipo
	ctx.card_count_by_type = {}
	for card in all_cards:
		ctx.card_count_by_type[card.type] = ctx.card_count_by_type.get(card.type, 0) + 1

	# Indexar tiles por recurso natural
	ctx.tiles_by_resource = {}
	for tile in ctx.controlled_tiles:
		if tile.natural_resource:
			if not ctx.tiles_by_resource.has(tile.natural_resource):
				ctx.tiles_by_resource[tile.natural_resource] = []
			ctx.tiles_by_resource[tile.natural_resource].append(tile)

	# Indexar tiles por bioma
	ctx.tiles_by_biome = {}
	for tile in ctx.controlled_tiles:
		if tile.mesh_data:
			if not ctx.tiles_by_biome.has(tile.mesh_data.type):
				ctx.tiles_by_biome[tile.mesh_data.type] = []
			ctx.tiles_by_biome[tile.mesh_data.type].append(tile)

	# Indexar tiles por tipo de localizacion
	ctx.tiles_by_location = {}
	for tile in ctx.controlled_tiles:
		if tile.location:
			if not ctx.tiles_by_location.has(tile.location.type):
				ctx.tiles_by_location[tile.location.type] = []
			ctx.tiles_by_location[tile.location.type].append(tile)

	# Datos militares
	ctx.troop_pool_size = p_stats.troop_pool.size()
	if p_battle_front_manager:
		ctx.active_front_count = p_battle_front_manager.active_fronts.size()

	# Comprobar si hay alguna tile controlada adyacente a otro imperio.
	# Funciona correctamente tanto para tiles terrestres como oceánicas:
	# tile.neighbors está poblado para todas las tiles del mapa (incluida Ocean)
	# por world_generator.set_neighbors(), y tile.controller se asigna al
	# colonizar independientemente del bioma.
	ctx.has_adjacent_enemy = false
	for tile in ctx.controlled_tiles:
		for neighbor in tile.neighbors:
			if neighbor is Tile and neighbor.controller != null and neighbor.controller != p_stats.empire:
				ctx.has_adjacent_enemy = true
				break
		if ctx.has_adjacent_enemy:
			break

	# Salvaguarda de progresión: si a partir del turno 20 ningún rival es
	# adyacente, probablemente los imperios están en masas de tierra separadas
	# por un mar interior generado proceduralmente. En ese caso forzamos
	# has_adjacent_enemy = true para que UnlockRecruitEvent (CORE_PROGRESSION,
	# único) no quede bloqueado indefinidamente.
	# HasAdjacentEnemyCondition solo la usa ese evento, así que este override
	# no afecta a ninguna otra condición del sistema.
	if not ctx.has_adjacent_enemy and p_turn_number >= 20:
		ctx.has_adjacent_enemy = true

	return ctx
