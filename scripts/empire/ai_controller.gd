extends EmpireController
class_name AIController

## Controlador de IA para imperios no-jugador.
##
## Versión 1: decide aleatoriamente entre todas las jugadas legales que
## puede tomar este turno (incluyendo la opción "no jugar nada"). El
## propósito es validar el flujo completo (efectos, fin de turno, eventos
## futuros) antes de meter heurísticas reales.
##
## Bucle por turno:
##   1. _process_turn_start() — producción y modificadores.
##   2. _process_battle_fronts() — tickeo de frentes (si tiene).
##   3. Robar `_get_effective_cards_per_turn()` cartas → drawn_cards.
##   4. Mientras haya cartas y no se haya superado MAX_ITER:
##        a. Enumerar opciones de cada carta vía AIOptionsBuilder + PASS.
##        b. Elegir una al azar con _rng.
##        c. Si es PASS, salir del bucle.
##        d. Ejecutar la opción, eliminar la carta jugada de drawn_cards,
##           pasar la carta por _handle_card_played.
##        e. Esperar action_delay para dar tiempo al jugador.
##   5. Descartar las cartas restantes.
##   6. Esperar turn_end_delay y emitir turn_finished.
##
## Decisiones de diseño:
##  - Re-enumerar tras cada jugada (jugar gasta oro y cambia opciones).
##  - RNG con seed inyectable → tests deterministas.
##  - MAX_ITER duro evita cuelgues por bugs en el builder.
##  - SÍ emite Events.card_played(card, stats) vía card.play(). El bus
##    está refactorizado para filtrar por owner_stats: PlayerHandler/Hand
##    ignoran las cartas IA y los modifiers/buildings de la IA reaccionan
##    correctamente a sus propias cartas.
##  - Escucha Events.card_returned_to_hand con filtro: si la carta es
##    suya, la reintroduce en _drawn_cards para que la pueda volver a
##    jugar en una iteración siguiente del bucle.

@export var max_iterations: int = 20
@export var action_delay: float = 0.9    ## Segundos entre jugadas
@export var turn_end_delay: float = 0.5  ## Segundos antes de cerrar el turno
@export var rng_seed: int = -1           ## -1 → seed aleatorio cada turno
## Configuración del algoritmo de decisión. Asignar un .tres de resources/ai/
## para cambiar entre heurística, MCTS aleatorio y MCTS con heurística.
## null → crea un AIConfig por defecto (mode=MCTS) en _ready().
@export var ai_config: AIConfig

## Referencia al TurnManager para construir AIWorldView en cada turno.
## Lo inyecta map.gd tras registrar el controller. null en tests unitarios,
## donde AIWorldView se construye solo con las stats propias (sin rivales).
var turn_manager: TurnManager

## Mínimo de tropas por frente que la heurística garantiza en la primera pasada.
## La segunda pasada puede añadir hasta +2 en frentes donde se pierde.
const MIN_TROOPS_PER_FRONT: int = 3

var _rng: RandomNumberGenerator
var _drawn_cards: Array[Card] = []
## Observer de cartas del rival. null hasta que turn_manager tiene un rival disponible.
## Se inicializa lazy en el primer turno con rival. Persiste entre turnos.
var _deck_observer: AIDeckObserver = null

## Diagnóstico MCTS (acumulado durante la partida): nº de decisiones tomadas con
## MCTS y de cuántas la búsqueda se apartó del prior heurístico (overrode_prior).
## El harness de simulación los lee al final para medir la tasa de "override".
var mcts_decisions: int = 0
var mcts_prior_overrides: int = 0


func _ready() -> void:
	_init_managers()
	_rng = RandomNumberGenerator.new()
	if ai_config == null:
		ai_config = AIConfig.new()
	Events.card_returned_to_hand.connect(_on_card_returned_to_hand)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _deck_observer != null:
		_deck_observer.cleanup()
		_deck_observer = null


func _on_card_returned_to_hand(card: Card, owner_stats: Stats) -> void:
	if owner_stats != stats:
		return
	# `_drawn_cards` y `ctx.drawn_cards` apuntan al mismo Array (referencia).
	_drawn_cards.append(card)


func start_game(new_stats: Stats) -> void:
	super.start_game(new_stats)


func start_turn() -> void:
	await _run_turn()


