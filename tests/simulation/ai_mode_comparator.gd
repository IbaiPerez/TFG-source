extends RefCounted
class_name AIModeComparator

## Enfrenta DOS contendientes de IA (A vs B) en una TANDA de N partidas headless
## y mide quién gana y a qué coste. Es AGNÓSTICO al tipo: cada contendiente es un
## AIConfig + una etiqueta legible. Así sirve para cualquier emparejamiento del
## round-robin:
##   - Heurística            vs ISMCTS (rollout heurístico)
##   - Heurística            vs ISMCTS (rollout aleatorio)
##   - ISMCTS (heurístico)   vs ISMCTS (aleatorio)
##
## Sin `mirror`, el contendiente A juega SIEMPRE como AI_A (mueve primero) y B
## como AI_B, y AI_A conserva la ventaja de primer turno (se documenta en el
## volcado). Con `mirror = true`, cada semilla se juega DOS veces con los
## asientos cambiados: las métricas a_*/b_* siguen siendo del CONTENDIENTE, no
## del asiento, así que el win-rate queda neutralizado frente al primer turno.
##
## `run()` juega todas las semillas de golpe. Para intercalar varias tandas
## (p.ej. barrer presupuestos semilla a semilla) el llamante usa `play_seed()`
## + `finalize()` + `dump_to()` por su cuenta; `load_from()` reanuda desde un
## volcado previo.
##
## Métricas por bando (a_*/b_*): win-rate con IC95, ms/turno, y diagnóstico MCTS
## (override del prior, iters por decisión = cómputo, visitas-raíz por decisión =
## profundidad efectiva con warm start, y el ratio de reutilización de subárbol).
##
## Uso:
##   var cmp := AIModeComparator.new()
##   cmp.config_a = <AIConfig>; cmp.label_a = "ISMCTS_H"
##   cmp.config_b = <AIConfig>; cmp.label_b = "HEUR"
##   cmp.n_games = 50
##   cmp.matchup_name = "ISMCTS_H_vs_HEUR"
##   cmp.attach_to(gut_test)
##   await cmp.run()
##   cmp.dump_to("user://sim_ISMCTS_H_vs_HEUR_500ms.json")


# --- Config de la tanda ------------------------------------------------------

var config_a: AIConfig = null       ## Contendiente A (juega como AI_A, mueve primero)
var config_b: AIConfig = null       ## Contendiente B (juega como AI_B)
var label_a: String = "A"           ## Etiqueta legible de A (p.ej. "ISMCTS_H")
var label_b: String = "B"           ## Etiqueta legible de B (p.ej. "HEUR")
var matchup_name: String = ""       ## Nombre del emparejamiento (para metadata)
var budget_ms: int = 0              ## Presupuesto de los MCTS de la tanda (solo metadata/resumen)

var n_games: int = 50               ## Semillas de la tanda (×2 partidas si mirror)
var mirror: bool = false            ## Jugar cada semilla también con los asientos cambiados
var max_rounds: int = 500           ## Límite de seguridad por partida
var rng_master_seed: int = 20260611 ## MISMO entre tandas → mismas partidas
var self_eval_games: int = 0        ## Nº de partidas con traza de auto-evaluación
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
	# partida → todas las tandas (distinto emparejamiento/budget) juegan las
	# MISMAS N partidas (mapa, recursos, imperios).
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_master_seed

	for i in range(n_games):
		await play_seed(i, rng.randi(), i < self_eval_games)
	finalize()


## Juega la semilla `idx`: una partida (A en AI_A) y, con mirror, otra con los
## asientos cambiados sobre el MISMO mapa.
func play_seed(idx: int, game_seed: int, trace: bool = false) -> void:
	await _play_game(idx, game_seed, trace, false)
	if mirror:
		await _play_game(idx, game_seed, trace, true)


func finalize() -> void:
	summary = _aggregate()


