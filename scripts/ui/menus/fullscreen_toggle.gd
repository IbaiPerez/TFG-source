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
	if current_mode == Window.MODE_WINDOWED:
		text = "Fullscreen: OFF"
	else:
		text = "Fullscreen: ON"
	print("Window mode: ", current_mode)
