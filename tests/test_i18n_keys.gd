extends GutTest

## Comprueba que las claves de traducción que el código construye a partir de un
## enum existen de verdad en las traducciones.
##
## Antes estas claves se montaban por concatenación (`"TILE_" + biome_type.keys()[b]
## .to_upper()`) en 5 sitios. Renombrar un valor del enum rompía la traducción EN
## SILENCIO: `tr()` no avisa de una clave inexistente, simplemente devuelve la clave,
## y la UI mostraba "TILE_LLANURA" en pantalla. Ahora las claves salen de
## `Tile.biome_key` / `Tile.location_key` y este test las valida contra el CSV.

const _CSV_PATH := "res://localization/translations.csv"

var _csv_keys: Dictionary = {}
var _saved_locale: String


func before_each() -> void:
	if _csv_keys.is_empty():
		_csv_keys = _load_csv_keys()
	_saved_locale = TranslationServer.get_locale()


func after_each() -> void:
	TranslationServer.set_locale(_saved_locale)


func test_el_csv_de_traducciones_se_lee() -> void:
	assert_gt(_csv_keys.size(), 50, "no se pudieron leer las claves de %s" % _CSV_PATH)


func _load_csv_keys() -> Dictionary:
	var keys: Dictionary = {}
	var file := FileAccess.open(_CSV_PATH, FileAccess.READ)
	if file == null:
		return keys
	file.get_csv_line()  # cabecera
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() > 0 and row[0] != "":
			keys[row[0]] = true
	file.close()
	return keys


func test_todos_los_biomas_tienen_clave_y_esta_en_el_csv() -> void:
	for value: int in Tile.biome_type.values():
		var key := Tile.biome_key(value)
		assert_ne(key, "", "el bioma %s no tiene clave en Tile.biome_key" % Tile.biome_type.find_key(value))
		assert_true(_csv_keys.has(key), "la clave '%s' no existe en translations.csv" % key)


func test_todos_los_niveles_de_casilla_tienen_clave_y_esta_en_el_csv() -> void:
	for value: int in Tile.location_type.values():
		var key := Tile.location_key(value)
		assert_ne(key, "", "el nivel %s no tiene clave en Tile.location_key" % Tile.location_type.find_key(value))
		assert_true(_csv_keys.has(key), "la clave '%s' no existe en translations.csv" % key)


func test_un_valor_fuera_del_enum_devuelve_cadena_vacia() -> void:
	# Los llamantes distinguen "no hay clave" de una clave real para poner "?".
	assert_eq(Tile.biome_key(99), "")
	assert_eq(Tile.location_key(99), "")


func test_nadie_vuelve_a_construir_estas_claves_por_concatenacion() -> void:
	# Guarda de cobertura, no de estilo: al migrar los 5 puntos a Tile.biome_key /
	# Tile.location_key se me pasó uno (tile_panel), y nada falló — precisamente
	# porque el fallo de la concatenación es silencioso. Esto recorre el código y
	# lo caza. Se admite dentro de comentarios para poder documentar el patrón.
	var offenders: Array[String] = []
	for path in _all_gd_files("res://scripts"):
		var source := FileAccess.get_file_as_string(path)
		for line in source.split("\n"):
			var stripped := line.strip_edges()
			if stripped.begins_with("#"):
				continue
			if stripped.contains('"TILE_" +') or stripped.contains('"LOC_" +'):
				offenders.append(path)
				break
	assert_eq(offenders, [] as Array[String],
		"usa Tile.biome_key / Tile.location_key en vez de concatenar la clave")


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


func test_las_claves_se_traducen_en_los_dos_idiomas() -> void:
	for locale in ["es", "en"]:
		TranslationServer.set_locale(locale)
		for value: int in Tile.biome_type.values():
			var key := Tile.biome_key(value)
			assert_ne(tr(key), key, "'%s' sin traducir en locale '%s'" % [key, locale])
		for value: int in Tile.location_type.values():
			var key := Tile.location_key(value)
			assert_ne(tr(key), key, "'%s' sin traducir en locale '%s'" % [key, locale])
