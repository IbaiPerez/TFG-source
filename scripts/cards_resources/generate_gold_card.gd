extends Card
class_name GenerateGoldCard

var base_generation := 30

func apply_effects(targets:Array[Node],stats:Stats) -> void:
	var effect := GenerateGoldEffect.new()
	effect.amount = base_generation
	effect.stats = stats
	effect.execute(targets)
