extends GutTest

## Tests para BattleFront: fórmula de movimiento, resolución,
## duración mínima, bajas, y asignación de tropas.

var front: BattleFront
var atk_tile: Tile
var def_tile: Tile
var atk_empire: Empire
var def_empire: Empire


func _create_tile(biome: Tile.biome_type) -> Tile:
	var tile := Tile.new()
	tile.mesh_data = TileMeshData.new()
	tile.mesh_data.type = biome
	tile.natural_resource = NaturalResource.new()
	tile.buildings = []
	return tile


func _create_troop(atk: int, def: int, name: String = "Test",
		troop_type: int = Troop.TroopType.INFANTERIA_LIGERA) -> Troop:
	var troop := Troop.new()
	troop.name = name
	troop.type = troop_type
	troop.attack = atk
	troop.defense = def
	troop.recruitment_cost_gold = 10
	troop.maintenance_gold = 2
	troop.maintenance_food = 1
	return troop


func before_each() -> void:
	# Limpiar el registro global para evitar interferencias entre tests
	BattleFront.clear_active_instances()

	atk_empire = Empire.new()
	atk_empire.name = "Atacante"
	def_empire = Empire.new()
	def_empire.name = "Defensor"

	atk_tile = _create_tile(Tile.biome_type.Grassland)
	def_tile = _create_tile(Tile.biome_type.Grassland)
	atk_tile.controller = atk_empire
	def_tile.controller = def_empire
	atk_tile.neighbors = [def_tile]
	def_tile.neighbors = [atk_tile]

	front = BattleFront.new(atk_tile, def_tile, atk_empire, def_empire)


func after_each() -> void:
	BattleFront.clear_active_instances()
	if is_instance_valid(atk_tile):
		atk_tile.free()
	if is_instance_valid(def_tile):
		def_tile.free()


# --- Tests de la fórmula de presión ---

func test_pressure_formula_basic() -> void:
	# Sin tropas y con biomas simétricos: ambas presiones son iguales (y nulas,
	# porque el bioma ya no aporta ataque plano).
	var atk_pressure := front.get_pressure(&"attacker")
	var def_pressure := front.get_pressure(&"defender")
	assert_eq(atk_pressure, def_pressure, "Presiones deben ser iguales con biomas simétricos")
	assert_eq(atk_pressure, 0.0, "Sin tropas no hay presión")


func test_pressure_with_troops() -> void:
	var troop := _create_troop(10, 0)
	front.assign_troop(troop, &"attacker")

	var atk_pressure := front.get_pressure(&"attacker")
	# atk efectivo de la tropa = 10 (sin enemigos, multiplicador efectividad 1.0)
	# bioma de la tile contraria (Grassland) → ×1.2
	# atk total = 10 × 1.2 = 12.0
	# def enemiga = 0 (sin tropas defensoras, edificios = 0)
	# presión = 12.0 / (1 + 0) = 12.0
	assert_almost_eq(atk_pressure, 12.0, 0.01, "Presión atacante con tropa ofensiva en pradera")


func test_no_defender_troops_means_zero_counter_pressure() -> void:
	# Sin tropas en defensa, el defensor no genera presión sin importar el bioma.
	var troop := _create_troop(10, 0)
	front.assign_troop(troop, &"attacker")

	var def_pressure := front.get_pressure(&"defender")
	assert_eq(def_pressure, 0.0,
		"Sin tropas defensoras la presión del defensor es 0 (el bioma no aporta plano)")


