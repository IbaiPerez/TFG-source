extends GutTest

## Parámetros que hay que mover JUNTOS, y la reparación de los que van en cadena.
##
## El optimizador trataba cada peso como una dimensión independiente. Eso falla de
## tres maneras, y las tres están documentadas con datos, no supuestas:
##
##  · SUSTITUTOS. Las dos condiciones de LATE van unidas por un `or`. Medido sobre
##    3194 snapshots: subir solo la cuota mueve el reparto de fases 17 puntos, subir
##    solo el gpt lo mueve 2.6, subir las dos lo mueve 49. Y SA perturba 3 de más de
##    60 dimensiones, así que la probabilidad de tocar justo ese par es ~0.1 % por
##    paso: nunca lo exploraba.
##  · CADENAS ORDENADAS. `heuristic_weights_optimized.tres` —el campeón que se
##    juega— tiene `encircle_min` en 2.57 por debajo de `encircle_low` 6.17. El
##    gradiente «cuanto más rodeado, más incentivo a escapar» se rompió porque nada
##    lo protegía.
##  · SEMÁNTICA INVERTIDA. En `complement_bonus`, cruzar una cadena NO deja ninguna
##    rama inalcanzable —se comprobó, cada rama se alcanza también por el otro eje—
##    pero sí invierte el sentido: el tramo estricto deja de dar el bonus mayor.
##
## Lo que se afirma aquí es el CONTRATO: un bloque se mueve entero, y todo candidato
## que sale del espacio de búsqueda es coherente.


func _w() -> HeuristicWeights:
	return HeuristicWeights.new()


func _espacio(claves: PackedStringArray, semilla: int = 7) -> SearchSpace:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	return SearchSpace.new(claves, rng)


# ---------------------------------------------------------------------------
# Los bloques declarados
# ---------------------------------------------------------------------------

func test_las_dos_condiciones_de_late_son_el_mismo_bloque() -> void:
	assert_eq(HeuristicWeightsInvariants.block_of("phase_late_share"),
		HeuristicWeightsInvariants.block_of("phase_late_gpt"),
		"unidas por un `or`, mover una sola no cambia la fase")
	assert_ne(HeuristicWeightsInvariants.block_of("phase_late_share"), "",
		"y ese bloque tiene que existir")


func test_un_peso_suelto_no_pertenece_a_ningun_bloque() -> void:
	assert_eq(HeuristicWeightsInvariants.block_of("gold_weight_pos"), "",
		"la mayoría de pesos son independientes y deben seguir siéndolo")
	assert_eq(HeuristicWeightsInvariants.block_peers("gold_weight_pos"),
		PackedStringArray(["gold_weight_pos"]),
		"sin bloque, sus «compañeras» son solo él")


func test_ninguna_clave_esta_en_dos_bloques() -> void:
	# Si una clave cayera en dos grupos, el índice inverso se quedaría con uno y el
	# otro no movería nunca a su compañera.
	var vistas := {}
	for nombre in HeuristicWeightsInvariants.BLOCKS:
		for k in HeuristicWeightsInvariants.BLOCKS[nombre]:
			assert_false(vistas.has(k),
				"%s aparece en %s y en %s" % [k, vistas.get(k, ""), nombre])
			vistas[k] = nombre


func test_todas_las_claves_de_bloque_existen_como_peso() -> void:
	# Un nombre mal escrito aquí no da error de parseo: el bloque simplemente no
	# movería nada, en silencio.
	var w := _w()
	for nombre in HeuristicWeightsInvariants.BLOCKS:
		for k in HeuristicWeightsInvariants.BLOCKS[nombre]:
			assert_true(w.get(k) != null, "%s (bloque %s) no es un @export de HeuristicWeights"
				% [k, nombre])


# ---------------------------------------------------------------------------
# El bloque se mueve entero
# ---------------------------------------------------------------------------

func test_perturbar_una_dimension_del_bloque_mueve_a_su_companera() -> void:
	# EL test que discrimina. Con una sola dimensión perturbada de las dos del
	# bloque, las DOS tienen que cambiar.
	var claves := PackedStringArray(["phase_late_share", "phase_late_gpt"])
	var espacio := _espacio(claves)
	var v := espacio.vector_of(_w())
	var out := espacio.perturb_dims(v, 0.15, 1)
	assert_ne(out[0], v[0], "la cuota de LATE debe moverse")
	assert_ne(out[1], v[1], "y el gpt de LATE con ella, aunque no se eligiera")


