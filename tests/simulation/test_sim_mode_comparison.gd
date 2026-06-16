extends GutTest

## Comparación headless MCTS (Fase C v2) vs HEURÍSTICA (Fase B), por TANDAS.
##
## Una sola ejecución corre las 3 tandas (500/750/1000 ms) EN SECUENCIA, una tras
## otra automáticamente, y vuelca el JSON de cada tanda EN CUANTO termina (así el
## resultado de la primera está disponible sin esperar a las demás). Secuencial,
## no paralelo: cada tanda usa la CPU entera, para que el presupuesto de TIEMPO
## rinda las iteraciones esperadas (en paralelo, la contención de CPU haría que
## cupieran menos iteraciones en el mismo tiempo de pared). Mismo seed maestro en
## las 3 → MISMAS partidas; la única variable es el presupuesto.
##
## Cómo lanzar (un único comando), bash:
##   RUN_MODE_COMPARISON=1 godot --headless -s addons/gut/gut_cmdln.gd "-gconfig=" \
##     -gtest=res://tests/simulation/test_sim_mode_comparison.gd -gexit
## PowerShell:
##   $env:RUN_MODE_COMPARISON=1; & godot --headless -s addons/gut/gut_cmdln.gd `
##     "-gconfig=" -gtest=res://tests/simulation/test_sim_mode_comparison.gd -gexit
##
## Salida: user://sim_batch_<budget>ms.json (uno por tanda). En Windows:
##   %APPDATA%\Godot\app_userdata\Source\sim_batch_<budget>ms.json
##
## Overrides por env: MODE_CMP_BUDGETS="500,1000" (lista), MODE_CMP_GAMES (def 100).


const COMPARATOR := preload("res://tests/simulation/ai_mode_comparator.gd")

# Lánzalo desde el panel GUT del editor (usa budget por defecto). Para las 3
# tandas, usa la línea de comandos con MODE_CMP_BUDGET.
const ENABLE_FROM_GUI := true

# --- Parámetros (ajustables) -----------------------------------------------
const N_GAMES := 100
## Tandas de tiempo que se ejecutan EN SECUENCIA (una tras otra, automáticamente)
## en una sola ejecución. Cada tanda usa el MISMO seed → mismas partidas; solo
## cambia el presupuesto. Secuencial (no paralelo) para que cada tanda tenga la
## CPU entera y el presupuesto de tiempo rinda las iteraciones esperadas.
const BUDGET_SWEEP_MS := [500, 750, 1000]
const ROLLOUT_DEPTH := 3
const MAX_ROUNDS := 500
const RNG_SEED := 20260611       ## MISMO en las 3 tandas → mismas partidas
const HEURISTIC_ROLLOUT := true
const SELF_EVAL_GAMES := 2       ## partidas con traza de auto-evaluación


