extends Card
class_name GenerateGoldCard

@export var amount := 30


func _build_tooltip() -> String:
	return "[center][b][color=yellow]Genera %d[/color][/b] de [color=yellow]oro[/color][/center]" % amount


func apply_effects(targets:Array[Node],stats:Stats) -> void:
	var effect := GenerateGoldEffect.new()
	effect.amount = amount
	effect.stats = stats
	effect.execute(targets)
