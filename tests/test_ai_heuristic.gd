extends GutTest

## Tests para AIHeuristic.
## Verifica el scoring de edificios con efectos, el factor de coste,
## la elección de carta en Recover y el factor de bioma en OpenFront.

# ============================================================
#  Helpers
# ============================================================

func _make_stats(p_gpt: int = 100, p_food: int = 10,
		p_gold: int = 500) -> Stats:
	var s := Stats.new()
	s.total_gold = p_gold
	s.gold_per_turn = p_gpt
	s.food = p_food
	s.cards_per_turn = 3
	s.turn_number = 10  # mid game (AIGamePhase.MID)
	s.deck = CardPile.new()
	s.draw_pile = CardPile.new()
	s.discard_pile = CardPile.new()
	s.played_pile = CardPile.new()
	s.empire = Empire.new()
	s.empire.name = "TestAI"
	s.empire.controlled_tiles = []
	s.troop_pool = []
	s.possible_buildings = []
	return s


func _make_ctx(stats: Stats) -> AITurnContext:
	var ctx := AITurnContext.new()
	ctx.stats = stats
	ctx.rng = RandomNumberGenerator.new()
	ctx.drawn_cards = []
	return ctx


func _make_building(p_gold: int = 0, p_food: int = 0,
		p_defense: int = 0, p_cost: int = 50) -> Building:
	var b := Building.new()
	b.name = "TestBuilding"
	b.gold_produced = p_gold
	b.food_produced = p_food
	b.flat_defense_bonus = p_defense
	b.construction_cost = p_cost
	b.effects = []
	b.upgrades_to = []
	b.allowed_biomes = []
	b.allowed_location_type = []
	return b


func _make_tile(p_empire: Empire = null,
		p_biome: Tile.biome_type = Tile.biome_type.Grassland) -> Tile:
	var tile := Tile.new()
	tile.mesh_data = TileMeshData.new()
	tile.mesh_data.type = p_biome
	tile.mesh_data.color = Color.GREEN
	tile.natural_resource = NaturalResource.new()
	tile.natural_resource.gold_produced = 2
	tile.natural_resource.food_produced = 1
	var loc := LocationType.new()
	loc.type = Tile.location_type.Village
	loc.max_building = 2
	loc.food_consumption = 0
	tile.location = loc
	tile.max_buildings = 2
	tile.gold_production = 2
	tile.food_production = 1
	tile.controller = p_empire
	tile.neighbors = []
	tile.buildings = []
	return tile


func _make_build_option(building: Building, tile: Tile) -> AIBuildOption:
	var card := BuildCard.new()
	card.id = "build"
	card.target = Card.Target.TILE
	card.buildings = [building]
	return AIBuildOption.from_card(card, tile, building)


func _make_upgrade_option(old_b: Building, new_b: Building,
		tile: Tile) -> AIUpgradeBuildingOption:
	var card := UpgradeBuildingCard.new()
	card.id = "upgrade"
	card.target = Card.Target.TILE
	return AIUpgradeBuildingOption.from_card(card, tile, old_b, new_b)


# ============================================================
#  _score_build: efectos de edificio
# ============================================================

func test_build_with_flat_gold_effect_scores_higher_than_plain() -> void:
	# Edificio A: gold_produced=0, sin efectos.
	# Edificio B: gold_produced=0, AddStatModifierEffect +10 FLAT_GOLD.
	# B debe puntuar más alto.
	var stats := _make_stats(50, 10, 1000)
	var ctx := _make_ctx(stats)
	var tile := _make_tile(stats.empire)
	add_child_autofree(tile)

	var b_plain := _make_building(0, 0, 0, 50)
	var b_gold_effect := _make_building(0, 0, 0, 50)
	var eff := AddStatModifierEffect.new()
	eff.modifier_id = "gold_bonus"
	eff.modifier_name = "Gold Bonus"
	eff.stat_type = StatModifier.StatType.FLAT_GOLD
	eff.value = 10.0
	b_gold_effect.effects = [eff]

	var score_plain := AIHeuristic.score_option(_make_build_option(b_plain, tile), ctx)
	var score_effect := AIHeuristic.score_option(_make_build_option(b_gold_effect, tile), ctx)

	assert_true(score_effect > score_plain,
		"Edificio con +10 FLAT_GOLD debe puntuar más que uno sin efectos")


