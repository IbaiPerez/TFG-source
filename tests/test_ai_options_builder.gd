extends GutTest

## Tests para AIOptionsBuilder. Cobertura Fase 1: ColonizeCard,
## GenerateGoldCard, CardDrawCard, DirectBuildCard. El resto de cartas
## devuelve [] hasta Fase 2.


# ============================================================
#  Helpers
# ============================================================

func _make_empire(p_name: String = "TestAI") -> Empire:
	var e := Empire.new()
	e.name = p_name
	e.color = Color.RED
	e.controlled_tiles = []
	return e


func _make_tile(p_biome: Tile.biome_type = Tile.biome_type.Grassland) -> Tile:
	var tile := Tile.new()
	tile.mesh_data = TileMeshData.new()
	tile.mesh_data.type = p_biome
	tile.mesh_data.color = Color.GREEN
	tile.natural_resource = NaturalResource.new()
	tile.natural_resource.gold_produced = 1
	tile.natural_resource.food_produced = 1
	var loc := LocationType.new()
	loc.type = Tile.location_type.Village
	loc.max_building = 2
	loc.food_consumption = 0
	tile.location = loc
	tile.max_buildings = 2
	tile.food_production = 1
	tile.gold_production = 1
	tile.controller = null
	tile.neighbors = []
	tile.buildings = []
	return tile


func _make_stats(p_gold: int = 200) -> Stats:
	var s := Stats.new()
	s.total_gold = p_gold
	# gpt y food positivos: el nuevo `can_afford_troop` (Opcion 3b)
	# bloquea cualquier recruit si gpt o food no cubren el mantenimiento
	# de la nueva tropa. Estos tests no quieren testear ese gating, asi
	# que les damos margen amplio. Los tests especificos del gating
	# viven en test_troops.gd.
	s.gold_per_turn = 100
	s.food = 100
	s.cards_per_turn = 3
	s.draw_pile = CardPile.new()
	s.discard_pile = CardPile.new()
	s.played_pile = CardPile.new()
	s.empire = _make_empire()
	s.possible_buildings = []
	return s


func _make_ctx(stats: Stats) -> AITurnContext:
	# Para tests del builder no necesitamos un AIController real: stats
	# y rng es suficiente. Construimos el ctx a mano.
	var ctx := AITurnContext.new()
	ctx.controller = null
	ctx.stats = stats
	ctx.battle_front_manager = null
	ctx.rng = RandomNumberGenerator.new()
	ctx.drawn_cards = []
	return ctx


func _make_building(p_name: String = "Mine", p_cost: int = 50) -> Building:
	var b := Building.new()
	b.name = p_name
	b.construction_cost = p_cost
	b.gold_produced = 3
	b.food_produced = 0
	b.allowed_biomes = []
	b.allowed_location_type = []
	b.required_natural_resource = null
	b.effects = []
	b.upgrades_to = []
	return b


# ============================================================
#  ColonizeCard
# ============================================================

func test_colonize_one_option_per_adjacent_uncontrolled_tile() -> void:
	var stats := _make_stats()
	var own_tile := _make_tile()
	var n1 := _make_tile()
	var n2 := _make_tile()
	add_child_autofree(own_tile)
	add_child_autofree(n1)
	add_child_autofree(n2)
	own_tile.controller = stats.empire
	own_tile.neighbors = [n1, n2]
	stats.empire.controlled_tiles = [own_tile]

	var card := ColonizeCard.new()
	card.target = Card.Target.TILE

	var options := AIOptionsBuilder.build_options(card, _make_ctx(stats))
	assert_eq(options.size(), 2, "Debe haber 1 opción por cada vecino libre")
	for opt in options:
		assert_eq(opt.card, card)
		assert_eq(opt.targets.size(), 1)
		assert_false(opt.is_pass)


func test_colonize_no_options_if_no_uncontrolled_neighbors() -> void:
	var stats := _make_stats()
	var own_tile := _make_tile()
	var enemy_tile := _make_tile()
	add_child_autofree(own_tile)
	add_child_autofree(enemy_tile)
	enemy_tile.controller = _make_empire("Otro")
	own_tile.controller = stats.empire
	own_tile.neighbors = [enemy_tile]
	stats.empire.controlled_tiles = [own_tile]

	var card := ColonizeCard.new()
	card.target = Card.Target.TILE

	var options := AIOptionsBuilder.build_options(card, _make_ctx(stats))
	assert_eq(options.size(), 0)


