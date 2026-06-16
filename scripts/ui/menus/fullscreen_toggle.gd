extends Button

func _ready() -> void:
	pressed.connect(_on_pressed)
	_update_text()

func _on_pressed() -> void:
	var current_mode = get_window().mode
	if current_mode == Window.MODE_WINDOWED:
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	else:
		get_window().mode = Window.MODE_WINDOWED
	_update_text()

func _update_text() -> void:
	var current_mode = get_window().mode
	# Se asigna la CLAVE; el Control la auto-traduce y se re-traduce al cambiar
	# de idioma (NOTIFICATION_TRANSLATION_CHANGED).
	if current_mode == Window.MODE_WINDOWED:
		text = "OPT_FULLSCREEN_OFF"
	else:
		text = "OPT_FULLSCREEN_ON"
