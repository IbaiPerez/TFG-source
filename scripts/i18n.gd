extends Node
## Autoload de localización (i18n).
##
## Registra las traducciones del CSV canónico (`res://localization/translations.csv`)
## en el TranslationServer y gestiona el cambio y la persistencia del idioma.
##
## El texto visible se traduce de dos formas:
##   - Controles (Label/Button/OptionButton/...): auto-traducción de su propiedad
##     `text` cuando esta contiene una CLAVE definida en el CSV.
##   - Cadenas dinámicas (formato con `%`, BBCode generado en código): vía
##     `tr("CLAVE")` (o el helper `I18n.format(...)`).
##
## Las traducciones se cargan por el sistema estándar de Godot: el CSV se importa
## a archivos `.translation` registrados en project.godot
## (`internationalization/locale/translations`). Este autoload solo resuelve,
## cambia y persiste el idioma activo. El CSV original sigue accesible vía
## FileAccess en el editor/tests (p.ej. para validar cobertura en test_i18n).

const CSV_PATH := "res://localization/translations.csv"
const CONFIG_PATH := "user://settings.cfg"
const CONFIG_SECTION := "localization"
const CONFIG_KEY := "locale"

## Idiomas soportados (códigos de locale). El primero es el de respaldo.
const SUPPORTED_LOCALES: PackedStringArray = ["es", "en"]
const DEFAULT_LOCALE := "es"

## Nombre nativo de cada idioma, para poblar selectores. Cada idioma se muestra
## en su propio idioma (no se traduce).
const LOCALE_NAMES := {
	"es": "Español",
	"en": "English",
}

signal locale_changed(locale: String)


func _ready() -> void:
	TranslationServer.set_locale(_resolve_initial_locale())


## Locale inicial: el guardado por el usuario > el idioma del SO (si soportado) >
## el idioma por defecto.
func _resolve_initial_locale() -> String:
	var saved := _load_saved_locale()
	if saved != "":
		return saved
	var os_lang := OS.get_locale_language()
	if os_lang in SUPPORTED_LOCALES:
		return os_lang
	return DEFAULT_LOCALE


## Cambia el idioma activo (retraduce los Controles vivos) y lo persiste.
func set_locale(locale: String) -> void:
	if locale not in SUPPORTED_LOCALES:
		push_warning("[I18n] Locale no soportado: %s" % locale)
		return
	TranslationServer.set_locale(locale)
	_save_locale(locale)
	locale_changed.emit(locale)


## Código de idioma activo ("es"/"en").
func get_current_locale() -> String:
	return TranslationServer.get_locale().substr(0, 2)


## Helper para cadenas con formato: `I18n.format("SHOP_GOLD", [oro])`.
## Equivale a `tr(key) % args` pero acepta tanto un valor suelto como un Array.
func format(key: String, args) -> String:
	if args is Array:
		return tr(key) % args
	return tr(key) % [args]


func _load_saved_locale() -> String:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return ""
	var value: String = config.get_value(CONFIG_SECTION, CONFIG_KEY, "")
	return value if value in SUPPORTED_LOCALES else ""


func _save_locale(locale: String) -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)  # se ignora el error si aún no existe
	config.set_value(CONFIG_SECTION, CONFIG_KEY, locale)
	config.save(CONFIG_PATH)
