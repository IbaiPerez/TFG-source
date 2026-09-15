extends GutTest

## Comparativa FINAL heurística vs SO-ISMCTS por presupuesto de tiempo, con la
## heurística optimizada (heuristic_weights_optimized.tres) en AMBOS bandos:
## la misma heurística juega sola (HEUR) y dentro del MCTS (prior + rollout).
##
## Diseño:
##   - Celdas = emparejamientos × presupuestos (def. ISMCTS_H_vs_HEUR × 500/750/1000 ms).
##   - Bucle SEMILLA-MAYOR: cada semilla se juega en TODAS las celdas antes de
##     pasar a la siguiente. Así, se pare cuando se pare, todas las celdas tienen
##     exactamente las mismas partidas y son comparables entre sí.
##   - ESPEJO: cada semilla se juega con los asientos cambiados (A/B), para
##     neutralizar la ventaja de primer turno. WR por contendiente, no por asiento.
##   - ACOTADO POR HORAS: antes de cada semilla estima si cabe (media × margen).
##   - Vuelca el JSON de CADA celda tras cada semilla (datos parciales siempre
##     disponibles) y REANUDA desde esos volcados con MODE_CMP_RESUME=1.
##
## Cómo lanzar (PowerShell, una línea):
##   $env:RUN_MODE_COMPARISON='1'; & 'C:\Users\ibaip\Desktop\Godot_v4.5-stable_win64.exe\Godot_v4.5-stable_win64_console.exe' --headless -s addons/gut/gut_cmdln.gd "-gconfig=" -gtest=res://tests/simulation/test_sim_mode_comparison.gd -gexit
##
## Salida (Windows): %APPDATA%\Godot\app_userdata\Source\sim_final_<matchup>_<budget>ms.json
##
## Overrides por env:
##   MODE_CMP_HOURS    presupuesto de reloj (def 40)
##   MODE_CMP_SEEDS    tope de semillas (def 1000 → manda el reloj)
##   MODE_CMP_BUDGETS  "500,750,1000"
##   MODE_CMP_MATCHUPS "ISMCTS_H_vs_HEUR,ISMCTS_R_vs_HEUR" (nombres de MATCHUPS)
##   MODE_CMP_TAG      sufijo del fichero de salida: sim_final<tag>_<matchup>_<b>ms.json
##                     (p.ej. "_prior" para no pisar la tanda anterior)
##   MODE_CMP_RESUME=1 reanudar desde los JSON existentes (misma config)
##   MODE_CMP_SMOKE=1  1 semilla (MODE_CMP_SEEDS) a 40/60 ms y 30 rondas (~1 min) para probar el circuito
##
## Coste orientativo (junio, esta máquina): ~270–290 decisiones MCTS/partida →
## ~2,7 / 4,0 / 5,2 min por partida a 500 / 750 / 1000 ms. Una semilla (par
## espejo × 3 presupuestos) ≈ 24 min → 40 h ≈ 100 semillas = 200 partidas/celda.


const COMPARATOR := preload("res://tests/simulation/ai_mode_comparator.gd")
const WEIGHTS_PATH := "res://resources/ai/heuristic_weights_optimized.tres"

const ENABLE_FROM_GUI := false

# --- Parámetros (ajustables) -----------------------------------------------
const HOURS := 40.0
const MAX_SEEDS := 1000
const BUDGET_SWEEP_MS := [500, 750, 1000]
const ROLLOUT_DEPTH := 10
const ITER_CAP := 100000          ## Techo de iteraciones (manda el tiempo)
const MAX_ROUNDS := 500
const RNG_SEED := 20260611        ## Misma secuencia de semillas en todas las celdas
const SAFETY := 1.5               ## Margen predictivo sobre la media por semilla

