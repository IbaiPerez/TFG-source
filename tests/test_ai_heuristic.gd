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


# ============================================================
#  Helpers para tests de frontera y encierro
# ============================================================

func _make_colonize_option(tile: Tile) -> AIPlayOption:
	var card := ColonizeCard.new()
	card.id = "colonize"
	card.target = Card.Target.TILE
	return AIPlayOption.simple(card, [tile])


## Crea un contexto con N tiles controladas y M colonizables para
## testear _encirclement_pressure sin necesidad de un mapa real.
func _make_ctx_with_colonizable(n_controlled: int,
		n_colonizable: int) -> AITurnContext:
	var stats := _make_stats()
	for _i in n_controlled:
		var t := _make_tile(stats.empire)
		autofree(t)
		stats.empire.controlled_tiles.append(t)
	var ctx := _make_ctx(stats)
	ctx.colonizable_tiles_count = n_colonizable
	return ctx


# ============================================================
#  _frontier_value: tiles nuevas que abre colonizar una tile
# ============================================================

func test_frontier_value_zero_when_all_neighbors_controlled() -> void:
	# T rodeada de tiles del propio imperio: no abre ninguna ruta nueva.
	var stats := _make_stats()
	var ctx := _make_ctx(stats)
	var empire := stats.empire

	var a := _make_tile(empire)
	autofree(a)
	var b := _make_tile(empire)
	autofree(b)
	var t := _make_tile()  # tile a evaluar, aún no controlada
	autofree(t)

	a.neighbors = [t]
	b.neighbors = [t]
	t.neighbors = [a, b]
	empire.controlled_tiles = [a, b]

	assert_eq(AIHeuristic._frontier_value(t, ctx), 0,
		"Tile rodeada de territorio propio no debe abrir tiles nuevas")


func test_frontier_value_counts_tiles_only_reachable_via_target() -> void:
	# Imperio controla A. T es adyacente a A.
	# B, C, D son libres y solo accesibles vía T (no adyacentes a A).
	var stats := _make_stats()
	var ctx := _make_ctx(stats)
	var empire := stats.empire

	var a := _make_tile(empire)
	autofree(a)
	var t := _make_tile()
	autofree(t)
	var b := _make_tile()
	autofree(b)
	var c := _make_tile()
	autofree(c)
	var d := _make_tile()
	autofree(d)

	a.neighbors = [t]
	t.neighbors = [a, b, c, d]
	b.neighbors = [t]
	c.neighbors = [t]
	d.neighbors = [t]
	empire.controlled_tiles = [a]

	assert_eq(AIHeuristic._frontier_value(t, ctx), 3,
		"B, C y D son solo accesibles colonizando T: debe contar 3")


func test_frontier_value_excludes_tiles_already_reachable() -> void:
	# Imperio controla A y B. T es adyacente a A.
	# C es libre pero también adyacente a B (ya reachable sin T).
	# D es libre y solo accesible vía T.
	# Resultado esperado: 1 (solo D).
	var stats := _make_stats()
	var ctx := _make_ctx(stats)
	var empire := stats.empire

	var a := _make_tile(empire)
	autofree(a)
	var b := _make_tile(empire)
	autofree(b)
	var t := _make_tile()
	autofree(t)
	var c := _make_tile()  # ya accesible vía B
	autofree(c)
	var d := _make_tile()  # solo accesible vía T
	autofree(d)

	a.neighbors = [t, b]
	b.neighbors = [a, c]
	t.neighbors = [a, c, d]
	c.neighbors = [b, t]
	d.neighbors = [t]
	empire.controlled_tiles = [a, b]

	assert_eq(AIHeuristic._frontier_value(t, ctx), 1,
		"Solo D es nueva; C ya es accesible vía B")


