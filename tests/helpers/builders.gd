extends RefCounted
class_name TestBuilders

## Builders fluidos para los tests. Sustituyen a los ~73 helpers privados
## `_make_stats` / `_make_tile` / `_make_empire` / … reimplementados en 19+
## ficheros de test. Los valores por defecto reproducen los de esos helpers para
## que migrar un test a estos builders NO cambie el objeto construido.
##
## Vive en tests/helpers/ (fuera del prefijo `test_`), así que GUT no lo ejecuta
## como suite. Se usa por su `class_name` global desde cualquier test:
##
##   var stats := TestBuilders.stats().with_gold(500).with_turn(10).build()
##   var tile  := TestBuilders.tile().with_biome(Tile.biome_type.Forest) \
##                   .with_controller(stats.empire).build()
##   var ctx   := TestBuilders.context(stats).with_colonizable(4).build()


# ---------------------------------------------------------------------------
# Empire
# ---------------------------------------------------------------------------

class EmpireB extends RefCounted:
	var _name := "TestAI"
	var _color := Color.RED
	var _ability: EmpireAbility = null

	func with_name(v: String) -> EmpireB: _name = v; return self
	func with_color(v: Color) -> EmpireB: _color = v; return self
	func with_ability(v: EmpireAbility) -> EmpireB: _ability = v; return self

	func build() -> Empire:
		var e := Empire.new()
		e.name = _name
		e.color = _color
		e.ability = _ability
		e.controlled_tiles = []
		return e


static func empire() -> EmpireB:
	return EmpireB.new()


# ---------------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------------

class StatsB extends RefCounted:
	var _gold := 100
	var _gpt := 50
	var _food := 10
	var _cards_per_turn := 3
	var _turn := 0
	var _empire: Empire = null
	var _tiles: Array = []
	var _troops: Array = []
	var _possible: Array = []
	## Mismo default que `Stats.event_chance`, para que construir sin indicarlo dé
	## exactamente lo que daba antes de existir este campo en el builder.
	var _event_chance := 0.5

	func with_gold(v: int) -> StatsB: _gold = v; return self
	func with_gpt(v: int) -> StatsB: _gpt = v; return self
	func with_food(v: int) -> StatsB: _food = v; return self
	func with_cards_per_turn(v: int) -> StatsB: _cards_per_turn = v; return self
	func with_turn(v: int) -> StatsB: _turn = v; return self
	func with_empire(e: Empire) -> StatsB: _empire = e; return self
	## Tiles ya controladas por el imperio (se les fija el controller al construir).
	func with_tiles(tiles: Array) -> StatsB: _tiles = tiles; return self
	func with_troop_pool(troops: Array) -> StatsB: _troops = troops; return self
	func with_possible_buildings(buildings: Array) -> StatsB: _possible = buildings; return self
	## Probabilidad de evento por turno. Los tests que no van de eventos la ponen a
	## 0.0 para que no se disparen y ensucien el escenario.
	func with_event_chance(v: float) -> StatsB: _event_chance = v; return self

	func build() -> Stats:
		var s := Stats.new()
		s.total_gold = _gold
		s.gold_per_turn = _gpt
		s.food = _food
		s.cards_per_turn = _cards_per_turn
		s.turn_number = _turn
		s.event_chance = _event_chance
		s.deck = CardPile.new()
		s.draw_pile = CardPile.new()
		s.discard_pile = CardPile.new()
		s.played_pile = CardPile.new()
		var e := _empire
		if e == null:
			e = TestBuilders.empire().build()
		var owned: Array[Tile] = []
		for t in _tiles:
			var tile := t as Tile
			tile.controller = e
			owned.append(tile)
		e.controlled_tiles = owned
		s.empire = e
		var pool: Array[Troop] = []
		for t in _troops:
			pool.append(t as Troop)
		s.troop_pool = pool
		var pb: Array[Building] = []
		for b in _possible:
			pb.append(b as Building)
		s.possible_buildings = pb
		return s


