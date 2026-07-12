extends GutTest

## Optimización de pesos de la heurística en DOS ETAPAS contra un POOL de rivales
## (baseline + arquetipos de heurística + random), SIN MCTS.
##
##   Etapa 1 (búsqueda, barata): SA y GA exploran contra un pool ligero
##     (core_pool) con pocas partidas/eval. Objetivo: localizar buenos candidatos.
##   Etapa 2 (revalidación, cara): los finalistas (baseline + campeón SA + campeón
##     GA) se re-evalúan contra el pool completo (full_pool, incluye random) con
##     MUCHAS partidas y SEMILLAS DISJUNTAS → win-rate con IC95 fiable, sin
##     sobreajuste al set de búsqueda.
##
## Cómo lanzar desde la UI: selecciona este script (o el método test_two_stage)
## en el panel GUT y Run. OJO: NO uses "Run All" si tu config incluye
## tests/simulation/ — dispararía esta corrida larga.
##
## Por CLI:
##   $env:RUN_OPT_2STAGE=1; & godot --headless -s addons/gut/gut_cmdln.gd `
##     "-gconfig=" -gtest=res://tests/simulation/test_optimize_heuristic_2stage.gd -gexit
## Smoke: añade $env:OPT_SMOKE=1.
##
## Salidas en user://: heuristic_weights_2stage.tres + opt_2stage.json


const ENABLE_FROM_GUI := true

# --- Parámetros por defecto (ajustables por env var) ------------------------
const STAGE1_GAMES := 10          ## partidas/matchup en la búsqueda
const STAGE1_SA_ITERS := 50
const STAGE1_GA_POP := 10
const STAGE1_GA_GENS := 6
const STAGE2_GAMES := 80          ## partidas/matchup en la revalidación
const STAGE_MAX_ROUNDS := 300     ## tope de rondas por partida (dial de velocidad)
const SEARCH_SEED := 20260706
const VALIDATE_SEED := 20261231   ## DISJUNTO del de búsqueda

# Smoke: valores mínimos para comprobar el flujo end-to-end (rápido).
const SMOKE_GAMES := 1
const SMOKE_SA_ITERS := 1
const SMOKE_GA_POP := 3
const SMOKE_GA_GENS := 1
const SMOKE_STAGE2_GAMES := 1
const SMOKE_MAX_ROUNDS := 120


