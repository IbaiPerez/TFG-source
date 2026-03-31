extends Card
class_name CardDrawCard

@export var amount:int = 1

func apply_effects(targets:Array[Node],_stats:Stats) -> void:
	var effect = DrawCardEffect.new()
	effect.cards_to_draw = amount
	effect.execute(targets)