func test_compare_modes() -> void:
	if not ENABLE_FROM_GUI and OS.get_environment("RUN_MODE_COMPARISON") == "":
		pass_test("Saltado: pon ENABLE_FROM_GUI=true o RUN_MODE_COMPARISON=1 para ejecutar la tanda.")
		return

	# Presupuestos a barrer (secuencialmente). Override por env:
	#   MODE_CMP_BUDGETS="500,1000"
	var budgets: Array = BUDGET_SWEEP_MS
	var env_budgets := OS.get_environment("MODE_CMP_BUDGETS")
	if env_budgets != "":
		budgets = []
		for tok in env_budgets.split(","):
			budgets.append(int(tok.strip_edges()))
	var n_games := N_GAMES
	var env_games := OS.get_environment("MODE_CMP_GAMES")
	if env_games != "":
		n_games = int(env_games)

	# Cada tanda corre en SECUENCIA y vuelca su JSON EN CUANTO termina, así el
	# resultado de la primera está disponible sin esperar a las demás.
	for budget in budgets:
		WorldMap.map = []
		WorldMap.map_as_dict = {}
		BattleFront.clear_active_instances()

		var cmp = COMPARATOR.new()
		cmp.budget_ms = budget
		cmp.n_games = n_games
		cmp.rollout_depth = ROLLOUT_DEPTH
		cmp.heuristic_rollout = HEURISTIC_ROLLOUT
		cmp.max_rounds = MAX_ROUNDS
		cmp.rng_master_seed = RNG_SEED   # mismo seed → mismas partidas en cada tanda
		cmp.self_eval_games = SELF_EVAL_GAMES
		cmp.attach_to(self)

		print("[ModeCmp] === TANDA: %d partidas @ %d ms, depth=%d, rollout=%s, seed=%d ===" % [
			n_games, budget, ROLLOUT_DEPTH,
			"heurístico" if HEURISTIC_ROLLOUT else "aleatorio", RNG_SEED])

		await cmp.run()

		var out_path := "user://sim_batch_%dms.json" % budget
		cmp.dump_to(out_path)
		print("[ModeCmp] Path absoluto: %s" % ProjectSettings.globalize_path(out_path))
		_print_summary(cmp.summary)

		assert_eq(int(cmp.summary["games"]), n_games,
			"La tanda %d ms debe tener %d partidas, tiene %d" % [
				budget, n_games, int(cmp.summary["games"])])

		# Consumir errores/warnings del motor de ESTA tanda antes de la siguiente.
		for e in get_errors():
			e.handled = true

	WorldMap.map = []
	WorldMap.map_as_dict = {}
	BattleFront.clear_active_instances()


# --- Resumen stdout --------------------------------------------------------

func _print_summary(s: Dictionary) -> void:
	print("\n[ModeCmp] === RESUMEN TANDA %d ms ===" % int(s["budget_ms"]))
	print("[ModeCmp] %-7s %-7s %-13s %-18s %-11s %-9s %-8s %-9s" % [
		"ms/dec", "Juegos", "MCTS W-L-D", "MCTS WR% [IC95]", "ms/t MCTS",
		"Rondas", "Coloniz%", "Prior-ovr%"])
	var wld := "%d-%d-%d" % [s["mcts_wins"], s["heur_wins"], s["draws"]]
	var wr := "%.0f%% [%.0f,%.0f]" % [
		s["mcts_winrate_decisive"] * 100.0,
		s["mcts_winrate_ci95_lo"] * 100.0, s["mcts_winrate_ci95_hi"] * 100.0]
	print("[ModeCmp] %-7d %-7d %-13s %-18s %-11.2f %-9.0f %-8s %-9s" % [
		int(s["budget_ms"]), int(s["games"]), wld, wr,
		s["ms_per_turn_mcts"], s["avg_rounds"],
		"%.0f%%" % (s["avg_colonized_pct"] * 100.0),
		"%.0f%%" % (s["prior_override_rate"] * 100.0)])

	print("\n[ModeCmp] --- Acciones por modo (%% del total) ---")
	var mcts_a: Dictionary = s["mcts_actions"]
	var heur_a: Dictionary = s["heur_actions"]
	var keys := {}
	for k in mcts_a: keys[k] = true
	for k in heur_a: keys[k] = true
	var key_list: Array = keys.keys()
	key_list.sort()
	var ms := _sum(mcts_a)
	var hs := _sum(heur_a)
	print("[ModeCmp] %-26s %-14s %-14s" % ["Acción", "MCTS", "Heurística"])
	for key in key_list:
		var mc: int = mcts_a.get(key, 0)
		var he: int = heur_a.get(key, 0)
		print("[ModeCmp] %-26s %-14s %-14s" % [
			key,
			"%d (%.0f%%)" % [mc, 100.0 * float(mc) / float(maxi(ms, 1))],
			"%d (%.0f%%)" % [he, 100.0 * float(he) / float(maxi(hs, 1))]])


func _sum(d: Dictionary) -> int:
	var s := 0
	for k in d:
		s += int(d[k])
	return s
