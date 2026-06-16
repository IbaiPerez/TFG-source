extends RefCounted
class_name GameSimHarness

## Harness de simulacion headless: monta una partida usando el
## WorldGenerator real (con tiles, biomas, recursos, agua y montañas
## reales) y dos AIControllers (sin jugador humano). Corre rondas hasta que
## se detecte una condicion de victoria (dominacion o eliminacion). Sin UI
## 3D ni paneles, pero reutilizando toda la logica de generacion y de turno.
##
## Uso:
##   var sim := GameSimHarness.new()
##   sim.max_rounds = 500   # limite de seguridad; la partida termina antes
##   sim.run_id = 0
##   sim.attach_to(gut_test)
##   await sim.run()
##   var snapshots := sim.snapshots
##
## Diseño:
##   - Sin TurnManager: orquestamos manualmente `await ai.start_turn()`.
##   - Tiles: TileFactory real → cada tile es Node3D con mesh y collider.
##   - WorldMap, TilesTracker, BattleFront se limpian al inicio y final.
##   - Cada run randomiza (dentro de rangos definidos):
##       * radius del mapa
##       * mountain_threshold y ocean_threshold
##       * imperios del bando A y bando B (distintos entre si)
##       * seeds de los noises (map_seed=0 → init_seed los randomiza)


# --- Config por run --------------------------------------------------------

var max_rounds: int = 500   ## Limite de seguridad; la partida termina antes si hay ganador
var run_id: int = 0
var rng_master: RandomNumberGenerator        ## Para randomizar settings de run

# Rangos de randomizacion (puedes ajustarlos)
# Radio 4-6 = tamaño realista (61-127 casillas). Radios mayores (hasta 10 = 331
# casillas) disparan el coste por iteración del MCTS y meten ruido de tamaño en
# las comparaciones, así que por defecto nos quedamos en el rango jugable.
var radius_range := Vector2i(4, 6)
var mountain_range := Vector2(0.5, 0.8)
var ocean_range := Vector2(0.5, 0.7)

## AIConfig por bando. null → el AIController crea su default en _ready()
## (mode=MCTS). Asignar configs distintas permite enfrentar modos de IA
## (heurística vs MCTS) en la misma partida.
var config_a: AIConfig = null
var config_b: AIConfig = null

## Si false, se omite la captura de snapshots por turno (economía/deck/mapa/
## militar/heurística). Acelera las comparaciones de modo, donde solo
## interesan ganador, coste por turno y acciones jugadas.
var capture_snapshots: bool = true


# --- Recursos -------------------------------------------------------------

const DEFAULT_SETTINGS := preload("res://resources/world_settings/Default.tres")
const INITIAL_STATS := preload("res://resources/stats/initial_stats.tres")
const TILES_TRACKER_SCRIPT := preload("res://scripts/tile/tiles_tracker.gd")


# --- Estado interno --------------------------------------------------------

var _gut_test
var _settings: GenerationSettings
var _tile_parent: Node3D
var _tiles_tracker: Node
var _run_root: Node                          ## Padre de TODOS los nodos de esta run
var ai_a: AIController
var ai_b: AIController
var stats_a: Stats
var stats_b: Stats
var snapshots: Array = []
var run_seed_meta: Dictionary = {}
var winner_empire_name: String = ""
var winner_label: String = ""       ## "AI_A" | "AI_B" | "" si no termino (empate/limite)
var victory_condition: String = ""  ## "domination" | "elimination" | "" si no termino
var finished_round: int = -1

## Recuento de casillas al terminar la partida (para saber si se colonizó todo
## el mapa o la partida acabó antes por dominación/eliminación).
var final_tiles_a: int = 0
var final_tiles_b: int = 0
var final_total_tiles: int = 0     ## WorldMap.map.size() (incluye agua/montaña)

## Si true, registra por turno la AUTO-EVALUACIÓN de cada IA: score_state del
## estado real desde su perspectiva + casillas propias/rival. Sirve para
## diagnosticar si la IA "sabe" cuándo va ganando/perdiendo (¿la curva de
## score_state sigue a la ventaja real de territorio, y con qué antelación?).
var capture_self_eval: bool = false
var self_eval_trace: Array = []    ## [{round, label, mode, empire, score_state, my_tiles, rival_tiles}]

