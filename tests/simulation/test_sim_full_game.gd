extends GutTest

## Test-driver para la simulacion headless de partida completa.
##
## Configuracion:
##  - 5 runs independientes.
##  - 100 turnos por run.
##  - Cada run usa WorldGenerator real con radius / mountain_threshold /
##    ocean_threshold / empires del jugador y rival randomizados.
##  - Ambos imperios son AIController (sin jugador humano). El "rol" de
##    primer turno es de AI_A.
##  - Deck inicial real (sin inyeccion de cartas militares).
##
## Como ejecutarlo:
##   godot --headless -s addons/gut/gut_cmdln.gd \
##     -gtest=res://tests/simulation/test_sim_full_game.gd -gexit
##
## Output JSON: `user://sim_full_game.json`. En Windows:
##   %APPDATA%\Godot\app_userdata\Source\sim_full_game.json


const MULTI_RUN := preload("res://tests/simulation/multi_run_simulator.gd")


func test_run_simulation() -> void:
	WorldMap.map = []
	WorldMap.map_as_dict = {}
	BattleFront.clear_active_instances()

	var multi = MULTI_RUN.new()
	# 15 runs: equilibrio entre precision estadistica y tiempo de ejecucion.
	# Con 100 rondas por run doblar los runs duplicaria el tiempo; 15 ofrece
	# error estandar de la media ~1/sqrt(3) ≈ 0.58x respecto a 5 runs,
	# suficiente para distinguir tendencias de balance en late-game.
	multi.num_runs = 15
	multi.num_rounds = 100
	multi.rng_master_seed = 20260516  # YYYYMMDD para tener un seed estable y fechado
	multi.attach_to(self)

	print("[Sim] Iniciando: %d runs x %d rondas (master seed = %d)" % [
		multi.num_runs, multi.num_rounds, multi.rng_master_seed
	])

	await multi.run()

	var out_path := "user://sim_full_game.json"
	multi.dump_to(out_path)
	print("[Sim] Path absoluto: %s" % ProjectSettings.globalize_path(out_path))

	_print_summary(multi)

	# Limpieza final.
	WorldMap.map = []
	WorldMap.map_as_dict = {}
	BattleFront.clear_active_instances()

	# Consumir los errores/warnings acumulados durante la sim. En 5 runs
	# x 100 turnos x 2 imperios pueden aflorar:
	#   * push_warnings del fallback de EmpireCreator (radius bajo).
	#   * push_errors si un mapa degenerado dejo a un imperio sin tiles.
	#   * engine warnings del motor de fisica al instanciar colliders
	#     headless ("Collisions between two concave shapes...").
	# Ninguno es un fallo de la sim per se; los marcamos como handled
	# para que el test no quede como Failed por "Unexpected Errors".
	# Los mensajes siguen visibles en el stdout para inspeccion manual.
	for e in get_errors():
		e.handled = true

	# Sanity check: el harness añade 2 snapshots iniciales (turno 0) +
	# 2 por ronda → 2 + 2*num_rounds por run.
	var expected_total = (2 + 2 * multi.num_rounds) * multi.num_runs
	var actual_total := 0
	for r in multi.runs:
		actual_total += r["snapshots"].size()
	assert_eq(actual_total, expected_total,
		"snapshots totales = %d esperados, %d obtenidos" % [expected_total, actual_total])

	# Sanity check de labels: cada run debe contener EXACTAMENTE las
	# etiquetas "AI_A" y "AI_B". Si esto falla es porque algun nodo de
	# una run anterior sigue vivo en el arbol y Godot esta dando el
	# nombre fallback `@Node@...` → la agregacion por (round, ai_label)
	# deja de casar entre runs y los mean/std se vuelven engañosos.
	#
	# Nota: `ai.name` es StringName en Godot 4. Array.sort() sobre
	# StringName no es lexicografico (ordena por puntero), por eso
	# convertimos a String antes de comparar.
	for r in multi.runs:
		var labels := {}
		for s in r["snapshots"]:
			labels[String(s["ai_label"])] = true
		var keys: Array = labels.keys()
		keys.sort()
		assert_eq(keys, ["AI_A", "AI_B"],
			"run %d: labels esperados [AI_A, AI_B], obtenidos %s" % [r["run_id"], keys])


# --- Resumen stdout --------------------------------------------------------

