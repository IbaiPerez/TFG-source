extends GutTest

## Guarda del tooltip de las opciones de evento.
##
## El bug que motiva estos tests: el tooltip usaba un Label, y las descripciones de
## choice pueden traer BBCode. EVT_CARD_OFFERING_CH1_DESC pone el nombre de la
## carta en negrita, asi que en la Ofrenda de Cartas se veian las etiquetas
## literales: "Recibes una copia de [b]colonize[/b]."
##
## Era el UNICO choice del CSV con BBCode, de ahi que solo fallara ese evento. Un
## Label no da error al recibir BBCode: lo pinta tal cual. Nada lo detectaba salvo
## mirar la pantalla.

const BOTON := preload("res://scenes/UI/turn_events/turn_event_choice_button.tscn")


func _boton(descripcion: String) -> TurnEventChoiceButton:
	var b: TurnEventChoiceButton = BOTON.instantiate()
	add_child_autofree(b)
	var choice := TurnEventChoice.new()
	choice.label = "X"
	choice.description = descripcion
	b.setup(choice, true)
	return b


func test_el_tooltip_interpreta_bbcode() -> void:
	# Si vuelve a ser un Label, este assert falla: Label no tiene bbcode_enabled.
	var b := _boton("Recibes una copia de [b]Colonizar[/b].")
	assert_true(b.tooltip_text_label is RichTextLabel,
		"el tooltip debe ser RichTextLabel para interpretar el BBCode de las descripciones")
	assert_true((b.tooltip_text_label as RichTextLabel).bbcode_enabled,
		"con bbcode_enabled=false las etiquetas se verian literales")


func test_el_texto_visible_no_contiene_etiquetas() -> void:
	# get_parsed_text devuelve lo que el jugador LEE, ya sin marcado.
	var b := _boton("Recibes una copia de [b]Colonizar[/b].")
	var visible := (b.tooltip_text_label as RichTextLabel).get_parsed_text()
	assert_false(visible.contains("[b]"), "no deben verse las etiquetas: %s" % visible)
	assert_true(visible.contains("Colonizar"), "el nombre de la carta si debe leerse")


func test_la_descripcion_de_la_ofrenda_lleva_bbcode() -> void:
	# Fija la premisa del bug: si alguien quita el BBCode del CSV, este test avisa
	# de que la guarda de arriba ya no esta cubriendo un caso real.
	var previo := TranslationServer.get_locale()
	for locale in ["es", "en"]:
		TranslationServer.set_locale(locale)
		var texto := TranslationServer.translate("EVT_CARD_OFFERING_CH1_DESC")
		assert_true(texto.contains("[b]"),
			"EVT_CARD_OFFERING_CH1_DESC usa negrita en '%s'" % locale)
	TranslationServer.set_locale(previo)


func test_la_opcion_de_saltar_esta_traducida() -> void:
	# Estaban a fuego en castellano dentro del panel, asi que en ingles se leian
	# igualmente en castellano.
	var previo := TranslationServer.get_locale()
	for clave in ["EVT_SKIP_LABEL", "EVT_SKIP_DESC"]:
		for locale in ["es", "en"]:
			TranslationServer.set_locale(locale)
			assert_ne(TranslationServer.translate(clave), clave,
				"%s no esta traducida en '%s'" % [clave, locale])
	TranslationServer.set_locale(previo)
