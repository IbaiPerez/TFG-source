extends Resource
class_name Building


@export var name:String
@export var required_natural_resource:NaturalResource
@export var allowed_location_type:Array[LocationType]
@export var allowed_biomes:Array[Tile.biome_type]
@export var image:Texture2D
@export var construction_cost:int
@export var gold_produced:int
@export var food_produced:int
@export var effects:Array[BuildingEffect]
@export var upgrades_to: Array[Building] = []
## Bonus plano de defensa que este edificio aporta al frente de batalla
## cuando está construido en la tile defensora. Solo relevante para
## edificios militares (Fortaleza, etc.). El BattleFront lee esta
## propiedad en _get_building_defense.
@export var flat_defense_bonus: int = 0
## Bonus porcentual sobre la comida producida por el recurso natural de
## la casilla. Se aplica en Tile.recalculate_modifiers() solo al food del
## natural_resource (no a otros edificios ni al consumo de la localizacion).
@export var food_percent_bonus: float = 0.0


func can_be_upgraded(stats:Stats) -> bool:
	for building in upgrades_to:
		if building.get_effective_construction_cost(stats) <= stats.total_gold:
			return true
	return false


## Devuelve el coste de construccion despues de aplicar los modificadores
## activos del jugador (BuildCostModifier de Banca Florentina, eventos de
## crisis, etc.) topado por ModifierManager.MIN_COST_MULTIPLIER (20% del
## coste base como minimo).
##
## Si `stats == null` o `stats.modifier_manager == null` (caso normal en
## tests unitarios que no pasan por EmpireController), devuelve el coste
## crudo — sin modifiers no hay descuento que aplicar.
##
## Todos los consumers del coste (deduccion al construir/mejorar, filtros
## de affordability en la IA, UI que muestra el precio) deben usar este
## metodo en lugar de `construction_cost` directamente, para que cualquier
## descuento del juego se aplique de forma consistente.
func get_effective_construction_cost(stats:Stats) -> int:
	if stats == null or stats.modifier_manager == null:
		return construction_cost
	var multiplier:float = stats.modifier_manager.get_build_cost_multiplier()
	return int(construction_cost * multiplier)
