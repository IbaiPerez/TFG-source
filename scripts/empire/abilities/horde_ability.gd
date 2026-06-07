extends EmpireAbility
class_name HordeAbility

## Horda Nomada - Habilidad del Imperio Mongol
## +1 carta por turno, Colonizar 30% de volver a la mano,
## +1 jinete extra por Reclutar (solo caballería) y -25% mantenimiento de caballería


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

	# +1 jinete extra por jugada de Reclutar (solo caballería, troop_type_filter = CABALLERIA)
	var recruit_mod := StatModifier.new(
		"horde_cavalry_recruit", "Horda Nomada: Caballería",
		StatModifier.StatType.TROOPS_PER_RECRUIT, 1.0, -1,
		null, null, Troop.TroopType.CABALLERIA
	)
	mods.append(recruit_mod)

	# -25% mantenimiento solo de caballería (jinetes ligeros nómadas)
	var maint_mod := StatModifier.new(
		"horde_cavalry_maintenance", "Horda Nomada: Mantenimiento",
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT, -25.0, -1,
		null, null, Troop.TroopType.CABALLERIA
	)
	mods.append(maint_mod)

	return mods
