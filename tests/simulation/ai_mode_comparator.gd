extends RefCounted
class_name AIModeComparator

## Enfrenta la IA MCTS (Fase C v2) contra la heurística (Fase B) en una TANDA de
## N partidas headless a un ÚNICO presupuesto de tiempo, y mide quién gana y a
## qué coste. Diseñado para correr 3 tandas INDEPENDIENTES (p.ej. 500/750/1000 ms)
## como invocaciones separadas: cada tanda usa el MISMO seed maestro → las MISMAS
## N partidas (mapa, recursos, imperios), así la única variable entre tandas es el
## presupuesto. Cada tanda vuelca su propio JSON al terminar (no hay que esperar a
## las demás).
##
## Sin pares-espejo: la IA MCTS juega SIEMPRE como AI_A y la heurística como AI_B.
## (El swap de orientación buscaba neutralizar la ventaja de mapa/turno, pero la
## generación no controla los recursos naturales —siempre aleatorios— así que no
## aportaba realismo; con el mismo seed por tanda el mapa ya queda pareado entre
## presupuestos.)
##
## Uso:
##   var cmp := AIModeComparator.new()
##   cmp.budget_ms = 500
##   cmp.n_games = 100
##   cmp.attach_to(gut_test)
##   await cmp.run()
##   cmp.dump_to("user://sim_batch_500ms.json")


# --- Config de la tanda ------------------------------------------------------

var budget_ms: int = 1000           ## Presupuesto de tiempo por decisión del MCTS
var n_games: int = 100              ## Partidas de la tanda
var rollout_depth: int = 3          ## mcts_rollout_depth
var heuristic_rollout: bool = true  ## mcts_heuristic_rollout
var iteration_cap: int = 100000     ## Techo de iteraciones (el tiempo manda)
var max_rounds: int = 500           ## Límite de seguridad por partida
var rng_master_seed: int = 20260611 ## MISMO en las 3 tandas → mismas partidas
var self_eval_games: int = 2        ## Nº de partidas con traza de auto-evaluación
var capture_snapshots: bool = false


# --- Estado ------------------------------------------------------------------

var _gut_test
var games: Array = []          ## un registro por partida
var summary: Dictionary = {}   ## agregado de la tanda
var self_eval_traces: Array = []


# --- API pública -------------------------------------------------------------

func attach_to(gut_test) -> void:
	_gut_test = gut_test


func run() -> void:
	# rng maestro: con el mismo seed produce la MISMA secuencia de seeds de
	# partida → las 3 tandas (distinto budget) juegan las MISMAS N partidas.
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_master_seed

	var heur := _make_heuristic_config()
	var mcts := _make_mcts_config(budget_ms, rollout_depth)

	for i in range(n_games):
		var game_seed := rng.randi()
		await _play_game(i, mcts, heur, game_seed, i < self_eval_games)

	summary = _aggregate()


# --- Una partida (MCTS = AI_A, heurística = AI_B) ----------------------------

func _play_game(idx: int, cfg_mcts: AIConfig, cfg_heur: AIConfig,
		game_seed: int, trace: bool) -> void:
	# Determinismo del mapa/imperios: el WorldGenerator usa el RNG GLOBAL para
	# barajar imperios y sembrar los ruidos. Sembrarlo con game_seed garantiza
	# que la misma partida idx tenga el mismo mapa/recursos en las 3 tandas.
	seed(game_seed)

	var harness := GameSimHarness.new()
	harness.max_rounds = max_rounds
	harness.run_id = idx
	harness.capture_snapshots = capture_snapshots
	harness.capture_self_eval = trace
	harness.config_a = cfg_mcts   # MCTS siempre A
	harness.config_b = cfg_heur   # heurística siempre B
	var run_rng := RandomNumberGenerator.new()
	run_rng.seed = game_seed
	harness.rng_master = run_rng
	harness.attach_to(_gut_test)
	await harness.run()

	var mcts_won := harness.winner_label == "AI_A"
	var heur_won := harness.winner_label == "AI_B"
	var winner_mode := ""
	if mcts_won:
		winner_mode = "MCTS"
	elif heur_won:
		winner_mode = "HEURISTIC"

	games.append({
		"game": idx,
		"map": harness.run_seed_meta,
		"winner_label": harness.winner_label,
		"winner_mode": winner_mode,
		"victory_condition": harness.victory_condition,
		"finished_round": harness.finished_round,
		"mcts_usec": int(harness.turn_usec_by_label["AI_A"]),
		"mcts_turns": int(harness.turns_by_label["AI_A"]),
		"heur_usec": int(harness.turn_usec_by_label["AI_B"]),
		"heur_turns": int(harness.turns_by_label["AI_B"]),
		"mcts_decisions": harness.mcts_decisions,
		"mcts_prior_overrides": harness.mcts_prior_overrides,
		"final_tiles_mcts": harness.final_tiles_a,
		"final_tiles_heur": harness.final_tiles_b,
		"final_total_tiles": harness.final_total_tiles,
		"colonized_pct": float(harness.final_tiles_a + harness.final_tiles_b)
			/ float(maxi(harness.final_total_tiles, 1)),
		"mcts_actions": (harness.actions_by_label["AI_A"] as Dictionary).duplicate(),
		"heur_actions": (harness.actions_by_label["AI_B"] as Dictionary).duplicate(),
	})

	if trace and not harness.self_eval_trace.is_empty():
		self_eval_traces.append({
			"game": idx,
			"map": harness.run_seed_meta,
			"trace": harness.self_eval_trace,
		})

	# Limpieza de estado global entre partidas.
	WorldMap.map = []
	WorldMap.map_as_dict = {}
	BattleFront.clear_active_instances()


