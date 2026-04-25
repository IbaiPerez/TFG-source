extends ShopEvent
class_name BasicShopEvent

## Tienda Basica - Evento repetible
## 2-3 cartas basicas + 1 uso de purga.
## Aparece a partir del turno 8 con peso moderado.


func _init():
	shop_type = ShopType.BASIC
	conditions = [
		TurnNumberCondition.new(8, Comparison.Type.GREATER_EQUAL),
		ControlledTilesCondition.new(3, Comparison.Type.GREATER_EQUAL),
	]
