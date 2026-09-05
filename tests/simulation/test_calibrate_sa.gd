extends GutTest

## CALIBRACIÓN de los hiperparámetros de SA, midiendo en vez de adivinar.
##
## `dims_per_step`, `t0` y `step_frac` se venían eligiendo a ojo. Lo que gobierna
## el comportamiento es qué le pasa a cada VECINO propuesto, y eso no se medía.
## Este banco corre una rejilla de configuraciones y reporta las cuatro cosas
## distintas que le pueden pasar a un vecino:
##
##   mejora          la búsqueda avanza
##   neutro/meseta   la perturbación no volteó NINGUNA decisión, así que el
##                   win-rate salió idéntico. Se acepta (delta >= 0) y la cadena
##                   se pasea sin aprender.
##   peor aceptado   Metropolis dejando pasar un empeoramiento
##   rechazado       la cadena se congela
##
## La rejilla cruza TRES factores, y el tercero está para deshacer un confundido:
## comparar dims=3/paso=0.150 con dims=12/paso=0.075 iguala la longitud del salto
## (crece con sqrt(d)) pero NO iguala el desplazamiento por eje. Si lo que gobierna
## el destrozo es el tamaño por coordenada y no la norma, esa comparación mide el
## paso disfrazado de dimensiones. E y F cierran el cuadrado (dims × paso) para
## poder atribuir el efecto a uno o a otro.
##
## POOL REDUCIDO a propósito: con los 19 rivales de la etapa 1 una evaluación
## cuesta ~10 min (medido: ~8 s/partida). Con pool reducido la granularidad del
## fitness es más GRUESA, así que la fracción de meseta que se mide aquí es una
## COTA SUPERIOR de la real — con más partidas hay más ocasiones de voltear algo.
## Sirve para comparar configuraciones entre sí, que es para lo que está.
##
## El `best_fitness` que reporta es fitness SOBRE EL POOL DE BÚSQUEDA. Mide con qué
## rapidez trepa cada configuración, NO la calidad del campeón: con 24 partidas por
## evaluación, trepar más rápido también puede ser sobreajustar más rápido.
##
## Lanzar:
##   $env:RUN_CALIBRATE_SA='1'; & godot --headless -s addons/gut/gut_cmdln.gd `
##     "-gconfig=" -gtest=res://tests/simulation/test_calibrate_sa.gd -gexit
## Diales: CAL_RIVALS, CAL_ITERS, CAL_GAMES, CAL_ONLY (letras, p.ej. "EF").
## Salida: user://calibrate_sa.json


const ENABLE_FROM_GUI := false
const CAL_RIVALS := 5             ## aleatorios frescos (+3 arquetipos)
const CAL_ITERS := 20             ## vecinos por configuración
const CAL_GAMES := 2              ## partidas por rol y rival
const CAL_MAX_ROUNDS := 300
const SEARCH_SEED := 20260706
const OPP_SEED := 31337
const SA_SEED := 4242             ## el mismo para todas: comparan proponiendo igual

## dims × paso × temperatura. `paso` es la sigma como fracción del rango, POR EJE.
const CONFIGS := [
	{"id": "A", "nombre": "A · actual",      "dims": 3,  "paso": 0.150, "t0": 0.15},
	{"id": "B", "nombre": "B · dims comp.",  "dims": 12, "paso": 0.075, "t0": 0.15},
	{"id": "C", "nombre": "C · frío",        "dims": 3,  "paso": 0.150, "t0": 0.03},
	{"id": "D", "nombre": "D · dims + frío", "dims": 12, "paso": 0.075, "t0": 0.03},
	{"id": "E", "nombre": "E · paso corto",  "dims": 3,  "paso": 0.075, "t0": 0.15},
	{"id": "F", "nombre": "F · dims largo",  "dims": 12, "paso": 0.150, "t0": 0.15},
]


