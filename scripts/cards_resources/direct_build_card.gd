extends BuildCard
class_name DirectBuildCard


func _build_tooltip() -> String:
	if buildings.is_empty():
		return "[center][b][color=#5B7A3A]Construye[/color][/b] un [color=#4A6A8A]edificio[/color] directamente[/center]"
	var building_name := buildings[0].name if buildings[0] else "?"
	return "[center][b][color=#5B7A3A]Construye[/color][/b] [color=#4A6A8A]%s[/color][/center]" % building_name


func apply_effects(targets:Array[Node], stats:Stats) -> void:
	if buildings.is_empty():
		return
	var effect := BuildEffect.new()
	effect.stats = stats
	effect.building = buildings[0]
	effect.execute(targets)
