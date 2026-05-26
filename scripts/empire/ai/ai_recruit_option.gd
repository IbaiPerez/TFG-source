extends AIPlayOption
class_name AIRecruitOption

## Bypass de RecruitCard: el flujo del jugador abre RecruitPanel para
## elegir tipo de tropa. La IA enumera 1 opción por cada Troop disponible
## que pueda permitirse y rellena card.chosen directamente.

var troop: Troop


static func from_card(p_card: RecruitCard, p_troop: Troop) -> AIRecruitOption:
	var opt := AIRecruitOption.new()
	opt.card = p_card
	opt.targets = []  # SELF target
	opt.troop = p_troop
	opt.payload = {"troop": p_troop}
	return opt


func execute(ctx: AITurnContext) -> Card:
	if card == null or troop == null:
		return null
	(card as RecruitCard).chosen = troop
	card.play(targets, ctx.stats)
	return card


func describe() -> String:
	var t_name := troop.name if troop else "?"
	return "Recruit(%s)" % t_name