func test_defense_diminishing_returns() -> void:
	# Atacante con ataque fijo. Comprobamos que añadir defensa reduce la
	# presión cada vez menos (rendimientos decrecientes) por la fórmula
	# atk / (1 + def_enemiga).
	front.assign_troop(_create_troop(20, 0), &"attacker")

	var t1 := _create_troop(0, 3)
	var t2 := _create_troop(0, 3)
	var t3 := _create_troop(0, 6)

	var pressure_at_0 := front.get_pressure(&"attacker")

	front.assign_troop(t1, &"defender")
	var pressure_at_3 := front.get_pressure(&"attacker")

	front.assign_troop(t2, &"defender")
	var pressure_at_6 := front.get_pressure(&"attacker")

	front.assign_troop(t3, &"defender")
	var pressure_at_12 := front.get_pressure(&"attacker")

	var improvement_0_to_3 := pressure_at_0 - pressure_at_3
	var improvement_3_to_6 := pressure_at_3 - pressure_at_6
	var improvement_6_to_12 := pressure_at_6 - pressure_at_12

	assert_gt(improvement_0_to_3, improvement_3_to_6,
		"Rendimientos decrecientes: la mejora 0→3 debe ser mayor que 3→6")
	assert_gt(improvement_3_to_6, improvement_6_to_12,
		"Rendimientos decrecientes: la mejora 3→6 debe ser mayor que 6→12")


# --- Tests de movimiento del marcador ---

func test_marker_starts_at_zero() -> void:
	assert_eq(front.marker, 0.0, "Marcador empieza en 0")


func test_tick_moves_marker() -> void:
	var troop := _create_troop(10, 2)
	front.assign_troop(troop, &"attacker")
	front.tick()
	assert_gt(front.marker, 0.0, "Con ventaja atacante, el marcador debe moverse positivo")


func test_symmetric_forces_marker_stays_near_zero() -> void:
	var t1 := _create_troop(5, 5)
	var t2 := _create_troop(5, 5)
	front.assign_troop(t1, &"attacker")
	front.assign_troop(t2, &"defender")
	front.tick()
	assert_almost_eq(front.marker, 0.0, 0.01, "Fuerzas simétricas: marcador apenas se mueve")


# --- Tests de duración mínima ---

func test_cannot_resolve_before_min_duration() -> void:
	front.min_duration = 3
	front.threshold = 1.0  # Umbral muy bajo para forzar resolución rápida
	var troop := _create_troop(50, 0)
	front.assign_troop(troop, &"attacker")

	front.tick()  # Turno 1
	assert_false(front.is_resolved, "No debe resolverse en turno 1 (min_duration=3)")
	front.tick()  # Turno 2
	assert_false(front.is_resolved, "No debe resolverse en turno 2")


func test_resolves_after_min_duration_and_threshold() -> void:
	front.min_duration = 1
	front.threshold = 0.5
	var troop := _create_troop(50, 0)
	front.assign_troop(troop, &"attacker")

	var resolved := front.tick()
	assert_true(resolved, "Debe resolverse tras alcanzar umbral y duración mínima")
	assert_true(front.is_resolved)


# --- Tests de resolución ---

func test_attacker_wins_with_positive_marker() -> void:
	front.min_duration = 1
	front.threshold = 0.1
	var troop := _create_troop(50, 50)
	front.assign_troop(troop, &"attacker")

	var result := [false]
	front.front_resolved.connect(func(_f, attacker_won): result[0] = attacker_won)
	front.tick()

	assert_true(front.is_resolved)
	assert_true(result[0], "Atacante debe ganar con marcador positivo")


func test_defender_wins_with_negative_marker() -> void:
	front.min_duration = 1
	front.threshold = 0.1
	var troop := _create_troop(50, 50)
	front.assign_troop(troop, &"defender")

	var result := [true]
	front.front_resolved.connect(func(_f, attacker_won): result[0] = attacker_won)
	front.tick()

	assert_true(front.is_resolved)
	assert_false(result[0], "Defensor debe ganar con marcador negativo")


# --- Tests de bonuses de cartas tácticas ---

func test_flat_attack_bonus() -> void:
	var base_pressure := front.get_pressure(&"attacker")
	front.add_bonus(&"attacker", { "attack": 5.0, "duration": 2 })
	var boosted_pressure := front.get_pressure(&"attacker")
	assert_gt(boosted_pressure, base_pressure, "Bonus de ataque debe aumentar presión")


