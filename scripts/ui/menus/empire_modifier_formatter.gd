class_name EmpireModifierFormatter

## Convierte los modificadores de una habilidad de imperio en lineas BBCode
## coloreadas y localizadas para la pantalla de seleccion de imperio.
##
## Fuente unica de verdad: `EmpireAbility.create_modifiers()` — exactamente los
## mismos modifiers que el juego aplica en partida. Asi la descripcion mostrada
## nunca se desincroniza de la mecanica real; si se reajusta un bonus en el
## codigo de la habilidad, esta pantalla lo refleja automaticamente.
##
## Metodos estaticos: usa TranslationServer.translate (no tr(), que requiere
## una instancia de Object) para resolver las claves de localizacion.

# Paleta semantica, alineada con los tooltips de cartas del CSV.
const COL_GOLD  := "#8A6A1A"  ## oro / economia
const COL_GREEN := "#5B7A3A"  ## comida / bonus favorable (descuentos)
const COL_RED   := "#8B1A1A"  ## penalizacion / militar
const COL_BLUE  := "#4A6A8A"  ## entidades (recursos, cartas, edificios)


## Devuelve una linea BBCode por cada modificador de la habilidad, mas una
## por cada edificio exclusivo. Array vacio si la habilidad es null o no
## aporta modificadores describibles.
static func describe_ability(ability: EmpireAbility) -> Array[String]:
	var lines: Array[String] = []
	if ability == null:
		return lines
	for mod in ability.create_modifiers():
		var line := _describe_modifier(mod)
		if line != "":
			lines.append(line)
	for building in ability.exclusive_buildings:
		if building != null:
			lines.append(_t("MODF_EXCLUSIVE_BUILDING") % _c(COL_BLUE, _t(building.name)))
	return lines


static func _describe_modifier(mod: Modifier) -> String:
	if mod is StatModifier:
		return _describe_stat(mod)
	if mod is BuildCostModifier:
		var pct := int(mod.percent)
		var body := _c(COL_GREEN, "-%d%%" % pct) if pct >= 0 else _c(COL_RED, "+%d%%" % absi(pct))
		return _t("MODF_BUILD_COST") % body
	if mod is CardReturnModifier:
		return _t("MODF_CARD_RETURN") % [
			_c(COL_BLUE, "%d%%" % int(mod.chance * 100.0)),
			_c(COL_BLUE, _t(_card_key(mod.card_id))),
		]
	if mod is GoldOnCardModifier:
		var col := COL_GOLD if mod.gold_amount >= 0 else COL_RED
		return _t("MODF_GOLD_ON_CARD") % [
			_c(col, "%+d" % mod.gold_amount),
			_c(COL_BLUE, _t(_card_key(mod.card_id))),
		]
	# Cualquier otro tipo: cae a la descripcion auto del modifier (sin color).
	return mod.description


static func _describe_stat(mod: StatModifier) -> String:
	var v := int(mod.value)
	match mod.type:
		StatModifier.StatType.PERCENT_GOLD:
			return _t("MODF_PERCENT_GOLD") % _c(COL_GOLD, "%+d%%" % v)
		StatModifier.StatType.PERCENT_FOOD:
			return _t("MODF_PERCENT_FOOD") % _c(COL_GREEN, "%+d%%" % v)
		StatModifier.StatType.FLAT_GOLD:
			return _t("MODF_FLAT_GOLD") % _c(COL_GOLD, "%+d" % v)
		StatModifier.StatType.FLAT_FOOD:
			return _t("MODF_FLAT_FOOD") % _c(COL_GREEN, "%+d" % v)
		StatModifier.StatType.TILE_RESOURCE_FOOD:
			return _t("MODF_TILE_FOOD") % [_c(COL_GREEN, "%+d" % v), _c(COL_BLUE, _resource_name(mod))]
		StatModifier.StatType.TILE_RESOURCE_GOLD:
			return _t("MODF_TILE_GOLD") % [_c(COL_GOLD, "%+d" % v), _c(COL_BLUE, _resource_name(mod))]
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT:
			# Descuento (valor negativo) = favorable → verde; encarecimiento → rojo.
			var col := COL_GREEN if v <= 0 else COL_RED
			var body := _c(col, "%d%%" % v)
			if mod.troop_type_filter == Troop.TroopType.CABALLERIA:
				return _t("MODF_TROOP_MAINT_CAVALRY") % body
			return _t("MODF_TROOP_MAINT") % body
	# StatType sin plantilla dedicada: descripcion auto del modifier.
	return mod.description


static func _resource_name(mod: StatModifier) -> String:
	if mod.target_resource != null:
		return _t(mod.target_resource.name)
	return "?"


static func _card_key(card_id: String) -> String:
	match card_id:
		"Colonize": return "CARD_COLONIZE_NAME"
		"Build Card": return "CARD_BUILD_NAME"
	return card_id


static func _c(hex: String, text: String) -> String:
	return "[color=%s]%s[/color]" % [hex, text]


static func _t(key: String) -> String:
	return String(TranslationServer.translate(key))
