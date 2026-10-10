extends RefCounted
class_name TurnEventLoader

## Carga el "reglamento" de eventos de turno (.tres) desde res://resources/turn_events/.
##
## Punto único de carga. Lo usan tanto el flujo de partida nueva (`map.gd`) como
## la restauración desde save (`GameStateSerializer`), que antes duplicaban
## verbatim este escaneo de directorio.

const EVENTS_DIR := "res://resources/turn_events/"


static func load_all() -> Array[TurnEvent]:
	var events:Array[TurnEvent] = []
	# ResourceLoader y no DirAccess: en la build exportada el directorio solo
	# contiene `*.tres.remap`, y DirAccess devolvería cero eventos sin avisar.
	for file_name in ResourceLoader.list_directory(EVENTS_DIR):
		if file_name.ends_with(".tres"):
			var event := load(EVENTS_DIR + file_name) as TurnEvent
			if event:
				events.append(event)
	if events.is_empty():
		push_warning("[TurnEventLoader] No se encontró ningún evento en %s" % EVENTS_DIR)
	return events
