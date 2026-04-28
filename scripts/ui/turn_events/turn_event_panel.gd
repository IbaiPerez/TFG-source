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

## Almacena la choice pendiente mientras el jugador selecciona una tile.
var _pending_tile_choice:TurnEventChoice = null
## Almacena la choice pendiente mientras el jugador selecciona una carta.
var _pending_card_choice:TurnEventChoice = null


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
		title_label.add_theme_constant_override("outline_size", 8)
		title_label.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.0))
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
	# Selección de tile: ocultar panel, resaltar tiles elegibles, esperar click
	if choice.needs_tile_input():
		_start_tile_selection(choice)
		return

	# Selección de carta: ocultar panel, mostrar candidatas, esperar click
	if choice.needs_player_input():
		_start_card_selection(choice)
		return

	turn_event_manager.resolve(event, choice, context)
	Events.turn_event_resolved.emit()
	queue_free()


func _start_tile_selection(choice:TurnEventChoice) -> void:
	_pending_tile_choice = choice
	var tile_effect = choice.get_tile_effect() as UrbanizeToMegalopolisEffect
	if tile_effect == null:
		push_warning("Choice necesita tile input pero no tiene UrbanizeToMegalopolisEffect")
		return

	var eligible := tile_effect.get_eligible_tiles(context)
	if eligible.is_empty():
		push_warning("No hay tiles elegibles para Megalopolis")
		return

	# Ocultar el panel mientras el jugador selecciona
	visible = false

	# Resaltar tiles elegibles y pedir selección
	Events.request_tile_selection.emit(eligible)
	Events.tile_selection_made.connect(_on_tile_selected, CONNECT_ONE_SHOT)
	Events.tile_selection_cancelled.connect(_on_tile_selection_cancelled, CONNECT_ONE_SHOT)


func _on_tile_selected(tile:Tile) -> void:
	if Events.tile_selection_cancelled.is_connected(_on_tile_selection_cancelled):
		Events.tile_selection_cancelled.disconnect(_on_tile_selection_cancelled)

	if _pending_tile_choice == null:
		return

	var choice := _pending_tile_choice
	_pending_tile_choice = null

	# Pagar el coste del evento
	if choice.cost:
		choice.cost.pay(context)

	# Ejecutar el efecto de urbanización con la tile elegida
	var tile_effect = choice.get_tile_effect() as UrbanizeToMegalopolisEffect
	if tile_effect:
		tile_effect.execute_with_tile(tile, context.stats)

	# Ejecutar los demás efectos que no sean de tile
	for effect in choice.effects:
		if not effect.needs_tile_input():
			effect.execute(context)

	if event.unique:
		context.stats.used_unique_events.append(event.id)

	Events.turn_event_resolved.emit()
	queue_free()


func _on_tile_selection_cancelled() -> void:
	if Events.tile_selection_made.is_connected(_on_tile_selected):
		Events.tile_selection_made.disconnect(_on_tile_selected)

	_pending_tile_choice = null
	visible = true


func _start_card_selection(choice:TurnEventChoice) -> void:
	_pending_card_choice = choice

	# Buscar el efecto que necesita input del jugador para obtener candidatas
	var candidates:Array[Card] = []
	for effect in choice.effects:
		if effect.needs_player_input() and effect is RemoveCardEventEffect:
			candidates = effect.get_candidates(context.stats)
			break

	if candidates.is_empty():
		push_warning("No hay cartas candidatas para seleccionar")
		return

	# Ocultar el panel mientras el jugador selecciona
	visible = false

	Events.request_card_selection.emit(candidates)
	Events.card_selection_made.connect(_on_card_selected, CONNECT_ONE_SHOT)
	Events.card_selection_cancelled.connect(_on_card_selection_cancelled, CONNECT_ONE_SHOT)


func _on_card_selected(card:Card) -> void:
	if Events.card_selection_cancelled.is_connected(_on_card_selection_cancelled):
		Events.card_selection_cancelled.disconnect(_on_card_selection_cancelled)

	if _pending_card_choice == null:
		return

	var choice := _pending_card_choice
	_pending_card_choice = null

	# Ejecutar efectos pasando la carta elegida
	for i in choice.effects.size():
		if choice.effects[i].needs_player_input():
			choice.effects[i].execute(context, card)
		else:
			choice.effects[i].execute(context)

	if event.unique:
		context.stats.used_unique_events.append(event.id)

	Events.turn_event_resolved.emit()
	queue_free()


func _on_card_selection_cancelled() -> void:
	if Events.card_selection_made.is_connected(_on_card_selected):
		Events.card_selection_made.disconnect(_on_card_selected)

	_pending_card_choice = null
	visible = true
