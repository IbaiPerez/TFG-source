extends Control
class_name StatsUI

@onready var gold: Label = %Gold
@onready var gold_generation: Label = %GoldGeneration
@onready var food_generation: Label = %FoodGeneration
@onready var gold_container: HBoxContainer = $GoldContainer
@onready var food_container: HBoxContainer = $FoodContainer
@onready var discard_pile: Label = $DiscardPile
@onready var draw_pile: Label = $DrawPile


func update_stats(stats: Stats) -> void:
	if stats.gold_per_turn < 0:
		gold_generation.text = "-" + str(stats.gold_gold_per_turn)
		gold_generation.label_settings.font_color = Color.DARK_RED
	else:
		gold_generation.text = "+" + str(stats.gold_per_turn)
		gold_generation.label_settings.font_color = Color.DARK_GREEN
	
	if stats.food < 0:
		food_generation.label_settings.font_color = Color.DARK_RED
	else:
		food_generation.label_settings.font_color = Color.DARK_GREEN
	food_generation.text = str(stats.food)
	gold.text = str(stats.total_gold)
	discard_pile.text = str(stats.discard_pile.cards.size())
	draw_pile.text = str(stats.draw_pile.cards.size())