func test_bonus_expires_after_duration() -> void:
	front.add_bonus(&"attacker", { "attack": 100.0, "duration": 1 })
	assert_eq(front.attacker_bonuses.size(), 1)
	front.tick()
	assert_eq(front.attacker_bonuses.size(), 0, "Bonus debe expirar tras 1 turno")


func test_permanent_bonus_persists() -> void:
	front.add_bonus(&"attacker", { "attack": 5.0 })  # Sin "duration"
	front.tick()
	front.tick()
	assert_eq(front.attacker_bonuses.size(), 1, "Bonus sin duración debe persistir")


# --- Tests del registro global de frentes activos ---

func test_active_registry_records_new_front() -> void:
	# El front de before_each ya cuenta como instancia activa
	var actives := BattleFront.get_active_instances()
	assert_eq(actives.size(), 1, "El BattleFront debe registrarse al construirse")
	assert_true(front in actives, "El registro debe contener al front recién creado")


func test_active_registry_clears_on_resolve() -> void:
	# Forzar resolución
	front.min_duration = 1
	front.threshold = 0.1
	front.assign_troop(_create_troop(50, 0), &"attacker")
	front.tick()
	assert_true(front.is_resolved, "Sanity check: el frente debe haberse resuelto")

	assert_eq(BattleFront.get_active_instances().size(), 0,
		"Tras resolverse, el frente debe salir del registro global")


func test_is_tile_in_active_front_finds_attacker_and_defender_tiles() -> void:
	assert_true(BattleFront.is_tile_in_active_front(atk_tile),
		"La tile atacante debe detectarse como ocupada")
	assert_true(BattleFront.is_tile_in_active_front(def_tile),
		"La tile defensora debe detectarse como ocupada")


func test_is_tile_in_active_front_returns_false_for_unrelated_tile() -> void:
	var other := _create_tile(Tile.biome_type.Forest)
	assert_false(BattleFront.is_tile_in_active_front(other),
		"Una tile que no participa en ningún frente debe devolver false")
	other.free()


# --- Tests de stats de tropas asignadas (info para la UI) ---

func test_assigned_troops_attack_sums_only_troop_attack() -> void:
	front.assign_troop(_create_troop(4, 1), &"attacker")
	front.assign_troop(_create_troop(6, 2), &"attacker")
	# Sin tropas en defensa
	assert_eq(front.get_assigned_troops_attack(&"attacker"), 10,
		"Debe sumar atk de las tropas asignadas (4+6=10)")
	assert_eq(front.get_assigned_troops_attack(&"defender"), 0,
		"Sin tropas asignadas el atk de tropas debe ser 0")


func test_assigned_troops_defense_sums_only_troop_defense() -> void:
	front.assign_troop(_create_troop(0, 5), &"defender")
	front.assign_troop(_create_troop(0, 7), &"defender")
	assert_eq(front.get_assigned_troops_defense(&"defender"), 12,
		"Debe sumar def de las tropas asignadas (5+7=12)")
	assert_eq(front.get_assigned_troops_defense(&"attacker"), 0,
		"Sin tropas asignadas la def de tropas debe ser 0")


func test_assigned_troops_stats_ignore_biome_and_bonuses() -> void:
	# El atk total tiene bioma + bonuses; el de tropas asignadas no.
	front.assign_troop(_create_troop(3, 0), &"attacker")
	front.add_bonus(&"attacker", { "attack": 50.0 })

	assert_eq(front.get_assigned_troops_attack(&"attacker"), 3,
		"Las tropas asignadas no deben incluir bioma ni bonuses")
	assert_gt(front.get_total_attack(&"attacker"), 3.0,
		"El total sí debe seguir incluyendo bioma y bonuses")


# --- Tests de mantenimiento progresivo ---