func test_colonize_no_options_with_no_controlled_tiles() -> void:
	var stats := _make_stats()
	# empire.controlled_tiles vacío
	var card := ColonizeCard.new()
	card.target = Card.Target.TILE

	var options := AIOptionsBuilder.build_options(card, _make_ctx(stats))
	assert_eq(options.size(), 0)


# ============================================================
#  ChangeLocationTypeCard (Urban Project / urbanizaciones)
# ============================================================

func _make_town_location_type(p_food_cost: int = 5) -> LocationType:
	var lt := LocationType.new()
	lt.type = Tile.location_type.Town
	lt.max_building = 3
	lt.food_consumption = p_food_cost
	return lt


func test_change_location_type_one_option_per_legal_tile() -> void:
	var stats := _make_stats()
	stats.food = 10  # suficiente para urbanizar
	var t1 := _make_tile()
	var t2 := _make_tile()
	add_child_autofree(t1)
	add_child_autofree(t2)
	t1.controller = stats.empire
	t2.controller = stats.empire
	# _make_tile() ya pone location en Village, así que son urbanizables a Town.
	stats.empire.controlled_tiles = [t1, t2]

	var card := ChangeLocationTypeCard.new()
	card.target = Card.Target.TILE
	card.location_type = _make_town_location_type(5)

	var options := AIOptionsBuilder.build_options(card, _make_ctx(stats))
	assert_eq(options.size(), 2,
		"Dos villages del imperio + comida suficiente → 2 opciones")
	for opt in options:
		assert_eq(opt.card, card)
		assert_eq(opt.targets.size(), 1)
		assert_false(opt.is_pass)


func test_change_location_type_no_options_when_food_too_low() -> void:
	var stats := _make_stats()
	stats.food = 2  # menos que food_consumption del Town
	var t := _make_tile()
	add_child_autofree(t)
	t.controller = stats.empire
	stats.empire.controlled_tiles = [t]

	var card := ChangeLocationTypeCard.new()
	card.target = Card.Target.TILE
	card.location_type = _make_town_location_type(5)

	var options := AIOptionsBuilder.build_options(card, _make_ctx(stats))
	assert_eq(options.size(), 0,
		"Sin comida suficiente la condición rechaza la tile")


func test_change_location_type_requires_consecutive_level() -> void:
	# Tile Uncolonized → no se puede saltar directamente a Town.
	var stats := _make_stats()
	stats.food = 10
	var t := _make_tile()
	add_child_autofree(t)
	t.controller = stats.empire
	var uncolonized := LocationType.new()
	uncolonized.type = Tile.location_type.Uncolonized
	t.location = uncolonized
	stats.empire.controlled_tiles = [t]

	var card := ChangeLocationTypeCard.new()
	card.target = Card.Target.TILE
	card.location_type = _make_town_location_type(5)

	var options := AIOptionsBuilder.build_options(card, _make_ctx(stats))
	assert_eq(options.size(), 0,
		"Solo se urbaniza al nivel inmediatamente superior (Village → Town)")


func test_change_location_type_no_options_with_no_controlled_tiles() -> void:
	var stats := _make_stats()
	stats.food = 10
	# empire.controlled_tiles vacío

	var card := ChangeLocationTypeCard.new()
	card.target = Card.Target.TILE
	card.location_type = _make_town_location_type(5)

	var options := AIOptionsBuilder.build_options(card, _make_ctx(stats))
	assert_eq(options.size(), 0)


# ============================================================
#  GenerateGoldCard
# ============================================================

func test_generate_gold_returns_single_option_with_empty_targets() -> void:
	var stats := _make_stats()
	var card := GenerateGoldCard.new()
	card.target = Card.Target.SELF
	card.amount = 30

	var options := AIOptionsBuilder.build_options(card, _make_ctx(stats))
	assert_eq(options.size(), 1)
	assert_eq(options[0].card, card)
	assert_eq(options[0].targets.size(), 0)
	assert_false(options[0].is_pass)


# ============================================================
#  CardDrawCard
# ============================================================

func test_card_draw_returns_a_draw_option_subclass() -> void:
	var stats := _make_stats()
	var card := CardDrawCard.new()
	card.target = Card.Target.SELF
	card.amount = 2

	var options := AIOptionsBuilder.build_options(card, _make_ctx(stats))
	assert_eq(options.size(), 1)
	assert_true(options[0] is AIDrawCardOption,
		"CardDrawCard debe producir un AIDrawCardOption (bypass)")
	var draw_opt := options[0] as AIDrawCardOption
	assert_eq(draw_opt.amount, 2)


