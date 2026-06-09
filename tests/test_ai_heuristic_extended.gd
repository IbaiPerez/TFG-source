extends GutTest
## Batería extendida de tests para AIHeuristic.
## Cubre funciones no testadas en test_ai_heuristic.gd:
## urgencias (gold/food/deck), saturación, factores auxiliares,
## scoring de todas las opciones y decisiones de mazo/tienda.


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
	s.turn_number = 10
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


func _make_troop(p_atk: int = 3, p_def: int = 3,
		p_mfood: int = 0, p_mgold: int = 0) -> Troop:
	var t := Troop.new()
	t.attack = p_atk
	t.defense = p_def
	t.maintenance_food = p_mfood
	t.maintenance_gold = p_mgold
	return t


func _make_location(p_type: Tile.location_type,
		p_food: int = 0, p_max_b: int = 2) -> LocationType:
	var loc := LocationType.new()
	loc.type = p_type
	loc.food_consumption = p_food
	loc.max_building = p_max_b
	return loc


func _make_ctx_with_deck_size(size: int) -> AITurnContext:
	var stats := _make_stats()
	for _i in size:
		stats.draw_pile.add_card(GenerateGoldCard.new())
	return _make_ctx(stats)


func _make_recruit_option(troop: Troop) -> AIRecruitOption:
	var card := RecruitCard.new()
	card.id = "recruit"
	card.target = Card.Target.SELF
	card.available_troops = []
	return AIRecruitOption.from_card(card, troop)


func _make_choice(effects: Array[TurnEventEffect]) -> TurnEventChoice:
	var choice := TurnEventChoice.new()
	choice.effects = effects
	choice.cost = null
	return choice


func _make_shop_item(card: Card) -> ShopItem:
	var item := ShopItem.new()
	item.card = card
	item.price = 10
	return item


# ============================================================
#  _gold_urgency
# ============================================================

func test_gold_urgency_early_crisis() -> void:
	# gpt=5 < 10 → 3.0
	assert_almost_eq(AIHeuristic._gold_urgency(5, AIGamePhase.Phase.EARLY), 3.0, 0.01)

func test_gold_urgency_early_low() -> void:
	# gpt=20 (10..30) → 1.8
	assert_almost_eq(AIHeuristic._gold_urgency(20, AIGamePhase.Phase.EARLY), 1.8, 0.01)

func test_gold_urgency_early_medium() -> void:
	# gpt=45 (30..60) → 1.0
	assert_almost_eq(AIHeuristic._gold_urgency(45, AIGamePhase.Phase.EARLY), 1.0, 0.01)

func test_gold_urgency_early_comfortable() -> void:
	# gpt=80 (≥60) → 0.7
	assert_almost_eq(AIHeuristic._gold_urgency(80, AIGamePhase.Phase.EARLY), 0.7, 0.01)

func test_gold_urgency_mid_crisis() -> void:
	# gpt=30 < 50 → 3.0
	assert_almost_eq(AIHeuristic._gold_urgency(30, AIGamePhase.Phase.MID), 3.0, 0.01)

func test_gold_urgency_mid_low() -> void:
	# gpt=100 (50..150) → 2.0
	assert_almost_eq(AIHeuristic._gold_urgency(100, AIGamePhase.Phase.MID), 2.0, 0.01)

func test_gold_urgency_mid_medium() -> void:
	# gpt=200 (150..250) → 1.3
	assert_almost_eq(AIHeuristic._gold_urgency(200, AIGamePhase.Phase.MID), 1.3, 0.01)

func test_gold_urgency_mid_target() -> void:
	# gpt=300 (250..400) → 1.0
	assert_almost_eq(AIHeuristic._gold_urgency(300, AIGamePhase.Phase.MID), 1.0, 0.01)

func test_gold_urgency_mid_surplus() -> void:
	# gpt=500 (≥400) → 0.7
	assert_almost_eq(AIHeuristic._gold_urgency(500, AIGamePhase.Phase.MID), 0.7, 0.01)

func test_gold_urgency_late_negative() -> void:
	# gpt=-5 < 0 → 3.0
	assert_almost_eq(AIHeuristic._gold_urgency(-5, AIGamePhase.Phase.LATE), 3.0, 0.01)

func test_gold_urgency_late_comfortable() -> void:
	# gpt=250 (200..500) → 0.7 (rendimiento decreciente en late rico)
	assert_almost_eq(AIHeuristic._gold_urgency(250, AIGamePhase.Phase.LATE), 0.7, 0.01)


# ============================================================
#  _food_urgency
# ============================================================

func test_food_urgency_early_negative() -> void:
	assert_almost_eq(AIHeuristic._food_urgency(-1, AIGamePhase.Phase.EARLY), 3.0, 0.01)

func test_food_urgency_early_tight() -> void:
	# food=1 (0..2) → 1.8
	assert_almost_eq(AIHeuristic._food_urgency(1, AIGamePhase.Phase.EARLY), 1.8, 0.01)

func test_food_urgency_early_acceptable() -> void:
	# food=3 (2..5) → 1.0
	assert_almost_eq(AIHeuristic._food_urgency(3, AIGamePhase.Phase.EARLY), 1.0, 0.01)

func test_food_urgency_early_comfortable() -> void:
	# food=10 (≥5) → 0.8
	assert_almost_eq(AIHeuristic._food_urgency(10, AIGamePhase.Phase.EARLY), 0.8, 0.01)

func test_food_urgency_mid_negative() -> void:
	assert_almost_eq(AIHeuristic._food_urgency(-1, AIGamePhase.Phase.MID), 3.0, 0.01)

func test_food_urgency_mid_tight() -> void:
	# food=3 (0..5) → 2.0 (más estricto que early)
	assert_almost_eq(AIHeuristic._food_urgency(3, AIGamePhase.Phase.MID), 2.0, 0.01)

