extends Resource
class_name BiomeConfig

## Configuración de multiplicadores de bioma para el combate.
##
## ATK: cuánto cuesta asaltar una tile del bioma dado (se aplica al
##   atacante, usando la tile CONTRARIA).
## DEF: cuánto refuerza el bioma a los defensores (se aplica sobre
##   la tile PROPIA del bando que defiende).
##
## Claves: Tile.biome_type (int). Biomas no listados → 1.0 (neutro).
##
## Cargado una única vez al inicio; guardar la instancia en BattleFront
## evita re-cargarla cada turno.

## Multiplicador que se aplica al ATK efectivo del bando que ataca
## la tile del bioma indicado.
@export var biome_attack_multipliers: Dictionary = {}

## Multiplicador que se aplica a la DEF de las tropas del bando que
## defiende en la tile del bioma indicado.
@export var biome_defense_multipliers: Dictionary = {}


func _init() -> void:
	if biome_attack_multipliers.is_empty():
		# Rango ~[0.6, 1.2]. Forestas y montañas frenan al asaltante.
		biome_attack_multipliers = {
			Tile.biome_type.Grassland: 1.20,
			Tile.biome_type.Desert:    1.10,
			Tile.biome_type.Tundra:    0.95,
			Tile.biome_type.Forest:    0.80,
			Tile.biome_type.Swamp:     0.70,
			Tile.biome_type.Mountain:  0.60,
			Tile.biome_type.Ocean:     1.00,
		}
	if biome_defense_multipliers.is_empty():
		# Rango ~[0.85, 1.5]. Montañas = mejor posición defensiva.
		biome_defense_multipliers = {
			Tile.biome_type.Mountain:  1.50,
			Tile.biome_type.Forest:    1.25,
			Tile.biome_type.Swamp:     1.20,
			Tile.biome_type.Tundra:    1.00,
			Tile.biome_type.Grassland: 0.90,
			Tile.biome_type.Desert:    0.85,
			Tile.biome_type.Ocean:     1.00,
		}


## Multiplicador de ataque para el bioma dado (tile que se intenta conquistar).
## Biomas no listados devuelven 1.0 (neutro).
func get_attack_multiplier(biome: int) -> float:
	return float(biome_attack_multipliers.get(biome, 1.0))


## Multiplicador de defensa para el bioma dado (tile donde se defiende).
## Biomas no listados devuelven 1.0 (neutro).
func get_defense_multiplier(biome: int) -> float:
	return float(biome_defense_multipliers.get(biome, 1.0))