## Implementación async del turno. La emitimos como coroutine porque hay
## awaits intercalados (action_delay, turn_end_delay). El TurnManager
## llama start_turn() sin await — esto está bien porque emitimos
## turn_finished al acabar.
func _run_turn() -> void:
	var empire_name := stats.empire.name if stats.empire else "IA"
	GameLogger.debug("[IA] === TURNO DE %s (turno %d) ===" % [empire_name, stats.turn_number + 1])

	# Señal de inicio para la capa de presentación (log, banner, etc.).
	Events.ai_turn_started.emit(self)

	_seed_rng_for_turn()
	_process_turn_start()
	_process_battle_fronts()
	# Asignacion de tropas a frentes propios. Va aqui, despues del tick
	# pero antes de robar/jugar cartas, para que las tropas reclutadas
	# este mismo turno (al jugar Recruit) no se asignen hasta el siguiente.
	# Asi separamos limpiamente "consecuencia del turno previo" (asignar)
	# de "decisiones de este turno" (reclutar / abrir frente / tacticas).
	_assign_troops_to_fronts()

	GameLogger.debug("[IA] Oro: %d (+%d/turno) | Comida: %d | Tiles: %d" % [
		stats.total_gold, stats.gold_per_turn, stats.food,
		stats.empire.controlled_tiles.size()
	])

	# Robar mano
	_drawn_cards = []
	var amount := _get_effective_cards_per_turn()
	for i in range(amount):
		var c := _draw_single_card()
		if c != null:
			_drawn_cards.append(c)
	GameLogger.debug("[IA] %s robó %d cartas" % [empire_name, _drawn_cards.size()])

	# Inicializar el observer de cartas del rival en cuanto tengamos un rival.
	_ensure_observer_ready()

	# Bucle decisorio
	var ctx := AITurnContext.create(self, _rng)
	ctx.drawn_cards = _drawn_cards
	ctx.world_view = _build_world_view()
	ctx.deck_observer = _deck_observer
	ctx.config = ai_config
	var _adj_cond := AdjacentCondition.new()
	_adj_cond.empire = stats.empire
	ctx.colonizable_tiles_count = _adj_cond.valid_targets().size()
	ctx.total_map_tiles = WorldMap.map.size()

	var iterations := 0
	while iterations < max_iterations and not ctx.drawn_cards.is_empty():
		var options := _enumerate_all_options(ctx)
		options.append(AIPlayOption.create_pass())

		# Preparar caché de urgencias una sola vez para todo este ciclo de scoring.
		# Se invalida tras ejecutar la opción porque el estado del mundo cambia.
		AIHeuristic.prepare_decision_cache(ctx)
		var chosen := _pick_best_option(options, ctx)
		ctx.invalidate_decision_cache()

		if chosen == null or chosen.is_pass:
			GameLogger.debug("[IA] %s decide pasar (iter %d)" % [empire_name, iterations])
			break

		GameLogger.debug("[IA] %s juega %s" % [empire_name, chosen.describe()])
		var played_card := chosen.execute(ctx)
		if played_card != null:
			ctx.drawn_cards.erase(played_card)
			_handle_card_played(played_card)
			# Notificar a la capa de presentación. anchor_tile puede ser null
			# (SELF cards sin tile concreta) — el consumidor decide qué hacer.
			Events.ai_card_played.emit(
				played_card, chosen.anchor_tile(), stats.empire, chosen.payload)

		iterations += 1
		await _wait(action_delay)

	# Descartar las cartas no jugadas
	for leftover in ctx.drawn_cards:
		stats.discard_pile.add_card(leftover)
	if not ctx.drawn_cards.is_empty():
		GameLogger.debug("[IA] %s descarta %d cartas no jugadas" % [empire_name, ctx.drawn_cards.size()])
	ctx.drawn_cards = []
	_drawn_cards = []

	# Segunda pasada de asignacion: cubre tropas reclutadas en este mismo
	# turno (al jugar Recruit) y frentes abiertos en este mismo turno (al
	# jugar Open Front). Sin esta segunda pasada los frentes recien creados
	# nacen vacios y el defensor no tiene oportunidad de reaccionar antes
	# del primer tick. Como la asignacion respeta MIN_TROOPS_PER_FRONT,
	# llamarla dos veces es idempotente para los frentes ya satisfechos.
	_assign_troops_to_fronts()

	# Evaluar y resolver evento de turno (Fase 4).
	# Reemplaza el flujo del jugador (que abre un panel) por resolución
	# headless: no se emite Events.turn_event_triggered, así que ningún
	# panel UI se abre. El resolver replica la lógica del panel sin UI.
	_evaluate_and_resolve_event(empire_name)

	await _wait(turn_end_delay)
	Events.ai_turn_ended.emit(self)
	_finish_turn()


