extends Control
class_name CardPileView

const CARD_MENU_UI = preload("uid://bt76i1liwhags")

@export var card_pile:CardPile

@onready var title: Label = %Title
@onready var cards_container: GridContainer = %CardsContainer
@onready var back_button: Button = %BackButton
@onready var card_tooltip_popup: CardTooltipPopup = %CardTooltipPopup
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var empty_state_container: CenterContainer = %EmptyStateContainer
@onready var empty_panel: PanelContainer = %EmptyPanel
@onready var empty_label: Label = %EmptyLabel


func _ready() -> void:
	back_button.pressed.connect(hide)

	for card:Node in cards_container.get_children():
		card.queue_free()

	card_tooltip_popup.hide_tooltip()

	empty_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style())
	empty_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	empty_label.add_theme_font_size_override("font_size", 18)


func _input(event: InputEvent) -> void:
	# Esta vista es persistente (se muestra/oculta, no se libera), asi que
	# solo gestionamos ESC cuando esta visible. Consumimos el input para que
	# no se propague al menu de pausa (que abriria "encima" de esta vista).
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if card_tooltip_popup.visible:
			card_tooltip_popup.hide_tooltip()
		else:
			hide()

func show_current_view(new_title:String, randomized:bool = false) -> void:
	for card:Node in cards_container.get_children():
		card.queue_free()
	
	card_tooltip_popup.hide_tooltip()
	title.text = tr(new_title)
	_update_view.call_deferred(randomized)

func _update_view(randomized:bool) -> void:
	if not card_pile:
		return
	var all_cards := card_pile.cards.duplicate()
	if randomized:
		all_cards.shuffle()

	if all_cards.is_empty():
		scroll_container.hide()
		empty_state_container.show()
	else:
		empty_state_container.hide()
		scroll_container.show()
		for card:Card in all_cards:
			var new_card := CARD_MENU_UI.instantiate() as CardMenuUi
			cards_container.add_child(new_card)
			new_card.card = card
			new_card.tooltip_requested.connect(card_tooltip_popup.show_tooltip)

	show()
	
