extends GutTest

## Barrido: TODOS los .gd de scripts/ deben compilar de verdad.
##
## Existe porque las dos guardas que teniamos no lo eran:
##
##   1. El reimport headless (`--editor --quit`) devuelve EXIT=0 AUNQUE imprima
##      parse errors. Comprobado inyectando una llamada a una funcion inexistente:
##      el log grita y el codigo de salida dice 0. No sirve de puerta.
##   2. Un script de test que no compila GUT lo SALTA en silencio y sigue diciendo
##      "All tests passed", con menos tests.
##
## OJO CON COMO SE COMPRUEBA: `load()` de un script roto NO devuelve null, devuelve
## un GDScript a medio compilar. Comprobado con probe: para un script con un parse
## error, `load() == null` da false, `can_instantiate()` da false y `reload()` da
## 43 en vez de OK. Asi que `assert_not_null(load(p))` es una guarda que NO FALLA
## NUNCA — se usa `can_instantiate()`.
##
## Se descarto `reload()` pese a ser igual de fiable: recompila en caliente y
## reiniciaria las `static var` de otras clases (p.ej. el default cacheado de
## HeuristicWeights) a mitad de suite. `can_instantiate()` no tiene efectos.


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


func test_todos_los_scripts_de_produccion_compilan() -> void:
	var files: Array[String] = []
	_gd_files_under("res://scripts", files)

	# Si el recorrido se rompe, el test pasaria en verde sin comprobar nada.
	assert_gt(files.size(), 250,
		"el barrido debe encontrar los ~312 scripts de produccion")

	var broken: Array[String] = []
	for path in files:
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			broken.append(path)

	assert_eq(broken, [] as Array[String],
		"estos scripts no compilan: %s" % str(broken))
