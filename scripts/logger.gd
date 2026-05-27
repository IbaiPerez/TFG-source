extends Node
class_name AppLogger

## Centralized logging autoload.
##
## Usage:
##   GameLogger.debug("message")
##   GameLogger.info("message")
##   GameLogger.warn("message")
##   GameLogger.error("message")
##   GameLogger.set_level(GameLogger.Level.WARN)  # suppress debug/info in release

enum Level { DEBUG = 0, INFO = 1, WARN = 2, ERROR = 3 }

var current_level: int = Level.DEBUG

const _COLORS := {
	Level.DEBUG: "",
	Level.INFO:  "",
	Level.WARN:  "",
	Level.ERROR: "",
}

const _LABELS := {
	Level.DEBUG: "DEBUG",
	Level.INFO:  "INFO ",
	Level.WARN:  "WARN ",
	Level.ERROR: "ERROR",
}


func set_level(level: int) -> void:
	current_level = level


func debug(msg: String) -> void:
	_log(Level.DEBUG, msg)


func info(msg: String) -> void:
	_log(Level.INFO, msg)


func warn(msg: String) -> void:
	_log(Level.WARN, msg)


func error(msg: String) -> void:
	_log(Level.ERROR, msg)


func _log(level: int, msg: String) -> void:
	if level < current_level:
		return
	var ts := Time.get_time_string_from_system()
	print("[%s][%s] %s" % [ts, _LABELS[level], msg])
