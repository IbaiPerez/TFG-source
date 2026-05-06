extends GutTest

## Tests para TroopEffectiveness: matriz de matchups, multiplicadores
## y cálculo de ataque efectivo con composiciones mixtas.


func _make(troop_type: int, atk: int = 5) -> Troop:
	var t := Troop.new()
	t.name = "T"
	t.type = troop_type
	t.attack = atk
	t.defense = 0
	t.recruitment_cost_gold = 10
	t.maintenance_gold = 1
	t.maintenance_food = 1
	return t


# --- get_multiplier ---

func test_same_type_is_neutral() -> void:
	for v in Troop.TroopType.values():
		assert_eq(TroopEffectiveness.get_multiplier(v, v),
			TroopEffectiveness.MULTIPLIER_NEUTRAL,
			"Mismo tipo debe dar multiplicador neutro (1.0)")


func test_caballeria_strong_vs_a_distancia_and_ligera() -> void:
	assert_eq(TroopEffectiveness.get_multiplier(
		Troop.TroopType.CABALLERIA, Troop.TroopType.A_DISTANCIA),
		TroopEffectiveness.MULTIPLIER_STRONG)
	assert_eq(TroopEffectiveness.get_multiplier(
		Troop.TroopType.CABALLERIA, Troop.TroopType.INFANTERIA_LIGERA),
		TroopEffectiveness.MULTIPLIER_STRONG)


func test_caballeria_weak_vs_piqueros_and_pesada() -> void:
	assert_eq(TroopEffectiveness.get_multiplier(
		Troop.TroopType.CABALLERIA, Troop.TroopType.PIQUEROS),
		TroopEffectiveness.MULTIPLIER_WEAK)
	assert_eq(TroopEffectiveness.get_multiplier(
		Troop.TroopType.CABALLERIA, Troop.TroopType.INFANTERIA_PESADA),
		TroopEffectiveness.MULTIPLIER_WEAK)


func test_a_distancia_weak_vs_caballeria_strong_vs_ligera() -> void:
	# Matchup pedido por el diseño: tiradores son débiles vs caballería
	# y fuertes vs infantería ligera.
	assert_eq(TroopEffectiveness.get_multiplier(
		Troop.TroopType.A_DISTANCIA, Troop.TroopType.CABALLERIA),
		TroopEffectiveness.MULTIPLIER_WEAK)
	assert_eq(TroopEffectiveness.get_multiplier(
		Troop.TroopType.A_DISTANCIA, Troop.TroopType.INFANTERIA_LIGERA),
		TroopEffectiveness.MULTIPLIER_STRONG)


func test_piqueros_strong_vs_caballeria() -> void:
	# Clásico: las picas frenan a la caballería.
	assert_eq(TroopEffectiveness.get_multiplier(
		Troop.TroopType.PIQUEROS, Troop.TroopType.CABALLERIA),
		TroopEffectiveness.MULTIPLIER_STRONG)


func test_matrix_is_balanced_each_type_has_two_strong_two_weak() -> void:
	# Por construcción, cada tipo es fuerte vs los 2 siguientes en el ciclo
	# y débil vs los 2 anteriores. Total: 2 strong + 2 weak + 1 neutral.
	for atk_type in Troop.TroopType.values():
		var strong_count := 0
		var weak_count := 0
		for def_type in Troop.TroopType.values():
			if def_type == atk_type:
				continue
			var m := TroopEffectiveness.get_multiplier(atk_type, def_type)
			if m == TroopEffectiveness.MULTIPLIER_STRONG:
				strong_count += 1
			elif m == TroopEffectiveness.MULTIPLIER_WEAK:
				weak_count += 1
		assert_eq(strong_count, 2,
			"Cada tipo debe ser fuerte vs exactamente 2 tipos (tipo %d)" % atk_type)
		assert_eq(weak_count, 2,
			"Cada tipo debe ser débil vs exactamente 2 tipos (tipo %d)" % atk_type)


# --- get_effective_attack ---

func test_no_enemy_troops_returns_flat_sum() -> void:
	var mine: Array[Troop] = [_make(Troop.TroopType.CABALLERIA, 5), _make(Troop.TroopType.PIQUEROS, 3)]
	var enemy: Array[Troop] = []
	var eff := TroopEffectiveness.get_effective_attack(mine, enemy)
	assert_almost_eq(eff, 8.0, 0.001,
		"Sin enemigos, el atk efectivo es la suma plana (5+3=8)")


func test_no_own_troops_returns_zero() -> void:
	var mine: Array[Troop] = []
	var enemy: Array[Troop] = [_make(Troop.TroopType.CABALLERIA, 5)]
	assert_eq(TroopEffectiveness.get_effective_attack(mine, enemy), 0.0)