## Evalúa si dispara un evento este turno y lo resuelve headless.
## Igual que en el flujo del jugador, usa el turn_event_manager para
## consultar candidatos. La diferencia: el resolver IA no abre paneles.
func _evaluate_and_resolve_event(empire_name: String) -> void:
	var context := EventContext.build(stats, modifier_manager,
			stats.turn_number, battle_front_manager)
	var event: TurnEvent = turn_event_manager.evaluate(context)
	if event == null:
		return
	GameLogger.debug("[IA] %s recibe evento: %s" % [empire_name, event.title])
	AIEventResolver.resolve(event, context, _rng, turn_event_manager)


func end_turn() -> void:
	# La IA gestiona su turno internamente; no se llama desde fuera.
	pass


## Hook heredado de EmpireController por compatibilidad. La IA resuelve
## sus eventos síncronamente vía AIEventResolver dentro de _run_turn(),
## así que este callback no se utiliza activamente.
func _on_turn_event_resolved() -> void:
	pass


# --- Helpers --------------------------------------------------------------

func _seed_rng_for_turn() -> void:
	if rng_seed >= 0:
		# Seed estable derivado del seed base + turno → cada turno es
		# determinista pero distinto del anterior con el mismo seed base.
		_rng.seed = rng_seed + stats.turn_number
	else:
		_rng.randomize()


func _enumerate_all_options(ctx: AITurnContext) -> Array[AIPlayOption]:
	var all: Array[AIPlayOption] = []
	for card in ctx.drawn_cards:
		all.append_array(AIOptionsBuilder.build_options(card, ctx))
	return all


func _pick_best_option(options: Array[AIPlayOption], ctx: AITurnContext) -> AIPlayOption:
	if options.is_empty():
		return null
	var cfg := ctx.config
	if cfg != null and cfg.mode == AIConfig.Mode.MCTS:
		var picked := _pick_best_option_mcts(options, ctx, cfg)
		# Si MCTS no devuelve jugada (sin acciones modelables), caemos a heurística.
		if picked != null:
			return picked
	return _pick_best_option_heuristic(options, ctx)


## Decisión por MCTS v2 (Fase C v2 — SO-ISMCTS sobre estado real). Construye el
## snapshot rico desde el contexto, busca con AIRealMCTS, y mapea la jugada
## elegida (snapshot) a la AIPlayOption real ejecutable. Devuelve:
##   - la AIPlayOption mapeada,
##   - una PASS si la búsqueda decidió pasar (cierra el turno),
##   - null si la búsqueda degeneró o la jugada no tiene opción real
##     correspondiente → el llamante cae a la heurística.
func _pick_best_option_mcts(options: Array[AIPlayOption], ctx: AITurnContext,
		cfg: AIConfig) -> AIPlayOption:
	var state := AIRealState.from_context(ctx)

	# Determinización del rival (SO-ISMCTS): deck conocido + tamaño de mano.
	var known_deck: Array[Card] = []
	var rival_hand_size := 2
	if ctx.world_view != null:
		var rival_view := ctx.world_view.get_rival_view()
		if rival_view != null:
			known_deck = AIDeterminizer.build_known_deck(rival_view, ctx.deck_observer)
			rival_hand_size = rival_view.hand_size

	# Prior HÍBRIDO de la raíz: puntuamos las jugadas reales con la heurística
	# REAL (score_option sobre el ctx real, con la caché ya preparada) y las
	# indexamos por move_key para que la raíz del MCTS use la heurística fuerte
	# como prior/poda, no la aproximación score_move.
	var root_priors := {}
	for m in AIRealOptions.enumerate(state, ctx.drawn_cards, AIRealState.OWNER_SELF):
		var opt := _map_move_to_option(m, options)
		if opt != null:
			root_priors[AIRealMCTSNode.move_key(m)] = AIHeuristic.score_option(opt, ctx)

	var result := AIRealMCTS.search(state, ctx.drawn_cards, known_deck,
		rival_hand_size, cfg, _rng, root_priors)
	# Diagnóstico: contar decisiones y cuántas se apartan del prior heurístico.
	mcts_decisions += 1
	if result.overrode_prior:
		mcts_prior_overrides += 1
	if result.best_move == null:
		return null   # búsqueda degenerada → heurística
	if result.chose_pass:
		return AIPlayOption.create_pass()

	var picked := _map_move_to_option(result.best_move, options)
	if picked == null:
		return null   # jugada sin opción real correspondiente → heurística
	GameLogger.debug("[IA] MCTS-v2: %d iters · raíz %d/%d · Q=%.3f → %s" % [
		result.iterations, result.root_visits, result.root_children,
		result.best_avg_value, picked.describe()])
	return picked


