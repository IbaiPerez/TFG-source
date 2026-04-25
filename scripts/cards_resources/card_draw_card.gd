extends Card
class_name CardDrawCard

@export var amount:int = 1


func _build_tooltip() -> String:
	if amount == 1:
		return "[center][b][color=#5B7A3A]Roba[/color][/b] una [color=#4A6A8A]carta[/color] extra[/center]"
	return "[center][b][color=#5B7A3A]Roba %d[/color][/b] [color=#4A6A8A]cartas[/color] extra[/center]" % amount


func apply_effects(targets:Array[Node],_stats:Stats) -> void:
	var effect = DrawCardEffect.new()
	effect.cards_to_draw = amount
	effect.execute(targets)
