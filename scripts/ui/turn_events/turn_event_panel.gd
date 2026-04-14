extends PanelContainer
class_name TurnEventPanel

const CHOICE_BUTTON = preload("uid://cy8rzkchoicebtn")
const UNIQUE_TITLE_MATERIAL = preload("uid://cx5evuniqtitle")

@onready var title_label: Label = %TitleLabel
@onready var event_image: TextureRect = %EventImage
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var choices_container: VBoxContainer = %ChoicesContainer

var event:TurnEvent
var context:EventContext
var turn_event_manager:TurnEventManager


func setup(p_event:TurnEvent, p_context:EventContext,
		p_manager:TurnEventManager) -> void:
	if not is_node_ready():
		await ready

	event = p_event
	context = p_context
	turn_event_manager = p_manager

	title_label.text = event.title
	description_label.text = event.description

	# Imagen del evento (opcional)
	if event.icon != null:
		event_image.texture = event.icon
		event_image.visible = true
	else:
		event_image.visible = false

	# Estilo especial para eventos unicos
	if event.unique:
		title_label.material = UNIQUE_TITLE_MATERIAL
		title_label.add_theme_constant_override("outline_size", 6)
		title_label.add_theme_color_override("font_outline_color", Color(0.3, 0.2, 0.0))
	else:
		title_label.material = null

	_populate_choices()


func _populate_choices() -> void:
	for child in choices_container.get_children():
		child.queue_free()

	for choice in event.choices:
		_add_choice_button(choice, choice.is_affordable(context))

	if event.allow_skip:
		var skip_choice := TurnEventChoice.new()
		skip_choice.label = "No hacer nada"
		skip_choice.description = "Declinar el evento y continuar el turno."
		_add_choice_button(skip_choice, true)


func _add_choice_button(choice:TurnEventChoice, is_affordable:bool) -> void:
	var btn:TurnEventChoiceButton = CHOICE_BUTTON.instantiate()
	choices_container.add_child(btn)
	btn.setup(choice, is_affordable)
	btn.choice_selected.connect(_on_choice_selected)


func _on_choice_selected(choice:TurnEventChoice) -> void:
	# TODO: cuando una opcion necesite seleccion de carta, abrir sub-panel
	if choice.needs_player_input():
		push_warning("Esta opcion requiere seleccion de carta (pendiente de implementar)")
		return

	turn_event_manager.resolve(event, choice, context)
	Events.turn_event_resolved.emit()
	queue_free()
