extends Control
class_name CardPileView

const CARD_MENU_UI = preload("uid://bt76i1liwhags")

@export var card_pile:CardPile

@onready var title: Label = %Title
@onready var cards_container: GridContainer = %CardsContainer
@onready var back_button: Button = %BackButton
@onready var card_tooltip_popup: CardTooltipPopup = %CardTooltipPopup


func _ready() -> void:
	back_button.pressed.connect(hide)
	
	for card:Node in cards_container.get_children():
		card.queue_free()
	
	card_tooltip_popup.hide_tooltip()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if card_tooltip_popup.visible:
			card_tooltip_popup.hide_tooltip()
		else:
			hide()

func show_current_view(new_title:String, randomized:bool = false) -> void:
	for card:Node in cards_container.get_children():
		card.queue_free()
	
	card_tooltip_popup.hide_tooltip()
	title.text = new_title
	_update_view.call_deferred(randomized)

func _update_view(randomized:bool) -> void:
	if not card_pile:
		return
	var all_cards := card_pile.cards.duplicate()
	if randomized:
		all_cards.shuffle()

	if all_cards.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No hay cartas"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		empty_label.add_theme_font_size_override("font_size", 18)
		cards_container.add_child(empty_label)
	else:
		for card:Card in all_cards:
			var new_card := CARD_MENU_UI.instantiate() as CardMenuUi
			cards_container.add_child(new_card)
			new_card.card = card
			new_card.tooltip_requested.connect(card_tooltip_popup.show_tooltip)

	show()
	
