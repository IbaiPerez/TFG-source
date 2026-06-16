extends BuildCard
class_name DirectBuildCard


func _build_tooltip() -> String:
	if buildings.is_empty():
		return tr("CARD_DIRECTBUILD_TOOLTIP_GENERIC")
	var building_name := tr(buildings[0].name) if buildings[0] else "?"
	return tr("CARD_DIRECTBUILD_TOOLTIP") % building_name


func apply_effects(targets:Array[Node], stats:Stats) -> void:
	if buildings.is_empty():
		return
	var effect := BuildEffect.new()
	effect.stats = stats
	effect.building = buildings[0]
	effect.execute(targets)
