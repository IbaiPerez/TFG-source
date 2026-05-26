extends GutTest

## Verifica que el .tres del Cuartel y el de la Academia Militar cargan
## con la estructura esperada. Sirve de regresion: si alguien rompe el
## resource (cambio de stat_type, perdida de un effect, valor numerico
## erroneo) este test falla antes de que la sim militar lo note.
##
## Mira solo el contrato visible (cantidad y tipo de effects, location_type,
## upgrades, stat_type del modifier), no internals de Godot.


const CUARTEL := preload("res://resources/buildings/lategame/cuartel_expansion.tres")
const ACADEMIA := preload("res://resources/buildings/lategame/academia_militar.tres")
const RECRUIT_CARD := preload("res://resources/cards/recruit_card.tres")


# ============================================================
#  Cuartel base
# ============================================================

func test_cuartel_loads_with_basic_fields() -> void:
	assert_not_null(CUARTEL, "El .tres del Cuartel debe cargarse")
	assert_eq(CUARTEL.name, "Cuartel")
	# El usuario itera coste/mantenimiento en paralelo; el test verifica
	# que los campos existen y son del orden correcto sin clavar el valor
	# exacto (que puede cambiar durante el tuning).
	assert_gt(CUARTEL.construction_cost, 0, "El Cuartel debe tener coste positivo")
	assert_lt(CUARTEL.gold_produced, 0,
		"El Cuartel cuesta oro de mantenimiento (gold_produced < 0)")
	assert_eq(CUARTEL.food_produced, 0, "El Cuartel no produce ni consume comida")


func test_cuartel_buildable_in_village_town_and_megalopolis() -> void:
	var loc_types: Array = []
	for loc in CUARTEL.allowed_location_type:
		loc_types.append(loc.type)
	assert_true(Tile.location_type.Village in loc_types,
		"El Cuartel debe poder construirse en Village (cualquier ciudad)")
	assert_true(Tile.location_type.Town in loc_types)
	assert_true(Tile.location_type.Megalopolis in loc_types)


func test_cuartel_has_two_effects() -> void:
	# +1 troops_per_recruit y AddCardToDeck(Recruit).
	assert_eq(CUARTEL.effects.size(), 2,
		"El Cuartel tiene exactamente 2 effects: stat modifier + add card")


func test_cuartel_first_effect_is_troops_per_recruit() -> void:
	# Duck-typing: comprobamos por la propiedad `stat_type` en lugar de
	# castear a `AddStatModifierEffect`. El static checker de GDScript
	# rechaza el cast porque el `Array[BuildingEffect]` esta tipado por
	# la clase base y no propaga la herencia de las subclases a traves
	# de la serializacion del .tres. `Object.get("prop")` devuelve null
	# si la propiedad no existe, asi que sirve como check de subtipo
	# sin pelearse con el sistema de tipos.
	var eff = CUARTEL.effects[0]
	assert_eq(eff.get("stat_type"), StatModifier.StatType.TROOPS_PER_RECRUIT,
		"Primer effect debe ser un modifier de TROOPS_PER_RECRUIT")
	assert_almost_eq(eff.get("value"), 1.0, 0.001,
		"El Cuartel debe dar +1 al bonus de tropas por play")


func test_cuartel_second_effect_adds_recruit_card() -> void:
	var eff = CUARTEL.effects[1]
	var added_card = eff.get("card")
	assert_not_null(added_card,
		"Segundo effect debe tener una propiedad `card` (AddCardToDeckEffect)")
	assert_eq(added_card.id, RECRUIT_CARD.id,
		"La carta a añadir debe ser una RecruitCard")
	# Opcion 2: el Cuartel debe tener first_only=true, asi el deck no
	# se inunda al apilar Cuarteles. Solo el primero suelta carta.
	assert_eq(eff.get("first_only"), true,
		"El AddCardToDeckEffect del Cuartel debe tener first_only=true")


func test_cuartel_upgrades_to_academia() -> void:
	assert_eq(CUARTEL.upgrades_to.size(), 1,
		"El Cuartel debe poder mejorarse a Academia Militar")
	assert_eq(CUARTEL.upgrades_to[0].name, "Academia Militar")


# ============================================================
#  Academia Militar (upgrade)
# ============================================================

func test_academia_loads_with_basic_fields() -> void:
	assert_not_null(ACADEMIA, "El .tres de la Academia debe cargarse")
	assert_eq(ACADEMIA.name, "Academia Militar")
	# Igual que en Cuartel, el usuario afina los numeros en paralelo. Solo
	# verificamos relaciones de orden con el Cuartel base.
	assert_gt(ACADEMIA.construction_cost, CUARTEL.construction_cost,
		"La Academia es mas cara que el Cuartel base")
	assert_lt(ACADEMIA.gold_produced, CUARTEL.gold_produced,
		"La Academia cuesta mas mantenimiento que el Cuartel (mas negativo)")
	assert_eq(ACADEMIA.food_produced, 0)


func test_academia_only_in_megalopolis() -> void:
	assert_eq(ACADEMIA.allowed_location_type.size(), 1)
	assert_eq(ACADEMIA.allowed_location_type[0].type,
		Tile.location_type.Megalopolis,
		"La Academia solo es construible en Megalopolis")


func test_academia_has_three_effects() -> void:
	# +1 troops_per_recruit (replica del Cuartel base que se substituye)
	# + -20% mantenimiento + AddCardToDeck(Recruit).
	assert_eq(ACADEMIA.effects.size(), 3,
		"La Academia tiene 3 effects: troops bonus + maintenance discount + add card")


func test_academia_has_troops_per_recruit_bonus() -> void:
	# Duck-typing: identificamos cada effect por sus propiedades en lugar
	# de hacer cast a subclases concretas (que GDScript rechaza en
	# tiempo de compilacion sobre `Array[BuildingEffect]`).
	var found := false
	for eff in ACADEMIA.effects:
		var stat_type = eff.get("stat_type")
		if stat_type == StatModifier.StatType.TROOPS_PER_RECRUIT:
			assert_almost_eq(eff.get("value"), 1.0, 0.001,
				"El bonus de la Academia debe ser +1 (mismo que el Cuartel)")
			found = true
	assert_true(found,
		"La Academia debe tener un effect TROOPS_PER_RECRUIT")


func test_academia_has_maintenance_discount() -> void:
	var found := false
	for eff in ACADEMIA.effects:
		var stat_type = eff.get("stat_type")
		if stat_type == StatModifier.StatType.TROOP_MAINTENANCE_PERCENT:
			assert_almost_eq(eff.get("value"), -20.0, 0.001,
				"El descuento de mantenimiento debe ser -20%")
			found = true
	assert_true(found,
		"La Academia debe tener un effect TROOP_MAINTENANCE_PERCENT -20%")


func test_academia_adds_recruit_card() -> void:
	# El AddCardToDeckEffect se identifica por tener una propiedad `card`
	# (las otras subclases de BuildingEffect del Cuartel/Academia no la
	# tienen, asi que sirve como discriminador). Ademas debe ser
	# first_only=true (Opcion 2): apilar 5 Academias no inunda el deck.
	var found := false
	for eff in ACADEMIA.effects:
		var card_property = eff.get("card")
		if card_property != null and card_property.id == RECRUIT_CARD.id:
			found = true
			assert_eq(eff.get("first_only"), true,
				"El AddCardToDeckEffect de la Academia debe tener first_only=true")
	assert_true(found,
		"La Academia tambien añade una carta Recruit al construirse")
