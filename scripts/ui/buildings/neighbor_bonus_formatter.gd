extends RefCounted
class_name NeighborBonusFormatter

## Texto legible de una [NeighborBonus] para la UI.
##
## El molino no produce nada en su casilla: todo su valor está en el vecindario, así
## que una carta de edificio que solo enseñe `food_produced` diría "0 de comida" y el
## jugador no entendería para qué sirve el edificio ni por qué cuesta 120.
##
## Vive aparte de `building_card.gd` porque la frase la necesita cualquiera que
## describa un edificio (la carta, el panel de casilla, el tutorial), y duplicarla
## garantizaría que un día digan cosas distintas.
##
## Métodos estáticos: usa `TranslationServer.translate`, no `tr()`, que necesita una
## instancia de Node. Las claves NUNCA se construyen concatenando — para la
## localización se usa el helper `Tile.location_key`, que lo vigila `test_i18n_keys`.


## Frase de una bonificación, ya traducida. Vacía si no concede nada.
## Ejemplo: "+5 de comida a cada Aldea propia adyacente".
static func describe(bonus: NeighborBonus) -> String:
	if bonus == null or bonus.is_empty():
		return ""
	var partes := PackedStringArray()
	if bonus.food != 0:
		partes.append(_t("BLD_NEIGHBOR_FOOD") % ["%+d" % bonus.food])
	if bonus.gold != 0:
		partes.append(_t("BLD_NEIGHBOR_GOLD") % ["%+d" % bonus.gold])
	if not is_zero_approx(bonus.food_percent):
		partes.append(_t("BLD_NEIGHBOR_FOOD_PCT") % ["%+.0f" % bonus.food_percent])
	if partes.is_empty():
		return ""
	return _t("BLD_NEIGHBOR_BONUS") % [", ".join(partes), _describe_targets(bonus)]


## A quién alcanza: "Aldea propia", "casilla propia", "Aldea, Ciudad"…
static func _describe_targets(bonus: NeighborBonus) -> String:
	var quien := ""
	if bonus.allowed_locations.is_empty():
		quien = _t("BLD_NEIGHBOR_ANY_TILE")
	else:
		var nombres := PackedStringArray()
		for loc in bonus.allowed_locations:
			nombres.append(_t(Tile.location_key(loc)))
		quien = ", ".join(nombres)
	if bonus.only_same_owner:
		quien += " " + _t("BLD_NEIGHBOR_OWN")
	return quien


## Todas las bonificaciones de un edificio, una por línea. Vacío si no tiene.
static func describe_all(building: Building) -> String:
	if building == null:
		return ""
	var lineas := PackedStringArray()
	for b in building.neighbor_bonuses:
		var t := describe(b)
		if t != "":
			lineas.append(t)
	return "\n".join(lineas)


static func _t(key: String) -> String:
	return String(TranslationServer.translate(key))
