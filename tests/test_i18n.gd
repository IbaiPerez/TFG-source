extends GutTest

## Tests del sistema de localización (i18n).
## Valida la integridad del CSV canónico y el comportamiento del autoload I18n.

const CSV_PATH := "res://localization/translations.csv"


func _read_rows() -> Dictionary:
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	assert_not_null(f, "El CSV de traducciones debe existir en " + CSV_PATH)
	var header := f.get_csv_line()
	var rows: Array = []
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.is_empty() or row[0].strip_edges() == "":
			continue
		rows.append(row)
	f.close()
	return {"header": header, "rows": rows}


func test_csv_header_has_keys_en_es() -> void:
	var header: PackedStringArray = _read_rows()["header"]
	assert_eq(header[0], "keys", "La primera columna debe ser 'keys'")
	assert_true(header.has("en"), "Debe existir la columna 'en'")
	assert_true(header.has("es"), "Debe existir la columna 'es'")


func test_every_key_has_en_and_es() -> void:
	var data := _read_rows()
	var header: PackedStringArray = data["header"]
	var en_idx := header.find("en")
	var es_idx := header.find("es")
	var missing: Array[String] = []
	for row: PackedStringArray in data["rows"]:
		var key: String = row[0]
		if en_idx >= row.size() or row[en_idx].strip_edges() == "":
			missing.append(key + " [en]")
		if es_idx >= row.size() or row[es_idx].strip_edges() == "":
			missing.append(key + " [es]")
	assert_eq(missing.size(), 0, "Claves sin traducción completa: " + ", ".join(missing))


func test_no_duplicate_keys() -> void:
	var data := _read_rows()
	var seen: Dictionary = {}
	var dups: Array[String] = []
	for row: PackedStringArray in data["rows"]:
		var key: String = row[0]
		if seen.has(key):
			dups.append(key)
		seen[key] = true
	assert_eq(dups.size(), 0, "Claves duplicadas en el CSV: " + ", ".join(dups))


func test_sample_keys_translate_in_both_locales() -> void:
	var prev := TranslationServer.get_locale()
	TranslationServer.set_locale("es")
	assert_eq(tr("MENU_PLAY"), "Jugar")
	assert_eq(tr("BLD_MOLINO_NAME"), "Molino")
	assert_eq(tr("TROOP_CAVALRY_NAME"), "Caballería")
	TranslationServer.set_locale("en")
	assert_eq(tr("MENU_PLAY"), "Play")
	assert_eq(tr("BLD_MOLINO_NAME"), "Mill")
	assert_eq(tr("TROOP_CAVALRY_NAME"), "Cavalry")
	TranslationServer.set_locale(prev)


func test_i18n_set_locale_changes_active_locale() -> void:
	var prev := I18n.get_current_locale()
	I18n.set_locale("en")
	assert_eq(I18n.get_current_locale(), "en")
	I18n.set_locale("es")
	assert_eq(I18n.get_current_locale(), "es")
	I18n.set_locale(prev)


func test_i18n_ignores_unsupported_locale() -> void:
	var prev := I18n.get_current_locale()
	I18n.set_locale("fr")
	assert_eq(I18n.get_current_locale(), prev, "Un locale no soportado debe ignorarse")
	# set_locale con un locale no soportado emite push_warning. GUT 9.5 lo
	# clasifica como ENGINE error (is_push_error() solo es true si function=="push_error")
	# y no expone assert_push_warning. assert_engine_error lo consume por subcadena
	# para que no se marque como error inesperado.
	assert_engine_error("Locale no soportado")


func test_i18n_exposes_supported_locales() -> void:
	assert_true(I18n.SUPPORTED_LOCALES.has("es"))
	assert_true(I18n.SUPPORTED_LOCALES.has("en"))
	assert_true(I18n.LOCALE_NAMES.has("es"))
	assert_true(I18n.LOCALE_NAMES.has("en"))


func test_main_menu_has_working_language_selector() -> void:
	var menu: Control = load("res://scenes/UI/menus/main_menu.tscn").instantiate()
	add_child_autofree(menu)
	var selector: OptionButton = menu.get_node("LanguageBar/LanguageSelector")
	assert_eq(selector.item_count, I18n.SUPPORTED_LOCALES.size(),
		"El selector debe ofrecer todos los idiomas soportados")
	var play: Button = menu.get_node(
		"CenterContainer/VBoxContainer/ButtonContainer/PlayButton")
	assert_eq(play.text, "MENU_PLAY",
		"El botón de Jugar debe usar la clave de traducción (auto-traducción de Control)")
