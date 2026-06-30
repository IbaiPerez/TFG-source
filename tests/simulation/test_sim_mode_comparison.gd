extends GutTest

## Round-robin headless de 3 EMPAREJAMIENTOS × 2 PRESUPUESTOS de tiempo, por
## TANDAS. Mide win-rate (con IC95) y eficiencia de la búsqueda (iters por
## decisión, profundidad efectiva con warm start, override del prior) para
## comparar la heurística (Fase B) contra SO-ISMCTS (Fase C v2) con rollout
## HEURÍSTICO vs ALEATORIO.
##
## Emparejamientos (A juega primero como AI_A; sin pares-espejo):
##   1. ISMCTS_H  vs HEUR       — ¿la búsqueda con prior/rollout heurístico bate a la heurística?
##   2. ISMCTS_R  vs HEUR       — ¿y la búsqueda "pura" (prior uniforme + rollout aleatorio)?
##   3. ISMCTS_H  vs ISMCTS_R   — ¿cuánto aporta la heurística DENTRO del MCTS?
##
## Cada (emparejamiento, presupuesto) es una TANDA de N partidas que vuelca su
## propio JSON EN CUANTO termina: user://sim_<matchup>_<budget>ms.json (6 ficheros).
## Mismo seed maestro en todas → MISMAS partidas; las variables son el
## emparejamiento y el presupuesto. Secuencial (no paralelo): cada tanda usa la
## CPU entera para que el presupuesto de TIEMPO rinda las iteraciones esperadas.
##
## Cómo lanzar (bash):
##   RUN_MODE_COMPARISON=1 "C:\Users\ibaip\Desktop\Godot_v4.5-stable_win64.exe\Godot_v4.5-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd "-gconfig=" \
##     -gtest=res://tests/simulation/test_sim_mode_comparison.gd -gexit
## PowerShell:
##   $env:RUN_MODE_COMPARISON=1; & godot --headless -s addons/gut/gut_cmdln.gd `
##     "-gconfig=" -gtest=res://tests/simulation/test_sim_mode_comparison.gd -gexit
##
## Salida en Windows: %APPDATA%\Godot\app_userdata\Source\sim_<matchup>_<budget>ms.json
##
## Overrides por env: MODE_CMP_BUDGETS="500,1000" (lista), MODE_CMP_GAMES (def 50).
## CAVEAT coste: el emparejamiento 3 tiene DOS MCTS pensando → es el más lento.


const COMPARATOR := preload("res://tests/simulation/ai_mode_comparator.gd")

# Lánzalo desde el panel GUT del editor (corre el round-robin completo). Para una
# tanda concreta usa los overrides por env.
const ENABLE_FROM_GUI := true

# --- Parámetros (ajustables) -----------------------------------------------
const N_GAMES := 50
## Presupuestos de tiempo por decisión del MCTS (ms). Se barren EN SECUENCIA.
const BUDGET_SWEEP_MS := [500, 1000]
const ROLLOUT_DEPTH := 10
const ITER_CAP := 100000          ## Techo de iteraciones (manda el tiempo)
const MAX_ROUNDS := 500
const RNG_SEED := 20260611        ## MISMO en todas las tandas → mismas partidas
const SELF_EVAL_GAMES := 0        ## 0 = sin traza (el foco es WR + eficiencia)

## Emparejamientos del round-robin. kind ∈ {"HEUR","MCTS_H","MCTS_R"}.
## A juega primero (AI_A); ver caveat de ventaja de primer turno en el comparador.
const MATCHUPS := [
	{"name": "ISMCTS_H_vs_HEUR",     "label_a": "ISMCTS_H", "kind_a": "MCTS_H", "label_b": "HEUR",     "kind_b": "HEUR"},
	{"name": "ISMCTS_R_vs_HEUR",     "label_a": "ISMCTS_R", "kind_a": "MCTS_R", "label_b": "HEUR",     "kind_b": "HEUR"},
	{"name": "ISMCTS_H_vs_ISMCTS_R", "label_a": "ISMCTS_H", "kind_a": "MCTS_H", "label_b": "ISMCTS_R", "kind_b": "MCTS_R"},
]


