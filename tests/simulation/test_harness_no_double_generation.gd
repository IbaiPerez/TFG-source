extends GutTest

## Regresion: el harness ya no genera el mundo dos veces.
##
## Bug original (sim_full_game.json, master seed 20260516, run 1):
## `WorldGenerator._ready()` auto-generaba un mundo al ser añadido al
## arbol y el harness invocaba `generate_world()` inmediatamente despues.
## Resultado: dos mapas distintos creados de forma secuencial,
## `EmpireCreator.create_empires()` corriendo dos veces sobre WorldMaps
## diferentes. Si el segundo intento caia en un mapa degenerado (radius
## pequeno + ocean_threshold alto, etc.), uno de los imperios acababa
## con 0 tiles sin que ningun assert saltara — solo un push_error en
## consola.
##
## Fix aplicado:
##   - `WorldGenerator.auto_generate_on_ready` controla la generacion
##     automatica en `_ready()`.
##   - El harness lo pone a false antes de `add_child(generator)`, asi
##     `_ready` ya no genera y queda una unica pasada de generate_world.
##
## Este test reproduce la semilla exacta del bug y verifica que tras el
## bootstrap (max_rounds=0), ningun imperio empieza con 0 tiles en
## ninguna de las 5 runs.


const MULTI_RUN := preload("res://tests/simulation/multi_run_simulator.gd")


func before_each() -> void:
	WorldMap.map = []
	WorldMap.map_as_dict = {}
	BattleFront.clear_active_instances()


func after_each() -> void:
	WorldMap.map = []
	WorldMap.map_as_dict = {}
	BattleFront.clear_active_instances()


func test_no_empire_starts_with_zero_tiles_under_original_failing_seed() -> void:
	# Misma configuracion que `test_sim_full_game.gd` pero con max_rounds=0
	# para que el test sea rapido: queremos ejercitar solo el bootstrap
	# (generate_world + create_empires + wire_stats), que es donde vivia
	# el bug.
	var multi = MULTI_RUN.new()
	multi.num_runs = 5
	multi.max_rounds = 0  # 0 = solo bootstrap, sin rondas jugadas
	multi.rng_master_seed = 20260516  # Semilla original del JSON con el bug.
	multi.attach_to(self)

	await multi.run()

	# Para cada run, los dos primeros snapshots son R=0 para AI_A y AI_B.
	# Ambos deben tener al menos 1 tile, si no es que el bug ha vuelto.
	assert_eq(multi.runs.size(), 5, "Se esperaban 5 runs ejecutadas")
	for r in multi.runs:
		var snaps: Array = r["snapshots"]
		assert_eq(snaps.size(), 2,
			"Con max_rounds=0 cada run debe tener exactamente 2 snapshots (R=0 x 2 IAs)")
		var ai_a_snap: Dictionary = snaps[0]
		var ai_b_snap: Dictionary = snaps[1]

		var tiles_a: int = int(ai_a_snap["map"]["controlled_tiles"])
		var tiles_b: int = int(ai_b_snap["map"]["controlled_tiles"])

		assert_gt(tiles_a, 0,
			"run %d AI_A (%s) empezo con 0 tiles" % [
				r["run_id"], ai_a_snap.get("empire", "?")
			])
		assert_gt(tiles_b, 0,
			"run %d AI_B (%s) empezo con 0 tiles" % [
				r["run_id"], ai_b_snap.get("empire", "?")
			])

	# Consumimos warnings/errores acumulados durante el bootstrap (fallback
	# de EmpireCreator con radius bajos, colisiones headless del motor de
	# fisica, etc.). Ninguno es fallo de este test.
	for e in get_errors():
		e.handled = true