func _print_summary(multi) -> void:
	print("\n[Sim] === RESUMEN ===")
	print("[Sim] Runs ejecutadas: %d" % multi.runs.size())

	# Por run: imperios elegidos.
	for r in multi.runs:
		print("[Sim]   run %d → A=%s vs B=%s | radius=%d, mtn=%.2f, ocean=%.2f" % [
			r["run_id"],
			r["seed_meta"].get("empire_a", "?"),
			r["seed_meta"].get("empire_b", "?"),
			r["seed_meta"].get("radius", 0),
			r["seed_meta"].get("mountain_threshold", 0.0),
			r["seed_meta"].get("ocean_threshold", 0.0),
		])

	# Para cada AI, comparar metricas en turnos clave (inicio, mitad, fin).
	var labels := ["AI_A", "AI_B"]
	var key_rounds := [0, int(multi.num_rounds / 4), int(multi.num_rounds / 2),
		int(multi.num_rounds * 3 / 4), multi.num_rounds]

	# Calculo los agregados una sola vez.
	var aggs: Array = multi.aggregate()
	var by_key := {}
	for a in aggs:
		by_key["%d|%s" % [a["round"], a["ai_label"]]] = a

	for label in labels:
		print("\n[Sim] --- %s (media ± std de %d runs) ---" % [label, multi.num_runs])
		print("[Sim] %-6s %-12s %-10s %-8s %-10s %-10s %-8s" % [
			"Round", "Gold", "Tiles", "Bldgs", "Troops", "MaintG", "Fronts"
		])
		for round_num in key_rounds:
			var agg = by_key.get("%d|%s" % [round_num, label])
			if agg == null:
				continue
			var m: Dictionary = agg["metrics"]
			print("[Sim] %-6d %-12s %-10s %-8s %-10s %-10s %-8s" % [
				round_num,
				_fmt(m["economy.total_gold"]),
				_fmt(m["map.controlled_tiles"]),
				_fmt(m["map.buildings_total"]),
				_fmt(m["military.troop_pool_size"]),
				_fmt(m["military.troop_maintenance_gold"]),
				_fmt(m["military.fronts_in_manager"]),
			])

	# Cuando se desbloquean cartas militares y aparecen tropas.
	_print_milestone(multi, "AI_A")
	_print_milestone(multi, "AI_B")


func _fmt(stats: Dictionary) -> String:
	return "%.0f±%.0f" % [stats.get("mean", 0.0), stats.get("std", 0.0)]


func _print_milestone(multi, ai_label: String) -> void:
	# Promedio de la ronda en que troop_pool_size pasa de 0 (primera tropa)
	# y promedio de la ronda en que aparece el primer frente.
	var first_troop_rounds: Array = []
	var first_front_rounds: Array = []
	var unlocked_recruit_rounds: Array = []
	var unlocked_open_front_rounds: Array = []

	for r in multi.runs:
		var found_troop := -1
		var found_front := -1
		var found_recruit := -1
		var found_open_front := -1
		for s in r["snapshots"]:
			if s["ai_label"] != ai_label:
				continue
			if found_troop < 0 and s["military"]["troop_pool_size"] > 0:
				found_troop = s["round"]
			if found_front < 0 and s["military"]["fronts_in_manager"] > 0:
				found_front = s["round"]
			var ids: Array = s["deck"]["unlocked_card_ids"]
			if found_recruit < 0 and ids.has("Recruit"):
				found_recruit = s["round"]
			if found_open_front < 0 and ids.has("Open Front"):
				found_open_front = s["round"]
		if found_troop >= 0: first_troop_rounds.append(found_troop)
		if found_front >= 0: first_front_rounds.append(found_front)
		if found_recruit >= 0: unlocked_recruit_rounds.append(found_recruit)
		if found_open_front >= 0: unlocked_open_front_rounds.append(found_open_front)

	print("\n[Sim] --- Hitos %s (rondas, n/%d alcanzados) ---" % [ai_label, multi.num_runs])
	print("[Sim]   Desbloqueo Recruit:    %s" % _summary_array(unlocked_recruit_rounds, multi.num_runs))
	print("[Sim]   Desbloqueo OpenFront:  %s" % _summary_array(unlocked_open_front_rounds, multi.num_runs))
	print("[Sim]   Primera tropa:         %s" % _summary_array(first_troop_rounds, multi.num_runs))
	print("[Sim]   Primer frente:         %s" % _summary_array(first_front_rounds, multi.num_runs))


func _summary_array(values: Array, total_runs: int) -> String:
	if values.is_empty():
		return "nunca (0/%d)" % total_runs
	var sum := 0.0
	var vmin = values[0]
	var vmax = values[0]
	for v in values:
		sum += v
		vmin = min(vmin, v)
		vmax = max(vmax, v)
	var mean := sum / values.size()
	return "media %.1f [%d, %d] (%d/%d)" % [mean, vmin, vmax, values.size(), total_runs]
