extends RefCounted
class_name AIEventScoring

## Puntuación de eventos, escrita UNA sola vez. Punto de
## partida: la valoración de una casilla candidata a urbanizarse a Megalópolis,
## que estaba DUPLICADA con fórmula IDÉNTICA en AIEventResolver (estado vivo,
## `_pick_best_megalopolis_tile`) y AIRealEvents (snapshot,
## `_apply_urbanize_megalopolis`).
##
## Solo se unifica la FÓRMULA por-casilla (pura sobre Building/recurso natural,
## clases compartidas). El RECORRIDO de casillas candidatas se queda en cada
## mundo (Tile vs TileSnap; el snapshot filtra owner/Town/min_buildings inline),
## así que el orden de iteración —y por tanto el desempate— se preserva:
## byte-idéntico en ambos mundos.


## Valor de urbanizar una casilla a Megalópolis: valor de los edificios que
## SOBREVIVEN + valor del recurso natural − valor de los que se DEMOLERÁN.
## Byte-idéntico a las dos implementaciones que sustituye (mismos literales y
## mismo orden de operaciones).
static func megalopolis_tile_value(buildings: Array, natural_resource) -> float:
	var surviving := 0.0
	var demolished := 0.0
	for b in buildings:
		if b == null:
			continue
		var val: float = b.gold_produced * 2.0 + b.food_produced * 1.5 + b.flat_defense_bonus * 1.0
		if _survives_megalopolis(b):
			surviving += val
		else:
			demolished += val
	var res_val := 0.0
	if natural_resource != null:
		res_val = natural_resource.gold_produced * 1.5 + natural_resource.food_produced * 1.2
	return surviving + res_val - demolished


## True si el edificio sobrevive al pasar a Megalópolis: sin restricción de
## localización (allowed_location_type vacío) o si su lista incluye un tipo
## ≥ Megalópolis. Espejo exacto del predicado `survives` de ambas implementaciones.
static func _survives_megalopolis(b) -> bool:
	if b.allowed_location_type.is_empty():
		return true
	for lt in b.allowed_location_type:
		if lt.type >= Tile.location_type.Megalopolis:
			return true
	return false