func test_calibrar_sa() -> void:
	if not (ENABLE_FROM_GUI or OS.get_environment("RUN_CALIBRATE_SA") != ""):
		pass_test("Saltado: RUN_CALIBRATE_SA=1 para ejecutar.")
		return

	var iters := _int_env("CAL_ITERS", CAL_ITERS)
	var fit := _build_fitness()
	var partidas_por_eval: int = fit.opponents.size() * fit.n_games * 2
	print("[cal] pool de %d rivales · %d partidas por evaluación · %d iters por config" % [
		fit.opponents.size(), partidas_por_eval, iters])
	print("[cal] granularidad del fitness: 1/%d = %.4f" % [
		partidas_por_eval, 1.0 / float(partidas_por_eval)])

	var informe: Array = []
	for cfg in _configs_pedidas():
		informe.append(await _correr(fit, cfg, iters))

	_resumen(informe, fit)
	_guardar(informe, fit, partidas_por_eval, iters)

	WorldMap.map = []
	WorldMap.map_as_dict = {}
	BattleFront.clear_active_instances()
	for e in get_errors():
		e.handled = true
	assert_true(true)


## Un solo fitness para todas las configuraciones: la memoización es por
## (semilla, partidas, vector), así que el punto de partida —común a todas— se
## evalúa una vez sola.
func _build_fitness() -> HeuristicFitness:
	var fit := HeuristicFitness.new(self)
	fit.n_games = _int_env("CAL_GAMES", CAL_GAMES)
	fit.seed_master = SEARCH_SEED
	fit.mirror = true
	fit.max_rounds = CAL_MAX_ROUNDS
	fit.opponents = HeuristicOpponents.search_pool(
		OPP_SEED, _int_env("CAL_RIVALS", CAL_RIVALS))
	return fit


## CAL_ONLY filtra por letra ("EF") para poder añadir configuraciones a una
## rejilla ya medida sin repetir las que ya costaron su hora de cómputo.
func _configs_pedidas() -> Array:
	var only := OS.get_environment("CAL_ONLY").to_upper()
	if only == "":
		return CONFIGS
	return CONFIGS.filter(func(c): return only.contains(c["id"]))


func _correr(fit: HeuristicFitness, cfg: Dictionary, iters: int) -> Dictionary:
	print("\n[cal] ===== %s (dims/paso=%d, paso=%.3f, t0=%.3f) =====" % [
		cfg["nombre"], cfg["dims"], cfg["paso"], cfg["t0"]])
	var sa := SAOptimizer.new(fit, SA_SEED)
	sa.iterations = iters
	sa.dims_per_step = cfg["dims"]
	sa.step_frac = cfg["paso"]
	sa.t0 = cfg["t0"]
	await sa.run()
	var d := sa.diagnostico()
	d["nombre"] = cfg["nombre"]
	d["id"] = cfg["id"]
	return d


func _resumen(informe: Array, fit: HeuristicFitness) -> void:
	print("\n[cal] ===================== RESUMEN =====================")
	print("[cal] %-16s %6s %7s %7s %8s %8s %8s %8s" % [
		"config", "dims", "paso", "t0", "mejora", "meseta", "peorAcc", "rechaz"])
	for d in informe:
		print("[cal] %-16s %6d %7.3f %7.3f %7.1f%% %7.1f%% %7.1f%% %7.1f%%" % [
			d["nombre"], d["dims_per_step"], d["step_frac"], d["t0"], d["pct_mejora"],
			d["pct_neutro"], d["pct_peor_aceptado"], d["pct_rechazado"]])
	print("[cal] %-16s %s" % ["mejor fitness", " · ".join(
		informe.map(func(d): return "%s %.3f" % [d["id"], d["best_fitness"]]))])
	print("[cal] partidas jugadas: %d · aciertos de caché: %d" % [fit.evals, fit.cache_hits])


func _guardar(informe: Array, fit: HeuristicFitness, por_eval: int, iters: int) -> void:
	var f := FileAccess.open("user://calibrate_sa.json", FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"rivales": fit.opponents.size(),
		"partidas_por_evaluacion": por_eval,
		"iteraciones_por_config": iters,
		"configs": informe,
		"partidas_totales": fit.evals,
		"timestamp": Time.get_datetime_string_from_system(true),
	}, "  "))
	f.close()
	print("[cal] informe en: %s" % ProjectSettings.globalize_path("user://calibrate_sa.json"))


func _int_env(name: String, fallback: int) -> int:
	var v := OS.get_environment(name)
	return int(v) if v != "" else fallback
