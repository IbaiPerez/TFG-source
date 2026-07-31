extends GutTest

## Cubre [UISelectionFlow], que empareja "el jugador eligió" con "el jugador
## canceló" para que no quede ninguna conexión viva dispare la que dispare.
##
## El patrón parece redundante (CONNECT_ONE_SHOT *y* desconexión manual) y el plan
## de refactor proponía quedarse con uno solo. No lo es, y estos tests lo fijan:
## los casos `..._deja_la_hermana_suelta` fallarían si se quitara la desconexión
## manual, y `..._suelta_la_que_se_disparo` fallaría si se quitara el one-shot.


signal made(value: int)
signal cancelled()

var _made_calls: Array[int] = []
var _cancelled_calls := 0
var _flow: UISelectionFlow


func before_each() -> void:
	_made_calls = []
	_cancelled_calls = 0
	_flow = UISelectionFlow.new(made, cancelled, _on_made, _on_cancelled)


func after_each() -> void:
	_flow.finish()


## Los handlers llaman a `finish()` lo primero, que es el contrato de la clase y lo
## que hacen los reales de TurnEventPanel. Sin esa llamada, la hermana se queda
## conectada — comprobado: la primera versión de estos tests la omitía y fallaban.
func _on_made(value: int) -> void:
	_flow.finish()
	_made_calls.append(value)


func _on_cancelled() -> void:
	_flow.finish()
	_cancelled_calls += 1


func test_antes_de_empezar_no_hay_espera() -> void:
	assert_false(_flow.is_waiting())


func test_start_deja_las_dos_a_la_espera() -> void:
	_flow.start()
	assert_true(_flow.is_waiting())
	assert_true(made.is_connected(_on_made))
	assert_true(cancelled.is_connected(_on_cancelled))


func test_elegir_entrega_el_valor_y_cierra_la_espera() -> void:
	_flow.start()
	made.emit(7)

	assert_eq(_made_calls, [7] as Array[int])
	assert_eq(_cancelled_calls, 0)
	assert_false(_flow.is_waiting(), "tras elegir no debe quedar nada conectado")


func test_elegir_deja_la_hermana_suelta() -> void:
	# Sin la desconexión manual, `cancelled` seguiría enganchada y una cancelación
	# posterior de OTRA selección llamaría a este handler.
	_flow.start()
	made.emit(1)

	cancelled.emit()
	assert_eq(_cancelled_calls, 0, "cancelar despues de elegir no debe llamar a nada")


func test_cancelar_deja_la_hermana_suelta() -> void:
	_flow.start()
	cancelled.emit()

	made.emit(99)
	assert_eq(_made_calls, [] as Array[int], "elegir despues de cancelar no debe llamar a nada")
	assert_eq(_cancelled_calls, 1)


func test_elegir_suelta_la_que_se_disparo() -> void:
	# Esto es lo que aporta CONNECT_ONE_SHOT: la señal que sí se disparó tampoco
	# queda conectada, así que un segundo disparo no repite el handler.
	_flow.start()
	made.emit(1)
	made.emit(2)

	assert_eq(_made_calls, [1] as Array[int], "el handler debe correr una sola vez")


func test_finish_es_idempotente() -> void:
	# Se llama desde ambos handlers y otra vez al salir del árbol.
	_flow.start()
	_flow.finish()
	_flow.finish()
	assert_false(_flow.is_waiting())


func test_start_sobre_una_espera_viva_no_duplica_la_conexion() -> void:
	# Reconectar una señal ya conectada es un error de motor (que GUT convierte en
	# fallo). start() suelta lo anterior primero.
	_flow.start()
	_flow.start()

	made.emit(5)
	assert_eq(_made_calls, [5] as Array[int], "el handler debe correr una sola vez")


func test_se_puede_reutilizar_para_una_segunda_seleccion() -> void:
	_flow.start()
	made.emit(1)

	_flow.start()
	made.emit(2)

	assert_eq(_made_calls, [1, 2] as Array[int])
