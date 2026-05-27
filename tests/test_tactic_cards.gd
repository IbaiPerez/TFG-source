extends GutTest

## Tests para TacticCard y el sistema de bonus dirigidos por tipo de tropa
## en BattleFront — incluye los formatos legacy (troop_name / troop_type)
## y el nuevo formato (troop_types: Array, attack_percent_per_type,
## defense_percent_per_type, biome_modifiers).

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


func _create_troop(troop_name: String, atk: int, def: int,
		troop_type: int = Troop.TroopType.INFANTERIA_LIGERA) -> Troop:
	var troop := Troop.new()
	troop.name = troop_name
	troop.type = troop_type
	troop.attack = atk
	troop.defense = def
	troop.recruitment_cost_gold = 10
	troop.maintenance_gold = 2
	troop.maintenance_food = 1
	return troop


func _create_stats(empire: Empire) -> Stats:
	var stats := Stats.new()
	stats.empire = empire
	stats.total_gold = 200
	stats.food = 100
	return stats


func before_each() -> void:
	BattleFront.clear_active_instances()

	atk_empire = Empire.new()
	atk_empire.name = "Atacante"
	def_empire = Empire.new()
	def_empire.name = "Defensor"

	atk_tile = _create_tile(Tile.biome_type.Grassland)
	def_tile = _create_tile(Tile.biome_type.Grassland)
	autofree(atk_tile)
	autofree(def_tile)
	atk_tile.controller = atk_empire
	def_tile.controller = def_empire
	atk_tile.neighbors = [def_tile]
	def_tile.neighbors = [atk_tile]

	front = BattleFront.new(atk_tile, def_tile, atk_empire, def_empire)


func after_each() -> void:
	BattleFront.clear_active_instances()


# ============================================================
#  Bonus PLANO por tipo de tropa (legacy: attack_per_troop)
# ============================================================

func test_troop_type_bonus_attack_scales_with_matching_troops() -> void:
	for i in 3:
		front.assign_troop(_create_troop("Milicia", 3, 3), &"attacker")

	var base_atk := front.get_total_attack(&"attacker")

	front.add_bonus(&"attacker", {
		"troop_name": "Milicia",
		"attack_per_troop": 2.0,
		"defense_per_troop": 1.0,
	})

	var boosted_atk := front.get_total_attack(&"attacker")
	assert_almost_eq(boosted_atk - base_atk, 6.0, 0.01, "Bonus ATK plano debe escalar con el número de tropas del tipo")


func test_troop_type_bonus_defense_scales_with_matching_troops() -> void:
	for i in 2:
		front.assign_troop(_create_troop("Piqueros", 1, 6), &"defender")

	var base_def := front.get_total_defense(&"defender")

	front.add_bonus(&"defender", {
		"troop_name": "Piqueros",
		"attack_per_troop": 1.0,
		"defense_per_troop": 3.0,
	})

	var boosted_def := front.get_total_defense(&"defender")
	assert_almost_eq(boosted_def - base_def, 6.0, 0.01, "Bonus DEF plano debe escalar con el número de tropas del tipo")


func test_troop_type_bonus_ignores_other_troop_types() -> void:
	front.assign_troop(_create_troop("Milicia", 3, 3), &"attacker")
	front.assign_troop(_create_troop("Milicia", 3, 3), &"attacker")
	front.assign_troop(_create_troop("Caballería", 6, 1), &"attacker")

	var base_atk := front.get_total_attack(&"attacker")

	front.add_bonus(&"attacker", {
		"troop_name": "Milicia",
		"attack_per_troop": 2.0,
		"defense_per_troop": 2.0,
	})

	var boosted_atk := front.get_total_attack(&"attacker")
	assert_almost_eq(boosted_atk - base_atk, 4.0, 0.01, "Bonus solo debe afectar a tropas del tipo indicado")


func test_troop_type_bonus_zero_matching_troops() -> void:
	front.assign_troop(_create_troop("Caballería", 6, 1), &"attacker")

	var base_atk := front.get_total_attack(&"attacker")

	front.add_bonus(&"attacker", {
		"troop_name": "Milicia",
		"attack_per_troop": 2.0,
		"defense_per_troop": 2.0,
	})

	var boosted_atk := front.get_total_attack(&"attacker")
	assert_eq(boosted_atk, base_atk, "Sin tropas del tipo, el bonus no debe aplicarse")


