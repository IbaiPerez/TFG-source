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
	var dir := DirAccess.open(EVENTS_DIR)
	if dir == null:
		push_warning("[TurnEventLoader] No se pudo abrir el directorio de eventos: %s" % EVENTS_DIR)
		return events

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var event := load(EVENTS_DIR + file_name) as TurnEvent
			if event:
				events.append(event)
		file_name = dir.get_next()
	dir.list_dir_end()

	return events
