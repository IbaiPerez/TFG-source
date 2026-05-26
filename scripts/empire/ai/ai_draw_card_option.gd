extends AIPlayOption
class_name AIDrawCardOption

## Bypass de CardDrawCard: el efecto original (DrawCardEffect) busca el
## PlayerHandler en el scene tree y le añade cartas a su mano, lo cual
## NO funciona para la IA (le daría cartas al jugador).
##
## Esta opción reproduce localmente lo que la IA necesita: robar N cartas
## (con bonus de modifier) y añadirlas al ctx.drawn_cards para que entren
## en el bucle de decisión del turno actual.

var amount: int = 1


static func from_card(p_card: CardDrawCard) -> AIDrawCardOption:
	var opt := AIDrawCardOption.new()
	opt.card = p_card
	opt.amount = p_card.amount
	return opt


func execute(ctx: AITurnContext) -> Card:
	if card == null:
		return null
	# Emitimos card_played para que modifiers/buildings reactivos (los del
	# propio imperio IA) puedan responder. El bus filtra por owner_stats.
	Events.card_played.emit(card, ctx.stats)
	var bonus: int = 0
	if ctx.controller != null and ctx.controller.modifier_manager != null:
		bonus = ctx.controller.modifier_manager.get_card_draw_bonus()
	var total := amount + bonus
	for i in range(total):
		var drawn: Card = ctx.controller._draw_single_card()
		if drawn != null:
			ctx.drawn_cards.append(drawn)
	return card


func describe() -> String:
	return "DrawCard(+%d)" % amount