func test_front_maintenance_scales_progressively() -> void:
	var t1 := _create_troop(3, 3)
	var t2 := _create_troop(3, 3)
	var t3 := _create_troop(3, 3)
	front.assign_troop(t1, &"attacker")
	front.assign_troop(t2, &"attacker")
	front.assign_troop(t3, &"attacker")

	var maint := front.get_front_maintenance(&"attacker")
	# 1 + 2 + 3 = 6
	assert_eq(maint["gold"], 6, "Mantenimiento progresivo: 1+2+3 = 6 oro")
	assert_eq(maint["food"], 6, "Mantenimiento progresivo: 1+2+3 = 6 comida")


func test_front_maintenance_empty() -> void:
	var maint := front.get_front_maintenance(&"attacker")
	assert_eq(maint["gold"], 0)
	assert_eq(maint["food"], 0)


# --- Tests de bajas ---

func test_casualties_proportional() -> void:
	front.min_duration = 1
	front.threshold = 0.1

	# Atacante aplastante
	for i in range(5):
		front.assign_troop(_create_troop(10, 10), &"attacker")
	for i in range(3):
		front.assign_troop(_create_troop(1, 1), &"defender")

	front.tick()
	assert_true(front.is_resolved)

	var casualties := front.calculate_casualties()
	assert_lt(casualties["attacker_losses"], casualties["defender_losses"],
		"El ganador debe perder menos tropas que el perdedor")


func test_casualties_zero_when_no_troops() -> void:
	front.is_resolved = true
	front.marker = front.threshold
	var casualties := front.calculate_casualties()
	assert_eq(casualties["attacker_losses"], 0)
	assert_eq(casualties["defender_losses"], 0)


# --- Tests de efectividad por tipo (piedra-papel-tijera) ---

func test_effective_attack_strong_matchup_increases_total_attack() -> void:
	# Atacante: caballería (atk=10). Defensor: a distancia.
	# Tropas con efectividad ×1.5 → atk efectivo = 15.
	# Bioma de la tile contraria (Grassland) → multiplicador ATK ×1.2.
	# atk total = 15 × 1.2 = 18.0
	front.assign_troop(_create_troop(10, 0, "Cab", Troop.TroopType.CABALLERIA), &"attacker")
	front.assign_troop(_create_troop(1, 0, "Dis", Troop.TroopType.A_DISTANCIA), &"defender")

	var atk := front.get_total_attack(&"attacker")
	assert_almost_eq(atk, 10.0 * 1.5 * 1.2, 0.01,
		"Caballería vs A Distancia: efectividad ×1.5 y bioma grassland ×1.2")


func test_effective_attack_weak_matchup_decreases_total_attack() -> void:
	# Caballería vs piqueros → efectividad ×0.7. Bioma Grassland ×1.2.
	# atk total = 10 × 0.7 × 1.2 = 8.4
	front.assign_troop(_create_troop(10, 0, "Cab", Troop.TroopType.CABALLERIA), &"attacker")
	front.assign_troop(_create_troop(1, 6, "Piq", Troop.TroopType.PIQUEROS), &"defender")

	var atk := front.get_total_attack(&"attacker")
	assert_almost_eq(atk, 10.0 * 0.7 * 1.2, 0.01,
		"Caballería vs Piqueros: efectividad ×0.7 y bioma grassland ×1.2")


func test_effective_attack_neutral_when_no_enemy_troops() -> void:
	# Sin enemigos: matchup neutro ×1.0. Bioma Grassland ×1.2.
	# atk total = 10 × 1.0 × 1.2 = 12.0
	front.assign_troop(_create_troop(10, 0, "Cab", Troop.TroopType.CABALLERIA), &"attacker")

	var atk := front.get_total_attack(&"attacker")
	assert_almost_eq(atk, 10.0 * 1.2, 0.01,
		"Sin tropas enemigas el atk efectivo es la suma plana (×1.0) y se aplica el bioma")