func test_food_urgency_mid_margin() -> void:
	# food=7 (5..10) → 1.2
	assert_almost_eq(AIHeuristic._food_urgency(7, AIGamePhase.Phase.MID), 1.2, 0.01)

func test_food_urgency_mid_comfortable() -> void:
	# food=15 (≥10) → 1.0
	assert_almost_eq(AIHeuristic._food_urgency(15, AIGamePhase.Phase.MID), 1.0, 0.01)


# ============================================================
#  _deck_urgency (via _score_draw / score_option)
# ============================================================

func _make_draw_option(amount: int) -> AIDrawCardOption:
	var card := CardDrawCard.new()
	card.id = "draw"
	card.amount = amount
	return AIDrawCardOption.from_card(card)


func test_deck_urgency_empty_pile_returns_max_score() -> void:
	# draw_size=0 → urgency=2.0 → score=1*4*2.0=8.0
	var ctx := _make_ctx(_make_stats())
	assert_almost_eq(AIHeuristic.score_option(_make_draw_option(1), ctx), 8.0, 0.01)


func test_deck_urgency_boundary_at_3() -> void:
	# draw_size=3 → urgency=1.4 → score=1*4*1.4=5.6
	var stats := _make_stats()
	for _i in 3:
		stats.draw_pile.add_card(GenerateGoldCard.new())
	var ctx := _make_ctx(stats)
	assert_almost_eq(AIHeuristic.score_option(_make_draw_option(1), ctx), 5.6, 0.01)


func test_deck_urgency_boundary_at_6() -> void:
	# draw_size=6 → urgency=1.0 → score=4.0
	var stats := _make_stats()
	for _i in 6:
		stats.draw_pile.add_card(GenerateGoldCard.new())
	var ctx := _make_ctx(stats)
	assert_almost_eq(AIHeuristic.score_option(_make_draw_option(1), ctx), 4.0, 0.01)


func test_deck_urgency_small_pile_scores_higher_than_large() -> void:
	var stats_small := _make_stats()
	for _i in 2:
		stats_small.draw_pile.add_card(GenerateGoldCard.new())
	var ctx_small := _make_ctx(stats_small)

	var stats_large := _make_stats()
	for _i in 6:
		stats_large.draw_pile.add_card(GenerateGoldCard.new())
	var ctx_large := _make_ctx(stats_large)

	var score_small := AIHeuristic.score_option(_make_draw_option(1), ctx_small)
	var score_large := AIHeuristic.score_option(_make_draw_option(1), ctx_large)
	assert_true(score_small > score_large,
		"Pila pequeña debe dar score mayor a _score_draw que pila grande")


# ============================================================
#  _type_saturation
# ============================================================

func test_type_saturation_single_copy_returns_one() -> void:
	# 0 copias en mazo → _card_type_count=maxi(0,1)=1 → sat=1.0
	var ctx := _make_ctx(_make_stats())
	var card := GenerateGoldCard.new()
	assert_almost_eq(AIHeuristic._type_saturation(card, ctx), 1.0, 0.01)


func test_type_saturation_two_copies() -> void:
	# 2 copias → sat=1/2=0.5
	var stats := _make_stats()
	for _i in 2:
		stats.draw_pile.add_card(GenerateGoldCard.new())
	var ctx := _make_ctx(stats)
	var card := GenerateGoldCard.new()
	assert_almost_eq(AIHeuristic._type_saturation(card, ctx), 0.5, 0.01)


func test_type_saturation_four_copies_hits_minimum() -> void:
	# 4 copias → 1/4=0.25 (exactamente el mínimo)
	var stats := _make_stats()
	for _i in 4:
		stats.draw_pile.add_card(GenerateGoldCard.new())
	var ctx := _make_ctx(stats)
	var card := GenerateGoldCard.new()
	assert_almost_eq(AIHeuristic._type_saturation(card, ctx), 0.25, 0.01)


func test_type_saturation_five_copies_clamped_to_minimum() -> void:
	# 5 copias → 1/5=0.2 → clamped a 0.25
	var stats := _make_stats()
	for _i in 5:
		stats.draw_pile.add_card(GenerateGoldCard.new())
	var ctx := _make_ctx(stats)
	var card := GenerateGoldCard.new()
	assert_almost_eq(AIHeuristic._type_saturation(card, ctx), 0.25, 0.01,
		"5 copias: saturación mínima debe ser 0.25 (no 0.2)")


# ============================================================
#  _deck_thinning_value
# ============================================================

func test_deck_thinning_value_small_deck() -> void:
	# size=5 → ratio=0 → lerpf(2,9,0)=2.0
	var ctx := _make_ctx_with_deck_size(5)
	assert_almost_eq(AIHeuristic._deck_thinning_value(ctx), 2.0, 0.01)


func test_deck_thinning_value_large_deck() -> void:
	# size=20 → ratio=1.0 → lerpf(2,9,1)=9.0
	var ctx := _make_ctx_with_deck_size(20)
	assert_almost_eq(AIHeuristic._deck_thinning_value(ctx), 9.0, 0.01)


func test_deck_thinning_value_medium_deck_between_bounds() -> void:
	# size=12 → ratio=7/15≈0.467 → lerpf(2,9,0.467)≈5.27
	var ctx := _make_ctx_with_deck_size(12)
	var val := AIHeuristic._deck_thinning_value(ctx)
	assert_true(val > 2.0 and val < 9.0,
		"Mazo mediano (12) debe dar valor entre 2.0 y 9.0")


# ============================================================
#  dynamic_purge_threshold
# ============================================================

func test_purge_threshold_small_deck() -> void:
	# size=5 → ratio=0 → lerpf(3,10,0)=3.0
	var ctx := _make_ctx_with_deck_size(5)
	assert_almost_eq(AIHeuristic.dynamic_purge_threshold(ctx), 3.0, 0.01)


