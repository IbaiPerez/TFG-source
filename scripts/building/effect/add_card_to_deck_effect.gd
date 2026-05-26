extends BuildingEffect
class_name AddCardToDeckEffect

## BuildingEffect que añade UNA carta al descarte cuando se construye el
## edificio. Util para edificios que "abren" mecanicas atadas a una carta
## concreta — p.ej. el Cuartel añade una RecruitCard al deck para que el
## jugador tenga mas frecuencia de reclutamiento, no solo mas tropas por
## play.
##
## Cuidados:
## - El efecto es de UN solo disparo: al construir mete la carta. No se
##   queda escuchando ni recalcula nada.
## - `remove_effect` es no-op: si demueles el edificio, la carta ya esta
##   en el deck y se queda. Si quieres revertir, hace falta otra
##   mecanica explicita.
## - `should_reapply_on_load` es `false`: la carta ya viene en el snapshot
##   del deck (StatsSerializer persiste las pilas), reaplicar duplicaria.

@export var card:Card

## Si es true, el effect solo se dispara la PRIMERA vez que el imperio
## construye un edificio con este nombre. Construcciones siguientes del
## mismo edificio NO añaden mas cartas al deck.
##
## Pensado para el Cuartel y la Academia Militar: queremos que el primer
## edificio meta su carta de Reclutar como bono fundacional, pero apilar
## 8-10 Cuarteles no debe inundar el deck con Reclutar. El bonus de
## `TROOPS_PER_RECRUIT` sigue sumando con cada edificio — solo se topa la
## carta one-shot.
@export var first_only:bool = false


func apply_effect(tile: Tile, stats: Stats) -> void:
	if card == null or stats == null or stats.discard_pile == null:
		return
	if first_only and _empire_already_has_another(tile, stats):
		return
	# Duplicate igual que `AddCardEffect` (turn event) — la carta del .tres
	# es un singleton compartido; lo que entra al deck es una copia para
	# evitar mutaciones cruzadas (p.ej. `RecruitCard.chosen`).
	var instance := card.duplicate()
	stats.sync_card_buildings(instance)
	stats.discard_pile.add_card(instance)


## Para `first_only`: comprueba si el imperio ya tiene OTRO edificio con
## el mismo nombre que el que se acaba de construir. `apply_effect` se
## llama justo despues de `tile.buildings.append(instance)`, asi que el
## edificio recien construido esta al final de `tile.buildings`. Buscamos
## en TODAS las tiles del imperio (incluida esta) y dejamos pasar la cuenta
## solo si encontramos un segundo match — el primero es el que dispara.
func _empire_already_has_another(tile: Tile, stats: Stats) -> bool:
	if tile == null or tile.buildings.is_empty():
		return false
	if stats.empire == null:
		return false
	var just_built_name: String = tile.buildings.back().name
	var seen := 0
	for t in stats.empire.controlled_tiles:
		if not is_instance_valid(t):
			continue
		for b in t.buildings:
			if b.name == just_built_name:
				seen += 1
				if seen > 1:
					return true
	return false


func remove_effect(_tile: Tile, _stats: Stats) -> void:
	pass


## La carta entró al deck en `apply_effect` y se persiste con el deck en
## el snapshot. Re-aplicar al cargar el save duplicaría la carta.
func should_reapply_on_load() -> bool:
	return false