func test_effective_attack_does_not_modify_buildings_or_bonuses() -> void:
	# El bonus plano de 5 al ataque NO se ve afectado por efectividad ni por
	# el multiplicador de bioma. Solo el aporte de tropas pasa por ambos.
	front.assign_troop(_create_troop(10, 0, "Cab", Troop.TroopType.CABALLERIA), &"attacker")
	front.assign_troop(_create_troop(1, 0, "Dis", Troop.TroopType.A_DISTANCIA), &"defender")
	front.add_bonus(&"attacker", { "attack": 5.0 })

	var atk := front.get_total_attack(&"attacker")
	# Tropas: 10 × 1.5 (efectividad) × 1.2 (bioma) = 18; bonus plano: +5 → 23
	assert_almost_eq(atk, 10.0 * 1.5 * 1.2 + 5.0, 0.01,
		"El bonus plano no pasa por matriz de efectividad ni por multiplicador de bioma")


func test_effective_attack_weighted_average_against_mixed_enemy() -> void:
	# Caballería vs 1 a distancia + 1 piquero (50/50).
	# Multiplicador medio = 0.5×1.5 + 0.5×0.7 = 1.10
	# atk total = 10 × 1.10 × 1.2 (bioma) = 13.2
	front.assign_troop(_create_troop(10, 0, "Cab", Troop.TroopType.CABALLERIA), &"attacker")
	front.assign_troop(_create_troop(1, 0, "Dis", Troop.TroopType.A_DISTANCIA), &"defender")
	front.assign_troop(_create_troop(1, 0, "Piq", Troop.TroopType.PIQUEROS), &"defender")

	var atk := front.get_total_attack(&"attacker")
	assert_almost_eq(atk, 10.0 * 1.10 * 1.2, 0.01,
		"Mezcla 50/50 fuerte+débil debe dar multiplicador medio 1.10 (y bioma ×1.2)")


func test_defense_is_not_affected_by_effectiveness() -> void:
	# La defensa no pasa por la matriz de efectividad — solo el ataque.
	# Tropa atacante con def=6 en Grassland → multiplicador DEF propio ×0.9.
	front.assign_troop(_create_troop(0, 6, "Cab", Troop.TroopType.CABALLERIA), &"attacker")
	front.assign_troop(_create_troop(0, 0, "Piq", Troop.TroopType.PIQUEROS), &"defender")

	var def := front.get_total_defense(&"attacker")
	assert_almost_eq(def, 6.0 * 0.9, 0.01,
		"La defensa solo aplica el multiplicador de bioma propio, no la matriz de efectividad")


# --- Tests de multiplicador de bioma ---

## Helper: crea un frente nuevo con biomas concretos para atacante y defensor.
func _make_front(atk_biome: Tile.biome_type, def_biome: Tile.biome_type) -> BattleFront:
	atk_tile.free()
	def_tile.free()
	atk_tile = _create_tile(atk_biome)
	def_tile = _create_tile(def_biome)
	atk_tile.controller = atk_empire
	def_tile.controller = def_empire
	atk_tile.neighbors = [def_tile]
	def_tile.neighbors = [atk_tile]
	return BattleFront.new(atk_tile, def_tile, atk_empire, def_empire)


func test_biome_attack_multiplier_uses_enemy_tile() -> void:
	# Atacante en Mountain (mult ATK ×0.6 si te atacaran a ti).
	# Defensor en Grassland (mult ATK ×1.2 si te atacaran a ti).
	# El ATK del atacante se calcula con la tile contraria → Grassland → ×1.2.
	# El ATK del defensor se calcula con la tile contraria → Mountain → ×0.6.
	BattleFront.clear_active_instances()
	front = _make_front(Tile.biome_type.Mountain, Tile.biome_type.Grassland)

	front.assign_troop(_create_troop(10, 0), &"attacker")
	front.assign_troop(_create_troop(10, 0), &"defender")

	# Sin enemigos del mismo tipo → matchup neutro; sólo bioma actúa.
	# Atacante: 10 × 1.2 (Grassland) = 12.0
	# Defensor: 10 × 0.6 (Mountain)  = 6.0
	assert_almost_eq(front.get_total_attack(&"attacker"), 12.0, 0.01,
		"ATK del atacante usa el bioma de la tile DEFENSORA (Grassland → ×1.2)")
	assert_almost_eq(front.get_total_attack(&"defender"), 6.0, 0.01,
		"ATK del defensor usa el bioma de la tile ATACANTE (Mountain → ×0.6)")


