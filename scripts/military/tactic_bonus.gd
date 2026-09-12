extends Resource
class_name TacticBonus

## Bonus táctico de un bando en un frente (carta táctica, evento, edificio).

@export var attack: float = 0.0
@export var attack_percent: float = 0.0
@export var attack_per_troop: float = 0.0
@export var attack_percent_per_type: float = 0.0
@export var attack_biome_modifier: float = 1.0

@export var defense: float = 0.0
@export var defense_percent: float = 0.0
@export var defense_per_troop: float = 0.0
@export var defense_percent_per_type: float = 0.0
@export var defense_biome_modifier: float = 1.0

## Tipo(s) de tropa afectados. `troop_types` tiene precedencia sobre `troop_type`
## que a su vez tiene precedencia sobre `troop_name` (compatibilidad legacy).
@export var troop_types: Array[int] = []
@export var troop_type: int = -1           # -1 = no establecido
@export var troop_name: String = ""

@export var tactic_name: String = ""
@export var duration: int = -1             # -1 = permanente (sin expiración)


## Construye un TacticBonus a partir de un Dictionary (el formato del save y el
## que usan las cartas tácticas y los tests para declarar bonuses).
static func from_dict(d: Dictionary) -> TacticBonus:
	var b := TacticBonus.new()
	b.attack                  = float(d.get("attack", 0.0))
	b.attack_percent          = float(d.get("attack_percent", 0.0))
	b.attack_per_troop        = float(d.get("attack_per_troop", 0.0))
	b.attack_percent_per_type = float(d.get("attack_percent_per_type", 0.0))
	b.attack_biome_modifier   = float(d.get("attack_biome_modifier", 1.0))
	b.defense                 = float(d.get("defense", 0.0))
	b.defense_percent         = float(d.get("defense_percent", 0.0))
	b.defense_per_troop       = float(d.get("defense_per_troop", 0.0))
	b.defense_percent_per_type = float(d.get("defense_percent_per_type", 0.0))
	b.defense_biome_modifier  = float(d.get("defense_biome_modifier", 1.0))
	b.tactic_name             = String(d.get("tactic_name", ""))
	b.troop_name              = String(d.get("troop_name", ""))
	# duration: -1 significa permanente; si el dict no tiene "duration", se deja en -1.
	if d.has("duration"):
		b.duration = int(d["duration"])
	else:
		b.duration = -1
	# troop_types (array, precedencia máxima)
	if d.has("troop_types"):
		var arr: Array = d["troop_types"]
		b.troop_types.clear()
		for t in arr:
			b.troop_types.append(int(t))
	# troop_type (singular)
	if d.has("troop_type"):
		b.troop_type = int(d["troop_type"])
	return b
