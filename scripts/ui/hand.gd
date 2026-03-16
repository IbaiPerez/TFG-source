extends HBoxContainer
class_name Hand

@export var stats:Stats
@onready var card_ui = preload("uid://cf5a8tg1tqyy7")

var cards_played_this_turn := 0

func _ready() -> void:
	Events.card_played.connect(_on_card_played)

func add_card(card:Card) -> void:
	var new_card_ui := card_ui.instantiate()
	add_child(new_card_ui)
	new_card_ui.reparent_requested.connect(_on_card_ui_reparent_requested)
	new_card_ui.card = card
	new_card_ui.parent = self
	new_card_ui.stats = stats

func discard_card(card:CardUI) -> void:
	card.queue_free()

func _on_card_played() -> void:
	cards_played_this_turn += 1

func _on_card_ui_reparent_requested(child:CardUI) -> void:
	child.reparent(self)
