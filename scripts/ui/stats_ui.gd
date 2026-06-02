extends Control
class_name StatsUI

@onready var gold: Label = %Gold
@onready var gold_generation: Label = %GoldGeneration
@onready var food_generation: Label = %FoodGeneration
@onready var modifiers_panel: ModifiersPanel = %ModifiersPanel
@onready var troop_pool_button: TroopPoolOpener = %TroopPoolButton


func update_stats(stats: Stats) -> void:
	if stats.gold_per_turn < 0:
		gold_generation.text = str(stats.gold_per_turn)
		gold_generation.add_theme_color_override("font_color", UITheme.VALUE_NEGATIVE)
	else:
		gold_generation.text = "+" + str(stats.gold_per_turn)
		gold_generation.add_theme_color_override("font_color", UITheme.VALUE_POSITIVE)

	if stats.food < 0:
		food_generation.text = str(stats.food)
		food_generation.add_theme_color_override("font_color", UITheme.VALUE_NEGATIVE)
	else:
		food_generation.text = "+" + str(stats.food)
		food_generation.add_theme_color_override("font_color", UITheme.VALUE_POSITIVE)

	gold.text = str(stats.total_gold)


func set_modifier_manager(mm:ModifierManager) -> void:
	if not is_node_ready():
		await ready
	modifiers_panel.modifier_manager = mm