## Diagnóstico MCTS de la partida: nº de decisiones del lado MCTS y de cuántas
## la búsqueda se apartó del prior heurístico. Capturados al terminar.
var mcts_decisions: int = 0
var mcts_prior_overrides: int = 0

## Conteo de acciones jugadas por etiqueta de IA → { card_class: count }.
## Poblado escuchando Events.ai_card_played. Permite comparar el "estilo" de
## juego de cada modo (cuántas Colonize/Build/Recruit/OpenFront/Tactic…).
var actions_by_label: Dictionary = {"AI_A": {}, "AI_B": {}}

## Coste de decisión por etiqueta: microsegundos totales en start_turn() y
## número de turnos jugados. ms/turno = (usec/turns)/1000. La diferencia entre
## el bando MCTS y el heurístico aísla el sobrecoste de la búsqueda.
var turn_usec_by_label: Dictionary = {"AI_A": 0, "AI_B": 0}
var turns_by_label: Dictionary = {"AI_A": 0, "AI_B": 0}
## Historial de frentes resueltos, contadores por empire.name. Cada empire
## tiene { won_as_atk, won_as_def, lost_as_atk, lost_as_def, total_resolved }.
## El harness escucha `Events.battle_front_resolved` y agrega aquí; los
## snapshots incorporan estos contadores en `military.resolved`. Sin esto,
## en el snapshot solo se ven los frentes ACTIVOS — los frentes que se han
## resuelto desaparecen del registro global y quedan invisibles.
var _battle_history: Dictionary = {}


# --- API publica -----------------------------------------------------------

func attach_to(gut_test) -> void:
	_gut_test = gut_test


