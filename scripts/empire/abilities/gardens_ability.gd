extends EmpireAbility
class_name GardensAbility

## Jardines Colgantes - Habilidad del Imperio Babilonico
## +2 comida en casillas con Wheat, +3 oro al jugar Build Card,
## y +10% produccion de oro global (Rutas Comerciales de Mesopotamia)

@export var wheat_resource:NaturalResource


func create_modifiers() -> Array[Modifier]:
	var mods:Array[Modifier] = []

	# +2 comida en casillas con trigo
	if wheat_resource:
		var food_mod := StatModifier.new(
			"gardens_wheat_food", "Jardines Colgantes: Trigo",
			StatModifier.StatType.TILE_RESOURCE_FOOD, 2.0, -1,
			null, wheat_resource
		)
		mods.append(food_mod)

	# +3 oro cada vez que se juega Build Card
	var gold_on_build := GoldOnCardModifier.new(
		"gardens_gold_on_build", "Jardines Colgantes: Construccion",
		"Build Card", 3, -1
	)
	mods.append(gold_on_build)

	# +10% produccion de oro global (Rutas Comerciales de Mesopotamia)
	var trade_mod := StatModifier.new(
		"babylonian_trade_gold", "Rutas de Mesopotamia",
		StatModifier.StatType.PERCENT_GOLD, 10.0, -1
	)
	mods.append(trade_mod)

	return mods