func test_troop_type_bonus_is_permanent_without_duration() -> void:
	front.assign_troop(_create_troop("Milicia", 3, 3), &"attacker")

	front.add_bonus(&"attacker", {
		"troop_name": "Milicia",
		"attack_per_troop": 2.0,
		"defense_per_troop": 2.0,
	})

	front._tick_bonuses(front.attacker_bonuses)
	front._tick_bonuses(front.attacker_bonuses)
	front._tick_bonuses(front.attacker_bonuses)

	assert_eq(front.attacker_bonuses.size(), 1, "Bonus permanente no debe eliminarse al hacer tick")


func test_multiple_troop_type_bonuses_stack() -> void:
	front.assign_troop(_create_troop("Milicia", 3, 3), &"attacker")
	front.assign_troop(_create_troop("Milicia", 3, 3), &"attacker")

	var base_atk := front.get_total_attack(&"attacker")

	front.add_bonus(&"attacker", {
		"troop_name": "Milicia",
		"attack_per_troop": 2.0,
		"defense_per_troop": 1.0,
	})
	front.add_bonus(&"attacker", {
		"troop_name": "Milicia",
		"attack_per_troop": 1.0,
		"defense_per_troop": 2.0,
	})

	var boosted_atk := front.get_total_attack(&"attacker")
	assert_almost_eq(boosted_atk - base_atk, 6.0, 0.01, "Múltiples bonus del mismo tipo deben apilarse")


func test_count_troops_by_name() -> void:
	front.assign_troop(_create_troop("Milicia", 3, 3), &"attacker")
	front.assign_troop(_create_troop("Milicia", 3, 3), &"attacker")
	front.assign_troop(_create_troop("Caballería", 6, 1), &"attacker")
	front.assign_troop(_create_troop("Piqueros", 1, 6), &"attacker")
	front.assign_troop(_create_troop("Milicia", 3, 3), &"attacker")

	assert_eq(front._count_troops_by_name(front.attacker_troops, "Milicia"), 3)
	assert_eq(front._count_troops_by_name(front.attacker_troops, "Caballería"), 1)
	assert_eq(front._count_troops_by_name(front.attacker_troops, "Piqueros"), 1)
	assert_eq(front._count_troops_by_name(front.attacker_troops, "Elite"), 0)


# ============================================================
#  Bonus por troop_type (singular, nuevo)
# ============================================================

func test_count_troops_by_type() -> void:
	front.assign_troop(_create_troop("A", 3, 3, Troop.TroopType.CABALLERIA), &"attacker")
	front.assign_troop(_create_troop("B", 3, 3, Troop.TroopType.CABALLERIA), &"attacker")
	front.assign_troop(_create_troop("C", 1, 6, Troop.TroopType.PIQUEROS), &"attacker")

	assert_eq(front._count_troops_by_type(front.attacker_troops,
		Troop.TroopType.CABALLERIA), 2)
	assert_eq(front._count_troops_by_type(front.attacker_troops,
		Troop.TroopType.PIQUEROS), 1)
	assert_eq(front._count_troops_by_type(front.attacker_troops,
		Troop.TroopType.A_DISTANCIA), 0)


func test_bonus_targets_troops_by_type() -> void:
	front.assign_troop(_create_troop("Caballería ligera", 6, 1, Troop.TroopType.CABALLERIA), &"attacker")
	front.assign_troop(_create_troop("Caballería pesada", 6, 1, Troop.TroopType.CABALLERIA), &"attacker")
	front.assign_troop(_create_troop("Piquero", 1, 6, Troop.TroopType.PIQUEROS), &"attacker")

	var base_atk := front.get_total_attack(&"attacker")

	front.add_bonus(&"attacker", {
		"troop_type": Troop.TroopType.CABALLERIA,
		"attack_per_troop": 3.0,
	})

	var boosted_atk := front.get_total_attack(&"attacker")
	assert_almost_eq(boosted_atk - base_atk, 6.0, 0.01,
		"El bonus por tipo debe afectar a todas las tropas de ese tipo, sin importar el nombre")


