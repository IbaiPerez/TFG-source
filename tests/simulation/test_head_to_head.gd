extends GutTest

## Mide un juego de pesos de la heurística (A) fuera del optimizador, en espejo (A
## juega como AI_A y como AI_B). Dos modos:
##
##   · Cara a cara (por defecto): A contra otro juego de pesos B, con semillas
##     disjuntas de las de la búsqueda y la revalidación del optimizador. Sirve para
##     decidir un despliegue: ganar al pool no garantiza ganar al campeón que ya usa
##     el juego.
##   · Pool de la etapa 2 (H2H_POOL=1): A contra los MISMOS rivales, semillas y
##     partidas con que el optimizador revalida a sus finalistas, leídos de su propio
##     lanzador. Así la cifra es directamente comparable con las de opt_2stage.json.
##
## Lanzar (bash; el "-gconfig=" vacío es imprescindible, ver tests/README):
##   RUN_HEAD_TO_HEAD=1 SIM_LOG_LEVEL=2 godot --headless -s addons/gut/gut_cmdln.gd \
##     "-gconfig=" -gtest=res://tests/simulation/test_head_to_head.gd -gexit
## Parámetros: H2H_A y H2H_B (rutas .tres; por defecto el campeón recién optimizado
## en user:// contra el desplegado), H2H_GAMES (partidas por rol en el cara a cara),
## H2H_POOL=1 (modo pool).
##
## Salida: user://head_to_head.json


const ENABLE_FROM_GUI := false
const OPT := preload("res://tests/simulation/test_optimize_heuristic_2stage.gd")
const DEFAULT_A := "user://heuristic_weights_2stage.tres"
const DEFAULT_B := "res://resources/ai/heuristic_weights_optimized.tres"
const GAMES := 250
const GAME_SEED := 20270115   ## el held-out de test_validate_champion: disjunto de búsqueda y revalidación
const MAX_ROUNDS := 300


func test_head_to_head() -> void:
	if not (ENABLE_FROM_GUI or OS.get_environment("RUN_HEAD_TO_HEAD") != ""):
		pass_test("Saltado: RUN_HEAD_TO_HEAD=1 para ejecutar.")
		return
	var path_a := _env("H2H_A", DEFAULT_A)
	var a := load(path_a) as HeuristicWeights
	assert_not_null(a, "no carga A: %s" % path_a)
	if a == null:
		return
	var pool_mode := OS.get_environment("H2H_POOL") != ""
	var fit := _pool_fitness() if pool_mode else _duel_fitness()
	if fit == null:
		return
	var rival := "pool de la etapa 2 (%d rivales)" % fit.opponents.size() if pool_mode \
		else _env("H2H_B", DEFAULT_B)
	print("[h2h] A = %s\n[h2h] contra: %s\n[h2h] %d partidas por rival y rol, en espejo" % [
		path_a, rival, fit.n_games])

	var d := await fit.evaluate_detailed(a)
	print("[h2h] A gana %d de %d decisivas: WR %.3f  IC95[%.3f, %.3f]" % [
		int(d["wins"]), int(d["decisive"]), d["winrate"], d["ci95_lo"], d["ci95_hi"]])
	_save(path_a, rival, fit, d)
	assert_gt(int(d["decisive"]), 0, "sin partidas decisivas no hay veredicto")
	_cleanup()


## A contra B con las semillas del held-out.
func _duel_fitness() -> HeuristicFitness:
	var path_b := _env("H2H_B", DEFAULT_B)
	var b := load(path_b) as HeuristicWeights
	assert_not_null(b, "no carga B: %s" % path_b)
	if b == null:
		return null
	var fit := HeuristicFitness.new(self)
	fit.n_games = SimEnv.int_env("H2H_GAMES", GAMES)
	fit.seed_master = GAME_SEED
	fit.mirror = true
	fit.max_rounds = MAX_ROUNDS
	fit.opponents = [HeuristicOpponents.heur_config(b)]
	return fit


## La misma evaluación que la etapa 2 del optimizador (ver su `_build_fit2`).
func _pool_fitness() -> HeuristicFitness:
	var fit := HeuristicFitness.new(self)
	fit.n_games = OPT.STAGE2_GAMES
	fit.seed_master = OPT.VALIDATE_SEED
	fit.mirror = true
	fit.max_rounds = OPT.STAGE_MAX_ROUNDS
	fit.opponents = HeuristicOpponents.selection_pool(OPT.SELECT_OPP_SEED, OPT.STAGE2_RIVALS)
	return fit


func _save(path_a: String, rival: String, fit: HeuristicFitness, d: Dictionary) -> void:
	var out := FileAccess.open("user://head_to_head.json", FileAccess.WRITE)
	out.store_string(JSON.stringify({
		"a": path_a, "rival": rival, "games_per_role": fit.n_games, "seed": fit.seed_master,
		"wins": d["wins"], "decisive": d["decisive"], "winrate": d["winrate"],
		"ci95_lo": d["ci95_lo"], "ci95_hi": d["ci95_hi"], "rounds": fit.rounds,
		"timestamp": Time.get_datetime_string_from_system(true)}, "\t"))
	out.close()


## Igual que el lanzador del optimizador: dejar el mundo limpio y no contar como
## fallo los errores del motor que emiten las partidas (colisiones de física).
func _cleanup() -> void:
	WorldMap.map = []
	WorldMap.map_as_dict = {}
	BattleFront.clear_active_instances()
	for e in get_errors():
		e.handled = true


func _env(name: String, fallback: String) -> String:
	var v := OS.get_environment(name)
	return v if v != "" else fallback
