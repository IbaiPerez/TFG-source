extends TutorialText
class_name TutorialBalanceEntries

## Entradas del manual que se COMPONEN leyendo los .tres reales de edificios,
## tropas, cartas tácticas e imperios (costes, producción, ATK/DEF, bonus de
## bioma). Están separadas de la prosa fija justo por eso: son las que no pueden
## desincronizarse del balance, y las que arrastran todos los preload.
##
## La prosa que no lee balance vive en [TutorialContent], que es quien ordena el
## manual y llama aquí.

# ── Troops ────────────────────────────────────────────────────────────────────
const _T_MILITIA        := preload("res://resources/troops/militia.tres")
const _T_RANGED         := preload("res://resources/troops/ranged.tres")
const _T_PIKEMEN        := preload("res://resources/troops/pikemen.tres")
const _T_CAVALRY        := preload("res://resources/troops/cavalry.tres")
const _T_HEAVY          := preload("res://resources/troops/heavy_infantry.tres")

# ── Tactic cards ──────────────────────────────────────────────────────────────
const _TC_CAVALRY_CHARGE  := preload("res://resources/cards/tactic_cavalry_charge.tres")
const _TC_PHALANX         := preload("res://resources/cards/tactic_phalanx.tres")
const _TC_ARROW_RAIN      := preload("res://resources/cards/tactic_arrow_rain.tres")
const _TC_AMBUSH          := preload("res://resources/cards/tactic_ambush.tres")
const _TC_FRONTAL_ASSAULT := preload("res://resources/cards/tactic_frontal_assault.tres")

# ── Empire abilities ──────────────────────────────────────────────────────────
const _AB_MEDICI   := preload("res://resources/empire_abilities/banca_florentina.tres")
const _AB_MONGOL   := preload("res://resources/empire_abilities/horde_nomada.tres")
const _AB_BABYLON  := preload("res://resources/empire_abilities/jardines_colgantes.tres")

# ── Empires ───────────────────────────────────────────────────────────────────
const _EMP_MEDICI  := preload("res://resources/empires/medici.tres")
const _EMP_MONGOL  := preload("res://resources/empires/mongol.tres")
const _EMP_BABYLON := preload("res://resources/empires/babylonian.tres")

# ── Basic buildings ───────────────────────────────────────────────────────────
const _B_CROPS          := preload("res://resources/buildings/basic/crops.tres")
const _B_FISHERY        := preload("res://resources/buildings/basic/fishery.tres")
const _B_GOLD_MINE      := preload("res://resources/buildings/basic/gold_mine.tres")
const _B_HUNTING        := preload("res://resources/buildings/basic/hunting_ground.tres")
const _B_IRON_MINE      := preload("res://resources/buildings/basic/iron_mine.tres")
const _B_LIVESTOCK_FARM := preload("res://resources/buildings/basic/livestock_farm.tres")
const _B_LOGGING_CAMP   := preload("res://resources/buildings/basic/logging_camp.tres")
const _B_QUARRY         := preload("res://resources/buildings/basic/quarry.tres")
const _B_SALT_MINE      := preload("res://resources/buildings/basic/salt_mine.tres")
const _B_SAND_PIT       := preload("res://resources/buildings/basic/sand_pit.tres")

# ── Upgrade buildings ─────────────────────────────────────────────────────────
const _B_GRANARY      := preload("res://resources/buildings/upgrades/granary.tres")
const _B_ROYAL_MINT   := preload("res://resources/buildings/upgrades/royal_mint.tres")
const _B_FORGE        := preload("res://resources/buildings/upgrades/forge.tres")
const _B_GLASSWORKS   := preload("res://resources/buildings/upgrades/glassworks.tres")
const _B_RANCH        := preload("res://resources/buildings/upgrades/ranch.tres")
const _B_TANNERY      := preload("res://resources/buildings/upgrades/tannery.tres")
const _B_SALT_REF     := preload("res://resources/buildings/upgrades/salt_refinery.tres")
const _B_SAWMILL      := preload("res://resources/buildings/upgrades/sawmill.tres")
const _B_STONECUTTER  := preload("res://resources/buildings/upgrades/stonecutter_workshop.tres")
const _B_FISHING_PORT := preload("res://resources/buildings/upgrades/fishing_port.tres")
const _B_FISH_MARKET  := preload("res://resources/buildings/upgrades/fishing_market.tres")

# ── Biome-specific buildings ──────────────────────────────────────────────────
const _B_MOLINO      := preload("res://resources/buildings/molino.tres")
const _B_SANTUARIO   := preload("res://resources/buildings/santuario_bosque.tres")
const _B_CARAVANA    := preload("res://resources/buildings/caravana_comercial.tres")
const _B_GRANJA_SANG := preload("res://resources/buildings/granja_sanguijuelas.tres")
const _B_FORTALEZA   := preload("res://resources/buildings/fortaleza.tres")
const _B_PORT        := preload("res://resources/buildings/port.tres")
const _B_OBSERV      := preload("res://resources/buildings/observatorio.tres")

