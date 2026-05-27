extends Resource
class_name TacticBonus

## Recurso tipado que reemplaza los diccionarios de bonus táctico en BattleFront.
##
## Mantiene compatibilidad con el acceso por clave estilo Dictionary:
##   bonus["attack"]            → llama a _get("attack")
##   bonus.has("tactic_name")   → método explícito
##   bonus.get("attack", 0.0)   → método explícito
##
## Esto permite que el código existente (tests incluidos) siga funcionando
## sin modificaciones mientras battle_front.gd accede a .attack, .defense, etc.

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


## Construye un TacticBonus a partir de un Dictionary con claves legacy.
## Permite migración incremental: el código antiguo sigue pasando dicts y
## `add_bonus` en battle_front convierte internamente.
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


## Soporte para acceso estilo Dictionary: bonus["attack"] → bonus.attack
## Permite que código y tests que usan [] sigan funcionando.
func _get(property: StringName) -> Variant:
	match property:
		"attack":                   return attack
		"attack_percent":           return attack_percent
		"attack_per_troop":         return attack_per_troop
		"attack_percent_per_type":  return attack_percent_per_type
		"attack_biome_modifier":    return attack_biome_modifier
		"defense":                  return defense
		"defense_percent":          return defense_percent
		"defense_per_troop":        return defense_per_troop
		"defense_percent_per_type": return defense_percent_per_type
		"defense_biome_modifier":   return defense_biome_modifier
		"tactic_name":              return tactic_name
		"troop_name":               return troop_name
		"troop_type":               return troop_type
		"troop_types":              return troop_types
		"duration":                 return duration
	return null


## Comprueba si esta instancia "tiene" una clave, imitando Dictionary.has().
## Devuelve true si la clave existe y su valor no es el default vacío/cero.
## Semántica: "clave presente y significativa" como en los dicts originales.
func has(key: String) -> bool:
	match key:
		"attack":                   return attack != 0.0
		"attack_percent":           return attack_percent != 0.0
		"attack_per_troop":         return attack_per_troop != 0.0
		"attack_percent_per_type":  return attack_percent_per_type != 0.0
		"attack_biome_modifier":    return true  # siempre presente (default 1.0)
		"defense":                  return defense != 0.0
		"defense_percent":          return defense_percent != 0.0
		"defense_per_troop":        return defense_per_troop != 0.0
		"defense_percent_per_type": return defense_percent_per_type != 0.0
		"defense_biome_modifier":   return true  # siempre presente (default 1.0)
		"tactic_name":              return tactic_name != ""
		"troop_name":               return troop_name != ""
		"troop_type":               return troop_type >= 0
		"troop_types":              return not troop_types.is_empty()
		"duration":                 return duration >= 0
	return false


## Versión tipada de get() con fallback, imitando Dictionary.get().
## NOTA: No se puede sobrecarga Object.get() nativamente en Godot 4.5.
## Esta función proporciona la funcionalidad de fallback para tests y código.
func get_value(key: String, default: Variant = null) -> Variant:
	var val: Variant = _get(key)
	if val == null:
		return default
	return val