func test_frontier_value_ignores_controlled_neighbors() -> void:
	# T tiene un vecino controlado por el imperio y uno libre nuevo.
	# El controlado no cuenta; solo el libre nuevo.
	var stats := _make_stats()
	var ctx := _make_ctx(stats)
	var empire := stats.empire

	var a := _make_tile(empire)
	autofree(a)
	var e2 := _make_tile(empire)  # segundo tile controlado
	autofree(e2)
	var t := _make_tile()
	autofree(t)
	var b := _make_tile()  # libre, solo accesible vía T
	autofree(b)

	a.neighbors = [t]
	e2.neighbors = [t]
	t.neighbors = [a, e2, b]
	b.neighbors = [t]
	empire.controlled_tiles = [a, e2]

	assert_eq(AIHeuristic._frontier_value(t, ctx), 1,
		"Solo B debe contar; E2 es controlado y se ignora")


func test_frontier_value_returns_zero_without_empire() -> void:
	var stats := _make_stats()
	stats.empire = null
	var ctx := _make_ctx(stats)
	var t := _make_tile()
	autofree(t)

	assert_eq(AIHeuristic._frontier_value(t, ctx), 0,
		"Sin empire en el contexto, frontier_value debe devolver 0")


# ============================================================
#  _encirclement_pressure: multiplicador según grado de encierro
# ============================================================

func test_encirclement_pressure_minimum_when_ratio_above_2() -> void:
	# 5 controladas, 15 colonizables → ratio=3.0 ≥ 2.0 → presión 1.5
	var ctx := _make_ctx_with_colonizable(5, 15)
	assert_almost_eq(AIHeuristic._encirclement_pressure(ctx), 1.5, 0.01,
		"Ratio ≥ 2.0 debe dar presión mínima 1.5 (mapa muy abierto)")


func test_encirclement_pressure_medium_when_ratio_between_1_and_2() -> void:
	# 10 controladas, 15 colonizables → ratio=1.5 → presión 2.5
	var ctx := _make_ctx_with_colonizable(10, 15)
	assert_almost_eq(AIHeuristic._encirclement_pressure(ctx), 2.5, 0.01,
		"Ratio entre 1.0 y 2.0 debe dar presión media 2.5")


func test_encirclement_pressure_high_when_ratio_between_half_and_1() -> void:
	# 10 controladas, 7 colonizables → ratio=0.7 → presión 4.0
	var ctx := _make_ctx_with_colonizable(10, 7)
	assert_almost_eq(AIHeuristic._encirclement_pressure(ctx), 4.0, 0.01,
		"Ratio entre 0.5 y 1.0 debe dar presión alta 4.0")


func test_encirclement_pressure_maximum_when_nearly_enclosed() -> void:
	# 10 controladas, 3 colonizables → ratio=0.3 < 0.5 → presión máxima 5.0
	var ctx := _make_ctx_with_colonizable(10, 3)
	assert_almost_eq(AIHeuristic._encirclement_pressure(ctx), 5.0, 0.01,
		"Ratio < 0.5 debe dar presión máxima 5.0 (casi encerrada)")


func test_encirclement_pressure_neutral_when_colonizable_unknown() -> void:
	# colonizable_tiles_count = -1 (tests sin mapa) → valor neutro 1.5
	var stats := _make_stats()
	var ctx := _make_ctx(stats)
	ctx.colonizable_tiles_count = -1

	assert_almost_eq(AIHeuristic._encirclement_pressure(ctx), 1.5, 0.01,
		"Colonizable desconocido (-1) debe devolver valor neutro 1.5")


# ============================================================
#  _score_colonize: integración frontier_bonus
# ============================================================

