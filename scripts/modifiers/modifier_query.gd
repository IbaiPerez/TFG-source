extends RefCounted
class_name ModifierQuery

## Consultas PURAS sobre una lista de modificadores activos (`Array[Modifier]`),
## sin estado ni escena. Es la fuente única de la agregación de modifiers:
##   - ModifierManager delega aquí sus `get_*` (opera sobre `active_modifiers`).
##   - AIRealSimulator las llama directamente sobre el snapshot (`emp.modifiers`),
##     en vez de reimplementarlas (antes eran espejos privados `_flat_gold`, …).
##
## Así la regla "cómo se agregan los modifiers" existe una sola vez y el motor de
## la IA no puede desincronizarse del juego real.


static func flat_gold(mods: Array[Modifier]) -> int:
	var total := 0
	for mod in mods:
		if mod is StatModifier and mod.type == StatModifier.StatType.FLAT_GOLD:
			total += int(mod.value)
	return total


static func flat_food(mods: Array[Modifier]) -> int:
	var total := 0
	for mod in mods:
		if mod is StatModifier and mod.type == StatModifier.StatType.FLAT_FOOD:
			total += int(mod.value)
	return total


static func percent_gold(mods: Array[Modifier]) -> float:
	var total := 0.0
	for mod in mods:
		if mod is StatModifier and mod.type == StatModifier.StatType.PERCENT_GOLD:
			total += mod.value
	return total


static func percent_food(mods: Array[Modifier]) -> float:
	var total := 0.0
	for mod in mods:
		if mod is StatModifier and mod.type == StatModifier.StatType.PERCENT_FOOD:
			total += mod.value
	return total


## Bonus de oro por el recurso natural dado (TILE_RESOURCE_GOLD con target_resource
## coincidente). Recibe el recurso, no la casilla, para servir tanto a Tile como a
## AIRealState.TileSnap.
static func tile_gold_bonus(mods: Array[Modifier], resource: NaturalResource) -> int:
	var total := 0
	for mod in mods:
		if mod is StatModifier and mod.type == StatModifier.StatType.TILE_RESOURCE_GOLD:
			if resource == mod.target_resource:
				total += int(mod.value)
	return total


static func tile_food_bonus(mods: Array[Modifier], resource: NaturalResource) -> int:
	var total := 0
	for mod in mods:
		if mod is StatModifier and mod.type == StatModifier.StatType.TILE_RESOURCE_FOOD:
			if resource == mod.target_resource:
				total += int(mod.value)
	return total


static func cards_per_turn_bonus(mods: Array[Modifier]) -> int:
	var total := 0
	for mod in mods:
		if mod is StatModifier and mod.type == StatModifier.StatType.CARDS_PER_TURN:
			total += int(mod.value)
	return total


static func card_draw_bonus(mods: Array[Modifier]) -> int:
	var total := 0
	for mod in mods:
		if mod is StatModifier and mod.type == StatModifier.StatType.CARD_DRAW_BONUS:
			total += int(mod.value)
	return total


## Suma de TROOPS_PER_RECRUIT que aplican a `troop`. Los modifiers sin filtro
## (troop_type_filter == -1) cuentan siempre; con filtro, solo si la tropa
## coincide. troop=null pide solo los modifiers sin filtro.
static func troops_per_recruit_bonus(mods: Array[Modifier], troop: Troop = null) -> int:
	var total := 0
	for mod in mods:
		if mod is StatModifier and mod.type == StatModifier.StatType.TROOPS_PER_RECRUIT:
			if mod.applies_to_troop(troop):
				total += int(mod.value)
	return total


## Suma porcentual de TROOP_MAINTENANCE_PERCENT que aplican a `troop` (mismo
## criterio de filtro que troops_per_recruit_bonus).
static func troop_maintenance_percent(mods: Array[Modifier], troop: Troop = null) -> float:
	var total := 0.0
	for mod in mods:
		if mod is StatModifier and mod.type == StatModifier.StatType.TROOP_MAINTENANCE_PERCENT:
			if mod.applies_to_troop(troop):
				total += mod.value
	return total


## Multiplicador de coste de construcción: 1 − Σ% descuento, clampeado a
## MIN_COST_MULTIPLIER (los encarecimientos > 1 no se topan).
static func build_cost_multiplier(mods: Array[Modifier]) -> float:
	var total_percent := 0.0
	for mod in mods:
		if mod is BuildCostModifier:
			total_percent += mod.percent
	return ModifierManager.clamp_cost_multiplier(1.0 - (total_percent / 100.0))


static func should_return_to_hand(mods: Array[Modifier], card: Card) -> bool:
	for mod in mods:
		if mod is CardReturnModifier and mod.should_return(card):
			return true
	return false