func test_purge_threshold_large_deck() -> void:
	# size=20 → ratio=1.0 → lerpf(3,10,1)=10.0
	var ctx := _make_ctx_with_deck_size(20)
	assert_almost_eq(AIHeuristic.dynamic_purge_threshold(ctx), 10.0, 0.01)


# ============================================================
#  _resource_surplus_factor
# ============================================================

func test_surplus_factor_blocked_by_low_food() -> void:
	# food=3 < 5 → guard → 1.0 aunque gpt sea muy alto
	var stats := _make_stats(500, 3)
	var ctx := _make_ctx(stats)
	assert_almost_eq(
		AIHeuristic._resource_surplus_factor(ctx, AIGamePhase.Phase.MID), 1.0, 0.01)


func test_surplus_factor_at_comfortable_threshold_returns_one() -> void:
	# MID comfortable_gpt=200; food=10, gpt=200 → gpt<=200 → 1.0
	var stats := _make_stats(200, 10)
	var ctx := _make_ctx(stats)
	assert_almost_eq(
		AIHeuristic._resource_surplus_factor(ctx, AIGamePhase.Phase.MID), 1.0, 0.01)


func test_surplus_factor_double_threshold_returns_max() -> void:
	# MID comfortable_gpt=200; gpt=400 (×2) → lerpf(1,3,1.0)=3.0
	var stats := _make_stats(400, 10)
	var ctx := _make_ctx(stats)
	assert_almost_eq(
		AIHeuristic._resource_surplus_factor(ctx, AIGamePhase.Phase.MID), 3.0, 0.01)


func test_surplus_factor_half_above_threshold() -> void:
	# MID comfortable_gpt=200; gpt=300 → (300-200)/200=0.5 → lerpf(1,3,0.5)=2.0
	var stats := _make_stats(300, 10)
	var ctx := _make_ctx(stats)
	assert_almost_eq(
		AIHeuristic._resource_surplus_factor(ctx, AIGamePhase.Phase.MID), 2.0, 0.01)


# ============================================================
#  _expansion_factor
# ============================================================

func test_expansion_factor_unknown_returns_neutral() -> void:
	var ctx := _make_ctx(_make_stats())
	ctx.colonizable_tiles_count = -1
	assert_almost_eq(AIHeuristic._expansion_factor(ctx), 0.5, 0.01)


func test_expansion_factor_zero_tiles_returns_zero() -> void:
	var ctx := _make_ctx(_make_stats())
	ctx.colonizable_tiles_count = 0
	assert_almost_eq(AIHeuristic._expansion_factor(ctx), 0.0, 0.01)


func test_expansion_factor_half_reference() -> void:
	# avail=7, REFERENCE=15 → 7/15≈0.467
	var ctx := _make_ctx(_make_stats())
	ctx.colonizable_tiles_count = 7
	assert_almost_eq(AIHeuristic._expansion_factor(ctx), 7.0 / 15.0, 0.01)


func test_expansion_factor_at_reference_returns_one() -> void:
	var ctx := _make_ctx(_make_stats())
	ctx.colonizable_tiles_count = 15
	assert_almost_eq(AIHeuristic._expansion_factor(ctx), 1.0, 0.01)


func test_expansion_factor_above_reference_capped_at_one() -> void:
	# avail=30 → min(30/15,1.0)=1.0
	var ctx := _make_ctx(_make_stats())
	ctx.colonizable_tiles_count = 30
	assert_almost_eq(AIHeuristic._expansion_factor(ctx), 1.0, 0.01)


# ============================================================
#  _buildable_slots
# ============================================================

func test_buildable_slots_empty_empire() -> void:
	var ctx := _make_ctx(_make_stats())
	assert_eq(AIHeuristic._buildable_slots(ctx), 0)


func test_buildable_slots_tile_with_free_slots() -> void:
	var stats := _make_stats()
	var ctx := _make_ctx(stats)
	var t := _make_tile(stats.empire)
	autofree(t)
	t.max_buildings = 2
	t.buildings = []
	stats.empire.controlled_tiles = [t]
	assert_eq(AIHeuristic._buildable_slots(ctx), 2)


func test_buildable_slots_full_tile() -> void:
	var stats := _make_stats()
	var ctx := _make_ctx(stats)
	var t := _make_tile(stats.empire)
	autofree(t)
	t.max_buildings = 2
	t.buildings = [_make_building(), _make_building()]
	stats.empire.controlled_tiles = [t]
	assert_eq(AIHeuristic._buildable_slots(ctx), 0)


func test_buildable_slots_mixed_tiles() -> void:
	var stats := _make_stats()
	var ctx := _make_ctx(stats)
	var t1 := _make_tile(stats.empire)
	autofree(t1)
	t1.max_buildings = 2
	t1.buildings = []
	var t2 := _make_tile(stats.empire)
	autofree(t2)
	t2.max_buildings = 2
	t2.buildings = [_make_building(), _make_building()]
	stats.empire.controlled_tiles = [t1, t2]
	assert_eq(AIHeuristic._buildable_slots(ctx), 2)


# ============================================================
#  _upgradeable_buildings
# ============================================================

func test_upgradeable_buildings_none() -> void:
	var stats := _make_stats()
	var ctx := _make_ctx(stats)
	var t := _make_tile(stats.empire)
	autofree(t)
	var b := _make_building()
	b.upgrades_to = []
	t.buildings = [b]
	stats.empire.controlled_tiles = [t]
	assert_eq(AIHeuristic._upgradeable_buildings(ctx), 0)


func test_upgradeable_buildings_one() -> void:
	var stats := _make_stats()
	var ctx := _make_ctx(stats)
	var t := _make_tile(stats.empire)
	autofree(t)
	var b := _make_building()
	b.upgrades_to = [_make_building()]
	t.buildings = [b]
	stats.empire.controlled_tiles = [t]
	assert_eq(AIHeuristic._upgradeable_buildings(ctx), 1)