func test_bonus_by_type_ignores_other_types() -> void:
	front.assign_troop(_create_troop("Cab", 6, 1, Troop.TroopType.CABALLERIA), &"attacker")
	front.assign_troop(_create_troop("Piq", 1, 6, Troop.TroopType.PIQUEROS), &"attacker")

	var base_def := front.get_total_defense(&"attacker")

	front.add_bonus(&"attacker", {
		"troop_type": Troop.TroopType.PIQUEROS,
		"defense_per_troop": 4.0,
	})

	var boosted_def := front.get_total_defense(&"attacker")
	assert_almost_eq(boosted_def - base_def, 4.0, 0.01)


func test_bonus_with_troop_types_array_takes_precedence_over_singular() -> void:
	# Si el bonus trae troop_types (array), prevalece sobre troop_type y troop_name.
	front.assign_troop(_create_troop("Pikeman", 1, 6, Troop.TroopType.PIQUEROS), &"attacker")
	front.assign_troop(_create_troop("Pikeman", 1, 6, Troop.TroopType.PIQUEROS), &"attacker")
	front.assign_troop(_create_troop("Pikeman", 1, 6, Troop.TroopType.CABALLERIA), &"attacker")

	var base_atk := front.get_total_attack(&"attacker")
	front.add_bonus(&"attacker", {
		"troop_name": "Pikeman",
		"troop_type": Troop.TroopType.CABALLERIA,
		"troop_types": [Troop.TroopType.PIQUEROS],
		"attack_per_troop": 5.0,
	})
	var boosted_atk := front.get_total_attack(&"attacker")
	assert_almost_eq(boosted_atk - base_atk, 10.0, 0.01,
		"troop_types (array) debe ganar a troop_type y a troop_name")


# ============================================================
#  Bonus por troop_types (array, nuevo — para cartas multi-tipo)
# ============================================================

func test_count_bonus_targets_with_array_of_types() -> void:
	front.assign_troop(_create_troop("Piq", 1, 6, Troop.TroopType.PIQUEROS), &"attacker")
	front.assign_troop(_create_troop("Lig", 3, 3, Troop.TroopType.INFANTERIA_LIGERA), &"attacker")
	front.assign_troop(_create_troop("Cab", 6, 1, Troop.TroopType.CABALLERIA), &"attacker")

	# Falange-style: PIQ + LIG.
	var bonus := TacticBonus.from_dict({"troop_types": [Troop.TroopType.PIQUEROS, Troop.TroopType.INFANTERIA_LIGERA]})
	assert_eq(front._count_bonus_targets(front.attacker_troops, bonus), 2,
		"Debe contar tropas que coincidan con alguno de los tipos del array")


func test_bonus_with_multiple_types_affects_all_listed() -> void:
	# Falange afecta a piqueros e infantería ligera.
	front.assign_troop(_create_troop("Piq", 1, 6, Troop.TroopType.PIQUEROS), &"defender")
	front.assign_troop(_create_troop("Lig", 3, 3, Troop.TroopType.INFANTERIA_LIGERA), &"defender")
	front.assign_troop(_create_troop("Cab", 6, 1, Troop.TroopType.CABALLERIA), &"defender")

	var base_def := front.get_total_defense(&"defender")
	front.add_bonus(&"defender", {
		"troop_types": [Troop.TroopType.PIQUEROS, Troop.TroopType.INFANTERIA_LIGERA],
		"defense_per_troop": 2.0,
	})
	var boosted_def := front.get_total_defense(&"defender")
	# 2 tropas afectadas (PIQ + LIG) × 2 DEF = +4. La caballería no cuenta.
	assert_almost_eq(boosted_def - base_def, 4.0, 0.01,
		"Bonus multi-tipo debe afectar a todas las tropas listadas")


# ============================================================
#  Bonus PORCENTUAL por tipo (nuevo — pasa por matriz de efectividad)
# ============================================================

