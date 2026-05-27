extends Node

## Autoload que orquesta el guardado/carga del estado de partida.
##
## Responsabilidades:
## - Leer/escribir archivos JSON en `user://saves/`.
## - Listar slots disponibles.
## - Construir el snapshot de la partida actual delegando en `GameStateSerializer`.
## - Restaurar la partida desde un snapshot (cambia a la escena de mapa con
##   el snapshot precargado).
##
## La persistencia de un estado global del juego (desbloqueos meta, opciones,
## etc.) queda fuera de este sistema: solo se guarda el estado de la partida
## en curso. Es por diseño — cf. discusión con Ibai (TFG, mayo 2026).

signal save_completed(slot_name:String)
signal load_failed(reason:String)
signal load_requested(snapshot:Dictionary)

## Snapshot pendiente de aplicar en el próximo `_ready()` de Map.
## SceneManager / Map lo consumen tras cambiar de escena.
var pending_snapshot:Dictionary = {}


func _ready() -> void:
	_ensure_dir(SaveConstants.USER_SAVES_DIR)


func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F5:
				if save_current_game(SaveConstants.QUICKSAVE_SLOT):
					Logger.info("[GameSaveManager] Quicksave guardado")
				else:
					Logger.warn("[GameSaveManager] No se pudo guardar (¿estás en partida?)")
				get_viewport().set_input_as_handled()
			KEY_F9:
				if load_game(SaveConstants.QUICKSAVE_SLOT):
					Logger.info("[GameSaveManager] Quickload solicitado")
				else:
					Logger.warn("[GameSaveManager] No hay quicksave disponible")
				get_viewport().set_input_as_handled()


## --- API pública ---------------------------------------------------------

## Guarda la partida en curso bajo el slot indicado.
## Devuelve true si el archivo se escribió correctamente.
func save_current_game(slot_name:String) -> bool:
	var snapshot := GameStateSerializer.build_snapshot()
	if snapshot.is_empty():
		Logger.warn("[GameSaveManager] No hay partida activa para guardar")
		return false

	var path := SaveConstants.user_slot_path(slot_name)
	if not _write_snapshot(path, snapshot):
		return false

	save_completed.emit(slot_name)
	return true


## Carga el slot indicado: lee el archivo, valida la versión y dispara la
## navegación a la escena de mapa con el snapshot listo para aplicar.
##
## Devuelve true si el archivo se leyó y validó. La aplicación efectiva
## ocurre cuando Map._ready() consume `pending_snapshot`.
func load_game(slot_name:String) -> bool:
	var path := SaveConstants.user_slot_path(slot_name)
	return _load_from_path(path)


## Variante para tests: carga un fixture desde res://tests/fixtures/.
func load_fixture(fixture_name:String) -> bool:
	var path := SaveConstants.fixture_path(fixture_name)
	return _load_from_path(path)


## Devuelve los nombres de los slots existentes (sin extensión).
func list_slots() -> Array[String]:
	var slots:Array[String] = []
	var dir := DirAccess.open(SaveConstants.USER_SAVES_DIR)
	if dir == null:
		return slots
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.ends_with(SaveConstants.SAVE_EXTENSION):
			slots.append(f.get_basename())
		f = dir.get_next()
	dir.list_dir_end()
	slots.sort()
	return slots


## Borra un slot (no falla si no existe).
func delete_slot(slot_name:String) -> bool:
	var path := SaveConstants.user_slot_path(slot_name)
	if not FileAccess.file_exists(path):
		return false
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if err != OK:
		# Fallback: intento con DirAccess regular
		var dir := DirAccess.open(SaveConstants.USER_SAVES_DIR)
		if dir != null:
			dir.remove(path.get_file())
	return true


## Devuelve el snapshot pendiente y lo limpia. Map._ready() llama a esto
## tras instanciar la escena para saber si debe regenerar el mundo o
## aplicar un save.
func consume_pending_snapshot() -> Dictionary:
	var snapshot := pending_snapshot
	pending_snapshot = {}
	return snapshot


## --- Helpers internos ----------------------------------------------------

func _load_from_path(path:String) -> bool:
	# Estos flujos de fallo son esperables (slot inexistente, save de versión
	# antigua, archivo manualmente corrompido). Se reportan via señal
	# `load_failed` y print, NO con push_warning, porque GUT trata los
	# warnings como errores inesperados de test.
	if not FileAccess.file_exists(path):
		var msg := "Archivo no encontrado: %s" % path
		Logger.warn("[GameSaveManager] %s" % msg)
		load_failed.emit(msg)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var err_msg := "No se pudo abrir el archivo: %s" % path
		Logger.error("[GameSaveManager] %s" % err_msg)
		load_failed.emit(err_msg)
		return false

	var text := file.get_as_text()
	file.close()

	var parsed:Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		var parse_msg := "JSON inválido en %s" % path
		Logger.error("[GameSaveManager] %s" % parse_msg)
		load_failed.emit(parse_msg)
		return false

	var snapshot:Dictionary = parsed
	var version:int = int(snapshot.get("version", -1))
	if version != SaveConstants.SAVE_FORMAT_VERSION:
		var ver_msg := "Versión incompatible: %d (esperada %d)" % [version, SaveConstants.SAVE_FORMAT_VERSION]
		Logger.warn("[GameSaveManager] %s" % ver_msg)
		load_failed.emit(ver_msg)
		return false

	pending_snapshot = snapshot
	load_requested.emit(snapshot)
	return true


func _write_snapshot(path:String, snapshot:Dictionary) -> bool:
	_ensure_dir(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("[GameSaveManager] No se pudo escribir: %s" % path)
		return false
	# stringify con indentación para que sea legible/diff-eable.
	file.store_string(JSON.stringify(snapshot, "\t"))
	file.close()
	return true


func _ensure_dir(dir_path:String) -> void:
	if DirAccess.dir_exists_absolute(dir_path):
		return
	DirAccess.make_dir_recursive_absolute(dir_path)
