extends Card
class_name CardDrawCard

func apply_effects(targets:Array[Node],_stats:Stats) -> void:
	var effect = DrawCardEffect.new()
	effect.cards_to_draw = 1
	effect.execute(targets)