func test_el_bloque_se_mueve_en_la_misma_direccion() -> void:
	# No basta con que se muevan las dos: tienen que ir hacia el mismo lado, o el
	# movimiento conjunto no significa «desplazar la frontera».
	var claves := PackedStringArray(["phase_late_share", "phase_late_gpt"])
	var v := _espacio(claves).vector_of(_w())
	var iguales := 0
	for semilla in range(20):
		var out := _espacio(claves, semilla).perturb_dims(v, 0.15, 1)
		if signf(out[0] - v[0]) == signf(out[1] - v[1]):
			iguales += 1
	assert_eq(iguales, 20, "las dos componentes del bloque deben moverse en el mismo sentido")


func test_una_dimension_suelta_no_arrastra_a_nadie() -> void:
	var claves := PackedStringArray(["gold_weight_pos", "food_weight", "defense_weight"])
	var espacio := _espacio(claves)
	var v := espacio.vector_of(_w())
	var out := espacio.perturb_dims(v, 0.15, 1)
	var movidas := 0
	for i in range(v.size()):
		if out[i] != v[i]:
			movidas += 1
	assert_eq(movidas, 1, "sin bloque, una perturbación mueve exactamente una dimensión")


func test_el_bloque_no_arrastra_claves_fuera_del_espacio() -> void:
	# Optimizar un subconjunto de claves no debe tocar las que quedaron fuera: el
	# vector solo tiene las suyas y escribir fuera de rango reventaría.
	var claves := PackedStringArray(["phase_late_share", "gold_weight_pos"])
	var espacio := _espacio(claves)
	var v := espacio.vector_of(_w())
	var out := espacio.perturb_dims(v, 0.15, 2)
	assert_eq(out.size(), 2, "el vector conserva su tamaño")


# ---------------------------------------------------------------------------
# Reparación de las cadenas
# ---------------------------------------------------------------------------

func test_repair_endereza_el_gradiente_de_encierro() -> void:
	# El caso REAL: así está el campeón que se juega.
	var w := _w()
	w.encircle_high = 1.81
	w.encircle_mid = 4.24
	w.encircle_low = 6.17
	w.encircle_min = 2.57      # roto: el caso más grave incentiva MENOS
	assert_gt(HeuristicWeightsInvariants.repair(w), 0, "debe tocar algo")
	assert_gte(w.encircle_mid, w.encircle_high, "el gradiente crece con el encierro")
	assert_gte(w.encircle_low, w.encircle_mid)
	assert_gte(w.encircle_min, w.encircle_low,
		"estar rodeado del todo debe incentivar lo máximo")


func test_repair_conserva_el_conjunto_de_valores() -> void:
	# Reparar ORDENA, no inventa: los cuatro números siguen ahí, en otro sitio. Si
	# clampease o promediase estaría tirando la exploración del optimizador.
	var w := _w()
	w.encircle_high = 1.81; w.encircle_mid = 4.24
	w.encircle_low = 6.17;  w.encircle_min = 2.57
	HeuristicWeightsInvariants.repair(w)
	var despues := [w.encircle_high, w.encircle_mid, w.encircle_low, w.encircle_min]
	despues.sort()
	assert_almost_eq(float(despues[0]), 1.81, 0.001)
	assert_almost_eq(float(despues[1]), 2.57, 0.001)
	assert_almost_eq(float(despues[2]), 4.24, 0.001)
	assert_almost_eq(float(despues[3]), 6.17, 0.001)


func test_repair_endereza_los_umbrales_decrecientes_del_encierro() -> void:
	var w := _w()
	w.encircle_r2 = 0.4; w.encircle_r1 = 2.5; w.encircle_r05 = 1.0
	HeuristicWeightsInvariants.repair(w)
	assert_gte(w.encircle_r2, w.encircle_r1, "los ratios se leen de mayor a menor")
	assert_gte(w.encircle_r1, w.encircle_r05)


