extends RefCounted
class_name AILegality

## Reglas de legalidad de jugadas escritas UNA sola vez (refactor C5 §1.4) contra el
## puerto AIStateView. Antes vivían duplicadas en AIOptionsBuilder (enumera sobre el
## estado vivo → AIPlayOption) y AIRealOptions (enumera sobre el snapshot → Move):
## las mismas reglas de legalidad sobre dos representaciones, y el snapshot además
## reimplementaba métodos de dominio (Tile.can_upgrade, Stats.can_afford_troop,
## RecruitCard.get_effective_troops_per_play). El espejo de la asequibilidad de tropa
## ya no existe: la regla vive en Troop.is_affordable y la usan los dos mundos (§3.4).
##
## Estas funciones devuelven los TARGETS legales (descriptores neutros); cada
## enumerador los traduce a su tipo propio. Las divergencias reales por mundo
## (fuente de edificios, guarda de upgrade, dirección de open_front) se aíslan en
## métodos del puerto, no aquí.
##
## Migración incremental (§1.4): PORTADOS = RECRUIT, BUILD, DIRECT_BUILD (snapshot),
## UPGRADE, CHANGE_LOCATION. COLONIZE se unifica vía view.colonizable_tiles() (dos
## mecanismos distintos por mundo: AdjacentRule vs recorrido). El resto sigue en cada
## enumerador hasta portarse.


## CHANGE_LOCATION: casillas propias donde la nueva ubicación es el tier siguiente
## (location_type + 1) y hay comida para su consumo. Espejo de ChangeLocationTypeRule
## (el mundo vivo) y de la reimplementación del snapshot, ahora una sola vez.
static func change_location_targets(view: AIStateView, target: LocationType) -> Array:
	var result: Array = []
	var food := view.food()
	for tile in view.owned_tiles():
		if view.tile_location_type(tile) + 1 != target.type:
			continue
		if food < target.food_consumption:
			continue
		result.append(tile)
	return result


## BUILD / DIRECT_BUILD: producto cartesiano (casilla propia × edificio) que pasa
## can_build y el coste efectivo ≤ oro. `buildings` lo provee cada enumerador (vivo
## BUILD: card.buildings; snapshot BUILD: emp.possible_buildings; DIRECT_BUILD:
## [buildings[0]]), aislando ahí la divergencia de fuente de edificios.
static func build_targets(view: AIStateView, buildings: Array[Building]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var gold := view.gold()
	for tile in view.owned_tiles():
		for building in buildings:
			if building == null:
				continue
			if view.effective_build_cost(building) > gold:
				continue
			if not view.can_build(tile, building):
				continue
			result.append({"tile": tile, "building": building})
	return result


## UPGRADE: (casilla × edificio viejo × edificio nuevo) legal. El guarda
## can_be_upgraded (solo del mundo vivo) y la regla can_upgrade se resuelven en la
## VISTA para preservar la divergencia real entre mundos (Tile.can_upgrade compara
## LocationType por objeto; el snapshot por enum).
static func upgrade_targets(view: AIStateView) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var gold := view.gold()
	for tile in view.owned_tiles():
		for old_b in view.tile_buildings(tile):
			if old_b == null:
				continue
			if not view.can_be_upgraded(old_b):
				continue
			for new_b in old_b.upgrades_to:
				if new_b == null:
					continue
				if view.effective_build_cost(new_b) > gold:
					continue
				if not view.can_upgrade(tile, old_b, new_b):
					continue
				result.append({"tile": tile, "old": old_b, "new": new_b})
	return result


## RECRUIT: por cada tropa disponible y asequible, un descriptor {troop, per_play}.
## Filtros (idénticos a AIOptionsBuilder._add_recruit_options y AIRealOptions._add_recruit):
##   1. asequibilidad (gating de producción, vía la regla de dominio Troop.is_affordable),
##   2. coste one-shot total per_play·recruitment_cost_gold ≤ oro disponible.
static func recruit_targets(view: AIStateView, card: RecruitCard) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if card.available_troops.is_empty():
		return result
	var gold := view.gold()
	for troop in card.available_troops:
		if troop == null:
			continue
		if not troop.is_affordable(gold, view.gold_per_turn(), view.food()):
			continue
		var per_play := troops_per_play(card.base_troops_per_play,
			view.troops_per_recruit_bonus(troop))
		if gold < troop.recruitment_cost_gold * per_play:
			continue
		result.append({"troop": troop, "per_play": per_play})
	return result


## Tropas por play efectivas (espejo de RecruitCard.get_effective_troops_per_play):
## base + bonus de modifiers, mínimo 1. El `bonus` lo calcula cada mundo con su vista.
static func troops_per_play(base_troops_per_play: int, bonus: int) -> int:
	return maxi(1, base_troops_per_play + bonus)