# ============================================================
#  DirectBuildCard
# ============================================================

func test_direct_build_filters_by_gold_and_can_build() -> void:
	var stats := _make_stats(100)
	var building := _make_building("CheapMine", 50)
	var own_tile := _make_tile()
	add_child_autofree(own_tile)
	own_tile.controller = stats.empire
	stats.empire.controlled_tiles = [own_tile]

	var card := DirectBuildCard.new()
	card.target = Card.Target.TILE
	card.buildings = [building]

	var options := AIOptionsBuilder.build_options(card, _make_ctx(stats))
	assert_eq(options.size(), 1, "Una tile válida + oro suficiente → 1 opción")


func test_direct_build_no_options_if_too_expensive() -> void:
	var stats := _make_stats(10)  # poco oro
	var building := _make_building("ExpensiveMine", 999)
	var own_tile := _make_tile()
	add_child_autofree(own_tile)
	own_tile.controller = stats.empire
	stats.empire.controlled_tiles = [own_tile]

	var card := DirectBuildCard.new()
	card.target = Card.Target.TILE
	card.buildings = [building]

	var options := AIOptionsBuilder.build_options(card, _make_ctx(stats))
	assert_eq(options.size(), 0, "Sin oro suficiente, no hay opciones")


# ============================================================
#  Cartas no cubiertas en Fase 1
# ============================================================

func test_null_card_returns_empty() -> void:
	var stats := _make_stats()
	var options := AIOptionsBuilder.build_options(null, _make_ctx(stats))
	assert_eq(options.size(), 0)


# ============================================================
#  BuildCard (Fase 2)
# ============================================================

func test_build_card_enumerates_tile_x_building_pairs() -> void:
	var stats := _make_stats(500)
	var b1 := _make_building("Mine", 50)
	var b2 := _make_building("Farm", 50)
	var t1 := _make_tile()
	var t2 := _make_tile()
	add_child_autofree(t1)
	add_child_autofree(t2)
	t1.controller = stats.empire
	t2.controller = stats.empire
	stats.empire.controlled_tiles = [t1, t2]

	var card := BuildCard.new()
	card.target = Card.Target.TILE
	card.buildings = [b1, b2]

	var options := AIOptionsBuilder.build_options(card, _make_ctx(stats))
	assert_eq(options.size(), 4,
		"2 tiles × 2 buildings = 4 opciones cuando todas son legales")
	for opt in options:
		assert_true(opt is AIBuildOption, "Cada opción debe ser AIBuildOption")


func test_build_card_filters_unaffordable_buildings() -> void:
	var stats := _make_stats(40)  # menos que el coste
	var building := _make_building("ExpensiveMine", 100)
	var tile := _make_tile()
	add_child_autofree(tile)
	tile.controller = stats.empire
	stats.empire.controlled_tiles = [tile]

	var card := BuildCard.new()
	card.target = Card.Target.TILE
	card.buildings = [building]

	var options := AIOptionsBuilder.build_options(card, _make_ctx(stats))
	assert_eq(options.size(), 0, "Sin oro suficiente, no hay opciones")


func test_build_card_filters_when_tile_cant_build() -> void:
	var stats := _make_stats(500)
	var building := _make_building("Mine", 50)
	var tile := _make_tile()
	add_child_autofree(tile)
	tile.controller = stats.empire
	# Saturar la tile con un building distinto para que can_build falle
	tile.max_buildings = 1
	tile.buildings = [_make_building("ExistingBuilding", 0)]
	stats.empire.controlled_tiles = [tile]

	var card := BuildCard.new()
	card.target = Card.Target.TILE
	card.buildings = [building]

	var options := AIOptionsBuilder.build_options(card, _make_ctx(stats))
	assert_eq(options.size(), 0, "Tile sin slots libres → 0 opciones")


func test_build_card_empty_buildings_returns_no_options() -> void:
	var stats := _make_stats(500)
	var tile := _make_tile()
	add_child_autofree(tile)
	tile.controller = stats.empire
	stats.empire.controlled_tiles = [tile]

	var card := BuildCard.new()
	card.target = Card.Target.TILE
	card.buildings = []

	var options := AIOptionsBuilder.build_options(card, _make_ctx(stats))
	assert_eq(options.size(), 0)