func test_upgradeable_buildings_counts_across_tiles() -> void:
	var stats := _make_stats()
	var ctx := _make_ctx(stats)
	for _i in 2:
		var t := _make_tile(stats.empire)
		autofree(t)
		var b := _make_building()
		b.upgrades_to = [_make_building()]
		t.buildings = [b]
		t.max_buildings = 2
		stats.empire.controlled_tiles.append(t)
	assert_eq(AIHeuristic._upgradeable_buildings(ctx), 2)


# ============================================================
#  _building_demolished_by
# ============================================================

func test_building_demolished_by_empty_allowed_never_demolished() -> void:
	var b := _make_building()
	b.allowed_location_type = []
	var new_loc := _make_location(Tile.location_type.Town)
	assert_false(AIHeuristic._building_demolished_by(b, new_loc),
		"Edificio sin restricciones no debe demolerse")


func test_building_demolished_by_matching_location_survives() -> void:
	var b := _make_building()
	var village := _make_location(Tile.location_type.Village)
	b.allowed_location_type = [village]
	assert_false(AIHeuristic._building_demolished_by(b, village),
		"Edificio permitido en Village debe sobrevivir si la nueva loc es Village")


func test_building_demolished_by_mismatch_returns_true() -> void:
	var b := _make_building()
	var village := _make_location(Tile.location_type.Village)
	b.allowed_location_type = [village]
	var town := _make_location(Tile.location_type.Town)
	assert_true(AIHeuristic._building_demolished_by(b, town),
		"Edificio permitido solo en Village debe demolerse al asignar Town")


# ============================================================
#  _build_cost_factor
# ============================================================

func test_build_cost_factor_zero_gold_returns_minimum() -> void:
	# total_gold=0 → 0.6
	assert_almost_eq(AIHeuristic._build_cost_factor(50, 0), 0.6, 0.01)


func test_build_cost_factor_full_spend_returns_minimum() -> void:
	# cost=total_gold → spend_ratio=1.0 → lerpf(1.0,0.6,1.0)=0.6
	assert_almost_eq(AIHeuristic._build_cost_factor(100, 100), 0.6, 0.01)


func test_build_cost_factor_half_spend() -> void:
	# cost/total=0.5 → lerpf(1.0,0.6,0.5)=0.8
	assert_almost_eq(AIHeuristic._build_cost_factor(50, 100), 0.8, 0.01)


func test_build_cost_factor_residual_spend_near_one() -> void:
	# cost=1, total=10000 → ratio≈0 → factor≈1.0
	var f := AIHeuristic._build_cost_factor(1, 10000)
	assert_true(f > 0.99, "Gasto residual debe dar factor cercano a 1.0")


# ============================================================
#  _score_recruit: null, vetoes, normal
# ============================================================

func test_score_recruit_null_troop_returns_zero() -> void:
	BattleFront.clear_active_instances()
	var ctx := _make_ctx(_make_stats())
	var opt := _make_recruit_option(null)
	assert_almost_eq(AIHeuristic.score_option(opt, ctx), 0.0, 0.01)
	BattleFront.clear_active_instances()


func test_score_recruit_food_veto_returns_negative_ten() -> void:
	# food=0, maintenance_food=6 → 0-6=-6 < -5 → -10.0
	BattleFront.clear_active_instances()
	var stats := _make_stats(200, 0)
	var ctx := _make_ctx(stats)
	var troop := _make_troop(5, 5, 6, 0)
	var opt := _make_recruit_option(troop)
	assert_almost_eq(AIHeuristic.score_option(opt, ctx), -10.0, 0.01)
	BattleFront.clear_active_instances()


func test_score_recruit_gpt_veto_returns_negative_ten() -> void:
	# gpt=10, maintenance_gold=20 → 10-20=-10 < 0 → -10.0
	BattleFront.clear_active_instances()
	var stats := _make_stats(10, 10)
	var ctx := _make_ctx(stats)
	var troop := _make_troop(5, 5, 0, 20)
	var opt := _make_recruit_option(troop)
	assert_almost_eq(AIHeuristic.score_option(opt, ctx), -10.0, 0.01)
	BattleFront.clear_active_instances()


func test_score_recruit_normal_returns_positive() -> void:
	BattleFront.clear_active_instances()
	var stats := _make_stats(200, 10)
	var ctx := _make_ctx(stats)
	var troop := _make_troop(4, 4, 0, 0)
	var opt := _make_recruit_option(troop)
	assert_true(AIHeuristic.score_option(opt, ctx) > 0.0,
		"Tropa válida sin vetoes debe puntuar positivo")
	BattleFront.clear_active_instances()


# ============================================================
#  _complement_bonus
# ============================================================

func test_complement_bonus_empty_pool_returns_one() -> void:
	var pool: Array[Troop] = []
	assert_almost_eq(AIHeuristic._complement_bonus(_make_troop(3, 3), pool), 1.0, 0.01)


func test_complement_bonus_offensive_pool_favors_defensive_troop() -> void:
	# pool: total_atk=40, total_def=0 → pool_ratio=40 > 2.0
	# troop: atk=0, def=10 → troop_ratio=0 < 0.8 → 2.0
	var pool: Array[Troop] = []
	for _i in 4:
		pool.append(_make_troop(10, 0))
	assert_almost_eq(
		AIHeuristic._complement_bonus(_make_troop(0, 10), pool), 2.0, 0.01)


func test_complement_bonus_balanced_pool_returns_one() -> void:
	# pool_ratio=1.0, troop_ratio=1.0 → 1.0
	var pool: Array[Troop] = []
	for _i in 2:
		pool.append(_make_troop(5, 5))
	assert_almost_eq(
		AIHeuristic._complement_bonus(_make_troop(5, 5), pool), 1.0, 0.01)


