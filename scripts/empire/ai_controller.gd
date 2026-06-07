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

## Referencia al TurnManager para construir AIWorldView en cada turno.
## Lo inyecta map.gd tras registrar el controller. null en tests unitarios,
## donde AIWorldView se construye solo con las stats propias (sin rivales).
var turn_manager: TurnManager

## Mínimo de tropas por frente que la heurística garantiza en la primera pasada.
## La segunda pasada puede añadir hasta +2 en frentes donde se pierde.
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
	ctx.world_view = _build_world_view()
	var _adj_cond := AdjacentCondition.new()
	_adj_cond.empire = stats.empire
	ctx.colonizable_tiles_count = _adj_cond.valid_targets().size()

	var iterations := 0
	while iterations < max_iterations and not ctx.drawn_cards.is_empty():
		var options := _enumerate_all_options(ctx)
		options.append(AIPlayOption.create_pass())

		var chosen := _pick_best_option(options, ctx)
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