func test_colonize_frontier_tile_scores_higher_than_gap_tile() -> void:
	# Dos tiles con recursos idénticos. T_frontier abre 3 rutas nuevas;
	# T_gap no abre ninguna (su única vecina libre ya es adyacente al imperio).
	# Con mapa abierto (presión mínima), T_frontier debe puntuar más.
	var stats := _make_stats(100, 10, 500)
	var empire := stats.empire

	var own := _make_tile(empire)
	add_child_autofree(own)
	empire.controlled_tiles = [own]

	# T_frontier: 3 vecinas libres solo accesibles vía ella
	var t_frontier := _make_tile()
	add_child_autofree(t_frontier)
	t_frontier.gold_production = 2
	t_frontier.food_production = 1
	var f1 := _make_tile()
	autofree(f1)
	var f2 := _make_tile()
	autofree(f2)
	var f3 := _make_tile()
	autofree(f3)
	f1.neighbors = [t_frontier]
	f2.neighbors = [t_frontier]
	f3.neighbors = [t_frontier]
	t_frontier.neighbors = [own, f1, f2, f3]

	# T_gap: su única vecina libre (g1) ya es adyacente a own → no abre rutas nuevas
	var t_gap := _make_tile()
	add_child_autofree(t_gap)
	t_gap.gold_production = 2
	t_gap.food_production = 1
	var g1 := _make_tile()
	autofree(g1)
	g1.neighbors = [own, t_gap]  # g1 ya es accesible directamente desde own
	t_gap.neighbors = [own, g1]
	own.neighbors = [t_frontier, t_gap, g1]

	var ctx := _make_ctx(stats)
	ctx.colonizable_tiles_count = 8  # mapa abierto → presión mínima 1.5

	var score_frontier := AIHeuristic.score_option(_make_colonize_option(t_frontier), ctx)
	var score_gap := AIHeuristic.score_option(_make_colonize_option(t_gap), ctx)

	assert_true(score_frontier > score_gap,
		"Tile frontera (abre 3 rutas) debe puntuar más que tile interior (no abre rutas)")


func test_colonize_encirclement_amplifies_frontier_preference() -> void:
	# Misma topología de tiles, dos contextos distintos:
	#   A) mapa abierto → _encirclement_pressure=1.5 → diff pequeña
	#   B) casi encerrada → _encirclement_pressure=5.0 → diff mayor
	# La diferencia de scores (frontier - gap) en B debe superar la de A.
	var stats := _make_stats(100, 10, 500)
	var empire := stats.empire

	var own := _make_tile(empire)
	add_child_autofree(own)
	# 10 tiles adicionales para tener territorio suficiente y que el ratio sea claro
	for _i in 10:
		var dummy := _make_tile(empire)
		autofree(dummy)
		empire.controlled_tiles.append(dummy)
	empire.controlled_tiles.append(own)  # 11 tiles en total

	var t_frontier := _make_tile()
	add_child_autofree(t_frontier)
	t_frontier.gold_production = 2
	t_frontier.food_production = 1
	var f1 := _make_tile()
	autofree(f1)
	var f2 := _make_tile()
	autofree(f2)
	var f3 := _make_tile()
	autofree(f3)
	f1.neighbors = [t_frontier]
	f2.neighbors = [t_frontier]
	f3.neighbors = [t_frontier]
	t_frontier.neighbors = [own, f1, f2, f3]

	var t_gap := _make_tile()
	add_child_autofree(t_gap)
	t_gap.gold_production = 2
	t_gap.food_production = 1
	var g1 := _make_tile()
	autofree(g1)
	g1.neighbors = [own, t_gap]
	t_gap.neighbors = [own, g1]
	own.neighbors = [t_frontier, t_gap, g1]

	# Contexto A: ratio=25/11≈2.3 → presión 1.5
	var ctx_open := _make_ctx(stats)
	ctx_open.colonizable_tiles_count = 25
	var diff_open := AIHeuristic.score_option(_make_colonize_option(t_frontier), ctx_open) \
				  - AIHeuristic.score_option(_make_colonize_option(t_gap), ctx_open)

	# Contexto B: ratio=2/11≈0.18 → presión 5.0
	var ctx_enclosed := _make_ctx(stats)
	ctx_enclosed.colonizable_tiles_count = 2
	var diff_enclosed := AIHeuristic.score_option(_make_colonize_option(t_frontier), ctx_enclosed) \
					  - AIHeuristic.score_option(_make_colonize_option(t_gap), ctx_enclosed)

	assert_true(diff_enclosed > diff_open,
		"El encierro debe amplificar la preferencia por tiles que abren nuevas rutas")
