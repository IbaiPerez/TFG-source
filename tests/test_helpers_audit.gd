extends GutTest

## Audita la propia infraestructura de tests (`tests/helpers/`): builders, fixtures,
## limpieza de estado global y aserciones de dominio.
##
## POR QUÉ EXISTE: esos helpers se crearon en el bloque A3 y hasta ahora
## `TestFixtures`, `TestWorld` y `TestAssertions` no los usaba NADIE, y
## `TestBuilders` solo dos ficheros. Sin llamantes no se ejecutaban, y sin
## ejecutarse no se veía que `TestBuilders.building()` llevaba roto desde que se
## escribió: asignaba un Array sin tipar a `Building.allowed_biomes`
## (`Array[Tile.biome_type]`), que es error EN EJECUCIÓN invisible al parser, y
## dejaba el builder devolviendo null.
##
## La Fase 4 propone migrar ~18 ficheros de test a estos helpers. Construir eso
## sobre infraestructura no ejercitada es cómo se rompen 18 ficheros a la vez, así
## que primero se fija que cada builder produce lo que promete.


# ---------------------------------------------------------------------------
# Builders: cada uno construye de verdad
# ---------------------------------------------------------------------------

func test_empire_se_construye() -> void:
	var e := TestBuilders.empire().with_name("Medici").with_color(Color.BLUE).build()
	assert_not_null(e)
	assert_eq(e.name, "Medici")
	assert_eq(e.color, Color.BLUE)
	assert_eq(e.controlled_tiles.size(), 0)


func test_empire_nace_con_territorio_tipado() -> void:
	# controlled_tiles es Array[Tile]: si el builder le volcase un Array sin tipar,
	# el append de un Tile fallaría en ejecución.
	var e := TestBuilders.empire().build()
	var t := _tile()
	e.controlled_tiles.append(t)
	assert_eq(e.controlled_tiles.size(), 1)


func test_stats_se_construye_con_sus_pilas() -> void:
	var s := TestBuilders.stats().with_gold(250).with_gpt(40).with_food(12) \
		.with_turn(7).build()
	assert_not_null(s)
	assert_eq(s.total_gold, 250)
	assert_eq(s.gold_per_turn, 40)
	assert_eq(s.food, 12)
	assert_eq(s.turn_number, 7)
	assert_not_null(s.draw_pile, "sin pilas, media suite de cartas peta")
	assert_not_null(s.discard_pile)
	assert_not_null(s.played_pile)
	assert_not_null(s.empire, "debe autocrear imperio si no se indica")


func test_los_defaults_del_builder_que_coinciden_con_stats() -> void:
	# De esto depende que migrar un `_make_stats` local sea seguro: los campos que
	# el helper NO fijaba se quedaban en el default de Stats, así que el builder
	# solo puede sustituirlo si coincide.
	var crudo := Stats.new()
	var construido := TestBuilders.stats().build()

	assert_eq(construido.turn_number, crudo.turn_number,
		"turn_number: mismo default, por eso no hace falta fijarlo al migrar")
	assert_eq(construido.event_chance, crudo.event_chance,
		"event_chance: mismo default")


func test_los_defaults_del_builder_que_NO_coinciden_con_stats() -> void:
	# Y estos son los que obligan a fijarlos a mano al migrar, porque el builder
	# elige valores de conveniencia distintos de los de Stats.
	var crudo := Stats.new()
	var construido := TestBuilders.stats().build()

	assert_ne(construido.gold_per_turn, crudo.gold_per_turn, "gpt: 50 vs 0")
	assert_ne(construido.food, crudo.food, "food: 10 vs 0")
	assert_ne(construido.cards_per_turn, crudo.cards_per_turn, "cards_per_turn: 3 vs 0")


