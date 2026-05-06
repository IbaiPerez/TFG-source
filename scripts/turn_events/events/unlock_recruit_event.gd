extends TurnEvent
class_name UnlockRecruitEvent

## Llamada a las armas
## Se activa al tener al menos una ciudad (Town+) y una provincia
## adyacente a otro imperio. Otorga la carta de Reclutar.
## Evento único: solo ocurre una vez por partida.

func _init():
	id = "unlock_recruit"
	title = "Llamada a las armas"
	description = "Las fronteras de tu imperio rozan las de un rival. Es hora de preparar tus defensas y reclutar tropas."
	weight = 100.0
	unique = true
	allow_skip = false

	conditions = [
		UrbanizedTilesCondition.new(1, Comparison.Type.GREATER_EQUAL),
		HasAdjacentEnemyCondition.new(),
	]

	var recruit_card := _create_recruit_card()

	var choice := TurnEventChoice.new()
	choice.label = "Reclutar tropas"
	choice.description = "Recibes una carta de Reclutar y se desbloquea en el pool de cartas."
	choice.effects = [
		AddCardEffect.new(recruit_card),
		AddToCardPoolEffect.new(recruit_card, 8.0, -0.1, 3.0),
	]
	choices = [choice]


static func _create_recruit_card() -> RecruitCard:
	var card := RecruitCard.new()
	card.id = "Recruit"
	card.type = Card.Type.BASIC
	card.target = Card.Target.SELF
	card.needs_confirmation = true
	return card
