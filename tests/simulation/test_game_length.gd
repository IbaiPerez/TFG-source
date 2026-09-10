extends GutTest

## ¿CUÁNTO DURAN, EN TURNOS, las partidas de la optimización?
##
## La corrida real no lo registró: se lanzó con SIM_LOG_LEVEL=2 —que silencia las
## líneas de turno— y HeuristicFitness tiraba el `avg_rounds` que el comparador sí
## calculaba. Ahora lo acumula, y esto lo lee.
##
## Las partidas que mide son LAS MISMAS de la etapa 2, no unas parecidas: el
## comparador siembra cada partida con `rng(seed_maestro).randi()` en el índice i,
## así que la partida i depende del maestro y del índice, NO de cuántas se pidan.
## Correr con GL_GAMES=2 replica exactamente las dos primeras partidas de cada
## enfrentamiento de la corrida real. Las constantes de abajo deben seguir siendo
## las de test_optimize_heuristic_2stage: si divergen, ya no son las mismas.
##
## Lanzar:
##   $env:RUN_GAME_LENGTH='1'; & godot --headless -s addons/gut/gut_cmdln.gd `
##     "-gconfig=" -gtest=res://tests/simulation/test_game_length.gd -gexit
## Diales: GL_GAMES (partidas por rol y rival, default 2).


const ENABLE_FROM_GUI := false
const CHAMPION_PATH := "res://resources/ai/heuristic_weights_optimized.tres"
const SELECT_OPP_SEED := 80085     ## == test_optimize_heuristic_2stage
const STAGE2_RIVALS := 12          ## == test_optimize_heuristic_2stage
const VALIDATE_SEED := 20261231    ## == test_optimize_heuristic_2stage
const MAX_ROUNDS := 300            ## == STAGE_MAX_ROUNDS
const GL_GAMES := 2


func test_duracion_de_las_partidas() -> void:
	if not (ENABLE_FROM_GUI or OS.get_environment("RUN_GAME_LENGTH") != ""):
		pass_test("Saltado: RUN_GAME_LENGTH=1 para ejecutar.")
		return

	var champ := load(CHAMPION_PATH) as HeuristicWeights
	assert_not_null(champ, "el campeón desplegado debe cargar")

	var fit := HeuristicFitness.new(self)
	fit.n_games = _int_env("GL_GAMES", GL_GAMES)
	fit.seed_master = VALIDATE_SEED
	fit.mirror = true
	fit.max_rounds = MAX_ROUNDS
	fit.opponents = HeuristicOpponents.selection_pool(SELECT_OPP_SEED, STAGE2_RIVALS)

	print("[len] campeón contra %d rivales · %d partidas por rol · tope %d rondas" % [
		fit.opponents.size(), fit.n_games, MAX_ROUNDS])
	var d := await fit.evaluate_detailed(champ)

	_resumen(fit.rounds)
	_por_rival(d["per_opponent"])
	_guardar(fit.rounds)

	WorldMap.map = []
	WorldMap.map_as_dict = {}
	BattleFront.clear_active_instances()
	for e in get_errors():
		e.handled = true
	assert_gt(fit.rounds.size(), 0, "debe haber medido alguna partida")


## El porcentaje que toca el tope es lo que decide si el tope está sesgando el
## win-rate: una partida cortada por límite no la gana nadie y sale del
## denominador de decisivas.
func _resumen(rondas: Array) -> void:
	if rondas.is_empty():
		return
	var xs := rondas.duplicate()
	xs.sort()
	var n := xs.size()
	var tope := 0
	for x in xs:
		if int(x) >= MAX_ROUNDS - 1:
			tope += 1
	print("\n[len] ================ DURACIÓN ================")
	print("[len] partidas      %d" % n)
	print("[len] media         %.1f turnos" % _media(xs))
	print("[len] p10 / p50     %d / %d" % [_pct(xs, 0.10), _pct(xs, 0.50)])
	print("[len] p90 / máximo  %d / %d" % [_pct(xs, 0.90), int(xs[n - 1])])
	print("[len] en el tope    %d (%.1f %%)" % [tope, 100.0 * float(tope) / float(n)])


func _por_rival(per: Array) -> void:
	print("\n[len] ============ POR RIVAL ============")
	print("[len] %-4s %10s %10s" % ["#", "turnos", "win-rate"])
	for i in range(per.size()):
		print("[len] %-4d %10.1f %10.3f" % [
			i, float(per[i].get("avg_rounds", 0.0)), float(per[i]["winrate"])])


func _guardar(rondas: Array) -> void:
	var f := FileAccess.open("user://game_length.json", FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"max_rounds": MAX_ROUNDS,
		"validate_seed": VALIDATE_SEED,
		"rondas": rondas,
		"timestamp": Time.get_datetime_string_from_system(true),
	}, "  "))
	f.close()
	print("\n[len] crudo en: %s" % ProjectSettings.globalize_path("user://game_length.json"))


func _media(xs: Array) -> float:
	var t := 0.0
	for x in xs:
		t += float(x)
	return t / float(maxi(xs.size(), 1))


## Percentil sobre una lista YA ordenada.
func _pct(xs: Array, p: float) -> int:
	return int(xs[clampi(int(p * float(xs.size())), 0, xs.size() - 1)])


func _int_env(name: String, fallback: int) -> int:
	var v := OS.get_environment(name)
	return int(v) if v != "" else fallback
