extends Node
## Autoload que rastreará cuántos menús están activos.
## Cuando hay menús abiertos, bloquea:
## - Clics en el mapa (interaction.gd)
## - Scroll de zoom de cámara (camera_3d.gd)

## Contador de menús abiertos (puede haber múltiples simultáneamente)
var _menu_count: int = 0

signal menu_opened
signal menu_closed

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	# Reset counter on game start to avoid stuck state
	_menu_count = 0


## Llamar cuando se abre un menú (desde _ready del menú)
func register_menu() -> void:
	_menu_count += 1
	if _menu_count == 1:
		menu_opened.emit()


## Llamar cuando se cierra un menú (desde _notification(NOTIFICATION_PREDELETE) del menú)
func unregister_menu() -> void:
	_menu_count = maxi(_menu_count - 1, 0)
	if _menu_count == 0:
		menu_closed.emit()


## Devuelve true si hay algún menú abierto
func is_any_menu_open() -> bool:
	return _menu_count > 0