# ── Town+ buildings ───────────────────────────────────────────────────────────
const _B_MARKET_SQ  := preload("res://resources/buildings/market_square.tres")
const _B_GREMIO     := preload("res://resources/buildings/gremio_mercaderes.tres")
const _B_WAREHOUSE  := preload("res://resources/buildings/warehouse.tres")
const _B_HUERTOS    := preload("res://resources/buildings/huertos_urbanos.tres")
const _B_TEMPLE     := preload("res://resources/buildings/temple.tres")
const _B_LIBRARY    := preload("res://resources/buildings/library.tres")
const _B_ANFITEATRO := preload("res://resources/buildings/anfiteatro.tres")
const _B_CUARTEL    := preload("res://resources/buildings/lategame/cuartel_expansion.tres")
const _B_COLISEO    := preload("res://resources/buildings/lategame/coliseo.tres")
const _B_OFICINA    := preload("res://resources/buildings/lategame/oficina_construccion.tres")
const _B_ESCUELA    := preload("res://resources/buildings/lategame/escuela_planificacion.tres")

# ── Megalopolis buildings ─────────────────────────────────────────────────────
const _B_PALACIO    := preload("res://resources/buildings/lategame/palacio_imperial.tres")
const _B_GRAN_BIBL  := preload("res://resources/buildings/lategame/gran_biblioteca.tres")
const _B_GRAN_CATED := preload("res://resources/buildings/lategame/gran_catedral.tres")
const _B_JARDINES_C := preload("res://resources/buildings/lategame/jardines_celestiales.tres")
const _B_TESORO     := preload("res://resources/buildings/lategame/tesoro_imperial.tres")
const _B_ACADEMIA   := preload("res://resources/buildings/lategame/academia_militar.tres")
const _B_PUERTO_COM := preload("res://resources/buildings/lategame/puerto_comercial.tres")

# NOTA: los edificios exclusivos (Banco, Zigurat) se describen en las entradas de
# Imperios a partir de la descripción de su habilidad, no de su .tres — por eso no
# se precargan aquí (los dos `const` que existían no los leía nadie).


# ─────────────────────────────────────────────────────────────────────────────
# Grupos de entradas que TutorialContent inserta tal cual
# ─────────────────────────────────────────────────────────────────────────────

func entries_natural_resources() -> Array[TutorialEntry]:
	return [_entry_food_resources(), _entry_wealth_resources()]


func entries_buildings() -> Array[TutorialEntry]:
	return [
		_entry_basic_buildings(),
		_entry_upgrade_buildings(),
		_entry_biome_buildings(),
		_entry_town_buildings(),
		_entry_megalopolis_buildings(),
	]


func entries_empires() -> Array[TutorialEntry]:
	return [
		_entry_empire(
			_EMP_MEDICI, _AB_MEDICI,
			_L("Estilo de juego: expansión económica progresiva. Los Medici construyen más barato y generan más oro desde el inicio. Su ventaja crece exponencialmente con el tiempo según acumulan edificios.\n\nDebilidad: vulnerables a presiones militares tempranas.\n\nConsejo: prioriza Minas de Oro y el Banco en los primeros turnos.",
				"Playstyle: progressive economic expansion. The Medici build cheaper and generate more gold from the start. Their advantage grows exponentially over time as they accumulate buildings.\n\nWeakness: vulnerable to early military pressure.\n\nTip: prioritize Gold Mines and the Bank in the first turns.")),
		_entry_empire(
			_EMP_MONGOL, _AB_MONGOL,
			_L("Estilo de juego: expansión agresiva desde el primer turno. La recuperación de Colonizar permite tomar muchos más territorios que cualquier otro Imperio.\n\nDebilidad: depende de expansión continua. Si la expansión se frena, puede quedarse sin recursos.\n\nConsejo: expande muy agresivamente los primeros turnos. Busca tiles de Pradera para Cargas de Caballería y tiles con Ganadería para la economía.",
				"Playstyle: aggressive expansion from the first turn. Recovering Colonize cards lets you take far more territory than any other Empire.\n\nWeakness: depends on continuous expansion. If expansion stalls, it can run out of resources.\n\nTip: expand very aggressively in the first turns. Look for Grassland tiles for Cavalry Charges and Livestock tiles for the economy.")),
		_entry_empire(
			_EMP_BABYLON, _AB_BABYLON,
			_L("Estilo de juego: equilibrio entre economía y producción de alimentos. Babilonia puede sostener más ciudades y Megalópolis gracias al bonus en Trigo.\n\nDebilidad: crece más despacio que Medici en oro puro y más despacio que Mongol en territorio.\n\nConsejo: busca tiles con Trigo activamente. Construye el Zigurat cuanto antes para iniciar la cadena hacia los Jardines Celestiales.",
				"Playstyle: a balance between economy and food production. Babylon can sustain more cities and Megalopolises thanks to its Wheat bonus.\n\nWeakness: grows slower than the Medici in pure gold and slower than the Mongols in territory.\n\nTip: actively look for Wheat tiles. Build the Ziggurat as soon as possible to start the chain toward the Celestial Gardens.")),
	]