## Mapea una jugada del snapshot (AIRealOptions.Move) a la AIPlayOption real
## equivalente entre las opciones legales del turno, casando por carta + target
## (índice de tile en WorldMap.map, igual que AIRealState.from_context). Devuelve
## null si ninguna casa (el llamante cae a la heurística).
func _map_move_to_option(m: AIRealOptions.Move,
		options: Array[AIPlayOption]) -> AIPlayOption:
	# Frentes activos en el mismo orden que from_context (para casar TACTIC).
	var active_fronts: Array = []
	for f in BattleFront.get_active_instances():
		if f != null and not f.is_resolved:
			active_fronts.append(f)

	for opt in options:
		if opt == null or opt.is_pass or opt.card != m.card:
			continue
		match m.kind:
			&"COLONIZE", &"CHANGE_LOCATION":
				if _tile_index(opt.anchor_tile()) == m.tile_id:
					return opt
			&"GENERATE_GOLD", &"CARD_DRAW":
				return opt   # sin target: basta la identidad de carta
			&"BUILD", &"DIRECT_BUILD":
				var bo := opt as AIBuildOption
				if bo != null and bo.building == m.building \
						and _tile_index(opt.anchor_tile()) == m.tile_id:
					return opt
			&"UPGRADE":
				var uo := opt as AIUpgradeBuildingOption
				if uo != null and uo.old_building == m.old_building \
						and uo.new_building == m.new_building \
						and _tile_index(opt.anchor_tile()) == m.tile_id:
					return opt
			&"RECRUIT":
				var ro := opt as AIRecruitOption
				if ro != null and ro.troop == m.troop:
					return opt
			&"OPEN_FRONT":
				var ofo := opt as AIOpenFrontOption
				if ofo != null and _tile_index(ofo.enemy_tile) == m.def_tile_id \
						and _tile_index(ofo.source_tile) == m.tile_id:
					return opt
			&"TACTIC":
				var to := opt as AITacticOption
				if to != null and m.front_idx >= 0 and m.front_idx < active_fronts.size() \
						and to.front == active_fronts[m.front_idx]:
					return opt
	return null


## Índice de una tile en WorldMap.map (mismo id que usa AIRealState.from_context).
func _tile_index(tile: Tile) -> int:
	if tile == null:
		return -1
	return WorldMap.map.find(tile)


## Decisión por heurística pura (Fase B). También es el fallback de MCTS.
func _pick_best_option_heuristic(options: Array[AIPlayOption],
		ctx: AITurnContext) -> AIPlayOption:
	var best: AIPlayOption = null
	var best_score := -INF
	for option in options:
		var s := AIHeuristic.score_option(option, ctx)
		if s > best_score:
			best_score = s
			best = option
	return best


## Espera asíncrona configurable. Si delay <= 0 retorna inmediatamente
## (clave para tests deterministas sin esperar tiempo real).
func _wait(delay: float) -> void:
	if delay <= 0.0:
		return
	await get_tree().create_timer(delay).timeout


func _finish_turn() -> void:
	var empire_name := stats.empire.name if stats.empire else "IA"
	GameLogger.debug("[IA] === FIN TURNO DE %s ===" % empire_name)
	turn_finished.emit(self)


## Inicializa _deck_observer la primera vez que hay un rival disponible.
## Idempotente: no hace nada si ya está inicializado o si no hay rival aún.
func _ensure_observer_ready() -> void:
	if _deck_observer != null or turn_manager == null:
		return
	for ctrl in turn_manager.controllers:
		if ctrl.stats == null or ctrl.stats == stats:
			continue
		_deck_observer = AIDeckObserver.new()
		var starting: Array[Card] = []
		if ctrl.stats.starting_deck != null:
			starting = ctrl.stats.starting_deck.cards
		_deck_observer.init(ctrl.stats, starting)
		return


