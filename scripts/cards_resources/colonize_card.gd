extends Card
class_name ColonizeCard


func apply_effects(targets:Array[Node],stats:Stats) -> void:
	var effect := ColonizeEffect.new()
	effect.controller = stats.empire
	effect.execute(targets)
	