# ─────────────────────────────────────────────────────────────────────────────
# Entradas compuestas a partir de los .tres de balance
# ─────────────────────────────────────────────────────────────────────────────

func _entry_food_resources() -> TutorialEntry:
	var fp := _B_FISHING_PORT
	var fm := _B_FISH_MARKET
	var body := _L("Cuatro recursos naturales producen principalmente comida:\n\n",
		"Four natural resources produce mainly food:\n\n")
	body += _L("• Trigo (Wheat) [solo Pradera] — Cultivos (coste %d): +%d comida/turno. Mejora a Granero (%d): +%d comida/turno.\n\n",
		"• Wheat [Grassland only] — Crops (cost %d): +%d food/turn. Upgrades to Granary (%d): +%d food/turn.\n\n") % [
		_B_CROPS.construction_cost, _B_CROPS.food_produced,
		_B_GRANARY.construction_cost, _B_GRANARY.food_produced]
	body += _L("• Ganadería (Livestock) [Tundra, Pradera, Desierto] — Granja de Ganado (%d): +%d comida, +%d oro/turno. Mejora a Rancho (%d): +%d comida, +%d oro/turno.\n\n",
		"• Livestock [Tundra, Grassland, Desert] — Livestock Farm (%d): +%d food, +%d gold/turn. Upgrades to Ranch (%d): +%d food, +%d gold/turn.\n\n") % [
		_B_LIVESTOCK_FARM.construction_cost, _B_LIVESTOCK_FARM.food_produced, _B_LIVESTOCK_FARM.gold_produced,
		_B_RANCH.construction_cost, _B_RANCH.food_produced, _B_RANCH.gold_produced]
	body += _L("• Pesca (Fish) [Océano, Pantano] — Pesquería (%d): +%d comida, +%d oro/turno. Mejora a Puerto Pesquero (%d, solo Océano, Town+): +%d comida, +%d oro; o a Mercado de Pescado (%d): +%d comida, +%d oro.\n\n",
		"• Fish [Ocean, Swamp] — Fishery (%d): +%d food, +%d gold/turn. Upgrades to Fishing Port (%d, Ocean only, Town+): +%d food, +%d gold; or to Fish Market (%d): +%d food, +%d gold.\n\n") % [
		_B_FISHERY.construction_cost, _B_FISHERY.food_produced, _B_FISHERY.gold_produced,
		fp.construction_cost, fp.food_produced, fp.gold_produced,
		fm.construction_cost, fm.food_produced, fm.gold_produced]
	body += _L("• Caza Mayor (Wild Game) [Bosque, Tundra] — Zona de Caza (%d): +%d comida, +%d oro/turno. Mejora a Tenería (%d): +%d comida, +%d oro/turno.",
		"• Wild Game [Forest, Tundra] — Hunting Ground (%d): +%d food, +%d gold/turn. Upgrades to Tannery (%d): +%d food, +%d gold/turn.") % [
		_B_HUNTING.construction_cost, _B_HUNTING.food_produced, _B_HUNTING.gold_produced,
		_B_TANNERY.construction_cost, _B_TANNERY.food_produced, _B_TANNERY.gold_produced]
	return TutorialEntry.new(_L("Recursos Naturales", "Natural Resources"), _L("Recursos alimentarios", "Food resources"), body)