func test_repair_endereza_la_cadena_de_complementariedad() -> void:
	var w := _w()
	w.complement_pool_hi = 0.3    # cruzado con los de abajo
	w.complement_pool_mid = 1.5
	w.complement_pool_lomid = 0.8
	w.complement_pool_lo = 2.4
	HeuristicWeightsInvariants.repair(w)
	# Son DOS pares por eje, no una cadena de cuatro: `hi`/`mid` son umbrales por
	# arriba y `lomid`/`lo` por abajo. Exigir `mid >= lomid` recortaría el espacio
	# de búsqueda sin motivo — es una configuración legítima.
	assert_gte(w.complement_pool_hi, w.complement_pool_mid,
		"el par de arriba se lee de la condición más fuerte a la más débil")
	assert_gte(w.complement_pool_lomid, w.complement_pool_lo,
		"y el par de abajo igual")

	w.complement_troop_lo = 1.4; w.complement_troop_mid = 1.0; w.complement_troop_hi = 0.7
	HeuristicWeightsInvariants.repair(w)
	assert_lte(w.complement_troop_lo, w.complement_troop_mid)
	assert_lte(w.complement_troop_mid, w.complement_troop_hi)


func test_repair_separa_las_fronteras_de_fase_cruzadas() -> void:
	# Aquí no basta con ordenar: iguales, la banda de en medio se queda sin ningún
	# estado posible. El orden tiene que ser ESTRICTO.
	var w := _w()
	w.phase_early_share = 0.70
	w.phase_late_share = 0.30
	w.phase_early_gpt = 2000.0
	w.phase_late_gpt = 500.0
	HeuristicWeightsInvariants.repair(w)
	assert_lt(w.phase_early_share, w.phase_late_share, "EARLY debe quedar por debajo de LATE")
	assert_lt(w.phase_early_gpt, w.phase_late_gpt)


func test_repair_no_toca_lo_que_ya_esta_bien() -> void:
	assert_eq(HeuristicWeightsInvariants.repair(_w()), 0,
		"los pesos por defecto ya son coherentes: reparar no debe moverlos")


func test_repair_no_impone_orden_donde_la_asimetria_es_intencional() -> void:
	# `openfront_econ_late_gpt` (50) es MENOR que el de MID (150) a propósito: en
	# late game el frente es el camino a la victoria y merece más tolerancia. El
	# bloque los escala juntos pero no los ordena.
	var w := _w()
	var antes := w.openfront_econ_late_gpt
	HeuristicWeightsInvariants.repair(w)
	assert_eq(w.openfront_econ_late_gpt, antes,
		"el gate económico del frente no es una cadena ordenada")
	assert_lt(w.openfront_econ_late_gpt, w.openfront_econ_mid_gpt,
		"y la asimetría de diseño sigue en pie")


# ---------------------------------------------------------------------------
# El contrato de extremo a extremo
# ---------------------------------------------------------------------------

func test_todo_candidato_que_sale_del_espacio_es_coherente() -> void:
	# LA garantía. `validate` es el juez y `repair` el que responde: después de
	# reparar, validar no puede encontrar nada. Se prueba con candidatos generados
	# al azar, que es como los produce el optimizador. 80 rondas · 12 dims por
	# ronda sobre las 132 del espacio completo: suficiente para pisar cada una de
	# las nueve cadenas al menos una vez con margen.
	var espacio := _espacio(HeuristicWeightsSpec.OPTIMIZABLE_KEYS, 20260901)
	var base := _w()
	for i in range(80):
		var v := espacio.perturb_dims(espacio.vector_of(base), 0.6, 12)
		var cand := espacio.apply(base, v)
		var errores := HeuristicWeightsInvariants.validate(cand)
		assert_eq(errores.size(), 0,
			"candidato %d incoherente tras reparar: %s" % [i, ", ".join(errores)])


func test_las_nueve_cadenas_de_urgencia_sobreviven_a_una_perturbacion_agresiva() -> void:
	# Directo: perturbar TODAS las claves de las seis cadenas de urgencia a la vez,
	# con ruido grande, y comprobar que sigue validando. Si `repair` olvidara una
	# cadena, esta es la prueba que lo vería.
	var claves := PackedStringArray()
	for prefijo in ["gold_urg_early", "gold_urg_mid", "gold_urg_late",
			"food_urg_early", "food_urg_mid", "food_urg_late"]:
		for k in HeuristicWeightsInvariants.BLOCKS.get(prefijo + "_thresholds", []):
			claves.append(k)
	for k in HeuristicWeightsInvariants.BLOCKS["deck_urg_thresholds"]:
		claves.append(k)
	assert_eq(claves.size(), 3 + 4 + 7 + 3 + 3 + 3 + 2, "se han recogido todas las cadenas")

	var espacio := _espacio(claves, 99)
	var base := _w()
	for i in range(30):
		var v := espacio.perturb_dims(espacio.vector_of(base), 1.0, claves.size())
		var cand := espacio.apply(base, v)
		var errores := HeuristicWeightsInvariants.validate(cand)
		assert_eq(errores.size(), 0, "ronda %d: %s" % [i, ", ".join(errores)])


