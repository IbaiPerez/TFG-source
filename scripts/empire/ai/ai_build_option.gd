extends AIPlayOption
class_name AIBuildOption

## Bypass de BuildCard: el flujo del jugador abre BuildingPanel para
## elegir el edificio. La IA elige al azar al enumerar y rellena
## card.chosen directamente antes de apply_effects, saltándose el panel.

var building: Building


static func from_card(p_card: BuildCard, p_target: Tile, p_building: Building) -> AIBuildOption:
	var opt := AIBuildOption.new()
	opt.card = p_card
	opt.targets = [p_target]
	opt.building = p_building
	opt.payload = {"building": p_building}
	return opt


func execute(ctx: AITurnContext) -> Card:
	if card == null or building == null:
		return null
	# BuildCard.apply_effects lee card.chosen para construir.
	(card as BuildCard).chosen = building
	# play() emite card_played(card, stats) antes de aplicar efectos.
	card.play(targets, ctx.stats)
	return card


func describe() -> String:
	var b_name := building.name if building else "?"
	return "Build(%s)" % b_name
