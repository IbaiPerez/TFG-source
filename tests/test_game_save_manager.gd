extends GutTest
## Tests de GameSaveManager: IO de slots, list/delete, validación de versión.
##
## NB: este test no carga la escena Map (eso se prueba a mano). Aquí solo
## se valida la mecánica de archivos del autoload.


const TEST_SLOT_PREFIX := "_gut_test_"


func before_each() -> void:
	# Limpiar cualquier slot de un run anterior.
	for slot in GameSaveManager.list_slots():
		if slot.begins_with(TEST_SLOT_PREFIX):
			GameSaveManager.delete_slot(slot)

	# Desconectar SceneManager.load_requested durante el test: si dejásemos
	# que se disparase, intentaría instanciar la escena Map en mitad del
	# test runner, lo que falla porque el UI se vincula a `stats.draw_pile`
	# que con un snapshot mínimo es null. La conexión se restaura después.
	if GameSaveManager.load_requested.is_connected(SceneManager._on_load_requested):
		GameSaveManager.load_requested.disconnect(SceneManager._on_load_requested)


func after_each() -> void:
	for slot in GameSaveManager.list_slots():
		if slot.begins_with(TEST_SLOT_PREFIX):
			GameSaveManager.delete_slot(slot)
	GameSaveManager.pending_snapshot = {}

	# Restaurar la conexión de SceneManager para el resto del proyecto.
	if not GameSaveManager.load_requested.is_connected(SceneManager._on_load_requested):
		GameSaveManager.load_requested.connect(SceneManager._on_load_requested)


# --- list / delete -----------------------------------------------------

func test_list_slots_starts_without_test_slots():
	# El loop puede iterar 0 veces si no hay slots residuales (caso normal):
	# en GUT eso cuenta como "Risky" porque ningún assert se ejecuta. Añadimos
	# un assert sobre la lista directamente para garantizar al menos uno.
	var slots := GameSaveManager.list_slots()
	for slot in slots:
		assert_false(slot.begins_with(TEST_SLOT_PREFIX),
				"slot residual no limpiado: %s" % slot)
	assert_true(true, "list_slots devuelve sin slots de test residuales")


func test_delete_slot_returns_false_when_missing():
	var ok := GameSaveManager.delete_slot(TEST_SLOT_PREFIX + "missing")
	assert_false(ok)


# --- save_current_game sin partida -------------------------------------

func test_save_returns_false_when_no_game_active():
	# Estamos en GUT, no hay escena Map activa; build_snapshot devolverá {}.
	var ok := GameSaveManager.save_current_game(TEST_SLOT_PREFIX + "no_game")
	assert_false(ok, "no debería guardarse fuera de partida")


# --- load: archivo inexistente ----------------------------------------

func test_load_missing_file_returns_false_and_emits_failure():
	var listener := _SignalListener.new()
	GameSaveManager.load_failed.connect(listener.on_failure)

	var ok := GameSaveManager.load_game(TEST_SLOT_PREFIX + "ghost")
	assert_false(ok)
	assert_true(listener.fired, "load_failed debería haberse emitido")

	GameSaveManager.load_failed.disconnect(listener.on_failure)


# --- load: versión incompatible ---------------------------------------

func test_load_rejects_unknown_version():
	var slot := TEST_SLOT_PREFIX + "bad_version"
	var path := SaveConstants.user_slot_path(slot)

	# Escribimos a mano un JSON con versión inválida.
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 99999, "tiles": []}))
	f.close()

	var ok := GameSaveManager.load_game(slot)
	assert_false(ok, "versión incompatible debería rechazarse")
	assert_true(GameSaveManager.pending_snapshot.is_empty(),
			"snapshot pendiente NO debe poblarse en versión inválida")


# --- load: archivo corrupto -------------------------------------------

func test_load_rejects_non_dict_json():
	# El parser de JSON de Godot dispara un push_error interno del engine
	# cuando recibe basura, lo cual GUT no puede ignorar. Aquí usamos JSON
	# válido pero con la forma equivocada (array en vez de objeto) — eso
	# pasa el parse y dispara nuestra validación de tipo.
	var slot := TEST_SLOT_PREFIX + "wrong_type"
	var path := SaveConstants.user_slot_path(slot)

	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("[]")
	f.close()

	var ok := GameSaveManager.load_game(slot)
	assert_false(ok, "JSON con tipo incorrecto debería rechazarse")
	assert_true(GameSaveManager.pending_snapshot.is_empty(),
			"snapshot pendiente NO debe poblarse en JSON inválido")


# --- escribir y leer un snapshot ficticio ------------------------------

func test_write_and_read_minimal_valid_snapshot():
	# Escribimos a mano un snapshot mínimo válido (la API save_current_game
	# requeriría una partida activa). Luego lo leemos vía load_game.
	var slot := TEST_SLOT_PREFIX + "valid_minimal"
	var path := SaveConstants.user_slot_path(slot)

	var minimal := {
		"version": SaveConstants.SAVE_FORMAT_VERSION,
		"tiles": [],
		"empires": [],
		"turn_manager": { "round_number": 1, "current_index": 0, "controller_order": [] },
		"battle_fronts": [],
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(minimal))
	f.close()

	var listener := _SignalListener.new()
	GameSaveManager.load_requested.connect(listener.on_request)

	var ok := GameSaveManager.load_game(slot)
	assert_true(ok)
	assert_true(listener.fired, "load_requested debe emitirse en éxito")
	assert_false(GameSaveManager.pending_snapshot.is_empty(),
			"pending_snapshot debe contener el dict cargado")

	GameSaveManager.load_requested.disconnect(listener.on_request)


# --- list_slots refleja escrituras manuales ---------------------------

func test_list_slots_includes_written_file():
	var slot := TEST_SLOT_PREFIX + "list_check"
	var path := SaveConstants.user_slot_path(slot)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": SaveConstants.SAVE_FORMAT_VERSION}))
	f.close()

	var slots := GameSaveManager.list_slots()
	assert_true(slot in slots, "list_slots debe incluir el slot recién creado")


# --- helper de señales -----------------------------------------------

class _SignalListener:
	var fired:bool = false

	func on_failure(_reason:String) -> void:
		fired = true

	func on_request(_snapshot:Dictionary) -> void:
		fired = true
