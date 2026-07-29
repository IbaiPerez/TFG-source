extends RefCounted
class_name EventContext

## Contexto de evaluación de eventos: un saco de datos AGREGADOS, precomputado una
## vez por evaluación. Las CONDICIONES leen solo de aquí (nunca de la escena), lo
## que permite construirlo también desde el snapshot del MCTS con `from_snapshot`
## y reusar las condiciones REALES en la simulación (refactor C6 §1.6.2), en vez de
## reimplementarlas en un espejo.
##
## `stats`, `modifier_manager` y `controlled_tiles` siguen aquí porque los usan los
## EFECTOS y la UI del mundo vivo; quedan vacíos en el contexto de snapshot.


## Datos por casilla controlada que necesitan las condiciones, sin exponer el nodo
## `Tile` (que es un Node3D de escena y no existe en el snapshot).
class TileFacts:
	var natural_resource: NaturalResource = null
	var biome: int = -1            ## Tile.biome_type (-1 si se desconoce)
	var location_type: int = 0     ## Tile.location_type
	var building_count: int = 0
	var building_names: Array[String] = []


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

## Agregados de casilla (C6 §1.6.2): sustituyen el recorrido de `controlled_tiles`
## que hacían las condiciones, para que valgan también sobre el snapshot.
var tile_facts:Array[TileFacts] = []
## Biomas de las casillas LIBRES adyacentes a territorio propio (biome → true).
var adjacent_uncontrolled_biomes:Dictionary = {}
var has_adjacent_uncontrolled:bool = false

## Datos militares
var troop_pool_size:int = 0
var active_front_count:int = 0
var has_adjacent_enemy:bool = false

## Contadores históricos del imperio (los leen dos condiciones; antes iban por `stats`).
var types_ever_recruited:Dictionary = {}
var used_unique_events:Array[String] = []


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

	# Agregados de casilla + adyacencia libre (C6 §1.6.2). Los contenedores ya nacen
	# vacíos y TIPADOS en la declaración; reasignarlos con un literal sin tipo sería
	# un error de asignación en tiempo de ejecución.
	for tile in ctx.controlled_tiles:
		var tf := TileFacts.new()
		tf.natural_resource = tile.natural_resource
		tf.biome = tile.mesh_data.type if tile.mesh_data else -1
		tf.location_type = tile.location.type if tile.location else 0
		tf.building_count = tile.buildings.size()
		for building in tile.buildings:
			if building != null:
				tf.building_names.append(building.name)
		ctx.tile_facts.append(tf)
		for neighbor in tile.neighbors:
			if neighbor is Tile and neighbor.controller == null:
				ctx.has_adjacent_uncontrolled = true
				if neighbor.mesh_data:
					ctx.adjacent_uncontrolled_biomes[neighbor.mesh_data.type] = true

	ctx.types_ever_recruited = p_stats.types_ever_recruited
	ctx.used_unique_events = p_stats.used_unique_events

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


## Construye el MISMO contexto agregado desde el snapshot del MCTS (C6 §1.6.2), para
## que las condiciones REALES se evalúen sobre la simulación sin tocar escena. Deja
## `stats`/`modifier_manager`/`controlled_tiles` vacíos: solo los usan los efectos y
## la UI del mundo vivo, no las condiciones.
static func from_snapshot(state:AIRealState, p_owner:int) -> EventContext:
	var ctx = EventContext.new()
	var emp := state.empire(p_owner)
	if emp == null:
		return ctx

	ctx.turn_number = state.turn_number
	ctx.total_gold = emp.gold
	ctx.gold_per_turn = emp.gold_per_turn
	ctx.food = emp.food
	# El snapshot solo modela los modifiers económicos: misma aproximación que el
	# espejo al que sustituye.
	ctx.active_modifier_count = emp.modifiers.size()

	ctx.cards_in_deck = emp.deck
	ctx.card_count_by_id = {}
	ctx.card_count_by_type = {}
	for card in emp.deck:
		if card == null:
			continue
		ctx.card_count_by_id[card.id] = ctx.card_count_by_id.get(card.id, 0) + 1
		ctx.card_count_by_type[card.type] = ctx.card_count_by_type.get(card.type, 0) + 1

	var enemy := AIRealState.OWNER_RIVAL if p_owner == AIRealState.OWNER_SELF \
		else AIRealState.OWNER_SELF
	for id in state.tiles:
		var t := state.tiles[id] as AIRealState.TileSnap
		if t.owner != p_owner:
			continue
		var tf := TileFacts.new()
		tf.natural_resource = t.natural_resource
		tf.biome = t.biome
		tf.location_type = t.location_type
		tf.building_count = t.buildings.size()
		for building in t.buildings:
			if building != null:
				tf.building_names.append(building.name)
		ctx.tile_facts.append(tf)
		for nid in t.neighbor_ids:
			var nb := state.tiles.get(nid) as AIRealState.TileSnap
			if nb == null:
				continue
			if nb.owner == AIRealState.OWNER_NONE:
				ctx.has_adjacent_uncontrolled = true
				ctx.adjacent_uncontrolled_biomes[nb.biome] = true
			elif nb.owner == enemy:
				ctx.has_adjacent_enemy = true

	ctx.types_ever_recruited = emp.types_ever_recruited
	ctx.used_unique_events = emp.used_unique_events
	ctx.troop_pool_size = emp.troop_pool.size()
	for f in state.fronts:
		var front := f as AIRealState.FrontSnap
		if not front.is_resolved and front.involves(p_owner):
			ctx.active_front_count += 1

	# Misma salvaguarda de progresión que el mundo vivo (ver arriba).
	if not ctx.has_adjacent_enemy and ctx.turn_number >= 20:
		ctx.has_adjacent_enemy = true

	return ctx