func test_biome_defense_multiplier_uses_own_tile() -> void:
	# Atacante en Mountain (DEF propia ×1.5).
	# Defensor en Desert  (DEF propia ×0.85).
	BattleFront.clear_active_instances()
	front = _make_front(Tile.biome_type.Mountain, Tile.biome_type.Desert)

	front.assign_troop(_create_troop(0, 10), &"attacker")
	front.assign_troop(_create_troop(0, 10), &"defender")

	assert_almost_eq(front.get_total_defense(&"attacker"), 10.0 * 1.5, 0.01,
		"DEF del atacante usa el bioma de su PROPIA tile (Mountain → ×1.5)")
	assert_almost_eq(front.get_total_defense(&"defender"), 10.0 * 0.85, 0.01,
		"DEF del defensor usa el bioma de su PROPIA tile (Desert → ×0.85)")


func test_biome_attack_multiplier_per_biome_values() -> void:
	# Verifica el valor exacto del multiplicador de ATK para cada bioma de
	# tile contraria, manteniendo la tile propia neutral (Tundra ×1.0 DEF).
	var expected := {
		Tile.biome_type.Grassland: 1.20,
		Tile.biome_type.Desert:    1.10,
		Tile.biome_type.Tundra:    0.95,
		Tile.biome_type.Forest:    0.80,
		Tile.biome_type.Swamp:     0.70,
		Tile.biome_type.Mountain:  0.60,
		Tile.biome_type.Ocean:     1.00,
	}
	for biome in expected.keys():
		BattleFront.clear_active_instances()
		front = _make_front(Tile.biome_type.Tundra, biome)
		front.assign_troop(_create_troop(10, 0), &"attacker")
		var expected_atk: float = 10.0 * expected[biome]
		assert_almost_eq(front.get_total_attack(&"attacker"), expected_atk, 0.01,
			"Bioma %s: ATK esperado %s" % [biome, expected_atk])


func test_biome_defense_multiplier_per_biome_values() -> void:
	# Verifica el valor exacto del multiplicador de DEF para cada bioma propio.
	var expected := {
		Tile.biome_type.Mountain:  1.50,
		Tile.biome_type.Forest:    1.25,
		Tile.biome_type.Swamp:     1.20,
		Tile.biome_type.Tundra:    1.00,
		Tile.biome_type.Grassland: 0.90,
		Tile.biome_type.Desert:    0.85,
		Tile.biome_type.Ocean:     1.00,
	}
	for biome in expected.keys():
		BattleFront.clear_active_instances()
		# Tile contraria neutra para no contaminar.
		front = _make_front(biome, Tile.biome_type.Tundra)
		front.assign_troop(_create_troop(0, 10), &"attacker")
		var expected_def: float = 10.0 * expected[biome]
		assert_almost_eq(front.get_total_defense(&"attacker"), expected_def, 0.01,
			"Bioma %s: DEF esperada %s" % [biome, expected_def])


