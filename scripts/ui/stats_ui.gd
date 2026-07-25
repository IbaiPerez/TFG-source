extends Control
class_name StatsUI

@onready var gold: Label = %Gold
@onready var gold_generation: Label = %GoldGeneration
@onready var food_generation: Label = %FoodGeneration
@onready var modifiers_panel: ModifiersPanel = %ModifiersPanel
@onready var troop_pool_button: TroopPoolOpener = %TroopPoolButton
@onready var rival_info_button: Button = %RivalInfoButton


func update_stats(stats: Stats) -> void:
	UITheme.apply_signed(gold_generation, stats.gold_per_turn)
	UITheme.apply_signed(food_generation, stats.food)
	gold.text = str(stats.total_gold)


func set_modifier_manager(mm:ModifierManager) -> void:
	if not is_node_ready():
		await ready
	modifiers_panel.modifier_manager = mm


## Activa el botón toggle con el nombre del rival y muestra el indicador de color.
func show_rival_toggle(empire_name: String) -> void:
	if not is_node_ready():
		await ready
	rival_info_button.visible = true
	rival_info_button.text = tr(empire_name) + " ▾"
