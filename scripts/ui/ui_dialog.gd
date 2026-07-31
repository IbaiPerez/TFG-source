extends RefCounted
class_name UIDialog

## Andamiaje de los diálogos a pantalla completa construidos por código
## (TutorialPanel, SaveLoadPanel): velo oscuro + panel centrado + botones.
##
## No es un helper especulativo: las dos implementaciones eran idénticas salvo en
## el tamaño mínimo del panel, la separación del vbox y el ancho del botón. Los dos
## `_make_button` diferían en UN número —100 frente a 120— y repetían las mismas 12
## líneas de estilos.
##
## Solo cubre el andamiaje. El contenido lo monta cada panel, que es lo que de
## verdad los distingue.


## Velo semitransparente que tapa el juego y se come los clics para que no lleguen
## a lo que hay detrás.
static func add_dim_background(root: CanvasLayer) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = UITheme.OVERLAY_DARK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bg)
	return bg


## Monta centrador → panel con estilo de pergamino → vbox, y devuelve el vbox,
## que es donde el llamante cuelga su contenido.
static func add_centered_panel(root: CanvasLayer, min_size: Vector2,
		separation: int) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_style())
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", separation)
	panel.add_child(vbox)
	return vbox


## Título del diálogo, centrado y en el marrón del tema.
static func make_title(text: String) -> Label:
	var title := Label.new()
	title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UITheme.BORDER_BROWN)
	return title


## Tema de pergamino para un ItemList, con los estados de selección resueltos para
## que el texto siga siendo legible y sin el rectángulo blanco de foco.
##
## Estaba escrito dos veces, palabra por palabra salvo el tamaño de fuente.
static func apply_item_list_theme(list: ItemList, font_size: int = 16) -> void:
	list.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.BORDER_BROWN, 2, 6))

	var sel_style := StyleBoxFlat.new()
	sel_style.bg_color = Color(UITheme.BORDER_BROWN.r, UITheme.BORDER_BROWN.g,
			UITheme.BORDER_BROWN.b, 0.22)
	sel_style.corner_radius_top_left     = 4
	sel_style.corner_radius_top_right    = 4
	sel_style.corner_radius_bottom_right = 4
	sel_style.corner_radius_bottom_left  = 4
	sel_style.content_margin_left   = 6
	sel_style.content_margin_top    = 3
	sel_style.content_margin_right  = 6
	sel_style.content_margin_bottom = 3
	list.add_theme_stylebox_override("selected", sel_style)
	list.add_theme_stylebox_override("selected_focus", sel_style)

	list.add_theme_stylebox_override("cursor", StyleBoxEmpty.new())
	list.add_theme_stylebox_override("cursor_unfocused", StyleBoxEmpty.new())

	list.add_theme_color_override("font_color", UITheme.TEXT_DARK)
	list.add_theme_color_override("font_selected_color", UITheme.BORDER_BROWN)
	list.add_theme_color_override("font_hovered_color", UITheme.BORDER_BROWN)

	list.add_theme_font_size_override("font_size", font_size)


## Botón del pie del diálogo, con los estados de hover/pulsado del tema y sin
## rectángulo de foco.
static func make_button(text: String, callback: Callable, width: int = 120) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(width, 38)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", UITheme.TEXT_DARK)
	btn.add_theme_color_override("font_hover_color", UITheme.BORDER_BROWN)
	btn.add_theme_color_override("font_pressed_color", UITheme.BORDER_BROWN)
	btn.add_theme_stylebox_override("normal", UITheme.make_panel_style(UITheme.BORDER_BROWN, 2, 8))
	btn.add_theme_stylebox_override("hover", UITheme.make_panel_hover_style(UITheme.BORDER_BROWN, 2, 8))
	btn.add_theme_stylebox_override("pressed", UITheme.make_panel_style(UITheme.BORDER_BROWN, 3, 8))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pressed.connect(callback)
	return btn
