extends Node
class_name ModifierManager

signal modifier_added(modifier:Modifier)
signal modifier_removed(modifier:Modifier)
signal modifiers_changed()

## Multiplicador minimo al que cualquier coste descontado puede llegar.
## Es regla de juego: por mucho que apilemos edificios o eventos de
## descuento (Cuartel/Academia para mantenimiento, Banca Florentina y
## eventos como Material Crisis o Spirit Raices para construccion),
## siempre se paga al menos un 20% del coste base. Evita que las tropas
## o los edificios se vuelvan gratis.
const MIN_COST_MULTIPLIER: float = 0.2

var active_modifiers:Array[Modifier] = []


## Aplica el clamp de coste minimo a un multiplicador ya calculado.
##
## Pensado para que CUALQUIER consumer que reciba un multiplicador de
## descuento (`get_build_cost_multiplier`, mantenimiento de tropas en
## EmpireController, etc.) lo pase por aqui antes de usarlo. Asi todos
## comparten la misma regla "como minimo se paga 20%" sin tener que
## recordar la constante a mano.
##
## NO toca multiplicadores > 1.0 (encarecimientos), que siguen subiendo
## el coste sin tope superior.
static func clamp_cost_multiplier(multiplier: float) -> float:
	return maxf(multiplier, MIN_COST_MULTIPLIER)


func add_modifier(mod:Modifier, p_stats:Stats) -> void:
	active_modifiers.append(mod)
	mod.activate(p_stats)
	modifier_added.emit(mod)
	modifiers_changed.emit()


func remove_modifier(mod:Modifier) -> void:
	mod.deactivate()
	active_modifiers.erase(mod)
	modifier_removed.emit(mod)
	modifiers_changed.emit()


func tick() -> void:
	for mod in active_modifiers:
		mod.on_turn_start()

	var expired:Array[Modifier] = []
	for mod in active_modifiers:
		if mod.duration > 0:
			mod.duration -= 1
			if mod.duration == 0:
				expired.append(mod)

	for mod in expired:
		remove_modifier(mod)


# --- Consultas (delegadas a ModifierQuery sobre active_modifiers) ---
# La lógica de agregación vive en ModifierQuery para no duplicarla con el motor
# de simulación de la IA (AIRealSimulator), que la consulta sobre su snapshot.

func get_flat_gold() -> int:
	return ModifierQuery.flat_gold(active_modifiers)


func get_percent_gold() -> float:
	return ModifierQuery.percent_gold(active_modifiers)


func get_flat_food() -> int:
	return ModifierQuery.flat_food(active_modifiers)


func get_percent_food() -> float:
	return ModifierQuery.percent_food(active_modifiers)


func get_tile_gold_bonus(tile:Tile) -> int:
	return ModifierQuery.tile_gold_bonus(active_modifiers, tile.natural_resource)


func get_tile_food_bonus(tile:Tile) -> int:
	return ModifierQuery.tile_food_bonus(active_modifiers, tile.natural_resource)


func get_cards_per_turn_bonus() -> int:
	return ModifierQuery.cards_per_turn_bonus(active_modifiers)


func get_card_draw_bonus() -> int:
	return ModifierQuery.card_draw_bonus(active_modifiers)


func get_troops_per_recruit_bonus(troop: Troop = null) -> int:
	return ModifierQuery.troops_per_recruit_bonus(active_modifiers, troop)


func get_troop_maintenance_percent(troop: Troop = null) -> float:
	return ModifierQuery.troop_maintenance_percent(active_modifiers, troop)


func get_build_cost_multiplier() -> float:
	return ModifierQuery.build_cost_multiplier(active_modifiers)


func should_return_to_hand(card:Card) -> bool:
	return ModifierQuery.should_return_to_hand(active_modifiers, card)
