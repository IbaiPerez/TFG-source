extends GutTest

## Cubre la paleta BBCode de [UITheme] y, sobre todo, impide que vuelva a
## dispersarse en literales.
##
## Los textos con formato necesitan el color como hex dentro de la cadena, así que
## se escapaban de la paleta: había 12 hex repartidos por 5 ficheros, tres de ellos
## duplicados en dos ficheros cada uno. Dos casos no se veían ni buscando el
## literal: "#8A6A1A" y "#8a6a1a" eran el mismo color con distinta capitalización,
## y tres hex más no estaban en forma `[color=#...]`.


func test_bb_hex_devuelve_el_formato_que_espera_bbcode() -> void:
	assert_eq(UITheme.bb_hex(Color("#cc3333")), "#cc3333")
	assert_eq(UITheme.bb_hex(Color.BLACK), "#000000")


func test_bb_hex_ignora_la_capitalizacion_de_origen() -> void:
	# Es lo que ocultaba que BB_GOLD y el color de "modificador permanente" fueran
	# el mismo: uno se escribía en mayúsculas y otro en minúsculas.
	assert_eq(UITheme.bb_hex(Color("#4A6A8A")), UITheme.bb_hex(Color("#4a6a8a")))


func test_bb_colored_envuelve_el_texto() -> void:
	assert_eq(UITheme.bb_colored("ATK: 5", UITheme.BB_ATTACK),
		"[color=%s]ATK: 5[/color]" % UITheme.bb_hex(UITheme.BB_ATTACK))


func test_bb_colored_respeta_el_marcado_que_ya_traiga_el_texto() -> void:
	# El panel de frente colorea un texto que ya viene en negrita.
	var result := UITheme.bb_colored("[b]Tácticas[/b]", UITheme.BB_ENTITY)
	assert_string_contains(result, "[b]Tácticas[/b]")
	assert_true(result.begins_with("[color=#"))
	assert_true(result.ends_with("[/color]"))


func test_la_paleta_no_tiene_dos_nombres_para_el_mismo_color() -> void:
	# Con los hex sueltos esto pasaba y no se notaba. Como constantes con nombre,
	# un duplicado es una decisión que hay que justificar, no un descuido.
	var palette := {
		"BB_ATTACK": UITheme.BB_ATTACK, "BB_DEFENSE": UITheme.BB_DEFENSE,
		"BB_PRESSURE": UITheme.BB_PRESSURE, "BB_MAINTENANCE": UITheme.BB_MAINTENANCE,
		"BB_BODY": UITheme.BB_BODY, "BB_BIOME": UITheme.BB_BIOME,
		"BB_GOLD": UITheme.BB_GOLD, "BB_FOOD": UITheme.BB_FOOD,
		"BB_PENALTY": UITheme.BB_PENALTY, "BB_ENTITY": UITheme.BB_ENTITY,
		"BB_TEMPORARY": UITheme.BB_TEMPORARY, "BB_EFFECTIVE": UITheme.BB_EFFECTIVE,
		"BB_INEFFECTIVE": UITheme.BB_INEFFECTIVE,
		"BB_NEUTRAL_MATCH": UITheme.BB_NEUTRAL_MATCH,
	}
	var seen: Dictionary = {}
	for name in palette:
		var hex: String = UITheme.bb_hex(palette[name])
		assert_false(seen.has(hex),
			"%s y %s son el mismo color (%s)" % [name, seen.get(hex, ""), hex])
		seen[hex] = name


func test_nadie_vuelve_a_escribir_un_color_bbcode_a_mano() -> void:
	# Guarda de dispersión: el color debe salir de la paleta, no de un literal.
	# Se admite dentro de comentarios para poder documentar los hex originales.
	var offenders: Array[String] = []
	for path in _all_gd_files("res://scripts"):
		var source := FileAccess.get_file_as_string(path)
		for line in source.split("\n"):
			var stripped := line.strip_edges()
			if stripped.begins_with("#"):
				continue
			if stripped.contains("[color=#"):
				offenders.append(path)
				break
	assert_eq(offenders, [] as Array[String],
		"usa UITheme.bb_colored con una constante BB_* de la paleta")


func test_el_helper_de_hex_no_esta_reimplementado_por_ahi() -> void:
	# empire_selection tenía su propio `_hex(color)`, idéntico a bb_hex.
	var offenders: Array[String] = []
	for path in _all_gd_files("res://scripts"):
		if path.ends_with("ui_theme.gd"):
			continue
		var source := FileAccess.get_file_as_string(path)
		for line in source.split("\n"):
			var stripped := line.strip_edges()
			if stripped.begins_with("#"):
				continue
			if stripped.contains("to_html("):
				offenders.append(path)
				break
	assert_eq(offenders, [] as Array[String], "usa UITheme.bb_hex")


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
