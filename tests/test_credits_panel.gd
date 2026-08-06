extends GutTest

## Guarda de los creditos.
##
## Existe por una razon de LICENCIA, no de interfaz: los iconos son CC BY 3.0 y la
## atribucion es obligatoria alli donde se distribuya la obra. Si alguien vaciara
## esta pantalla o quitara la mencion, el juego dejaria de cumplir la licencia y
## nada mas lo detectaria — no hay error, no hay crash, solo un incumplimiento
## silencioso.


func _panel() -> CreditsPanel:
	var p := CreditsPanel.new()
	add_child_autofree(p)
	return p


func _textos(nodo: Node, acc: Array[String]) -> Array[String]:
	if nodo is Label:
		acc.append((nodo as Label).text)
	for hijo in nodo.get_children():
		_textos(hijo, acc)
	return acc


func test_la_mencion_de_la_licencia_aparece_en_pantalla() -> void:
	var textos := _textos(_panel(), [] as Array[String])
	var encontrado := false
	for t in textos:
		if t == CreditsPanel.ICON_NOTICE:
			encontrado = true
	assert_true(encontrado,
		"la mencion literal que exige game-icons.net debe estar visible")


func test_la_mencion_nombra_la_fuente_y_la_licencia() -> void:
	# Los dos datos que CC BY exige: quien y bajo que licencia.
	assert_true(CreditsPanel.ICON_NOTICE.contains("game-icons.net"))
	assert_true(CreditsPanel.ICON_NOTICE.contains("CC BY 3.0"))
	assert_true(CreditsPanel.ICON_LICENSE_URL.begins_with("https://creativecommons.org/"))


func test_se_atribuye_a_todos_los_autores() -> void:
	# La licencia pide reconocer al AUTOR, no solo a la web. Si se anaden iconos de
	# un autor nuevo, su nombre tiene que entrar aqui.
	var textos := "\n".join(_textos(_panel(), [] as Array[String]))
	for autor in CreditsPanel.ICON_AUTHORS:
		assert_true(textos.contains(autor), "falta el autor %s en los creditos" % autor)


func test_los_textos_estan_traducidos_en_ambos_idiomas() -> void:
	# Una clave sin entrada en el CSV se muestra como la clave misma (CREDITS_ART),
	# que es un fallo visible pero que ninguna otra prueba mira.
	var claves := ["MENU_CREDITS", "CREDITS_DEVELOPMENT", "CREDITS_AUTHOR",
		"CREDITS_ENGINE", "CREDITS_ART", "CREDITS_ART_INTRO", "CREDITS_ART_LICENSE"]
	var previo := TranslationServer.get_locale()
	for locale in ["es", "en"]:
		TranslationServer.set_locale(locale)
		for clave in claves:
			assert_ne(TranslationServer.translate(clave), clave,
				"%s no esta traducida en '%s'" % [clave, locale])
	TranslationServer.set_locale(previo)


func test_el_menu_principal_ofrece_los_creditos() -> void:
	# Sin punto de entrada, la pantalla existe pero el jugador nunca la ve, con lo
	# que la atribucion no se estaria cumpliendo de hecho.
	var escena := load("res://scenes/UI/menus/main_menu.tscn") as PackedScene
	assert_not_null(escena)
	var menu := escena.instantiate()
	add_child_autofree(menu)
	var boton := menu.get_node_or_null(
		"CenterContainer/VBoxContainer/ButtonContainer/CreditsButton")
	assert_not_null(boton, "el menu principal debe tener boton de creditos")
	assert_eq((boton as Button).text, "MENU_CREDITS")
