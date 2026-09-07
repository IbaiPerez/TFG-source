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
## paso disfrazado de dimensiones. E y F cierran el cuadrado (dims × paso).
##
## RÉPLICAS: una sola cadena de 25 vecinos no distingue un efecto de una secuencia
## de propuestas afortunada. Cada réplica redibuja LAS DOS fuentes de azar —la
## semilla del SA (qué ejes se tocan, las monedas de Metropolis) y la de partidas
## (qué realización del fitness se mide)— para que sean sorteos independientes.
## No permite atribuir la variación a una fuente u otra; permite saber si la
## conclusión aguanta, que es la pregunta.
##
## POOL REDUCIDO a propósito: con los 19 rivales de la etapa 1 una evaluación
## cuesta ~10 min (medido: ~8 s/partida). Con pool reducido la granularidad del
## fitness es más GRUESA, así que la fracción de meseta que se mide aquí es una
## COTA SUPERIOR de la real — con más partidas hay más ocasiones de voltear algo.
##
## El `best_fitness` que reporta es fitness SOBRE EL POOL DE BÚSQUEDA. Mide con qué
## rapidez trepa cada configuración, NO la calidad del campeón: con 24 partidas por
## evaluación, trepar más rápido también puede ser sobreajustar más rápido.
##
## RESOLUCIÓN INSUFICIENTE, medido: con cadenas de 25 vecinos la varianza ENTRE
## cadenas de una misma configuración (A dio 76%, 32% y 32% de rechazo en tres
## réplicas) es mayor que las diferencias entre configuraciones que se querían
## detectar. Separar 20 puntos pediría ~16 cadenas por configuración, unos nueve
## días de cómputo. Los diales se quedan como estaban. Lo único que sí salió
## limpio es negativo: la meseta nunca pasó del 16% en diez cadenas, así que no
## es lo que ata la búsqueda.
##
## Lanzar:
##   $env:RUN_CALIBRATE_SA='1'; & godot --headless -s addons/gut/gut_cmdln.gd `
##     "-gconfig=" -gtest=res://tests/simulation/test_calibrate_sa.gd -gexit
## Diales: CAL_RIVALS, CAL_ITERS, CAL_GAMES, CAL_ONLY (letras, p.ej. "AB"),
## CAL_REP_FROM / CAL_REP_TO (índices de réplica, ambos inclusive).
## Salida: user://calibrate_sa.json


const ENABLE_FROM_GUI := false
const CAL_RIVALS := 5             ## aleatorios frescos (+3 arquetipos)
const CAL_ITERS := 20             ## vecinos por configuración
const CAL_GAMES := 2              ## partidas por rol y rival
const CAL_MAX_ROUNDS := 300
const OPP_SEED := 31337           ## el pool es el MISMO en todas las réplicas

## dims × paso × temperatura. `paso` es la sigma como fracción del rango, POR EJE.
const CONFIGS := [
	{"id": "A", "nombre": "A · actual",      "dims": 3,  "paso": 0.150, "t0": 0.15},
	{"id": "B", "nombre": "B · dims comp.",  "dims": 12, "paso": 0.075, "t0": 0.15},
	{"id": "C", "nombre": "C · frío",        "dims": 3,  "paso": 0.150, "t0": 0.03},
	{"id": "D", "nombre": "D · dims + frío", "dims": 12, "paso": 0.075, "t0": 0.03},
	{"id": "E", "nombre": "E · paso corto",  "dims": 3,  "paso": 0.075, "t0": 0.15},
	{"id": "F", "nombre": "F · dims largo",  "dims": 12, "paso": 0.150, "t0": 0.15},
]

## La réplica 0 es la ya medida; las demás redibujan ambas semillas.
const REPLICAS := [
	{"sa": 4242,  "juego": 20260706},
	{"sa": 91173, "juego": 20260707},
	{"sa": 55501, "juego": 20260708},
]


func test_calibrar_sa() -> void:
	if not (ENABLE_FROM_GUI or OS.get_environment("RUN_CALIBRATE_SA") != ""):
		pass_test("Saltado: RUN_CALIBRATE_SA=1 para ejecutar.")
		return

	var iters := _int_env("CAL_ITERS", CAL_ITERS)
	var configs := _configs_pedidas()
	var informe: Array = []
	var partidas := 0

	for r in _replicas_pedidas():
		var fit := _build_fitness(REPLICAS[r]["juego"])
		print("\n[cal] ########## RÉPLICA %d · sa=%d juego=%d ##########" % [
			r, REPLICAS[r]["sa"], REPLICAS[r]["juego"]])
		_cabecera(fit, iters)
		for cfg in configs:
			var d := await _correr(fit, cfg, iters, REPLICAS[r]["sa"])
			d["replica"] = r
			informe.append(d)
		partidas += fit.evals

	_resumen(informe, partidas)
	_agregado(informe)
	_guardar(informe, iters, partidas)

	WorldMap.map = []
	WorldMap.map_as_dict = {}
	BattleFront.clear_active_instances()
	for e in get_errors():
		e.handled = true
	assert_true(true)


