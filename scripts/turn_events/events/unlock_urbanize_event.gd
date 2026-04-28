extends TurnEvent
class_name UnlockUrbanizeEvent

## Auge Urbano
## Se activa al tener 8+ edificios construidos (después de unlock_upgrade).
## Añade la carta de Proyecto Urbano (urbanizar a Town) al descarte
## y desbloquea 5 edificios exclusivos de Town.
## Evento único: solo ocurre una vez por partida.

const URBAN_PROJECT_CARD = preload("res://resources/cards/urban_project.tres")

const MARKET_SQUARE = preload("res://resources/buildings/market_square.tres")
const WAREHOUSE = preload("res://resources/buildings/warehouse.tres")
const PORT = preload("res://resources/buildings/port.tres")
const GREMIO_MERCADERES = preload("res://resources/buildings/gremio_mercaderes.tres")
const HUERTOS_URBANOS = preload("res://resources/buildings/huertos_urbanos.tres")


func _init():
	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		# 8+ edificios construidos en total (después de unlock_upgrade)
		BuildingCountCondition.new(8, Comparison.Type.GREATER_EQUAL),
	]

	var choice := TurnEventChoice.new()
	choice.label = "Fundar ciudades"
	choice.description = "Recibes una carta de Proyecto Urbano y desbloqueas nuevos edificios de ciudad."
	choice.effects = [
		AddCardEffect.new(URBAN_PROJECT_CARD),
		AddToCardPoolEffect.new(URBAN_PROJECT_CARD, 6.0, 0.0, 3.0),
		UnlockBuildingEffect.new(MARKET_SQUARE),
		UnlockBuildingEffect.new(WAREHOUSE),
		UnlockBuildingEffect.new(PORT),
		UnlockBuildingEffect.new(GREMIO_MERCADERES),
		UnlockBuildingEffect.new(HUERTOS_URBANOS),
	]
	choices = [choice]
