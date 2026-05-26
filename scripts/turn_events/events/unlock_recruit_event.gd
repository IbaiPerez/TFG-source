extends TurnEvent
class_name UnlockRecruitEvent

## Llamada a las armas
## Se activa al tener al menos una ciudad (Town+) y una provincia
## adyacente a otro imperio. Otorga la carta de Reclutar.
## Evento único: solo ocurre una vez por partida.

# Usamos el recurso .tres en lugar de construir la carta a mano: el .tres
# ya trae `available_troops` configurado con militia, cavalry, pikemen,
# heavy y ranged. Construirla con RecruitCard.new() dejaba ese array vacio
# y AIOptionsBuilder._add_recruit_options la descartaba siempre (la IA
# tenia la carta en la mano pero nunca generaba opciones de reclutar).
const RECRUIT_CARD = preload("res://resources/cards/recruit_card.tres")
const CUARTEL_BUILDING = preload("res://resources/buildings/lategame/cuartel_expansion.tres")


func _init():
	id = "unlock_recruit"
	title = "Llamada a las armas"
	description = "Las fronteras de tu imperio rozan las de un rival. Es hora de preparar tus defensas y reclutar tropas."
	weight = 100.0
	unique = true
	allow_skip = false
	category = EventCategory.Type.CORE_PROGRESSION

	conditions = [
		UrbanizedTilesCondition.new(1, Comparison.Type.GREATER_EQUAL),
		HasAdjacentEnemyCondition.new(),
	]

	var choice := TurnEventChoice.new()
	choice.label = "Reclutar tropas"
	choice.description = "Recibes una carta de Reclutar, se desbloquea en el pool de cartas y se habilita la construcción del Cuartel."
	choice.effects = [
		AddCardEffect.new(RECRUIT_CARD),
		AddToCardPoolEffect.new(RECRUIT_CARD, 8.0, -0.1, 3.0),
		# El Cuartel queda disponible para construir desde el momento que se
		# permite reclutar: cada Cuartel construido suma +1 al numero de
		# tropas por play de Recruit Y mete una carta Recruit adicional al
		# deck, asi que escala tanto throughput como frecuencia de plays.
		UnlockBuildingEffect.new(CUARTEL_BUILDING),
	]
	choices = [choice]