func run() -> void:
	BattleFront.clear_active_instances()
	WorldMap.map = []
	WorldMap.map_as_dict = {}

	# Un raiz por run: todos los nodos (tiles, generator, AIs, tracker)
	# cuelgan de aqui y se liberan en bloque al final. Sin esto, las AIs
	# de la run anterior siguen vivas en el arbol del test (autofree solo
	# libera al terminar el test entero) y `ai.name = "AI_A"` colisiona,
	# por lo que Godot le asigna nombre fallback (@Node@1234...) y la
	# agregacion del MultiRunSimulator deja de casar las runs.
	_run_root = Node.new()
	_run_root.name = "SimRunRoot_%d" % run_id
	_gut_test.add_child(_run_root)

	_spawn_tiles_tracker()
	_randomize_settings()
	_run_world_generator()
	_wire_stats_to_generated_empires()
	_spawn_ai_controllers()

	# Suscripcion al bus global: cada vez que cualquier frente se resuelve,
	# acumulamos en `_battle_history` para tener el conteo final de la run.
	# Se conecta tras spawnar las AIs (ya tenemos sus stats/empires) y se
	# desconecta al final del run() para no fugar entre runs.
	_battle_history = {}
	if not Events.battle_front_resolved.is_connected(_on_battle_front_resolved):
		Events.battle_front_resolved.connect(_on_battle_front_resolved)

	# Conteo de acciones jugadas por cada IA (Events.ai_card_played).
	actions_by_label = {"AI_A": {}, "AI_B": {}}
	turn_usec_by_label = {"AI_A": 0, "AI_B": 0}
	turns_by_label = {"AI_A": 0, "AI_B": 0}
	if not Events.ai_card_played.is_connected(_on_ai_card_played):
		Events.ai_card_played.connect(_on_ai_card_played)

	if capture_snapshots:
		snapshots.append(_capture_snapshot(0, ai_a))
		snapshots.append(_capture_snapshot(0, ai_b))

	var round_num := 0
	while round_num < max_rounds:
		# Temporizamos solo start_turn() (decisión + ejecución), no la captura
		# de snapshot, para que el coste medido sea el de la IA.
		var t0 := Time.get_ticks_usec()
		await ai_a.start_turn()
		turn_usec_by_label["AI_A"] += Time.get_ticks_usec() - t0
		turns_by_label["AI_A"] += 1
		if capture_snapshots:
			snapshots.append(_capture_snapshot(round_num + 1, ai_a))
		_capture_self_eval(round_num + 1, ai_a)

		var t1 := Time.get_ticks_usec()
		await ai_b.start_turn()
		turn_usec_by_label["AI_B"] += Time.get_ticks_usec() - t1
		turns_by_label["AI_B"] += 1
		if capture_snapshots:
			snapshots.append(_capture_snapshot(round_num + 1, ai_b))
		_capture_self_eval(round_num + 1, ai_b)

		var result := _check_victory_in_sim()
		if not result.is_empty():
			winner_empire_name = result["winner"]
			victory_condition = result["condition"]
			finished_round = round_num + 1
			winner_label = "AI_A" if winner_empire_name == stats_a.empire.name else "AI_B"
			break

		round_num += 1
		# Yield al motor entre rondas para evitar warnings de "frame too long"
		# y mantener el heartbeat de GUT activo.
		await _gut_test.get_tree().process_frame

	# Recuento final de casillas ANTES de liberar las tiles (run_root). Sirve
	# para distinguir "la partida acabó con el mapa lleno" de "acabó antes por
	# dominación/eliminación con casillas sin colonizar".
	if stats_a != null and stats_a.empire != null:
		final_tiles_a = stats_a.empire.controlled_tiles.size()
	if stats_b != null and stats_b.empire != null:
		final_tiles_b = stats_b.empire.controlled_tiles.size()
	final_total_tiles = WorldMap.map.size()

	# Contadores de diagnóstico MCTS del bando MCTS (antes de liberar las IAs).
	var mcts_ai: AIController = null
	if config_a != null and config_a.mode == AIConfig.Mode.MCTS:
		mcts_ai = ai_a
	elif config_b != null and config_b.mode == AIConfig.Mode.MCTS:
		mcts_ai = ai_b
	if mcts_ai != null:
		mcts_decisions = mcts_ai.mcts_decisions
		mcts_prior_overrides = mcts_ai.mcts_prior_overrides

	# Cleanup obligatorio antes de devolver: liberamos el raiz para que
	# la siguiente run pueda registrar `AI_A` / `AI_B` sin colision.
	# Los `snapshots` ya estan poblados (dicts puros), no dependen de los
	# nodos vivos. Esperamos un frame para que queue_free se procese.
	if Events.battle_front_resolved.is_connected(_on_battle_front_resolved):
		Events.battle_front_resolved.disconnect(_on_battle_front_resolved)
	if Events.ai_card_played.is_connected(_on_ai_card_played):
		Events.ai_card_played.disconnect(_on_ai_card_played)
	_run_root.queue_free()
	_run_root = null
	ai_a = null
	ai_b = null
	_tile_parent = null
	_tiles_tracker = null
	await _gut_test.get_tree().process_frame


# --- Bootstrap -------------------------------------------------------------

func _spawn_tiles_tracker() -> void:
	# TilesTracker es Node hijo del Map en el juego real. Lo necesitamos
	# porque EmpireCreator emite `change_tile_controller` y el tracker es
	# quien llama a empire.add_tile() y dispara location_changed → Village.
	_tiles_tracker = Node.new()
	_tiles_tracker.set_script(TILES_TRACKER_SCRIPT)
	_run_root.add_child(_tiles_tracker)