static func stats() -> StatsB:
	return StatsB.new()


# ---------------------------------------------------------------------------
# Tile
# ---------------------------------------------------------------------------

class TileB extends RefCounted:
	var _biome := Tile.biome_type.Grassland
	var _res_gold := 1
	var _res_food := 1
	var _loc := Tile.location_type.Village
	var _max_building := 2
	var _food_consumption := 0
	var _controller: Empire = null
	var _neighbors: Array = []
	var _buildings: Array = []

	func with_biome(v: Tile.biome_type) -> TileB: _biome = v; return self
	func with_resource(gold: int, food: int) -> TileB: _res_gold = gold; _res_food = food; return self
	func with_location(type: Tile.location_type, max_building := 2, food_consumption := 0) -> TileB:
		_loc = type; _max_building = max_building; _food_consumption = food_consumption; return self
	func with_controller(e: Empire) -> TileB: _controller = e; return self
	func with_neighbors(tiles: Array) -> TileB: _neighbors = tiles; return self
	func with_buildings(buildings: Array) -> TileB: _buildings = buildings; return self

	func build() -> Tile:
		var tile := Tile.new()
		tile.mesh_data = TileMeshData.new()
		tile.mesh_data.type = _biome
		tile.mesh_data.color = Color.GREEN
		tile.natural_resource = NaturalResource.new()
		tile.natural_resource.gold_produced = _res_gold
		tile.natural_resource.food_produced = _res_food
		var loc := LocationType.new()
		loc.type = _loc
		loc.max_building = _max_building
		loc.food_consumption = _food_consumption
		tile.location = loc
		tile.controller = _controller
		tile.neighbors = _neighbors
		var blds: Array[Building] = []
		for b in _buildings:
			blds.append(b as Building)
		tile.buildings = blds
		# Las producciones NO se fijan a mano: las deriva el dominio. Antes este
		# builder hacía `food_production = _res_food`, ignorando el consumo de la
		# localización, cuando la regla real (Tile.recalculate_modifiers) es
		# `recurso − consumo` más lo que aporten los edificios. Solo divergía con
		# food_consumption ≠ 0, así que no se veía con los valores por defecto.
		tile.recalculate_modifiers()
		return tile


static func tile() -> TileB:
	return TileB.new()


# ---------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------

class BuildingB extends RefCounted:
	var _name := "TestBuilding"
	var _gold := 0
	var _food := 0
	var _defense := 0
	var _cost := 50
	var _effects: Array = []
	var _upgrades_to: Array = []
	var _allowed_biomes: Array = []
	var _allowed_location_type: Array = []

	func with_name(v: String) -> BuildingB: _name = v; return self
	func with_gold(v: int) -> BuildingB: _gold = v; return self
	func with_food(v: int) -> BuildingB: _food = v; return self
	func with_defense(v: int) -> BuildingB: _defense = v; return self
	func with_cost(v: int) -> BuildingB: _cost = v; return self
	func with_effects(effects: Array) -> BuildingB: _effects = effects; return self
	func with_upgrades_to(buildings: Array) -> BuildingB: _upgrades_to = buildings; return self
	func with_allowed_biomes(biomes: Array) -> BuildingB: _allowed_biomes = biomes; return self
	func with_allowed_locations(locations: Array) -> BuildingB: _allowed_location_type = locations; return self

	func build() -> Building:
		var b := Building.new()
		b.name = _name
		b.gold_produced = _gold
		b.food_produced = _food
		b.flat_defense_bonus = _defense
		b.construction_cost = _cost
		var eff: Array[BuildingEffect] = []
		for e in _effects:
			eff.append(e as BuildingEffect)
		b.effects = eff
		var up: Array[Building] = []
		for u in _upgrades_to:
			up.append(u as Building)
		b.upgrades_to = up
		# allowed_biomes es Array[Tile.biome_type]: asignarle un Array sin tipar
		# es error EN EJECUCIÓN (no lo detecta el parser), y deja el builder
		# devolviendo null. Hay que copiar elemento a elemento, igual que abajo
		# con allowed_location_type.
		var biomes: Array[Tile.biome_type] = []
		for bm in _allowed_biomes:
			biomes.append(bm)
		b.allowed_biomes = biomes
		var locs: Array[LocationType] = []
		for l in _allowed_location_type:
			locs.append(l as LocationType)
		b.allowed_location_type = locs
		return b