func test_attack_percent_per_type_applies_to_effective_attack() -> void:
	# Caballería propia (atk 10) vs A Distancia enemiga → matchup ×1.5.
	# Atk efectivo de la cab = 10 × 1.5 = 15. Bonus +30% sobre eso = +4.5.
	front.assign_troop(_create_troop("Cab", 10, 0, Troop.TroopType.CABALLERIA), &"attacker")
	front.assign_troop(_create_troop("Dis", 1, 0, Troop.TroopType.A_DISTANCIA), &"defender")

	var base_atk := front.get_total_attack(&"attacker")
	front.add_bonus(&"attacker", {
		"troop_types": [Troop.TroopType.CABALLERIA],
		"attack_percent_per_type": 30.0,
	})
	var boosted_atk := front.get_total_attack(&"attacker")
	assert_almost_eq(boosted_atk - base_atk, 15.0 * 0.30, 0.01,
		"+30%% sobre el ATK efectivo (15) debería sumar 4.5")


func test_attack_percent_per_type_passes_through_weak_matchup() -> void:
	# Caballería propia (10) vs Piqueros enemigos → matchup ×0.7.
	# Atk efectivo = 10 × 0.7 = 7. Bonus +30% = +2.1
	front.assign_troop(_create_troop("Cab", 10, 0, Troop.TroopType.CABALLERIA), &"attacker")
	front.assign_troop(_create_troop("Piq", 1, 6, Troop.TroopType.PIQUEROS), &"defender")

	var base_atk := front.get_total_attack(&"attacker")
	front.add_bonus(&"attacker", {
		"troop_types": [Troop.TroopType.CABALLERIA],
		"attack_percent_per_type": 30.0,
	})
	var boosted_atk := front.get_total_attack(&"attacker")
	assert_almost_eq(boosted_atk - base_atk, 7.0 * 0.30, 0.01,
		"+30%% sobre matchup débil (7) debería sumar 2.1, no 3.0")


func test_defense_percent_per_type_applies_to_base_defense() -> void:
	# La defensa NO pasa por matriz: el % aplica directo al troop.defense.
	front.assign_troop(_create_troop("Piq", 1, 6, Troop.TroopType.PIQUEROS), &"defender")
	front.assign_troop(_create_troop("Lig", 3, 3, Troop.TroopType.INFANTERIA_LIGERA), &"defender")

	var base_def := front.get_total_defense(&"defender")
	front.add_bonus(&"defender", {
		"troop_types": [Troop.TroopType.PIQUEROS, Troop.TroopType.INFANTERIA_LIGERA],
		"defense_percent_per_type": 30.0,
	})
	var boosted_def := front.get_total_defense(&"defender")
	# DEF base afectada = 6 (PIQ) + 3 (LIG) = 9. +30% = +2.7.
	assert_almost_eq(boosted_def - base_def, 9.0 * 0.30, 0.01,
		"+30%% sobre la DEF base de las tropas afectadas (9) debería sumar 2.7")


func test_attack_biome_modifier_scales_percent_bonus() -> void:
	# Bonus +30% sobre cab (atk efectivo 15) con biome_modifier ×1.5 = +6.75
	front.assign_troop(_create_troop("Cab", 10, 0, Troop.TroopType.CABALLERIA), &"attacker")
	front.assign_troop(_create_troop("Dis", 1, 0, Troop.TroopType.A_DISTANCIA), &"defender")

	var base_atk := front.get_total_attack(&"attacker")
	front.add_bonus(&"attacker", {
		"troop_types": [Troop.TroopType.CABALLERIA],
		"attack_percent_per_type": 30.0,
		"attack_biome_modifier": 1.5,
	})
	var boosted_atk := front.get_total_attack(&"attacker")
	assert_almost_eq(boosted_atk - base_atk, 15.0 * 0.30 * 1.5, 0.01,
		"El biome_modifier debe multiplicar el bonus efectivo")


func test_zero_biome_modifier_nullifies_percent_bonus() -> void:
	front.assign_troop(_create_troop("Cab", 10, 0, Troop.TroopType.CABALLERIA), &"attacker")
	front.assign_troop(_create_troop("Dis", 1, 0, Troop.TroopType.A_DISTANCIA), &"defender")

	var base_atk := front.get_total_attack(&"attacker")
	front.add_bonus(&"attacker", {
		"troop_types": [Troop.TroopType.CABALLERIA],
		"attack_percent_per_type": 30.0,
		"attack_biome_modifier": 0.0,
	})
	var boosted_atk := front.get_total_attack(&"attacker")
	assert_eq(boosted_atk, base_atk,
		"Con biome_modifier=0 el bonus no debe aportar nada")


