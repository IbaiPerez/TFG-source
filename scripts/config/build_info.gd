extends RefCounted
class_name BuildInfo

## Identidad de la build publicada y destino de la encuesta de feedback.
##
## La versión NO se escribe aquí: se lee de `application/config/version`, que es
## lo que Godot estampa en el ejecutable al exportar. Tenerla en dos sitios
## acabaría haciendo que un informe de partida atribuyera un fallo a la build
## equivocada, que es exactamente lo que el informe existe para evitar.
##
## Las URLs sí viven aquí porque no hay ajuste de proyecto para ellas. Hay una
## por idioma: el formulario se rellena en el idioma en que se jugó, y un único
## formulario mezclado obliga después a separar las respuestas a mano.
##
## Este módulo no referencia ninguna clase del juego: es config, y un ciclo de
## referencias desde aquí rompería el `load()` de los `.tres` en ejecución sin
## dar ningún error de parseo.

const VERSION_SETTING := "application/config/version"

## Se usa cuando el ajuste está vacío, que es el caso al correr desde el editor
## o los tests. Marca el informe como "no es una build publicada".
const UNKNOWN_VERSION := "dev"

## Formulario de encuesta por locale. Vacío = todavía sin publicar: el panel de
## feedback deshabilita el botón en vez de abrir una URL rota, así que la build
## es utilizable aunque los formularios lleguen más tarde.
const SURVEY_URLS := {
	"es": "",
	"en": "",
}


## Versión declarada del proyecto, o [constant UNKNOWN_VERSION] si no hay.
static func version() -> String:
	var value := str(ProjectSettings.get_setting(VERSION_SETTING, ""))
	return value if value != "" else UNKNOWN_VERSION


## URL de la encuesta para `locale`, o "" si ese idioma no tiene formulario.
static func survey_url(locale: String) -> String:
	return str(SURVEY_URLS.get(locale, ""))


static func has_survey(locale: String) -> bool:
	return survey_url(locale) != ""
