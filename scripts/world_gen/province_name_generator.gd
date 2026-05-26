extends RefCounted
class_name ProvinceNameGenerator

## Generador silábico de nombres de provincia por bioma.
##
## Cada bioma tiene su propio estilo fonético:
##   Grassland → Latino/Romano     (Valentia, Coranum, Beloria)
##   Forest    → Celta/Élfico      (Sylethyn, Duinwenith, Caerynel)
##   Desert    → Árabe/Semítico    (Alkarah, Zalamesh, Sirahan)
##   Swamp     → Eslavo/Oscuro     (Voronsk, Bolokev, Mrakevna)
##   Tundra    → Nórdico           (Bjordalr, Iskvikar, Kaldborga)
##   Mountain  → Enano/Pétreo      (Karakholm, Durunen, Granhold)
##   Ocean     → Griego            (Thalassos, Aegiron, Pontaros)
##
## La función `generate()` es determinista: la misma posición de grid siempre
## produce el mismo nombre, independientemente del orden de generación.

static var _data: Dictionary = {
	"Grassland": {
		"prefix": ["Val", "Cor", "Cam", "Aur", "Bel", "Mar", "Ter", "Gal", "Sal", "Pal"],
		"root":   ["ent", "an",  "ar",  "en",  "or",  "in",  "al",  "ur",  "ot",  "un"],
		"suffix": ["a",   "um",  "ia",  "us",  "ae",  "o",   "as",  "ius"]
	},
	"Forest": {
		"prefix": ["Syl", "Duin", "Caer", "Bren", "Fern", "Nan", "Tir", "Gwyr", "Mor", "Eir"],
		"root":   ["eth", "wen",  "ren",  "ael",  "ith",  "yn",  "el",  "and",  "or",  "ar"],
		"suffix": ["wen", "yn",   "ith",  "en",   "el",   "or",  "ath", "is",   "ar",  "an"]
	},
	"Desert": {
		"prefix": ["Al",  "Si",  "Za",  "Ra",  "Sa",  "Ha",  "Kha", "An",  "Ma",  "Qa"],
		"root":   ["kar", "rah", "lam", "nar", "far", "sir", "bar", "dar", "war", "mal"],
		"suffix": ["a",   "ah",  "esh", "an",  "ir",  "at",  "in",  "i",   "um",  "ara"]
	},
	"Swamp": {
		"prefix": ["Vor",  "Mrak", "Bol", "Tor",  "Gnil", "Mog", "Chern", "Zal", "Blag", "Kry"],
		"root":   ["on",   "ev",   "ok",  "ar",   "in",   "an",  "il",    "ot",  "uk",   "em"],
		"suffix": ["sk",   "ev",   "ka",  "ov",   "ich",  "na",  "ets",   "in",  "ek",   "ya"]
	},
	"Tundra": {
		"prefix": ["Bjor", "Isk",  "Grim", "Hvit", "Kald", "Sno", "Ulf",  "Orm", "Dag",  "Arv"],
		"root":   ["dal",  "vik",  "fell", "borg", "stad", "nes", "and",  "fjor","heim", "mark"],
		"suffix": ["r",    "en",   "a",    "ar",   "i",    "ur",  "d",    "mar", "vik",  "el"]
	},
	"Mountain": {
		"prefix": ["Kar",  "Dur",  "Krak", "Gran", "Bul",  "Dag", "Rok",  "Stor","Dum",  "Gor"],
		"root":   ["ak",   "un",   "im",   "or",   "ar",   "um",  "ok",   "ur",  "el",   "in"],
		"suffix": ["holm", "vast", "hold", "gate", "fell", "ar",  "im",   "ur",  "en",   "rock"]
	},
	"Ocean": {
		"prefix": ["Tha",  "Ae",   "Pont", "Neri", "Pela", "Neo", "Ky",   "Hali","Tri",  "Meso"],
		"root":   ["lass", "gir",  "ant",  "ar",   "on",   "er",  "tos",  "eros","as",   "eid"],
		"suffix": ["os",   "on",   "is",   "idos", "ara",  "eia", "ion",  "sos", "ikon", "a"]
	},
}

## Fallback para biomas no reconocidos (no debería ocurrir, pero por si acaso).
static var _fallback_key: String = "Grassland"


## Genera un nombre de provincia determinista.
##
## @param biome     Nombre del bioma (debe coincidir con Tile.biome_type keys).
## @param grid_pos  Posición en el grid hexagonal (Vector2). Actúa como seed.
## @return          Nombre generado (capitalizado).
static func generate(biome: String, grid_pos: Vector2) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = _pos_seed(grid_pos)

	var data: Dictionary = _data.get(biome, _data[_fallback_key])

	var prefix: String = _pick(rng, data["prefix"])
	var root:   String = _pick(rng, data["root"])
	var suffix: String = _pick(rng, data["suffix"])

	return prefix + root + suffix


## Convierte una posición de grid en un seed entero reproducible.
static func _pos_seed(grid_pos: Vector2) -> int:
	# Empaquetamos x e y en un entero de 64 bits para evitar colisiones
	# entre posiciones como (1,2) y (12, ...).
	var ix: int = int(grid_pos.x) + 1000
	var iy: int = int(grid_pos.y) + 1000
	return ix * 100003 + iy   # 100003 es primo → buena dispersión


## Elige un elemento del array usando el RNG dado.
static func _pick(rng: RandomNumberGenerator, arr: Array) -> String:
	return arr[rng.randi() % arr.size()]
