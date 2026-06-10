extends EmpireAbility
class_name HordeAbility

## Horda Nomada - Habilidad del Imperio Mongol
## +1 comida en casillas con Ganado, Colonizar 30% de volver a la mano,
## -25% mantenimiento de caballería

@export var livestock_resource:NaturalResource


func create_modifiers() -> Array[Modifier]:
	var mods:Array[Modifier] = []

	# +1 comida en casillas con Ganado
	if livestock_resource:
		var food_mod := StatModifier.new(
			"horde_livestock_food", "Horda Nomada: Ganado",
			StatModifier.StatType.TILE_RESOURCE_FOOD, 1.0, -1,
			null, livestock_resource
		)
		mods.append(food_mod)

	# Colonizar vuelve a la mano con 30% de probabilidad
	var return_mod := CardReturnModifier.new(
		"horde_colonize_return", "Horda Nomada: Colonizar",
		"Colonize", 0.3, -1
	)
	mods.append(return_mod)

	# -25% mantenimiento solo de caballería (jinetes ligeros nómadas)
	var maint_mod := StatModifier.new(
		"horde_cavalry_maintenance", "Horda Nomada: Mantenimiento",
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT, -25.0, -1,
		null, null, Troop.TroopType.CABALLERIA
	)
	mods.append(maint_mod)

	return mods
