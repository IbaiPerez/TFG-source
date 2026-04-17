extends Control
class_name StatsUI

@onready var gold: Label = %Gold
@onready var gold_generation: Label = %GoldGeneration
@onready var food_generation: Label = %FoodGeneration
@onready var modifiers_panel: ModifiersPanel = %ModifiersPanel


func update_stats(stats: Stats) -> void:
	if stats.gold_per_turn < 0:
		gold_generation.text = str(stats.gold_per_turn)
		gold_generation.label_settings.font_color = Color.DARK_RED
	else:
		gold_generation.text = "+" + str(stats.gold_per_turn)
		gold_generation.label_settings.font_color = Color(0.10196079, 0.3882353, 0.10196079, 1)

	if stats.food < 0:
		food_generation.text = str(stats.food)
		food_generation.label_settings.font_color = Color.DARK_RED
	else:
		food_generation.text = "+" + str(stats.food)
		food_generation.label_settings.font_color = Color(0.10196079, 0.3882353, 0.10196079, 1)

	gold.text = str(stats.total_gold)


func set_modifier_manager(mm:ModifierManager) -> void:
	if not is_node_ready():
		await ready
	modifiers_panel.modifier_manager = mm
