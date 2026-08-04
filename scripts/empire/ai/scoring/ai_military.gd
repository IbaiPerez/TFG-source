extends RefCounted
class_name AIMilitary

## Bonos militares de la heurística (complementariedad de tropas y counter de matchup),
## escritos UNA sola vez. Antes vivían DUPLICADOS en AIHeuristic
## (estado vivo) y AIRealEvalStrong (snapshot). Son funciones PURAS: el pool es
## `Array[Troop]` en ambos mundos (Troop es una clase compartida), así que la
## complementariedad se comparte tal cual; el counter se parametriza por la lista de
## tipos rivales que cada mundo recolecta de sus frentes (BattleFront vs FrontSnap).


## Bonus de complementariedad [1.0, complement_bonus_hi]: favorece tropas que
## equilibran el balance atk/def del pool propio. Pool vacío → 1.0 (nada que
## equilibrar). Solo una de las cuatro ramas puede aplicar (if/elif encadenados).
static func complement_bonus(troop: Troop, pool: Array[Troop], w: HeuristicWeights) -> float:
	if pool.is_empty():
		return 1.0
	var total_atk := 0
	var total_def := 0
	for t in pool:
		total_atk += t.attack
		total_def += t.defense
	var pool_ratio := float(total_atk) / maxf(float(total_def), 1.0)
	var troop_ratio := float(troop.attack) / maxf(float(troop.defense), 1.0)
	if pool_ratio > w.complement_pool_hi and troop_ratio < w.complement_troop_lo:
		return w.complement_bonus_hi
	elif pool_ratio > w.complement_pool_mid and troop_ratio < w.complement_troop_mid:
		return w.complement_bonus_mid
	elif pool_ratio < w.complement_pool_lo and troop_ratio > w.complement_troop_hi:
		return w.complement_bonus_hi
	elif pool_ratio < w.complement_pool_lomid and troop_ratio > w.complement_troop_mid:
		return w.complement_bonus_mid
	return 1.0


## Counter-bonus: `counter_bonus` si `troop_type` es FUERTE (≥ MULTIPLIER_STRONG)
## contra algún tipo visible del rival; si no, 1.0. `rival_types` vacío → 1.0.
## Cada mundo recolecta rival_types de sus frentes activos y lo pasa aquí.
static func counter_bonus(troop_type: int, rival_types: Array[int], w: HeuristicWeights) -> float:
	for rt in rival_types:
		if TroopEffectiveness.get_multiplier(troop_type, rt) >= TroopEffectiveness.MULTIPLIER_STRONG:
			return w.counter_bonus
	return 1.0
