extends AIPlayOption
class_name AIRecoverOption

## Bypass de RecoverCard: el flujo del jugador abre RecoverCardPanel para
## elegir qué carta recuperar de played_pile. La IA enumera 1 opción por
## carta del played_pile y rellena card.chosen directamente.
##
## Tras card.play, RecoverCard.apply_effects emite Events.card_returned_to_hand
## con la stats correcta (tras el refactor del bus). El AIController escucha
## y reintroduce la carta recuperada en _drawn_cards, por lo que la IA
## puede volver a jugarla en la siguiente iteración del bucle.

var chosen_card: Card


static func from_card(p_card: RecoverCard, p_chosen: Card) -> AIRecoverOption:
	var opt := AIRecoverOption.new()
	opt.card = p_card
	opt.targets = []
	opt.chosen_card = p_chosen
	opt.payload = {"chosen_card": p_chosen}
	return opt


func execute(ctx: AITurnContext) -> Card:
	if card == null or chosen_card == null:
		return null
	(card as RecoverCard).chosen = chosen_card
	card.play(targets, ctx.stats)
	return card


func describe() -> String:
	var name := chosen_card.id if chosen_card and chosen_card.id else "?"
	return "Recover(%s)" % name