func _entry_wealth_resources() -> TutorialEntry:
	var body := _L("Seis recursos naturales generan principalmente oro:\n\n",
		"Six natural resources generate mainly gold:\n\n")
	body += _L("• Oro (Gold) [todos los biomas] — Mina de Oro (coste %d): +%d oro/turno. Mejora a Casa de la Moneda (%d): +%d oro/turno. El más rentable del juego.\n\n",
		"• Gold [all biomes] — Gold Mine (cost %d): +%d gold/turn. Upgrades to Royal Mint (%d): +%d gold/turn. The most profitable in the game.\n\n") % [
		_B_GOLD_MINE.construction_cost, _B_GOLD_MINE.gold_produced,
		_B_ROYAL_MINT.construction_cost, _B_ROYAL_MINT.gold_produced]
	body += _L("• Hierro (Iron) [Montaña, Desierto] — Mina de Hierro (%d): +%d oro/turno. Mejora a Herrería (%d): +%d oro/turno.\n\n",
		"• Iron [Mountain, Desert] — Iron Mine (%d): +%d gold/turn. Upgrades to Forge (%d): +%d gold/turn.\n\n") % [
		_B_IRON_MINE.construction_cost, _B_IRON_MINE.gold_produced,
		_B_FORGE.construction_cost, _B_FORGE.gold_produced]
	body += _L("• Sal (Salt) [Océano, Desierto] — Mina de Sal (%d): +%d oro/turno. Mejora a Refinería de Sal (%d): +%d oro/turno.\n\n",
		"• Salt [Ocean, Desert] — Salt Mine (%d): +%d gold/turn. Upgrades to Salt Refinery (%d): +%d gold/turn.\n\n") % [
		_B_SALT_MINE.construction_cost, _B_SALT_MINE.gold_produced,
		_B_SALT_REF.construction_cost, _B_SALT_REF.gold_produced]
	body += _L("• Madera (Wood) [Bosque, Pantano] — Campamento Forestal (%d): +%d oro/turno. Mejora a Serrería (%d): +%d oro/turno.\n\n",
		"• Wood [Forest, Swamp] — Logging Camp (%d): +%d gold/turn. Upgrades to Sawmill (%d): +%d gold/turn.\n\n") % [
		_B_LOGGING_CAMP.construction_cost, _B_LOGGING_CAMP.gold_produced,
		_B_SAWMILL.construction_cost, _B_SAWMILL.gold_produced]
	body += _L("• Piedra (Stone) [Montaña, Pradera] — Cantera (%d): +%d oro/turno. Mejora a Taller de Cantería (%d): +%d oro/turno.\n\n",
		"• Stone [Mountain, Grassland] — Quarry (%d): +%d gold/turn. Upgrades to Stonecutter Workshop (%d): +%d gold/turn.\n\n") % [
		_B_QUARRY.construction_cost, _B_QUARRY.gold_produced,
		_B_STONECUTTER.construction_cost, _B_STONECUTTER.gold_produced]
	body += _L("• Arena (Sand) [Desierto, Montaña] — Foso de Arena (%d): +%d oro/turno. Mejora a Vidriera (%d): +%d oro/turno.",
		"• Sand [Desert, Mountain] — Sand Pit (%d): +%d gold/turn. Upgrades to Glassworks (%d): +%d gold/turn.") % [
		_B_SAND_PIT.construction_cost, _B_SAND_PIT.gold_produced,
		_B_GLASSWORKS.construction_cost, _B_GLASSWORKS.gold_produced]
	return TutorialEntry.new(_L("Recursos Naturales", "Natural Resources"), _L("Recursos de riqueza", "Wealth resources"), body)


## Cuerpo de la entrada "La comida": lo compone porque enumera el mantenimiento
## real de cada tropa desde su .tres.
func food_body() -> String:
	var troops := [_T_MILITIA, _T_RANGED, _T_PIKEMEN, _T_CAVALRY, _T_HEAVY]
	var body := _L("La comida mantiene activas tus ciudades y tropas. Cada turno se descuenta:\n• Town: −5 comida/turno\n• Megalópolis: −10 comida/turno",
		"Food keeps your cities and troops active. Each turn the following is deducted:\n• Town: −5 food/turn\n• Megalopolis: −10 food/turn")
	for t in troops:
		if t.maintenance_food > 0:
			body += _L("\n• %s: −%d comida/turno por tropa", "\n• %s: −%d food/turn per troop") % [tr(t.name), t.maintenance_food]
	body += _L("\n\nSi tu producción no cubre el consumo, el déficit degrada el multiplicador de combate igual que el déficit de oro.\n\nCuidado con la expansión rápida: colonizar muchas ciudades sin suficiente producción de comida puede colapsar tu economía de golpe.",
		"\n\nIf your production does not cover consumption, the deficit degrades the combat multiplier just like a gold deficit.\n\nBe careful with rapid expansion: colonizing many cities without enough food production can collapse your economy all at once.")
	return body