func test_percent_bonus_dynamically_includes_newly_assigned_troops() -> void:
	# Decisión de diseño: el bonus se evalúa cada tick, así que tropas
	# asignadas DESPUÉS de jugar la carta también se benefician.
	front.assign_troop(_create_troop("Cab1", 10, 0, Troop.TroopType.CABALLERIA), &"attacker")
	front.assign_troop(_create_troop("Dis", 1, 0, Troop.TroopType.A_DISTANCIA), &"defender")

	front.add_bonus(&"attacker", {
		"troop_types": [Troop.TroopType.CABALLERIA],
		"attack_percent_per_type": 30.0,
		"attack_biome_modifier": 1.0,
	})
	var atk_with_one := front.get_total_attack(&"attacker")

	# Asignar otra caballería al frente DESPUÉS del bonus.
	front.assign_troop(_create_troop("Cab2", 10, 0, Troop.TroopType.CABALLERIA), &"attacker")
	var atk_with_two := front.get_total_attack(&"attacker")

	# La 2ª cab también recibe el bonus (no congelado al jugar).
	# Sólo comprobamos que la diferencia es estrictamente mayor que el aporte
	# base de la nueva tropa (el bonus la incluye también).
	assert_gt(atk_with_two - atk_with_one, 15.0,
		"Tropas asignadas después también se benefician del bonus dinámico")


# ============================================================
#  TacticCard — modelo de carta (nueva API)
# ============================================================

func test_tactic_card_has_correct_properties() -> void:
	var card := TacticCard.new()
	card.tactic_name = "Test"
	card.affected_troop_types = [Troop.TroopType.CABALLERIA]
	card.attack_percent_per_type = 30.0
	card.target = Card.Target.BATTLE_FRONT
	card.type = Card.Type.SPECIAL

	assert_true(card.is_batle_front_targeted(), "TacticCard debe tener target BATTLE_FRONT")
	assert_false(card.is_tile_targeted(), "TacticCard no debe ser tile targeted")
	assert_false(card.is_single_use(), "TacticCard SPECIAL no debe ser single use")


func test_tactic_card_tooltip_contains_name_and_bonuses() -> void:
	var card := TacticCard.new()
	card.tactic_name = "Carga de Caballería"
	card.affected_troop_types = [Troop.TroopType.CABALLERIA]
	card.attack_percent_per_type = 30.0
	card.biome_modifiers = {Tile.biome_type.Grassland: 1.5}

	var tooltip := card._build_tooltip()
	assert_true(tooltip.contains("Carga de Caballería"), "Tooltip debe contener el nombre de la táctica")
	assert_true(tooltip.contains("Caballería"), "Tooltip debe contener el tipo afectado")
	assert_true(tooltip.contains("30"), "Tooltip debe contener el porcentaje")
	assert_true(tooltip.contains("Pradera"), "Tooltip debe listar el bioma con modificador no neutro")


func test_get_biome_modifier_for_tile_returns_neutral_when_unlisted() -> void:
	var card := TacticCard.new()
	card.biome_modifiers = {Tile.biome_type.Grassland: 1.5}

	var tile := _create_tile(Tile.biome_type.Forest)
	autofree(tile)
	assert_eq(card.get_biome_modifier_for_tile(tile), 1.0,
		"Bioma no listado debe devolver multiplicador neutro (1.0)")


func test_get_biome_modifier_for_tile_clamps_negative_to_zero() -> void:
	var card := TacticCard.new()
	card.biome_modifiers = {Tile.biome_type.Grassland: -2.0}

	var tile := _create_tile(Tile.biome_type.Grassland)
	autofree(tile)
	assert_eq(card.get_biome_modifier_for_tile(tile), 0.0,
		"Multiplicador negativo debe clampearse a 0 (jugar la carta nunca penaliza)")


