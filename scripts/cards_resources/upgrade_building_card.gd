extends Card
class_name UpgradeBuildingCard

var old_building:Building
var chosen:Building
var menu:BuildingPanel

func apply_effects(targets:Array[Node],stats:Stats) -> void:
	var effect := UpgradeBuildingEffect.new()
	effect.new_building = chosen
	effect.old_building = old_building
	effect.stats = stats
	effect.execute(targets)

func get_valid_targets(stats:Stats) -> Array[Node]:
	var condition := UpgradeBuildingCondition.new()
	condition.stats = stats
	return condition.valid_targets()

func is_valid_target(node:Node,stats:Stats) -> bool:
	var condition := UpgradeBuildingCondition.new()
	condition.stats = stats
	return condition.is_valid_target(node)
	
func confirm(targets:Array[Node], stats:Stats) -> void:
	if targets.size() != 1:
		return
	Events.upgrade_building_card_confirm_started.emit(self,targets,stats)
