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

## Heuristica de asignacion v1: rellenar cada frente propio hasta este
## minimo de tropas, sacando del pool por orden. Cuando se itere sobre la
## IA real se sustituira por una politica con prioridad (frente con marker
## en mi contra > frente recien abierto > etc.).
const MIN_TROOPS_PER_FRONT: int = 3

var _rng: RandomNumberGenerator
var _drawn_cards: Array[Card] = []


func _ready() -> void:
	_init_managers()
	_rng = RandomNumberGenerator.new()
	# Escuchar retornos a la mano: si una carta nuestra "vuelve a la
	# mano" (por CardReturnModifier), la reintroducimos en drawn_cards
	# para que el bucle pueda volver a jugarla este turno.
	Events.card_returned_to_hand.connect(_on_card_returned_to_hand)


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

	# Bucle decisorio
	var ctx := AITurnContext.create(self, _rng)
	ctx.drawn_cards = _drawn_cards

	var iterations := 0
	while iterations < max_iterations and not ctx.drawn_cards.is_empty():
		var options := _enumerate_all_options(ctx)
		options.append(AIPlayOption.create_pass())

		var chosen := _pick_random_option(options)
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


func _pick_random_option(options: Array[AIPlayOption]) -> AIPlayOption:
	if options.is_empty():
		return null
	var idx := _rng.randi_range(0, options.size() - 1)
	return options[idx]


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


## Asigna tropas del pool a los frentes propios sin suficientes refuerzos.
##
## Heuristica v1 (placeholder, no inteligente):
##   - Recorre TODOS los frentes activos del registro global, no solo los
##     del manager propio. Los frentes solo se almacenan en el manager del
##     atacante; sin esta visibilidad global, el defensor nunca recibe
##     refuerzos en sus tiles bajo ataque y pierde el frente por inanicion.
##   - Para cada frente donde este imperio participa (atacante O defensor),
##     saca tropas del pool hasta llegar a `MIN_TROOPS_PER_FRONT` o agotar
##     el pool.
##   - Sin priorizacion, sin balance entre frentes, sin tener en cuenta la
##     composicion enemiga ni el marker. Esta intencionalmente simple para
##     que el sistema de combate empiece a producir datos; la heuristica
##     se sustituira cuando se aborde la IA militar de verdad.
##
## Pre: este metodo solo lo llama el AIController; un Player no pasa por
## aqui (el jugador asigna manualmente via BattleFrontPanel).
func _assign_troops_to_fronts() -> void:
	if battle_front_manager == null:
		return
	if stats == null or stats.troop_pool.is_empty():
		return

	for front in BattleFront.get_active_instances():
		if front == null or front.is_resolved:
			continue
		var side: StringName
		var current_count: int
		if front.attacker_empire == stats.empire:
			side = &"attacker"
			current_count = front.attacker_troops.size()
		elif front.defender_empire == stats.empire:
			side = &"defender"
			current_count = front.defender_troops.size()
		else:
			continue

		while current_count < MIN_TROOPS_PER_FRONT and not stats.troop_pool.is_empty():
			var troop: Troop = stats.troop_pool[0]
			var assigned := battle_front_manager.assign_troop_to_front(front, troop, side)
			if not assigned:
				# Si el manager rechaza (p.ej. frente ya resuelto entre
				# iteraciones), salimos del while para no bucle infinito.
				break
			current_count += 1

		if stats.troop_pool.is_empty():
			return