## Construye el AIWorldView para este turno usando los controllers registrados
## en el TurnManager. Si turn_manager es null (tests unitarios sin escena
## completa), devuelve una vista con solo las propias stats y sin rivales.
func _build_world_view() -> AIWorldView:
	var all: Array[EmpireController] = []
	if turn_manager != null:
		all = turn_manager.controllers
	return AIWorldView.build(stats, all)


## Asigna tropas del pool a los frentes propios con prioridad por urgencia.
##
## Heurística v2:
##   1. Calcula urgency_score para cada frente (posición del marker vs umbral).
##      Frentes sin tropas reciben urgencia × 2: sin resistencia el marker cae libre.
##   2. Ordena frentes por urgencia DESC.
##   3. Primera pasada: llenar hasta MIN_TROOPS_PER_FRONT empezando por el más urgente.
##      Tropa elegida: defensor → max defense; atacante → max attack.
##   4. Segunda pasada: reforzar hasta MIN + 2 los frentes donde se pierde
##      activamente (base_urgency > 1.5, es decir, marker negativo).
##
## Pre: solo lo llama AIController; el jugador asigna via BattleFrontPanel.
func _assign_troops_to_fronts() -> void:
	if battle_front_manager == null:
		return
	if stats == null or stats.troop_pool.is_empty():
		return

	# Recopilar frentes donde participamos con urgencia calculada
	var entries: Array = []
	for front in BattleFront.get_active_instances():
		if front == null or front.is_resolved:
			continue
		var side: StringName
		if front.attacker_empire == stats.empire:
			side = &"attacker"
		elif front.defender_empire == stats.empire:
			side = &"defender"
		else:
			continue
		var base_urg := _front_base_urgency(front, side)
		var cur_troops := front.attacker_troops if side == &"attacker" else front.defender_troops
		var full_urg := base_urg * (2.0 if cur_troops.is_empty() else 1.0)
		entries.append({ "front": front, "side": side, "base_urgency": base_urg, "urgency": full_urg })

	if entries.is_empty():
		return

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.urgency > b.urgency)

	# Primera pasada: llenar hasta MIN_TROOPS_PER_FRONT
	for entry in entries:
		if stats.troop_pool.is_empty():
			return
		var front: BattleFront = entry.front
		var side: StringName = entry.side
		var troops := front.attacker_troops if side == &"attacker" else front.defender_troops
		while troops.size() < MIN_TROOPS_PER_FRONT and not stats.troop_pool.is_empty():
			if not _assign_best_troop(front, side):
				break

	# Segunda pasada: reforzar frentes donde se pierde activamente
	for entry in entries:
		if stats.troop_pool.is_empty():
			return
		if entry.base_urgency <= 1.5:
			continue
		var front: BattleFront = entry.front
		var side: StringName = entry.side
		var troops := front.attacker_troops if side == &"attacker" else front.defender_troops
		while troops.size() < MIN_TROOPS_PER_FRONT + 2 and not stats.troop_pool.is_empty():
			if not _assign_best_troop(front, side):
				break


## Urgencia base del frente para nuestro bando, sin multiplicador por troop_count.
## 3.0 = perdiendo gravemente | 2.0 = perdiendo | 1.5 = equilibrio
## 0.8 = ganando              | 0.3 = casi resuelto
func _front_base_urgency(front: BattleFront, side: StringName) -> float:
	var ai_marker := front.marker if side == &"attacker" else -front.marker
	var thr := front.get_current_threshold()
	if ai_marker < -thr * 0.5: return 3.0
	if ai_marker < 0.0:         return 2.0
	if ai_marker < thr * 0.4:   return 1.5
	if ai_marker < thr * 0.7:   return 0.8
	return 0.3


## Elige la mejor tropa del pool para el rol dado y la asigna al frente.
## Defensor → max defense; Atacante → max attack.
func _assign_best_troop(front: BattleFront, side: StringName) -> bool:
	if stats.troop_pool.is_empty():
		return false
	var sorted_pool := stats.troop_pool.duplicate()
	if side == &"defender":
		sorted_pool.sort_custom(func(a: Troop, b: Troop) -> bool: return a.defense > b.defense)
	else:
		sorted_pool.sort_custom(func(a: Troop, b: Troop) -> bool: return a.attack > b.attack)
	return battle_front_manager.assign_troop_to_front(front, sorted_pool[0], side)