func test_complement_bonus_moderately_offensive_pool() -> void:
	# pool: total_atk=9, total_def=5 → ratio=1.8 (>1.5 pero ≤2.0)
	# La condición pool_ratio>2.0 falla, pero pool_ratio>1.5 AND troop_ratio<1.0 → 1.5
	# troop: atk=3, def=5 → ratio=0.6 < 1.0
	var pool: Array[Troop] = [_make_troop(9, 5)]
	assert_almost_eq(
		AIHeuristic._complement_bonus(_make_troop(3, 5), pool), 1.5, 0.01)


# ============================================================
#  _score_open_front
# ============================================================

func test_score_open_front_zero_troops_returns_zero() -> void:
	BattleFront.clear_active_instances()
	var stats := _make_stats(300, 15, 2000)
	stats.troop_pool = []
	var empire := stats.empire
	var enemy_emp := Empire.new()
	enemy_emp.name = "Enemy"
	var own := _make_tile(empire)
	add_child_autofree(own)
	var enemy := _make_tile(enemy_emp)
	add_child_autofree(enemy)
	own.neighbors = [enemy]
	enemy.neighbors = [own]
	empire.controlled_tiles = [own]
	var ctx := _make_ctx(stats)
	var bfm := BattleFrontManager.new()
	bfm.stats = stats
	add_child_autofree(bfm)
	ctx.battle_front_manager = bfm
	var card := OpenFrontCard.new()
	card.id = "open"
	card.target = Card.Target.TILE
	var opt := AIOpenFrontOption.from_card(card, enemy, own, bfm)
	assert_almost_eq(AIHeuristic.score_option(opt, ctx), 0.0, 0.01)
	BattleFront.clear_active_instances()


func test_score_open_front_bad_economy_lower_than_good() -> void:
	# gpt=-5 → econ_safety=0.15 → score muy bajo vs economía sana
	BattleFront.clear_active_instances()

	# Contexto con economía mala
	var stats_bad := _make_stats(-5, 15, 2000)
	for _i in 6:
		stats_bad.troop_pool.append(_make_troop())
	var own_b := _make_tile(stats_bad.empire)
	add_child_autofree(own_b)
	var enemy_b := _make_tile(Empire.new())
	add_child_autofree(enemy_b)
	own_b.neighbors = [enemy_b]
	enemy_b.neighbors = [own_b]
	stats_bad.empire.controlled_tiles = [own_b]
	var ctx_bad := _make_ctx(stats_bad)
	var bfm_bad := BattleFrontManager.new()
	bfm_bad.stats = stats_bad
	add_child_autofree(bfm_bad)
	ctx_bad.battle_front_manager = bfm_bad

	# Contexto con economía buena (misma topología)
	var stats_good := _make_stats(300, 15, 2000)
	for _i in 6:
		stats_good.troop_pool.append(_make_troop())
	var own_g := _make_tile(stats_good.empire)
	add_child_autofree(own_g)
	var enemy_g := _make_tile(Empire.new())
	add_child_autofree(enemy_g)
	own_g.neighbors = [enemy_g]
	enemy_g.neighbors = [own_g]
	stats_good.empire.controlled_tiles = [own_g]
	var ctx_good := _make_ctx(stats_good)
	var bfm_good := BattleFrontManager.new()
	bfm_good.stats = stats_good
	add_child_autofree(bfm_good)
	ctx_good.battle_front_manager = bfm_good

	var card := OpenFrontCard.new()
	card.id = "open"
	card.target = Card.Target.TILE
	var opt_bad  := AIOpenFrontOption.from_card(card, enemy_b, own_b, bfm_bad)
	var opt_good := AIOpenFrontOption.from_card(card, enemy_g, own_g, bfm_good)

	var score_bad  := AIHeuristic.score_option(opt_bad, ctx_bad)
	var score_good := AIHeuristic.score_option(opt_good, ctx_good)
	assert_true(score_good > score_bad,
		"Economía positiva debe dar score mayor al abrir frente (econ_safety 0.15 vs 1.0)")
	BattleFront.clear_active_instances()


# ============================================================
#  _score_tactic
# ============================================================

func test_score_tactic_null_front_returns_zero() -> void:
	BattleFront.clear_active_instances()
	var ctx := _make_ctx(_make_stats())
	var card := TacticCard.new()
	card.id = "tactic"
	card.target = Card.Target.TILE
	var opt := AITacticOption.from_card(card, null)
	opt.front = null
	assert_almost_eq(AIHeuristic.score_option(opt, ctx), 0.0, 0.01)
	BattleFront.clear_active_instances()


func _make_tactic_context() -> Array:
	# Returns [ctx, card, atk_tile, def_tile] — limpia instancias antes de crear el frente
	BattleFront.clear_active_instances()
	var stats := _make_stats(200, 10)
	var empire := stats.empire
	var enemy_emp := Empire.new()
	enemy_emp.name = "Enemy"
	var atk_tile := _make_tile(empire)
	var def_tile := _make_tile(enemy_emp)
	empire.controlled_tiles = [atk_tile]
	var ctx := _make_ctx(stats)
	var card := TacticCard.new()
	card.id = "tactic"
	card.target = Card.Target.TILE
	return [ctx, card, atk_tile, def_tile]


func test_score_tactic_losing_scores_higher_than_winning() -> void:
	var parts := _make_tactic_context()
	var ctx: AITurnContext = parts[0]
	var card: TacticCard  = parts[1]
	var atk: Tile         = parts[2]
	var def_t: Tile       = parts[3]
	add_child_autofree(atk)
	add_child_autofree(def_t)

	# Frente ganando: marker=+5 (ventaja atacante) → urgency=0
	var front_win := BattleFront.new(atk, def_t, ctx.stats.empire, def_t.controller)
	front_win.marker = 5.0
	var score_win := AIHeuristic.score_option(AITacticOption.from_card(card, front_win), ctx)
	BattleFront.clear_active_instances()

	# Frente perdiendo: marker=-15 (ventaja máxima defensor) → urgency=1
	var front_lose := BattleFront.new(atk, def_t, ctx.stats.empire, def_t.controller)
	front_lose.marker = -15.0
	var score_lose := AIHeuristic.score_option(AITacticOption.from_card(card, front_lose), ctx)

	assert_true(score_lose > score_win,
		"Frente perdiendo debe requerir más urgencia táctica que frente ganando")
	BattleFront.clear_active_instances()


