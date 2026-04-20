extends EmpireAbility
class_name BankingAbility

## Banca Florentina - Habilidad de la Dinastia Medici
## +15% produccion de oro global y -20% coste de construccion


func create_modifiers() -> Array[Modifier]:
	var mods:Array[Modifier] = []

	# +15% oro global
	var gold_mod := StatModifier.new(
		"banking_gold", "Banca Florentina: Oro",
		StatModifier.StatType.PERCENT_GOLD, 15.0, -1
	)
	mods.append(gold_mod)

	# -20% coste de construccion (20% descuento)
	var cost_mod := BuildCostModifier.new(
		"banking_build_cost", "Banca Florentina: Construccion",
		20.0, -1
	)
	mods.append(cost_mod)

	return mods