func test_get_biome_modifier_for_tile_returns_value_for_listed() -> void:
	var card := TacticCard.new()
	card.biome_modifiers = {
		Tile.biome_type.Grassland: 1.5,
		Tile.biome_type.Mountain: 0.2,
	}

	var grass := _create_tile(Tile.biome_type.Grassland)
	autofree(grass)
	var mtn := _create_tile(Tile.biome_type.Mountain)
	autofree(mtn)
	assert_eq(card.get_biome_modifier_for_tile(grass), 1.5)
	assert_eq(card.get_biome_modifier_for_tile(mtn), 0.2)


# ============================================================
#  TacticCard.apply_effects — qué se mete en el frente
# ============================================================

func test_apply_effects_adds_bonus_to_attacker_side_with_correct_data() -> void:
	var stats := _create_stats(atk_empire)

	add_child(atk_tile)
	add_child(def_tile)

	var visual := BattleFrontVisual.new(front)
	add_child_autofree(visual)
	await get_tree().process_frame

	var card := TacticCard.new()
	card.tactic_name = "Carga"
	card.affected_troop_types = [Troop.TroopType.CABALLERIA]
	card.attack_percent_per_type = 30.0
	card.biome_modifiers = {Tile.biome_type.Grassland: 1.5}
	card.target = Card.Target.BATTLE_FRONT

	var targets: Array[Node] = [visual]
	card.apply_effects(targets, stats)

	assert_eq(front.attacker_bonuses.size(), 1, "Debe añadir bonus al bando atacante")
	assert_eq(front.defender_bonuses.size(), 0, "No debe afectar al bando defensor")
	var bonus: TacticBonus = front.attacker_bonuses[0]
	assert_eq(bonus["tactic_name"], "Carga")
	assert_eq(bonus["attack_percent_per_type"], 30.0)
	# Tile contraria (def_tile) es Grassland → mod ×1.5 capturado.
	assert_eq(bonus["attack_biome_modifier"], 1.5,
		"El biome_modifier de ATK debe leer el bioma de la tile CONTRARIA")


func test_apply_effects_uses_own_tile_for_defense_biome() -> void:
	var stats := _create_stats(def_empire)

	# Cambiar la tile defensora a Forest para distinguirla de la atacante (Grassland).
	def_tile.mesh_data.type = Tile.biome_type.Forest

	add_child(atk_tile)
	add_child(def_tile)

	var visual := BattleFrontVisual.new(front)
	add_child_autofree(visual)
	await get_tree().process_frame

	var card := TacticCard.new()
	card.tactic_name = "Falange"
	card.affected_troop_types = [Troop.TroopType.PIQUEROS, Troop.TroopType.INFANTERIA_LIGERA]
	card.defense_percent_per_type = 30.0
	card.biome_modifiers = {
		Tile.biome_type.Grassland: 1.0,
		Tile.biome_type.Forest: 1.3,
	}
	card.target = Card.Target.BATTLE_FRONT

	var targets: Array[Node] = [visual]
	card.apply_effects(targets, stats)

	assert_eq(front.defender_bonuses.size(), 1)
	var bonus: TacticBonus = front.defender_bonuses[0]
	# El jugador es defensor → tile propia es def_tile (Forest, ×1.3).
	assert_eq(bonus["defense_biome_modifier"], 1.3,
		"El biome_modifier de DEF debe leer el bioma de la tile PROPIA")


func test_apply_effects_full_flow_bonus_affects_combat() -> void:
	var stats := _create_stats(atk_empire)

	# 2 caballerías en atacante, 1 a distancia en defensor (matchup ×1.5).
	front.assign_troop(_create_troop("Cab1", 10, 0, Troop.TroopType.CABALLERIA), &"attacker")
	front.assign_troop(_create_troop("Cab2", 10, 0, Troop.TroopType.CABALLERIA), &"attacker")
	front.assign_troop(_create_troop("Dis", 1, 0, Troop.TroopType.A_DISTANCIA), &"defender")

	var atk_before := front.get_total_attack(&"attacker")

	add_child(atk_tile)
	add_child(def_tile)

	var visual := BattleFrontVisual.new(front)
	add_child_autofree(visual)
	await get_tree().process_frame

	var card := TacticCard.new()
	card.tactic_name = "Carga"
	card.affected_troop_types = [Troop.TroopType.CABALLERIA]
	card.attack_percent_per_type = 30.0
	# Defender tile es Grassland (modificador 1.5).
	card.biome_modifiers = {Tile.biome_type.Grassland: 1.5}
	card.target = Card.Target.BATTLE_FRONT

	var targets: Array[Node] = [visual]
	card.apply_effects(targets, stats)

	var atk_after := front.get_total_attack(&"attacker")
	# Atk efectivo afectado = 2 cab × (10 × 1.5) = 30. +30% × 1.5 (bioma) = +13.5.
	assert_almost_eq(atk_after - atk_before, 30.0 * 0.30 * 1.5, 0.01,
		"Bonus efectivo = atk_eff_afectado × pct × biome_mod")