func _randomize_settings() -> void:
	# Duplicar a fondo (deep=true) para no mutar el Default.tres global
	# entre runs.
	_settings = DEFAULT_SETTINGS.duplicate(true) as GenerationSettings

	# map_seed=0 → WorldGenerator.init_seed() randomiza biome/mountain/ocean
	# noises con randi() del global RNG. Para reproducibilidad usamos
	# rng_master.seed previo a esta llamada.
	_settings.map_seed = 0

	_settings.radius = rng_master.randi_range(radius_range.x, radius_range.y)
	_settings.mountain_threshold = rng_master.randf_range(mountain_range.x, mountain_range.y)
	_settings.ocean_threshold = rng_master.randf_range(ocean_range.x, ocean_range.y)

	# Empires aleatorios: cogemos los 3 disponibles del Default.tres,
	# barajamos, primero al bando A, segundo al bando B.
	var all_empires: Array[Empire] = []
	all_empires.append(_settings.player_empire)
	for e in _settings.empires:
		if e != _settings.player_empire:
			all_empires.append(e)
	all_empires.shuffle()

	_settings.player_empire = all_empires[0]
	# `empires` es la lista de candidatos a IA. El EmpireCreator hara
	# pick_random sobre esa lista — para forzar al bando B fijamos solo
	# uno candidato.
	var enemy_list: Array[Empire] = []
	enemy_list.append(all_empires[1])
	_settings.empires = enemy_list

	run_seed_meta = {
		"radius": _settings.radius,
		"mountain_threshold": _settings.mountain_threshold,
		"ocean_threshold": _settings.ocean_threshold,
		"empire_a": _settings.player_empire.name,
		"empire_b": all_empires[1].name,
	}


func _run_world_generator() -> void:
	_tile_parent = Node3D.new()
	_tile_parent.name = "TileParent"
	_run_root.add_child(_tile_parent)

	var generator := preload("res://scripts/world_gen/world_generator.gd").new()
	# Conducimos init_seed + generate_world a mano, asi que apagamos la
	# auto-generacion de `_ready()`. Sin esto, `add_child(generator)`
	# disparaba _ready, que ya invocaba init_seed + generate_world por su
	# cuenta, y luego el harness lo volvia a invocar abajo: dos mundos
	# distintos, EmpireCreator corriendo dos veces sobre WorldMaps
	# distintos, y un imperio acabando con 0 tiles si el segundo intento
	# caia en un mapa degenerado.
	generator.auto_generate_on_ready = false
	generator.settings = _settings
	generator.tile_parent = _tile_parent
	# WorldGenerator es Node, lo añadimos al arbol antes de generar para
	# que get_tree() funcione si lo necesita internamente.
	_run_root.add_child(generator)
	generator.init_seed()
	generator.generate_world()


func _wire_stats_to_generated_empires() -> void:
	# Despues de generate_world, settings.player_empire y settings.empires[0]
	# tienen sus controlled_tiles asignadas via EmpireCreator → TilesTracker.
	var empire_a: Empire = _settings.player_empire
	var empire_b: Empire = _settings.empires[0]

	stats_a = INITIAL_STATS.create_instance() as Stats
	stats_b = INITIAL_STATS.create_instance() as Stats
	stats_a.empire = empire_a
	stats_b.empire = empire_b

	stats_a.available_events = _load_turn_events()
	stats_b.available_events = _load_turn_events()


func _spawn_ai_controllers() -> void:
	# Seeds derivados del rng_master para reproducibilidad de la run
	# completa: misma seed_master → misma sim entera (mapa + decisiones).
	ai_a = _spawn_ai(stats_a, rng_master.randi(), "AI_A", config_a)
	ai_b = _spawn_ai(stats_b, rng_master.randi(), "AI_B", config_b)

	# Registro mínimo de controllers para que cada IA vea al rival vía
	# AIController._build_world_view() — IMPRESCINDIBLE para el MCTS: sin un
	# rival visible, AIGameState.from_context deja rival_tiles=0 y la
	# evaluación da 1.0 (victoria) en todo estado, degenerando la búsqueda.
	# También habilita el deck observer (_ensure_observer_ready).
	#
	# NO usamos TurnManager.register_controller(): conectaría turn_finished y
	# dispararía el auto-avance de turnos, en conflicto con la orquestación
	# manual (await ai.start_turn()). Poblamos .controllers directamente.
	var tm := TurnManager.new()
	tm.name = "SimTurnManager"
	tm.controllers.append(ai_a)
	tm.controllers.append(ai_b)
	_run_root.add_child(tm)
	ai_a.turn_manager = tm
	ai_b.turn_manager = tm