# --- Configs -----------------------------------------------------------------

func _make_heuristic_config() -> AIConfig:
	var c := AIConfig.new()
	c.mode = AIConfig.Mode.HEURISTIC
	return c


func _make_mcts_config(budget: int, depth: int) -> AIConfig:
	var c := AIConfig.new()
	c.mode = AIConfig.Mode.MCTS
	c.mcts_time_budget_ms = budget
	c.mcts_iterations = iteration_cap
	c.mcts_rollout_depth = depth
	c.mcts_heuristic_rollout = heuristic_rollout
	return c


# --- Agregación --------------------------------------------------------------

func _aggregate() -> Dictionary:
	var mcts_wins := 0
	var heur_wins := 0
	var draws := 0
	var mcts_usec := 0
	var mcts_turns := 0
	var heur_usec := 0
	var heur_turns := 0
	var rounds: Array = []
	var colonized: Array = []
	var total_decisions := 0
	var total_overrides := 0
	var mcts_actions := {}
	var heur_actions := {}

	for g in games:
		match g["winner_mode"]:
			"MCTS": mcts_wins += 1
			"HEURISTIC": heur_wins += 1
			_: draws += 1
		mcts_usec += int(g["mcts_usec"])
		mcts_turns += int(g["mcts_turns"])
		heur_usec += int(g["heur_usec"])
		heur_turns += int(g["heur_turns"])
		total_decisions += int(g["mcts_decisions"])
		total_overrides += int(g["mcts_prior_overrides"])
		if int(g["finished_round"]) > 0:
			rounds.append(int(g["finished_round"]))
		colonized.append(float(g["colonized_pct"]))
		_merge_counts(mcts_actions, g["mcts_actions"])
		_merge_counts(heur_actions, g["heur_actions"])

	var decisive := mcts_wins + heur_wins
	var wr := float(mcts_wins) / float(maxi(decisive, 1))
	# IC 95% (aproximación normal) del win-rate decisivo.
	var ci := 1.96 * sqrt(wr * (1.0 - wr) / float(maxi(decisive, 1)))
	var ms_mcts := (float(mcts_usec) / float(maxi(mcts_turns, 1))) / 1000.0
	var ms_heur := (float(heur_usec) / float(maxi(heur_turns, 1))) / 1000.0

	return {
		"budget_ms": budget_ms,
		"games": games.size(),
		"mcts_wins": mcts_wins,
		"heur_wins": heur_wins,
		"draws": draws,
		"mcts_winrate_decisive": wr,
		"mcts_winrate_ci95_lo": clampf(wr - ci, 0.0, 1.0),
		"mcts_winrate_ci95_hi": clampf(wr + ci, 0.0, 1.0),
		"mcts_winrate_all": float(mcts_wins) / float(maxi(games.size(), 1)),
		"ms_per_turn_mcts": ms_mcts,
		"ms_per_turn_heuristic": ms_heur,
		"cost_overhead_factor": ms_mcts / maxf(ms_heur, 0.0001),
		"avg_rounds": _avg(rounds),
		"avg_colonized_pct": _avg(colonized),
		"prior_override_rate": float(total_overrides) / float(maxi(total_decisions, 1)),
		"mcts_decisions": total_decisions,
		"mcts_actions": mcts_actions,
		"heur_actions": heur_actions,
	}


func _merge_counts(acc: Dictionary, src: Dictionary) -> void:
	for key in src:
		acc[key] = acc.get(key, 0) + int(src[key])


func _avg(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var s := 0.0
	for v in values:
		s += float(v)
	return s / float(values.size())


# --- Volcado -----------------------------------------------------------------

func dump_to(path: String) -> void:
	var payload := {
		"metadata": {
			"budget_ms": budget_ms,
			"n_games": n_games,
			"rollout_depth": rollout_depth,
			"heuristic_rollout": heuristic_rollout,
			"iteration_cap": iteration_cap,
			"max_rounds_safety_cap": max_rounds,
			"rng_master_seed": rng_master_seed,
			"timestamp": Time.get_datetime_string_from_system(true),
		},
		"summary": summary,
		"games": games,
		"self_eval_traces": self_eval_traces,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[ModeCmp] No se pudo abrir %s para escribir" % path)
		return
	f.store_string(JSON.stringify(payload, "  "))
	f.close()
	print("[ModeCmp] JSON volcado en: %s" % path)