# ============================================================
#  Política exclusiva: una sola táctica activa por bando
# ============================================================

func _make_tactic_bonus(name: String) -> Dictionary:
	# Helper: bonus dict mínimo equivalente al que mete una TacticCard.
	return {
		"tactic_name": name,
		"troop_types": [Troop.TroopType.CABALLERIA],
		"attack_percent_per_type": 20.0,
		"defense_percent_per_type": 0.0,
		"attack_per_troop": 0.0,
		"defense_per_troop": 0.0,
		"attack_biome_modifier": 1.0,
		"defense_biome_modifier": 1.0,
	}


func test_clear_tactics_removes_only_entries_with_tactic_name() -> void:
	# Mezcla bonuses de táctica con bonuses planos manuales.
	front.add_bonus(&"attacker", _make_tactic_bonus("Carga"))
	front.add_bonus(&"attacker", {"attack": 5.0})  # plano sin tactic_name
	front.add_bonus(&"attacker", _make_tactic_bonus("Falange"))

	var removed := front.clear_tactics_for_side(&"attacker")
	assert_eq(removed, 2, "Debe eliminar las 2 tácticas, no el bonus plano")
	assert_eq(front.attacker_bonuses.size(), 1,
		"Sólo debe quedar el bonus plano sin tactic_name")
	assert_eq(front.attacker_bonuses[0].get("attack", 0.0), 5.0)


func test_clear_tactics_does_not_touch_opposite_side() -> void:
	front.add_bonus(&"attacker", _make_tactic_bonus("Carga"))
	front.add_bonus(&"defender", _make_tactic_bonus("Falange"))

	front.clear_tactics_for_side(&"attacker")
	assert_eq(front.attacker_bonuses.size(), 0,
		"El bando atacante debe quedar limpio")
	assert_eq(front.defender_bonuses.size(), 1,
		"La táctica del defensor no debe verse afectada")


func test_clear_tactics_empty_returns_zero() -> void:
	var removed := front.clear_tactics_for_side(&"attacker")
	assert_eq(removed, 0, "Sin tácticas activas debe devolver 0")


func test_has_active_tactic_on_side() -> void:
	assert_false(front.has_active_tactic_on_side(&"attacker"))
	front.add_bonus(&"attacker", _make_tactic_bonus("Carga"))
	assert_true(front.has_active_tactic_on_side(&"attacker"))
	assert_false(front.has_active_tactic_on_side(&"defender"))


func test_has_active_tactic_ignores_non_tactic_bonuses() -> void:
	# Un bonus plano sin tactic_name no debe contar como táctica.
	front.add_bonus(&"attacker", {"attack": 10.0})
	assert_false(front.has_active_tactic_on_side(&"attacker"),
		"Bonus sin tactic_name no es una táctica")


func test_has_any_active_tactic_detects_either_side() -> void:
	assert_false(front.has_any_active_tactic())
	front.add_bonus(&"defender", _make_tactic_bonus("Falange"))
	assert_true(front.has_any_active_tactic(),
		"Una táctica en el defensor también cuenta")


func test_add_bonus_emits_bonuses_changed() -> void:
	watch_signals(front)
	front.add_bonus(&"attacker", _make_tactic_bonus("Carga"))
	assert_signal_emitted_with_parameters(front, "bonuses_changed", [&"attacker"])


