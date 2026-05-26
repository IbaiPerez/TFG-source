extends AIPlayOption
class_name AIUpgradeBuildingOption

## Bypass de UpgradeBuildingCard: el jugador elige el edificio existente
## a mejorar y luego el target del upgrade en BuildingPanel. La IA enumera
## todos los pares (old_building, new_building) legales y rellena los
## campos de la carta directamente.

var old_building: Building
var new_building: Building


static func from_card(p_card: UpgradeBuildingCard, p_target: Tile,
		p_old: Building, p_new: Building) -> AIUpgradeBuildingOption:
	var opt := AIUpgradeBuildingOption.new()
	opt.card = p_card
	opt.targets = [p_target]
	opt.old_building = p_old
	opt.new_building = p_new
	opt.payload = {"old_building": p_old, "new_building": p_new}
	return opt


func execute(ctx: AITurnContext) -> Card:
	if card == null or old_building == null or new_building == null:
		return null
	var ucard := card as UpgradeBuildingCard
	ucard.old_building = old_building
	ucard.chosen = new_building
	card.play(targets, ctx.stats)
	return card


func describe() -> String:
	var old_n := old_building.name if old_building else "?"
	var new_n := new_building.name if new_building else "?"
	return "Upgrade(%s→%s)" % [old_n, new_n]
