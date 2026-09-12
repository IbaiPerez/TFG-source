extends GutTest

## Regla de VICTORIA (`VictoryRules`), la que comparten `TurnManager` y el arnés
## de simulación. Hasta ahora no la probaba nada: el arnés llevaba una copia con
## el umbral escrito a mano y `TurnManager._check_victory` no tenía tests.
##
## Las entradas se DERIVAN de `GameBalance.VICTORY_TILE_SHARE`, no se escriben:
## si el umbral cambia, los tests siguen describiendo la regla.

const TOTAL := 100


func _empire_with(n_tiles: int, name: String) -> Empire:
	var tiles: Array = []
	for _i in range(n_tiles):
		var t := TestBuilders.tile().build()
		add_child_autofree(t)
		tiles.append(t)
	var stats := TestBuilders.stats().with_tiles(tiles) \
		.with_empire(TestBuilders.empire().with_name(name).build()).build()
	return stats.empire


## Mínimo de casillas que da la dominación en un mapa de TOTAL.
func _dominating_count() -> int:
	return int(ceil(GameBalance.VICTORY_TILE_SHARE * TOTAL))


func test_sin_mapa_no_hay_ganador() -> void:
	var a := _empire_with(5, "A")
	var b := _empire_with(0, "B")
	assert_true(VictoryRules.check([a, b] as Array[Empire], 0).is_empty(),
		"con 0 casillas en el mapa la regla no decide nada")


func test_con_los_dos_vivos_y_por_debajo_del_umbral_la_partida_sigue() -> void:
	var a := _empire_with(_dominating_count() - 1, "A")
	var b := _empire_with(1, "B")
	assert_true(VictoryRules.check([a, b] as Array[Empire], TOTAL).is_empty())


func test_eliminacion_cuando_solo_uno_conserva_casillas() -> void:
	var a := _empire_with(3, "A")
	var b := _empire_with(0, "B")
	var r := VictoryRules.check([a, b] as Array[Empire], TOTAL)
	assert_eq(r.get("winner"), a)
	assert_eq(r.get("condition"), VictoryRules.ELIMINATION)


func test_eliminacion_no_depende_del_orden() -> void:
	var a := _empire_with(0, "A")
	var b := _empire_with(3, "B")
	var r := VictoryRules.check([a, b] as Array[Empire], TOTAL)
	assert_eq(r.get("winner"), b)
	assert_eq(r.get("condition"), VictoryRules.ELIMINATION)


func test_dominacion_justo_en_el_umbral() -> void:
	var a := _empire_with(_dominating_count(), "A")
	var b := _empire_with(1, "B")
	var r := VictoryRules.check([a, b] as Array[Empire], TOTAL)
	assert_eq(r.get("winner"), a)
	assert_eq(r.get("condition"), VictoryRules.DOMINATION)


func test_una_casilla_por_debajo_del_umbral_no_domina() -> void:
	var a := _empire_with(_dominating_count() - 1, "A")
	var b := _empire_with(1, "B")
	assert_true(VictoryRules.check([a, b] as Array[Empire], TOTAL).is_empty())


func test_la_eliminacion_tiene_prioridad_sobre_la_dominacion() -> void:
	# A controla todo el mapa: cumple las dos. Se reporta eliminación, que es
	# la que describe lo que ha pasado.
	var a := _empire_with(TOTAL, "A")
	var b := _empire_with(0, "B")
	var r := VictoryRules.check([a, b] as Array[Empire], TOTAL)
	assert_eq(r.get("condition"), VictoryRules.ELIMINATION)


func test_el_umbral_es_el_de_game_balance() -> void:
	# Sanidad del propio test: la cuota debe estar en (0, 1] para que las
	# entradas derivadas tengan sentido.
	assert_gt(GameBalance.VICTORY_TILE_SHARE, 0.0)
	assert_lte(GameBalance.VICTORY_TILE_SHARE, 1.0)
	assert_gt(_dominating_count(), 1)
