extends GutTest

## CALIBRACIÓN de los hiperparámetros de SA, midiendo en vez de adivinar.
##
## `dims_per_step`, `t0` y `step_frac` se venían eligiendo a ojo. El parámetro que
## de verdad gobierna el comportamiento es la TASA DE ACEPTACIÓN, y no se medía.
## Este banco corre un factorial 2×2 sobre las dos decisiones que importan y
## reporta las cuatro cosas distintas que le pueden pasar a un vecino:
##
##   mejora          la búsqueda avanza
##   neutro/meseta   la perturbación no volteó NINGUNA decisión, así que el
##                   win-rate salió idéntico. Se acepta (delta >= 0) y la cadena
##                   se pasea sin aprender.
##   peor aceptado   Metropolis dejando pasar un empeoramiento
##   rechazado       la cadena se congela
##
## Cómo leerlo:
##   mucho NEUTRO      -> perturbar más dimensiones, o más partidas por evaluación
##   mucho PEOR ACEPT. -> t0 alto para la granularidad real del fitness
##   mucho RECHAZADO   -> enfriamiento demasiado rápido
##
## POOL REDUCIDO a propósito: con los 19 rivales de la etapa 1 una evaluación
## cuesta ~10 min (medido: ~8 s/partida). Con pool reducido la granularidad del
## fitness es más GRUESA, así que la fracción de meseta que se mide aquí es una
## COTA SUPERIOR de la real — con más partidas hay más ocasiones de voltear algo.
## Sirve para comparar configuraciones entre sí, que es para lo que está.
##
## Lanzar:
##   $env:RUN_CALIBRATE_SA='1'; & godot --headless -s addons/gut/gut_cmdln.gd `
##     "-gconfig=" -gtest=res://tests/simulation/test_calibrate_sa.gd -gexit
## Diales: CAL_RIVALS, CAL_ITERS, CAL_GAMES.  Salida: user://calibrate_sa.json


const ENABLE_FROM_GUI := false
const CAL_RIVALS := 5             ## aleatorios frescos (+3 arquetipos)
const CAL_ITERS := 20             ## vecinos por configuración
const CAL_GAMES := 2              ## partidas por rol y rival
const CAL_MAX_ROUNDS := 300
const SEARCH_SEED := 20260706
const OPP_SEED := 31337


func test_calibrar_sa() -> void:
	if not (ENABLE_FROM_GUI or OS.get_environment("RUN_CALIBRATE_SA") != ""):
		pass_test("Saltado: RUN_CALIBRATE_SA=1 para ejecutar.")
		return

	var rivales := _int_env("CAL_RIVALS", CAL_RIVALS)
	var iters := _int_env("CAL_ITERS", CAL_ITERS)

	# Un solo fitness para las cuatro configuraciones: la memoización es por
	# (semilla, partidas, vector), así que el punto de partida —común a todas— se
	# evalúa una vez sola.
	var fit := HeuristicFitness.new(self)
	fit.n_games = _int_env("CAL_GAMES", CAL_GAMES)
	fit.seed_master = SEARCH_SEED
	fit.mirror = true
	fit.max_rounds = CAL_MAX_ROUNDS
	fit.opponents = HeuristicOpponents.search_pool(OPP_SEED, rivales)

	var partidas_por_eval: int = fit.opponents.size() * fit.n_games * 2
	print("[cal] pool de %d rivales · %d partidas por evaluación · %d iters por config" % [
		fit.opponents.size(), partidas_por_eval, iters])
	print("[cal] granularidad del fitness: 1/%d = %.4f" % [
		partidas_por_eval, 1.0 / float(partidas_por_eval)])

	# Factorial 2x2 sobre las dos decisiones que importan.
	var configs := [
		{"nombre": "A · actual",        "dims": 3,  "t0": 0.15},
		{"nombre": "B · más dims",      "dims": 12, "t0": 0.15},
		{"nombre": "C · más frío",      "dims": 3,  "t0": 0.03},
		{"nombre": "D · dims + frío",   "dims": 12, "t0": 0.03},
	]

	var informe: Array = []
	for cfg in configs:
		print("\n[cal] ===== %s (dims/paso=%d, t0=%.3f) =====" % [
			cfg["nombre"], cfg["dims"], cfg["t0"]])
		var sa := SAOptimizer.new(fit, 4242)
		sa.iterations = iters
		sa.dims_per_step = cfg["dims"]
		sa.t0 = cfg["t0"]
		# Con más dimensiones el salto crece como sqrt(d), así que se compensa el
		# paso para comparar configuraciones a IGUAL longitud de salto: si no, se
		# estaría midiendo "saltos más largos", no "más dimensiones".
		sa.step_frac = 0.15 * sqrt(3.0 / float(cfg["dims"]))
		await sa.run()
		var d := sa.diagnostico()
		d["nombre"] = cfg["nombre"]
		informe.append(d)

	print("\n[cal] ===================== RESUMEN =====================")
	print("[cal] %-16s %6s %8s %8s %8s %8s %8s" % [
		"config", "dims", "t0", "mejora", "meseta", "peorAcc", "rechaz"])
	for d in informe:
		print("[cal] %-16s %6d %8.3f %7.1f%% %7.1f%% %7.1f%% %7.1f%%" % [
			d["nombre"], d["dims_per_step"], d["t0"], d["pct_mejora"],
			d["pct_neutro"], d["pct_peor_aceptado"], d["pct_rechazado"]])
	print("[cal] %-16s %s" % ["mejor fitness", " · ".join(
		informe.map(func(d): return "%s %.3f" % [d["nombre"].split(" ")[0], d["best_fitness"]]))])
	print("[cal] partidas jugadas: %d · aciertos de caché: %d" % [fit.evals, fit.cache_hits])

	var f := FileAccess.open("user://calibrate_sa.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({
			"rivales": fit.opponents.size(),
			"partidas_por_evaluacion": partidas_por_eval,
			"iteraciones_por_config": iters,
			"configs": informe,
			"partidas_totales": fit.evals,
			"timestamp": Time.get_datetime_string_from_system(true),
		}, "  "))
		f.close()
		print("[cal] informe en: %s" % ProjectSettings.globalize_path("user://calibrate_sa.json"))

	WorldMap.map = []
	WorldMap.map_as_dict = {}
	BattleFront.clear_active_instances()
	for e in get_errors():
		e.handled = true
	assert_true(true)


func _int_env(name: String, fallback: int) -> int:
	var v := OS.get_environment(name)
	return int(v) if v != "" else fallback
