extends Resource
class_name Stats

signal stats_changed

@export var initial_gold:int
@export var starting_deck:CardPile
@export var cards_per_turn:int:set = set_cards_per_turn

var gold:int:set = set_gold
var food:int:set = set_food

var deck:CardPile
var discard_pile:CardPile
var hand:CardPile

func set_cards_per_turn(value:int) -> void:
	cards_per_turn = clampi(value,1,20)
	stats_changed.emit()

func set_gold(value:int) -> void:
	gold = value
	stats_changed.emit()

func set_food(value:int) -> void:
	food = value
	stats_changed.emit()


func create_instance() -> Resource:
	var instance:Stats = self.duplicate()
	instance.gold = initial_gold
	instance.food = 0
	instance.deck = instance.starting_deck.duplicate()
	instance.hand = CardPile.new()
	instance.discard_pile = CardPile.new()
	return instance