## Un fitness por réplica: la memoización es por (semilla, partidas, vector), así
## que dentro de una réplica el punto de partida se evalúa una sola vez.
func _build_fitness(semilla_juego: int) -> HeuristicFitness:
	var fit := HeuristicFitness.new(self)
	fit.n_games = _int_env("CAL_GAMES", CAL_GAMES)
	fit.seed_master = semilla_juego
	fit.mirror = true
	fit.max_rounds = CAL_MAX_ROUNDS
	fit.opponents = HeuristicOpponents.search_pool(
		OPP_SEED, _int_env("CAL_RIVALS", CAL_RIVALS))
	return fit


func _cabecera(fit: HeuristicFitness, iters: int) -> void:
	var por_eval: int = fit.opponents.size() * fit.n_games * 2
	print("[cal] pool de %d rivales · %d partidas por evaluación · %d iters por config" % [
		fit.opponents.size(), por_eval, iters])
	print("[cal] granularidad del fitness: 1/%d = %.4f" % [por_eval, 1.0 / float(por_eval)])


## CAL_ONLY filtra por letra ("AB") para poder ampliar una rejilla ya medida sin
## repetir las configuraciones que ya costaron su hora de cómputo.
func _configs_pedidas() -> Array:
	var only := OS.get_environment("CAL_ONLY").to_upper()
	if only == "":
		return CONFIGS
	return CONFIGS.filter(func(c): return only.contains(c["id"]))


func _replicas_pedidas() -> Array:
	var desde := _int_env("CAL_REP_FROM", 0)
	var hasta := mini(_int_env("CAL_REP_TO", 0), REPLICAS.size() - 1)
	var out: Array = []
	for r in range(maxi(desde, 0), hasta + 1):
		out.append(r)
	return out


func _correr(fit: HeuristicFitness, cfg: Dictionary, iters: int, sa_seed: int) -> Dictionary:
	print("\n[cal] ===== %s (dims/paso=%d, paso=%.3f, t0=%.3f) =====" % [
		cfg["nombre"], cfg["dims"], cfg["paso"], cfg["t0"]])
	var sa := SAOptimizer.new(fit, sa_seed)
	sa.iterations = iters
	sa.dims_per_step = cfg["dims"]
	sa.step_frac = cfg["paso"]
	sa.t0 = cfg["t0"]
	await sa.run()
	var d := sa.diagnostico()
	d["nombre"] = cfg["nombre"]
	d["id"] = cfg["id"]
	return d


func _resumen(informe: Array, partidas: int) -> void:
	print("\n[cal] ================= POR CADENA =================")
	print("[cal] %-16s %4s %5s %6s %6s %8s %8s %8s %8s" % [
		"config", "rep", "dims", "paso", "t0", "mejora", "meseta", "peorAcc", "rechaz"])
	for d in informe:
		print("[cal] %-16s %4d %5d %6.3f %6.3f %7.1f%% %7.1f%% %7.1f%% %7.1f%%" % [
			d["nombre"], d["replica"], d["dims_per_step"], d["step_frac"], d["t0"],
			d["pct_mejora"], d["pct_neutro"], d["pct_peor_aceptado"], d["pct_rechazado"]])
	print("[cal] partidas jugadas: %d" % partidas)


## Lo que decide: media entre réplicas y RANGO, para ver si la separación entre
## configuraciones sobrevive al redibujado o se la come la variación entre cadenas.
func _agregado(informe: Array) -> void:
	print("\n[cal] ============ AGREGADO POR CONFIG =============")
	print("[cal] %-16s %4s %18s %18s" % ["config", "n", "rechaza (media)", "mejora (media)"])
	for cfg in _configs_pedidas():
		var filas := informe.filter(func(d): return d["id"] == cfg["id"])
		if filas.is_empty():
			continue
		var rech: Array = filas.map(func(d): return float(d["pct_rechazado"]))
		var mej: Array = filas.map(func(d): return float(d["pct_mejora"]))
		print("[cal] %-16s %4d  %5.1f%% [%.0f–%.0f]  %5.1f%% [%.0f–%.0f]" % [
			cfg["nombre"], filas.size(),
			_media(rech), rech.min(), rech.max(),
			_media(mej), mej.min(), mej.max()])


func _media(xs: Array) -> float:
	var t := 0.0
	for x in xs:
		t += x
	return t / float(maxi(xs.size(), 1))


func _guardar(informe: Array, iters: int, partidas: int) -> void:
	var f := FileAccess.open("user://calibrate_sa.json", FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"iteraciones_por_config": iters,
		"replicas": REPLICAS,
		"cadenas": informe,
		"partidas_totales": partidas,
		"timestamp": Time.get_datetime_string_from_system(true),
	}, "  "))
	f.close()
	print("[cal] informe en: %s" % ProjectSettings.globalize_path("user://calibrate_sa.json"))


func _int_env(name: String, fallback: int) -> int:
	var v := OS.get_environment(name)
	return int(v) if v != "" else fallback