# ============================================================
#  UpgradeBuildingCard (Fase 2)
# ============================================================

func _make_upgradable_chain(p_old_name: String = "Mine",
		p_new_name: String = "ImprovedMine",
		p_old_cost: int = 50, p_new_cost: int = 100) -> Array:
	var new_b := _make_building(p_new_name, p_new_cost)
	var old_b := _make_building(p_old_name, p_old_cost)
	old_b.upgrades_to = [new_b]
	return [old_b, new_b]


func test_upgrade_building_enumerates_legal_pairs() -> void:
	var stats := _make_stats(500)
	var chain := _make_upgradable_chain()
	var old_b: Building = chain[0]
	var new_b: Building = chain[1]

	var tile := _make_tile()
	add_child_autofree(tile)
	tile.controller = stats.empire
	tile.buildings = [old_b]
	tile.max_buildings = 2
	stats.empire.controlled_tiles = [tile]

	var card := UpgradeBuildingCard.new()
	card.target = Card.Target.TILE

	var options := AIOptionsBuilder.build_options(card, _make_ctx(stats))
	assert_eq(options.size(), 1, "1 building upgradable × 1 nuevo = 1 opción")
	assert_true(options[0] is AIUpgradeBuildingOption)
	var u := options[0] as AIUpgradeBuildingOption
	assert_eq(u.old_building, old_b)
	assert_eq(u.new_building, new_b)


func test_upgrade_building_filters_unaffordable() -> void:
	var stats := _make_stats(20)  # menos que el coste del nuevo
	var chain := _make_upgradable_chain("Mine", "ExpensiveMine", 50, 999)
	var old_b: Building = chain[0]

	var tile := _make_tile()
	add_child_autofree(tile)
	tile.controller = stats.empire
	tile.buildings = [old_b]
	stats.empire.controlled_tiles = [tile]

	var card := UpgradeBuildingCard.new()
	card.target = Card.Target.TILE

	var options := AIOptionsBuilder.build_options(card, _make_ctx(stats))
	assert_eq(options.size(), 0, "Sin oro para el upgrade, no hay opciones")


func test_upgrade_building_no_options_with_no_upgradable_buildings() -> void:
	var stats := _make_stats(500)
	# Building sin upgrades_to → no es upgradable.
	var tile := _make_tile()
	add_child_autofree(tile)
	tile.controller = stats.empire
	tile.buildings = [_make_building("Final", 0)]
	stats.empire.controlled_tiles = [tile]

	var card := UpgradeBuildingCard.new()
	card.target = Card.Target.TILE

	var options := AIOptionsBuilder.build_options(card, _make_ctx(stats))
	assert_eq(options.size(), 0)


# ============================================================
#  RecruitCard (Fase 2)
# ============================================================

func _make_troop(p_name: String = "Knight", p_cost: int = 30) -> Troop:
	var t := Troop.new()
	t.name = p_name
	t.attack = 3
	t.defense = 3
	t.recruitment_cost_gold = p_cost
	t.maintenance_gold = 1
	t.maintenance_food = 1
	return t


func test_recruit_card_enumerates_one_per_affordable_troop() -> void:
	var stats := _make_stats(100)
	var t1 := _make_troop("T1", 30)
	var t2 := _make_troop("T2", 50)
	var t3 := _make_troop("T3", 200)  # no asequible

	var card := RecruitCard.new()
	card.target = Card.Target.SELF
	card.available_troops = [t1, t2, t3]

	var options := AIOptionsBuilder.build_options(card, _make_ctx(stats))
	assert_eq(options.size(), 2, "Solo las 2 tropas asequibles deben generar opciones")
	for opt in options:
		assert_true(opt is AIRecruitOption)
		var r := opt as AIRecruitOption
		assert_true(r.troop != t3, "T3 no debe aparecer (caro)")


func test_recruit_card_no_options_when_all_unaffordable() -> void:
	var stats := _make_stats(5)
	var t := _make_troop("Pricey", 100)

	var card := RecruitCard.new()
	card.target = Card.Target.SELF
	card.available_troops = [t]

	var options := AIOptionsBuilder.build_options(card, _make_ctx(stats))
	assert_eq(options.size(), 0)


# ============================================================
#  OpenFrontCard (Fase 2)
# ============================================================

