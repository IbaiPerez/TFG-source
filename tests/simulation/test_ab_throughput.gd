extends GutTest

## Sonda A/B de THROUGHPUT del MCTS, con las partidas CLAVADAS.
##
## Por que no vale test_sim_mode_comparison para esto: alli el MCTS esta acotado
## por TIEMPO, asi que un build mas rapido hace mas iteraciones, elige otras
## jugadas y la partida DIVERGE. Se acaba comparando el coste medio sobre
## trayectorias distintas, y el numero mezcla "cuanto cuesta una iteracion" con
## "que partida toco jugar".
##
## Aqui se fija el NUMERO DE ITERACIONES (mcts_time_budget_ms = 0), de modo que:
##   - ambos brazos hacen EXACTAMENTE el mismo trabajo,
##   - con la misma semilla juegan la MISMA partida (comprobable: si los recuentos
##     de decisiones no coinciden, la comparacion no es pareada y hay que decirlo),
##   - y lo que se compara es tiempo de reloj por iteracion, que es throughput puro.
##
## Oponente FIJO (heuristica), no MCTS contra MCTS, para que el cambio no afecte a
## los dos lados y se enmascare.
##
## Uso:
##   RUN_AB_THROUGHPUT=1 godot --headless -s addons/gut/gut_cmdln.gd "-gconfig=" \
##     -gtest=res://tests/simulation/test_ab_throughput.gd -gexit
##
## Salida: user://ab_throughput.json

const COMPARATOR := preload("res://tests/simulation/ai_mode_comparator.gd")

const RNG_SEED := 20260611     ## el mismo que usa la comparacion de modos
const ITERS_PER_DECISION := 3  ## del orden de lo que cabia en 250 ms
const ROLLOUT_DEPTH := 10
const N_GAMES := 3
const MAX_ROUNDS := 500


func test_ab_throughput() -> void:
	if OS.get_environment("RUN_AB_THROUGHPUT") == "":
		pass_test("Saltado: pon RUN_AB_THROUGHPUT=1 para ejecutar.")
		return

	WorldMap.map = []
	WorldMap.map_as_dict = {}
	BattleFront.clear_active_instances()

	var mcts := AIConfig.new()
	mcts.mode = AIConfig.Mode.MCTS
	mcts.mcts_time_budget_ms = 0            # <- sin reloj: itera un numero FIJO
	mcts.mcts_iterations = ITERS_PER_DECISION
	mcts.mcts_rollout_depth = ROLLOUT_DEPTH
	mcts.mcts_heuristic_rollout = true

	var heur := AIConfig.new()
	heur.mode = AIConfig.Mode.HEURISTIC

	var cmp = COMPARATOR.new()
	cmp.config_a = mcts
	cmp.config_b = heur
	cmp.label_a = "ISMCTS_H"
	cmp.label_b = "HEUR"
	cmp.matchup_name = "AB_THROUGHPUT"
	cmp.budget_ms = 0
	cmp.n_games = N_GAMES
	cmp.max_rounds = MAX_ROUNDS
	cmp.rng_master_seed = RNG_SEED
	cmp.attach_to(self)

	print("[AB] === %d partidas · %d iters/decision FIJAS · depth=%d · seed=%d ===" % [
		N_GAMES, ITERS_PER_DECISION, ROLLOUT_DEPTH, RNG_SEED])

	await cmp.run()

	cmp.dump_to("user://ab_throughput.json")

	# Resumen legible: lo que importa es usec por ITERACION.
	var total_usec := 0
	var total_iters := 0
	var total_dec := 0
	for g in cmp.games:
		var m: Dictionary = g["a_mcts"]
		total_usec += int(g["a_usec"])
		total_iters += int(m["total_iterations"])
		total_dec += int(m["decisions"])
		print("[AB] p%d radio %d · dec %d · iters %d · %.1f ms/iter" % [
			int(g["game"]), int(g["map"]["radius"]), int(m["decisions"]),
			int(m["total_iterations"]),
			float(g["a_usec"]) / 1000.0 / maxf(float(m["total_iterations"]), 1.0)])

	print("[AB] === TOTAL: %d decisiones · %d iteraciones · %.2f ms/iter ===" % [
		total_dec, total_iters,
		float(total_usec) / 1000.0 / maxf(float(total_iters), 1.0)])

	assert_gt(total_iters, 0, "la busqueda debe haber iterado")
	assert_eq(total_iters, total_dec * ITERS_PER_DECISION,
		"con presupuesto por iteraciones, cada decision debe hacer EXACTAMENTE las fijadas")

	# Consumir los errores del motor que emite la simulacion (igual que hace
	# test_sim_mode_comparison). Sin esto GUT marca el test como fallido por
	# "Unexpected Errors" aunque la medicion sea correcta — pasa desapercibido si
	# solo se mira el numero impreso.
	for e in get_errors():
		e.handled = true