func test_build_with_cards_per_turn_effect_scores_much_higher() -> void:
	# CARDS_PER_TURN vale 12.0 por carta; cualquier edificio que lo tenga
	# debe superar claramente a uno sin efectos con mismos stats base.
	var stats := _make_stats(100, 10, 1000)
	var ctx := _make_ctx(stats)
	var tile := _make_tile(stats.empire)
	add_child_autofree(tile)

	var b_plain := _make_building(5, 0, 0, 50)  # score base ~25 (5*5*1.0)
	var b_cards := _make_building(5, 0, 0, 50)
	var eff := AddStatModifierEffect.new()
	eff.modifier_id = "cpt"
	eff.modifier_name = "+1 Card/Turn"
	eff.stat_type = StatModifier.StatType.CARDS_PER_TURN
	eff.value = 1.0
	b_cards.effects = [eff]

	var score_plain := AIHeuristic.score_option(_make_build_option(b_plain, tile), ctx)
	var score_cards := AIHeuristic.score_option(_make_build_option(b_cards, tile), ctx)

	assert_true(score_cards > score_plain + 10.0,
		"Edificio con +1 CARDS_PER_TURN debe puntuar 12+ puntos más")


func test_build_with_add_card_to_deck_effect_scores_higher() -> void:
	# Un edificio que mete una ColonizeCard (val ~15) al deck debe superar
	# a uno sin efectos con los mismos stats base.
	var stats := _make_stats(50, 10, 1000)
	stats.turn_number = 5  # early game → ColonizeCard vale 15.0
	var ctx := _make_ctx(stats)
	var tile := _make_tile(stats.empire)
	add_child_autofree(tile)

	var b_plain := _make_building(0, 0, 0, 50)
	var b_deck := _make_building(0, 0, 0, 50)
	var colonize := ColonizeCard.new()
	colonize.id = "colonize"
	colonize.target = Card.Target.TILE
	var eff := AddCardToDeckEffect.new()
	eff.card = colonize
	b_deck.effects = [eff]

	var score_plain := AIHeuristic.score_option(_make_build_option(b_plain, tile), ctx)
	var score_deck := AIHeuristic.score_option(_make_build_option(b_deck, tile), ctx)

	assert_true(score_deck > score_plain,
		"Edificio que añade ColonizeCard al deck debe puntuar más")


# ============================================================
#  _build_cost_factor
# ============================================================

func test_cost_factor_is_1_when_spending_nothing() -> void:
	# Edificio de coste 1 con 10000 de oro: spend_ratio ≈ 0 → factor ≈ 1.0
	var stats := _make_stats(100, 10, 10000)
	var ctx := _make_ctx(stats)
	var tile := _make_tile(stats.empire)
	add_child_autofree(tile)

	var b_cheap := _make_building(10, 0, 0, 1)   # coste residual
	var b_equiv := _make_building(10, 0, 0, 5000) # gasta 50% → factor ~0.8

	var score_cheap := AIHeuristic.score_option(_make_build_option(b_cheap, tile), ctx)
	var score_costly := AIHeuristic.score_option(_make_build_option(b_equiv, tile), ctx)

	assert_true(score_cheap > score_costly,
		"Edificio barato con mismos stats debe puntuar más que uno que gasta la mitad del oro")


func test_cost_factor_penalizes_spending_all_gold() -> void:
	# Edificio de coste = total_gold: spend_ratio=1.0 → factor=0.6
	# El score resultante debe ser ≤ 0.6 * score_sin_penalizacion
	var stats := _make_stats(100, 10, 100)
	var ctx := _make_ctx(stats)
	var tile := _make_tile(stats.empire)
	add_child_autofree(tile)

	# Dos edificios idénticos en stats; el caro gasta TODO el gold
	var b_free := _make_building(10, 0, 0, 1)    # casi gratis
	var b_all_in := _make_building(10, 0, 0, 100) # gasta todo

	var score_free := AIHeuristic.score_option(_make_build_option(b_free, tile), ctx)
	var score_all_in := AIHeuristic.score_option(_make_build_option(b_all_in, tile), ctx)

	assert_true(score_free > score_all_in,
		"Gastar todo el oro debe penalizar el score del edificio")


# ============================================================
#  _score_upgrade: delta de efectos
# ============================================================

