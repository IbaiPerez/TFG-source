extends PanelContainer
class_name UIHoverTooltip

## Tooltip propio que se muestra al pasar el ratón por un control.
##
## Existe porque el `tooltip_text` de Godot se posiciona en coordenadas FÍSICAS de
## pantalla, incompatibles con el modo de estirado `canvas_items` que usa el
## proyecto (viewport virtual de 1280x720): el tooltip nativo aparece descolocado.
## Este panel es `top_level` y trabaja en coordenadas virtuales, como el resto de
## la interfaz.
##
## Estaba escrito a mano dentro de `_setup_map_mode_buttons`, mezclado con el
## cableado de los botones de modo de mapa.

var _label: Label


func _init() -> void:
	visible = false
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	custom_minimum_size = Vector2(200, 0)
	add_theme_stylebox_override("panel", UITheme.make_panel_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_color_override("font_color", UITheme.TEXT_DARK)
	_label.add_theme_font_size_override("font_size", 13)
	margin.add_child(_label)


## Engancha el tooltip a `control`: aparecerá con `text_key` (clave de traducción)
## mientras el ratón esté encima.
func attach_to(control: Control, text_key: String) -> void:
	control.mouse_entered.connect(_show_beside.bind(control, text_key))
	control.mouse_exited.connect(hide)


## Se coloca a la IZQUIERDA del control, pegado al borde, y se recorta contra el
## viewport para no salirse. Hace falta esperar un frame: hasta que el panel no se
## ha dibujado con el texto nuevo, su `size` es el anterior y el recorte saldría mal.
func _show_beside(control: Control, text_key: String) -> void:
	_label.text = tr(text_key)
	show()
	await get_tree().process_frame

	var viewport_size := get_viewport_rect().size
	var anchor := control.global_position
	global_position = Vector2(
		clampf(anchor.x - size.x - 8, 0.0, viewport_size.x - size.x),
		clampf(anchor.y, 0.0, viewport_size.y - size.y))
