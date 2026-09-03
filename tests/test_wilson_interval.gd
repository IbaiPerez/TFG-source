extends GutTest

## El intervalo de confianza que sostiene la barrera del 50 % del optimizador.
##
## Es de WILSON, no de Wald, y el motivo salió corriendo el protocolo: con Wald,
## 0 victorias de 2 da √0 = 0 y el intervalo colapsa a [0, 0] — afirmando con
## "certeza" algo que dos partidas no pueden establecer. La barrera leía eso como
## derrota concluyente y descartaba candidatos por puro ruido.


func test_con_muestra_diminuta_no_concluye_nada() -> void:
	# EL caso que rompía la barrera. 0 de 2 no permite afirmar que se pierde.
	var ci := HeuristicFitness.wilson_interval(0, 2)
	assert_gt(ci.y, 0.5,
		"con 0 de 2 el extremo superior debe seguir por encima del 50 %%: no se concluye")


func test_con_muestra_grande_una_derrota_clara_si_concluye() -> void:
	# 0 de 160 sí es una derrota: la barrera tiene que morder aquí.
	var ci := HeuristicFitness.wilson_interval(0, 160)
	assert_lt(ci.y, 0.5, "con 0 de 160 la derrota es concluyente")


func test_el_intervalo_nunca_colapsa_a_un_punto() -> void:
	# La patología de Wald en los extremos: p=0 y p=1 daban anchura cero.
	for n in [1, 2, 8, 40]:
		for wins in [0, n]:
			var ci := HeuristicFitness.wilson_interval(wins, n)
			assert_gt(ci.y - ci.x, 0.0,
				"n=%d wins=%d: el intervalo no puede tener anchura cero" % [n, wins])


func test_un_candidato_parejo_no_cuenta_como_derrota() -> void:
	# Justo por debajo del 50 % con muestra grande: es ruido, no derrota.
	var ci := HeuristicFitness.wilson_interval(78, 160)   # 0.4875
	assert_gt(ci.y, 0.5, "estar rozando el 50 %% no debe contar como perder")


func test_detecta_una_derrota_real_moderada() -> void:
	# Con 160 decisivas la barrera detecta win-rate real por debajo de ~0.42.
	var ci := HeuristicFitness.wilson_interval(64, 160)   # 0.40
	assert_lt(ci.y, 0.5, "un 40 %% sostenido en 160 partidas sí es una derrota")


func test_el_intervalo_se_estrecha_con_mas_partidas() -> void:
	var ancho_previo := 2.0
	for n in [4, 20, 100, 400]:
		var ci := HeuristicFitness.wilson_interval(int(n / 2), n)
		var ancho := ci.y - ci.x
		assert_lt(ancho, ancho_previo, "con n=%d el intervalo debe ser más estrecho" % n)
		ancho_previo = ancho


func test_contiene_siempre_la_proporcion_observada() -> void:
	for n in [3, 10, 57, 200]:
		for wins in [0, 1, int(n / 2), n - 1, n]:
			var ci := HeuristicFitness.wilson_interval(wins, n)
			var p := float(wins) / float(n)
			assert_between(p, ci.x - 0.0001, ci.y + 0.0001,
				"n=%d wins=%d: el intervalo debe contener la proporción" % [n, wins])


func test_sin_partidas_no_afirma_nada() -> void:
	var ci := HeuristicFitness.wilson_interval(0, 0)
	assert_almost_eq(ci.x, 0.0, 0.001)
	assert_almost_eq(ci.y, 1.0, 0.001)
