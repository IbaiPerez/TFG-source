extends GutTest

## Benchmark: CAMPEÓN-MCTS (ai_config_mcts_optimized) vs BASELINE-MCTS
## (ai_config_mcts_heuristic), ambos MCTS con presupuesto 1000 ms. Mide el
## win-rate del campeón con IC95, con MIRROR (juega como A y como B sobre la
## MISMA semilla) para neutralizar la ventaja de primer turno.
##
## ACOTADO POR TIEMPO (nunca supera el presupuesto): antes de cada PAR de
## partidas estima si el siguiente par cabe (media móvil × margen); si no, para.
## Vuelca resultados PARCIALES tras cada par en user://bench_mcts_optimized.json,
## así que si se corta (o lo detienes) hay datos y un IC95 con lo jugado.
##
## Determinismo: el modo por tiempo NO es determinista (nº de iteraciones ∝
## velocidad de la máquina); es una MEDIDA estadística, no una búsqueda.
##
## Lanzar (una noche, PowerShell, una sola línea):
##   $env:RUN_BENCH_MCTS='1'; & 'C:\Users\ibaip\Desktop\Godot_v4.5-stable_win64.exe\Godot_v4.5-stable_win64_console.exe' --headless -s addons/gut/gut_cmdln.gd "-gconfig=" -gtest=res://tests/simulation/test_bench_mcts_optimized.gd -gexit
##   Opcionales:  $env:BENCH_HOURS='7.5'   $env:BENCH_MAX_ROUNDS='300'
##   Smoke rápido (1 par a 40 ms y sale): añade  $env:BENCH_SMOKE='1'
##
## Salida (Windows): %APPDATA%\Godot\app_userdata\Source\bench_mcts_optimized.json


const ENABLE_FROM_GUI := false     # gated por RUN_BENCH_MCTS; no se dispara en Run All
const CHAMP_PATH := "res://resources/ai/ai_config_mcts_optimized.tres"
const BASE_PATH := "res://resources/ai/ai_config_mcts_heuristic.tres"

const HOURS := 7.5                 # presupuesto de reloj (máx del usuario: 8 h → margen)
const MAX_ROUNDS := 300            # tope de rondas por partida (acota duración/partida)
const RNG_SEED := 20270201         # disjunto de search (20260706) / validate (20261231 / 20270115)
const SAFETY := 1.5                # margen predictivo sobre el tiempo medio por par


func test_bench_mcts_optimized() -> void:
	if not (ENABLE_FROM_GUI or OS.get_environment("RUN_BENCH_MCTS") != ""):
		pass_test("Saltado: RUN_BENCH_MCTS=1 (o ENABLE_FROM_GUI=true) para ejecutar.")
		return

	var smoke := OS.get_environment("BENCH_SMOKE") != ""
	var champ := load(CHAMP_PATH) as AIConfig
	var base := load(BASE_PATH) as AIConfig
	assert_not_null(champ, "No se cargó %s" % CHAMP_PATH)
	assert_not_null(base, "No se cargó %s" % BASE_PATH)
	if champ == null or base == null:
		return

	var max_rounds := _int_env("BENCH_MAX_ROUNDS", MAX_ROUNDS)
	var budget_ms := int(_float_env("BENCH_HOURS", HOURS) * 3600.0 * 1000.0)

	# Duplicar (no mutar el recurso compartido/desplegado) y forzar límite por
	# TIEMPO: tope de iteraciones ALTO → la búsqueda para por tiempo, no por
	# iteraciones. Sin esto, el default 500 de mcts_iterations ataría antes de
	# agotar el presupuesto en estados baratos (haría el MCTS iteration-limited).
	# Es la metodología de las sims/sweep (presupuesto de tiempo, ITER_CAP alto).
	champ = champ.duplicate() as AIConfig
	base = base.duplicate() as AIConfig
	champ.mcts_iterations = 100000
	base.mcts_iterations = 100000
	if smoke:
		# Smoke: presupuesto MCTS diminuto + pocas rondas para acabar en ~1 min.
		champ.mcts_time_budget_ms = 40
		base.mcts_time_budget_ms = 40
		max_rounds = 40

	print("[bench] CAMPEÓN-MCTS vs BASELINE-MCTS (%d ms) · mirror · presupuesto %.1f h · max_rounds %d" % [
		champ.mcts_time_budget_ms, float(budget_ms) / 3600000.0, max_rounds])

	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED
	var start := Time.get_ticks_msec()

	var champ_wins := 0
	var decisive := 0
	var draws := 0
	var pairs := 0
	var rounds_sum := 0
	var rounds_n := 0
	var conditions := {"domination": 0, "elimination": 0}

	while true:
		var elapsed := Time.get_ticks_msec() - start
		if pairs > 0:
			# ¿Cabe otro par? Media móvil por par × margen de seguridad.
			var avg_pair := float(elapsed) / float(pairs)
			if float(elapsed) + avg_pair * SAFETY > float(budget_ms):
				print("[bench] presupuesto agotado (elapsed %.2f h, media/par %.1f min) → paro" % [
					elapsed / 3600000.0, avg_pair / 60000.0])
				break
		elif elapsed > budget_ms:
			break

		var game_seed := rng.randi()
		# Partida 1: campeón = A (mueve primero). Partida 2: campeón = B (misma semilla).
		var g1 := await _play(champ, base, game_seed, max_rounds, pairs * 2)
		var g2 := await _play(base, champ, game_seed, max_rounds, pairs * 2 + 1)
		pairs += 1

		for entry in [{"r": g1, "champ_side": "AI_A"}, {"r": g2, "champ_side": "AI_B"}]:
			var r: Dictionary = entry["r"]
			var winner: String = r["winner"]
			if winner == "":
				draws += 1
			else:
				decisive += 1
				if winner == entry["champ_side"]:
					champ_wins += 1
				var cond: String = r["condition"]
				if conditions.has(cond):
					conditions[cond] += 1
			if int(r["rounds"]) > 0:
				rounds_sum += int(r["rounds"])
				rounds_n += 1

		_dump(champ_wins, decisive, draws, pairs, rounds_sum, rounds_n, conditions,
			Time.get_ticks_msec() - start, budget_ms, max_rounds, champ.mcts_time_budget_ms, false)

		var wr_now := float(champ_wins) / float(maxi(decisive, 1))
		print("[bench] par %d · %d partidas · campeón WR %.3f (%d/%d dec, %d empates) · %.2f h" % [
			pairs, pairs * 2, wr_now, champ_wins, decisive, draws,
			(Time.get_ticks_msec() - start) / 3600000.0])

		if smoke and pairs >= 1:
			break

	# Resumen final.
	var wr := float(champ_wins) / float(maxi(decisive, 1))
	var ci := 1.96 * sqrt(wr * (1.0 - wr) / float(maxi(decisive, 1)))
	print("[bench] === FINAL: %d partidas · campeón WR %.3f  IC95[%.3f, %.3f]  (%d decisivas, %d empates) ===" % [
		pairs * 2, wr, clampf(wr - ci, 0.0, 1.0), clampf(wr + ci, 0.0, 1.0), decisive, draws])
	_dump(champ_wins, decisive, draws, pairs, rounds_sum, rounds_n, conditions,
		Time.get_ticks_msec() - start, budget_ms, max_rounds, champ.mcts_time_budget_ms, true)

	assert_gt(pairs, 0, "Debe haberse jugado al menos un par")
	WorldMap.map = []
	WorldMap.map_as_dict = {}
	BattleFront.clear_active_instances()
	for e in get_errors():
		e.handled = true