func test_two_stage() -> void:
	if not (ENABLE_FROM_GUI or OS.get_environment("RUN_OPT_2STAGE") != ""):
		pass_test("Saltado: RUN_OPT_2STAGE=1 (o ENABLE_FROM_GUI=true) para ejecutar.")
		return
	var smoke := OS.get_environment("OPT_SMOKE") != ""

	# ---- Etapa 1: búsqueda contra el pool ligero -------------------------
	var fit1 := HeuristicFitness.new(self)
	fit1.n_games = SMOKE_GAMES if smoke else _int_env("STAGE1_GAMES", STAGE1_GAMES)
	fit1.seed_master = SEARCH_SEED
	fit1.mirror = true
	fit1.max_rounds = SMOKE_MAX_ROUNDS if smoke else _int_env("STAGE_MAX_ROUNDS", STAGE_MAX_ROUNDS)
	# En smoke solo 1 rival (baseline) para que el flujo termine en segundos.
	fit1.opponents = [HeuristicOpponents.heur_config(HeuristicOpponents.baseline())] \
		if smoke else HeuristicOpponents.core_pool()
	print("[2stage] === ETAPA 1: búsqueda · pool ligero (%d rivales) · %d partidas/matchup ===" % [
		fit1.opponents.size(), fit1.n_games])

	var sa := SAOptimizer.new(fit1, 4242)
	sa.iterations = SMOKE_SA_ITERS if smoke else _int_env("STAGE1_SA_ITERS", STAGE1_SA_ITERS)
	print("[2stage] -- SA (%d iters) --" % sa.iterations)
	var sa_champ: HeuristicWeights = await sa.run()

	var ga := GAOptimizer.new(fit1, 999)
	ga.pop_size = SMOKE_GA_POP if smoke else _int_env("STAGE1_GA_POP", STAGE1_GA_POP)
	ga.generations = SMOKE_GA_GENS if smoke else _int_env("STAGE1_GA_GENS", STAGE1_GA_GENS)
	print("[2stage] -- GA (pop %d × %d gen) --" % [ga.pop_size, ga.generations])
	var ga_champ: HeuristicWeights = await ga.run()

	# ---- Etapa 2: revalidación pesada de los finalistas ------------------
	var finalists := [
		{"name": "baseline", "w": HeuristicWeights.new()},
		{"name": "sa", "w": sa_champ},
		{"name": "ga", "w": ga_champ},
	]
	var fit2 := HeuristicFitness.new(self)
	fit2.n_games = SMOKE_STAGE2_GAMES if smoke else _int_env("STAGE2_GAMES", STAGE2_GAMES)
	fit2.seed_master = VALIDATE_SEED
	fit2.mirror = true
	fit2.max_rounds = SMOKE_MAX_ROUNDS if smoke else _int_env("STAGE_MAX_ROUNDS", STAGE_MAX_ROUNDS)
	# En smoke, pool reducido (core) para acabar rápido; real usa el completo.
	fit2.opponents = HeuristicOpponents.core_pool() if smoke else HeuristicOpponents.full_pool()
	print("[2stage] === ETAPA 2: revalidación · pool completo (%d rivales) · %d partidas/matchup · seed DISJUNTO ===" % [
		fit2.opponents.size(), fit2.n_games])

	var report: Array = []
	var champion = null
	var champion_wr := -1.0
	for f in finalists:
		var d := await fit2.evaluate_detailed(f["w"])
		var row := {
			"name": f["name"],
			"winrate": d["winrate"],
			"ci95_lo": d["ci95_lo"],
			"ci95_hi": d["ci95_hi"],
			"decisive": d["decisive"],
			"per_opponent": _summarize_per_opponent(d["per_opponent"]),
		}
		report.append(row)
		print("[2stage] %-9s WR %.3f  IC95[%.3f, %.3f]  (%d decisivas)" % [
			f["name"], d["winrate"], d["ci95_lo"], d["ci95_hi"], int(d["decisive"])])
		if float(d["winrate"]) > champion_wr:
			champion_wr = float(d["winrate"])
			champion = f["w"]

	# ---- Guardado -------------------------------------------------------
	assert_not_null(champion, "Debe haber un campeón")
	var tres_path := "user://heuristic_weights_2stage.tres"
	var err := ResourceSaver.save(champion, tres_path)
	assert_eq(err, OK, "Debe guardar %s" % tres_path)
	print("[2stage] campeón (WR %.3f) guardado en: %s" % [
		champion_wr, ProjectSettings.globalize_path(tres_path)])

	var payload := {
		"keys": Array(HeuristicWeights.OPTIMIZABLE_KEYS),
		"search_seed": SEARCH_SEED,
		"validate_seed": VALIDATE_SEED,
		"stage1_games": fit1.n_games,
		"stage2_games": fit2.n_games,
		"finalists": report,
		"champion_winrate": champion_wr,
		"champion_weights": _weights_dict(champion),
		"sa_trace": sa.trace,
		"ga_trace": ga.trace,
		"total_games_played": fit1.evals + fit2.evals,
		"cache_hits": fit1.cache_hits + fit2.cache_hits,
		"timestamp": Time.get_datetime_string_from_system(true),
	}
	var f := FileAccess.open("user://opt_2stage.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(payload, "  "))
		f.close()
		print("[2stage] informe JSON en: %s" % ProjectSettings.globalize_path("user://opt_2stage.json"))

	WorldMap.map = []
	WorldMap.map_as_dict = {}
	BattleFront.clear_active_instances()
	for e in get_errors():
		e.handled = true


# --- Helpers -----------------------------------------------------------------

func _summarize_per_opponent(per: Array) -> Array:
	var out: Array = []
	for r in per:
		out.append({"label": r["label"], "winrate": r["winrate"], "decisive": r["decisive"]})
	return out


func _weights_dict(w: HeuristicWeights) -> Dictionary:
	var out := {}
	for k in HeuristicWeights.OPTIMIZABLE_KEYS:
		out[k] = w.get(k)
	return out


func _int_env(name: String, fallback: int) -> int:
	var v := OS.get_environment(name)
	return int(v) if v != "" else fallback