func _spawn_ai(stats: Stats, seed_value: int, name: String,
		config: AIConfig = null) -> AIController:
	var ai := AIController.new()
	ai.name = name
	ai.action_delay = 0.0
	ai.turn_end_delay = 0.0
	ai.rng_seed = seed_value
	ai.max_iterations = 20
	# Asignar antes de add_child: _ready() solo crea un default si ai_config
	# es null, así que esto fija el modo (heurística / MCTS) de este bando.
	if config != null:
		ai.ai_config = config
	_run_root.add_child(ai)
	ai.start_game(stats)
	return ai


## Listener de Events.ai_card_played. Contabiliza la acción por etiqueta de IA
## y tipo de carta (nombre de clase). Mapea el empire emisor a AI_A/AI_B.
func _on_ai_card_played(card: Card, _anchor_tile: Tile, empire: Empire,
		_payload: Dictionary) -> void:
	if card == null or empire == null:
		return
	var label := ""
	if stats_a != null and empire == stats_a.empire:
		label = "AI_A"
	elif stats_b != null and empire == stats_b.empire:
		label = "AI_B"
	else:
		return
	var key := _card_action_label(card)
	var tally: Dictionary = actions_by_label[label]
	tally[key] = tally.get(key, 0) + 1


## Etiqueta legible del tipo de carta para el conteo de acciones.
func _card_action_label(card: Card) -> String:
	var script := card.get_script() as Script
	if script != null:
		var gname := script.get_global_name()
		if gname != &"":
			return String(gname)
	return "UnknownCard"


func _load_turn_events() -> Array[TurnEvent]:
	var events: Array[TurnEvent] = []
	var dir := DirAccess.open("res://resources/turn_events/")
	if dir == null:
		return events
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var event := load("res://resources/turn_events/" + file_name) as TurnEvent
			if event:
				events.append(event)
		file_name = dir.get_next()
	dir.list_dir_end()
	return events


# --- Condiciones de victoria -----------------------------------------------

## Comprueba dominación (>= 70 % del mapa) y eliminación (rival a 0 tiles).
## Devuelve {"winner": nombre, "condition": "domination"|"elimination"}
## o {} si la partida continúa.
func _check_victory_in_sim() -> Dictionary:
	var total := WorldMap.map.size()
	if total == 0 or stats_a == null or stats_b == null:
		return {}
	var a_tiles := stats_a.empire.controlled_tiles.size()
	var b_tiles := stats_b.empire.controlled_tiles.size()
	if b_tiles == 0 and a_tiles > 0:
		return {"winner": stats_a.empire.name, "condition": "elimination"}
	if a_tiles == 0 and b_tiles > 0:
		return {"winner": stats_b.empire.name, "condition": "elimination"}
	const THRESHOLD := 0.70
	if float(a_tiles) / float(total) >= THRESHOLD:
		return {"winner": stats_a.empire.name, "condition": "domination"}
	if float(b_tiles) / float(total) >= THRESHOLD:
		return {"winner": stats_b.empire.name, "condition": "domination"}
	return {}


# --- Captura de metricas ---------------------------------------------------

## Registra la auto-evaluación de la IA en el turno actual: construye el
## snapshot del estado REAL desde su perspectiva (igual que hace el MCTS al
## decidir) y guarda score_state + casillas. Comparar la curva de score_state
## con la ventaja real de tiles revela si la IA "sabe" su situación y cuándo.
func _capture_self_eval(round_num: int, ai: AIController) -> void:
	if not capture_self_eval or ai == null or ai.stats == null:
		return
	var ctx := AITurnContext.new()
	ctx.controller = ai
	ctx.stats = ai.stats
	ctx.battle_front_manager = ai.battle_front_manager
	ctx.rng = RandomNumberGenerator.new()
	ctx.drawn_cards = []
	ctx.world_view = ai._build_world_view()
	ctx.total_map_tiles = WorldMap.map.size()
	var snap := AIRealState.from_context(ctx)
	var mode := "MCTS" if (ai.ai_config != null \
		and ai.ai_config.mode == AIConfig.Mode.MCTS) else "HEURISTIC"
	self_eval_trace.append({
		"round": round_num,
		"label": ai.name,
		"mode": mode,
		"empire": ai.stats.empire.name if ai.stats.empire else "",
		"score_state": AIRealEval.score_state(snap),
		"my_tiles": snap.count_tiles(AIRealState.OWNER_SELF),
		"rival_tiles": snap.count_tiles(AIRealState.OWNER_RIVAL),
		"total_tiles": snap.total_map_tiles,
	})