func test_score_tactic_winning_front_expected_value() -> void:
	# marker=0 → urgency=0 → (12+0)*mu; has_active_front=true → mu=1.5
	# score = 12 * 1.5 = 18.0
	var parts := _make_tactic_context()
	var ctx: AITurnContext = parts[0]
	var card: TacticCard  = parts[1]
	var atk: Tile         = parts[2]
	var def_t: Tile       = parts[3]
	add_child_autofree(atk)
	add_child_autofree(def_t)

	var front := BattleFront.new(atk, def_t, ctx.stats.empire, def_t.controller)
	front.marker = 0.0
	var score := AIHeuristic.score_option(AITacticOption.from_card(card, front), ctx)
	assert_almost_eq(score, 18.0, 0.1,
		"marker=0, urgency=0 → (12+0)*1.5=18.0")
	BattleFront.clear_active_instances()


# ============================================================
#  _score_change_location
# ============================================================

func _make_change_loc_option(tile: Tile, new_loc: LocationType) -> AIPlayOption:
	var card := ChangeLocationTypeCard.new()
	card.id = "urbanize"
	card.target = Card.Target.TILE
	card.location_type = new_loc
	return AIPlayOption.simple(card, [tile])


func test_score_change_location_food_veto_returns_negative() -> void:
	# food=3, delta_consumption=5 → new_food=-2 < 0 → -20.0
	BattleFront.clear_active_instances()
	var stats := _make_stats(100, 3)
	var ctx := _make_ctx(stats)
	var tile := _make_tile(stats.empire)
	autofree(tile)
	tile.location = _make_location(Tile.location_type.Village, 0, 1)
	var new_loc := _make_location(Tile.location_type.Town, 5, 3)
	assert_almost_eq(AIHeuristic.score_option(_make_change_loc_option(tile, new_loc), ctx),
		-20.0, 0.01)
	BattleFront.clear_active_instances()


func test_score_change_location_demolition_reduces_score() -> void:
	BattleFront.clear_active_instances()
	var stats := _make_stats(100, 15, 500)
	var ctx := _make_ctx(stats)
	var old_loc := _make_location(Tile.location_type.Village, 0, 1)
	var new_loc := _make_location(Tile.location_type.Town, 2, 3)

	# Tile limpia (sin edificios que demoler)
	var tile_clean := _make_tile(stats.empire)
	autofree(tile_clean)
	tile_clean.location = old_loc
	var score_clean := AIHeuristic.score_option(
		_make_change_loc_option(tile_clean, new_loc), ctx)

	# Tile con edificio gold=5 que solo existe en Village → demolido al pasar a Town
	var tile_demo := _make_tile(stats.empire)
	autofree(tile_demo)
	tile_demo.location = old_loc
	var doomed := _make_building(5, 0, 0, 50)
	doomed.allowed_location_type = [_make_location(Tile.location_type.Village)]
	tile_demo.buildings = [doomed]
	var score_demo := AIHeuristic.score_option(
		_make_change_loc_option(tile_demo, new_loc), ctx)

	assert_true(score_demo < score_clean,
		"Demolición de edificio rentable debe reducir el score de cambio de ubicación")
	BattleFront.clear_active_instances()


func test_score_change_location_positive_when_viable() -> void:
	BattleFront.clear_active_instances()
	var stats := _make_stats(100, 15)
	var ctx := _make_ctx(stats)
	var tile := _make_tile(stats.empire)
	autofree(tile)
	tile.location = _make_location(Tile.location_type.Village, 0, 1)
	var new_loc := _make_location(Tile.location_type.Town, 2, 3)
	var score := AIHeuristic.score_option(_make_change_loc_option(tile, new_loc), ctx)
	assert_true(score > 0.0, "Urbanización sin demolición ni veto debe puntuar positivo")
	BattleFront.clear_active_instances()


func test_score_change_location_resource_bonus_increases_score() -> void:
	# Edificio de recurso mejorado que sobrevive → resource_bonus=+8.0
	BattleFront.clear_active_instances()
	var stats := _make_stats(100, 15, 500)
	var ctx := _make_ctx(stats)
	var old_loc := _make_location(Tile.location_type.Village, 0, 1)
	var new_loc := _make_location(Tile.location_type.Town, 1, 3)

	# Tile sin edificio de recurso
	var tile_base := _make_tile(stats.empire)
	autofree(tile_base)
	tile_base.location = old_loc
	var score_base := AIHeuristic.score_option(
		_make_change_loc_option(tile_base, new_loc), ctx)

	# Tile con edificio de recurso mejorado que sobrevive al upgrade
	var tile_bonus := _make_tile(stats.empire)
	autofree(tile_bonus)
	tile_bonus.location = old_loc

	var base_b := _make_building(0, 0, 0, 50)
	base_b.required_natural_resource = tile_bonus.natural_resource
	base_b.allowed_location_type = []

	var upgraded_b := _make_building(2, 0, 0, 100)
	upgraded_b.required_natural_resource = tile_bonus.natural_resource
	upgraded_b.allowed_location_type = []  # sobrevive en cualquier location
	base_b.upgrades_to = [upgraded_b]

	tile_bonus.buildings = [upgraded_b]
	stats.possible_buildings = [base_b]

	var score_bonus := AIHeuristic.score_option(
		_make_change_loc_option(tile_bonus, new_loc), ctx)

	assert_true(score_bonus > score_base,
		"Edificio de recurso mejorado que sobrevive debe dar bonus +8.0 al score")
	BattleFront.clear_active_instances()


