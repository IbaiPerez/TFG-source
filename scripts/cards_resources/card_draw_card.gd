extends Card
class_name CardDrawCard

@export var amount:int = 1


func _build_tooltip() -> String:
	if amount == 1:
		return tr("CARD_DRAW_TOOLTIP_ONE")
	return tr("CARD_DRAW_TOOLTIP_N") % amount


func apply_effects(targets:Array[Node],_stats:Stats) -> void:
	var effect = DrawCardEffect.new()
	effect.cards_to_draw = amount
	effect.execute(targets)