func _entry_basic_buildings() -> TutorialEntry:
	var lines: Array[String] = [
		_L("Todos los edificios básicos requieren solo Aldea. Cada uno necesita el recurso natural específico en el tile:\n",
			"All basic buildings require only a Village. Each one needs the specific natural resource on the tile:\n"),
		_L("Recurso [biomas principales] → Edificio (coste) → Producción/turno",
			"Resource [main biomes] → Building (cost) → Production/turn"),
		_L("Trigo [Pradera] → Cultivos (%d) → +%d comida", "Wheat [Grassland] → Crops (%d) → +%d food") % [_B_CROPS.construction_cost, _B_CROPS.food_produced],
		_L("Pesca [Océano, Pantano] → Pesquería (%d) → +%d comida, +%d oro", "Fish [Ocean, Swamp] → Fishery (%d) → +%d food, +%d gold") % [_B_FISHERY.construction_cost, _B_FISHERY.food_produced, _B_FISHERY.gold_produced],
		_L("Oro [todos los biomas] → Mina de Oro (%d) → +%d oro", "Gold [all biomes] → Gold Mine (%d) → +%d gold") % [_B_GOLD_MINE.construction_cost, _B_GOLD_MINE.gold_produced],
		_L("Caza Mayor [Bosque, Tundra] → Zona de Caza (%d) → +%d comida, +%d oro", "Wild Game [Forest, Tundra] → Hunting Ground (%d) → +%d food, +%d gold") % [_B_HUNTING.construction_cost, _B_HUNTING.food_produced, _B_HUNTING.gold_produced],
		_L("Hierro [Montaña, Desierto] → Mina de Hierro (%d) → +%d oro", "Iron [Mountain, Desert] → Iron Mine (%d) → +%d gold") % [_B_IRON_MINE.construction_cost, _B_IRON_MINE.gold_produced],
		_L("Ganado [Tundra, Pradera, Desierto] → Granja de Ganado (%d) → +%d comida, +%d oro", "Livestock [Tundra, Grassland, Desert] → Livestock Farm (%d) → +%d food, +%d gold") % [_B_LIVESTOCK_FARM.construction_cost, _B_LIVESTOCK_FARM.food_produced, _B_LIVESTOCK_FARM.gold_produced],
		_L("Madera [Bosque, Pantano] → Campamento Forestal (%d) → +%d oro", "Wood [Forest, Swamp] → Logging Camp (%d) → +%d gold") % [_B_LOGGING_CAMP.construction_cost, _B_LOGGING_CAMP.gold_produced],
		_L("Piedra [Montaña, Pradera] → Cantera (%d) → +%d oro", "Stone [Mountain, Grassland] → Quarry (%d) → +%d gold") % [_B_QUARRY.construction_cost, _B_QUARRY.gold_produced],
		_L("Sal [Océano, Desierto] → Mina de Sal (%d) → +%d oro", "Salt [Ocean, Desert] → Salt Mine (%d) → +%d gold") % [_B_SALT_MINE.construction_cost, _B_SALT_MINE.gold_produced],
		_L("Arena [Desierto, Montaña] → Foso de Arena (%d) → +%d oro", "Sand [Desert, Mountain] → Sand Pit (%d) → +%d gold") % [_B_SAND_PIT.construction_cost, _B_SAND_PIT.gold_produced],
		_L("\nLa Mina de Oro (%d oro/turno, coste %d) es la inversión con mejor retorno. El Oro puede aparecer en todos los biomas aunque es poco frecuente.",
			"\nThe Gold Mine (%d gold/turn, cost %d) is the best-return investment. Gold can appear in all biomes, though it is rare.") % [_B_GOLD_MINE.gold_produced, _B_GOLD_MINE.construction_cost],
	]
	return TutorialEntry.new(_L("Edificios", "Buildings"), _L("Edificios básicos", "Basic buildings"), "\n".join(lines))


func _entry_upgrade_buildings() -> TutorialEntry:
	var body := _L("Mejoras construidas con la carta 'Mejorar Edificio'. La mejora requiere el mismo bioma que el edificio base.\n\n",
		"Upgrades built with the 'Upgrade Building' card. The upgrade requires the same biome as the base building.\n\n")
	body += _L("Solo Aldea (misma restricción que la base):\n", "Village only (same restriction as the base):\n")
	body += _L("• Cultivos → Granero (%d): +%d comida/turno\n", "• Crops → Granary (%d): +%d food/turn\n") % [_B_GRANARY.construction_cost, _B_GRANARY.food_produced]
	body += _L("• Mina de Oro → Casa de la Moneda (%d): +%d oro/turno\n", "• Gold Mine → Royal Mint (%d): +%d gold/turn\n") % [_B_ROYAL_MINT.construction_cost, _B_ROYAL_MINT.gold_produced]
	body += _L("• Granja de Ganado → Rancho (%d): +%d comida, +%d oro/turno\n", "• Livestock Farm → Ranch (%d): +%d food, +%d gold/turn\n") % [_B_RANCH.construction_cost, _B_RANCH.food_produced, _B_RANCH.gold_produced]
	body += _L("• Zona de Caza → Tenería (%d): +%d comida, +%d oro/turno\n", "• Hunting Ground → Tannery (%d): +%d food, +%d gold/turn\n") % [_B_TANNERY.construction_cost, _B_TANNERY.food_produced, _B_TANNERY.gold_produced]
	body += _L("• Mina de Sal → Refinería de Sal (%d): +%d oro/turno\n", "• Salt Mine → Salt Refinery (%d): +%d gold/turn\n") % [_B_SALT_REF.construction_cost, _B_SALT_REF.gold_produced]
	body += _L("\nCualquier nivel de tile (sin restricción):\n", "\nAny tile level (no restriction):\n")
	body += _L("• Mina de Hierro → Herrería (%d): +%d oro/turno\n", "• Iron Mine → Forge (%d): +%d gold/turn\n") % [_B_FORGE.construction_cost, _B_FORGE.gold_produced]
	body += _L("• Campamento Forestal → Serrería (%d): +%d oro/turno\n", "• Logging Camp → Sawmill (%d): +%d gold/turn\n") % [_B_SAWMILL.construction_cost, _B_SAWMILL.gold_produced]
	body += _L("• Cantera → Taller de Cantería (%d): +%d oro/turno\n", "• Quarry → Stonecutter Workshop (%d): +%d gold/turn\n") % [_B_STONECUTTER.construction_cost, _B_STONECUTTER.gold_produced]
	body += _L("• Foso de Arena → Vidriera (%d): +%d oro/turno\n", "• Sand Pit → Glassworks (%d): +%d gold/turn\n") % [_B_GLASSWORKS.construction_cost, _B_GLASSWORKS.gold_produced]
	body += _L("• Pesquería → Puerto Pesquero (%d, solo Océano): +%d comida, +%d oro/turno\n", "• Fishery → Fishing Port (%d, Ocean only): +%d food, +%d gold/turn\n") % [_B_FISHING_PORT.construction_cost, _B_FISHING_PORT.food_produced, _B_FISHING_PORT.gold_produced]
	body += _L("• Pesquería → Mercado de Pescado (%d): +%d comida, +%d oro/turno\n", "• Fishery → Fish Market (%d): +%d food, +%d gold/turn\n") % [_B_FISH_MARKET.construction_cost, _B_FISH_MARKET.food_produced, _B_FISH_MARKET.gold_produced]
	body += _L("\nLa Casa de la Moneda (%d oro, inversión total %d) tiene el mejor retorno absoluto a largo plazo.",
		"\nThe Royal Mint (%d gold, total investment %d) has the best absolute long-term return.") % [
		_B_ROYAL_MINT.gold_produced, _B_GOLD_MINE.construction_cost + _B_ROYAL_MINT.construction_cost]
	return TutorialEntry.new(_L("Edificios", "Buildings"), _L("Mejoras de edificios", "Building upgrades"), body)


