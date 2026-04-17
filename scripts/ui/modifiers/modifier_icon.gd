extends Control
class_name ModifierIcon

## Icono de un modificador activo en la UI.
## Muestra el icono del modificador y los turnos restantes.
## Al pasar el raton por encima muestra un tooltip con el nombre,
## descripcion y duracion del modificador.

@export var normal_style:StyleBox
@export var permanent_style:StyleBox

@onready var background: PanelContainer = %Background
@onready var icon_rect: TextureRect = %Icon
@onready var duration_label: Label = %DurationLabel
@onready var tooltip: Tooltip = %Tooltip

var modifier:Modifier:set = _set_modifier


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_refresh()


func _set_modifier(value:Modifier) -> void:
	modifier = value
	if not is_node_ready():
		await ready
	_refresh()


func _refresh() -> void:
	if not modifier:
		return

	icon_rect.texture = modifier.icon

	if modifier.duration == -1:
		duration_label.text = "∞"
		if permanent_style:
			background.add_theme_stylebox_override("panel", permanent_style)
	else:
		duration_label.text = str(modifier.duration)
		if normal_style:
			background.add_theme_stylebox_override("panel", normal_style)


func _on_mouse_entered() -> void:
	if not modifier:
		return

	var dur_text:String
	if modifier.duration == -1:
		dur_text = "[color=#8a6a1a]Permanente[/color]"
	elif modifier.duration == 1:
		dur_text = "[color=#5a3a12]Turnos restantes: 1[/color]"
	else:
		dur_text = "[color=#5a3a12]Turnos restantes: %d[/color]" % modifier.duration

	var text := "[b]%s[/b]\n\n%s\n\n%s" % [modifier.name, modifier.description, dur_text]
	tooltip.show_tooltip(text)


func _on_mouse_exited() -> void:
	tooltip.hide_tooltip()
