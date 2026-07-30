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
	category = EventCategory.Type.CORE_PROGRESSION

	conditions = [
		UrbanizedTilesCondition.new(1, Comparison.Type.GREATER_EQUAL),
		HasAdjacentEnemyCondition.new(),
	]

	# El Cuartel queda disponible para construir desde que se permite reclutar:
	# cada Cuartel suma +1 tropas/play de Recruit Y mete una carta Recruit adicional
	# al deck, escalando tanto throughput como frecuencia de plays.
	choices = [make_card_unlock_choice(RECRUIT_CARD,
		"EVT_UNLOCK_RECRUIT_CH1_LABEL", "EVT_UNLOCK_RECRUIT_CH1_DESC", 8.0, -0.1, 3.0,
		[UnlockBuildingEffect.new(CUARTEL_BUILDING)])]
