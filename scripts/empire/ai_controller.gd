extends EmpireController
class_name AIController

## Stub de controlador de IA. De momento solo imprime mensajes de debug
## para verificar que el flujo de turnos funciona correctamente.
## En el futuro, aqui se conectara el modulo de IA real.

const AI_TURN_DELAY := 0.5  ## Delay simulado para el turno de la IA

func _ready() -> void:
	_init_managers()

func start_game(new_stats:Stats) -> void:
	super.start_game(new_stats)

func start_turn() -> void:
	var empire_name := stats.empire.name if stats.empire else "IA Desconocida"
	print("[IA] === TURNO DE %s ===" % empire_name)
	print("[IA] Turno numero: %d" % (stats.turn_number + 1))

	_process_turn_start()

	print("[IA] Oro total: %d | Oro/turno: %d | Comida: %d" % [stats.total_gold, stats.gold_per_turn, stats.food])
	print("[IA] Tiles controlados: %d" % stats.empire.controlled_tiles.size())
	print("[IA] Cartas en mazo: %d" % stats.draw_pile.cards.size())

	# Robar cartas (sin animacion)
	var effective_cards := _get_effective_cards_per_turn()
	var drawn_cards:Array[Card] = []
	for i in range(effective_cards):
		var card := _draw_single_card()
		drawn_cards.append(card)
	print("[IA] Cartas robadas: %d" % drawn_cards.size())

	# --- Aqui ira la logica de IA en el futuro ---
	# Por ahora, descarta todas las cartas sin jugar ninguna
	for card in drawn_cards:
		stats.discard_pile.add_card(card)
	print("[IA] (Sin logica de IA, descartando todas las cartas)")

	# Simular un pequeño delay antes de terminar
	print("[IA] Finalizando turno de %s..." % empire_name)
	var timer := get_tree().create_timer(AI_TURN_DELAY)
	timer.timeout.connect(_finish_turn)

func _finish_turn() -> void:
	var empire_name := stats.empire.name if stats.empire else "IA Desconocida"
	# TODO: Evaluar eventos de fin de turno para la IA cuando se implemente
	# el sistema de eventos generico. Por ahora se salta la evaluacion.
	print("[IA] === FIN TURNO DE %s ===" % empire_name)
	turn_finished.emit(self)

func _on_turn_event_resolved() -> void:
	# Reservado para cuando la IA gestione sus propios eventos
	var empire_name := stats.empire.name if stats.empire else "IA Desconocida"
	print("[IA] === FIN TURNO DE %s (post-evento) ===" % empire_name)
	turn_finished.emit(self)

func end_turn() -> void:
	# La IA no necesita end_turn externo; gestiona su turno internamente
	pass
