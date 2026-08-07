extends GutTest

## Cubre el informe de partida que el jugador copia en la encuesta y la config
## de la build de la que sale.
##
## El informe es un formato de DATOS, no texto de interfaz: se pega en una hoja
## de respuestas y luego se filtra por él. Lo que se protege aquí es justo eso —
## que quepa en una línea, que la semilla viaje entera y que los desenlaces se
## escriban siempre igual—, porque un cambio en cualquiera de las tres cosas
## invalida en silencio las respuestas ya recogidas.

const _CSV_PATH := "res://localization/translations.csv"

## Claves que escribe el panel de feedback. Una errata aquí no rompe nada: `tr()`
## devuelve la clave y el jugador ve "FEEDBACK_INTRO" en pantalla.
const _PANEL_KEYS: Array[String] = [
	"PAUSE_FEEDBACK", "FEEDBACK_TITLE", "FEEDBACK_INTRO", "FEEDBACK_COPY",
	"FEEDBACK_COPIED", "FEEDBACK_OPEN_SURVEY", "FEEDBACK_SURVEY_UNAVAILABLE",
	"FEEDBACK_URL_HINT", "UI_CLOSE", "GAMEOVER_TITLE", "PAUSE_MAIN_MENU",
]


func _make(outcome: int = PlayReport.Outcome.DEFEAT, map_seed: int = 48213,
		empire_key: String = "EMP_MEDICI_NAME", turn: int = 31,
		owned: int = 32, total: int = 128) -> PlayReport:
	return PlayReport.capture(outcome, map_seed, empire_key, turn, owned, total)


# ─────────────────────────────────────────────────────────────────────────────
# Formato
# ─────────────────────────────────────────────────────────────────────────────

func test_el_informe_cabe_en_una_sola_linea() -> void:
	# Es la razón de que el formato sea el que es: las respuestas cortas de un
	# formulario no admiten saltos de línea. Con varias líneas habría que usar un
	# campo de párrafo, donde el jugador escribe encima del informe.
	var text := _make().to_text()
	assert_false(text.contains("\n"), "el informe no puede tener saltos de línea")
	assert_false(text.contains("\r"), "el informe no puede tener retornos de carro")


func test_la_semilla_viaja_completa_en_el_informe() -> void:
	# Sin la semilla el informe no sirve para nada: es lo que permite volver a
	# generar el mapa del que se queja el jugador.
	var text := _make(PlayReport.Outcome.DEFEAT, 48213).to_text()
	assert_string_contains(text, "seed 48213")


func test_la_semilla_negativa_no_se_recorta() -> void:
	# `init_seed` usa randi(), que en GDScript devuelve un entero con signo.
	var text := _make(PlayReport.Outcome.DEFEAT, -1902345871).to_text()
	assert_string_contains(text, "seed -1902345871")


func test_el_informe_lleva_version_turno_y_porcentaje() -> void:
	var text := _make(PlayReport.Outcome.DEFEAT, 1, "EMP_MEDICI_NAME", 31, 32, 128).to_text()
	assert_string_contains(text, "v" + BuildInfo.version())
	assert_string_contains(text, "turn 31")
	assert_string_contains(text, "25% map")


func test_el_porcentaje_sale_del_cociente_y_no_de_un_valor_fijo() -> void:
	# Con entradas literales el test seguiría verde midiendo otra cosa.
	assert_string_contains(_make(PlayReport.Outcome.VICTORY, 1, "", 1, 90, 127).to_text(),
		"%d%% map" % roundi(90.0 / 127.0 * 100.0))


func test_un_mapa_vacio_no_divide_entre_cero() -> void:
	# Pasa de verdad: el menú de pausa puede pedir el informe antes de que
	# WorldMap tenga tiles.
	var report := _make(PlayReport.Outcome.ABANDONED, 7, "", 0, 0, 0)
	assert_eq(report.map_share, 0.0)
	assert_string_contains(report.to_text(), "0% map")


# ─────────────────────────────────────────────────────────────────────────────
# Desenlace
# ─────────────────────────────────────────────────────────────────────────────

func test_cada_desenlace_tiene_su_propia_palabra() -> void:
	# Si dos desenlaces compartieran token, filtrar las respuestas mezclaría
	# partidas ganadas con abandonadas sin que se notara.
	var seen: Dictionary = {}
	for outcome: int in PlayReport.Outcome.values():
		var token: String = PlayReport.OUTCOME_TOKENS[outcome]
		assert_ne(token, "", "el desenlace %d no tiene palabra" % outcome)
		assert_false(seen.has(token), "'%s' se usa para dos desenlaces" % token)
		seen[token] = outcome


