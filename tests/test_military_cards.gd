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
	BattleFront.clear_active_instances()
	empire = Empire.new()
	empire.name = "Player"
	enemy_empire = Empire.new()
	enemy_empire.name = "Enemy"

	stats = Stats.new()
	stats.total_gold = 100
	stats.food = 50
	stats.troop_pool = []
	stats.empire = empire


func after_each() -> void:
	BattleFront.clear_active_instances()


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


# --- Tests RecruitCard con troop_type_filter (Horda Nomada) ---

func _create_cavalry() -> Troop:
	var t := _create_troop(6, 1, 40)
	t.type = Troop.TroopType.CABALLERIA
	t.maintenance_gold = 3
	t.maintenance_food = 2
	return t


func _create_infantry() -> Troop:
	var t := _create_troop(2, 2, 20)
	t.type = Troop.TroopType.INFANTERIA_LIGERA
	return t


func _setup_manager_with_cavalry_filter() -> ModifierManager:
	var mm := ModifierManager.new()
	add_child_autofree(mm)
	mm.add_modifier(StatModifier.new("horde", "Horda",
		StatModifier.StatType.TROOPS_PER_RECRUIT, 1.0, -1,
		null, null, Troop.TroopType.CABALLERIA), stats)
	stats.modifier_manager = mm
	return mm


func test_recruit_card_cavalry_filter_bonus_applies_to_cavalry() -> void:
	_setup_manager_with_cavalry_filter()
	var card := RecruitCard.new()
	card.base_troops_per_play = 1
	var cav := _create_cavalry()
	# Modifier filtrado a CABALLERIA + jinete → total 2
	assert_eq(card.get_effective_troops_per_play(stats, cav), 2,
		"Modifier de caballería debe sumar +1 al reclutar un jinete")


func test_recruit_card_cavalry_filter_bonus_does_not_apply_to_infantry() -> void:
	_setup_manager_with_cavalry_filter()
	var card := RecruitCard.new()
	card.base_troops_per_play = 1
	var inf := _create_infantry()
	assert_eq(card.get_effective_troops_per_play(stats, inf), 1,
		"Modifier filtrado a caballería NO debe sumar bonus a infantería")


func test_recruit_card_apply_effects_recruits_bonus_cavalry() -> void:
	# Con modifier de caballería +1, reclutar un jinete recluta 2 en total.
	_setup_manager_with_cavalry_filter()
	stats.total_gold = 100

	var card := RecruitCard.new()
	card.base_troops_per_play = 1
	var cav := _create_cavalry()
	card.chosen = cav

	card.apply_effects([], stats)
	assert_eq(stats.troop_pool.size(), 2,
		"Con modifier +1 caballería, deben reclutarse 2 jinetes")
	assert_eq(stats.total_gold, 20,
		"100 - 2*40 = 20 oro restante")


func test_recruit_card_apply_effects_infantry_not_affected_by_cavalry_filter() -> void:
	# Modifier de caballería no afecta al reclutar infantería.
	_setup_manager_with_cavalry_filter()
	stats.total_gold = 100

	var card := RecruitCard.new()
	card.base_troops_per_play = 1
	var inf := _create_infantry()
	card.chosen = inf

	card.apply_effects([], stats)
	assert_eq(stats.troop_pool.size(), 1,
		"Modifier de caballería no debe afectar al reclutar infantería")
	assert_eq(stats.total_gold, 80,
		"100 - 1*20 = 80 oro restante")


func test_recruit_card_combined_filter_and_general_bonus_for_cavalry() -> void:
	# Cuartel (sin filtro, +1) + Horda (filtro cav, +1): jinete recluta 3 total.
	var mm := ModifierManager.new()
	add_child_autofree(mm)
	mm.add_modifier(StatModifier.new("cuartel", "Cuartel",
		StatModifier.StatType.TROOPS_PER_RECRUIT, 1.0, -1), stats)
	mm.add_modifier(StatModifier.new("horde", "Horda",
		StatModifier.StatType.TROOPS_PER_RECRUIT, 1.0, -1,
		null, null, Troop.TroopType.CABALLERIA), stats)
	stats.modifier_manager = mm

	var card := RecruitCard.new()
	card.base_troops_per_play = 1
	var cav := _create_cavalry()
	assert_eq(card.get_effective_troops_per_play(stats, cav), 3,
		"Base(1) + Cuartel(1) + Horda(1) = 3 jinetes por play")


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


