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


static func build(p_stats:Stats, p_modifier_manager:ModifierManager, p_turn_number:int) -> EventContext:
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

	return ctx
