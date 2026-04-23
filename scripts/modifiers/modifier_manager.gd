extends Node
class_name ModifierManager

signal modifier_added(modifier:Modifier)
signal modifier_removed(modifier:Modifier)
signal modifiers_changed()

var active_modifiers:Array[Modifier] = []


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


# --- Consulta de BuildCostModifier ---

func get_build_cost_multiplier() -> float:
	var total_percent := 0.0
	for mod in active_modifiers:
		if mod is BuildCostModifier:
			total_percent += mod.percent
	## 20% descuento -> 0.8, -15% encarecimiento -> 1.15
	return 1.0 - (total_percent / 100.0)


# --- Consulta de CardReturnModifier ---

func should_return_to_hand(card:Card) -> bool:
	for mod in active_modifiers:
		if mod is CardReturnModifier:
			if mod.should_return(card):
				return true
	return false