func _entry_biome_buildings() -> TutorialEntry:
	var body := _L("Edificios que requieren un bioma concreto. El nivel de tile requerido varía:\n\n",
		"Buildings that require a specific biome. The required tile level varies:\n\n")
	body += _L("• Molino (%d, Pradera, cualquier nivel) — +%d comida, +%.0f%% comida del tile, %s.\n\n",
		"• Mill (%d, Grassland, any level) — +%d food, +%.0f%% tile food, %s.\n\n") % [
		_B_MOLINO.construction_cost, _B_MOLINO.food_produced,
		_B_MOLINO.food_percent_bonus, _sgold(_B_MOLINO.gold_produced)]
	body += _L("• Santuario del Bosque (%d, Bosque, solo Aldea) — %s/turno. Desbloquea eventos SPIRIT exclusivos.\n\n",
		"• Forest Sanctuary (%d, Forest, Village only) — %s/turn. Unlocks exclusive SPIRIT events.\n\n") % [
		_B_SANTUARIO.construction_cost, _prod(_B_SANTUARIO.gold_produced, _B_SANTUARIO.food_produced)]
	body += _L("• Caravana Comercial (%d, Desierto, cualquier nivel) — %s/turno.\n\n",
		"• Trade Caravan (%d, Desert, any level) — %s/turn.\n\n") % [
		_B_CARAVANA.construction_cost, _prod(_B_CARAVANA.gold_produced, _B_CARAVANA.food_produced)]
	body += _L("• Granja de Sanguijuelas (%d, Pantano, solo Aldea) — %s/turno. Muy rentable para su coste.\n\n",
		"• Leech Farm (%d, Swamp, Village only) — %s/turn. Very profitable for its cost.\n\n") % [
		_B_GRANJA_SANG.construction_cost, _prod(_B_GRANJA_SANG.gold_produced, _B_GRANJA_SANG.food_produced)]
	body += _L("• Fortaleza (%d, Montaña, cualquier nivel) — +%d defensa plana en el tile, %s.\n\n",
		"• Fortress (%d, Mountain, any level) — +%d flat defense on the tile, %s.\n\n") % [
		_B_FORTALEZA.construction_cost, _B_FORTALEZA.flat_defense_bonus, _sgold(_B_FORTALEZA.gold_produced)]
	body += _L("• Puerto (%d, Océano, solo Town+) — +%d oro/turno. Mejora a Puerto Comercial (%d): +%d oro, +1 carta/turno.\n\n",
		"• Port (%d, Ocean, Town+ only) — +%d gold/turn. Upgrades to Trade Port (%d): +%d gold, +1 card/turn.\n\n") % [
		_B_PORT.construction_cost, _B_PORT.gold_produced,
		_B_PUERTO_COM.construction_cost, _B_PUERTO_COM.gold_produced]
	body += _L("• Observatorio (%d, Tundra, solo Town+) — +%d oro, +1 carta/turno, %s.",
		"• Observatory (%d, Tundra, Town+ only) — +%d gold, +1 card/turn, %s.") % [
		_B_OBSERV.construction_cost, _B_OBSERV.gold_produced, _sfood(_B_OBSERV.food_produced)]
	return TutorialEntry.new(_L("Edificios", "Buildings"), _L("Edificios especiales de bioma", "Biome-specific buildings"), body)


