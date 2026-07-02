extends RefCounted
class_name ProductionCalculator

## Calculadora pura de produccion/mantenimiento del turno.
##
## Refactor H2: extraida de `EmpireController._process_turn_start()` para
## separar el calculo (puro, sin efectos secundarios ni señales) de la
## aplicacion (mutacion de `Stats`, emision de señales). Esto permite
## testear la formula de produccion en aislamiento y reutilizarla desde
## otros sitios (p.ej. UI de prediccion economica, IA evaluando jugadas).
##
## Diseño:
##   - `RefCounted` (no Node): se libera automaticamente al perder
##     referencias, no entra en el scene tree.
##   - Recibe sus dependencias por constructor (DI): `Stats`,
##     `ModifierManager` y opcionalmente `BattleFrontManager`. Sin
##     accesos a autoloads ni busquedas en el arbol.
##   - Sin señales. Los consumers (EmpireController) se encargan de
##     escribir el resultado en Stats y emitir lo que toque.
##
## Algoritmo (identico al codigo anterior en EmpireController):
##   1. Suma `gold_production + tile_gold_bonus` y `food_production + tile_food_bonus`
##      por cada tile controlado.
##   2. Suma `flat_gold` / `flat_food` de los modifiers globales.
##   3. Aplica `percent_gold` / `percent_food` SOLO a la parte positiva
##      (los costes negativos no se amplifican).
##   4. Resta el mantenimiento base de tropas, con el descuento porcentual
##      clampeado por `ModifierManager.clamp_cost_multiplier`.
##   5. Resta el recargo escalado por tropas asignadas a frentes (NO se
##      le aplica el descuento porcentual: el recargo es de coste plano).

var stats: Stats
var modifier_manager: ModifierManager
var battle_front_manager: BattleFrontManager


func _init(p_stats: Stats, p_modifier_manager: ModifierManager,
		p_battle_front_manager: BattleFrontManager = null) -> void:
	stats = p_stats
	modifier_manager = p_modifier_manager
	battle_front_manager = p_battle_front_manager


## Calcula el resultado economico completo del turno.
##
## Devuelve un Dictionary con los campos:
##   - `gold` (int): Oro neto del turno (lo que va a `gold_per_turn`).
##   - `food` (int): Comida neta del turno (lo que va a `food`).
##   - `base_troop_gold` (int): Mantenimiento base de tropas en oro.
##   - `base_troop_food` (int): Mantenimiento base de tropas en comida.
##   - `front_surcharge_gold` (int): Recargo de frentes en oro.
##   - `front_surcharge_food` (int): Recargo de frentes en comida.
##   - `total_troop_maint` (int): Suma de los cuatro anteriores. Usada
##     por `EmpireController._update_combat_multiplier` como denominador
##     del ratio de penalizacion economica.
func calculate_turn() -> Dictionary:
	var base := _calculate_base_production()
	var maint := _calculate_troop_maintenance()
	var fronts := _calculate_front_surcharges()

	var final_gold: int = base["gold"] - maint["gold"] - fronts["gold"]
	var final_food: int = base["food"] - maint["food"] - fronts["food"]

	var total_troop_maint: int = maint["gold"] + maint["food"] \
			+ fronts["gold"] + fronts["food"]

	return {
		"gold": final_gold,
		"food": final_food,
		"base_troop_gold": maint["gold"],
		"base_troop_food": maint["food"],
		"front_surcharge_gold": fronts["gold"],
		"front_surcharge_food": fronts["food"],
		"total_troop_maint": total_troop_maint,
	}


## Paso 1+2+3: tiles + flat modifiers + percent modifiers (solo positivos).
func _calculate_base_production() -> Dictionary:
	var base_gold := 0
	var base_food := 0
	for t in stats.empire.controlled_tiles:
		base_gold += t.gold_production + modifier_manager.get_tile_gold_bonus(t)
		base_food += t.food_production + modifier_manager.get_tile_food_bonus(t)

	base_gold += modifier_manager.get_flat_gold()
	base_food += modifier_manager.get_flat_food()

	# Los modificadores porcentuales solo afectan a la produccion positiva,
	# no a los costes de mantenimiento (produccion negativa).
	var gold_positive := maxi(base_gold, 0)
	var gold_negative := mini(base_gold, 0)
	var food_positive := maxi(base_food, 0)
	var food_negative := mini(base_food, 0)

	var final_gold := int(gold_positive * (1.0 + modifier_manager.get_percent_gold() / 100.0)) + gold_negative
	var final_food := int(food_positive * (1.0 + modifier_manager.get_percent_food() / 100.0)) + food_negative

	return { "gold": final_gold, "food": final_food }


## Paso 4: mantenimiento base de tropas con descuento clampeado.
## Itera por-tropa para que los modifiers con troop_type_filter apliquen
## solo a las tropas de ese tipo; los modifiers sin filtro aplican a todas.
func _calculate_troop_maintenance() -> Dictionary:
	var total_gold := 0
	var total_food := 0
	for troop in stats.troop_pool:
		var percent := modifier_manager.get_troop_maintenance_percent(troop)
		var multiplier := ModifierManager.clamp_cost_multiplier(1.0 + percent / 100.0)
		total_gold += int(troop.maintenance_gold * multiplier)
		total_food += int(troop.maintenance_food * multiplier)
	return { "gold": total_gold, "food": total_food }


## Paso 5: recargo escalado por tropas asignadas a frentes activos.
##
## NO se aplica descuento porcentual: el recargo es un coste plano cuyo
## escalado se rompe si lo descontaramos. La penalizacion economica
## (`_update_combat_multiplier`) si tiene este recargo en cuenta como
## parte del mantenimiento total.
func _calculate_front_surcharges() -> Dictionary:
	var gold := 0
	var food := 0
	if battle_front_manager == null:
		return { "gold": 0, "food": 0 }
	for front in battle_front_manager.active_fronts:
		var side: BattleFront.Side
		if front.attacker_empire == stats.empire:
			side = BattleFront.Side.ATTACKER
		else:
			side = BattleFront.Side.DEFENDER
		var maint := front.get_front_maintenance(side)
		gold += maint["gold"]
		food += maint["food"]
	return { "gold": gold, "food": food }