func test_biome_does_not_scale_flat_bonus() -> void:
	# Frente con multiplicador hostil (Mountain ×0.6 ATK) y un bonus plano alto.
	# El bonus plano debe quedarse íntegro; sólo las tropas se escalan por bioma.
	BattleFront.clear_active_instances()
	front = _make_front(Tile.biome_type.Tundra, Tile.biome_type.Mountain)
	front.assign_troop(_create_troop(10, 0), &"attacker")
	front.add_bonus(&"attacker", { "attack": 100.0 })

	var atk := front.get_total_attack(&"attacker")
	# Tropas: 10 × 0.6 = 6;  bonus plano: 100 → total = 106
	assert_almost_eq(atk, 10.0 * 0.6 + 100.0, 0.01,
		"El bonus plano no se ve afectado por el multiplicador de bioma")


func test_no_troops_means_zero_attack_and_defense_in_any_biome() -> void:
	# Sin tropas, ningún bioma genera atk/def — el bioma es un multiplicador,
	# no un aporte plano. Edificios siguen pudiendo aportar (placeholder = 0).
	BattleFront.clear_active_instances()
	front = _make_front(Tile.biome_type.Mountain, Tile.biome_type.Grassland)

	assert_eq(front.get_total_attack(&"attacker"), 0.0,
		"Sin tropas no hay ataque, da igual el bioma")
	assert_eq(front.get_total_defense(&"attacker"), 0.0,
		"Sin tropas no hay defensa, da igual el bioma")
	assert_eq(front.get_total_attack(&"defender"), 0.0)
	assert_eq(front.get_total_defense(&"defender"), 0.0)


# ============================================================
#  combat_multiplier — penalizacion por economia en deficit (Opcion 3a)
# ============================================================

func test_combat_multiplier_default_does_not_change_attack() -> void:
	# combat_multiplier = 1.0 (default) = sin penalizacion. La salida es la
	# misma que sin la fix, garantiza retrocompat para empires economicamente
	# sanas.
	front.assign_troop(_create_troop(10, 0), &"attacker")
	var atk := front.get_total_attack(&"attacker")
	# Grassland atacando Grassland: multiplicador biome = 1.20.
	assert_almost_eq(atk, 10.0 * 1.20, 0.01,
		"Con combat_multiplier=1.0 el ATK es el de tropas × biome, sin penalty")


func test_combat_multiplier_halves_troop_attack() -> void:
	# Imperio en deficit: combat_multiplier = 0.5 (50% penalty). El ATK
	# de las tropas se reduce a la mitad.
	atk_empire.combat_multiplier = 0.5
	front.assign_troop(_create_troop(10, 0), &"attacker")
	var atk := front.get_total_attack(&"attacker")
	assert_almost_eq(atk, 10.0 * 1.20 * 0.5, 0.01,
		"combat_multiplier=0.5 → ATK escalado al 50%")


func test_combat_multiplier_halves_troop_defense() -> void:
	# Mismo principio para defensa, mirando al defender_empire.
	def_empire.combat_multiplier = 0.5
	front.assign_troop(_create_troop(0, 10), &"defender")
	var def := front.get_total_defense(&"defender")
	# Defender en Grassland: multiplicador biome defense = 0.90.
	assert_almost_eq(def, 10.0 * 0.90 * 0.5, 0.01,
		"combat_multiplier=0.5 → DEF escalada al 50%")


func test_combat_multiplier_does_not_affect_flat_bonus() -> void:
	# El multiplier solo afecta a la contribucion de tropas; bonuses
	# tacticos planos siguen al 100%. Verificamos con un bonus de +100 ATK.
	atk_empire.combat_multiplier = 0.1  # Peor caso
	front.assign_troop(_create_troop(10, 0), &"attacker")
	front.add_bonus(&"attacker", { "attack": 100.0 })

	var atk := front.get_total_attack(&"attacker")
	# Tropas: 10 × 1.20 × 0.1 = 1.2;  bonus plano: 100 → total = 101.2
	assert_almost_eq(atk, 10.0 * 1.20 * 0.1 + 100.0, 0.01,
		"El bonus plano debe quedar intacto aunque combat_multiplier sea 0.1")


