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


# --- Consultas de StatModifier (produccion) ---

func get_flat_gold() -> int:
	var total := 0
	for mod in active_modifiers:
		if mod is StatModifier and mod.type == StatModifier.StatType.FLAT_GOLD:
			total += int(mod.value)
	return total


func get_percent_gold() -> float:
	var total := 0.0
	for mod in active_modifiers:
		if mod is StatModifier and mod.type == StatModifier.StatType.PERCENT_GOLD:
			total += mod.value
	return total


func get_flat_food() -> int:
	var total := 0
	for mod in active_modifiers:
		if mod is StatModifier and mod.type == StatModifier.StatType.FLAT_FOOD:
			total += int(mod.value)
	return total


func get_percent_food() -> float:
	var total := 0.0
	for mod in active_modifiers:
		if mod is StatModifier and mod.type == StatModifier.StatType.PERCENT_FOOD:
			total += mod.value
	return total


func get_tile_gold_bonus(tile:Tile) -> int:
	var total := 0
	for mod in active_modifiers:
		if mod is StatModifier and mod.type == StatModifier.StatType.TILE_RESOURCE_GOLD:
			if tile.natural_resource == mod.target_resource:
				total += int(mod.value)
	return total


func get_tile_food_bonus(tile:Tile) -> int:
	var total := 0
	for mod in active_modifiers:
		if mod is StatModifier and mod.type == StatModifier.StatType.TILE_RESOURCE_FOOD:
			if tile.natural_resource == mod.target_resource:
				total += int(mod.value)
	return total


func get_cards_per_turn_bonus() -> int:
	var total := 0
	for mod in active_modifiers:
		if mod is StatModifier and mod.type == StatModifier.StatType.CARDS_PER_TURN:
			total += int(mod.value)
	return total


func get_card_draw_bonus() -> int:
	var total := 0
	for mod in active_modifiers:
		if mod is StatModifier and mod.type == StatModifier.StatType.CARD_DRAW_BONUS:
			total += int(mod.value)
	return total


## Suma de modifiers activos del tipo TROOPS_PER_RECRUIT. Cada Cuartel
## construido añade +1; el total se aplica como bonus al base_troops_per_play
## de RecruitCard cuando se juega.
func get_troops_per_recruit_bonus() -> int:
	var total := 0
	for mod in active_modifiers:
		if mod is StatModifier and mod.type == StatModifier.StatType.TROOPS_PER_RECRUIT:
			total += int(mod.value)
	return total


## Suma porcentual de modifiers del tipo TROOP_MAINTENANCE_PERCENT (e.g.,
## -20 + -20 = -40 → -40% al mantenimiento base). El consumer
## (EmpireController) clampa este valor a [-80, 0] antes de aplicarlo para
## que el mantenimiento no pueda llegar a 0; el clamp se hace alli porque
## es regla de juego, no de agregacion de modifiers.
func get_troop_maintenance_percent() -> float:
	var total := 0.0
	for mod in active_modifiers:
		if mod is StatModifier and mod.type == StatModifier.StatType.TROOP_MAINTENANCE_PERCENT:
			total += mod.value
	return total


# --- Consulta de BuildCostModifier ---

func get_build_cost_multiplier() -> float:
	var total_percent := 0.0
	for mod in active_modifiers:
		if mod is BuildCostModifier:
			total_percent += mod.percent
	## 20% descuento -> 0.8, -15% encarecimiento -> 1.15
	## Clampeado a >= MIN_COST_MULTIPLIER para que apilar descuentos no
	## pueda hacer la construccion gratuita ni negativa. Los
	## encarecimientos (multiplier > 1) NO se topan.
	return clamp_cost_multiplier(1.0 - (total_percent / 100.0))


# --- Consulta de CardReturnModifier ---

func should_return_to_hand(card:Card) -> bool:
	for mod in active_modifiers:
		if mod is CardReturnModifier:
			if mod.should_return(card):
				return true
	return false
