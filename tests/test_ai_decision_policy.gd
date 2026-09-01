extends GutTest

## Tests de AIDecisionPolicy: cómo se elige la jugada entre las opciones legales.
##
## El contrato que se verifica aquí lo declara la cabecera de AIHeuristic:
##
##     "PASS tiene score 0.0 por convenio. Cualquier acción con score POSITIVO
##      se prefiere sobre pasar."
##
## O sea: el cero es una frontera, no un empate. Una jugada que no aporta nada
## NO debe desplazar a PASS. El caso que lo hace visible no es teórico: una
## OpenFrontCard con el pool de tropas vacío puntúa exactamente 0.0
## (AIMoveScorer.score_open_front sale por el veto `free_troops == 0`), y si esa
## jugada ganara, la IA abriría un frente que no puede guarnecer.
##
## Se ejercita por la API pública `pick_best` con `ctx.config == null`, que es el
## camino que cae a la política heurística.


func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	return r


## Contexto SIN tropas libres: es lo que hace que OPEN_FRONT puntúe 0.0.
func _ctx_sin_tropas() -> AITurnContext:
	var stats := TestBuilders.stats() \
		.with_gold(500).with_gpt(200).with_food(20) \
		.with_troop_pool([]) \
		.build()
	return TestBuilders.context(stats).with_rng(_rng()).build()


## Opción de abrir frente sobre una casilla enemiga cualquiera. No necesita
## BattleFrontManager: el scorer sale por el veto de tropas antes de usarlo.
func _open_front_option() -> AIOpenFrontOption:
	var enemiga := TestBuilders.tile().build()
	var propia := TestBuilders.tile().build()
	# Tile extiende Node3D: sin esto quedan huérfanos al terminar el test.
	add_child_autofree(enemiga)
	add_child_autofree(propia)
	var opt := AIOpenFrontOption.new()
	opt.card = OpenFrontCard.new()
	# `targets` es Array[Node]: asignarle un literal sin tipar es error EN
	# EJECUCIÓN, no de parseo. Se construye tipado a propósito.
	var targets: Array[Node] = [enemiga]
	opt.targets = targets
	opt.enemy_tile = enemiga
	opt.source_tile = propia
	return opt


# ---------------------------------------------------------------------------
# El cero como frontera
# ---------------------------------------------------------------------------

func test_la_jugada_de_referencia_puntua_exactamente_cero() -> void:
	# Guarda del propio escenario: si esto dejara de valer 0.0, el test de abajo
	# estaría midiendo otra cosa sin enterarse.
	var ctx := _ctx_sin_tropas()
	assert_eq(AIHeuristic.score_option(_open_front_option(), ctx), 0.0,
		"abrir frente sin tropas libres debe puntuar 0.0 (veto free_troops == 0)")


func test_una_jugada_que_puntua_cero_no_desplaza_a_pass() -> void:
	var ctx := _ctx_sin_tropas()
	var policy := AIDecisionPolicy.new(_rng())

	var options: Array[AIPlayOption] = [_open_front_option()]
	options.append(AIPlayOption.create_pass())

	var elegida := policy.pick_best(options, ctx)
	assert_true(elegida == null or elegida.is_pass,
		"con score 0.0 debe ganar PASS: solo una acción POSITIVA se prefiere sobre pasar")


func test_el_orden_de_enumeracion_no_decide_el_empate_a_cero() -> void:
	# Misma comprobación con PASS al principio: el resultado no puede depender de
	# en qué posición venga PASS en la lista.
	var ctx := _ctx_sin_tropas()
	var policy := AIDecisionPolicy.new(_rng())

	var options: Array[AIPlayOption] = [AIPlayOption.create_pass()]
	options.append(_open_front_option())

	var elegida := policy.pick_best(options, ctx)
	assert_true(elegida == null or elegida.is_pass,
		"el empate a cero se resuelve por el contrato, no por el orden de la lista")


func test_una_jugada_positiva_si_desplaza_a_pass() -> void:
	# El contraste: con tropas en el pool, abrir frente puntúa > 0 y debe ganar.
	# Sin este caso, el test anterior pasaría también con una política que
	# devolviera PASS siempre.
	var tropa := TestBuilders.troop().build()
	var stats := TestBuilders.stats() \
		.with_gold(500).with_gpt(200).with_food(20) \
		.with_troop_pool([tropa]) \
		.build()
	var ctx := TestBuilders.context(stats).with_rng(_rng()).build()
	var policy := AIDecisionPolicy.new(_rng())

	var opt := _open_front_option()
	assert_gt(AIHeuristic.score_option(opt, ctx), 0.0,
		"precondición: con tropas libres la jugada debe puntuar positivo")

	var options: Array[AIPlayOption] = [opt]
	options.append(AIPlayOption.create_pass())

	var elegida := policy.pick_best(options, ctx)
	assert_false(elegida == null or elegida.is_pass,
		"una jugada con score positivo sí debe preferirse sobre pasar")


func test_una_jugada_negativa_pierde_contra_pass() -> void:
	# Ya funcionaba antes del arreglo (PASS 0.0 > negativo), pero es la otra mitad
	# del contrato y conviene tenerla escrita.
	var stats := TestBuilders.stats() \
		.with_gold(500).with_gpt(200).with_food(0) \
		.with_troop_pool([]) \
		.build()
	var ctx := TestBuilders.context(stats).with_rng(_rng()).build()
	var policy := AIDecisionPolicy.new(_rng())

	# Reclutar con la comida al límite dispara el veto (score negativo).
	var tropa := TestBuilders.troop().with_maintenance(0, 20).build()
	var recluta := AIRecruitOption.new()
	recluta.card = RecruitCard.new()
	recluta.troop = tropa
	assert_lt(AIHeuristic.score_option(recluta, ctx), 0.0,
		"precondición: el veto de mantenimiento debe dar score negativo")

	var options: Array[AIPlayOption] = [recluta]
	options.append(AIPlayOption.create_pass())

	var elegida := policy.pick_best(options, ctx)
	assert_true(elegida == null or elegida.is_pass,
		"una jugada vetada nunca debe ejecutarse: gana PASS")