# --- Una partida (espejo de AIModeComparator._play_game) --------------------

func _play(cfg_a: AIConfig, cfg_b: AIConfig, game_seed: int, max_rounds: int,
		run_id: int) -> Dictionary:
	# Sembrar el RNG global → mapa/imperios deterministas por semilla (idénticos
	# entre la partida-A y su espejo-B).
	seed(game_seed)
	var h := GameSimHarness.new()
	h.max_rounds = max_rounds
	h.run_id = run_id
	h.capture_snapshots = false
	h.config_a = cfg_a
	h.config_b = cfg_b
	var run_rng := RandomNumberGenerator.new()
	run_rng.seed = game_seed
	h.rng_master = run_rng
	h.attach_to(self)
	await h.run()
	var res := {
		"winner": h.winner_label,          # "AI_A" | "AI_B" | ""
		"condition": h.victory_condition,  # "domination" | "elimination" | ""
		"rounds": h.finished_round,
	}
	WorldMap.map = []
	WorldMap.map_as_dict = {}
	BattleFront.clear_active_instances()
	return res


func _dump(champ_wins: int, decisive: int, draws: int, pairs: int,
		rounds_sum: int, rounds_n: int, conditions: Dictionary,
		elapsed_ms: int, budget_ms: int, max_rounds: int, budget_mcts_ms: int,
		final: bool) -> void:
	var wr := float(champ_wins) / float(maxi(decisive, 1))
	var ci := 1.96 * sqrt(wr * (1.0 - wr) / float(maxi(decisive, 1)))
	var payload := {
		"matchup": "champion_mcts_vs_baseline_mcts",
		"mcts_budget_ms": budget_mcts_ms,
		"limited_by": "time",
		"mcts_iterations_cap": 100000,
		"max_rounds": max_rounds,
		"mirror": true,
		"rng_seed": RNG_SEED,
		"time_budget_h": float(budget_ms) / 3600000.0,
		"elapsed_h": float(elapsed_ms) / 3600000.0,
		"complete": final,
		"games_played": pairs * 2,
		"champion_wins": champ_wins,
		"decisive": decisive,
		"draws": draws,
		"champion_winrate": wr,
		"ci95_lo": clampf(wr - ci, 0.0, 1.0),
		"ci95_hi": clampf(wr + ci, 0.0, 1.0),
		"avg_rounds": (float(rounds_sum) / float(rounds_n)) if rounds_n > 0 else 0.0,
		"victory_conditions": conditions,
		"champion_config": CHAMP_PATH,
		"baseline_config": BASE_PATH,
		"timestamp": Time.get_datetime_string_from_system(true),
	}
	var f := FileAccess.open("user://bench_mcts_optimized.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(payload, "  "))
		f.close()


func _int_env(name: String, fallback: int) -> int:
	var v := OS.get_environment(name)
	return int(v) if v != "" else fallback


func _float_env(name: String, fallback: float) -> float:
	var v := OS.get_environment(name)
	return float(v) if v != "" else fallback