func _capture_snapshot(round_num: int, ai: AIController) -> Dictionary:
	var stats := ai.stats
	var empire := stats.empire
	return {
		"run_id": run_id,
		"round": round_num,
		"empire": empire.name if empire else "",
		"ai_label": ai.name,
		"turn_number": stats.turn_number,
		"economy": _capture_economy(stats),
		"deck": _capture_deck(stats, ai),
		"map": _capture_map(empire),
		"military": _capture_military(stats, ai),
		"modifiers": _capture_modifiers(ai.modifier_manager),
		"heuristic": _capture_heuristic(ai),
	}


func _capture_economy(stats: Stats) -> Dictionary:
	# `combat_multiplier` vive en el Empire y lo recalcula `EmpireController`
	# cada turno segun el deficit relativo de oro+comida (Opcion 3). Lo
	# exponemos para poder ver, post-mortem, cuantos snapshots estuvieron en
	# penalizacion economica (mult < 1.0) y cuanto tiempo.
	var combat_mult: float = 1.0
	if stats.empire != null:
		combat_mult = stats.empire.combat_multiplier
	return {
		"total_gold": stats.total_gold,
		"gold_per_turn": stats.gold_per_turn,
		"food": stats.food,
		"total_purges_done": stats.total_purges_done,
		"combat_multiplier": combat_mult,
	}


func _capture_deck(stats: Stats, ai: AIController) -> Dictionary:
	# `stats.cards_per_turn` es el valor BASE (siempre 2 con el deck inicial).
	# La mano real que la IA roba es el efectivo: base + bonus de modifiers
	# (Horde Ability, Library, Observatorio, Gran Biblioteca, Palacio, Wise
	# Travelers, Spirit Susurros…). Capturamos los tres para poder distinguir
	# cuanto de cada partida es base, ability y construido.
	var bonus := 0
	if ai and ai.modifier_manager:
		bonus = ai.modifier_manager.get_cards_per_turn_bonus()
	# `deck_total_size` (Stats.deck) refleja el `starting_deck` y NUNCA cambia
	# durante la partida; las cartas reales viven en draw/discard/played, asi
	# que esa metrica por si sola es engañosa (en la primera simulacion el
	# valor se quedo en 4 las 100 rondas). Añadimos `deck_total_real` que
	# suma las tres pilas para tener el tamaño dinamico de mazo.
	var draw_n: int = stats.draw_pile.cards.size() if stats.draw_pile else 0
	var disc_n: int = stats.discard_pile.cards.size() if stats.discard_pile else 0
	var play_n: int = stats.played_pile.cards.size() if stats.played_pile else 0
	return {
		"draw_pile": draw_n,
		"discard_pile": disc_n,
		"played_pile": play_n,
		"deck_total_size": stats.deck.cards.size() if stats.deck else 0,
		"deck_total_real": draw_n + disc_n + play_n,
		"cards_per_turn_base": stats.cards_per_turn,
		"cards_per_turn_bonus": bonus,
		"cards_per_turn": clampi(stats.cards_per_turn + bonus, 1, 20),
		"unlocked_pool_size": stats.unlocked_card_pool.size(),
		"unlocked_card_ids": _list_unlocked_card_ids(stats),
	}


func _list_unlocked_card_ids(stats: Stats) -> Array:
	var ids := []
	for entry in stats.unlocked_card_pool:
		if entry and entry.card:
			ids.append(entry.card.id)
	return ids