func test_combat_multiplier_independent_per_side() -> void:
	# Atacante en deficit (0.3) y defensor sano (1.0): cada bando ve su
	# propio multiplier, no se cruzan.
	atk_empire.combat_multiplier = 0.3
	def_empire.combat_multiplier = 1.0
	front.assign_troop(_create_troop(10, 0), &"attacker")
	front.assign_troop(_create_troop(0, 10), &"defender")

	var atk := front.get_total_attack(&"attacker")
	var def := front.get_total_defense(&"defender")
	assert_almost_eq(atk, 10.0 * 1.20 * 0.3, 0.01)
	assert_almost_eq(def, 10.0 * 0.90 * 1.0, 0.01)


# --- Tests del threshold dinamico (decay con turns_elapsed) ---

func test_threshold_initial_default_is_15() -> void:
	# Default actualizado tras el primer rebalanceo: bajado de 20 a 15.
	assert_eq(front.threshold, 15.0,
		"Threshold inicial por defecto deberia ser 15 tras el rebalanceo")


func test_current_threshold_starts_at_initial() -> void:
	# turns_elapsed = 0 → no hay decay aplicado.
	assert_eq(front.get_current_threshold(), front.threshold,
		"Sin tiempo transcurrido, el threshold efectivo es el inicial")


func test_current_threshold_decays_to_min_after_decay_window() -> void:
	# Tras THRESHOLD_DECAY_TURNS turnos, el threshold ha bajado al minimo.
	front.turns_elapsed = BattleFront.THRESHOLD_DECAY_TURNS
	assert_almost_eq(front.get_current_threshold(), BattleFront.MIN_THRESHOLD, 0.001,
		"Al final del decay, el threshold queda en MIN_THRESHOLD")


func test_current_threshold_decays_linearly_at_halfway() -> void:
	# A mitad de la ventana de decay, el threshold cae a la media entre
	# inicial y minimo.
	front.turns_elapsed = BattleFront.THRESHOLD_DECAY_TURNS / 2
	var expected: float = (front.threshold + BattleFront.MIN_THRESHOLD) / 2.0
	assert_almost_eq(front.get_current_threshold(), expected, 0.01,
		"A mitad del decay, threshold = media entre inicial y minimo")


func test_current_threshold_clamps_at_min_after_decay() -> void:
	# Mas alla del periodo de decay, el threshold se queda en MIN_THRESHOLD,
	# nunca baja por debajo.
	front.turns_elapsed = BattleFront.THRESHOLD_DECAY_TURNS * 3
	assert_eq(front.get_current_threshold(), BattleFront.MIN_THRESHOLD,
		"Pasado el decay, el threshold se clampea en MIN_THRESHOLD")


func test_current_threshold_does_not_rise_when_initial_below_min() -> void:
	# Tests con threshold pequeño (configuracion de tests rapidos) NO deben
	# verse afectados por el decay: si el inicial ya es < MIN_THRESHOLD, no
	# decae nunca — el threshold solo baja, jamas sube.
	front.threshold = 0.5
	front.turns_elapsed = BattleFront.THRESHOLD_DECAY_TURNS
	assert_eq(front.get_current_threshold(), 0.5,
		"Threshold inicial bajo no debe subir aunque pase la ventana de decay")


func test_can_resolve_uses_current_threshold() -> void:
	# Un frente con marker entre MIN_THRESHOLD e initial deberia resolverse
	# SOLO cuando ha pasado tiempo suficiente para que el threshold haya
	# bajado hasta el marker.
	front.min_duration = 1
	front.threshold = 15.0
	front.marker = 11.0
	front.turns_elapsed = 1
	assert_false(front.can_resolve(),
		"En turno 1, threshold ~15 sigue por encima del marker=11 → no resuelve")
	# Al final del decay, threshold = 10 < 11, ya resuelve.
	front.turns_elapsed = BattleFront.THRESHOLD_DECAY_TURNS
	assert_true(front.can_resolve(),
		"Tras el decay, threshold=10 < marker=11 → puede resolverse")
