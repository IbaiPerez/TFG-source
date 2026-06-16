extends GutTest

## Tests para la economía con modificadores y habilidad de imperio
## (Fase C v2 — F2.5a). El test central es la PARIDAD de recompute_economy
## contra ProductionCalculator real bajo distintos modifiers, incluyendo las
## habilidades de imperio (que se aplican como modifiers).


# ============================================================
#  Helpers
# ============================================================

func _make_resource(gold: int, food: int) -> NaturalResource:
	var r := NaturalResource.new()
	r.gold_produced = gold
	r.food_produced = food
	return r


func _make_location() -> LocationType:
	var lt := LocationType.new()
	lt.type = Tile.location_type.Village
	lt.max_building = 1
	lt.food_consumption = 0
	return lt


func _make_troop(p_type: int, maint_g: int, maint_f: int) -> Troop:
	var t := Troop.new()
	t.name = "troop"
	t.type = p_type
	t.maintenance_gold = maint_g
	t.maintenance_food = maint_f
	return t


## Tile real con un recurso natural, recalculado, autofree.
func _make_real_tile(resource: NaturalResource) -> Tile:
	var t := autofree(Tile.new()) as Tile
	t.natural_resource = resource
	t.location = _make_location()
	t.buildings = []
	t.recalculate_modifiers()
	return t


## TileSnap espejo de un Tile real.
func _make_snap(id: int, resource: NaturalResource) -> AIRealState.TileSnap:
	var s := AIRealState.TileSnap.new()
	s.id = id
	s.natural_resource = resource
	s.resource_gold = resource.gold_produced
	s.resource_food = resource.food_produced
	s.location_type = Tile.location_type.Village
	s.max_buildings = 1
	s.food_consumption = 0
	s.owner = AIRealState.OWNER_SELF
	s.neighbor_ids = []
	return s


## Construye (Stats real + ModifierManager) y el AIRealState equivalente con los
## mismos recursos, tropas y modifiers; verifica que recompute_economy coincide
## con ProductionCalculator.calculate_turn().
func _assert_economy_parity(resources: Array, troops: Array[Troop],
		mods: Array[Modifier]) -> void:
	# --- Mundo real ---
	var empire := Empire.new()
	var real_tiles: Array[Tile] = []
	for r in resources:
		real_tiles.append(_make_real_tile(r as NaturalResource))
	empire.controlled_tiles = real_tiles
	var stats := Stats.new()
	stats.empire = empire
	stats.troop_pool = troops.duplicate()
	var mm := autofree(ModifierManager.new()) as ModifierManager
	mm.active_modifiers = mods.duplicate()
	var calc := ProductionCalculator.new(stats, mm, null)
	var result := calc.calculate_turn()

	# --- Simulación ---
	var state := AIRealState.new()
	for i in range(resources.size()):
		state.tiles[i] = _make_snap(i, resources[i] as NaturalResource)
	state.own.troop_pool = troops.duplicate()
	state.own.modifiers = mods.duplicate()
	AIRealSimulator.recompute_own_economy(state)

	assert_eq(state.own.gold_per_turn, int(result["gold"]),
		"gpt debe coincidir con ProductionCalculator (sim %d vs real %d)"
			% [state.own.gold_per_turn, int(result["gold"])])
	assert_eq(state.own.food, int(result["food"]),
		"food debe coincidir con ProductionCalculator (sim %d vs real %d)"
			% [state.own.food, int(result["food"])])


# ============================================================
#  Paridad de economía con modifiers
# ============================================================

func test_economy_parity_no_modifiers() -> void:
	var no_mods: Array[Modifier] = []
	_assert_economy_parity([_make_resource(10, 4), _make_resource(6, 2)], [], no_mods)


func test_economy_parity_percent_gold() -> void:
	var mods: Array[Modifier] = [StatModifier.new(
		"m", "+10% oro", StatModifier.StatType.PERCENT_GOLD, 10.0, -1)]
	_assert_economy_parity([_make_resource(100, 10), _make_resource(50, 5)], [], mods)


func test_economy_parity_flat_gold_and_food() -> void:
	var mods: Array[Modifier] = [
		StatModifier.new("g", "+oro", StatModifier.StatType.FLAT_GOLD, 25.0, -1),
		StatModifier.new("f", "+comida", StatModifier.StatType.FLAT_FOOD, 7.0, -1),
	]
	_assert_economy_parity([_make_resource(40, 8)], [], mods)


func test_economy_parity_percent_only_on_positive() -> void:
	# Producción de oro baja + mantenimiento alto → la parte negativa no se
	# amplifica con el porcentaje (regla de ProductionCalculator).
	var mods: Array[Modifier] = [StatModifier.new(
		"m", "+50% oro", StatModifier.StatType.PERCENT_GOLD, 50.0, -1)]
	var troops: Array[Troop] = [_make_troop(Troop.TroopType.PIQUEROS, 30, 0)]
	_assert_economy_parity([_make_resource(10, 5)], troops, mods)


func test_economy_parity_tile_resource_bonus() -> void:
	# +2 comida en casillas con un recurso concreto (estilo Jardines Colgantes).
	var wheat := _make_resource(0, 3)
	var other := _make_resource(5, 0)
	var mods: Array[Modifier] = [StatModifier.new(
		"w", "+2 comida trigo", StatModifier.StatType.TILE_RESOURCE_FOOD, 2.0, -1,
		null, wheat)]
	_assert_economy_parity([wheat, other], [], mods)