# ============================================================
#  score_card_for_deck: todos los tipos principales
# ============================================================

func test_score_card_colonize_no_tiles_returns_low() -> void:
	# avail=0 → 0.5*sat (sat=1.0 con mazo vacío) → 0.5
	var ctx := _make_ctx(_make_stats())
	ctx.colonizable_tiles_count = 0
	var card := ColonizeCard.new()
	assert_almost_eq(AIHeuristic.score_card_for_deck(card, ctx), 0.5, 0.01)


func test_score_card_colonize_full_expansion_returns_max() -> void:
	# avail=15 → lerpf(8,15,1.0)*1.0 = 15.0
	var ctx := _make_ctx(_make_stats())
	ctx.colonizable_tiles_count = 15
	var card := ColonizeCard.new()
	assert_almost_eq(AIHeuristic.score_card_for_deck(card, ctx), 15.0, 0.01)


func test_score_card_upgrade_no_upgradeable_returns_low() -> void:
	# upgrades=0 → 2.0*sat = 2.0
	var ctx := _make_ctx(_make_stats())
	var card := UpgradeBuildingCard.new()
	card.id = "upgrade"
	assert_almost_eq(AIHeuristic.score_card_for_deck(card, ctx), 2.0, 0.01)


func test_score_card_upgrade_five_upgradeable_returns_max() -> void:
	# 5 upgradeable → lerpf(5,18,1.0)*1.0 = 18.0
	var stats := _make_stats()
	for _i in 5:
		var t := _make_tile(stats.empire)
		autofree(t)
		var b := _make_building()
		b.upgrades_to = [_make_building()]
		t.buildings = [b]
		t.max_buildings = 2
		stats.empire.controlled_tiles.append(t)
	var ctx := _make_ctx(stats)
	var card := UpgradeBuildingCard.new()
	card.id = "upgrade"
	assert_almost_eq(AIHeuristic.score_card_for_deck(card, ctx), 18.0, 0.01)


func test_score_card_build_no_slots_returns_low() -> void:
	# slots=0 → 1.0*sat = 1.0
	var ctx := _make_ctx(_make_stats())
	var card := BuildCard.new()
	card.id = "build"
	card.target = Card.Target.TILE
	card.buildings = []
	assert_almost_eq(AIHeuristic.score_card_for_deck(card, ctx), 1.0, 0.01)


func test_score_card_build_ten_slots_returns_max() -> void:
	# 10 slots → lerpf(5,20,1.0)*1.0 = 20.0
	var stats := _make_stats()
	for _i in 5:
		var t := _make_tile(stats.empire)
		autofree(t)
		t.max_buildings = 2
		t.buildings = []
		stats.empire.controlled_tiles.append(t)
	var ctx := _make_ctx(stats)
	var card := BuildCard.new()
	card.id = "build"
	card.target = Card.Target.TILE
	card.buildings = []
	assert_almost_eq(AIHeuristic.score_card_for_deck(card, ctx), 20.0, 0.01)


func test_score_card_carddraw_larger_deck_scores_higher() -> void:
	var ctx_small := _make_ctx_with_deck_size(5)
	var ctx_large := _make_ctx_with_deck_size(20)
	var card := CardDrawCard.new()
	card.id = "draw"
	card.amount = 1
	assert_true(
		AIHeuristic.score_card_for_deck(card, ctx_large) > AIHeuristic.score_card_for_deck(card, ctx_small),
		"CardDrawCard vale más con mazo grande")


func test_score_card_recover_empty_deck_returns_minimum() -> void:
	# Sin cartas → best_score=0 → clamp(0*0.6,4,12)*sat=4.0
	var ctx := _make_ctx(_make_stats())
	var card := RecoverCard.new()
	card.id = "recover"
	assert_almost_eq(AIHeuristic.score_card_for_deck(card, ctx), 4.0, 0.01)


func test_score_card_generate_gold_scales_with_amount() -> void:
	# GenerateGoldCard(10) debe valer el doble que GenerateGoldCard(5)
	var ctx := _make_ctx(_make_stats())
	ctx.colonizable_tiles_count = -1
	var card5 := GenerateGoldCard.new()
	card5.amount = 5
	var card10 := GenerateGoldCard.new()
	card10.amount = 10
	var s5  := AIHeuristic.score_card_for_deck(card5, ctx)
	var s10 := AIHeuristic.score_card_for_deck(card10, ctx)
	assert_almost_eq(s10 / s5, 2.0, 0.05,
		"GenerateGoldCard(10) debe valer el doble que GenerateGoldCard(5)")


func test_score_card_unknown_type_returns_neutral() -> void:
	# Card base (sin subclase) → 5.0*sat = 5.0
	var ctx := _make_ctx(_make_stats())
	var card := Card.new()
	assert_almost_eq(AIHeuristic.score_card_for_deck(card, ctx), 5.0, 0.01)


# ============================================================
#  pick_card_to_remove
# ============================================================

func test_pick_card_to_remove_empty_returns_null() -> void:
	var ctx := _make_ctx(_make_stats())
	var result := AIHeuristic.pick_card_to_remove([], ctx)
	assert_null(result)


func test_pick_card_to_remove_protects_last_colonize_when_tiles_available() -> void:
	# [ColonizeCard, GenerateGoldCard(5)] con avail=5 → colonize protegida → elimina GenerateGoldCard
	var ctx := _make_ctx(_make_stats(100, 10, 500))
	ctx.colonizable_tiles_count = 5
	var colonize := ColonizeCard.new()
	colonize.id = "colonize"
	var gold_card := GenerateGoldCard.new()
	gold_card.id = "gold"
	gold_card.amount = 5
	var candidates: Array[Card] = [colonize, gold_card]
	var result := AIHeuristic.pick_card_to_remove(candidates, ctx)
	assert_true(result is GenerateGoldCard,
		"La última ColonizeCard está protegida cuando hay tiles colonizables")


