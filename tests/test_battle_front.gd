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
	# Sin tropas, solo bioma Grassland (atk=1.5, def=0.5)
	var atk_pressure := front.get_pressure(&"attacker")
	var def_pressure := front.get_pressure(&"defender")
	# Simétrico con mismos biomas: ambas presiones iguales
	assert_eq(atk_pressure, def_pressure, "Presiones deben ser iguales con biomas simétricos")


func test_pressure_with_troops() -> void:
	var troop := _create_troop(10, 0)
	front.assign_troop(troop, &"attacker")

	var atk_pressure := front.get_pressure(&"attacker")
	# atk total = 1.5 (bioma) + 10 (tropa) = 11.5
	# def enemiga = 0.5 (bioma)
	# presión = 11.5 / (1 + 0.5) = 7.666...
	assert_almost_eq(atk_pressure, 11.5 / 1.5, 0.01, "Presión atacante con tropa ofensiva")


func test_no_defense_is_catastrophic() -> void:
	# Bioma desert: atk=2.0, def=0.0
	atk_tile.free()
	atk_tile = _create_tile(Tile.biome_type.Desert)
	atk_tile.controller = atk_empire
	def_tile.neighbors = [atk_tile]
	atk_tile.neighbors = [def_tile]
	front = BattleFront.new(atk_tile, def_tile, atk_empire, def_empire)

	var troop := _create_troop(10, 0)
	front.assign_troop(troop, &"attacker")

	# Presión defensora contra atacante sin defensa:
	# def_atk = 1.5 (grassland), atk_def = 0.0 (desert) + 0 (tropa)
	# presión def = 1.5 / (1 + 0) = 1.5
	var def_pressure := front.get_pressure(&"defender")
	assert_almost_eq(def_pressure, 1.5, 0.01, "Sin defensa el denominador es 1")


func test_defense_diminishing_returns() -> void:
	# Con 3 de defensa: presión = 10 / (1+3) = 2.5
	# Con 6 de defensa: presión = 10 / (1+6) = 1.43
	# Con 12 de defensa: presión = 10 / (1+12) = 0.77
	# La mejora de 0→3 es mucho mayor que de 6→12
	var t1 := _create_troop(0, 3)
	var t2 := _create_troop(0, 3)
	var t3 := _create_troop(0, 6)

	# Solo con bioma base (Grassland def=0.5)
	# Primeros 3 puntos de defensa defensora
	front.assign_troop(t1, &"defender")
	var pressure_at_3 := front.get_pressure(&"attacker")

	# 6 puntos totales
	front.assign_troop(t2, &"defender")
	var pressure_at_6 := front.get_pressure(&"attacker")

	# 12 puntos totales
	front.assign_troop(t3, &"defender")
	var pressure_at_12 := front.get_pressure(&"attacker")

	var improvement_0_to_3 := pressure_at_3  # Ya reducido desde la base
	var improvement_3_to_6 := pressure_at_3 - pressure_at_6
	var improvement_6_to_12 := pressure_at_6 - pressure_at_12

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
	# Sin efectividad: ataque total = 1.5 (bioma) + 10 = 11.5
	# Con efectividad ×1.5: ataque total = 1.5 + 10*1.5 = 16.5
	front.assign_troop(_create_troop(10, 0, "Cab", Troop.TroopType.CABALLERIA), &"attacker")
	front.assign_troop(_create_troop(1, 0, "Dis", Troop.TroopType.A_DISTANCIA), &"defender")

	var atk := front.get_total_attack(&"attacker")
	assert_almost_eq(atk, 1.5 + 10.0 * 1.5, 0.01,
		"Caballería vs A Distancia debe aplicar ×1.5 al ataque de las tropas")


func test_effective_attack_weak_matchup_decreases_total_attack() -> void:
	# Atacante: caballería (atk=10). Defensor: piqueros.
	# Con efectividad ×0.7: 1.5 + 10*0.7 = 8.5
	front.assign_troop(_create_troop(10, 0, "Cab", Troop.TroopType.CABALLERIA), &"attacker")
	front.assign_troop(_create_troop(1, 6, "Piq", Troop.TroopType.PIQUEROS), &"defender")

	var atk := front.get_total_attack(&"attacker")
	assert_almost_eq(atk, 1.5 + 10.0 * 0.7, 0.01,
		"Caballería vs Piqueros debe aplicar ×0.7 al ataque de las tropas")


func test_effective_attack_neutral_when_no_enemy_troops() -> void:
	# Sólo bioma + ataque plano (no hay enemigos para calcular matchup).
	front.assign_troop(_create_troop(10, 0, "Cab", Troop.TroopType.CABALLERIA), &"attacker")

	var atk := front.get_total_attack(&"attacker")
	assert_almost_eq(atk, 1.5 + 10.0, 0.01,
		"Sin tropas enemigas el atk efectivo es la suma plana (×1.0)")


func test_effective_attack_does_not_modify_biome_or_buildings_or_bonuses() -> void:
	# El bonus plano de 5 al ataque no debe verse afectado por efectividad.
	front.assign_troop(_create_troop(10, 0, "Cab", Troop.TroopType.CABALLERIA), &"attacker")
	front.assign_troop(_create_troop(1, 0, "Dis", Troop.TroopType.A_DISTANCIA), &"defender")
	front.add_bonus(&"attacker", { "attack": 5.0 })

	var atk := front.get_total_attack(&"attacker")
	# 1.5 (bioma) + 10*1.5 (tropas con efectividad) + 5 (bonus plano) = 21.5
	assert_almost_eq(atk, 1.5 + 15.0 + 5.0, 0.01,
		"El bonus plano se suma al final, sin pasar por la matriz de efectividad")


func test_effective_attack_weighted_average_against_mixed_enemy() -> void:
	# Atacante: caballería 10. Defensor: 1 a distancia + 1 piquero (50/50).
	# Multiplicador medio = 0.5*1.5 + 0.5*0.7 = 1.10
	# Atk efectivo de tropas = 11.0; total = 1.5 + 11 = 12.5
	front.assign_troop(_create_troop(10, 0, "Cab", Troop.TroopType.CABALLERIA), &"attacker")
	front.assign_troop(_create_troop(1, 0, "Dis", Troop.TroopType.A_DISTANCIA), &"defender")
	front.assign_troop(_create_troop(1, 0, "Piq", Troop.TroopType.PIQUEROS), &"defender")

	var atk := front.get_total_attack(&"attacker")
	assert_almost_eq(atk, 1.5 + 11.0, 0.01,
		"Mezcla 50/50 fuerte+débil debe dar multiplicador medio 1.10")


func test_defense_is_not_affected_by_effectiveness() -> void:
	# La defensa es suma plana — la efectividad sólo aplica al ataque.
	front.assign_troop(_create_troop(0, 6, "Cab", Troop.TroopType.CABALLERIA), &"attacker")
	front.assign_troop(_create_troop(0, 0, "Piq", Troop.TroopType.PIQUEROS), &"defender")

	var def := front.get_total_defense(&"attacker")
	# Bioma grassland def = 0.5; tropa def = 6
	assert_almost_eq(def, 0.5 + 6.0, 0.01,
		"La defensa no debe pasar por la matriz de efectividad")