func test_el_desenlace_aparece_en_el_informe() -> void:
	for outcome: int in PlayReport.Outcome.values():
		var text := _make(outcome).to_text()
		assert_string_contains(text, PlayReport.OUTCOME_TOKENS[outcome])


func test_un_desenlace_desconocido_cae_en_abandonada() -> void:
	var report := _make()
	report.outcome = 99
	assert_eq(report.outcome_token(), PlayReport.OUTCOME_TOKENS[PlayReport.Outcome.ABANDONED])


# ─────────────────────────────────────────────────────────────────────────────
# Imperio
# ─────────────────────────────────────────────────────────────────────────────

func test_el_imperio_se_escribe_sin_la_envoltura_de_la_clave() -> void:
	# `Empire.name` guarda la clave de traducción, no el nombre. Se usa la clave
	# a propósito (es igual en los dos idiomas), pero desnuda.
	assert_eq(PlayReport.strip_empire_key("EMP_MEDICI_NAME"), "medici")
	assert_eq(PlayReport.strip_empire_key("EMP_BABYLON_NAME"), "babylon")


func test_una_clave_con_otra_forma_sobrevive_al_desnudado() -> void:
	# Mejor un nombre feo en el informe que un informe sin imperio.
	assert_eq(PlayReport.strip_empire_key("MONGOL"), "mongol")
	assert_eq(PlayReport.strip_empire_key(""), "")


func test_un_imperio_ausente_no_deja_un_hueco_en_el_informe() -> void:
	# Un campo vacío desplaza la lectura de las columnas al separar el informe.
	var text := _make(PlayReport.Outcome.ABANDONED, 1, "", 3, 0, 10).to_text()
	assert_false(text.contains("|  |"), "el informe tiene un campo vacío: %s" % text)


func test_los_imperios_reales_producen_un_identificador_legible() -> void:
	# Ejercita las claves que existen de verdad, no una inventada.
	for path in ["res://resources/empires/medici.tres",
			"res://resources/empires/mongol.tres",
			"res://resources/empires/babylonian.tres"]:
		var empire: Empire = load(path) as Empire
		assert_not_null(empire, "no se pudo cargar %s" % path)
		var id := PlayReport.strip_empire_key(empire.name)
		assert_ne(id, "", "%s produce un identificador vacío" % path)
		assert_false(id.contains("emp_"), "%s conserva el prefijo: %s" % [path, id])


# ─────────────────────────────────────────────────────────────────────────────
# Config de la build
# ─────────────────────────────────────────────────────────────────────────────

func test_la_version_del_proyecto_esta_declarada() -> void:
	# Sin versión, un informe no dice a qué build culpar.
	assert_eq(BuildInfo.version(), str(ProjectSettings.get_setting(BuildInfo.VERSION_SETTING, "")))
	assert_ne(BuildInfo.version(), "", "la build no declara versión")


func test_hay_una_entrada_de_encuesta_por_cada_idioma_soportado() -> void:
	for locale in I18n.SUPPORTED_LOCALES:
		assert_true(BuildInfo.SURVEY_URLS.has(locale),
			"falta la URL de encuesta para '%s' en BuildInfo.SURVEY_URLS" % locale)


func test_la_encuesta_se_publica_para_todos_los_idiomas_o_para_ninguno() -> void:
	# El fallo que evita: publicar solo el formulario en español y que quien
	# juegue en inglés se encuentre el botón desactivado sin explicación.
	var configured: Array[String] = []
	for locale in I18n.SUPPORTED_LOCALES:
		if BuildInfo.has_survey(locale):
			configured.append(locale)
	if configured.is_empty():
		return  # Todavía sin publicar: el panel deshabilita el botón.
	assert_eq(configured.size(), I18n.SUPPORTED_LOCALES.size(),
		"solo %s tienen encuesta" % str(configured))


func test_un_idioma_sin_encuesta_no_devuelve_basura() -> void:
	assert_eq(BuildInfo.survey_url("xx"), "")
	assert_false(BuildInfo.has_survey("xx"))


# ─────────────────────────────────────────────────────────────────────────────
# Textos del panel
# ─────────────────────────────────────────────────────────────────────────────

func test_los_textos_del_panel_existen_en_el_csv() -> void:
	var keys := _load_csv_keys()
	assert_gt(keys.size(), 50, "no se pudieron leer las claves de %s" % _CSV_PATH)
	for key in _PANEL_KEYS:
		assert_true(keys.has(key), "la clave '%s' no existe en translations.csv" % key)


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