## kind ∈ {"HEUR","MCTS_H","MCTS_R"}. Por defecto solo el primero (ver env).
const MATCHUPS := [
	{"name": "ISMCTS_H_vs_HEUR",     "label_a": "ISMCTS_H", "kind_a": "MCTS_H", "label_b": "HEUR",     "kind_b": "HEUR"},
	{"name": "ISMCTS_R_vs_HEUR",     "label_a": "ISMCTS_R", "kind_a": "MCTS_R", "label_b": "HEUR",     "kind_b": "HEUR"},
	{"name": "ISMCTS_H_vs_ISMCTS_R", "label_a": "ISMCTS_H", "kind_a": "MCTS_H", "label_b": "ISMCTS_R", "kind_b": "MCTS_R"},
]
const DEFAULT_MATCHUPS := ["ISMCTS_H_vs_HEUR"]

var _weights: HeuristicWeights = null
var _max_rounds := MAX_ROUNDS


func test_compare_modes() -> void:
	if not ENABLE_FROM_GUI and OS.get_environment("RUN_MODE_COMPARISON") == "":
		pass_test("Saltado: pon ENABLE_FROM_GUI=true o RUN_MODE_COMPARISON=1 para ejecutar.")
		return

	_weights = load(WEIGHTS_PATH) as HeuristicWeights
	assert_not_null(_weights, "No se cargó %s" % WEIGHTS_PATH)
	if _weights == null:
		return

	var smoke := OS.get_environment("MODE_CMP_SMOKE") != ""
	var budgets := _int_list_env("MODE_CMP_BUDGETS", BUDGET_SWEEP_MS)
	var hours := SimEnv.float_env("MODE_CMP_HOURS", HOURS)
	var max_seeds := SimEnv.int_env("MODE_CMP_SEEDS", MAX_SEEDS)
	if smoke:
		budgets = [40, 60]
		max_seeds = SimEnv.int_env("MODE_CMP_SEEDS", 1)
		_max_rounds = 30

	var cells := _build_cells(_selected_matchups(), budgets)
	var start_seed := _resume(cells) if OS.get_environment("MODE_CMP_RESUME") != "" else 0
	print("[ModeCmp] %d celdas · espejo · %.1f h · tope %d semillas · desde semilla %d · depth=%d · seed=%d" % [
		cells.size(), hours, max_seeds, start_seed, ROLLOUT_DEPTH, RNG_SEED])

	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED
	for _i in range(start_seed):
		rng.randi()   # saltar las semillas ya jugadas

	var played := await _sweep(cells, rng, start_seed, max_seeds, int(hours * 3600000.0))

	for cell in cells:
		var cmp = cell["cmp"]
		_print_summary(cmp.summary)
		assert_eq(cmp.games.size(), (start_seed + played) * 2,
			"La celda %s debe tener %d partidas, tiene %d" % [
				cell["path"], (start_seed + played) * 2, cmp.games.size()])
	_clear_world()


# --- Bucle semilla-mayor ----------------------------------------------------

## Juega semillas hasta agotar el reloj o el tope. Devuelve las semillas jugadas.
func _sweep(cells: Array, rng: RandomNumberGenerator, start_seed: int,
		max_seeds: int, budget_ms: int) -> int:
	var t0 := Time.get_ticks_msec()
	var played := 0
	while start_seed + played < max_seeds:
		var elapsed := Time.get_ticks_msec() - t0
		if played > 0 and float(elapsed) + float(elapsed) / float(played) * SAFETY > float(budget_ms):
			print("[ModeCmp] presupuesto agotado (%.2f h, %.1f min/semilla) → paro" % [
				elapsed / 3600000.0, float(elapsed) / float(played) / 60000.0])
			break
		var idx := start_seed + played
		var game_seed := rng.randi()
		for cell in cells:
			_clear_world()
			var cmp = cell["cmp"]
			await cmp.play_seed(idx, game_seed)
			cmp.finalize()
			cmp.dump_to(cell["path"])
			_consume_engine_errors()
		played += 1
		print("[ModeCmp] semilla %d hecha · %.2f h · %s" % [
			idx, (Time.get_ticks_msec() - t0) / 3600000.0, _progress_line(cells)])
	return played


