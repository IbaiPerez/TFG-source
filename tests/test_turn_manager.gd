extends GutTest

## Rotación de turnos de `TurnManager`: quién empieza, quién sigue, cuándo cambia
## la ronda, y qué pasa cuando alguien gana. No lo cubría ningún test: el arnés
## de simulación no pasa por aquí (llama a `start_turn()` de cada IA a pelo), y
## el único test existente (`test_player_resume_turn`) mira `resume_turn`.
##
## Los controladores son STUBS de `EmpireController` (clase abstracta: su
## `start_turn` es `pass`). Registran las llamadas y terminan el turno cuando el
## test lo pide, que es exactamente el contrato que TurnManager consume.


class StubController extends EmpireController:
	var starts := 0
	var resumes := 0

	func start_turn() -> void:
		starts += 1

	func resume_turn() -> void:
		resumes += 1

	func finish() -> void:
		turn_finished.emit(self)


class GameOverListener extends RefCounted:
	var winner: Empire = null
	var count := 0

	func on_game_over(w: Empire) -> void:
		winner = w
		count += 1


var _tm: TurnManager
var _a: StubController
var _b: StubController
var _listener: GameOverListener


func before_each() -> void:
	TestWorld.reset()
	_tm = TurnManager.new()
	add_child_autofree(_tm)
	_a = _controller("A", 1)
	_b = _controller("B", 1)
	_tm.register_controller(_a)
	_tm.register_controller(_b)
	_listener = GameOverListener.new()
	Events.game_over.connect(_listener.on_game_over)
	watch_signals(_tm)


func after_each() -> void:
	Events.game_over.disconnect(_listener.on_game_over)
	TestWorld.reset()


func _controller(name: String, n_tiles: int) -> StubController:
	var c := StubController.new()
	add_child_autofree(c)
	c.stats = _stats(name, n_tiles)
	return c


func _stats(name: String, n_tiles: int) -> Stats:
	var tiles: Array = []
	for _i in range(n_tiles):
		var t := TestBuilders.tile().build()
		add_child_autofree(t)
		tiles.append(t)
	return TestBuilders.stats().with_tiles(tiles) \
		.with_empire(TestBuilders.empire().with_name(name).build()).build()


## Mapa de `total` casillas en WorldMap, que es de donde la regla lee el total.
func _world_of(total: int) -> void:
	var tiles: Array[Tile] = []
	for _i in range(total):
		var t := TestBuilders.tile().build()
		add_child_autofree(t)
		tiles.append(t)
	WorldMap.map = tiles


# ============================================================
#  Arranque y rotación
# ============================================================

func test_la_primera_ronda_empieza_por_el_primer_controlador() -> void:
	_tm.start_first_round()
	assert_eq(_tm.round_number, 1)
	assert_eq(_tm.current_index, 0)
	assert_eq(_a.starts, 1, "el primero juega")
	assert_eq(_b.starts, 0, "el segundo espera")
	assert_signal_emitted_with_parameters(_tm, "round_started", [1])


func test_al_terminar_el_primero_juega_el_segundo() -> void:
	_tm.start_first_round()
	_a.finish()
	assert_eq(_tm.current_index, 1)
	assert_eq(_b.starts, 1)
	assert_eq(_tm.round_number, 1, "sigue la misma ronda")
	assert_signal_not_emitted(_tm, "round_ended")


func test_al_terminar_el_ultimo_empieza_otra_ronda_por_el_primero() -> void:
	_tm.start_first_round()
	_a.finish()
	_b.finish()
	assert_signal_emitted_with_parameters(_tm, "round_ended", [1])
	assert_eq(_tm.round_number, 2)
	assert_eq(_tm.current_index, 0)
	assert_eq(_a.starts, 2, "el primero vuelve a jugar")
	assert_eq(_b.starts, 1)
	assert_signal_emit_count(_tm, "round_started", 2)


