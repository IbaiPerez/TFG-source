extends BuildCard
class_name DirectBuildCard



func apply_effects(targets:Array[Node], stats:Stats) -> void:
	if buildings.is_empty():
		return
	var effect := BuildEffect.new()
	effect.stats = stats
	effect.building = buildings[0]
	effect.execute(targets)