## WR de A por celda, en una línea, para seguir la tanda desde el log.
func _progress_line(cells: Array) -> String:
	var parts: Array[String] = []
	for cell in cells:
		var s: Dictionary = cell["cmp"].summary
		parts.append("%dms %d-%d-%d" % [int(s["budget_ms"]), s["a_wins"], s["b_wins"], s["draws"]])
	return " | ".join(parts)


## Reanuda: carga los JSON existentes y devuelve la semilla por la que seguir
## (la mínima completada en TODAS las celdas; el resto se recorta a ese punto).
func _resume(cells: Array) -> int:
	var seeds_done := -1
	for cell in cells:
		var n: int = cell["cmp"].load_from(cell["path"])
		seeds_done = n / 2 if seeds_done < 0 else mini(seeds_done, n / 2)
	seeds_done = maxi(seeds_done, 0)
	for cell in cells:
		var cmp = cell["cmp"]
		cmp.games.resize(seeds_done * 2)
		cmp.finalize()
	return seeds_done


# --- Construcción de celdas/configs ------------------------------------------

func _build_cells(matchups: Array, budgets: Array) -> Array:
	var cells := []
	for mu in matchups:
		for budget in budgets:
			var b: int = int(budget)
			var cmp = COMPARATOR.new()
			cmp.config_a = _build_config(String(mu["kind_a"]), b)
			cmp.config_b = _build_config(String(mu["kind_b"]), b)
			cmp.label_a = String(mu["label_a"])
			cmp.label_b = String(mu["label_b"])
			cmp.matchup_name = String(mu["name"])
			cmp.budget_ms = b
			cmp.mirror = true
			cmp.max_rounds = _max_rounds
			cmp.rng_master_seed = RNG_SEED
			cmp.attach_to(self)
			cmp.finalize()   # summary vacío pero con forma, para _progress_line
			cells.append({"cmp": cmp, "path": "user://sim_final%s_%s_%dms.json" % [
				OS.get_environment("MODE_CMP_TAG"), mu["name"], b]})
	return cells


func _selected_matchups() -> Array:
	var wanted := DEFAULT_MATCHUPS
	var env := OS.get_environment("MODE_CMP_MATCHUPS")
	if env != "":
		wanted = []
		for tok in env.split(","):
			wanted.append(tok.strip_edges())
	var out := []
	for mu in MATCHUPS:
		if String(mu["name"]) in wanted:
			out.append(mu)
	assert_false(out.is_empty(), "MODE_CMP_MATCHUPS='%s' no casa con ningún emparejamiento" % env)
	return out


func _build_config(kind: String, budget: int) -> AIConfig:
	var c := AIConfig.new()
	c.heuristic_weights = _weights
	match kind:
		"HEUR":
			c.mode = AIConfig.Mode.HEURISTIC
		"MCTS_H", "MCTS_R":
			c.mode = AIConfig.Mode.MCTS
			c.mcts_time_budget_ms = budget
			c.mcts_iterations = ITER_CAP
			c.mcts_rollout_depth = ROLLOUT_DEPTH
			c.mcts_heuristic_rollout = kind == "MCTS_H"
	return c


func _int_list_env(name: String, fallback: Array) -> Array:
	var env := OS.get_environment(name)
	if env == "":
		return fallback
	var out := []
	for tok in env.split(","):
		out.append(int(tok.strip_edges()))
	return out


func _clear_world() -> void:
	WorldMap.map = []
	WorldMap.map_as_dict = {}
	BattleFront.clear_active_instances()


## Consumir errores/warnings del motor de esta partida para que GUT no los
## cuente como fallo del test.
func _consume_engine_errors() -> void:
	for e in get_errors():
		e.handled = true


# --- Resumen stdout --------------------------------------------------------

func _print_summary(s: Dictionary) -> void:
	var la := String(s["label_a"])
	var lb := String(s["label_b"])
	print("\n[ModeCmp] === RESUMEN %s @ %d ms · %d partidas ===" % [s["matchup"], int(s["budget_ms"]), int(s["games"])])
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
