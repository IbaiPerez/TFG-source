extends HBoxContainer
class_name StatsUI

@onready var gold: Label = %Gold
@onready var gold_generation: Label = %GoldGeneration
@onready var food_generation: Label = %FoodGeneration
@onready var gold_container: HBoxContainer = $GoldContainer
@onready var food_container: HBoxContainer = $FoodContainer

func update_stats(stats: Stats) -> void:
	if stats.gold < 0:
		gold_generation.text = "-" + str(stats.gold)
		gold_generation.label_settings.font_color = Color.DARK_RED
	else:
		gold_generation.text = "+" + str(stats.gold)
		gold_generation.label_settings.font_color = Color.LIGHT_GREEN
	
	if stats.food < 0:
		food_generation.label_settings.font_color = Color.DARK_RED
	else:
		food_generation.label_settings.font_color = Color.LIGHT_GREEN
	food_generation.text = str(stats.food)
	