func test_pick_card_to_remove_no_protection_when_no_tiles() -> void:
	# avail=0 → ColonizeCard no protegida; score=0.5 vs ~3.0 → elimina ColonizeCard
	var ctx := _make_ctx(_make_stats(100, 10, 500))
	ctx.colonizable_tiles_count = 0
	var colonize := ColonizeCard.new()
	colonize.id = "colonize"
	var gold_card := GenerateGoldCard.new()
	gold_card.id = "gold"
	gold_card.amount = 5
	var candidates: Array[Card] = [colonize, gold_card]
	var result := AIHeuristic.pick_card_to_remove(candidates, ctx)
	assert_true(result is ColonizeCard,
		"Sin tiles colonizables, ColonizeCard es la peor y debe eliminarse")


func test_pick_card_to_remove_two_colonize_no_protection() -> void:
	# colonize_count=2 → protect_colonize=(avail!=0 AND count<=1)=false → elige una
	var ctx := _make_ctx(_make_stats())
	ctx.colonizable_tiles_count = 5
	var c1 := ColonizeCard.new()
	c1.id = "colonize"
	var c2 := ColonizeCard.new()
	c2.id = "colonize"
	var candidates: Array[Card] = [c1, c2]
	var result := AIHeuristic.pick_card_to_remove(candidates, ctx)
	assert_not_null(result,
		"Con dos ColonizeCards y avail>0, debe elegir una (no null)")


# ============================================================
#  score_choice
# ============================================================

func test_score_choice_null_returns_zero() -> void:
	assert_almost_eq(
		AIHeuristic.score_choice(null, _make_ctx(_make_stats())), 0.0, 0.01)


func test_score_choice_gold_effect() -> void:
	# GoldEventEffect(100), gpt=100 MID → gu=2.0 → 100*0.4*2.0=80.0
	var ctx := _make_ctx(_make_stats(100, 10))
	assert_almost_eq(
		AIHeuristic.score_choice(_make_choice([GoldEventEffect.new(100)]), ctx), 80.0, 0.01)


func test_score_choice_food_effect() -> void:
	# FoodEventEffect(5), food=10 MID → fu=1.0 → 5*0.5*1.0=2.5
	var ctx := _make_ctx(_make_stats(100, 10))
	assert_almost_eq(
		AIHeuristic.score_choice(_make_choice([FoodEventEffect.new(5)]), ctx), 2.5, 0.01)


func test_score_choice_add_card_effect() -> void:
	# AddCardEffect(GenerateGoldCard(5)) → score_card_for_deck = 5*0.3*2.0=3.0
	var ctx := _make_ctx(_make_stats(100, 10))
	var gold_card := GenerateGoldCard.new()
	gold_card.amount = 5
	assert_almost_eq(
		AIHeuristic.score_choice(_make_choice([AddCardEffect.new(gold_card)]), ctx), 3.0, 0.01)


func test_score_choice_remove_card_effect() -> void:
	# RemoveCardEventEffect, mazo vacío → _deck_thinning_value=2.0
	var ctx := _make_ctx(_make_stats())
	assert_almost_eq(
		AIHeuristic.score_choice(_make_choice([RemoveCardEventEffect.new()]), ctx), 2.0, 0.01)


func test_score_choice_add_random_pool_card() -> void:
	# AddRandomPoolCardEffect → score=8.0 (valor estimado fijo)
	var ctx := _make_ctx(_make_stats())
	assert_almost_eq(
		AIHeuristic.score_choice(_make_choice([AddRandomPoolCardEffect.new()]), ctx), 8.0, 0.01)


func test_score_choice_cost_penalizes_by_two() -> void:
	# Sin efectos + coste no nulo → score = 0 - 2.0 = -2.0
	var ctx := _make_ctx(_make_stats())
	var choice := TurnEventChoice.new()
	choice.effects = []
	choice.cost = TurnEventCost.new()
	assert_almost_eq(AIHeuristic.score_choice(choice, ctx), -2.0, 0.01)


func test_score_choice_multiple_effects_stack() -> void:
	# GoldEventEffect(100) + FoodEventEffect(5) = 80.0 + 2.5 = 82.5
	var ctx := _make_ctx(_make_stats(100, 10))
	var choice := _make_choice([GoldEventEffect.new(100), FoodEventEffect.new(5)])
	assert_almost_eq(AIHeuristic.score_choice(choice, ctx), 82.5, 0.01)


# ============================================================
#  should_buy_shop_item
# ============================================================

func test_should_buy_null_item_returns_false() -> void:
	assert_false(AIHeuristic.should_buy_shop_item(null, _make_ctx(_make_stats())))


func test_should_buy_null_card_returns_false() -> void:
	var item := ShopItem.new()
	item.card = null
	assert_false(AIHeuristic.should_buy_shop_item(item, _make_ctx(_make_stats())))


func test_should_buy_high_value_with_small_deck_returns_true() -> void:
	# Mazo vacío → threshold=lerpf(5,12,0)=5.0
	# ColonizeCard con avail=15 → score=15.0 ≥ 5.0 → true
	var ctx := _make_ctx(_make_stats())
	ctx.colonizable_tiles_count = 15
	var colonize := ColonizeCard.new()
	colonize.id = "colonize"
	assert_true(AIHeuristic.should_buy_shop_item(_make_shop_item(colonize), ctx),
		"Carta de alto valor debe comprarse con mazo pequeño")


func test_should_buy_low_value_returns_false() -> void:
	# GenerateGoldCard(1) con gpt=100 → score=1*0.3*2.0=0.6 < threshold=5.0 → false
	var ctx := _make_ctx(_make_stats(100))
	var gold_card := GenerateGoldCard.new()
	gold_card.amount = 1
	assert_false(AIHeuristic.should_buy_shop_item(_make_shop_item(gold_card), ctx),
		"Carta de bajo valor no debe comprarse con umbral mínimo de 5.0")