func _entry_town_buildings() -> TutorialEntry:
	var body := _L("La mayoría requieren Town+. Las excepciones se indican:\n\nProducción económica (Town+):\n",
		"Most require Town+. Exceptions are noted:\n\nEconomic production (Town+):\n")
	body += _L("• Plaza del Mercado (%d): +%d oro/turno\n", "• Market Square (%d): +%d gold/turn\n") % [_B_MARKET_SQ.construction_cost, _B_MARKET_SQ.gold_produced]
	body += _L("• Gremio de Mercaderes (%d): +%d oro/turno\n", "• Merchants' Guild (%d): +%d gold/turn\n") % [_B_GREMIO.construction_cost, _B_GREMIO.gold_produced]
	body += _L("• Almacén (%d): %s/turno\n", "• Warehouse (%d): %s/turn\n") % [_B_WAREHOUSE.construction_cost, _prod(_B_WAREHOUSE.gold_produced, _B_WAREHOUSE.food_produced)]
	body += _L("• Huertos Urbanos (%d): +%d comida/turno\n", "• Urban Gardens (%d): +%d food/turn\n") % [_B_HUERTOS.construction_cost, _B_HUERTOS.food_produced]
	body += _L("• Templo (%d): +%d oro, +%d comida, +10%% comida global → mejora a Gran Catedral\n", "• Temple (%d): +%d gold, +%d food, +10%% global food → upgrades to Great Cathedral\n") % [_B_TEMPLE.construction_cost, _B_TEMPLE.gold_produced, _B_TEMPLE.food_produced]
	body += _L("• Biblioteca (%d): +%d oro, +1 carta/turno → mejora a Gran Biblioteca\n", "• Library (%d): +%d gold, +1 card/turn → upgrades to Great Library\n") % [_B_LIBRARY.construction_cost, _B_LIBRARY.gold_produced]
	body += _L("• Anfiteatro (%d): +1 carta/turno, %s/turno\n", "• Amphitheater (%d): +1 card/turn, %s/turn\n") % [_B_ANFITEATRO.construction_cost, _prod(_B_ANFITEATRO.gold_produced, _B_ANFITEATRO.food_produced)]
	body += _L("\nMilitar (cualquier nivel de tile):\n", "\nMilitary (any tile level):\n")
	body += _L("• Cuartel (%d): +1 tropa extra al reclutar, %s → mejora a Academia Militar\n", "• Barracks (%d): +1 extra troop when recruiting, %s → upgrades to Military Academy\n") % [_B_CUARTEL.construction_cost, _sgold(_B_CUARTEL.gold_produced)]
	body += _L("\nMilitar y construcción (Town+):\n", "\nMilitary and construction (Town+):\n")
	body += _L("• Coliseo (%d): +%d oro, +%d comida, −20%% coste de construcción global\n", "• Colosseum (%d): +%d gold, +%d food, −20%% global construction cost\n") % [_B_COLISEO.construction_cost, _B_COLISEO.gold_produced, _B_COLISEO.food_produced]
	body += _L("• Oficina de Construcción (%d): +15 oro cada vez que juegas Construir o Mejorar Edificio\n", "• Construction Office (%d): +15 gold each time you play Build or Upgrade Building\n") % _B_OFICINA.construction_cost
	body += _L("• Escuela de Planificación (%d): +20 oro cada vez que juegas Proyecto Urbano", "• Planning School (%d): +20 gold each time you play Urban Project") % _B_ESCUELA.construction_cost
	return TutorialEntry.new(_L("Edificios", "Buildings"), _L("Edificios para ciudades (Town+)", "City buildings (Town+)"), body)


