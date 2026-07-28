extends GutTest

## Tests de AIEventScoring: valoración de casilla candidata a Megalópolis unificada
## (refactor C6 §1.6.6). Antes vivía DUPLICADA con fórmula idéntica en
## AIEventResolver (vivo) y AIRealEvents (snapshot). Aquí se fija la fórmula sobre
## los literales exactos que ambos mundos usaban: surviving + recurso − demolished.


func _make_building(p_gold: int = 0, p_food: int = 0, p_defense: int = 0) -> Building:
	var b := Building.new()
	b.name = "TestBuilding"
	b.gold_produced = p_gold
	b.food_produced = p_food
	b.flat_defense_bonus = p_defense
	b.allowed_location_type = []
	return b


func _make_location(p_type: Tile.location_type) -> LocationType:
	var loc := LocationType.new()
	loc.type = p_type
	return loc


# ------------------------------------------------------------------
#  Edificios que sobreviven (allowed vacío o incluye ≥ Megalópolis)
# ------------------------------------------------------------------

func test_surviving_buildings_sum_positive() -> void:
	# gold=5→10, food=2→3, defense=4→4  ⇒  17.  Sin recurso.
	var b := _make_building(5, 2, 4)   # allowed vacío → sobrevive
	var v := AIEventScoring.megalopolis_tile_value([b], null)
	assert_almost_eq(v, 17.0, 0.001)


func test_building_allowed_in_megalopolis_survives() -> void:
	var b := _make_building(10, 0, 0)   # 20
	b.allowed_location_type = [_make_location(Tile.location_type.Megalopolis)]
	var v := AIEventScoring.megalopolis_tile_value([b], null)
	assert_almost_eq(v, 20.0, 0.001)


# ------------------------------------------------------------------
#  Edificios que se demuelen (allowed no incluye Megalópolis) → restan
# ------------------------------------------------------------------

func test_doomed_building_is_subtracted() -> void:
	var b := _make_building(6, 0, 0)   # 12
	b.allowed_location_type = [_make_location(Tile.location_type.Village)]
	var v := AIEventScoring.megalopolis_tile_value([b], null)
	assert_almost_eq(v, -12.0, 0.001)


func test_survivor_minus_doomed() -> void:
	var keep := _make_building(5, 0, 0)   # +10, allowed vacío
	var doomed := _make_building(3, 0, 0)   # −6
	doomed.allowed_location_type = [_make_location(Tile.location_type.Town)]
	var v := AIEventScoring.megalopolis_tile_value([keep, doomed], null)
	assert_almost_eq(v, 4.0, 0.001)


# ------------------------------------------------------------------
#  Recurso natural + robustez (null buildings, tile vacía)
# ------------------------------------------------------------------

func test_natural_resource_adds_value() -> void:
	# recurso gold=4→6, food=2→2.4  ⇒  8.4
	var res := NaturalResource.new()
	res.gold_produced = 4
	res.food_produced = 2
	var v := AIEventScoring.megalopolis_tile_value([], res)
	assert_almost_eq(v, 8.4, 0.001)


func test_null_buildings_are_skipped() -> void:
	var b := _make_building(5, 0, 0)   # +10
	var v := AIEventScoring.megalopolis_tile_value([null, b, null], null)
	assert_almost_eq(v, 10.0, 0.001)


func test_empty_tile_scores_zero() -> void:
	assert_almost_eq(AIEventScoring.megalopolis_tile_value([], null), 0.0, 0.001)
