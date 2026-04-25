extends ShopEvent
class_name SpecialShopEvent

## Tienda Especial - Evento poco frecuente
## 1 basica + 1 especial + 1 especial/single-use + 2-3 usos de purga.
## Aparece a partir del turno 12, requiere mas oro y tiles controlados.


func _init():
	shop_type = ShopType.SPECIAL
	conditions = [
		TurnNumberCondition.new(12, Comparison.Type.GREATER_EQUAL),
		ControlledTilesCondition.new(5, Comparison.Type.GREATER_EQUAL),
		GoldThresholdCondition.new(40, Comparison.Type.GREATER_EQUAL),
	]
