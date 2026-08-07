extends RefCounted
class_name PlayReport

## Resumen de una partida en una línea, pensado para pegarse en la encuesta.
##
## El formato es FIJO y en inglés aunque el juego esté en español: es un dato
## que hay que poder agrupar y filtrar en la hoja de respuestas, no texto de
## interfaz. Si las etiquetas se tradujeran habría que normalizar dos idiomas
## antes de poder contar nada, y el idioma ya viaja como un campo más.
##
## Va en UNA línea a propósito: las respuestas cortas de un formulario no
## aceptan saltos de línea, y obligar a un campo de párrafo para esto invita a
## que el jugador escriba encima del informe.
##
## La semilla es el campo que más vale. La generación del mundo es determinista
## por semilla (`WorldGenerator.init_seed` siembra también la RNG global), así
## que convierte un "el mapa me tocó fatal" en un mapa que se puede volver a
## generar y mirar.

enum Outcome { VICTORY, DEFEAT, ABANDONED }

## Palabra con la que cada desenlace aparece en el informe. Son literales
## estables: cambiarlos invalida el filtrado de las respuestas ya recogidas.
const OUTCOME_TOKENS := {
	Outcome.VICTORY: "victory",
	Outcome.DEFEAT: "defeat",
	Outcome.ABANDONED: "abandoned",
}

## Los imperios se llaman con su clave de traducción (`EMP_MEDICI_NAME`), que es
## justo lo que interesa aquí por ser independiente del idioma. Se le quitan el
## prefijo y el sufijo para que el informe se lea.
const _EMPIRE_KEY_PREFIX := "EMP_"
const _EMPIRE_KEY_SUFFIX := "_NAME"

const _SEPARATOR := " | "

var version: String = BuildInfo.UNKNOWN_VERSION
var map_seed: int = 0
## Identificador del imperio del jugador, ya desnudo ("medici").
var empire: String = ""
var outcome: int = Outcome.ABANDONED
var turn_number: int = 0
## Fracción del mapa en manos del jugador, en [0, 1].
var map_share: float = 0.0
var locale: String = ""
var platform: String = ""


## Construye el informe con los datos de partida que solo conoce quien lo pide;
## los de la build (versión, idioma, plataforma) los resuelve por su cuenta.
static func capture(p_outcome: int, p_map_seed: int, p_empire_key: String,
		p_turn_number: int, p_owned_tiles: int, p_total_tiles: int) -> PlayReport:
	var report := PlayReport.new()
	report.version = BuildInfo.version()
	report.map_seed = p_map_seed
	report.empire = strip_empire_key(p_empire_key)
	report.outcome = p_outcome
	report.turn_number = p_turn_number
	report.map_share = (float(p_owned_tiles) / float(p_total_tiles)
			if p_total_tiles > 0 else 0.0)
	report.locale = I18n.get_current_locale()
	report.platform = OS.get_name()
	return report


func to_text() -> String:
	var fields: Array[String] = [
		"v" + version,
		"seed %d" % map_seed,
		empire if empire != "" else "?",
		outcome_token(),
		"turn %d" % turn_number,
		"%d%% map" % roundi(map_share * 100.0),
		locale,
		platform,
	]
	return _SEPARATOR.join(fields)


func outcome_token() -> String:
	return str(OUTCOME_TOKENS.get(outcome, OUTCOME_TOKENS[Outcome.ABANDONED]))


## "EMP_MEDICI_NAME" → "medici". Una clave con otra forma se devuelve tal cual:
## es preferible un informe con un nombre feo que uno sin imperio.
static func strip_empire_key(key: String) -> String:
	var stripped := key
	if stripped.begins_with(_EMPIRE_KEY_PREFIX):
		stripped = stripped.substr(_EMPIRE_KEY_PREFIX.length())
	if stripped.ends_with(_EMPIRE_KEY_SUFFIX):
		stripped = stripped.left(stripped.length() - _EMPIRE_KEY_SUFFIX.length())
	return stripped.to_lower()