func test_pure_strong_matchup_applies_full_multiplier() -> void:
	# Caballería (atk 10) vs A Distancia → ×1.5 → 15.0
	var mine: Array[Troop] = [_make(Troop.TroopType.CABALLERIA, 10)]
	var enemy: Array[Troop] = [_make(Troop.TroopType.A_DISTANCIA, 1)]
	var eff := TroopEffectiveness.get_effective_attack(mine, enemy)
	assert_almost_eq(eff, 15.0, 0.001,
		"Matchup fuerte puro: 10 atk × 1.5 = 15")


func test_pure_weak_matchup_applies_full_multiplier() -> void:
	# Caballería (atk 10) vs Piqueros → ×0.7 → 7.0
	var mine: Array[Troop] = [_make(Troop.TroopType.CABALLERIA, 10)]
	var enemy: Array[Troop] = [_make(Troop.TroopType.PIQUEROS, 1)]
	var eff := TroopEffectiveness.get_effective_attack(mine, enemy)
	assert_almost_eq(eff, 7.0, 0.001,
		"Matchup débil puro: 10 atk × 0.7 = 7")


func test_neutral_matchup_unchanged() -> void:
	# Caballería vs Caballería = 1.0
	var mine: Array[Troop] = [_make(Troop.TroopType.CABALLERIA, 8)]
	var enemy: Array[Troop] = [_make(Troop.TroopType.CABALLERIA, 1)]
	var eff := TroopEffectiveness.get_effective_attack(mine, enemy)
	assert_almost_eq(eff, 8.0, 0.001)


func test_weighted_average_with_mixed_enemy_composition() -> void:
	# Caballería (atk 10) contra mezcla 50/50 de A Distancia (1.5) y Piqueros (0.7).
	# Multiplicador medio = 0.5*1.5 + 0.5*0.7 = 1.10
	# Atk efectivo = 10 * 1.10 = 11.0
	var mine: Array[Troop] = [_make(Troop.TroopType.CABALLERIA, 10)]
	var enemy: Array[Troop] = [
		_make(Troop.TroopType.A_DISTANCIA, 1),
		_make(Troop.TroopType.PIQUEROS, 1),
	]
	var eff := TroopEffectiveness.get_effective_attack(mine, enemy)
	assert_almost_eq(eff, 11.0, 0.001,
		"Promedio ponderado: 0.5*1.5 + 0.5*0.7 = 1.10 → 10*1.10")


func test_weighted_average_with_uneven_enemy_composition() -> void:
	# 1 A Distancia + 3 Piqueros (4 enemigos): pesos 0.25 y 0.75.
	# Multiplicador caballería = 0.25*1.5 + 0.75*0.7 = 0.375 + 0.525 = 0.9
	# Atk efectivo = 10 * 0.9 = 9.0
	var mine: Array[Troop] = [_make(Troop.TroopType.CABALLERIA, 10)]
	var enemy: Array[Troop] = [
		_make(Troop.TroopType.A_DISTANCIA, 1),
		_make(Troop.TroopType.PIQUEROS, 1),
		_make(Troop.TroopType.PIQUEROS, 1),
		_make(Troop.TroopType.PIQUEROS, 1),
	]
	var eff := TroopEffectiveness.get_effective_attack(mine, enemy)
	assert_almost_eq(eff, 9.0, 0.001,
		"La mayor proporción de Piqueros tira la efectividad media de la Caballería hacia abajo")


func test_mixed_own_lineup_each_troop_resolves_its_own_matchup() -> void:
	# Tropas propias: Caballería (10) y Piqueros (10).
	# Enemigos: 1 Caballería (peso 1.0).
	# Caballería propia vs Caballería = 1.0 → 10
	# Piqueros propia vs Caballería = 1.5 → 15
	# Total = 25
	var mine: Array[Troop] = [
		_make(Troop.TroopType.CABALLERIA, 10),
		_make(Troop.TroopType.PIQUEROS, 10),
	]
	var enemy: Array[Troop] = [_make(Troop.TroopType.CABALLERIA, 1)]
	var eff := TroopEffectiveness.get_effective_attack(mine, enemy)
	assert_almost_eq(eff, 25.0, 0.001,
		"Cada tropa propia aplica su propio multiplicador contra la mezcla enemiga")


# --- get_average_multiplier_against ---

func test_average_multiplier_no_enemies_is_neutral() -> void:
	assert_eq(TroopEffectiveness.get_average_multiplier_against(
		Troop.TroopType.CABALLERIA, []),
		TroopEffectiveness.MULTIPLIER_NEUTRAL)


func test_average_multiplier_pure_enemy() -> void:
	var enemy: Array[Troop] = [_make(Troop.TroopType.A_DISTANCIA, 1)]
	assert_eq(TroopEffectiveness.get_average_multiplier_against(
		Troop.TroopType.CABALLERIA, enemy),
		TroopEffectiveness.MULTIPLIER_STRONG)
