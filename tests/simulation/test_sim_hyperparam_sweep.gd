extends GutTest

## Calibración de hiperparámetros del SO-ISMCTS (ablación, una variable a la vez).
##
## Fija el oponente (HEURÍSTICA), el presupuesto y el seed, y varía UN eje cada
## vez alrededor de una configuración base, para aislar el efecto de:
##   C     — mcts_exploration_c   (peso de exploración en el PUCT)
##   K     — mcts_action_pruning_k (nº de jugadas candidatas top-K por nodo)
##   depth — mcts_rollout_depth    (rondas simuladas por rollout)
## Más un punto COMBINADO (la hipótesis de "punto dulce": C bajo + K bajo + depth medio).
##
## Cada punto del barrido es una TANDA de N partidas que vuelca su JSON:
##   user://sweep_<tag>.json
## Mismo seed maestro en todos → MISMAS partidas; la única variable es el
## hiperparámetro. A = ISMCTS_H (con los params del punto), B = HEUR.
##
## Cómo lanzar (PowerShell):
##   $env:RUN_HP_SWEEP=1; & godot --headless -s addons/gut/gut_cmdln.gd `
##     "-gconfig=" -gtest=res://tests/simulation/test_sim_hyperparam_sweep.gd -gexit
## bash:
##   RUN_HP_SWEEP=1 godot --headless -s addons/gut/gut_cmdln.gd "-gconfig=" \
##     -gtest=res://tests/simulation/test_sim_hyperparam_sweep.gd -gexit
##
## Smoke test rápido (2 partidas/punto) antes de la corrida larga:
##   $env:RUN_HP_SWEEP=1; $env:MODE_CMP_GAMES=2; & godot --headless ...
##
## Salida en Windows: %APPDATA%\Godot\app_userdata\Source\sweep_<tag>.json


const COMPARATOR := preload("res://tests/simulation/ai_mode_comparator.gd")

## true → se ejecuta al lanzarlo desde el panel GUT del editor. OJO: con true,
## una corrida de la suite COMPLETA también dispararía este barrido largo (8
## puntos); ejecútalo SOLO seleccionando este script, no "Run All".
const ENABLE_FROM_GUI := true

# --- Parámetros (ajustables) -----------------------------------------------
const N_GAMES := 30
const BUDGET_MS := 500            ## Presupuesto fijo durante el barrido
const ITER_CAP := 100000
const MAX_ROUNDS := 500
const RNG_SEED := 20260611        ## MISMO que el round-robin → mismas partidas

# Configuración BASE (la que usaste en las tandas previas). Cada eje varía
# alrededor de estos valores dejando los otros dos fijos.
const BASE_C := 1.0
const BASE_K := 12
const BASE_DEPTH := 10

## Puntos del barrido. tag se usa para el nombre del JSON y el resumen.
## La base aparece una sola vez; cada eje añade solo sus valores NUEVOS.
const SWEEP := [
	{"tag": "base_c1.0_k12_d10", "c": 1.0, "k": 12, "depth": 10},
	# Eje C (exploración) — con K y depth en base
	{"tag": "c0.4_k12_d10",      "c": 0.4, "k": 12, "depth": 10},
	{"tag": "c1.8_k12_d10",      "c": 1.8, "k": 12, "depth": 10},
	# Eje K (poda) — con C y depth en base
	{"tag": "c1.0_k6_d10",       "c": 1.0, "k": 6,  "depth": 10},
	{"tag": "c1.0_k18_d10",      "c": 1.0, "k": 18, "depth": 10},
	# Eje depth (rollout) — con C y K en base
	{"tag": "c1.0_k12_d3",       "c": 1.0, "k": 12, "depth": 3},
	{"tag": "c1.0_k12_d5",       "c": 1.0, "k": 12, "depth": 5},
	# Punto COMBINADO: hipótesis de punto dulce (C bajo + K bajo + depth medio)
	{"tag": "combo_c0.4_k6_d5",  "c": 0.4, "k": 6,  "depth": 5},
]


func test_hyperparam_sweep() -> void:
	if not ENABLE_FROM_GUI and OS.get_environment("RUN_HP_SWEEP") == "":
		pass_test("Saltado: pon ENABLE_FROM_GUI=true o RUN_HP_SWEEP=1 para ejecutar.")
		return

	var n_games := N_GAMES
	var env_games := OS.get_environment("MODE_CMP_GAMES")
	if env_games != "":
		n_games = int(env_games)

	for pt in SWEEP:
		WorldMap.map = []
		WorldMap.map_as_dict = {}
		BattleFront.clear_active_instances()

		var tag := String(pt["tag"])
		var c := float(pt["c"])
		var k := int(pt["k"])
		var depth := int(pt["depth"])

		var cmp = COMPARATOR.new()
		cmp.config_a = _mcts_config(c, k, depth)
		cmp.config_b = _heur_config()
		cmp.label_a = "ISMCTS_H"
		cmp.label_b = "HEUR"
		cmp.matchup_name = "sweep_%s" % tag
		cmp.budget_ms = BUDGET_MS
		cmp.n_games = n_games
		cmp.max_rounds = MAX_ROUNDS
		cmp.rng_master_seed = RNG_SEED
		cmp.self_eval_games = 0
		cmp.attach_to(self)

		print("[Sweep] === PUNTO: %s · C=%.1f K=%d depth=%d · %d partidas @ %d ms ===" % [
			tag, c, k, depth, n_games, BUDGET_MS])

		await cmp.run()

		var out_path := "user://sweep_%s.json" % tag
		cmp.dump_to(out_path)
		print("[Sweep] Path absoluto: %s" % ProjectSettings.globalize_path(out_path))
		_print_point(tag, cmp.summary)

		assert_eq(int(cmp.summary["games"]), n_games,
			"El punto %s debe tener %d partidas, tiene %d" % [
				tag, n_games, int(cmp.summary["games"])])

		for e in get_errors():
			e.handled = true

	WorldMap.map = []
	WorldMap.map_as_dict = {}
	BattleFront.clear_active_instances()


# --- Construcción de configs ------------------------------------------------

func _mcts_config(c: float, k: int, depth: int) -> AIConfig:
	var cfg := AIConfig.new()
	cfg.mode = AIConfig.Mode.MCTS
	cfg.mcts_time_budget_ms = BUDGET_MS
	cfg.mcts_iterations = ITER_CAP
	cfg.mcts_rollout_depth = depth
	cfg.mcts_heuristic_rollout = true
	cfg.mcts_exploration_c = c
	cfg.mcts_action_pruning_k = k
	return cfg


func _heur_config() -> AIConfig:
	var cfg := AIConfig.new()
	cfg.mode = AIConfig.Mode.HEURISTIC
	return cfg


# --- Resumen stdout (una línea por punto) ----------------------------------

func _print_point(tag: String, s: Dictionary) -> void:
	var wld := "%d-%d-%d" % [s["a_wins"], s["b_wins"], s["draws"]]
	print("[Sweep] %-20s WR %.0f%% [%.0f,%.0f] · %s · iters/dec %.1f · warm ×%.2f · prior-ovr %.0f%% · %.0f ms/turno · rondas %.0f" % [
		tag,
		s["a_winrate_decisive"] * 100.0,
		s["a_winrate_ci95_lo"] * 100.0, s["a_winrate_ci95_hi"] * 100.0,
		wld,
		s["a_avg_iters_per_decision"],
		s["a_warm_start_ratio"],
		s["a_prior_override_rate"] * 100.0,
		s["ms_per_turn_a"],
		s["avg_rounds"]])
