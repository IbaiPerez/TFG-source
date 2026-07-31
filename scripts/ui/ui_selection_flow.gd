extends RefCounted
class_name UISelectionFlow

## Empareja dos señales mutuamente excluyentes —"el jugador eligió" y "el jugador
## canceló"— de forma que, dispare la que dispare, no queda ninguna conexión viva.
##
## El patrón que encapsula es sutil y estaba escrito dos veces en TurnEventPanel
## (una para elegir casilla y otra para elegir carta):
##
##   1. Ambas se conectan con CONNECT_ONE_SHOT, que suelta la que SÍ se dispara.
##   2. El handler de la que se disparó tiene que desconectar A MANO la HERMANA,
##      porque esa no llegó a dispararse y seguiría enganchada.
##
## Los dos pasos son necesarios: quitar CONNECT_ONE_SHOT dejaría viva la que se
## disparó, y quitar la desconexión manual dejaría viva la otra. (El plan de
## refactor los daba por redundantes y proponía elegir uno; no lo son.)

var _made: Signal
var _cancelled: Signal
var _on_made: Callable
var _on_cancelled: Callable


func _init(made: Signal, cancelled: Signal, on_made: Callable, on_cancelled: Callable) -> void:
	_made = made
	_cancelled = cancelled
	_on_made = on_made
	_on_cancelled = on_cancelled


## Queda a la espera de la elección del jugador.
##
## Suelta antes lo que hubiera quedado de una espera anterior: reconectar una señal
## ya conectada es un error de motor, y GUT lo convierte en fallo de test.
func start() -> void:
	finish()
	_made.connect(_on_made, Object.CONNECT_ONE_SHOT)
	_cancelled.connect(_on_cancelled, Object.CONNECT_ONE_SHOT)


## Cierra la espera. Se llama desde AMBOS handlers, al principio: desconecta lo que
## siga conectado, que es siempre la señal que no se disparó. Idempotente.
func finish() -> void:
	if _made.is_connected(_on_made):
		_made.disconnect(_on_made)
	if _cancelled.is_connected(_on_cancelled):
		_cancelled.disconnect(_on_cancelled)


## Si hay una espera en curso (alguna de las dos sigue conectada).
func is_waiting() -> bool:
	return _made.is_connected(_on_made) or _cancelled.is_connected(_on_cancelled)
