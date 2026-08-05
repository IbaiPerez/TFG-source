extends EmpireController
class_name AIController

## Controlador de IA para imperios no-jugador. ORQUESTA el turno; no decide.
##
## QUÉ jugada se elige (MCTS / heurística / random) vive en [AIDecisionPolicy], y
## el reparto de tropas a los frentes en [AIFrontAssignment]. Aquí queda el ciclo
## del turno: robar, iterar decisiones, esperar los delays de presentación,
## descartar y cerrar.
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
## Alias público (lo leen los tests) de la constante de TroopAssignmentPolicy.
const MIN_TROOPS_PER_FRONT: int = TroopAssignmentPolicy.MIN_TROOPS_PER_FRONT

var _rng: RandomNumberGenerator
var _drawn_cards: Array[Card] = []
## Observer de cartas del rival. null hasta que turn_manager tiene un rival disponible.
## Se inicializa lazy en el primer turno con rival. Persiste entre turnos.
var _deck_observer: AIDeckObserver = null

## Politica de decision (MCTS / heuristica / random). Guarda el subarbol
## conservado entre decisiones del turno y los contadores de diagnostico.
var decision_policy: AIDecisionPolicy



func _ready() -> void:
	_init_managers()
	_rng = RandomNumberGenerator.new()
	decision_policy = AIDecisionPolicy.new(_rng)
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
## Fases del turno. `_run_decision_loop` y `_end_turn` contienen
## `await`, así que son corrutinas y DEBEN esperarse: llamarlas sin `await` las
## dejaría corriendo en paralelo y rompería el orden del turno.
func _run_turn() -> void:
	var empire_name := stats.empire.name if stats.empire else "IA"
	_begin_turn(empire_name)
	_draw_hand(empire_name)
	var ctx := _build_turn_context()
	await _run_decision_loop(ctx, empire_name)
	_discard_leftovers(ctx, empire_name)
	await _end_turn(empire_name)


## Arranque: señal de inicio, producción/modificadores, tick de frentes y primera
## asignación de tropas.
func _begin_turn(empire_name: String) -> void:
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


## Roba la mano del turno y deja lista la observación del mazo rival.
func _draw_hand(empire_name: String) -> void:
	_drawn_cards = []
	var amount := _get_effective_cards_per_turn()
	for i in range(amount):
		var c := _draw_single_card()
		if c != null:
			_drawn_cards.append(c)
	GameLogger.debug("[IA] %s robó %d cartas" % [empire_name, _drawn_cards.size()])

	# Inicializar el observer de cartas del rival en cuanto tengamos un rival.
	_ensure_observer_ready()


## Contexto de decisión del turno (mano, vista del mundo, pesos, datos del mapa).
func _build_turn_context() -> AITurnContext:
	var ctx := AITurnContext.create(self, _rng)
	ctx.drawn_cards = _drawn_cards
	ctx.world_view = _build_world_view()
	ctx.deck_observer = _deck_observer
	ctx.config = ai_config
	ctx.weights = ai_config.heuristic_weights if ai_config != null else null
	var _adj_cond := AdjacentRule.new()
	_adj_cond.empire = stats.empire
	ctx.colonizable_tiles_count = _adj_cond.valid_targets().size()
	# Índice Tile→id construido UNA vez por turno: sustituye los
	# `WorldMap.map.find()` O(n) que se hacían por jugada al mapear las del MCTS.
	# El constructor lo comparte AIRealState: los ids DEBEN coincidir con los del
	# snapshot, porque las jugadas del MCTS se casan con las opciones por ese id.
	var world: Array = WorldMap.map
	ctx.total_map_tiles = world.size()
	ctx.tile_index = AIRealState.build_tile_index(world)

	# Nuevo turno: el árbol de turnos anteriores ya no es válido (intervinieron
	# el rival y advance_turn). La reutilización de subárbol es SOLO intra-turno.
	decision_policy.reset_tree()
	return ctx


## Bucle decisorio: la única parte con lógica real del turno. Enumera opciones,
## elige una y la ejecuta, hasta pasar o quedarse sin cartas.
func _run_decision_loop(ctx: AITurnContext, empire_name: String) -> void:
	var iterations := 0
	while iterations < max_iterations and not ctx.drawn_cards.is_empty():
		var options := decision_policy.enumerate_all_options(ctx)
		options.append(AIPlayOption.create_pass())

		# Preparar caché de urgencias una sola vez para todo este ciclo de scoring.
		# Se invalida tras ejecutar la opción porque el estado del mundo cambia.
		AIDecisionCache.prepare_decision_cache(ctx)
		var chosen := decision_policy.pick_best(options, ctx)
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


## Las cartas que no se jugaron van al descarte.
func _discard_leftovers(ctx: AITurnContext, empire_name: String) -> void:
	for leftover in ctx.drawn_cards:
		stats.discard_pile.add_card(leftover)
	if not ctx.drawn_cards.is_empty():
		GameLogger.debug("[IA] %s descarta %d cartas no jugadas" % [empire_name, ctx.drawn_cards.size()])
	ctx.drawn_cards = []
	_drawn_cards = []


## Cierre: segunda asignación de tropas, evento de turno y fin.
func _end_turn(empire_name: String) -> void:
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
	AIEventResolver.resolve(event, context, _rng, turn_event_manager,
			ai_config.heuristic_weights if ai_config != null else null)


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


## Reparto de tropas del pool a los frentes propios. El algoritmo vive en
## AIFrontAssignment (y su politica compartida con el simulador del MCTS).
func _assign_troops_to_fronts() -> void:
	AIFrontAssignment.assign(battle_front_manager, stats)
