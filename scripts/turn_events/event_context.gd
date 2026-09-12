extends RefCounted
class_name EventContext

## Contexto de evaluación de eventos: un saco de datos AGREGADOS, precomputado una
## vez por evaluación. Las CONDICIONES leen solo de aquí (nunca de la escena), lo
## que permite construirlo también desde el snapshot del MCTS con `from_snapshot`
## y reusar las condiciones REALES en la simulación, en vez de
## reimplementarlas en un espejo.
##
## `stats`, `modifier_manager` y `controlled_tiles` siguen aquí porque los usan los
## EFECTOS y la UI del mundo vivo; quedan vacíos en el contexto de snapshot.


## Datos por casilla controlada que necesitan las condiciones, sin exponer el nodo
## `Tile` (que es un Node3D de escena y no existe en el snapshot).
class TileFacts:
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

var controlled_tiles:Array[Tile]

## Agregados de casilla: sustituyen el recorrido de `controlled_tiles`
## que hacían las condiciones, para que valgan también sobre el snapshot.
var tile_facts:Array[TileFacts] = []


## Biomas de las casillas LIBRES adyacentes a territorio propio (biome → true).
var adjacent_uncontrolled_biomes:Dictionary = {}
var has_adjacent_uncontrolled:bool = false

## Datos militares
var troop_pool_size:int = 0
var has_adjacent_enemy:bool = false

## Contadores históricos del imperio (los leen dos condiciones; antes iban por `stats`).
var types_ever_recruited:Dictionary = {}
var used_unique_events:Array[String] = []


static func build(p_stats:Stats, p_modifier_manager:ModifierManager,
		p_turn_number:int) -> EventContext:
	var ctx = EventContext.new()
	ctx.stats = p_stats
	ctx.modifier_manager = p_modifier_manager
	ctx.turn_number = p_turn_number

	_collect_economy(ctx, p_stats)
	_collect_tiles(ctx, p_stats.empire)
	_collect_military(ctx, p_stats, p_turn_number)
	return ctx


static func _collect_economy(ctx:EventContext, p_stats:Stats) -> void:
	ctx.total_gold = p_stats.total_gold
	ctx.gold_per_turn = p_stats.gold_per_turn
	ctx.food = p_stats.food
	ctx.controlled_tiles = p_stats.empire.controlled_tiles
	ctx.types_ever_recruited = p_stats.types_ever_recruited
	ctx.used_unique_events = p_stats.used_unique_events


## Agregados de territorio, en UNA sola pasada sobre las casillas propias.
##
## Los contenedores ya nacen vacíos y TIPADOS en la declaración: reasignarlos con un
## literal sin tipo sería un error en tiempo de ejecución.
static func _collect_tiles(ctx:EventContext, empire:Empire) -> void:
	for tile in ctx.controlled_tiles:
		var tf := TileFacts.new()
		tf.biome = tile.mesh_data.type if tile.mesh_data else -1
		tf.location_type = tile.location.type if tile.location else 0
		tf.building_count = tile.buildings.size()
		for building in tile.buildings:
			if building != null:
				tf.building_names.append(building.name)
		ctx.tile_facts.append(tf)

		# Adyacencia: casillas libres (por bioma) y presencia de otro imperio.
		# Funciona igual para casillas terrestres y oceánicas: `neighbors` está
		# poblado para TODAS las del mapa (world_generator.set_neighbors) y
		# `controller` se asigna al colonizar, sea cual sea el bioma.
		for neighbor in tile.neighbors:
			if not (neighbor is Tile):
				continue
			if neighbor.controller == null:
				ctx.has_adjacent_uncontrolled = true
				if neighbor.mesh_data:
					ctx.adjacent_uncontrolled_biomes[neighbor.mesh_data.type] = true
			elif neighbor.controller != empire:
				ctx.has_adjacent_enemy = true


static func _collect_military(ctx:EventContext, p_stats:Stats, p_turn_number:int) -> void:
	ctx.troop_pool_size = p_stats.troop_pool.size()

	# Salvaguarda de progresión: si a partir del turno 20 ningún rival es
	# adyacente, probablemente los imperios están en masas de tierra separadas
	# por un mar interior generado proceduralmente. En ese caso forzamos
	# has_adjacent_enemy = true para que UnlockRecruitEvent (CORE_PROGRESSION,
	# único) no quede bloqueado indefinidamente.
	# HasAdjacentEnemyCondition solo la usa ese evento, así que este override
	# no afecta a ninguna otra condición del sistema.
	if not ctx.has_adjacent_enemy and p_turn_number >= 20:
		ctx.has_adjacent_enemy = true


## Construye el MISMO contexto agregado desde el snapshot del MCTS, para
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

	var enemy := AIRealState.OWNER_RIVAL if p_owner == AIRealState.OWNER_SELF \
		else AIRealState.OWNER_SELF
	for id in state.tiles:
		var t := state.tiles[id] as AIRealState.TileSnap
		if t.owner != p_owner:
			continue
		var tf := TileFacts.new()
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

	# Misma salvaguarda de progresión que el mundo vivo (ver arriba).
	if not ctx.has_adjacent_enemy and ctx.turn_number >= 20:
		ctx.has_adjacent_enemy = true

	return ctx
