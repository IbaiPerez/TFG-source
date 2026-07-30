extends RefCounted
class_name SerializationUtils

## Empaquetado y desempaquetado de los campos ESCALARES PLANOS de un objeto, a
## partir de una tabla declarativa (refactor §2.6.b).
##
## Antes cada serializador escribía el mismo campo DOS veces —una en `to_dict`
## (`"total_gold": stats.total_gold`) y otra en `from_dict`
## (`stats.total_gold = int(data.get("total_gold", 0))`)—, dos ediciones simétricas
## que es fácil desincronizar: añadir el campo solo al pack lo hace desaparecer
## silenciosamente al cargar. Con la tabla, cada campo se declara UNA vez.
##
## ALCANCE, a propósito limitado: solo campos escalares (int/float/bool/String) que
## viajan tal cual. Los que necesitan traducción —recursos por path o registry,
## referencias a Empire/Tile, pilas de cartas, arrays de tropas— se quedan escritos
## a mano en cada serializador, porque su lógica es lo suyo propio y meterla aquí
## solo la escondería. Medido antes de hacerlo: de ~66 líneas de pack en
## `scripts/save/`, unas 15 son de este tipo.
##
## `KEEP` como default significa «si el save no trae el campo, deja el valor que el
## objeto ya tiene». Es lo que necesitan los campos que vienen del template del
## imperio (cards_per_turn, event_chance) o del propio constructor (min_duration,
## threshold), donde el default correcto NO es 0 sino lo que ya había.

## Centinela de default: conservar el valor actual del objeto.
const KEEP := "__keep__"


## Vuelca a un Dictionary los campos declarados en `fields` (nombre → default).
## El default no se usa aquí; la tabla es la misma que consume `unpack`, de modo que
## ambas direcciones no pueden desincronizarse.
static func pack(obj:Object, fields:Dictionary) -> Dictionary:
	var out := {}
	for name in fields:
		out[name] = obj.get(name)
	return out


## Aplica sobre `obj` los campos declarados que vengan en `data`.
##
## Respeta los setters: se asigna por `obj.set(...)`, así que un campo con `set =`
## (p.ej. `Stats.total_gold`, que emite `stats_changed`) se comporta igual que con la
## asignación directa que sustituye. La conversión de tipo la hace GDScript al
## asignar sobre una propiedad tipada, que es lo que hacían los `int(...)`/`float(...)`
## explícitos de antes.
static func unpack(obj:Object, data:Dictionary, fields:Dictionary) -> void:
	for name in fields:
		var fallback = fields[name]
		if fallback is String and fallback == KEEP:
			fallback = obj.get(name)
		obj.set(name, data.get(name, fallback))
