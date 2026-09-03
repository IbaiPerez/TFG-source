extends GutTest

## Optimización de pesos de la heurística en DOS ETAPAS contra un POOL de rivales
## (baseline + arquetipos de heurística), SIN MCTS.
##
##   Etapa 1 (búsqueda, barata): SA y GA exploran contra un pool ligero
##     (search_pool: 3 arquetipos + N aleatorios frescos) con POCAS partidas por
##     rival. Objetivo: localizar candidatos buenos SIN que se especialicen.
##   Etapa 2 (revalidación, cara): los finalistas (baseline + campeón SA + campeón
##     GA) se re-evalúan contra un pool HELD-OUT (selection_pool: baseline + N
##     aleatorios de semilla disjunta, cero solapamiento con la búsqueda) con
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
const STAGE1_RIVALS := 16         ## heurísticas aleatorias frescas en la búsqueda
const STAGE2_RIVALS := 12         ## heurísticas aleatorias frescas en la selección
const TOP_K := 5                  ## finalistas que pasa CADA algoritmo a la etapa 2
const SEARCH_OPP_SEED := 31337    ## fija los rivales de búsqueda: los MISMOS para todos
const SELECT_OPP_SEED := 80085    ## rivales de selección: DISJUNTO del de búsqueda
const STAGE1_GAMES := 2           ## partidas/matchup en la búsqueda (muchos rivales)
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
		if smoke else HeuristicOpponents.search_pool(
			SEARCH_OPP_SEED, _int_env("STAGE1_RIVALS", STAGE1_RIVALS))
	print("[2stage] === ETAPA 1: búsqueda · pool ligero (%d rivales) · %d partidas/matchup ===" % [
		fit1.opponents.size(), fit1.n_games])

	var k_fin := 1 if smoke else _int_env("TOP_K", TOP_K)

	var sa := SAOptimizer.new(fit1, 4242)
	sa.iterations = SMOKE_SA_ITERS if smoke else _int_env("STAGE1_SA_ITERS", STAGE1_SA_ITERS)
	sa.top_k = k_fin
	print("[2stage] -- SA (%d iters, top-%d) --" % [sa.iterations, k_fin])
	await sa.run()

	var ga := GAOptimizer.new(fit1, 999)
	ga.pop_size = SMOKE_GA_POP if smoke else _int_env("STAGE1_GA_POP", STAGE1_GA_POP)
	ga.generations = SMOKE_GA_GENS if smoke else _int_env("STAGE1_GA_GENS", STAGE1_GA_GENS)
	ga.top_k = k_fin
	print("[2stage] -- GA (pop %d × %d gen, top-%d) --" % [ga.pop_size, ga.generations, k_fin])
	await ga.run()

	# ---- Etapa 2: revalidación pesada de los finalistas ------------------
	# Pasan los K mejores de cada algoritmo, no el argmax: quedarse con el mejor
	# del pool de BÚSQUEDA es el paso de sobreajuste, porque ese es por
	# construcción el más afinado a esos rivales. Con top-K decide el held-out.
	var finalists: Array = [{"name": "baseline", "w": HeuristicWeights.new()}]
	for i in range(sa.top.size()):
		finalists.append({"name": "sa_%d" % (i + 1), "w": sa.top.to_array()[i]["weights"]})
	for i in range(ga.top.size()):
		finalists.append({"name": "ga_%d" % (i + 1), "w": ga.top.to_array()[i]["weights"]})
	print("[2stage] finalistas: %d (baseline + %d de SA + %d de GA)" % [
		finalists.size(), sa.top.size(), ga.top.size()])
	var fit2 := HeuristicFitness.new(self)
	fit2.n_games = SMOKE_STAGE2_GAMES if smoke else _int_env("STAGE2_GAMES", STAGE2_GAMES)
	fit2.seed_master = VALIDATE_SEED
	fit2.mirror = true
	fit2.max_rounds = SMOKE_MAX_ROUNDS if smoke else _int_env("STAGE_MAX_ROUNDS", STAGE_MAX_ROUNDS)
	# En smoke, pool reducido (core) para acabar rápido; real usa el completo.
	fit2.opponents = HeuristicOpponents.selection_pool(SELECT_OPP_SEED, 2) if smoke \
		else HeuristicOpponents.selection_pool(
			SELECT_OPP_SEED, _int_env("STAGE2_RIVALS", STAGE2_RIVALS))
	print("[2stage] === ETAPA 2: revalidación · pool completo (%d rivales) · %d partidas/matchup · seed DISJUNTO ===" % [
		fit2.opponents.size(), fit2.n_games])

	var report: Array = []
	for f in finalists:
		var d := await fit2.evaluate_detailed(f["w"])
		var derrotas := _derrotas_significativas(d["per_opponent"])
		var row := {
			"name": f["name"],
			"winrate": d["winrate"],
			"ci95_lo": d["ci95_lo"],
			"ci95_hi": d["ci95_hi"],
			"decisive": d["decisive"],
			"significant_losses": derrotas,
			"weights": f["w"],
			"per_opponent": _summarize_per_opponent(d["per_opponent"]),
		}
		report.append(row)
		print("[2stage] %-9s WR %.3f  IC95[%.3f, %.3f]  (%d decisivas)  derrotas sig.: %d" % [
			f["name"], d["winrate"], d["ci95_lo"], d["ci95_hi"], int(d["decisive"]), derrotas])

	var champion_row := _elegir_campeon(report)
	var champion = champion_row["weights"]
	var champion_wr: float = champion_row["winrate"]
	print("[2stage] CAMPEÓN: %s (WR %.3f, %d derrotas significativas)" % [
		champion_row["name"], champion_wr, int(champion_row["significant_losses"])])

	# ---- Guardado -------------------------------------------------------
	assert_not_null(champion, "Debe haber un campeón")
	var tres_path := "user://heuristic_weights_2stage.tres"
	var err := ResourceSaver.save(champion, tres_path)
	assert_eq(err, OK, "Debe guardar %s" % tres_path)
	print("[2stage] campeón (WR %.3f) guardado en: %s" % [
		champion_wr, ProjectSettings.globalize_path(tres_path)])

	var payload := {
		"keys": Array(HeuristicWeightsSpec.OPTIMIZABLE_KEYS),
		"search_seed": SEARCH_SEED,
		"validate_seed": VALIDATE_SEED,
		"stage1_games": fit1.n_games,
		"stage2_games": fit2.n_games,
		"finalists": _report_serializable(report),
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
	for k in HeuristicWeightsSpec.OPTIMIZABLE_KEYS:
		out[k] = w.get(k)
	return out


func _int_env(name: String, fallback: int) -> int:
	var v := OS.get_environment(name)
	return int(v) if v != "" else fallback


## Copia del informe SIN el objeto de pesos: `JSON.stringify` no sabe serializar
## un Resource y lo dejaría como basura silenciosa en el fichero.
func _report_serializable(report: Array) -> Array:
	var out: Array = []
	for row in report:
		var copia := {}
		for k in row:
			if k != "weights":
				copia[k] = row[k]
		out.append(copia)
	return out


## Cuántos rivales le ganan de forma SIGNIFICATIVA (no por ruido): el extremo
## superior del IC95 de ese enfrentamiento no llega al 50 %.
##
## La barrera tiene que ser estadística y no literal. Un candidato cuyo win-rate
## REAL contra un rival es exactamente 0.50 se observa por debajo de 0.50 la mitad
## de las veces, y eso no mejora con más partidas — es la definición de estar en la
## media. Una barrera literal ("≥50 % contra todos") rechazaría a casi todos: con k
## rivales parejos, la probabilidad de que al menos uno caiga por debajo es
## 1 − 0.5^k, que con 12 rivales es del 99.98 %.
func _derrotas_significativas(per_opponent: Array) -> int:
	var n := 0
	for o in per_opponent:
		if float(o.get("ci95_hi", 1.0)) < 0.5:
			n += 1
	return n


## Campeón: el de mayor win-rate medio ENTRE LOS QUE no pierden significativamente
## contra ningún rival.
##
## Si nadie pasa la barrera, no se aborta: se elige por menor número de derrotas
## significativas y, a igualdad, por media. Que la barrera quede desierta también
## es un resultado, y queda registrado en el JSON para poder contarlo.
func _elegir_campeon(report: Array) -> Dictionary:
	var limpios: Array = []
	for row in report:
		if int(row["significant_losses"]) == 0:
			limpios.append(row)

	var candidatos: Array = limpios
	if limpios.is_empty():
		print("[2stage] AVISO: ningún finalista pasa la barrera del 50 %. " +
			"Se elige por menos derrotas significativas y, a igualdad, por media.")
		var minimo := 9999
		for row in report:
			minimo = mini(minimo, int(row["significant_losses"]))
		for row in report:
			if int(row["significant_losses"]) == minimo:
				candidatos.append(row)

	var mejor: Dictionary = candidatos[0]
	for row in candidatos:
		if float(row["winrate"]) > float(mejor["winrate"]):
			mejor = row
	return mejor
