extends Node
class_name TurnManager

## Orquesta el ciclo de turnos entre todos los controladores de imperio.
## El primer controlador siempre es el jugador. Los demas son IAs.
## Ciclo: jugador -> IA1 -> IA2 -> ... -> jugador -> ...

signal round_started(round_number:int)
signal round_ended(round_number:int)

var controllers:Array[EmpireController] = []
var current_index:int = -1
var round_number:int = 0

func register_controller(controller:EmpireController) -> void:
	controllers.append(controller)
	controller.turn_finished.connect(_on_controller_turn_finished)

func start_first_round() -> void:
	round_number = 1
	current_index = 0
	print("[TurnManager] === RONDA %d ===" % round_number)
	round_started.emit(round_number)
	_start_current_controller_turn()

## Llamado cuando el jugador pulsa "Fin de turno"
func on_player_turn_ended() -> void:
	if current_index != 0:
		push_warning("[TurnManager] on_player_turn_ended llamado fuera del turno del jugador")
		return
	# Iniciar fin de turno del jugador (descarte + eventos)
	var player := controllers[0] as PlayerHandler
	player.end_turn()

## Llamado cuando el jugador termina de descartar
func on_player_hand_discarded() -> void:
	if current_index != 0:
		return
	var player := controllers[0] as PlayerHandler
	player.evaluate_end_of_turn()

func _on_controller_turn_finished(_controller:EmpireController) -> void:
	_advance_to_next()

func _advance_to_next() -> void:
	current_index += 1

	if current_index >= controllers.size():
		# Todos han jugado -> nueva ronda
		print("[TurnManager] === FIN RONDA %d ===" % round_number)
		round_ended.emit(round_number)
		round_number += 1
		current_index = 0
		print("[TurnManager] === RONDA %d ===" % round_number)
		round_started.emit(round_number)

	_start_current_controller_turn()

func _start_current_controller_turn() -> void:
	var controller := controllers[current_index]
	var empire_name := controller.stats.empire.name if controller.stats and controller.stats.empire else "???"
	print("[TurnManager] Turno de: %s (indice %d)" % [empire_name, current_index])
	controller.start_turn()
