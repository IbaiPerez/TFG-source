extends RefCounted
class_name TutorialText

## Base compartida por las clases de contenido del tutorial: localización de la
## prosa larga y formato de las cifras de balance.
##
## Es RefCounted y no un módulo estático porque `tr()` es un método de Object.


## Helper de localización para el texto largo del tutorial. Devuelve la cadena
## en inglés si el locale activo es "en"; en español en cualquier otro caso.
## Se usa en lugar de claves del CSV porque los bloques de prosa son extensos y
## específicos del tutorial — mantenerlos inline es más legible que en el CSV.
func _L(es: String, en: String) -> String:
	return en if TranslationServer.get_locale().begins_with("en") else es


# ─────────────────────────────────────────────────────────────────────────────
# Helpers de formato
# ─────────────────────────────────────────────────────────────────────────────

func _prod(gold: int, food: int) -> String:
	var parts: Array[String] = []
	if gold > 0:
		parts.append(_L("+%d oro", "+%d gold") % gold)
	elif gold < 0:
		parts.append(_L("−%d oro", "−%d gold") % absi(gold))
	if food > 0:
		parts.append(_L("+%d comida", "+%d food") % food)
	elif food < 0:
		parts.append(_L("−%d comida", "−%d food") % absi(food))
	return ", ".join(parts)


func _sgold(gold: int) -> String:
	if gold >= 0:
		return _L("+%d oro/turno", "+%d gold/turn") % gold
	return _L("−%d oro/turno", "−%d gold/turn") % absi(gold)


func _sfood(food: int) -> String:
	if food >= 0:
		return _L("+%d comida/turno", "+%d food/turn") % food
	return _L("−%d comida/turno", "−%d food/turn") % absi(food)


func _biome_label(biome: int) -> String:
	var key := Tile.biome_key(biome)
	return tr(key) if key != "" else "?"


## Nombre del tipo de tropa. Delega en la única fuente del juego: este módulo
## tenía su propia tabla y llamaba "Tiradores" y "Milicia" a los tipos que el
## resto de la interfaz nombra "A Distancia" e "Infantería Ligera".
func _troop_type_label(t: int) -> String:
	return Troop.type_label_for(t)
