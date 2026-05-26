extends Resource
class_name Empire

@export var name:String
@export var color:Color
@export var ability:EmpireAbility
var controlled_tiles:Array[Tile] = []

## Multiplicador de ataque y defensa de las tropas del imperio, derivado
## del estado economico. Lo recalcula `EmpireController` cada turno: si la
## produccion (oro o comida) cae en negativo, se considera que parte del
## mantenimiento no esta cubierto y las tropas operan a menor capacidad.
##
## Rango: [0.1, 1.0]. 1.0 = economia sana, 0.1 = colapso absoluto (las
## tropas conservan el 10% minimo de sus stats). El clamp existe para que
## una tropa nunca quede totalmente neutralizada.
##
## Solo afecta a la contribucion de tropas a `BattleFront.get_total_attack`
## y `get_total_defense` — edificios y bonuses de tacticas siguen al 100%.
var combat_multiplier:float = 1.0

signal tile_conquered(tile:Tile)
signal tile_lost(tile:Tile)

func add_tile(tile:Tile):
	if tile not in controlled_tiles:
		controlled_tiles.append(tile)
		tile.set_controller(self)
		tile_conquered.emit(tile)

func remove_tile(tile:Tile):
	if tile in controlled_tiles:
		controlled_tiles.erase(tile)
		tile.set_controller(null)
		tile_lost.emit(tile)

func reset_controlled_tiles() -> void:
	controlled_tiles = []
	# Estado economico tambien fresh entre partidas/runs.
	combat_multiplier = 1.0

func create_instance() -> Empire:
	var empire:Empire = self.duplicate()
	empire.name = name
	empire.color = color
	empire.ability = ability
	empire.controlled_tiles = []
	return empire
