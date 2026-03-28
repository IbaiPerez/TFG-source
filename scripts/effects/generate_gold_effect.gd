extends Effect
class_name GenerateGoldEffect

var amount := 0
var stats:Stats

func execute(_targets: Array[Node]) -> void:
	if not stats:
		return
	stats.total_gold += amount