func _capture_map(empire: Empire) -> Dictionary:
	var by_loc := {}
	var by_biome := {}
	var by_resource := {}
	var buildings_total := 0
	var buildings_by_name := {}
	# Filtramos tiles invalidas (`previously freed`) por si quedaran refs
	# colgantes en empire.controlled_tiles de runs anteriores. Hoy
	# EmpireCreator hace reset defensivo al inicio, pero esto es defensa
	# en profundidad: si en el futuro otro flujo deja refs stale, el
	# snapshot ya no crashea — solo las omite del conteo.
	var valid_tiles: Array[Tile] = []
	for t in empire.controlled_tiles:
		if t != null and is_instance_valid(t):
			valid_tiles.append(t)
	for t in valid_tiles:
		var loc_name: String = ""
		if t.location:
			loc_name = Tile.location_type.keys()[t.location.type]
		by_loc[loc_name] = by_loc.get(loc_name, 0) + 1
		var biome_name: String = t.biome if t.biome else ""
		by_biome[biome_name] = by_biome.get(biome_name, 0) + 1
		var res_name: String = t.natural_resource.name if t.natural_resource else ""
		by_resource[res_name] = by_resource.get(res_name, 0) + 1
		for b in t.buildings:
			buildings_total += 1
			buildings_by_name[b.name] = buildings_by_name.get(b.name, 0) + 1
	return {
		"total_map_tiles": WorldMap.map.size(),
		# Reportamos el tamaño REAL (tiles vivas), no el de la lista
		# bruta, para que un eventual error de bookkeeping se vea en
		# los datos en lugar de inflar contadores con tiles fantasma.
		"controlled_tiles": valid_tiles.size(),
		"tiles_by_location": by_loc,
		"tiles_by_biome": by_biome,
		"tiles_by_resource": by_resource,
		"buildings_total": buildings_total,
		"buildings_by_name": buildings_by_name,
	}


func _capture_military(stats: Stats, ai: AIController) -> Dictionary:
	var by_type := {}
	for troop in stats.troop_pool:
		if troop == null:
			continue
		# La propiedad en Troop es `type` (enum Troop.TroopType), no
		# `troop_type`. Usamos la etiqueta legible para que el JSON sea
		# directamente inspeccionable.
		var key: String = troop.get_type_label()
		by_type[key] = by_type.get(key, 0) + 1

	var fronts_as_atk := 0
	var fronts_as_def := 0
	var markers := []
	for front in BattleFront.get_active_instances():
		if front.attacker_empire == stats.empire:
			fronts_as_atk += 1
		if front.defender_empire == stats.empire:
			fronts_as_def += 1
		if front.attacker_empire == stats.empire or front.defender_empire == stats.empire:
			markers.append({
				"marker": front.marker,
				"turns_elapsed": front.turns_elapsed,
				"atk_troops": front.attacker_troops.size(),
				"def_troops": front.defender_troops.size(),
				"i_am_attacker": front.attacker_empire == stats.empire,
			})

	# Historial acumulado de frentes resueltos para este imperio (puede estar
	# vacio si nunca cierra un frente). Defaults a 0 para que el dict tenga
	# siempre las mismas claves y los agregados no fallen.
	var emp_name: String = stats.empire.name if stats.empire else ""
	var resolved: Dictionary = _battle_history.get(emp_name, {
		"won_as_attacker": 0,
		"won_as_defender": 0,
		"lost_as_attacker": 0,
		"lost_as_defender": 0,
		"total_resolved": 0,
	})

	return {
		"troop_pool_size": stats.troop_pool.size(),
		"troops_by_type": by_type,
		"fronts_as_attacker": fronts_as_atk,
		"fronts_as_defender": fronts_as_def,
		"front_markers": markers,
		"troop_maintenance_gold": stats.get_troop_maintenance_gold(),
		"troop_maintenance_food": stats.get_troop_maintenance_food(),
		"fronts_in_manager": ai.battle_front_manager.active_fronts.size() if ai.battle_front_manager else 0,
		"resolved": resolved,
	}


