extends Resource
class_name NeighborBonus

## Bonificación que un edificio concede a las casillas VECINAS, no a la suya.
##
## Hasta ahora un edificio solo producía en su propia casilla (`Building.gold_produced`
## / `food_produced`). Esta es la otra mecánica: el molino se construye en una ciudad y
## la comida la reciben los pueblos de alrededor. Un mismo coste de construcción llega
## así a seis casillas en vez de a una, a cambio de que el edificio ocupe un slot en un
## sitio donde no produce nada por sí mismo.
##
## Las CONDICIONES son la parte reutilizable: cada bonificación declara a qué casillas
## alcanza, y todas se combinan en Y. Una lista vacía significa "sin restricción por ese
## eje", igual que en `Building.allowed_location_type` / `allowed_biomes`. Así el molino
## se declara en su `.tres` sin escribir código:
##
##     only_same_owner   = true            # no regalar comida al rival
##     allowed_locations = [Village]       # la comida se concentra en los pueblos
##
## y otro edificio futuro puede pedir un bioma concreto o un recurso natural sin tocar
## nada de esto.
##
## La condición se evalúa sobre PRIMITIVAS (propiedad, enum de localización, enum de
## bioma, recurso) a propósito: la casilla viva es un `Tile` y la del snapshot de la IA
## un `AIRealState.TileSnap`, dos representaciones sin ancestro común. Pasando escalares,
## la regla se escribe UNA vez y los dos mundos la comparten — que es justo donde este
## proyecto se ha roto antes.


@export_group("Qué concede")
## Comida por turno que suma a cada casilla vecina que cumpla las condiciones.
@export var food: int = 0
## Oro por turno que suma a cada casilla vecina que cumpla las condiciones.
@export var gold: int = 0
## Porcentaje sobre la comida del RECURSO NATURAL de la vecina, no sobre su total
## (mismo criterio que `Building.food_percent_bonus`).
@export var food_percent: float = 0.0

@export_group("A qué casillas alcanza")
## Solo casillas del mismo imperio que la que tiene el edificio. Una casilla sin
## dueño nunca cumple: no se puede bonificar territorio que no es de nadie.
@export var only_same_owner: bool = true
## Localizaciones que reciben la bonificación. Vacío = cualquiera.
@export var allowed_locations: Array[Tile.location_type] = []
## Biomas que la reciben. Vacío = cualquiera.
@export var allowed_biomes: Array[Tile.biome_type] = []
## Si se indica, solo la reciben las casillas con ese recurso natural.
@export var required_natural_resource: NaturalResource = null


## True si una casilla vecina con estas características recibe la bonificación.
##
## `same_owner` lo decide el llamante porque cada mundo compara la propiedad a su
## manera (referencia a `Empire` en la escena, entero `OWNER_*` en el snapshot).
func applies_to(same_owner: bool, location: int, biome: int,
		resource: NaturalResource) -> bool:
	if only_same_owner and not same_owner:
		return false
	if not allowed_locations.is_empty() and location not in allowed_locations:
		return false
	if not allowed_biomes.is_empty() and biome not in allowed_biomes:
		return false
	if required_natural_resource != null and resource != required_natural_resource:
		return false
	return true


## True si no concede nada. Un bonus vacío se puede saltar sin evaluar condiciones.
func is_empty() -> bool:
	return food == 0 and gold == 0 and is_zero_approx(food_percent)
