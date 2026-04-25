extends TurnEvent
class_name ShopEvent

## Evento de tienda. Cuando se dispara, el SceneManager usa ShopGenerator
## para crear un ShopConfig dinamico y abrir el ShopPanel.

enum ShopType { BASIC, SPECIAL }

@export var shop_type:ShopType = ShopType.BASIC


## Genera el ShopConfig usando el generador dinamico.
func generate_shop(stats:Stats) -> ShopConfig:
	match shop_type:
		ShopType.BASIC:
			return ShopGenerator.generate_basic_shop(stats)
		ShopType.SPECIAL:
			return ShopGenerator.generate_special_shop(stats)
		_:
			return ShopGenerator.generate_basic_shop(stats)
