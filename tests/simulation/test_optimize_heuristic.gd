extends GutTest

## Lanzador de la optimización de pesos de la heurística (Simulated Annealing y
## algoritmo genético). Sigue el patrón de test_sim_hyperparam_sweep.gd: es un
## GutTest gated por variable de entorno para NO dispararse en una corrida
## normal de la suite (el fitness son partidas completas y tarda).
##
## Cómo lanzar (PowerShell):
##   $env:RUN_OPT_SA=1; & '..\Godot_v4.5-stable_win64.exe\Godot_v4.5-stable_win64_console.exe' `
##     --headless -s addons/gut/gut_cmdln.gd "-gconfig=" `
##     -gtest=res://tests/simulation/test_optimize_heuristic.gd -gexit
##   (usa RUN_OPT_GA=1 para el genético; puedes activar ambos a la vez)
##
## Smoke rápido (pocas partidas/iteraciones):
##   $env:RUN_OPT_SA=1; $env:OPT_SMOKE=1; & godot --headless -s addons/gut/gut_cmdln.gd ...
##
## Salidas en user:// (Windows: %APPDATA%\Godot\app_userdata\Source\):
##   heuristic_weights_sa.tres / heuristic_weights_ga.tres   → mejor candidato
##   opt_sa.json / opt_ga.json                               → traza + validación


# true → se ejecuta también desde el panel GUT del editor. OJO: con true, una
# corrida de la suite COMPLETA que incluya tests/simulation/ también dispararía
# esta optimización larga; ejecútala SOLO seleccionando este script (o un test
# concreto: test_optimize_sa / test_optimize_ga) en el panel GUT, no "Run All".
const ENABLE_FROM_GUI := true

# --- Parámetros por defecto (ajustables por env var) ------------------------
const SEARCH_GAMES := 16          ## partidas por evaluación durante la búsqueda
const VALIDATE_GAMES := 60        ## partidas de revalidación del campeón
const SEARCH_SEED := 20260706
const VALIDATE_SEED := 20261231   ## DISJUNTO del de búsqueda (evita overfit)

const SA_ITERATIONS := 120
const GA_POP := 12
const GA_GENS := 12

# Smoke: valores mínimos para comprobar que el bucle corre y escribe salidas.
const SMOKE_GAMES := 2
const SMOKE_SA_ITERS := 3
const SMOKE_GA_POP := 4
const SMOKE_GA_GENS := 2


func test_optimize_sa() -> void:
	if not _enabled("RUN_OPT_SA"):
		pass_test("Saltado: pon RUN_OPT_SA=1 (o ENABLE_FROM_GUI=true) para ejecutar.")
		return
	var smoke := _is_smoke()
	var fit := _search_fitness(smoke)
	var sa := SAOptimizer.new(fit, 4242)
	sa.iterations = SMOKE_SA_ITERS if smoke else _int_env("SA_ITERATIONS", SA_ITERATIONS)
	print("[Opt-SA] === búsqueda: %d iters · %d partidas/eval · mirror ===" % [
		sa.iterations, fit.n_games])

	var champ: HeuristicWeights = await sa.run()
	await _finish("sa", champ, sa.trace, smoke)


func test_optimize_ga() -> void:
	if not _enabled("RUN_OPT_GA"):
		pass_test("Saltado: pon RUN_OPT_GA=1 (o ENABLE_FROM_GUI=true) para ejecutar.")
		return
	var smoke := _is_smoke()
	var fit := _search_fitness(smoke)
	var ga := GAOptimizer.new(fit, 999)
	ga.pop_size = SMOKE_GA_POP if smoke else _int_env("GA_POP", GA_POP)
	ga.generations = SMOKE_GA_GENS if smoke else _int_env("GA_GENS", GA_GENS)
	print("[Opt-GA] === búsqueda: pop %d × %d gen · %d partidas/eval · mirror ===" % [
		ga.pop_size, ga.generations, fit.n_games])

	var champ: HeuristicWeights = await ga.run()
	await _finish("ga", champ, ga.trace, smoke)


# --- Helpers -----------------------------------------------------------------

func _search_fitness(smoke: bool) -> HeuristicFitness:
	var fit := HeuristicFitness.new(self)
	fit.n_games = SMOKE_GAMES if smoke else _int_env("SEARCH_GAMES", SEARCH_GAMES)
	fit.seed_master = SEARCH_SEED
	fit.mirror = true
	return fit


## Revalida el campeón en un set de semillas DISJUNTO, guarda el .tres y la
## traza JSON, y deja constancia por stdout.
func _finish(tag: String, champ: HeuristicWeights, trace: Array, smoke: bool) -> void:
	assert_not_null(champ, "El optimizador %s debe devolver un candidato" % tag)

	var val_fit := HeuristicFitness.new(self)
	val_fit.n_games = SMOKE_GAMES if smoke else _int_env("VALIDATE_GAMES", VALIDATE_GAMES)
	val_fit.seed_master = VALIDATE_SEED
	val_fit.mirror = true
	var val_wr: float = await val_fit.evaluate(champ)
	print("[Opt-%s] win-rate validación (seeds disjuntos, %d part.): %.3f" % [
		tag, val_fit.n_games, val_wr])

	var tres_path := "user://heuristic_weights_%s.tres" % tag
	var err := ResourceSaver.save(champ, tres_path)
	assert_eq(err, OK, "Debe guardar %s" % tres_path)
	print("[Opt-%s] pesos guardados en: %s" % [tag, ProjectSettings.globalize_path(tres_path)])

	var payload := {
		"tag": tag,
		"keys": Array(HeuristicWeights.OPTIMIZABLE_KEYS),
		"champion_weights": _weights_dict(champ),
		"validation_winrate": val_wr,
		"validation_games": val_fit.n_games,
		"validation_seed": VALIDATE_SEED,
		"search_seed": SEARCH_SEED,
		"trace": trace,
		"timestamp": Time.get_datetime_string_from_system(true),
	}
	var json_path := "user://opt_%s.json" % tag
	var f := FileAccess.open(json_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(payload, "  "))
		f.close()
		print("[Opt-%s] traza JSON en: %s" % [tag, ProjectSettings.globalize_path(json_path)])

	# Limpieza global final.
	WorldMap.map = []
	WorldMap.map_as_dict = {}
	BattleFront.clear_active_instances()
	for e in get_errors():
		e.handled = true


## Serializa solo las claves optimizadas del candidato (para el JSON).
func _weights_dict(w: HeuristicWeights) -> Dictionary:
	var out := {}
	for k in HeuristicWeights.OPTIMIZABLE_KEYS:
		out[k] = w.get(k)
	return out


func _enabled(env_name: String) -> bool:
	return ENABLE_FROM_GUI or OS.get_environment(env_name) != ""


func _is_smoke() -> bool:
	return OS.get_environment("OPT_SMOKE") != ""


func _int_env(name: String, fallback: int) -> int:
	var v := OS.get_environment(name)
	return int(v) if v != "" else fallback