func _entry_megalopolis_buildings() -> TutorialEntry:
	var body := _L("Los edificios más poderosos del juego requieren Megalópolis:\n\n",
		"The most powerful buildings in the game require a Megalopolis:\n\n")
	body += _L("• Palacio Imperial (%d): +%d oro, +%d comida, +15%% oro global, +15%% comida global, +1 carta/turno. El edificio más completo del juego. Requiere carta de un solo uso.\n\n",
		"• Imperial Palace (%d): +%d gold, +%d food, +15%% global gold, +15%% global food, +1 card/turn. The most complete building in the game. Requires a single-use card.\n\n") % [
		_B_PALACIO.construction_cost, _B_PALACIO.gold_produced, _B_PALACIO.food_produced]
	body += _L("• Gran Biblioteca (%d): +%d oro, +%d comida, +1 carta/turno, +1 carta extra al robar. Requiere Biblioteca previa.\n\n",
		"• Great Library (%d): +%d gold, +%d food, +1 card/turn, +1 extra card when drawing. Requires a previous Library.\n\n") % [
		_B_GRAN_BIBL.construction_cost, _B_GRAN_BIBL.gold_produced, _B_GRAN_BIBL.food_produced]
	body += _L("• Gran Catedral (%d): +%d oro, +%d comida, +25%% comida global. Requiere Templo previo.\n\n",
		"• Great Cathedral (%d): +%d gold, +%d food, +25%% global food. Requires a previous Temple.\n\n") % [
		_B_GRAN_CATED.construction_cost, _B_GRAN_CATED.gold_produced, _B_GRAN_CATED.food_produced]
	body += _L("• Jardines Celestiales (%d): +%d oro, +%d comida, +15%% comida global. Solo accesible vía Zigurat (exclusivo Babilonia).\n\n",
		"• Celestial Gardens (%d): +%d gold, +%d food, +15%% global food. Only accessible via Ziggurat (Babylon exclusive).\n\n") % [
		_B_JARDINES_C.construction_cost, _B_JARDINES_C.gold_produced, _B_JARDINES_C.food_produced]
	body += _L("• Tesoro Imperial (%d): +%d oro, +20%% oro global, %s. Exclusivo Medici (vía Banco).\n\n",
		"• Imperial Treasury (%d): +%d gold, +20%% global gold, %s. Medici exclusive (via Bank).\n\n") % [
		_B_TESORO.construction_cost, _B_TESORO.gold_produced, _sfood(_B_TESORO.food_produced)]
	body += _L("• Academia Militar (%d): +1 tropa extra al reclutar, −20%% mantenimiento de tropas, %s. Requiere Cuartel previo.\n\n",
		"• Military Academy (%d): +1 extra troop when recruiting, −20%% troop upkeep, %s. Requires a previous Barracks.\n\n") % [
		_B_ACADEMIA.construction_cost, _sgold(_B_ACADEMIA.gold_produced)]
	body += _L("• Puerto Comercial (%d, Océano): +%d oro, +1 carta/turno. Requiere Puerto previo.",
		"• Trade Port (%d, Ocean): +%d gold, +1 card/turn. Requires a previous Port.") % [
		_B_PUERTO_COM.construction_cost, _B_PUERTO_COM.gold_produced]
	return TutorialEntry.new(_L("Edificios", "Buildings"), _L("Edificios avanzados (Megalópolis)", "Advanced buildings (Megalopolis)"), body)


func entry_troops() -> TutorialEntry:
	var troops := [_T_MILITIA, _T_RANGED, _T_PIKEMEN, _T_CAVALRY, _T_HEAVY]
	var lines: Array[String] = [_L("Hay 5 tipos de tropa, todas accesibles con la carta Reclutar:\n",
		"There are 5 troop types, all accessible with the Recruit card:\n")]
	for t in troops:
		lines.append(_L("• %s — ATK %d / DEF %d. Recluta: %d oro. Mantenimiento: %d oro + %d comida/turno.",
			"• %s — ATK %d / DEF %d. Recruit: %d gold. Upkeep: %d gold + %d food/turn.") % [
			tr(t.name), t.attack, t.defense, t.recruitment_cost_gold, t.maintenance_gold, t.maintenance_food])
	return TutorialEntry.new(_L("Militar", "Military"), _L("Tipos de tropas", "Troop types"), "\n\n".join(lines))


func entry_tactic_cards() -> TutorialEntry:
	var tactics := [_TC_CAVALRY_CHARGE, _TC_PHALANX, _TC_ARROW_RAIN, _TC_AMBUSH, _TC_FRONTAL_ASSAULT]
	var lines: Array[String] = [_L("Las tácticas se juegan sobre un frente de batalla activo y potencian tropas concretas. Su efectividad varía según el bioma del tile en combate:\n",
		"Tactics are played on an active battle front and boost specific troops. Their effectiveness varies with the biome of the tile in combat:\n")]
	for t in tactics:
		var type_labels: Array[String] = []
		for tt: int in t.affected_troop_types:
			type_labels.append(_troop_type_label(tt))
		var bonus_parts: Array[String] = []
		if t.attack_percent_per_type != 0.0:
			bonus_parts.append("+%.0f%% ATK" % t.attack_percent_per_type)
		if t.defense_percent_per_type != 0.0:
			bonus_parts.append("+%.0f%% DEF" % t.defense_percent_per_type)
		var header := "• %s (%s %s)" % [tr(t.tactic_name), " / ".join(bonus_parts), ", ".join(type_labels)]
		var biome_parts: Array[String] = []
		for biome in range(7):
			if t.biome_modifiers.has(biome):
				var mod: float = float(t.biome_modifiers[biome])
				if absf(mod - 1.0) > 0.01:
					biome_parts.append("%s ×%.1f" % [_biome_label(biome), mod])
		var tactic_text := header
		if not biome_parts.is_empty():
			tactic_text += "\n  " + " | ".join(biome_parts)
		lines.append(tactic_text)
	lines.append(_L("Nota: el bioma Océano (×0.0) anula todas las tácticas. Nunca las uses en frentes de agua.",
		"Note: the Ocean biome (×0.0) nullifies all tactics. Never use them on water fronts."))
	return TutorialEntry.new(_L("Cartas", "Cards"), _L("Cartas tácticas", "Tactic cards"), "\n\n".join(lines))


func _entry_empire(empire: Resource, ability: Resource, advice: String) -> TutorialEntry:
	var title: String = "%s — %s" % [tr(empire.name), tr(ability.ability_name)]
	var body: String = tr(ability.description)
	if advice != "":
		body += "\n\n" + advice
	return TutorialEntry.new(_L("Imperios", "Empires"), title, body)
