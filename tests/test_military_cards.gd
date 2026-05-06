extends GutTest

## Tests para RecruitCard y OpenFrontCard.

var stats: Stats
var empire: Empire
var enemy_empire: Empire


func _create_troop(atk: int = 3, def: int = 3, gold: int = 20) -> Troop:
	var troop := Troop.new()
	troop.name = "Test"
	troop.attack = atk
	troop.defense = def
	troop.recruitment_cost_gold = gold
	troop.maintenance_gold = 2
	troop.maintenance_food = 1
	return troop


func _create_tile(biome: Tile.biome_type, ctrl: Empire) -> Tile:
	var tile := Tile.new()
	tile.mesh_data = TileMeshData.new()
	tile.mesh_data.type = biome
	tile.natural_resource = NaturalResource.new()
	tile.buildings = []
	tile.controller = ctrl
	return tile


func before_each() -> void:
	empire = Empire.new()
	empire.name = "Player"
	enemy_empire = Empire.new()
	enemy_empire.name = "Enemy"

	stats = Stats.new()
	stats.total_gold = 100
	stats.food = 50
	stats.troop_pool = []
	stats.empire = empire


# --- Tests RecruitCard ---

func test_recruit_card_apply_effects_success() -> void:
	var card := RecruitCard.new()
	card.id = "Recruit"
	card.type = Card.Type.BASIC
	card.target = Card.Target.SELF
	card.needs_confirmation = true

	var troop := _create_troop(3, 3, 20)
	card.chosen = troop

	card.apply_effects([], stats)
	assert_eq(stats.troop_pool.size(), 1, "Tropa debe añadirse al pool")
	assert_eq(stats.total_gold, 80, "Debe restar coste de oro")


func test_recruit_card_apply_effects_no_chosen() -> void:
	var card := RecruitCard.new()
	card.chosen = null

	card.apply_effects([], stats)
	assert_eq(stats.troop_pool.size(), 0, "Sin chosen no debe reclutar")
	assert_eq(stats.total_gold, 100, "No debe restar nada")


func test_recruit_card_apply_effects_insufficient_gold() -> void:
	stats.total_gold = 5
	var card := RecruitCard.new()
	var troop := _create_troop(3, 3, 20)
	card.chosen = troop

	card.apply_effects([], stats)
	assert_eq(stats.troop_pool.size(), 0, "No debe reclutar sin oro")


func test_recruit_card_is_basic_type() -> void:
	var card := RecruitCard.new()
	card.type = Card.Type.BASIC
	assert_false(card.is_single_use(), "Carta BASIC no es single use")


# --- Tests OpenFrontCard ---

func test_open_front_card_valid_targets() -> void:
	var own_tile := _create_tile(Tile.biome_type.Grassland, empire)
	var enemy_tile := _create_tile(Tile.biome_type.Grassland, enemy_empire)
	own_tile.neighbors = [enemy_tile]
	enemy_tile.neighbors = [own_tile]
	empire.controlled_tiles = [own_tile]

	var bfm := BattleFrontManager.new()
	autofree(bfm)
	var card := OpenFrontCard.new()
	card.target = Card.Target.TILE
	card.battle_front_manager = bfm
	card.battle_front_manager.stats = stats

	var targets := card.get_valid_targets(stats)
	assert_eq(targets.size(), 1, "Debe encontrar 1 target válido")
	assert_eq(targets[0], enemy_tile)

	own_tile.free()
	enemy_tile.free()


func test_open_front_card_no_targets_without_enemy_neighbors() -> void:
	var own_tile := _create_tile(Tile.biome_type.Grassland, empire)
	var own_tile2 := _create_tile(Tile.biome_type.Forest, empire)
	own_tile.neighbors = [own_tile2]
	own_tile2.neighbors = [own_tile]
	empire.controlled_tiles = [own_tile, own_tile2]

	var bfm2 := BattleFrontManager.new()
	autofree(bfm2)
	var card := OpenFrontCard.new()
	card.target = Card.Target.TILE
	card.battle_front_manager = bfm2
	card.battle_front_manager.stats = stats

	var targets := card.get_valid_targets(stats)
	assert_eq(targets.size(), 0, "Sin vecinos enemigos no hay targets")

	own_tile.free()
	own_tile2.free()


func test_open_front_card_excludes_tiles_with_active_front() -> void:
	var own_tile := _create_tile(Tile.biome_type.Grassland, empire)
	var enemy_tile := _create_tile(Tile.biome_type.Grassland, enemy_empire)
	own_tile.neighbors = [enemy_tile]
	enemy_tile.neighbors = [own_tile]
	empire.controlled_tiles = [own_tile]

	var manager := BattleFrontManager.new()
	manager.stats = stats
	add_child(manager)
	manager.open_front(own_tile, enemy_tile)

	var card := OpenFrontCard.new()
	card.target = Card.Target.TILE
	card.battle_front_manager = manager

	var targets := card.get_valid_targets(stats)
	assert_eq(targets.size(), 0, "Tile con frente activo no debe ser target")

	own_tile.free()
	enemy_tile.free()
	manager.queue_free()


func test_open_front_card_apply_effects() -> void:
	var own_tile := _create_tile(Tile.biome_type.Grassland, empire)
	var enemy_tile := _create_tile(Tile.biome_type.Grassland, enemy_empire)
	own_tile.neighbors = [enemy_tile]
	enemy_tile.neighbors = [own_tile]
	empire.controlled_tiles = [own_tile]

	var manager := BattleFrontManager.new()
	manager.stats = stats
	add_child(manager)

	var card := OpenFrontCard.new()
	card.target = Card.Target.TILE
	card.battle_front_manager = manager
	card.target_enemy_tile = enemy_tile
	card.source_own_tile = own_tile

	card.apply_effects([enemy_tile], stats)
	assert_eq(manager.active_fronts.size(), 1, "Debe abrir un frente")

	own_tile.free()
	enemy_tile.free()
	manager.queue_free()


# --- Tests EnemyAdjacentCondition ---

func test_enemy_adjacent_condition_valid() -> void:
	var own_tile := _create_tile(Tile.biome_type.Grassland, empire)
	var enemy_tile := _create_tile(Tile.biome_type.Grassland, enemy_empire)
	own_tile.neighbors = [enemy_tile]
	enemy_tile.neighbors = [own_tile]
	empire.controlled_tiles = [own_tile]

	var condition := EnemyAdjacentCondition.new()
	condition.empire = empire

	assert_true(condition.is_valid_target(enemy_tile))
	assert_false(condition.is_valid_target(own_tile))

	own_tile.free()
	enemy_tile.free()


func test_enemy_adjacent_condition_ignores_uncontrolled() -> void:
	var own_tile := _create_tile(Tile.biome_type.Grassland, empire)
	var empty_tile := _create_tile(Tile.biome_type.Grassland, null)
	own_tile.neighbors = [empty_tile]
	empty_tile.neighbors = [own_tile]
	empire.controlled_tiles = [own_tile]

	var condition := EnemyAdjacentCondition.new()
	condition.empire = empire

	assert_false(condition.is_valid_target(empty_tile), "Tiles sin controlador no son targets")

	own_tile.free()
	empty_tile.free()
