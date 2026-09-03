extends GutTest

## `TopCandidates`: los K mejores DISTINTOS que ve un optimizador.
##
## Sustituye al `best_weights` único. El motivo es de método: quedarse con el
## argmax del pool de BÚSQUEDA es el paso de sobreajuste, porque ese candidato es
## por construcción el más afinado a esos rivales concretos. Pasando K, la
## decisión final la toma el pool held-out.


func _w(marca: float) -> HeuristicWeights:
	var w := HeuristicWeights.new()
	w.gold_weight_pos = marca      # marca reconocible para identificarlo después
	return w


func test_guarda_los_k_mejores_ordenados() -> void:
	var top := TopCandidates.new(3)
	for i in range(6):
		top.offer(_w(float(i)), float(i) / 10.0, "c%d" % i)
	assert_eq(top.size(), 3, "solo caben 3")
	var arr := top.to_array()
	assert_almost_eq(float(arr[0]["fitness"]), 0.5, 0.001, "el mejor primero")
	assert_almost_eq(float(arr[1]["fitness"]), 0.4, 0.001)
	assert_almost_eq(float(arr[2]["fitness"]), 0.3, 0.001)


func test_descarta_los_peores_aunque_lleguen_despues() -> void:
	var top := TopCandidates.new(2)
	top.offer(_w(1.0), 0.9, "bueno")
	top.offer(_w(2.0), 0.8, "medio")
	top.offer(_w(3.0), 0.1, "malo")
	assert_eq(top.size(), 2)
	assert_almost_eq(top.best_fitness(), 0.9, 0.001)


func test_deduplica_por_clave() -> void:
	# EL caso real: la élite del GA pasa intacta entre generaciones y SA revisita
	# puntos, así que sin deduplicar el top-K serían K copias del mismo candidato
	# y la etapa 2 no tendría nada que arbitrar.
	var top := TopCandidates.new(3)
	for i in range(5):
		top.offer(_w(1.0), 0.9, "el_mismo")
	assert_eq(top.size(), 1, "el mismo candidato no ocupa cinco huecos")


func test_el_mejor_coincide_con_el_primero() -> void:
	var top := TopCandidates.new(4)
	top.offer(_w(1.0), 0.3, "a")
	top.offer(_w(2.0), 0.7, "b")
	top.offer(_w(3.0), 0.5, "c")
	assert_almost_eq(top.best_fitness(), 0.7, 0.001)
	assert_almost_eq(top.best().gold_weight_pos, 2.0, 0.001,
		"best() devuelve los pesos del de mayor fitness")


func test_guarda_una_copia_no_una_referencia() -> void:
	# Si guardara la referencia, mutar el candidato después (SA reutiliza objetos)
	# corrompería el top-K en silencio.
	var w := _w(5.0)
	var top := TopCandidates.new(2)
	top.offer(w, 0.9, "x")
	w.gold_weight_pos = 999.0
	assert_almost_eq(top.best().gold_weight_pos, 5.0, 0.001,
		"el top-K debe conservar el valor que tenía al ofrecerlo")


func test_vacio_devuelve_null_sin_reventar() -> void:
	var top := TopCandidates.new(3)
	assert_eq(top.size(), 0)
	assert_null(top.best())
	assert_almost_eq(top.best_fitness(), -1.0, 0.001)