func test_compare_modes() -> void:
	if not ENABLE_FROM_GUI and OS.get_environment("RUN_MODE_COMPARISON") == "":
		pass_test("Saltado: pon ENABLE_FROM_GUI=true o RUN_MODE_COMPARISON=1 para ejecutar.")
		return

	# Presupuestos a barrer. Override por env: MODE_CMP_BUDGETS="500,1000"
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

	# Cada (emparejamiento, presupuesto) corre en SECUENCIA y vuelca su JSON en
	# cuanto termina, así los primeros resultados están disponibles sin esperar.
	for mu in MATCHUPS:
		for budget in budgets:
			WorldMap.map = []
			WorldMap.map_as_dict = {}
			BattleFront.clear_active_instances()

			var b: int = int(budget)
			var cmp = COMPARATOR.new()
			cmp.config_a = _build_config(String(mu["kind_a"]), b)
			cmp.config_b = _build_config(String(mu["kind_b"]), b)
			cmp.label_a = String(mu["label_a"])
			cmp.label_b = String(mu["label_b"])
			cmp.matchup_name = String(mu["name"])
			cmp.budget_ms = b
			cmp.n_games = n_games
			cmp.max_rounds = MAX_ROUNDS
			cmp.rng_master_seed = RNG_SEED
			cmp.self_eval_games = SELF_EVAL_GAMES
			cmp.attach_to(self)

			print("[ModeCmp] === TANDA: %s @ %d ms · %d partidas · depth=%d · seed=%d ===" % [
				mu["name"], budget, n_games, ROLLOUT_DEPTH, RNG_SEED])

			await cmp.run()

			var out_path := "user://sim_%s_%dms.json" % [mu["name"], budget]
			cmp.dump_to(out_path)
			print("[ModeCmp] Path absoluto: %s" % ProjectSettings.globalize_path(out_path))
			_print_summary(cmp.summary)

			assert_eq(int(cmp.summary["games"]), n_games,
				"La tanda %s @ %d ms debe tener %d partidas, tiene %d" % [
					mu["name"], budget, n_games, int(cmp.summary["games"])])

			# Consumir errores/warnings del motor de ESTA tanda antes de la siguiente.
			for e in get_errors():
				e.handled = true

	WorldMap.map = []
	WorldMap.map_as_dict = {}
	BattleFront.clear_active_instances()


# --- Construcción de configs ------------------------------------------------

func _build_config(kind: String, budget: int) -> AIConfig:
	match kind:
		"HEUR": return _heur_config()
		"MCTS_H": return _mcts_config(budget, true)
		"MCTS_R": return _mcts_config(budget, false)
	return _heur_config()


func _heur_config() -> AIConfig:
	var c := AIConfig.new()
	c.mode = AIConfig.Mode.HEURISTIC
	return c


func _mcts_config(budget: int, heuristic_rollout: bool) -> AIConfig:
	var c := AIConfig.new()
	c.mode = AIConfig.Mode.MCTS
	c.mcts_time_budget_ms = budget
	c.mcts_iterations = ITER_CAP
	c.mcts_rollout_depth = ROLLOUT_DEPTH
	c.mcts_heuristic_rollout = heuristic_rollout
	return c


# --- Resumen stdout --------------------------------------------------------

func _print_summary(s: Dictionary) -> void:
	var la := String(s["label_a"])
	var lb := String(s["label_b"])
	print("\n[ModeCmp] === RESUMEN %s @ %d ms ===" % [s["matchup"], int(s["budget_ms"])])
	var wld := "%d-%d-%d" % [s["a_wins"], s["b_wins"], s["draws"]]
	var wr := "%.0f%% [%.0f,%.0f]" % [
		s["a_winrate_decisive"] * 100.0,
		s["a_winrate_ci95_lo"] * 100.0, s["a_winrate_ci95_hi"] * 100.0]
	print("[ModeCmp] %s (A) vs %s (B) | W-L-D %s | A WR %s" % [la, lb, wld, wr])
	print("[ModeCmp] ms/turno: A=%.2f  B=%.2f | Rondas %.0f | Coloniz %.0f%%" % [
		s["ms_per_turn_a"], s["ms_per_turn_b"], s["avg_rounds"],
		s["avg_colonized_pct"] * 100.0])

	# Eficiencia de la búsqueda por bando (los heurísticos no imprimen línea).
	_print_mcts_line(s, "a", la)
	_print_mcts_line(s, "b", lb)

	print("\n[ModeCmp] --- Acciones por bando (%% del total) ---")
	var a_act: Dictionary = s["a_actions"]
	var b_act: Dictionary = s["b_actions"]
	var keys := {}
	for k in a_act: keys[k] = true
	for k in b_act: keys[k] = true
	var key_list: Array = keys.keys()
	key_list.sort()
	var as_total := _sum(a_act)
	var bs_total := _sum(b_act)
	print("[ModeCmp] %-26s %-16s %-16s" % ["Acción", la, lb])
	for key in key_list:
		var ac: int = a_act.get(key, 0)
		var bc: int = b_act.get(key, 0)
		print("[ModeCmp] %-26s %-16s %-16s" % [
			key,
			"%d (%.0f%%)" % [ac, 100.0 * float(ac) / float(maxi(as_total, 1))],
			"%d (%.0f%%)" % [bc, 100.0 * float(bc) / float(maxi(bs_total, 1))]])


## Imprime la línea de eficiencia MCTS de un bando. Si decisions==0 (heurística),
## no imprime nada.
func _print_mcts_line(s: Dictionary, prefix: String, label: String) -> void:
	var dec: int = int(s["%s_decisions" % prefix])
	if dec == 0:
		return
	print("[ModeCmp] %-9s MCTS: %d dec · prior-ovr %.0f%% · iters/dec %.1f · visitas-raíz/dec %.1f · warm ×%.2f" % [
		label, dec,
		s["%s_prior_override_rate" % prefix] * 100.0,
		s["%s_avg_iters_per_decision" % prefix],
		s["%s_avg_root_visits_per_decision" % prefix],
		s["%s_warm_start_ratio" % prefix]])


func _sum(d: Dictionary) -> int:
	var s := 0
	for k in d:
		s += int(d[k])
	return s