func test_clear_tactics_emits_signal_only_when_changes() -> void:
	# Sembramos una táctica antes de empezar a vigilar para que el
	# watch_signals no recoja el emit del add_bonus inicial.
	front.add_bonus(&"attacker", _make_tactic_bonus("Carga"))
	watch_signals(front)

	# Primera limpieza: hubo cambios → emite (count = 1).
	front.clear_tactics_for_side(&"attacker")
	assert_signal_emit_count(front, "bonuses_changed", 1,
		"Si hubo cambios reales debe emitirse la señal una vez")

	# Segunda limpieza sobre un bando ya vacío: no emite (count sigue = 1).
	front.clear_tactics_for_side(&"attacker")
	assert_signal_emit_count(front, "bonuses_changed", 1,
		"Sin cambios reales el contador NO debe subir")


func test_apply_effects_replaces_previous_tactic_on_same_side() -> void:
	var stats := _create_stats(atk_empire)

	add_child(atk_tile)
	add_child(def_tile)

	var visual := BattleFrontVisual.new(front)
	add_child_autofree(visual)
	await get_tree().process_frame

	# Primera táctica: Carga
	var carga := TacticCard.new()
	carga.tactic_name = "Carga"
	carga.affected_troop_types = [Troop.TroopType.CABALLERIA]
	carga.attack_percent_per_type = 30.0
	carga.biome_modifiers = {Tile.biome_type.Grassland: 1.5}
	carga.target = Card.Target.BATTLE_FRONT
	var targets: Array[Node] = [visual]
	carga.apply_effects(targets, stats)
	assert_eq(front.attacker_bonuses.size(), 1)
	assert_eq(front.attacker_bonuses[0]["tactic_name"], "Carga")

	# Segunda táctica: Emboscada — debe sustituir a la anterior, no apilarse.
	var emboscada := TacticCard.new()
	emboscada.tactic_name = "Emboscada"
	emboscada.affected_troop_types = [Troop.TroopType.INFANTERIA_LIGERA]
	emboscada.attack_percent_per_type = 40.0
	emboscada.biome_modifiers = {Tile.biome_type.Grassland: 0.8}
	emboscada.target = Card.Target.BATTLE_FRONT
	emboscada.apply_effects(targets, stats)

	assert_eq(front.attacker_bonuses.size(), 1,
		"En cada bando sólo puede haber UNA táctica activa")
	assert_eq(front.attacker_bonuses[0]["tactic_name"], "Emboscada",
		"La táctica nueva debe sustituir a la anterior")


func test_apply_effects_does_not_clear_opposite_side_tactic() -> void:
	# El atacante juega Carga, el defensor ya tenía una Falange activa.
	# La táctica del defensor no debe desaparecer.
	var def_stats := _create_stats(def_empire)
	add_child(atk_tile)
	add_child(def_tile)

	var visual := BattleFrontVisual.new(front)
	add_child_autofree(visual)
	await get_tree().process_frame

	# El defensor juega Falange primero.
	var falange := TacticCard.new()
	falange.tactic_name = "Falange"
	falange.affected_troop_types = [Troop.TroopType.PIQUEROS]
	falange.defense_percent_per_type = 30.0
	falange.target = Card.Target.BATTLE_FRONT
	var defender_targets: Array[Node] = [visual]
	falange.apply_effects(defender_targets, def_stats)
	assert_eq(front.defender_bonuses.size(), 1)

	# Luego el atacante juega Carga. La Falange del defensor sigue ahí.
	var atk_stats := _create_stats(atk_empire)
	var carga := TacticCard.new()
	carga.tactic_name = "Carga"
	carga.affected_troop_types = [Troop.TroopType.CABALLERIA]
	carga.attack_percent_per_type = 30.0
	carga.target = Card.Target.BATTLE_FRONT
	var attacker_targets: Array[Node] = [visual]
	carga.apply_effects(attacker_targets, atk_stats)

	assert_eq(front.attacker_bonuses.size(), 1,
		"El atacante tiene su propia táctica")
	assert_eq(front.defender_bonuses.size(), 1,
		"La táctica del defensor NO debe verse afectada")
	assert_eq(front.defender_bonuses[0]["tactic_name"], "Falange")