func test_el_campeon_del_repo_se_repara_al_entrar_en_la_busqueda() -> void:
	# El campeón vigente viola el gradiente de encierro. Arrancar una corrida desde
	# él sin reparar metería la incoherencia en toda la búsqueda.
	var champ := load("res://resources/ai/heuristic_weights_optimized.tres") as HeuristicWeights
	assert_not_null(champ, "el campeón debe cargar")
	var copia := champ.clone()
	assert_gt(HeuristicWeightsInvariants.repair(copia), 0,
		"el campeón tiene al menos una cadena desordenada")
	assert_eq(HeuristicWeightsInvariants.validate(copia).size(), 0,
		"y tras repararlo debe validar")


# ---------------------------------------------------------------------------
# Bloque económico: los umbrales dispersos que ahora se mueven juntos
# ---------------------------------------------------------------------------

func test_los_umbrales_economicos_ya_son_optimizables() -> void:
	# Estaban fuera del espacio, así que el desfase de escala que arrastraban no
	# había forma de corregirlo por optimización.
	var keys := HeuristicWeightsSpec.OPTIMIZABLE_KEYS
	for k in ["surplus_comfortable_early", "surplus_comfortable_mid",
			"surplus_comfortable_late", "openfront_econ_early_gpt",
			"openfront_econ_mid_gpt", "openfront_econ_late_gpt", "surplus_min_food"]:
		assert_true(keys.has(k), "%s debe entrar en el espacio de búsqueda" % k)


func test_los_umbrales_de_gpt_de_las_tres_familias_van_en_el_mismo_bloque() -> void:
	# El hallazgo: TRES sitios distintos preguntan «¿va bien mi economía?» en gpt y
	# ninguno se entera de los otros. Ahora se desplazan juntos.
	var b := HeuristicWeightsInvariants.block_of("surplus_comfortable_mid")
	assert_ne(b, "", "el excedente económico debe estar en un bloque")
	assert_eq(HeuristicWeightsInvariants.block_of("openfront_econ_mid_gpt"), b,
		"el gate económico del frente pregunta lo mismo, en la misma unidad")


func test_la_comida_tiene_su_propia_escala() -> void:
	# Mezclarlas ataría a un factor común dos economías que no lo comparten: el oro
	# se dispara durante la partida y la comida se queda en las decenas.
	assert_ne(HeuristicWeightsInvariants.block_of("surplus_min_food"),
		HeuristicWeightsInvariants.block_of("surplus_comfortable_mid"),
		"oro y comida no comparten factor de escala")


func test_mover_el_excedente_arrastra_al_gate_del_frente() -> void:
	var claves := PackedStringArray(["surplus_comfortable_mid", "openfront_econ_mid_gpt"])
	var espacio := _espacio(claves)
	var v := espacio.vector_of(_w())
	var out := espacio.perturb_dims(v, 0.15, 1)
	assert_ne(out[0], v[0])
	assert_ne(out[1], v[1], "el gate del frente debe seguir al excedente")


# ---------------------------------------------------------------------------
# Bloque de urgencias: la petición original — «todas las urgencias, sin
# ningún criterio aparente»
# ---------------------------------------------------------------------------

func test_las_curvas_de_urgencia_completas_ya_son_optimizables() -> void:
	# Antes solo la militar (4 campos) entraba. Oro, comida y mazo estaban fuera
	# ENTERAS — ni un umbral ni un valor.
	var keys := HeuristicWeightsSpec.OPTIMIZABLE_KEYS
	for k in ["gold_urg_early_t0", "gold_urg_mid_v2", "gold_urg_late_t6",
			"food_urg_early_v0", "food_urg_mid_t1", "food_urg_late_v3",
			"deck_urg_t0", "deck_urg_v2"]:
		assert_true(keys.has(k), "%s debe ser optimizable" % k)


