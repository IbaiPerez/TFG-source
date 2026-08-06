extends CanvasLayer
class_name CreditsPanel

## Créditos del juego.
##
## No es un adorno: la iconografía procede de game-icons.net bajo licencia
## CC BY 3.0, que EXIGE atribuir a los autores allí donde se distribuya la obra.
## Esta pantalla es lo que cumple esa condición en la build publicada; la memoria
## del TFG la cumple por su lado en el apartado de recursos de terceros.
##
## Por eso la mención de game-icons.net no puede quitarse de aquí sin sustituir
## los iconos: no es una cortesía, es la condición de uso.

## Autores de los iconos empleados, con cuántos símbolos aporta cada uno.
## La licencia pide reconocer al AUTOR, no solo a la web que los aloja.
const ICON_AUTHORS: Array[String] = [
	"Delapouite", "Lorc", "Quoting", "Faithtoken", "Willdabeast", "Cathelineau",
]

## Mención literal que pide game-icons.net. Se deja en inglés a propósito: es la
## fórmula de atribución de la fuente, no texto de interfaz que deba traducirse.
const ICON_NOTICE := "Icons by Lorc, Delapouite & contributors — game-icons.net (CC BY 3.0)"
const ICON_LICENSE_URL := "https://creativecommons.org/licenses/by/3.0/"


func _ready() -> void:
	layer = 10
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()


# ─────────────────────────────────────────────────────────────────────────────
# Construcción de la interfaz
# ─────────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	UIDialog.add_dim_background(self)

	# Alto holgado a propósito: el enlace de la licencia es largo y, si el panel
	# se queda justo, la última línea se corta a media altura en vez de envolver
	# limpiamente.
	var vbox := UIDialog.add_centered_panel(self, Vector2(680, 520), 10)
	vbox.add_child(UIDialog.make_title(tr("MENU_CREDITS")))
	vbox.add_child(HSeparator.new())
	vbox.add_child(_make_body())
	vbox.add_child(HSeparator.new())
	vbox.add_child(_make_footer())


## Cuerpo desplazable: desarrollo + atribución de los recursos gráficos.
func _make_body() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)

	content.add_child(_make_section(tr("CREDITS_DEVELOPMENT")))
	content.add_child(_make_text(tr("CREDITS_AUTHOR")))
	content.add_child(_make_text(tr("CREDITS_ENGINE")))

	content.add_child(_make_spacer())
	content.add_child(_make_section(tr("CREDITS_ART")))
	content.add_child(_make_text(tr("CREDITS_ART_INTRO")))
	content.add_child(_make_text("• " + ", ".join(ICON_AUTHORS)))
	content.add_child(_make_notice())
	# El enlace va en su propia línea: pegado al texto de la licencia envolvía por
	# la mitad de la URL, que queda ilegible.
	content.add_child(_make_text(tr("CREDITS_ART_LICENSE")))
	content.add_child(_make_text(ICON_LICENSE_URL))

	scroll.add_child(content)
	return scroll


## La mención literal exigida por la licencia, destacada del resto del texto.
func _make_notice() -> Label:
	var label := _make_text(ICON_NOTICE)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", UITheme.BORDER_BROWN)
	return label


func _make_section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", UITheme.TEXT_DARK)
	return label


func _make_text(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", UITheme.TEXT_SECONDARY)
	return label


func _make_spacer() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	return spacer


func _make_footer() -> HBoxContainer:
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_child(UIDialog.make_button(tr("UI_CLOSE"), _on_close_pressed, 120))
	return footer


func _on_close_pressed() -> void:
	queue_free()