func _make_bfm_for(stats: Stats) -> BattleFrontManager:
	var bfm := BattleFrontManager.new()
	bfm.stats = stats
	bfm.base_max_fronts = 3
	add_child_autofree(bfm)
	return bfm


func _make_ctx_with_bfm(stats: Stats, bfm: BattleFrontManager) -> AITurnContext:
	var ctx := AITurnContext.new()
	ctx.controller = null
	ctx.stats = stats
	ctx.battle_front_manager = bfm
	ctx.rng = RandomNumberGenerator.new()
	ctx.drawn_cards = []
	return ctx


func test_open_front_enumerates_enemy_x_own_neighbor_pairs() -> void:
	BattleFront.clear_active_instances()
	var stats := _make_stats()
	var enemy_empire := _make_empire("Enemy")
	var own1 := _make_tile()
	var own2 := _make_tile()
	var enemy_tile := _make_tile()
	add_child_autofree(own1)
	add_child_autofree(own2)
	add_child_autofree(enemy_tile)
	own1.controller = stats.empire
	own2.controller = stats.empire
	enemy_tile.controller = enemy_empire
	# Ambas tiles propias adyacentes a la enemiga
	own1.neighbors = [enemy_tile]
	own2.neighbors = [enemy_tile]
	enemy_tile.neighbors = [own1, own2]
	stats.empire.controlled_tiles = [own1, own2]

	var bfm := _make_bfm_for(stats)
	var card := OpenFrontCard.new()
	card.target = Card.Target.TILE

	var options := AIOptionsBuilder.build_options(card, _make_ctx_with_bfm(stats, bfm))
	assert_eq(options.size(), 2, "1 tile enemiga × 2 propias adyacentes = 2 opciones")
	for opt in options:
		assert_true(opt is AIOpenFrontOption)


func test_open_front_excludes_tiles_with_active_front() -> void:
	BattleFront.clear_active_instances()
	var stats := _make_stats()
	var enemy_empire := _make_empire("Enemy")
	var own_tile := _make_tile()
	var enemy_tile := _make_tile()
	add_child_autofree(own_tile)
	add_child_autofree(enemy_tile)
	own_tile.controller = stats.empire
	enemy_tile.controller = enemy_empire
	own_tile.neighbors = [enemy_tile]
	enemy_tile.neighbors = [own_tile]
	stats.empire.controlled_tiles = [own_tile]

	var bfm := _make_bfm_for(stats)
	# Abrimos un frente para ocupar las tiles
	bfm.open_front(own_tile, enemy_tile)

	var card := OpenFrontCard.new()
	card.target = Card.Target.TILE

	var options := AIOptionsBuilder.build_options(card, _make_ctx_with_bfm(stats, bfm))
	assert_eq(options.size(), 0,
		"Tile enemiga ya en frente activo no debe generar opciones")
	BattleFront.clear_active_instances()


# ============================================================
#  TacticCard (Fase 3)
# ============================================================

func _make_battle_front(atk_empire: Empire, def_empire: Empire) -> BattleFront:
	# Crear tiles mínimos para el constructor de BattleFront
	var atk_tile := _make_tile()
	var def_tile := _make_tile()
	add_child_autofree(atk_tile)
	add_child_autofree(def_tile)
	atk_tile.controller = atk_empire
	def_tile.controller = def_empire
	atk_tile.neighbors = [def_tile]
	def_tile.neighbors = [atk_tile]
	return BattleFront.new(atk_tile, def_tile, atk_empire, def_empire)


func test_tactic_card_enumerates_active_fronts_where_ia_participates() -> void:
	BattleFront.clear_active_instances()
	var stats := _make_stats()
	var enemy_empire := _make_empire("Enemy")
	var bfm := _make_bfm_for(stats)

	# Frente donde la IA es atacante
	var f1 := _make_battle_front(stats.empire, enemy_empire)
	# Frente donde la IA es defensora
	var f2 := _make_battle_front(enemy_empire, stats.empire)
	bfm.active_fronts = [f1, f2]

	var card := TacticCard.new()
	card.target = Card.Target.BATTLE_FRONT

	var options := AIOptionsBuilder.build_options(card, _make_ctx_with_bfm(stats, bfm))
	assert_eq(options.size(), 2,
		"La IA participa como atacante en f1 y como defensora en f2 → 2 opciones")
	for opt in options:
		assert_true(opt is AITacticOption)
	BattleFront.clear_active_instances()


