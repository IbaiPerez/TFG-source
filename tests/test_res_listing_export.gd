extends GutTest

## Impide volver a recorrer `res://` con DirAccess.
##
## En la build exportada los `.tres` del paquete aparecen como `*.tres.remap`, así
## que un escaneo con DirAccess que filtra por `.tres` devuelve cero ficheros sin
## ningún error. Pasó con los eventos de turno (la build no lanzaba ninguno) y con
## el registro de guardado (no habría podido cargar partidas). En el editor todo
## funciona, por eso la guarda es estática: la suite no corre sobre la build.
##
## Para listar recursos, `ResourceLoader.list_directory`, que resuelve los remaps.

## Ficheros que recorren `user://`, donde no hay remaps.
const ALLOWED := ["res://scripts/save/game_save_manager.gd"]


func test_nadie_recorre_res_con_dir_access() -> void:
	var offenders: Array[String] = []
	for path in _all_gd_files("res://scripts"):
		if path in ALLOWED:
			continue
		var source := FileAccess.get_file_as_string(path)
		for line in source.split("\n"):
			var stripped := line.strip_edges()
			if stripped.begins_with("#"):
				continue
			if stripped.contains("list_dir_begin") or stripped.contains(".get_files("):
				offenders.append(path)
				break
	assert_eq(offenders, [] as Array[String],
		"usa ResourceLoader.list_directory: en la build exportada DirAccess no ve los .tres")


func test_los_eventos_de_turno_se_cargan() -> void:
	assert_gt(TurnEventLoader.load_all().size(), 0)


func _all_gd_files(root: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := root.path_join(entry)
		if dir.current_is_dir():
			found.append_array(_all_gd_files(full))
		elif entry.ends_with(".gd"):
			found.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return found