func test_economy_parity_troop_maintenance_discount() -> void:
	# -25% mantenimiento solo de caballería (estilo Horda Nómada).
	var mods: Array[Modifier] = [StatModifier.new(
		"m", "-25% mant caballería", StatModifier.StatType.TROOP_MAINTENANCE_PERCENT,
		-25.0, -1, null, null, Troop.TroopType.CABALLERIA)]
	var troops: Array[Troop] = [
		_make_troop(Troop.TroopType.CABALLERIA, 20, 4),
		_make_troop(Troop.TroopType.PIQUEROS, 20, 4),
	]
	_assert_economy_parity([_make_resource(100, 50)], troops, mods)


# ============================================================
#  Habilidades de imperio (salen gratis vía modifiers)
# ============================================================

func test_gardens_ability_percent_gold_parity() -> void:
	# GardensAbility incluye +10% oro global; verificamos paridad con el cálculo real.
	var ability := GardensAbility.new()
	var mods: Array[Modifier] = ability.create_modifiers()
	_assert_economy_parity([_make_resource(200, 20), _make_resource(80, 10)], [], mods)


func test_banking_ability_percent_gold_parity() -> void:
	# BankingAbility (Medici): +15% oro global.
	var ability := BankingAbility.new()
	var mods: Array[Modifier] = ability.create_modifiers()
	_assert_economy_parity([_make_resource(300, 30)], [], mods)


# ============================================================
#  Coste de construcción con BuildCostModifier
# ============================================================

func _build_state_with_discount(percent: float) -> AIRealState:
	var s := AIRealState.new()
	var snap := _make_snap(0, _make_resource(2, 0))
	s.tiles[0] = snap
	s.own.gold = 1000
	if percent != 0.0:
		s.own.modifiers = [BuildCostModifier.new("b", "descuento", percent, -1)] as Array[Modifier]
	return s


func test_build_cost_applies_discount() -> void:
	# -20% (Banca Florentina): edificio de coste 50 → cuesta 40.
	var s := _build_state_with_discount(20.0)
	var b := Building.new()
	b.name = "mina"
	b.construction_cost = 50
	b.gold_produced = 5
	AIRealSimulator.apply_build(s, 0, b)
	assert_eq(s.own.gold, 960, "Coste con −20%: 1000 − 40")


func test_build_cost_no_discount() -> void:
	var s := _build_state_with_discount(0.0)
	var b := Building.new()
	b.name = "mina"
	b.construction_cost = 50
	b.gold_produced = 5
	AIRealSimulator.apply_build(s, 0, b)
	assert_eq(s.own.gold, 950, "Sin descuento: 1000 − 50")


func test_build_cost_clamped_to_minimum() -> void:
	# Descuento del 95% → clampeado al 20% del coste mínimo (MIN_COST_MULTIPLIER).
	var s := _build_state_with_discount(95.0)
	var b := Building.new()
	b.name = "mina"
	b.construction_cost = 100
	b.gold_produced = 5
	AIRealSimulator.apply_build(s, 0, b)
	assert_eq(s.own.gold, 980, "Coste mínimo 20%: 1000 − 20")


# ============================================================
#  Duración y expiración de modifiers
# ============================================================

func test_modifier_expires_on_advance_turn() -> void:
	var s := AIRealState.new()
	s.tiles[0] = _make_snap(0, _make_resource(100, 0))
	# Modifier temporal de +50% oro, dura 1 turno.
	s.own.modifiers = [StatModifier.new(
		"m", "+50%", StatModifier.StatType.PERCENT_GOLD, 50.0, 1)] as Array[Modifier]
	AIRealSimulator.recompute_own_economy(s)
	assert_eq(s.own.gold_per_turn, 150, "Con el modifier activo: 100 × 1.5")
	AIRealSimulator.advance_turn(s)
	assert_eq(s.own.modifiers.size(), 0, "El modifier de 1 turno expira en advance_turn")
	assert_eq(s.own.gold_per_turn, 100, "Tras expirar, gpt vuelve a la base")


func test_permanent_modifier_survives_advance_turn() -> void:
	var s := AIRealState.new()
	s.tiles[0] = _make_snap(0, _make_resource(100, 0))
	s.own.modifiers = [StatModifier.new(
		"m", "+50%", StatModifier.StatType.PERCENT_GOLD, 50.0, -1)] as Array[Modifier]
	AIRealSimulator.advance_turn(s)
	assert_eq(s.own.modifiers.size(), 1, "Un modifier permanente (duration -1) no expira")


func test_modifier_clone_independent() -> void:
	var s := AIRealState.new()
	s.own.modifiers = [StatModifier.new(
		"m", "+50%", StatModifier.StatType.PERCENT_GOLD, 50.0, 3)] as Array[Modifier]
	var c := s.clone()
	(c.own.modifiers[0] as StatModifier).duration = 0
	(c.own.modifiers[0] as StatModifier).value = 999.0
	assert_eq((s.own.modifiers[0] as StatModifier).duration, 3,
		"Clonar duplica los modifiers: mutar el clon no afecta al original")
	assert_eq((s.own.modifiers[0] as StatModifier).value, 50.0)