func test_enemy_adjacent_condition_excludes_own_tile_in_active_front() -> void:
	# Si la tile propia ya está en un frente activo, NO puede ser origen de
	# otro ataque. valid_targets() debe devolver 0 candidatos.
	var own_tile := _create_tile(Tile.biome_type.Grassland, empire)
	var enemy_tile := _create_tile(Tile.biome_type.Grassland, enemy_empire)
	var enemy_tile2 := _create_tile(Tile.biome_type.Grassland, enemy_empire)
	own_tile.neighbors = [enemy_tile, enemy_tile2]
	enemy_tile.neighbors = [own_tile]
	enemy_tile2.neighbors = [own_tile]
	empire.controlled_tiles = [own_tile]

	var manager := BattleFrontManager.new()
	manager.stats = stats
	add_child(manager)
	manager.open_front(own_tile, enemy_tile)  # own_tile ya comprometida

	var condition := EnemyAdjacentCondition.new()
	condition.empire = empire

	# Con own_tile ya en frente, ningún vecino enemigo es atacable desde ella
	var targets := condition.valid_targets()
	assert_eq(targets.size(), 0,
		"Una tile propia ya en un frente no puede originar otro ataque")

	own_tile.free()
	enemy_tile.free()
	enemy_tile2.free()
	manager.queue_free()


func test_enemy_adjacent_condition_excludes_tile_in_front_as_defender() -> void:
	# Regresión: antes usaba battle_front_manager.get_front_for_tile() que
	# solo buscaba en los frentes del ATACANTE. Ahora usa el registro global
	# BattleFront.is_tile_in_active_front() que detecta también frentes donde
	# la tile es DEFENSORA de otro imperio.
	var own_tile := _create_tile(Tile.biome_type.Grassland, empire)
	var enemy_tile := _create_tile(Tile.biome_type.Grassland, enemy_empire)
	var third_empire := Empire.new()
	third_empire.name = "Third"
	var third_tile := _create_tile(Tile.biome_type.Grassland, third_empire)
	own_tile.neighbors = [enemy_tile]
	enemy_tile.neighbors = [own_tile, third_tile]
	third_tile.neighbors = [enemy_tile]
	empire.controlled_tiles = [own_tile]

	# Un tercer imperio abre un frente donde enemy_tile es DEFENSORA.
	var third_stats := Stats.new()
	third_stats.empire = third_empire
	third_stats.troop_pool = []
	var third_manager := BattleFrontManager.new()
	third_manager.stats = third_stats
	add_child(third_manager)
	third_manager.open_front(third_tile, enemy_tile)

	var condition := EnemyAdjacentCondition.new()
	condition.empire = empire

	# enemy_tile está en el registro como defensora → no debe ser target
	assert_false(condition.is_valid_target(enemy_tile),
		"Tile defensora en frente de otro imperio no debe ser target")

	own_tile.free()
	enemy_tile.free()
	third_tile.free()
	third_manager.queue_free()


func test_open_front_card_apply_effects_null_bfm() -> void:
	# Si battle_front_manager no se inyectó (es null), apply_effects no debe
	# crashear ni abrir ningún frente.
	var own_tile := _create_tile(Tile.biome_type.Grassland, empire)
	var enemy_tile := _create_tile(Tile.biome_type.Grassland, enemy_empire)
	own_tile.neighbors = [enemy_tile]
	enemy_tile.neighbors = [own_tile]

	var card := OpenFrontCard.new()
	card.target = Card.Target.TILE
	card.battle_front_manager = null   # inyección ausente (bug previo del jugador)
	card.target_enemy_tile = enemy_tile
	card.source_own_tile = own_tile

	# No debe crashear
	card.apply_effects([enemy_tile], stats)

	# No se ha abierto ningún frente (el guard de null retorna sin hacer nada)
	assert_eq(BattleFront.get_active_instances().size(), 0,
		"Sin battle_front_manager no debe abrirse ningún frente")

	own_tile.free()
	enemy_tile.free()
