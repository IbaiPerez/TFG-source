extends GutTest

## Validación de GENERALIZACIÓN del campeón del optimizador.
##
## Carga los pesos guardados (res://resources/ai/heuristic_weights_optimized.tres)
## y los mide contra un pool HELD-OUT que NO se usó en la búsqueda/validación:
##   - baseline (referencia cara a cara, en semillas nuevas),
##   - k heurísticas de pesos ALEATORIOS frescos (fuera de los 3 arquetipos),
##   - opcional: MCTS (rival de lookahead fuerte) si INCLUDE_MCTS=1.
##
## Compara campeón vs baseline sobre los MISMOS rivales para aislar la mejora.
## Cierra el caveat de la corrida 2-etapas (validada contra la misma familia de
## arquetipos): si el campeón sigue ganando aquí, la mejora generaliza.
##
## Lanzar (UI): selecciona este script en el panel GUT (con "Include Subdirs").
## CLI:
##   $env:RUN_VALIDATE_CHAMPION='1'; & godot --headless -s addons/gut/gut_cmdln.gd `
##     "-gconfig=" -gtest=res://tests/simulation/test_validate_champion.gd -gexit
##   Añade $env:INCLUDE_MCTS='1' para incluir el rival MCTS (más lento).
##   $env:OPT_SMOKE='1' para el smoke.
##
## Salida: user://validate_champion.json


const ENABLE_FROM_GUI := true
const CHAMPION_PATH := "res://resources/ai/heuristic_weights_optimized.tres"

# --- Parámetros (ajustables por env var) ------------------------------------
const VAL_GAMES := 30             ## partidas/matchup contra el pool heurístico
const HELDOUT_K := 3              ## nº de heurísticas aleatorias frescas
const HELDOUT_OPP_SEED := 777     ## semilla que genera los pesos aleatorios
const HELDOUT_GAME_SEED := 20270115  ## semilla de las PARTIDAS (disjunta de search/validate)
const MAX_ROUNDS := 300
const MCTS_GAMES := 12            ## partidas vs MCTS (pocas: es lento)
const MCTS_BUDGET_MS := 500       ## presupuesto de tiempo del MCTS (como las sims 500/750/1000 ms)

# Smoke
const SMOKE_GAMES := 1
const SMOKE_K := 1
const SMOKE_MAX_ROUNDS := 120