func test_las_seis_cadenas_de_umbral_de_urgencia_son_bloques() -> void:
	# `gold_urgency`/`food_urgency` leen `if x < t0: ... if x < t1: ...` de arriba
	# abajo: cruzar dos umbrales deja un tramo sin ningún estado que lo alcance.
	for prefijo in ["gold_urg_early", "gold_urg_mid", "gold_urg_late",
			"food_urg_early", "food_urg_mid", "food_urg_late"]:
		var t0 := "%s_t0" % prefijo
		var t1 := "%s_t1" % prefijo
		assert_ne(HeuristicWeightsInvariants.block_of(t0), "",
			"%s debe pertenecer a un bloque" % t0)
		assert_eq(HeuristicWeightsInvariants.block_of(t0), HeuristicWeightsInvariants.block_of(t1),
			"%s y %s deben ir en el mismo bloque" % [t0, t1])
	assert_eq(HeuristicWeightsInvariants.block_of("deck_urg_t0"),
		HeuristicWeightsInvariants.block_of("deck_urg_t1"))


func test_los_valores_de_urgencia_no_forman_cadena() -> void:
	# El código no exige que v0 > v1 > v2…; imponerlo restringiría exploración que
	# el diseño no necesita.
	assert_eq(HeuristicWeightsInvariants.block_of("gold_urg_late_v3"), "",
		"los VALORES de la curva son independientes, solo los umbrales son cadena")


func test_repair_endereza_las_seis_cadenas_de_urgencia() -> void:
	var w := _w()
	w.gold_urg_early_t0 = 60.0; w.gold_urg_early_t1 = 10.0; w.gold_urg_early_t2 = 30.0
	w.food_urg_late_t0 = 10.0; w.food_urg_late_t1 = 0.0; w.food_urg_late_t2 = 5.0
	w.deck_urg_t0 = 6.0; w.deck_urg_t1 = 3.0
	assert_gt(HeuristicWeightsInvariants.repair(w), 0)
	assert_lte(w.gold_urg_early_t0, w.gold_urg_early_t1)
	assert_lte(w.gold_urg_early_t1, w.gold_urg_early_t2)
	assert_lte(w.food_urg_late_t0, w.food_urg_late_t1)
	assert_lte(w.food_urg_late_t1, w.food_urg_late_t2)
	assert_lte(w.deck_urg_t0, w.deck_urg_t1)
	assert_eq(HeuristicWeightsInvariants.validate(w).size(), 0,
		"tras reparar, validate no debe encontrar nada")


func test_los_umbrales_que_empiezan_en_cero_no_quedan_atrapados_en_cero_uno() -> void:
	# EL bug que se habria colado: cuatro umbrales tienen default 0.0 porque el
	# primer tramo empieza en cero, y la regla general de rangos confunde "default
	# 0" con "esto es una probabilidad" y lo encierra en [0,1] — cuando vive en la
	# misma escala que sus hermanos (hasta 2000 en gold_urg_late).
	for k in ["gold_urg_late_t0", "food_urg_early_t0", "food_urg_mid_t0", "food_urg_late_t0"]:
		var b := HeuristicWeightsSpec.get_bounds(k)
		assert_gt(b.y, 1.0, "%s debe poder buscarse más allá de 1.0" % k)


# ---------------------------------------------------------------------------
# Bloque del eje del mazo
# ---------------------------------------------------------------------------

func test_deck_small_y_deck_large_ya_son_optimizables() -> void:
	var keys := HeuristicWeightsSpec.OPTIMIZABLE_KEYS
	assert_true(keys.has("deck_small"))
	assert_true(keys.has("deck_large"))
	assert_true(keys.has("shop_thresh_small"),
		"faltaba sin motivo: deck_thin_* y purge_thresh_* ya entraban")
	assert_true(keys.has("shop_thresh_large"))


func test_repair_evita_la_division_por_cero_del_eje_del_mazo() -> void:
	# El caso real que puede producir SA: dos dimensiones perturbadas por separado
	# convergen al mismo punto. `_deck_ratio` divide por (deck_large - deck_small);
	# igualados, eso es NaN silencioso propagándose a compra/purga/adelgazamiento.
	var w := _w()
	w.deck_small = 12.0
	w.deck_large = 12.0
	assert_gt(HeuristicWeightsInvariants.repair(w), 0, "debe intervenir")
	assert_gte(w.deck_large - w.deck_small, 0.5, "debe quedar un hueco mínimo")


