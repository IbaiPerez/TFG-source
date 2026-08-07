extends CanvasLayer
class_name FeedbackPanel

## Panel de feedback: enseña el resumen copiable de la partida y lleva a la
## encuesta.
##
## Tiene dos entradas y una sola implementación a propósito. Desde el menú de
## pausa recoge al jugador que está ABANDONANDO —justo el que nunca rellena una
## encuesta enlazada desde la página de itch.io, y el que más información
## aporta— y desde el fin de partida hace además de diálogo de resultado.
##
## El resumen se muestra en un campo seleccionable ADEMÁS de copiarse al
## portapapeles: en la build web el navegador puede denegar el portapapeles, y
## sin el campo a la vista el jugador se quedaría sin nada que pegar. Por lo
## mismo la URL de la encuesta se enseña escrita: `OS.shell_open` abre una
## pestaña nueva y el bloqueador de emergentes puede comérsela sin avisar.
##
## Los campos públicos se rellenan ANTES de `add_child`, como `WorldGenerator`
## con sus settings: `_ready()` ya construye la interfaz con ellos.

const PANEL_MIN_SIZE := Vector2(620, 0)
const LAYER := 30

## Cuánto aguanta el botón de copiar diciendo "copiado" antes de volver a su
## texto normal.
const COPIED_FEEDBACK_SECONDS := 2.0

## Informe a mostrar. Sin él el panel no tiene sentido, pero no se rompe: enseña
## la explicación y la encuesta igual.
var report: PlayReport = null

## Título del diálogo. Vacío = el genérico de feedback.
var title_text: String = ""

## Línea bajo el título, para el mensaje de victoria/derrota. Vacío = no se
## muestra.
var subtitle_text: String = ""

## Texto del botón de cierre. Vacío = "cerrar".
var close_text: String = ""

## Se llama al cerrar el panel (el fin de partida la usa para volver al menú).
var on_closed: Callable = Callable()

var _copy_button: Button = null


func _ready() -> void:
	layer = LAYER
	# Explícito y no heredado: el menú de pausa deja el árbol pausado, y desde el
	# fin de partida el padre es el mapa, que no lo está.
	process_mode = Node.PROCESS_MODE_ALWAYS
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

	var vbox := UIDialog.add_centered_panel(self, PANEL_MIN_SIZE, 12)
	var title := title_text if title_text != "" else tr("FEEDBACK_TITLE")
	vbox.add_child(UIDialog.make_title(title))
	if subtitle_text != "":
		vbox.add_child(_make_subtitle())
	vbox.add_child(HSeparator.new())

	vbox.add_child(_make_text(tr("FEEDBACK_INTRO")))
	vbox.add_child(_make_report_field())
	vbox.add_child(_make_actions())
	for node in _make_survey_hint():
		vbox.add_child(node)

	vbox.add_child(HSeparator.new())
	vbox.add_child(_make_footer())


func _make_subtitle() -> Label:
	var label := _make_text(subtitle_text)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", UITheme.TEXT_DARK)
	return label


## El informe, en un campo de solo lectura pero seleccionable: es la vía de
## escape cuando el portapapeles no está disponible.
func _make_report_field() -> LineEdit:
	var field := LineEdit.new()
	field.text = report.to_text() if report != null else ""
	field.editable = false
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_font_size_override("font_size", 15)
	field.add_theme_color_override("font_uneditable_color", UITheme.TEXT_DARK)
	field.add_theme_stylebox_override("read_only",
			UITheme.make_panel_style(UITheme.BORDER_BROWN, 2, 6))
	return field


func _make_actions() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)

	_copy_button = UIDialog.make_button(tr("FEEDBACK_COPY"), _on_copy_pressed, 200)
	row.add_child(_copy_button)

	var survey := UIDialog.make_button(tr("FEEDBACK_OPEN_SURVEY"), _on_survey_pressed, 220)
	survey.disabled = not BuildInfo.has_survey(I18n.get_current_locale())
	if survey.disabled:
		survey.tooltip_text = tr("FEEDBACK_SURVEY_UNAVAILABLE")
	row.add_child(survey)
	return row


## Aviso y URL escrita, solo cuando hay encuesta que abrir.
func _make_survey_hint() -> Array[Control]:
	var url := BuildInfo.survey_url(I18n.get_current_locale())
	if url == "":
		push_warning("[FeedbackPanel] Sin URL de encuesta para el locale activo: "
				+ "el botón queda deshabilitado (ver BuildInfo.SURVEY_URLS).")
		return []

	var hint := _make_text(tr("FEEDBACK_URL_HINT"))
	hint.add_theme_font_size_override("font_size", 13)
	var link := _make_text(url)
	link.add_theme_font_size_override("font_size", 13)
	link.add_theme_color_override("font_color", UITheme.BORDER_BROWN)
	return [hint, link]


func _make_footer() -> HBoxContainer:
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	var label := close_text if close_text != "" else tr("UI_CLOSE")
	footer.add_child(UIDialog.make_button(label, _on_close_pressed, 160))
	return footer


func _make_text(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", UITheme.TEXT_SECONDARY)
	return label


# ─────────────────────────────────────────────────────────────────────────────
# Acciones
# ─────────────────────────────────────────────────────────────────────────────

func _on_copy_pressed() -> void:
	if report == null:
		return
	DisplayServer.clipboard_set(report.to_text())
	_copy_button.text = tr("FEEDBACK_COPIED")
	# El temporizador corre aunque el árbol esté pausado (process_always), que es
	# el caso cuando se llega aquí desde el menú de pausa.
	await get_tree().create_timer(COPIED_FEEDBACK_SECONDS).timeout
	if is_instance_valid(_copy_button):
		_copy_button.text = tr("FEEDBACK_COPY")


func _on_survey_pressed() -> void:
	var url := BuildInfo.survey_url(I18n.get_current_locale())
	if url == "":
		return
	OS.shell_open(url)


func _on_close_pressed() -> void:
	queue_free()
	if on_closed.is_valid():
		on_closed.call()