func test_validate_champion() -> void:
	if not (ENABLE_FROM_GUI or OS.get_environment("RUN_VALIDATE_CHAMPION") != ""):
		pass_test("Saltado: RUN_VALIDATE_CHAMPION=1 (o ENABLE_FROM_GUI=true) para ejecutar.")
		return

	var champion := load(CHAMPION_PATH) as HeuristicWeights
	assert_not_null(champion, "No se pudo cargar el campeón en %s" % CHAMPION_PATH)
	if champion == null:
		return

	var smoke := OS.get_environment("OPT_SMOKE") != ""
	var baseline := HeuristicWeights.new()

	# ---- Pool HELD-OUT heurístico (baseline + k aleatorias frescas) -------
	var fit := HeuristicFitness.new(self)
	fit.n_games = SMOKE_GAMES if smoke else _int_env("VAL_GAMES", VAL_GAMES)
	fit.seed_master = HELDOUT_GAME_SEED
	fit.mirror = true
	fit.max_rounds = SMOKE_MAX_ROUNDS if smoke else MAX_ROUNDS
	fit.opponents = HeuristicOpponents.heldout_pool(
		HELDOUT_OPP_SEED, SMOKE_K if smoke else _int_env("HELDOUT_K", HELDOUT_K))
	print("[valida] === Pool HELD-OUT heurístico: %d rivales · %d partidas/matchup · seed disjunto ===" % [
		fit.opponents.size(), fit.n_games])

	var d_champ := await fit.evaluate_detailed(champion)
	var d_base := await fit.evaluate_detailed(baseline)
	# per_opponent[0] es la baseline (primer elemento del heldout_pool).
	var champ_vs_base: float = d_champ["per_opponent"][0]["winrate"]

	print("[valida] baseline  WR %.3f  IC95[%.3f, %.3f]  (%d decisivas)" % [
		d_base["winrate"], d_base["ci95_lo"], d_base["ci95_hi"], int(d_base["decisive"])])
	print("[valida] CAMPEÓN   WR %.3f  IC95[%.3f, %.3f]  (%d decisivas)" % [
		d_champ["winrate"], d_champ["ci95_lo"], d_champ["ci95_hi"], int(d_champ["decisive"])])
	print("[valida] campeón cara a cara vs baseline (seeds nuevos): %.3f" % champ_vs_base)

	# ---- Opcional: rival MCTS -------------------------------------------
	var mcts_report := {}
	if OS.get_environment("INCLUDE_MCTS") != "" and not smoke:
		var fit_m := HeuristicFitness.new(self)
		fit_m.n_games = _int_env("MCTS_GAMES", MCTS_GAMES)
		fit_m.seed_master = HELDOUT_GAME_SEED
		fit_m.mirror = true
		fit_m.max_rounds = MAX_ROUNDS
		var budget := _int_env("MCTS_BUDGET_MS", MCTS_BUDGET_MS)
		fit_m.opponents = [HeuristicOpponents.mcts_config(budget)]
		print("[valida] === Rival MCTS (presupuesto %d ms) · %d partidas ===" % [budget, fit_m.n_games])
		var dc := await fit_m.evaluate_detailed(champion)
		var db := await fit_m.evaluate_detailed(baseline)
		mcts_report = {
			"budget_ms": budget,
			"games": fit_m.n_games,
			"champion": {"winrate": dc["winrate"], "ci95_lo": dc["ci95_lo"], "ci95_hi": dc["ci95_hi"], "decisive": dc["decisive"]},
			"baseline": {"winrate": db["winrate"], "ci95_lo": db["ci95_lo"], "ci95_hi": db["ci95_hi"], "decisive": db["decisive"]},
		}
		print("[valida] vs MCTS  baseline WR %.3f  |  CAMPEÓN WR %.3f" % [
			db["winrate"], dc["winrate"]])

	# ---- Informe --------------------------------------------------------
	var payload := {
		"champion_path": CHAMPION_PATH,
		"heldout_opp_seed": HELDOUT_OPP_SEED,
		"heldout_game_seed": HELDOUT_GAME_SEED,
		"games_per_matchup": fit.n_games,
		"pool_size": fit.opponents.size(),
		"baseline_vs_pool": {"winrate": d_base["winrate"], "ci95_lo": d_base["ci95_lo"], "ci95_hi": d_base["ci95_hi"], "decisive": d_base["decisive"], "per_opponent": _po(d_base)},
		"champion_vs_pool": {"winrate": d_champ["winrate"], "ci95_lo": d_champ["ci95_lo"], "ci95_hi": d_champ["ci95_hi"], "decisive": d_champ["decisive"], "per_opponent": _po(d_champ)},
		"champion_head_to_head_vs_baseline": champ_vs_base,
		"mcts": mcts_report,
		"timestamp": Time.get_datetime_string_from_system(true),
	}
	var f := FileAccess.open("user://validate_champion.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(payload, "  "))
		f.close()
		print("[valida] informe en: %s" % ProjectSettings.globalize_path("user://validate_champion.json"))

	WorldMap.map = []
	WorldMap.map_as_dict = {}
	BattleFront.clear_active_instances()
	for e in get_errors():
		e.handled = true


func _po(d: Dictionary) -> Array:
	var out: Array = []
	for r in d["per_opponent"]:
		out.append({"label": r["label"], "winrate": r["winrate"], "decisive": r["decisive"]})
	return out


func _int_env(name: String, fallback: int) -> int:
	var v := OS.get_environment(name)
	return int(v) if v != "" else fallback
