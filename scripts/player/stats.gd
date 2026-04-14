extends Resource
class_name Stats

signal stats_changed

@export var initial_gold:int
@export var initial_gold_per_turn:int
@export var starting_deck:CardPile
@export var cards_per_turn:int:set = set_cards_per_turn

var total_gold:int:set = set_gold
var gold_per_turn:int:set = set_gold_per_turn
var food:int:set = set_food

var deck:CardPile
var discard_pile:CardPile
var draw_pile:CardPile
var played_pile:CardPile

@export var empire:Empire
@export var event_chance:float = 0.5
@export var available_events:Array[TurnEvent] = []
var used_unique_events:Array[String] = []
var turn_number:int = 0


func set_cards_per_turn(value:int) -> void:
	cards_per_turn = clampi(value,1,20)
	stats_changed.emit()

func set_gold(value:int) -> void:
	total_gold = value
	stats_changed.emit()

func set_gold_per_turn(value:int) -> void:
	gold_per_turn = value
	stats_changed.emit()

func set_food(value:int) -> void:
	food = value
	stats_changed.emit()


func create_instance() -> Resource:
	var instance:Stats = self.duplicate()
	instance.total_gold = initial_gold
	instance.gold_per_turn = initial_gold_per_turn
	instance.food = 0
	instance.deck = instance.starting_deck.duplicate()
	instance.draw_pile = CardPile.new()
	instance.discard_pile = CardPile.new()
	instance.played_pile = CardPile.new()
	instance.empire = empire
	instance.used_unique_events = []
	instance.turn_number = 0
	return instance