func test_upgrade_to_building_with_effect_scores_higher_than_plain_upgrade() -> void:
	var stats := _make_stats(100, 10, 1000)
	var ctx := _make_ctx(stats)
	var tile := _make_tile(stats.empire)
	add_child_autofree(tile)

	var old_b := _make_building(5, 0, 0, 50)

	# Upgrade A: sin efectos extra, +5 gold
	var new_plain := _make_building(10, 0, 0, 100)

	# Upgrade B: mismos stats, pero añade +1 CARDS_PER_TURN
	var new_with_effect := _make_building(10, 0, 0, 100)
	var eff := AddStatModifierEffect.new()
	eff.modifier_id = "cpt"
	eff.modifier_name = "+1 CPT"
	eff.stat_type = StatModifier.StatType.CARDS_PER_TURN
	eff.value = 1.0
	new_with_effect.effects = [eff]

	var score_plain := AIHeuristic.score_option(_make_upgrade_option(old_b, new_plain, tile), ctx)
	var score_effect := AIHeuristic.score_option(_make_upgrade_option(old_b, new_with_effect, tile), ctx)

	assert_true(score_effect > score_plain,
		"Upgrade a edificio con CARDS_PER_TURN debe puntuar más que upgrade sin efectos")


# ============================================================
#  _score_recover: carta concreta
# ============================================================

func test_recover_high_value_card_scores_higher_than_low_value() -> void:
	# ColonizeCard vale 15 en early; GenerateGoldCard(5) vale ~2.
	# Recover con la ColonizeCard debe puntuar más.
	var stats := _make_stats(50, 10, 200)
	stats.turn_number = 3  # early game
	var ctx := _make_ctx(stats)

	var colonize := ColonizeCard.new()
	colonize.id = "colonize"
	colonize.target = Card.Target.TILE
	stats.played_pile.add_card(colonize)

	var gold_card := GenerateGoldCard.new()
	gold_card.id = "gold"
	gold_card.target = Card.Target.SELF
	gold_card.amount = 5
	stats.played_pile.add_card(gold_card)

	var rc_base := RecoverCard.new()
	rc_base.id = "recover"
	rc_base.target = Card.Target.SELF

	var opt_colonize := AIRecoverOption.from_card(rc_base, colonize)
	var opt_gold := AIRecoverOption.from_card(rc_base, gold_card)

	var score_colonize := AIHeuristic.score_option(opt_colonize, ctx)
	var score_gold := AIHeuristic.score_option(opt_gold, ctx)

	assert_true(score_colonize > score_gold,
		"Recover de ColonizeCard debe puntuar más que Recover de GenerateGoldCard(5)")


# ============================================================
#  _score_open_front: bioma
# ============================================================

func test_open_front_scores_lower_for_mountain_than_grassland() -> void:
	# Atacar montaña (factor 0.60) debe puntuar menos que atacar pradera (1.20).
	BattleFront.clear_active_instances()
	var stats := _make_stats(300, 15, 2000)
	stats.turn_number = 30  # mid game
	# pool_factor requiere tropas libres; 6 tropas → ×1.0 (pool_factor neutro).
	# El mismo pool_factor se aplica a ambas opciones, preservando el orden biome.
	for _i in range(6):
		var t := Troop.new()
		t.attack = 3
		t.defense = 3
		t.maintenance_food = 1
		t.maintenance_gold = 1
		stats.troop_pool.append(t)
	var empire := stats.empire
	var enemy_emp := Empire.new()
	enemy_emp.name = "Enemy"

	var own_tile := _make_tile(empire)
	add_child_autofree(own_tile)

	var mountain_tile := _make_tile(enemy_emp, Tile.biome_type.Mountain)
	add_child_autofree(mountain_tile)
	mountain_tile.neighbors = [own_tile]
	own_tile.neighbors = [mountain_tile]

	var grassland_tile := _make_tile(enemy_emp, Tile.biome_type.Grassland)
	add_child_autofree(grassland_tile)
	grassland_tile.neighbors = [own_tile]
	own_tile.neighbors = [mountain_tile, grassland_tile]

	empire.controlled_tiles = [own_tile]

	var bfm := BattleFrontManager.new()
	bfm.stats = stats
	add_child_autofree(bfm)
	var ctx := _make_ctx(stats)
	ctx.battle_front_manager = bfm

	var card := OpenFrontCard.new()
	card.id = "open"
	card.target = Card.Target.TILE

	var opt_mountain := AIOpenFrontOption.from_card(card, mountain_tile, own_tile, bfm)
	var opt_grassland := AIOpenFrontOption.from_card(card, grassland_tile, own_tile, bfm)

	var score_mountain := AIHeuristic.score_option(opt_mountain, ctx)
	var score_grassland := AIHeuristic.score_option(opt_grassland, ctx)

	assert_true(score_grassland > score_mountain,
		"Atacar pradera (biome_factor 1.20) debe puntuar más que atacar montaña (0.60)")
	BattleFront.clear_active_instances()