func test_cards_per_turn_no_puede_bajar_de_uno() -> void:
	# El setter de Stats clampa a [1,20], así que el builder NO puede reproducir un
	# `cards_per_turn` de 0. Es el motivo de que los tests que lo dejan sin fijar no
	# se puedan migrar sin cambiar comportamiento.
	var s := TestBuilders.stats().with_cards_per_turn(0).build()
	assert_eq(s.cards_per_turn, 1, "el setter sube el 0 a 1")


func test_stats_enlaza_las_casillas_con_su_imperio() -> void:
	var a := _tile()
	var b := _tile()
	var s := TestBuilders.stats().with_tiles([a, b]).build()
	assert_eq(s.empire.controlled_tiles.size(), 2)
	assert_eq(a.controller, s.empire, "el builder debe fijar el controller")
	assert_eq(b.controller, s.empire)


func test_tile_se_construye_completa() -> void:
	var t := _tile()
	assert_not_null(t)
	assert_not_null(t.mesh_data, "sin mesh_data no hay bioma")
	assert_not_null(t.natural_resource)
	assert_not_null(t.location)


func test_tile_respeta_bioma_y_recurso() -> void:
	var t := TestBuilders.tile().with_biome(Tile.biome_type.Mountain) \
		.with_resource(7, 3).build()
	add_child_autofree(t)
	assert_eq(t.mesh_data.type, Tile.biome_type.Mountain)
	assert_eq(t.gold_production, 7)
	assert_eq(t.food_production, 3)


func test_tile_acepta_edificios_tipados() -> void:
	var b := TestBuilders.building().with_name("Mina").build()
	var t := TestBuilders.tile().with_buildings([b]).build()
	add_child_autofree(t)
	assert_eq(t.buildings.size(), 1)
	assert_eq(t.buildings[0].name, "Mina")


func test_building_se_construye() -> void:
	# El caso que estaba roto: devolvía null por el Array sin tipar.
	var b := TestBuilders.building().with_name("Cantera").with_cost(75) \
		.with_gold(9).with_food(2).build()
	assert_not_null(b, "TestBuilders.building() no debe devolver null")
	assert_eq(b.name, "Cantera")
	assert_eq(b.construction_cost, 75)
	assert_eq(b.gold_produced, 9)
	assert_eq(b.food_produced, 2)


func test_building_acepta_biomas_y_niveles() -> void:
	# Las dos listas tipadas del builder, que son donde estaba el fallo.
	var loc := LocationType.new()
	loc.type = Tile.location_type.Town
	var b := TestBuilders.building() \
		.with_allowed_biomes([Tile.biome_type.Desert, Tile.biome_type.Mountain]) \
		.with_allowed_locations([loc]).build()
	assert_not_null(b)
	assert_eq(b.allowed_biomes.size(), 2)
	assert_eq(b.allowed_location_type.size(), 1)


func test_building_encadena_mejoras() -> void:
	var up := TestBuilders.building().with_name("Herreria").build()
	var base := TestBuilders.building().with_upgrades_to([up]).build()
	assert_not_null(base)
	assert_eq(base.upgrades_to.size(), 1)
	assert_eq(base.upgrades_to[0].name, "Herreria")


func test_troop_se_construye() -> void:
	var t := TestBuilders.troop().with_attack(6).with_defense(4) \
		.with_recruit_cost(35).with_maintenance(3, 2).build()
	assert_not_null(t)
	assert_eq(t.attack, 6)
	assert_eq(t.defense, 4)
	assert_eq(t.recruitment_cost_gold, 35)
	assert_eq(t.maintenance_gold, 3)
	assert_eq(t.maintenance_food, 2)


func test_context_se_construye_con_rng_propio() -> void:
	var s := TestBuilders.stats().build()
	var ctx := TestBuilders.context(s).with_colonizable(4).with_total_map_tiles(127).build()
	assert_not_null(ctx)
	assert_eq(ctx.stats, s)
	assert_eq(ctx.colonizable_tiles_count, 4)
	assert_eq(ctx.total_map_tiles, 127)
	assert_not_null(ctx.rng, "el rng debe autocrearse")


