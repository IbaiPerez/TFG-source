extends GutTest

## Guarda de las tablas de despacho `Script -> Callable(Clase, "metodo")`.
##
## El proyecto usa ese patron en varios sitios (efectos de evento, enumeradores de
## jugadas...) porque casar por tipo exacto no degrada con el numero de casos. El
## problema es que el nombre del metodo viaja DENTRO DE UNA CADENA:
##
##   - el parser no lo mira, asi que un nombre equivocado NO da error de parseo
##   - el reimport headless queda limpio
##   - falla solo EN EJECUCION, y solo si se pisa esa rama concreta
##
## Paso justo por esto al mover los 14 aplicadores de efecto a AIRealEventEffects:
## la tabla seguia diciendo `Callable(AIRealEvents, "_eff_gold")`, todo compilaba y
## lo cazo la suite de milagro, porque habia tests que ejercitaban esos efectos.
## Este barrido lo caza SIEMPRE, sin depender de que exista un test por rama.


func _gd_files_under(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			_gd_files_under(full, out)
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


func test_todo_callable_por_nombre_apunta_a_un_metodo_que_existe() -> void:
	var files: Array[String] = []
	_gd_files_under("res://scripts", files)

	# Callable(NombreDeClase, "metodo")
	var re := RegEx.create_from_string('Callable\\(\\s*([A-Z]\\w+)\\s*,\\s*"(\\w+)"\\s*\\)')

	var revisados := 0
	var rotos: Array[String] = []
	for path in files:
		var text := FileAccess.get_file_as_string(path)
		for m in re.search_all(text):
			var cls_name := m.get_string(1)
			var method := m.get_string(2)
			if not ClassDB.class_exists(cls_name) and not _is_global_script_class(cls_name):
				continue   # no es una clase global (variable local, autoload...)
			revisados += 1
			var script := _script_of_class(cls_name)
			if script == null:
				continue
			if not _has_method(script, method):
				rotos.append("%s: Callable(%s, \"%s\") — no existe ese método"
					% [path, cls_name, method])

	assert_gt(revisados, 20,
		"el barrido debe encontrar las tablas de despacho; si baja de golpe, no está mirando")
	assert_eq(rotos, [] as Array[String],
		"despachos que fallarían en ejecución: %s" % str(rotos))


func _is_global_script_class(cls_name: String) -> bool:
	for entry in ProjectSettings.get_global_class_list():
		if entry.get("class", "") == cls_name:
			return true
	return false


func _script_of_class(cls_name: String) -> Script:
	for entry in ProjectSettings.get_global_class_list():
		if entry.get("class", "") == cls_name:
			return load(entry.get("path", "")) as Script
	return null


func _has_method(script: Script, method: String) -> bool:
	for m in script.get_script_method_list():
		if m.get("name", "") == method:
			return true
	return false
