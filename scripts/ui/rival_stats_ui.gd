extends PanelContainer
class_name RivalStatsUI

## Panel desplegable que muestra las estadísticas públicas del imperio rival.
## Se muestra/oculta con animación desde general_ui.gd al pulsar el botón toggle
## de la barra superior.

@onready var color_indicator: ColorRect = $Content/Header/ColorIndicator
@onready var empire_name: Label = %EmpireName
@onready var tile_count: Label = %TileCount
@onready var gold_value: Label = %GoldValue
@onready var gold_per_turn: Label = %GoldPerTurn
@onready var food_value: Label = %FoodValue
@onready var cards_value: Label = %CardsValue


func update_stats(p_stats: Stats) -> void:
	if not is_node_ready():
		await ready
	if p_stats == null:
		return

	if p_stats.empire != null:
		color_indicator.color = p_stats.empire.color
		empire_name.text = p_stats.empire.name
		tile_count.text = "%d tiles" % p_stats.empire.controlled_tiles.size()

	gold_value.text = str(p_stats.total_gold)

	if p_stats.gold_per_turn >= 0:
		gold_per_turn.text = "+%d/turn" % p_stats.gold_per_turn
		gold_per_turn.add_theme_color_override("font_color", UITheme.VALUE_POSITIVE)
	else:
		gold_per_turn.text = "%d/turn" % p_stats.gold_per_turn
		gold_per_turn.add_theme_color_override("font_color", UITheme.VALUE_NEGATIVE)

	if p_stats.food >= 0:
		food_value.text = "+%d" % p_stats.food
		food_value.add_theme_color_override("font_color", UITheme.VALUE_POSITIVE)
	else:
		food_value.text = str(p_stats.food)
		food_value.add_theme_color_override("font_color", UITheme.VALUE_NEGATIVE)

	var bonus := 0
	if p_stats.modifier_manager != null:
		bonus = p_stats.modifier_manager.get_cards_per_turn_bonus()
	cards_value.text = str(clampi(p_stats.cards_per_turn + bonus, 1, 20))
