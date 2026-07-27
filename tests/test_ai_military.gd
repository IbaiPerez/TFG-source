extends GutTest

## Tests de AIMilitary: complementariedad de tropas y counter de matchup, unificados
## (refactor C4 §1.3.e). Antes vivían duplicados en AIHeuristic (estado vivo) y
## AIRealEvalStrong (snapshot). La paridad a alto nivel la cubren además
## test_ai_heuristic_extended (_complement_bonus con 2 args) y test_ai_real_eval_strong.


func _w() -> HeuristicWeights:
	return HeuristicWeights.new()


func _troop(atk: int, def: int, type := Troop.TroopType.INFANTERIA_LIGERA) -> Troop:
	var t := Troop.new()
	t.attack = atk
	t.defense = def
	t.type = type
	return t


# ------------------------------------------------------------------
#  Complementariedad
# ------------------------------------------------------------------

func test_complement_empty_pool_is_neutral() -> void:
	var pool: Array[Troop] = []
	assert_almost_eq(AIMilitary.complement_bonus(_troop(5, 5), pool, _w()), 1.0, 0.001)


func test_complement_defensive_troop_when_pool_is_attack_heavy() -> void:
	# Pool ratio 20/2 = 10 (>2.0) + tropa muy defensiva (0/10=0 <0.8) → bonus_hi 2.0.
	var pool: Array[Troop] = [_troop(10, 1), _troop(10, 1)]
	assert_almost_eq(AIMilitary.complement_bonus(_troop(0, 10), pool, _w()), 2.0, 0.001)


func test_complement_attack_troop_when_pool_is_defense_heavy() -> void:
	# Pool ratio 2/20 = 0.1 (<0.5) + tropa muy ofensiva (10/1=10 >1.2) → bonus_hi 2.0.
	var pool: Array[Troop] = [_troop(1, 10), _troop(1, 10)]
	assert_almost_eq(AIMilitary.complement_bonus(_troop(10, 1), pool, _w()), 2.0, 0.001)


func test_complement_mid_band() -> void:
	# Pool ratio 16/10 = 1.6 (>1.5, no >2.0) + tropa 8/10 = 0.8 (<1.0) → bonus_mid 1.5.
	var pool: Array[Troop] = [_troop(8, 5), _troop(8, 5)]
	assert_almost_eq(AIMilitary.complement_bonus(_troop(8, 10), pool, _w()), 1.5, 0.001)


func test_complement_balanced_is_neutral() -> void:
	# Pool ratio 1.0 + tropa 1.0 → ninguna rama → 1.0.
	var pool: Array[Troop] = [_troop(5, 5), _troop(5, 5)]
	assert_almost_eq(AIMilitary.complement_bonus(_troop(5, 5), pool, _w()), 1.0, 0.001)


# ------------------------------------------------------------------
#  Counter de matchup
# ------------------------------------------------------------------

func test_counter_empty_rivals_is_neutral() -> void:
	var empty: Array[int] = []
	assert_almost_eq(AIMilitary.counter_bonus(Troop.TroopType.CABALLERIA, empty, _w()), 1.0, 0.001)


func test_counter_applies_when_strong_against_a_visible_type() -> void:
	# CABALLERIA es FUERTE (1.5) contra A_DISTANCIA → counter_bonus 1.5.
	var rivals: Array[int] = [Troop.TroopType.A_DISTANCIA]
	assert_almost_eq(AIMilitary.counter_bonus(Troop.TroopType.CABALLERIA, rivals, _w()), 1.5, 0.001)


func test_counter_neutral_when_not_strong() -> void:
	# CABALLERIA es DÉBIL contra PIQUEROS → sin counter (1.0).
	var rivals: Array[int] = [Troop.TroopType.PIQUEROS]
	assert_almost_eq(AIMilitary.counter_bonus(Troop.TroopType.CABALLERIA, rivals, _w()), 1.0, 0.001)


func test_counter_applies_if_any_rival_type_is_countered() -> void:
	# Basta con que UN tipo de la lista sea contrarrestado (A_DISTANCIA lo es).
	var rivals: Array[int] = [Troop.TroopType.PIQUEROS, Troop.TroopType.A_DISTANCIA]
	assert_almost_eq(AIMilitary.counter_bonus(Troop.TroopType.CABALLERIA, rivals, _w()), 1.5, 0.001)