## Listener de `Events.battle_front_resolved`. Acumula el resultado del frente
## en `_battle_history` para AMBOS bandos (atacante y defensor). El snapshot
## de `_capture_military` lee de aqui, asi que los counters se "congelan" en
## la foto del turno y permiten reconstruir cuantos frentes gano cada imperio
## a lo largo de la partida.
func _on_battle_front_resolved(front: BattleFront, attacker_won: bool) -> void:
	if front == null:
		return
	for empire in [front.attacker_empire, front.defender_empire]:
		if empire == null:
			continue
		var key: String = empire.name
		var entry: Dictionary = _battle_history.get(key, {
			"won_as_attacker": 0,
			"won_as_defender": 0,
			"lost_as_attacker": 0,
			"lost_as_defender": 0,
			"total_resolved": 0,
		})
		var is_attacker: bool = empire == front.attacker_empire
		if is_attacker:
			if attacker_won:
				entry["won_as_attacker"] += 1
			else:
				entry["lost_as_attacker"] += 1
		else:
			if attacker_won:
				entry["lost_as_defender"] += 1
			else:
				entry["won_as_defender"] += 1
		entry["total_resolved"] += 1
		_battle_history[key] = entry


## Construye un AITurnContext mínimo (sin cartas en mano ni world_view) para
## pasar a los metodos estaticos de AIHeuristic durante la captura de snapshot.
## El RNG es desechable: ninguno de los metodos de scoring lo usa.
func _make_snapshot_ctx(ai: AIController) -> AITurnContext:
	var ctx := AITurnContext.new()
	ctx.controller = ai
	ctx.stats = ai.stats
	ctx.battle_front_manager = ai.battle_front_manager
	ctx.rng = RandomNumberGenerator.new()
	ctx.colonizable_tiles_count = _count_colonizable_tiles(ai.stats.empire)
	return ctx


## Cuenta tiles sin controller adyacentes al territorio del empire.
func _count_colonizable_tiles(empire: Empire) -> int:
	if empire == null:
		return 0
	var seen := {}
	var count := 0
	for tile in empire.controlled_tiles:
		for nb in tile.neighbors:
			if nb is Tile and (nb as Tile).controller == null and not seen.has(nb):
				seen[nb] = true
				count += 1
	return count


## Captura señales de urgencia y metricas de posicion de la heuristica IA.
func _capture_heuristic(ai: AIController) -> Dictionary:
	var stats := ai.stats
	if stats == null or stats.empire == null:
		return {}
	var phase := AIGamePhase.detect(stats)
	var ctx := _make_snapshot_ctx(ai)

	var total := WorldMap.map.size()
	var controlled := stats.empire.controlled_tiles.size()
	var dom_target := int(ceil(float(total) * 0.70))

	return {
		"phase": AIGamePhase.Phase.keys()[phase],
		"gold_urgency": AIHeuristic._gold_urgency(stats.gold_per_turn, phase),
		"food_urgency": AIHeuristic._food_urgency(stats.food, phase),
		"military_urgency": AIHeuristic._military_urgency(ctx, phase),
		"deck_urgency": AIHeuristic._deck_urgency(ctx),
		"expansion_factor": AIHeuristic._expansion_factor(ctx),
		"resource_surplus_factor": AIHeuristic._resource_surplus_factor(ctx, phase),
		"max_front_pressure": AIHeuristic._max_front_pressure(ctx),
		"buildable_slots": AIHeuristic._buildable_slots(ctx),
		"upgradeable_buildings": AIHeuristic._upgradeable_buildings(ctx),
		"colonizable_tiles": ctx.colonizable_tiles_count,
		"territory_pct": float(controlled) / float(total) if total > 0 else 0.0,
		"tiles_to_domination": maxi(0, dom_target - controlled),
	}


func _capture_modifiers(mm: ModifierManager) -> Array:
	var out := []
	if mm == null:
		return out
	for m in mm.active_modifiers:
		out.append({
			"id": m.id,
			"name": m.name,
			"duration": m.duration,
		})
	return out