func test_tactic_card_excludes_fronts_where_ia_does_not_participate() -> void:
	BattleFront.clear_active_instances()
	var stats := _make_stats()
	var enemy1 := _make_empire("E1")
	var enemy2 := _make_empire("E2")
	var bfm := _make_bfm_for(stats)

	# Frente entre dos imperios ajenos: la IA no participa
	var f := _make_battle_front(enemy1, enemy2)
	bfm.active_fronts = [f]

	var card := TacticCard.new()
	card.target = Card.Target.BATTLE_FRONT

	var options := AIOptionsBuilder.build_options(card, _make_ctx_with_bfm(stats, bfm))
	assert_eq(options.size(), 0,
		"Frentes ajenos no deben generar opciones para la IA")
	BattleFront.clear_active_instances()


func test_tactic_card_excludes_resolved_fronts() -> void:
	BattleFront.clear_active_instances()
	var stats := _make_stats()
	var enemy_empire := _make_empire("Enemy")
	var bfm := _make_bfm_for(stats)

	var f := _make_battle_front(stats.empire, enemy_empire)
	f.is_resolved = true
	bfm.active_fronts = [f]

	var card := TacticCard.new()
	card.target = Card.Target.BATTLE_FRONT

	var options := AIOptionsBuilder.build_options(card, _make_ctx_with_bfm(stats, bfm))
	assert_eq(options.size(), 0,
		"Frentes ya resueltos no deben generar opciones")
	BattleFront.clear_active_instances()


func test_tactic_card_no_options_with_no_fronts() -> void:
	BattleFront.clear_active_instances()
	var stats := _make_stats()
	var bfm := _make_bfm_for(stats)
	# bfm.active_fronts = [] por defecto

	var card := TacticCard.new()
	card.target = Card.Target.BATTLE_FRONT

	var options := AIOptionsBuilder.build_options(card, _make_ctx_with_bfm(stats, bfm))
	assert_eq(options.size(), 0)


# ============================================================
#  RecoverCard (Fase 3)
# ============================================================

func test_recover_card_enumerates_one_per_played_pile_card() -> void:
	var stats := _make_stats()
	var c1 := _make_gold_card("p1", 5)
	var c2 := _make_gold_card("p2", 10)
	stats.played_pile.add_card(c1)
	stats.played_pile.add_card(c2)

	var card := RecoverCard.new()
	card.target = Card.Target.SELF

	var options := AIOptionsBuilder.build_options(card, _make_ctx(stats))
	assert_eq(options.size(), 2, "1 opción por cada carta del played_pile")
	for opt in options:
		assert_true(opt is AIRecoverOption)
	# Verificar que las dos cartas del played_pile están entre los chosen_card
	var chosen_set := []
	for opt in options:
		chosen_set.append((opt as AIRecoverOption).chosen_card)
	assert_true(c1 in chosen_set)
	assert_true(c2 in chosen_set)


func test_recover_card_no_options_with_empty_played_pile() -> void:
	var stats := _make_stats()
	# played_pile vacío por defecto
	var card := RecoverCard.new()
	card.target = Card.Target.SELF

	var options := AIOptionsBuilder.build_options(card, _make_ctx(stats))
	assert_eq(options.size(), 0)


func _make_gold_card(p_id: String = "g", p_amount: int = 10) -> GenerateGoldCard:
	var c := GenerateGoldCard.new()
	c.id = p_id
	c.target = Card.Target.SELF
	c.amount = p_amount
	return c


func test_open_front_no_options_at_max_fronts() -> void:
	BattleFront.clear_active_instances()
	var stats := _make_stats()
	var enemy_empire := _make_empire("Enemy")
	var own_tile := _make_tile()
	var enemy_tile := _make_tile()
	add_child_autofree(own_tile)
	add_child_autofree(enemy_tile)
	own_tile.controller = stats.empire
	enemy_tile.controller = enemy_empire
	own_tile.neighbors = [enemy_tile]
	enemy_tile.neighbors = [own_tile]
	stats.empire.controlled_tiles = [own_tile]

	var bfm := _make_bfm_for(stats)
	bfm.base_max_fronts = 0  # ningún frente permitido
	bfm.tiles_per_extra_front = 9999

	var card := OpenFrontCard.new()
	card.target = Card.Target.TILE

	var options := AIOptionsBuilder.build_options(card, _make_ctx_with_bfm(stats, bfm))
	assert_eq(options.size(), 0,
		"Si can_open_front es false, no se enumeran opciones")