## Reanuda desde un volcado previo de dump_to(). Devuelve el nº de partidas
## recuperadas (0 si el fichero no existe o no se pudo leer).
func load_from(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or not parsed.has("games"):
		return 0
	games = parsed["games"]
	self_eval_traces = parsed.get("self_eval_traces", [])
	return games.size()


# --- Una partida -------------------------------------------------------------

## `swapped` = false → A juega en AI_A (mueve primero); true → A en AI_B.
## El registro y las métricas se indexan por CONTENDIENTE (a_*/b_*), no por asiento.
func _play_game(idx: int, game_seed: int, trace: bool, swapped: bool) -> void:
	# Determinismo del mapa/imperios: el WorldGenerator usa el RNG GLOBAL para
	# barajar imperios y sembrar los ruidos. Sembrarlo con game_seed garantiza
	# que la misma partida idx tenga el mismo mapa/recursos en todas las tandas.
	seed(game_seed)

	var harness := GameSimHarness.new()
	harness.max_rounds = max_rounds
	harness.run_id = idx
	harness.capture_snapshots = capture_snapshots
	harness.capture_self_eval = trace
	harness.config_a = config_b if swapped else config_a
	harness.config_b = config_a if swapped else config_b
	var run_rng := RandomNumberGenerator.new()
	run_rng.seed = game_seed
	harness.rng_master = run_rng
	harness.attach_to(_gut_test)
	await harness.run()

	var seat_a := "AI_B" if swapped else "AI_A"
	var seat_b := "AI_A" if swapped else "AI_B"
	var winner_side := ""
	if harness.winner_label == seat_a:
		winner_side = "A"
	elif harness.winner_label == seat_b:
		winner_side = "B"

	games.append({
		"game": idx,
		"a_seat": seat_a,
		"map": harness.run_seed_meta,
		"winner_label": harness.winner_label,
		"winner_side": winner_side,
		"victory_condition": harness.victory_condition,
		"finished_round": harness.finished_round,
		"a_usec": int(harness.turn_usec_by_label[seat_a]),
		"a_turns": int(harness.turns_by_label[seat_a]),
		"b_usec": int(harness.turn_usec_by_label[seat_b]),
		"b_turns": int(harness.turns_by_label[seat_b]),
		"a_mcts": harness.mcts_stats_by_label[seat_a],
		"b_mcts": harness.mcts_stats_by_label[seat_b],
		"final_tiles_a": harness.final_tiles_a if not swapped else harness.final_tiles_b,
		"final_tiles_b": harness.final_tiles_b if not swapped else harness.final_tiles_a,
		"final_total_tiles": harness.final_total_tiles,
		"colonized_pct": float(harness.final_tiles_a + harness.final_tiles_b)
			/ float(maxi(harness.final_total_tiles, 1)),
		"a_actions": (harness.actions_by_label[seat_a] as Dictionary).duplicate(),
		"b_actions": (harness.actions_by_label[seat_b] as Dictionary).duplicate(),
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


# --- Agregación --------------------------------------------------------------

func _aggregate() -> Dictionary:
	var a_wins := 0
	var b_wins := 0
	var draws := 0
	var a_usec := 0
	var a_turns := 0
	var b_usec := 0
	var b_turns := 0
	var rounds: Array = []
	var colonized: Array = []
	var a_acc := _new_mcts_acc()
	var b_acc := _new_mcts_acc()
	var a_actions := {}
	var b_actions := {}

	for g in games:
		match g["winner_side"]:
			"A": a_wins += 1
			"B": b_wins += 1
			_: draws += 1
		a_usec += int(g["a_usec"])
		a_turns += int(g["a_turns"])
		b_usec += int(g["b_usec"])
		b_turns += int(g["b_turns"])
		_accumulate_mcts(a_acc, g["a_mcts"])
		_accumulate_mcts(b_acc, g["b_mcts"])
		if int(g["finished_round"]) > 0:
			rounds.append(int(g["finished_round"]))
		colonized.append(float(g["colonized_pct"]))
		_merge_counts(a_actions, g["a_actions"])
		_merge_counts(b_actions, g["b_actions"])

	var decisive := a_wins + b_wins
	var wr := float(a_wins) / float(maxi(decisive, 1))
	# IC 95% (aproximación normal) del win-rate decisivo del contendiente A.
	var ci := 1.96 * sqrt(wr * (1.0 - wr) / float(maxi(decisive, 1)))
	var ms_a := (float(a_usec) / float(maxi(a_turns, 1))) / 1000.0
	var ms_b := (float(b_usec) / float(maxi(b_turns, 1))) / 1000.0

	var s := {
		"matchup": matchup_name,
		"label_a": label_a,
		"label_b": label_b,
		"budget_ms": budget_ms,
		"games": games.size(),
		"a_wins": a_wins,
		"b_wins": b_wins,
		"draws": draws,
		"a_winrate_decisive": wr,
		"a_winrate_ci95_lo": clampf(wr - ci, 0.0, 1.0),
		"a_winrate_ci95_hi": clampf(wr + ci, 0.0, 1.0),
		"a_winrate_all": float(a_wins) / float(maxi(games.size(), 1)),
		"ms_per_turn_a": ms_a,
		"ms_per_turn_b": ms_b,
		"cost_overhead_factor": ms_a / maxf(ms_b, 0.0001),
		"avg_rounds": _avg(rounds),
		# La lista completa, no solo la media: la distribución de duración es un
		# resultado por sí misma (cuántas partidas llegan al tope de rondas dice
		# si el tope está sesgando el win-rate) y la media sola la esconde.
		"rounds": rounds,
		"avg_colonized_pct": _avg(colonized),
		"a_actions": a_actions,
		"b_actions": b_actions,
	}
	_merge_mcts_summary(s, "a", a_acc)
	_merge_mcts_summary(s, "b", b_acc)
	return s


func _new_mcts_acc() -> Dictionary:
	return {"decisions": 0, "overrides": 0, "iterations": 0, "root_visits": 0}


func _accumulate_mcts(acc: Dictionary, src: Dictionary) -> void:
	acc["decisions"] += int(src.get("decisions", 0))
	acc["overrides"] += int(src.get("prior_overrides", 0))
	acc["iterations"] += int(src.get("total_iterations", 0))
	acc["root_visits"] += int(src.get("total_root_visits", 0))


## Vuelca las métricas MCTS agregadas de un bando al resumen con prefijo a_/b_.
## Para un bando heurístico (decisions=0) todas salen 0.
func _merge_mcts_summary(s: Dictionary, prefix: String, acc: Dictionary) -> void:
	var dec: int = acc["decisions"]
	var iters: int = acc["iterations"]
	s["%s_decisions" % prefix] = dec
	# Frecuencia con que la búsqueda se apartó del prior heurístico.
	s["%s_prior_override_rate" % prefix] = float(acc["overrides"]) / float(maxi(dec, 1))
	# Iteraciones NUEVAS por decisión (cómputo real gastado).
	s["%s_avg_iters_per_decision" % prefix] = float(iters) / float(maxi(dec, 1))
	# Visitas en raíz por decisión: con reutilización de subárbol incluye el warm
	# start heredado → profundidad de búsqueda EFECTIVA.
	s["%s_avg_root_visits_per_decision" % prefix] = float(acc["root_visits"]) / float(maxi(dec, 1))
	# Ratio > 1 ⇒ la persistencia del árbol aporta visitas heredadas.
	s["%s_warm_start_ratio" % prefix] = float(acc["root_visits"]) / float(maxi(iters, 1))


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

## Resumen de los parámetros relevantes de un AIConfig, para el bloque metadata.
func _config_meta(cfg: AIConfig) -> Dictionary:
	if cfg == null:
		return {"mode": "DEFAULT"}
	var weights := "default" if cfg.heuristic_weights == null else cfg.heuristic_weights.resource_path
	if cfg.mode == AIConfig.Mode.HEURISTIC:
		return {"mode": "HEURISTIC", "weights": weights}
	return {
		"mode": "MCTS",
		"weights": weights,
		"time_budget_ms": cfg.mcts_time_budget_ms,
		"rollout_depth": cfg.mcts_rollout_depth,
		"heuristic_rollout": cfg.mcts_heuristic_rollout,
		"exploration_c": cfg.mcts_exploration_c,
		"action_pruning_k": cfg.mcts_action_pruning_k,
		"iterations_cap": cfg.mcts_iterations,
	}


func dump_to(path: String) -> void:
	var payload := {
		"metadata": {
			"matchup": matchup_name,
			"label_a": label_a,
			"label_b": label_b,
			"budget_ms": budget_ms,
			"mirror": mirror,
			"games_played": games.size(),
			"config_a": _config_meta(config_a),
			"config_b": _config_meta(config_b),
			"max_rounds_safety_cap": max_rounds,
			"rng_master_seed": rng_master_seed,
			"first_move_advantage": "neutralizada: cada semilla jugada en ambos asientos" if mirror
				else "AI_A (label_a) mueve primero — sin pares-espejo",
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
