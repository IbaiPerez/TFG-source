extends GutTest

## Tests de AIMilitary: complementariedad de tropas y counter de matchup.
##
## Las aserciones van contra el CAMPO DE PESO (w.complement_bonus_hi,
## w.counter_bonus) y las entradas se construyen a partir de los UMBRALES
## (w.complement_pool_hi…), no de números elegidos a mano que casualmente caen en
## la banda. Así el test dice en qué banda debe caer cada caso, que es la regla, y
## no se rompe cuando el optimizador reajusta los defaults.
##
## `1.0` se deja literal: no es un peso, es la identidad "sin bonus".

const NEUTRO := 1.0


func _w() -> HeuristicWeights:
	return HeuristicWeights.new()


func _troop(atk: int, def: int, type := Troop.TroopType.INFANTERIA_LIGERA) -> Troop:
	var t := Troop.new()
	t.attack = atk
	t.defense = def
	t.type = type
	return t


## Pool con el ratio atk/def pedido, construido desde el umbral en vez de a ojo.
func _pool_con_ratio(ratio: float) -> Array[Troop]:
	var defensa := 10
	var pool: Array[Troop] = [_troop(int(round(defensa * ratio)), defensa)]
	return pool


# ------------------------------------------------------------------
#  Complementariedad
# ------------------------------------------------------------------

func test_complement_empty_pool_is_neutral() -> void:
	var pool: Array[Troop] = []
	assert_almost_eq(AIMilitary.complement_bonus(_troop(5, 5), pool, _w()), NEUTRO, 0.001)


func test_complement_defensive_troop_when_pool_is_attack_heavy() -> void:
	var w := _w()
	# Pool muy ofensivo (por encima del umbral alto) + tropa muy defensiva (por
	# debajo del umbral bajo) → la rama de bonus máximo.
	var pool := _pool_con_ratio(w.complement_pool_hi * 2.0)
	var tropa := _troop(0, 10)   # ratio 0, siempre bajo el umbral
	assert_almost_eq(AIMilitary.complement_bonus(tropa, pool, w),
		w.complement_bonus_hi, 0.001)


func test_complement_attack_troop_when_pool_is_defense_heavy() -> void:
	var w := _w()
	# Caso simétrico: pool muy defensivo + tropa muy ofensiva → bonus máximo.
	var pool := _pool_con_ratio(w.complement_pool_lo * 0.5)
	var tropa := _troop(int(w.complement_troop_hi * 10.0), 1)
	assert_almost_eq(AIMilitary.complement_bonus(tropa, pool, w),
		w.complement_bonus_hi, 0.001)


func test_complement_mid_band() -> void:
	var w := _w()
	# Entre el umbral medio y el alto → bonus intermedio, no el máximo.
	var pool := _pool_con_ratio((w.complement_pool_mid + w.complement_pool_hi) / 2.0)
	var tropa := _troop(8, 10)   # ratio 0.8: bajo el umbral medio, sobre el bajo
	assert_almost_eq(AIMilitary.complement_bonus(tropa, pool, w),
		w.complement_bonus_mid, 0.001)


func test_complement_balanced_is_neutral() -> void:
	# Pool equilibrado y tropa equilibrada: no hay nada que compensar.
	var pool: Array[Troop] = [_troop(5, 5), _troop(5, 5)]
	assert_almost_eq(AIMilitary.complement_bonus(_troop(5, 5), pool, _w()), NEUTRO, 0.001)


func test_complement_el_bonus_alto_supera_al_medio() -> void:
	# Fija el ORDEN de las bandas, que es lo que da sentido a tener dos.
	var w := _w()
	assert_gt(w.complement_bonus_hi, w.complement_bonus_mid)
	assert_gt(w.complement_bonus_mid, NEUTRO)


# ------------------------------------------------------------------
#  Counter de matchup
# ------------------------------------------------------------------

func test_counter_empty_rivals_is_neutral() -> void:
	var empty: Array[int] = []
	assert_almost_eq(AIMilitary.counter_bonus(Troop.TroopType.CABALLERIA, empty, _w()),
		NEUTRO, 0.001)


func test_counter_applies_when_strong_against_a_visible_type() -> void:
	# CABALLERIA es FUERTE contra A_DISTANCIA. La premisa se comprueba, no se asume:
	# si la matriz de efectividad cambiara, el test lo diría en vez de fallar por
	# una razón que parece otra.
	assert_gte(TroopEffectiveness.get_multiplier(
		Troop.TroopType.CABALLERIA, Troop.TroopType.A_DISTANCIA),
		TroopEffectiveness.MULTIPLIER_STRONG,
		"premisa: caballería contrarresta a distancia")

	var rivals: Array[int] = [Troop.TroopType.A_DISTANCIA]
	assert_almost_eq(AIMilitary.counter_bonus(Troop.TroopType.CABALLERIA, rivals, _w()),
		_w().counter_bonus, 0.001)


func test_counter_neutral_when_not_strong() -> void:
	assert_lt(TroopEffectiveness.get_multiplier(
		Troop.TroopType.CABALLERIA, Troop.TroopType.PIQUEROS),
		TroopEffectiveness.MULTIPLIER_STRONG,
		"premisa: caballería NO contrarresta piqueros")

	var rivals: Array[int] = [Troop.TroopType.PIQUEROS]
	assert_almost_eq(AIMilitary.counter_bonus(Troop.TroopType.CABALLERIA, rivals, _w()),
		NEUTRO, 0.001)


func test_counter_applies_if_any_rival_type_is_countered() -> void:
	# Basta con que UN tipo de la lista sea contrarrestado, aunque el otro no.
	var rivals: Array[int] = [Troop.TroopType.PIQUEROS, Troop.TroopType.A_DISTANCIA]
	assert_almost_eq(AIMilitary.counter_bonus(Troop.TroopType.CABALLERIA, rivals, _w()),
		_w().counter_bonus, 0.001)
