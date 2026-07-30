extends GutTest

## Cubre [TutorialContent], el contenido del manual extraído de TutorialPanel.
##
## El valor de estos tests no es solo cubrir el refactor: construir el manual
## ejecuta ~40 formateos `%` contra los .tres reales, así que un descuadre de
## argumentos o un campo renombrado en un recurso de balance falla aquí en vez de
## romper el panel en ejecución.

const _GOLD_MINE := preload("res://resources/buildings/basic/gold_mine.tres")

var _saved_locale: String


func before_each() -> void:
	_saved_locale = TranslationServer.get_locale()


func after_each() -> void:
	TranslationServer.set_locale(_saved_locale)


func _build() -> Array[TutorialEntry]:
	return TutorialContent.new().build()


func test_build_devuelve_entradas_completas() -> void:
	var entries := _build()
	assert_gt(entries.size(), 20, "el manual debe tener todas sus entradas")
	for entry in entries:
		assert_ne(entry.category, "", "categoria vacia")
		assert_ne(entry.title, "", "titulo vacio en la categoria %s" % entry.category)
		assert_ne(entry.body, "", "cuerpo vacio en la entrada %s" % entry.title)


func test_las_categorias_son_contiguas() -> void:
	# El panel inserta una cabecera cada vez que CAMBIA la categoría: si una
	# categoría reapareciera después de otra, saldría dos veces en la lista.
	var entries := _build()
	var seen: Array[String] = []
	var current := ""
	for entry in entries:
		if entry.category == current:
			continue
		assert_false(seen.has(entry.category),
			"la categoria '%s' reaparece tras otra: saldria duplicada en la lista" % entry.category)
		seen.append(entry.category)
		current = entry.category


func test_los_titulos_no_se_repiten_dentro_de_una_categoria() -> void:
	var entries := _build()
	var seen: Dictionary = {}
	for entry in entries:
		var key := "%s/%s" % [entry.category, entry.title]
		assert_false(seen.has(key), "titulo duplicado: %s" % key)
		seen[key] = true


func test_el_manual_lee_el_balance_real_y_no_texto_congelado() -> void:
	# Invariante deliberado: las cifras salen de los .tres, no están escritas a
	# mano. Si alguien convierte el contenido a texto estático, esto lo detecta.
	var entries := _build()
	var basic := _find_by_title(entries, "Edificios básicos", "Basic buildings")
	assert_not_null(basic, "falta la entrada de edificios basicos")
	if basic == null:
		return
	assert_string_contains(basic.body, str(_GOLD_MINE.construction_cost),
		"el coste de la Mina de Oro debe venir de su .tres")
	assert_string_contains(basic.body, str(_GOLD_MINE.gold_produced),
		"la produccion de la Mina de Oro debe venir de su .tres")


func test_se_construye_en_los_dos_idiomas() -> void:
	TranslationServer.set_locale("es")
	var es := _build()
	TranslationServer.set_locale("en")
	var en := _build()

	assert_eq(es.size(), en.size(), "ambos idiomas deben tener las mismas entradas")
	assert_eq(es[0].category, "Primeros Pasos")
	assert_eq(en[0].category, "Getting Started")


func test_ninguna_entrada_deja_marcadores_de_formato_sin_sustituir() -> void:
	for entry in _build():
		assert_false(entry.body.contains("%d"), "queda un %%d sin sustituir en '%s'" % entry.title)
		assert_false(entry.body.contains("%s"), "queda un %%s sin sustituir en '%s'" % entry.title)


func test_las_tacticas_resuelven_todas_sus_etiquetas() -> void:
	# `_troop_type_label` y `_biome_label` devuelven "?" para un valor de enum
	# desconocido: si se añade un tipo de tropa o un bioma y no se actualizan,
	# la entrada de tácticas sale con interrogantes.
	var tactics := _find_by_title(_build(), "Cartas tácticas", "Tactic cards")
	assert_not_null(tactics, "falta la entrada de cartas tacticas")
	if tactics == null:
		return
	assert_false(tactics.body.contains("?"),
		"hay un tipo de tropa o bioma sin etiqueta en la entrada de tacticas")


func _find_by_title(entries: Array[TutorialEntry], es: String, en: String) -> TutorialEntry:
	for entry in entries:
		if entry.title == es or entry.title == en:
			return entry
	return null