func test_varias_rondas_alternan_estrictamente() -> void:
	_tm.start_first_round()
	for _r in range(3):
		_a.finish()
		_b.finish()
	assert_eq(_tm.round_number, 4)
	assert_eq(_a.starts, 4)
	assert_eq(_b.starts, 3)
	assert_eq(_listener.count, 0, "nadie gana con 1 casilla cada uno")


# ============================================================
#  Victoria: se comprueba al cerrar la ronda, con la regla de VictoryRules
# ============================================================

func test_la_victoria_se_evalua_solo_al_cerrar_la_ronda() -> void:
	_world_of(10)
	_a.stats = _stats("A", 0)  # A eliminado desde el principio
	_tm.start_first_round()
	assert_eq(_listener.count, 0, "a mitad de ronda no se mira")
	_a.finish()
	assert_eq(_listener.count, 0, "tampoco entre turnos")
	_b.finish()
	assert_eq(_listener.count, 1, "al cerrar la ronda sí")
	assert_eq(_listener.winner, _b.stats.empire)


func test_tras_la_victoria_no_empieza_otra_ronda() -> void:
	_world_of(10)
	_a.stats = _stats("A", 0)
	_tm.start_first_round()
	_a.finish()
	_b.finish()
	assert_eq(_tm.round_number, 1, "la ronda no avanza")
	assert_eq(_a.starts, 1, "nadie vuelve a jugar")
	assert_signal_emit_count(_tm, "round_started", 1)


func test_la_dominacion_usa_el_umbral_de_game_balance() -> void:
	var total := 10
	_world_of(total)
	var dominante := int(ceil(GameBalance.VICTORY_TILE_SHARE * total))
	_a.stats = _stats("A", dominante)
	_b.stats = _stats("B", 1)
	_tm.start_first_round()
	_a.finish()
	_b.finish()
	assert_eq(_listener.winner, _a.stats.empire,
		"con %d de %d casillas A domina" % [dominante, total])


func test_una_casilla_por_debajo_del_umbral_no_gana() -> void:
	var total := 10
	_world_of(total)
	var dominante := int(ceil(GameBalance.VICTORY_TILE_SHARE * total))
	_a.stats = _stats("A", dominante - 1)
	_b.stats = _stats("B", 1)
	_tm.start_first_round()
	_a.finish()
	_b.finish()
	assert_eq(_listener.count, 0)
	assert_eq(_tm.round_number, 2, "la partida sigue")


func test_un_controlador_sin_stats_no_rompe_la_comprobacion() -> void:
	_world_of(10)
	_b.stats = null
	_a.stats = _stats("A", 7)
	_tm.start_first_round()
	_a.finish()
	_b.finish()
	# Solo A cuenta: es el único con casillas → eliminación.
	assert_eq(_listener.winner, _a.stats.empire)


# ============================================================
#  Reanudar desde un save
# ============================================================

func test_resume_reanuda_al_controlador_actual_sin_reiniciar_la_ronda() -> void:
	_tm.round_number = 7
	_tm.current_index = 1
	_tm.resume_turn()
	assert_eq(_tm.round_number, 7)
	assert_eq(_b.resumes, 1, "reanuda al segundo, que tenía el turno")
	assert_eq(_a.resumes, 0)
	assert_eq(_a.starts + _b.starts, 0, "reanudar no es empezar")
	assert_signal_emitted_with_parameters(_tm, "round_started", [7])


func test_resume_acota_un_indice_fuera_de_rango() -> void:
	_tm.round_number = 3
	_tm.current_index = 99
	_tm.resume_turn()
	assert_eq(_tm.current_index, 1, "se acota al último controlador")
	assert_eq(_b.resumes, 1)


func test_el_fin_de_turno_del_jugador_se_ignora_fuera_de_su_turno() -> void:
	_tm.start_first_round()
	_a.finish()  # ahora el turno es de B (índice 1)
	_tm.on_player_turn_ended()
	_tm.on_player_hand_discarded()
	assert_eq(_tm.current_index, 1, "no cambia nada")
	assert_eq(_b.starts, 1)
