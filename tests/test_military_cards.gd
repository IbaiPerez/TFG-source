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


# --- Tests RecruitCard con base_troops_per_play y bonus ---

func test_recruit_card_default_base_is_one() -> void:
	var card := RecruitCard.new()
	assert_eq(card.base_troops_per_play, 1,
		"Default base_troops_per_play debe ser 1 (mantiene comportamiento previo)")


func test_recruit_card_recruits_base_times_when_no_modifier_manager() -> void:
	# stats.modifier_manager null → bonus = 0; con base=2 recluta 2.
	stats.modifier_manager = null
	var card := RecruitCard.new()
	card.base_troops_per_play = 2
	var troop := _create_troop(3, 3, 20)
	card.chosen = troop

	card.apply_effects([], stats)
	assert_eq(stats.troop_pool.size(), 2,
		"Con base=2 y sin manager, debe reclutar 2 tropas")
	assert_eq(stats.total_gold, 60, "100 - 2*20 = 60")


func test_recruit_card_applies_modifier_bonus_to_count() -> void:
	# Simulamos un Cuartel: modifier de TROOPS_PER_RECRUIT +1.
	var mm := ModifierManager.new()
	add_child_autofree(mm)
	mm.add_modifier(StatModifier.new("cuartel", "Cuartel",
		StatModifier.StatType.TROOPS_PER_RECRUIT, 1.0, -1), stats)
	stats.modifier_manager = mm

	var card := RecruitCard.new()
	card.base_troops_per_play = 1
	var troop := _create_troop(3, 3, 20)
	card.chosen = troop

	card.apply_effects([], stats)
	assert_eq(stats.troop_pool.size(), 2,
		"Con Cuartel (+1) y base=1, debe reclutar 2 tropas")
	assert_eq(stats.total_gold, 60, "100 - 2*20 = 60")


func test_recruit_card_stops_when_gold_runs_out() -> void:
	# Con 50 oro y troops de 20 cada una, intentamos reclutar 3 → solo
	# entran 2 (40 oro) y la tercera (60 oro) falla. El bucle corta.
	stats.total_gold = 50
	var mm := ModifierManager.new()
	add_child_autofree(mm)
	mm.add_modifier(StatModifier.new("ac", "Academia",
		StatModifier.StatType.TROOPS_PER_RECRUIT, 2.0, -1), stats)
	stats.modifier_manager = mm

	var card := RecruitCard.new()
	card.base_troops_per_play = 1  # +2 bonus → total 3
	var troop := _create_troop(3, 3, 20)
	card.chosen = troop

	card.apply_effects([], stats)
	assert_eq(stats.troop_pool.size(), 2,
		"Solo deberia haber reclutado las 2 que se pueden pagar")
	assert_eq(stats.total_gold, 10, "50 - 2*20 = 10")


func test_recruit_card_effective_total_clamps_to_min_one() -> void:
	# Aunque el base sea 0 y no haya bonus (negativos imposibles hoy pero
	# defensivo), get_effective_troops_per_play nunca devuelve menos de 1.
	var card := RecruitCard.new()
	card.base_troops_per_play = 0
	assert_eq(card.get_effective_troops_per_play(stats), 1,
		"Defensivo: minimo 1 tropa por play, base=0 lo clampa")


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