func test_context_acepta_cartas_robadas() -> void:
	var card := load("res://resources/cards/colonize_card.tres") as Card
	var ctx := TestBuilders.context(TestBuilders.stats().build()) \
		.with_drawn_cards([card]).build()
	assert_eq(ctx.drawn_cards.size(), 1)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

func test_fixture_early_expansion() -> void:
	var f := TestFixtures.early_expansion()
	assert_true(f.has("stats") and f.has("ctx") and f.has("owned_tile") and f.has("free_tile"))
	add_child_autofree(f["owned_tile"])
	add_child_autofree(f["free_tile"])

	var stats: Stats = f["stats"]
	assert_eq(stats.empire.controlled_tiles.size(), 1)
	assert_eq(f["owned_tile"].controller, stats.empire)
	assert_null(f["free_tile"].controller, "la vecina debe estar libre")
	assert_true(f["owned_tile"].neighbors.has(f["free_tile"]), "deben ser adyacentes")


func test_fixture_mid_economy() -> void:
	var f := TestFixtures.mid_economy()
	var stats: Stats = f["stats"]
	assert_eq(stats.turn_number, 15)
	assert_gt(stats.total_gold, 0)
	assert_not_null(f["ctx"])


func test_fixture_late_dominance() -> void:
	var f := TestFixtures.late_dominance()
	var stats: Stats = f["stats"]
	assert_eq(stats.empire.controlled_tiles.size(), 12)
	for t in stats.empire.controlled_tiles:
		add_child_autofree(t)
	assert_eq(stats.turn_number, 40)


func test_las_fases_de_los_fixtures_van_en_orden() -> void:
	# early < mid < late en número de turno: es lo que hace que sirvan para probar
	# comportamiento por fase de partida.
	#
	# Los fixtures devuelven Tile, que son Node3D sin padre: hay que liberarlas o
	# GUT las cuenta como huérfanas (así se detectó esta fuga, en este mismo test).
	var early_f := TestFixtures.early_expansion()
	add_child_autofree(early_f["owned_tile"])
	add_child_autofree(early_f["free_tile"])
	var late_f := TestFixtures.late_dominance()
	for t in late_f["stats"].empire.controlled_tiles:
		add_child_autofree(t)

	var early: Stats = early_f["stats"]
	var mid: Stats = TestFixtures.mid_economy()["stats"]
	var late: Stats = late_f["stats"]
	assert_lt(early.turn_number, mid.turn_number)
	assert_lt(mid.turn_number, late.turn_number)


# ---------------------------------------------------------------------------
# TestWorld
# ---------------------------------------------------------------------------

func test_reset_limpia_el_mapa_global() -> void:
	var t := _tile()
	WorldMap.map = [t] as Array[Tile]
	WorldMap.map_as_dict = {Vector2.ZERO: t}

	TestWorld.reset()

	assert_eq(WorldMap.map.size(), 0)
	assert_eq(WorldMap.map_as_dict.size(), 0,
		"map_as_dict tambien: no limpiarlo devolvia casillas ya liberadas")


func test_reset_es_idempotente() -> void:
	TestWorld.reset()
	TestWorld.reset()
	assert_eq(WorldMap.map.size(), 0)


# ---------------------------------------------------------------------------
# TestAssertions
# ---------------------------------------------------------------------------

func test_assert_gold_delta_acepta_la_relacion_correcta() -> void:
	var s := TestBuilders.stats().with_gold(65).build()
	TestAssertions.assert_gold_delta(self, s, 100, -35, "compra")


func test_assert_descending_acepta_una_serie_decreciente() -> void:
	TestAssertions.assert_descending(self, [10.0, 5.0, 1.0], "urgencias")


func _tile() -> Tile:
	var t := TestBuilders.tile().build()
	add_child_autofree(t)
	return t