func test_repair_endereza_el_eje_del_mazo_cruzado() -> void:
	# No basta con que quede ordenado: tiene que CONSERVAR EL CONJUNTO, como las
	# cadenas. La primera versión colapsaba (20, 5) a (12.25, 12.75) —ordenado, sí,
	# pero inventándose la banda entera y tirando la exploración del optimizador.
	var w := _w()
	w.deck_small = 20.0
	w.deck_large = 5.0
	HeuristicWeightsInvariants.repair(w)
	assert_almost_eq(w.deck_small, 5.0, 0.001, "el extremo bajo era 5")
	assert_almost_eq(w.deck_large, 20.0, 0.001, "y el alto 20: se ordenan, no se inventan")


func test_mover_el_eje_no_toca_los_umbrales_de_valor() -> void:
	# El eje (posición) y los umbrales de compra/purga (magnitud) son cosas
	# distintas: no comparten bloque.
	assert_ne(HeuristicWeightsInvariants.block_of("deck_small"),
		HeuristicWeightsInvariants.block_of("deck_thin_small"))


# ---------------------------------------------------------------------------
# Lo que la auditoría destapó: validate() no cubría lo que repair() arregla
# ---------------------------------------------------------------------------

func test_validate_ve_el_gradiente_de_encierro_invertido() -> void:
	# El agujero real: `validate` daba 0 errores para un candidato con el encierro
	# invertido, la cadena de tropa cruzada y el eje del mazo del revés, los TRES a
	# la vez. Eso hacía que el test de coherencia extremo a extremo no significara
	# nada — solo comprobaba las cadenas de urgencia y el orden de fases.
	var w := _w()
	w.encircle_min = 0.1     # por debajo de encircle_low: gradiente del revés
	assert_gt(HeuristicWeightsInvariants.validate(w).size(), 0,
		"un gradiente de encierro invertido debe ser un error, no pasar callando")


func test_validate_ve_la_cadena_de_complementariedad_cruzada() -> void:
	var w := _w()
	w.complement_troop_hi = 0.1
	assert_gt(HeuristicWeightsInvariants.validate(w).size(), 0)

	var w2 := _w()
	w2.complement_pool_mid = 99.0   # por encima de pool_hi
	assert_gt(HeuristicWeightsInvariants.validate(w2).size(), 0)


func test_validate_ve_el_eje_del_mazo_sin_banda() -> void:
	var w := _w()
	w.deck_large = w.deck_small
	assert_gt(HeuristicWeightsInvariants.validate(w).size(), 0,
		"sin banda, _deck_ratio divide por cero")


func test_el_campeon_del_repo_falla_la_validacion_por_el_encierro() -> void:
	# Antes de esta corrección `validate(campeon)` daba 0 errores pese a tener el
	# gradiente roto — medido. Ahora lo señala, y `repair` lo arregla.
	var champ := load("res://resources/ai/heuristic_weights_optimized.tres") as HeuristicWeights
	assert_not_null(champ)
	assert_gt(HeuristicWeightsInvariants.validate(champ).size(), 0,
		"el campeón tiene encircle_min por debajo de encircle_low")
	var copia := champ.clone()
	HeuristicWeightsInvariants.repair(copia)
	assert_eq(HeuristicWeightsInvariants.validate(copia).size(), 0,
		"y tras repararlo debe validar limpio")


func test_cruzar_una_sola_cadena_de_complementariedad_no_mata_ninguna_rama() -> void:
	# Documenta la corrección de una afirmación mía que era falsa. Cruzar el par
	# alto del pool NO deja ramas inalcanzables: cada una se alcanza también por el
	# eje de la tropa. Solo mueren si se cruzan las dos a la vez. La razón para
	# ordenarlas es la semántica, no la alcanzabilidad.
	var w := _w()
	w.complement_pool_hi = 1.0      # por debajo de pool_mid (1.5)
	var vistos := {}
	for pr in [0.2, 0.6, 0.9, 1.2, 1.8, 3.0]:
		for tr in [0.3, 0.6, 0.9, 1.05, 1.5]:
			var t := TestBuilders.troop().with_attack(int(tr * 100)).with_defense(100).build()
			var pool: Array[Troop] = []
			pool.append(TestBuilders.troop().with_attack(int(pr * 100)).with_defense(100).build())
			vistos[snappedf(AIMilitary.complement_bonus(t, pool, w), 0.01)] = true
	assert_eq(vistos.size(), 3,
		"las tres salidas (neutro, medio, alto) siguen siendo alcanzables")
