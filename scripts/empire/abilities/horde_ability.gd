extends EmpireAbility
class_name HordeAbility

## Horda Nomada - Habilidad del Imperio Mongol
## +1 carta por turno y la carta Colonizar tiene 30% de volver a la mano


func create_modifiers() -> Array[Modifier]:
	var mods:Array[Modifier] = []

	# +1 carta por turno
	var cards_mod := StatModifier.new(
		"horde_cards", "Horda Nomada: Cartas",
		StatModifier.StatType.CARDS_PER_TURN, 1.0, -1
	)
	mods.append(cards_mod)

	# Colonizar vuelve a la mano con 30% de probabilidad
	var return_mod := CardReturnModifier.new(
		"horde_colonize_return", "Horda Nomada: Colonizar",
		"Colonize", 0.3, -1
	)
	mods.append(return_mod)

	return mods