static func building() -> BuildingB:
	return BuildingB.new()


# ---------------------------------------------------------------------------
# Troop
# ---------------------------------------------------------------------------

class TroopB extends RefCounted:
	var _name := "TestTroop"
	var _type := Troop.TroopType.INFANTERIA_LIGERA
	var _atk := 3
	var _def := 3
	var _recruit_cost := 10
	var _maint_gold := 0
	var _maint_food := 0

	func with_name(v: String) -> TroopB: _name = v; return self
	func with_type(v: int) -> TroopB: _type = v; return self
	func with_attack(v: int) -> TroopB: _atk = v; return self
	func with_defense(v: int) -> TroopB: _def = v; return self
	func with_recruit_cost(v: int) -> TroopB: _recruit_cost = v; return self
	func with_maintenance(gold: int, food: int) -> TroopB: _maint_gold = gold; _maint_food = food; return self

	func build() -> Troop:
		var t := Troop.new()
		t.name = _name
		t.type = _type
		t.attack = _atk
		t.defense = _def
		t.recruitment_cost_gold = _recruit_cost
		t.maintenance_gold = _maint_gold
		t.maintenance_food = _maint_food
		return t


static func troop() -> TroopB:
	return TroopB.new()


# ---------------------------------------------------------------------------
# AITurnContext
# ---------------------------------------------------------------------------

class ContextB extends RefCounted:
	var _stats: Stats = null
	var _rng: RandomNumberGenerator = null
	var _drawn: Array = []
	var _bfm: BattleFrontManager = null
	var _world_view: AIWorldView = null
	var _config: AIConfig = null
	var _weights: HeuristicWeights = null
	var _colonizable := -1
	var _total_map_tiles := 0

	func with_rng(v: RandomNumberGenerator) -> ContextB: _rng = v; return self
	func with_drawn_cards(cards: Array) -> ContextB: _drawn = cards; return self
	func with_battle_front_manager(v: BattleFrontManager) -> ContextB: _bfm = v; return self
	func with_world_view(v: AIWorldView) -> ContextB: _world_view = v; return self
	func with_config(v: AIConfig) -> ContextB: _config = v; return self
	func with_weights(v: HeuristicWeights) -> ContextB: _weights = v; return self
	func with_colonizable(v: int) -> ContextB: _colonizable = v; return self
	func with_total_map_tiles(v: int) -> ContextB: _total_map_tiles = v; return self

	func build() -> AITurnContext:
		var ctx := AITurnContext.new()
		ctx.stats = _stats
		ctx.rng = _rng if _rng != null else RandomNumberGenerator.new()
		var cards: Array[Card] = []
		for c in _drawn:
			cards.append(c as Card)
		ctx.drawn_cards = cards
		ctx.battle_front_manager = _bfm
		ctx.world_view = _world_view
		ctx.config = _config
		ctx.weights = _weights
		ctx.colonizable_tiles_count = _colonizable
		ctx.total_map_tiles = _total_map_tiles
		return ctx


## Contexto de decisión de la IA para `stats`. rng se autocrea si no se indica.
static func context(stats: Stats) -> ContextB:
	var b := ContextB.new()
	b._stats = stats
	return b


# ---------------------------------------------------------------------------
# LocationType (recurso suelto, útil para ChangeLocation)
# ---------------------------------------------------------------------------

static func location(type: Tile.location_type, food_consumption := 0,
		max_building := 2) -> LocationType:
	var loc := LocationType.new()
	loc.type = type
	loc.food_consumption = food_consumption
	loc.max_building = max_building
	return loc
