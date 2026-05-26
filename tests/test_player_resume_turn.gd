extends GutTest

## Tests para el flujo de reanudacion del turno tras cargar un save.
##
## Bug original: al cargar una partida guardada a mitad del turno del
## jugador, TurnManager.resume_turn llamaba a controller.start_turn(),
## que reincrementaba turn_number, recalculaba produccion y volvia a
## robar cartas. Con un draw_pile casi vacio (situacion comun mid-turno
## en partidas tempranas) `pop_back()` devolvia null, hand.add_card(null)
## creaba un CardUI y CardUI._set_card crasheaba con
## `Invalid access to property or key 'icon' on a base object of type 'Nil'`.
##
## La correccion introduce `EmpireController.resume_turn` (default =
## start_turn) y PlayerHandler la sobreescribe para NO repetir el inicio
## de turno; solo reactiva input emitiendo `Events.player_hand_drawn`.


# ============================================================
#  Helpers
# ============================================================

func _make_empire() -> Empire:
	var e := Empire.new()
	e.name = "TestPlayer"
	e.color = Color.BLUE
	e.controlled_tiles = []
	return e


func _make_stats() -> Stats:
	var s := Stats.new()
	s.total_gold = 50
	s.gold_per_turn = 0
	s.food = 5
	s.cards_per_turn = 2
	s.deck = CardPile.new()
	s.draw_pile = CardPile.new()
	s.discard_pile = CardPile.new()
	s.played_pile = CardPile.new()
	s.empire = _make_empire()
	s.possible_buildings = []
	s.turn_number = 1  # Simula save tomado tras start_turn del turno 1.
	s.event_chance = 0.0
	return s


## Crea un PlayerHandler minimo, sin Hand UI real (los tests de resume_turn
## no necesitan instanciar CardUI; solo verifican la logica del controller).
func _spawn_player() -> PlayerHandler:
	var ph := PlayerHandler.new()
	add_child_autofree(ph)
	return ph


# ============================================================
#  resume_turn del jugador
# ============================================================

func test_player_resume_turn_emits_player_hand_drawn() -> void:
	# resume_turn debe emitir player_hand_drawn (reactivar input) sin
	# tocar la mano ni los recursos.
	var ph := _spawn_player()
	ph.stats = _make_stats()

	var listener := _SignalListener.new()
	Events.player_hand_drawn.connect(listener.on_fired)

	ph.resume_turn()

	assert_true(listener.fired,
		"resume_turn del jugador debe emitir player_hand_drawn")

	Events.player_hand_drawn.disconnect(listener.on_fired)


func test_player_resume_turn_does_not_increment_turn_number() -> void:
	# La clave del bug: resume_turn no debe llamar a _process_turn_start.
	var ph := _spawn_player()
	var stats := _make_stats()
	stats.turn_number = 7
	ph.stats = stats

	ph.resume_turn()

	assert_eq(stats.turn_number, 7,
		"resume_turn NO debe incrementar turn_number (lo hace start_turn)")


func test_player_resume_turn_does_not_modify_total_gold() -> void:
	# _process_turn_start aplica produccion; resume_turn no debe.
	var ph := _spawn_player()
	var stats := _make_stats()
	stats.total_gold = 123
	stats.gold_per_turn = 999  # Trampa: si se reaplica, total_gold subiria 999.
	ph.stats = stats

	ph.resume_turn()

	assert_eq(stats.total_gold, 123,
		"resume_turn no debe sumar gold_per_turn a total_gold otra vez")


# ============================================================
#  EmpireController base: comportamiento por defecto
# ============================================================

func test_base_controller_resume_turn_defaults_to_start_turn() -> void:
	# Un EmpireController generico (no PlayerHandler) reanuda como
	# start_turn. Comprobamos via override.
	var ctrl := _CountingController.new()
	add_child_autofree(ctrl)

	ctrl.resume_turn()

	assert_eq(ctrl.start_turn_calls, 1,
		"EmpireController.resume_turn por defecto debe llamar a start_turn")


# ============================================================
#  Helpers internos
# ============================================================

class _SignalListener:
	var fired:bool = false

	func on_fired() -> void:
		fired = true


## Subclase minima de EmpireController para auditar el default de
## resume_turn sin tocar PlayerHandler/AIController.
class _CountingController extends EmpireController:
	var start_turn_calls:int = 0

	func start_turn() -> void:
		start_turn_calls += 1
