extends CanvasLayer
class_name TutorialPanel

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

# ── Exclusive buildings ───────────────────────────────────────────────────────
const _B_BANK     := preload("res://resources/buildings/exclusive/bank.tres")
const _B_ZIGGURAT := preload("res://resources/buildings/exclusive/ziggurat.tres")

var _entries: Array = []
var _index_map: Dictionary = {}
var _entry_list: ItemList
var _content_title: Label
var _content_body: Label


## Helper de localización para el texto largo del tutorial. Devuelve la cadena
## en inglés si el locale activo es "en"; en español en cualquier otro caso.
## Se usa en lugar de claves del CSV porque los bloques de prosa son extensos y
## específicos del tutorial — mantenerlos inline es más legible que en el CSV.
func _L(es: String, en: String) -> String:
	return en if TranslationServer.get_locale().begins_with("en") else es


func _ready() -> void:
	layer = 10
	_entries = _build_entries()
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()


# ─────────────────────────────────────────────────────────────────────────────
# Entry construction
# ─────────────────────────────────────────────────────────────────────────────

func _build_entries() -> Array:
	var e: Array = []

	# --- Primeros Pasos ---
	e.append({
		"category": _L("Primeros Pasos", "Getting Started"),
		"title": _L("Inicio de partida", "Starting a game"),
		"body": _L("Comienzas la partida con:\n• 100 de oro en reserva\n• 10 oro de producción por turno\n• 2 cartas robadas al inicio de cada turno\n• 4 copias de la carta Colonizar en tu mazo\n\nCada turno hay un 90% de probabilidad de que ocurra un evento. Los primeros eventos no están disponibles hasta que hayas colonizado al menos 5 tiles, momento en que se activa el 'Boom de Construcción' que desbloquea el resto de eventos.",
			"You start the game with:\n• 100 gold in reserve\n• 10 gold of production per turn\n• 2 cards drawn at the start of each turn\n• 4 copies of the Colonize card in your deck\n\nEach turn there is a 90% chance an event will occur. The first events are not available until you have colonized at least 5 tiles, at which point the 'Construction Boom' triggers and unlocks the rest of the events."),
	})
	e.append({
		"category": _L("Primeros Pasos", "Getting Started"),
		"title": _L("El flujo de turno", "The turn flow"),
		"body": _L("Cada turno tiene tres fases:\n\n1. Evento de turno — Al inicio puede ocurrir un evento aleatorio (90% de probabilidad). Requiere tu decisión antes de continuar.\n\n2. Fase de acción — Juegas las cartas de tu mano para colonizar, construir, reclutar, abrir frentes de batalla... No hay límite de cartas por turno.\n\n3. Fin de turno — Pulsas el botón para terminar. Se resuelven los frentes de batalla, se cobra el mantenimiento de tropas y se procesa la producción de recursos de todos tus tiles.",
			"Each turn has three phases:\n\n1. Turn event — At the start a random event may occur (90% chance). It requires your decision before continuing.\n\n2. Action phase — You play cards from your hand to colonize, build, recruit, open battle fronts... There is no card limit per turn.\n\n3. End of turn — You press the button to end it. Battle fronts are resolved, troop upkeep is charged, and the resource production of all your tiles is processed."),
	})

	# --- El Mapa ---
	e.append({
		"category": _L("El Mapa", "The Map"),
		"title": _L("Los biomas", "The biomes"),
		"body": _L("El mapa está compuesto por tiles hexagonales de 7 tipos de bioma:\n\n• Pradera (Grassland) — Recursos: Trigo (exclusivo), Ganado (común), Piedra y Arena (raros). Permite el Molino (+20% comida). Ideal para Caballería (×1.5 en Carga).\n• Bosque (Forest) — Recursos: Madera (principal) y Caza Mayor. Permite el Santuario del Bosque (solo Aldea).\n• Desierto (Desert) — Recursos: Arena (principal), Sal, Hierro y Ganado (secundarios). Permite la Caravana Comercial (+15 oro).\n• Pantano (Swamp) — Recursos: Madera y Pesca. Permite la Granja de Sanguijuelas (solo Aldea).\n• Tundra — Recursos: Ganado (principal) y Caza Mayor. Permite el Observatorio (solo Town+).\n• Montaña (Mountain) — Recursos: Piedra (principal), Hierro (común) y Arena. Permite la Fortaleza (+5 defensa plana). El Muro de Lanzas es muy efectivo aquí (×1.5).\n• Océano (Ocean) — Se coloniza como cualquier tile. Recursos: Pesca (principal) y Sal. Solo permite construir Puertos (Town+).\n\nATENCIÓN: todas las cartas tácticas tienen multiplicador ×0.0 en Océano. Las tácticas militares son completamente inefectivas en tiles de agua.",
			"The map is made up of hexagonal tiles of 7 biome types:\n\n• Grassland — Resources: Wheat (exclusive), Livestock (common), Stone and Sand (rare). Allows the Mill (+20% food). Ideal for Cavalry (×1.5 on Charge).\n• Forest — Resources: Wood (main) and Wild Game. Allows the Forest Sanctuary (Village only).\n• Desert — Resources: Sand (main), Salt, Iron and Livestock (secondary). Allows the Trade Caravan (+15 gold).\n• Swamp — Resources: Wood and Fish. Allows the Leech Farm (Village only).\n• Tundra — Resources: Livestock (main) and Wild Game. Allows the Observatory (Town+ only).\n• Mountain — Resources: Stone (main), Iron (common) and Sand. Allows the Fortress (+5 flat defense). The Pike Wall is very effective here (×1.5).\n• Ocean — Colonized like any tile. Resources: Fish (main) and Salt. Only allows building Ports (Town+).\n\nWARNING: all tactic cards have a ×0.0 multiplier on Ocean. Military tactics are completely ineffective on water tiles."),
	})

	# --- Recursos Naturales ---
	e.append(_entry_food_resources())
	e.append(_entry_wealth_resources())

	# --- Territorios ---
	e.append({
		"category": _L("Territorios", "Territories"),
		"title": _L("Village, Town y Megalópolis", "Village, Town and Megalopolis"),
		"body": _L("Los tiles controlados tienen tres niveles de desarrollo:\n\n• Aldea (Village) — 1 slot de construcción. Acepta edificios básicos y algunos especiales (Fortaleza, Santuario del Bosque, Caravana Comercial, Granja de Sanguijuelas, Cuartel, Molino). Consumo: 0 comida/turno.\n\n• Ciudad (Town) — 3 slots de construcción. Da acceso a edificios avanzados, mercados, templos y militares. Consumo: 5 comida/turno.\n\n• Megalópolis — 5 slots de construcción. Permite los edificios más poderosos del juego (Palacio Imperial, Gran Biblioteca, Academia Militar). Consumo: 10 comida/turno.\n\nNo urbanices más rápido de lo que tu producción de comida puede sostener: cada Town añade 5 de consumo y cada Megalópolis 10.",
			"Controlled tiles have three development levels:\n\n• Village — 1 building slot. Accepts basic buildings and a few special ones (Fortress, Forest Sanctuary, Trade Caravan, Leech Farm, Barracks, Mill). Consumption: 0 food/turn.\n\n• Town — 3 building slots. Grants access to advanced, market, temple and military buildings. Consumption: 5 food/turn.\n\n• Megalopolis — 5 building slots. Allows the most powerful buildings in the game (Imperial Palace, Great Library, Military Academy). Consumption: 10 food/turn.\n\nDo not urbanize faster than your food production can sustain: each Town adds 5 consumption and each Megalopolis 10."),
	})
	e.append({
		"category": _L("Territorios", "Territories"),
		"title": _L("Colonizar y Urbanizar", "Colonize and Urbanize"),
		"body": _L("Colonizar — Juega la carta Colonizar sobre un tile vacío adyacente a uno que ya controles. El tile pasa a ser una Aldea (1 slot). Es la única carta en el mazo inicial (4 copias).\n\nUrbanizar a Town — Juega la carta 'Proyecto Urbano' sobre una Aldea para convertirla en Ciudad (3 slots). Desbloquea edificios más poderosos pero añade 5 comida/turno de consumo. La carta Proyecto Urbano se desbloquea mediante un evento de turno.\n\nFundar Megalópolis — Aparece como evento de turno cuando tienes una Town con 3 o más edificios y dispones de 200 de oro. Coste fijo: 200 oro. Convierte esa Town en Megalópolis (5 slots, 10 comida/turno).\n\nEstrategia: coloniza para expandirte, urbaniza donde quieras construir edificios avanzados, y guarda la Megalópolis para las ciudades más productivas.",
			"Colonize — Play the Colonize card on an empty tile adjacent to one you already control. The tile becomes a Village (1 slot). It is the only card in the starting deck (4 copies).\n\nUrbanize to Town — Play the 'Urban Project' card on a Village to turn it into a Town (3 slots). It unlocks more powerful buildings but adds 5 food/turn of consumption. The Urban Project card is unlocked through a turn event.\n\nFound a Megalopolis — Appears as a turn event when you have a Town with 3 or more buildings and you have 200 gold. Fixed cost: 200 gold. It turns that Town into a Megalopolis (5 slots, 10 food/turn).\n\nStrategy: colonize to expand, urbanize where you want to build advanced buildings, and save the Megalopolis for your most productive cities."),
	})

	# --- Economía ---
	e.append({
		"category": _L("Economía", "Economy"),
		"title": _L("El oro", "Gold"),
		"body": _L("El oro es el recurso principal del juego. Se usa para:\n• Jugar cartas (construir, reclutar tropas, abrir frentes)\n• Pagar costes en eventos negativos\n• Fundar una Megalópolis (200 oro fijo)\n• Firmar el Tratado Comercial (60 oro, +10% oro permanente)\n\nProducción inicial: 10 oro/turno. Cada edificio económico suma directamente a este valor.\n\nSi acumulas déficit de oro sostenido, tu multiplicador de combate se degrada progresivamente hasta un mínimo de 10% de tu capacidad total. Un ejército en un Imperio en quiebra es casi inútil en combate.",
			"Gold is the game's main resource. It is used to:\n• Play cards (build, recruit troops, open fronts)\n• Pay costs in negative events\n• Found a Megalopolis (200 gold fixed)\n• Sign the Trade Agreement (60 gold, +10% permanent gold)\n\nStarting production: 10 gold/turn. Each economic building adds directly to this value.\n\nIf you build up a sustained gold deficit, your combat multiplier degrades progressively down to a minimum of 10% of your full capacity. An army in a bankrupt Empire is nearly useless in combat."),
	})
	e.append({
		"category": _L("Economía", "Economy"),
		"title": _L("La comida", "Food"),
		"body": _entry_food_body(),
	})
	e.append({
		"category": _L("Economía", "Economy"),
		"title": _L("El multiplicador de combate", "The combat multiplier"),
		"body": _L("Cada Imperio tiene un multiplicador de combate entre 0.1 y 1.0 que se aplica a todo el ataque y defensa de sus tropas.\n\n• Economía sana → multiplicador 1.0 (100% de efectividad)\n• Déficit creciente → el multiplicador se degrada gradualmente\n• Colapso económico → multiplicador 0.1 (solo 10% de efectividad)\n\nEste valor se recalcula cada turno en función del déficit acumulado de oro y comida.\n\nImpacto estratégico: un Imperio rico puede vencer a uno militarmente superior simplemente agotando su economía. Forzar el colapso económico del rival mediante expansión agresiva que supere su producción de comida puede ser tan efectivo como vencerle en combate directo.",
			"Each Empire has a combat multiplier between 0.1 and 1.0 that applies to all of its troops' attack and defense.\n\n• Healthy economy → multiplier 1.0 (100% effectiveness)\n• Growing deficit → the multiplier degrades gradually\n• Economic collapse → multiplier 0.1 (only 10% effectiveness)\n\nThis value is recalculated each turn based on the accumulated gold and food deficit.\n\nStrategic impact: a wealthy Empire can beat a militarily superior one simply by draining its economy. Forcing the rival's economic collapse through aggressive expansion that exceeds its food production can be as effective as defeating it in direct combat."),
	})

	# --- Cartas ---
	e.append({
		"category": _L("Cartas", "Cards"),
		"title": _L("El mazo y la mano", "The deck and the hand"),
		"body": _L("Tu mazo contiene todas las cartas disponibles para tu Imperio. Comienzas solo con 4 copias de Colonizar y robas 2 cartas por turno.\n\nCuando el mazo se agota, el montón de descarte se baraja automáticamente formando uno nuevo. Haz clic en los iconos de pila en la pantalla para ver el contenido de tu mazo y descarte.\n\nLas cartas de un solo uso (SINGLE_USE) van a una pila separada al jugarse. La carta 'Recuperar' permite devolverle una de ellas a tu mano.\n\nFormas de robar más cartas por turno:\n• Biblioteca, Observatorio, Puerto Comercial, Anfiteatro: +1 carta/turno cada uno\n• Gran Biblioteca: +1 carta/turno adicional al robar\n• Palacio Imperial: +1 carta/turno\n• Evento Sabios Viajeros: +1 carta/turno permanente",
			"Your deck contains all the cards available to your Empire. You start with only 4 copies of Colonize and draw 2 cards per turn.\n\nWhen the deck runs out, the discard pile is automatically shuffled to form a new one. Click the pile icons on screen to see the contents of your deck and discard.\n\nSingle-use cards (SINGLE_USE) go to a separate pile when played. The 'Recover' card lets you return one of them to your hand.\n\nWays to draw more cards per turn:\n• Library, Observatory, Trade Port, Amphitheater: +1 card/turn each\n• Great Library: +1 additional card/turn when drawing\n• Imperial Palace: +1 card/turn\n• Wise Travelers event: +1 card/turn permanently"),
	})
	e.append({
		"category": _L("Cartas", "Cards"),
		"title": _L("Tipos de cartas", "Card types"),
		"body": _L("Cartas BÁSICAS (núcleo del juego, desbloqueadas por eventos):\n• Colonizar — Toma un tile adyacente vacío. En el mazo inicial.\n• Construir — Elige y construye un edificio en un tile controlado.\n• Mejorar Edificio — Mejora un edificio existente a su siguiente nivel.\n• Reclutar — Elige un tipo de tropa y reclútala.\n• Abrir Frente — Inicia un frente de batalla contra un tile enemigo adyacente.\n\nCartas ESPECIALES:\n• Proyecto Urbano — Urbaniza una Aldea a Town.\n• Robar Carta — Roba 1 carta adicional inmediatamente.\n• Recuperar — Devuelve a tu mano una carta de un solo uso ya jugada.\n\nCartas de UN SOLO USO — Construyen directamente edificios especiales (Templo, Biblioteca, Santuario, Coliseo, Escuela, Oficina, Palacio). Se desbloquean por eventos.\n\nCartas TÁCTICAS — Se juegan sobre frentes de batalla activos.",
			"BASIC cards (the game's core, unlocked by events):\n• Colonize — Take an empty adjacent tile. In the starting deck.\n• Build — Choose and build a building on a controlled tile.\n• Upgrade Building — Upgrade an existing building to its next level.\n• Recruit — Choose a troop type and recruit it.\n• Open Front — Start a battle front against an adjacent enemy tile.\n\nSPECIAL cards:\n• Urban Project — Urbanize a Village to a Town.\n• Draw Card — Draw 1 additional card immediately.\n• Recover — Return a played single-use card to your hand.\n\nSINGLE-USE cards — Directly build special buildings (Temple, Library, Sanctuary, Colosseum, School, Office, Palace). Unlocked by events.\n\nTACTIC cards — Played on active battle fronts."),
	})
	e.append(_entry_tactic_cards())

	# --- Edificios ---
	e.append(_entry_basic_buildings())
	e.append(_entry_upgrade_buildings())
	e.append(_entry_biome_buildings())
	e.append(_entry_town_buildings())
	e.append(_entry_megalopolis_buildings())

	# --- Militar ---
	e.append(_entry_troops())
	e.append({
		"category": _L("Militar", "Military"),
		"title": _L("La matriz de efectividad", "The effectiveness matrix"),
		"body": _L("El combate usa una cadena de ventajas tipo piedra-papel-tijera:\n\nCaballería → supera a Tiradores y Milicia (×1.5 ATK)\nTiradores → superan a Milicia e Infantería Pesada (×1.5 ATK)\nMilicia → supera a Piqueros e Infantería Pesada (×1.5 ATK)\nPiqueros → superan a Caballería e Infantería Pesada (×1.5 ATK)\nInfantería Pesada → supera a Caballería y Tiradores (×1.5 ATK)\n\nLos enfrentamientos inversos aplican ×0.7 (débil).\n\nEl cálculo es ponderado: si el rival tiene mezcla de tipos, el ataque de cada tropa tuya usa un promedio basado en la composición enemiga.\n\nContra-composiciones:\n• Mucha Caballería rival → Piqueros + Infantería Pesada\n• Muchos Tiradores rival → Caballería + Infantería Pesada\n• Mucha Infantería Pesada rival → Milicia + Tiradores\n• Mezcla variada → Milicia (neutra pero sin ventajas claras)",
			"Combat uses a rock-paper-scissors chain of advantages:\n\nCavalry → beats Ranged and Militia (×1.5 ATK)\nRanged → beats Militia and Heavy Infantry (×1.5 ATK)\nMilitia → beats Pikemen and Heavy Infantry (×1.5 ATK)\nPikemen → beat Cavalry and Heavy Infantry (×1.5 ATK)\nHeavy Infantry → beats Cavalry and Ranged (×1.5 ATK)\n\nThe reverse matchups apply ×0.7 (weak).\n\nThe calculation is weighted: if the rival has a mix of types, each of your troops' attack uses an average based on the enemy composition.\n\nCounter-compositions:\n• Lots of enemy Cavalry → Pikemen + Heavy Infantry\n• Lots of enemy Ranged → Cavalry + Heavy Infantry\n• Lots of enemy Heavy Infantry → Militia + Ranged\n• Varied mix → Militia (neutral but with no clear advantages)"),
	})
	e.append({
		"category": _L("Militar", "Military"),
		"title": _L("Los frentes de batalla", "Battle fronts"),
		"body": _L("Para abrir un frente necesitas la carta 'Abrir Frente' (desbloqueada por evento). Selecciona el tile enemigo a atacar y luego tu tile desde la que atacas. Ambas deben ser adyacentes.\n\nCada frente tiene un marcador de posición que se desplaza cada turno según la fuerza neta de ambos bandos. Cuando alcanza el umbral, el frente se resuelve: el atacante conquista el tile o el defensor lo rechaza.\n\nEl umbral se reduce con el tiempo (decay), evitando frentes eternos. Un frente no puede resolverse en sus primeros 3 turnos.\n\nFactores que determinan la fuerza:\n• Número y tipos de tropas asignadas\n• Cartas tácticas jugadas (modificadas por bioma)\n• Edificios militares en el tile propio (ej. Fortaleza: +5 defensa plana)\n• Multiplicador económico del Imperio (entre 0.1 y 1.0)\n• Matriz de efectividad tipo vs tipo",
			"To open a front you need the 'Open Front' card (unlocked by event). Select the enemy tile to attack and then your tile to attack from. Both must be adjacent.\n\nEach front has a position marker that shifts each turn according to the net strength of both sides. When it reaches the threshold, the front resolves: the attacker conquers the tile or the defender repels it.\n\nThe threshold decreases over time (decay), preventing endless fronts. A front cannot resolve in its first 3 turns.\n\nFactors that determine strength:\n• Number and types of assigned troops\n• Tactic cards played (modified by biome)\n• Military buildings on your own tile (e.g. Fortress: +5 flat defense)\n• The Empire's economic multiplier (between 0.1 and 1.0)\n• Type-vs-type effectiveness matrix"),
	})

	# --- Eventos ---
	e.append({
		"category": _L("Eventos", "Events"),
		"title": _L("Cómo funcionan los eventos", "How events work"),
		"body": _L("Cada turno hay un 90% de probabilidad de que ocurra un evento. Los eventos no están disponibles hasta controlar 5 o más tiles, momento en que se activa el 'Boom de Construcción' que desbloquea todos los demás.\n\nCada evento tiene condiciones específicas de aparición: número de turno mínimo, recursos necesarios, edificios construidos, tiles controlados, etc.\n\nTipos de evento:\n• Únicos — Ocurren solo una vez por partida. Muy valiosos, no los desperdicies.\n• Repetibles — Pueden ocurrir varias veces a lo largo de la partida.\n• Obligatorios — No se puede evitar su efecto (plagas, sequías).\n• Con elección — Presentan varias opciones con trade-offs distintos.\n\nLos efectos de los eventos escalan con el número de turno: los positivos dan más al avanzar la partida, pero los negativos también golpean más fuerte.",
			"Each turn there is a 90% chance an event will occur. Events are not available until you control 5 or more tiles, at which point the 'Construction Boom' triggers and unlocks all the others.\n\nEach event has specific appearance conditions: minimum turn number, required resources, constructed buildings, controlled tiles, etc.\n\nEvent types:\n• Unique — Occur only once per game. Very valuable, don't waste them.\n• Repeatable — Can occur several times during the game.\n• Mandatory — Their effect cannot be avoided (plagues, droughts).\n• With choices — Present several options with different trade-offs.\n\nEvent effects scale with the turn number: positive ones give more as the game advances, but negative ones also hit harder."),
	})
	e.append({
		"category": _L("Eventos", "Events"),
		"title": _L("Eventos de prosperidad", "Prosperity events"),
		"body": _L("Eventos que benefician a tu Imperio:\n\n• Cosecha Abundante — +15 comida + escala por turno. Disponible desde turno 5.\n• Tiempo de Abundancia — +20% comida durante 3 turnos. Requiere producción ≥ 5 comida.\n• Vientos de Comercio — +15% oro durante 3 turnos. Requiere producción ≥ 10 oro.\n• Caravana Mercante — +20 oro + escala por turno. Desde turno 3, con 3+ tiles.\n• Artesanos Ambulantes — −15% coste de construcción durante 4 turnos. Desde turno 6.\n• Feria de Ganado — Intercambia −8 comida por +15% oro durante 3 turnos. Requiere producción ≥ 10 comida.\n\nEventos únicos (solo una vez por partida):\n• Sabios Viajeros — +1 carta/turno permanente. Turno 15+, 10+ tiles controlados.\n• Tratado Comercial — +10% oro permanente por 60 oro. Turno 10+, producción ≥ 15 oro.",
			"Events that benefit your Empire:\n\n• Abundant Harvest — +15 food + scales per turn. Available from turn 5.\n• Time of Plenty — +20% food for 3 turns. Requires production ≥ 5 food.\n• Trade Winds — +15% gold for 3 turns. Requires production ≥ 10 gold.\n• Merchant Caravan — +20 gold + scales per turn. From turn 3, with 3+ tiles.\n• Traveling Artisans — −15% construction cost for 4 turns. From turn 6.\n• Cattle Fair — Trade −8 food for +15% gold for 3 turns. Requires production ≥ 10 food.\n\nUnique events (only once per game):\n• Wise Travelers — +1 card/turn permanently. Turn 15+, 10+ controlled tiles.\n• Trade Agreement — +10% permanent gold for 60 gold. Turn 10+, production ≥ 15 gold."),
	})
	e.append({
		"category": _L("Eventos", "Events"),
		"title": _L("Eventos negativos", "Negative events"),
		"body": _L("Eventos que causan daño a tu Imperio:\n\nEvitables (puedes pagar oro para cancelar el efecto):\n• Mala Cosecha — −10 comida durante 3 turnos. Pagar: 25 oro + escala. Desde turno 4.\n• Bandidos en los Caminos — −8 oro/turno durante 3 turnos. Pagar: 30 oro + escala. Desde turno 5, 4+ tiles.\n• Crisis de Materiales — +25% coste construcción durante 4 turnos. Pagar: 40 oro + escala. Desde turno 8.\n\nObligatorios (no se pueden evitar):\n• Plaga de Langostas — −20% comida durante 4 turnos. Ocurre entre turno 6 y 30.\n• Sequía — −15% comida durante 5 turnos. Ocurre entre turno 10 y 40.\n\nMantén siempre un margen de producción de comida para absorber las plagas y sequías sin que colapsen tu economía.",
			"Events that harm your Empire:\n\nAvoidable (you can pay gold to cancel the effect):\n• Bad Harvest — −10 food for 3 turns. Pay: 25 gold + scaling. From turn 4.\n• Bandits on the Roads — −8 gold/turn for 3 turns. Pay: 30 gold + scaling. From turn 5, 4+ tiles.\n• Material Crisis — +25% construction cost for 4 turns. Pay: 40 gold + scaling. From turn 8.\n\nMandatory (cannot be avoided):\n• Locust Plague — −20% food for 4 turns. Occurs between turn 6 and 30.\n• Drought — −15% food for 5 turns. Occurs between turn 10 and 40.\n\nAlways keep a margin of food production to absorb plagues and droughts without collapsing your economy."),
	})
	e.append({
		"category": _L("Eventos", "Events"),
		"title": _L("Eventos de decisión", "Decision events"),
		"body": _L("Eventos que requieren una elección estratégica con consecuencias a largo plazo:\n\n• Reforma Agraria (turno 10+, 8+ tiles) — Intercambia −15% oro por +20% comida durante 4 turnos. Ideal si tienes déficit de comida pero superávit de oro.\n\n• Fundación de Megalópolis — Convierte una Town con 3+ edificios en Megalópolis por 200 oro. Muy valioso si tienes una ciudad bien desarrollada.\n\n• Depuración del Mazo — Elimina permanentemente una carta de tu mazo. Usa esta oportunidad para eliminar Colonizares sobrantes o cartas que ya no necesitas. Un mazo pequeño y eficiente es mucho mejor que uno grande y diluido.\n\n• Ofrenda de Cartas — Recibe una carta aleatoria del pool de cartas desbloqueadas.\n\n• Mercenarios (turno 12+) — Recibe una carta Colonizar por 50 oro + escala. Útil para expansión tardía.\n\n• Tratado Comercial (único) — +10% oro permanente por 60 oro. Acepta siempre que puedas pagarlo.",
			"Events that require a strategic choice with long-term consequences:\n\n• Agrarian Reform (turn 10+, 8+ tiles) — Trade −15% gold for +20% food for 4 turns. Ideal if you have a food deficit but a gold surplus.\n\n• Founding a Megalopolis — Turn a Town with 3+ buildings into a Megalopolis for 200 gold. Very valuable if you have a well-developed city.\n\n• Deck Purge — Permanently remove a card from your deck. Use this chance to remove surplus Colonize cards or cards you no longer need. A small, efficient deck is much better than a large, diluted one.\n\n• Card Offering — Receive a random card from the pool of unlocked cards.\n\n• Mercenaries (turn 12+) — Receive a Colonize card for 50 gold + scaling. Useful for late expansion.\n\n• Trade Agreement (unique) — +10% permanent gold for 60 gold. Always accept it if you can afford it."),
	})
	e.append({
		"category": _L("Eventos", "Events"),
		"title": _L("Los espíritus del bosque", "The forest spirits"),
		"body": _L("Construyendo el Santuario del Bosque (en un tile de Bosque, solo Aldea) desbloqueas un conjunto especial de eventos de tipo SPIRIT:\n\n• Bendición de la Naturaleza — +25% comida durante 3 turnos.\n• Ofrenda del Bosque — +20 comida inmediata + (turno × 2) comida adicional.\n• Pacto con el Bosque — Coloniza automáticamente 1 tile adyacente (prioriza Bosque). Ideal para expansión sin gastar cartas.\n• Raíces Protectoras — −15% coste de construcción durante 3 turnos.\n• Susurros Ancestrales — +1 carta/turno durante 3 turnos.\n\nLos eventos SPIRIT tienen baja probabilidad individual pero en conjunto ofrecen bonificaciones muy valiosas a lo largo de toda la partida. El Santuario es especialmente útil en mapas con abundante terreno boscoso.",
			"By building the Forest Sanctuary (on a Forest tile, Village only) you unlock a special set of SPIRIT-type events:\n\n• Blessing of Nature — +25% food for 3 turns.\n• Forest Offering — +20 immediate food + (turn × 2) additional food.\n• Pact with the Forest — Automatically colonizes 1 adjacent tile (prioritizes Forest). Ideal for expansion without spending cards.\n• Protective Roots — −15% construction cost for 3 turns.\n• Ancestral Whispers — +1 card/turn for 3 turns.\n\nSPIRIT events have a low individual probability but together they offer very valuable bonuses throughout the game. The Sanctuary is especially useful on maps with abundant forest terrain."),
	})
	e.append({
		"category": _L("Eventos", "Events"),
		"title": _L("Tiendas", "Shops"),
		"body": _L("Dos eventos especiales permiten comprar cartas y mejoras directamente con oro:\n\n• Mercado Local — Tienda estándar. Ofrece cartas y artículos a precio moderado. Aparece con frecuencia moderada.\n\n• Bazar Exótico — Tienda especial con artículos raros y más poderosos, a un precio más elevado. Aparece menos frecuentemente.\n\nAmbas tiendas son opcionales: puedes cerrarlas sin comprar nada.\n\nLas tiendas son una de las principales formas de ampliar tu mazo con cartas nuevas fuera de los eventos de desbloqueo estándar. Si tienes oro sobrante y la tienda ofrece algo útil, suele merecer la pena.",
			"Two special events let you buy cards and upgrades directly with gold:\n\n• Local Market — Standard shop. Offers cards and items at a moderate price. Appears with moderate frequency.\n\n• Exotic Bazaar — Special shop with rare and more powerful items, at a higher price. Appears less frequently.\n\nBoth shops are optional: you can close them without buying anything.\n\nShops are one of the main ways to expand your deck with new cards outside the standard unlock events. If you have spare gold and the shop offers something useful, it is usually worth it."),
	})

	# --- Imperios ---
	e.append(_entry_empire(
		_EMP_MEDICI, _AB_MEDICI,
		_L("Estilo de juego: expansión económica progresiva. Los Medici construyen más barato y generan más oro desde el inicio. Su ventaja crece exponencialmente con el tiempo según acumulan edificios.\n\nDebilidad: vulnerables a presiones militares tempranas.\n\nConsejo: prioriza Minas de Oro y el Banco en los primeros turnos.",
			"Playstyle: progressive economic expansion. The Medici build cheaper and generate more gold from the start. Their advantage grows exponentially over time as they accumulate buildings.\n\nWeakness: vulnerable to early military pressure.\n\nTip: prioritize Gold Mines and the Bank in the first turns."),
	))
	e.append(_entry_empire(
		_EMP_MONGOL, _AB_MONGOL,
		_L("Estilo de juego: expansión agresiva desde el primer turno. La recuperación de Colonizar permite tomar muchos más territorios que cualquier otro Imperio.\n\nDebilidad: depende de expansión continua. Si la expansión se frena, puede quedarse sin recursos.\n\nConsejo: expande muy agresivamente los primeros turnos. Busca tiles de Pradera para Cargas de Caballería y tiles con Ganadería para la economía.",
			"Playstyle: aggressive expansion from the first turn. Recovering Colonize cards lets you take far more territory than any other Empire.\n\nWeakness: depends on continuous expansion. If expansion stalls, it can run out of resources.\n\nTip: expand very aggressively in the first turns. Look for Grassland tiles for Cavalry Charges and Livestock tiles for the economy."),
	))
	e.append(_entry_empire(
		_EMP_BABYLON, _AB_BABYLON,
		_L("Estilo de juego: equilibrio entre economía y producción de alimentos. Babilonia puede sostener más ciudades y Megalópolis gracias al bonus en Trigo.\n\nDebilidad: crece más despacio que Medici en oro puro y más despacio que Mongol en territorio.\n\nConsejo: busca tiles con Trigo activamente. Construye el Zigurat cuanto antes para iniciar la cadena hacia los Jardines Celestiales.",
			"Playstyle: a balance between economy and food production. Babylon can sustain more cities and Megalopolises thanks to its Wheat bonus.\n\nWeakness: grows slower than the Medici in pure gold and slower than the Mongols in territory.\n\nTip: actively look for Wheat tiles. Build the Ziggurat as soon as possible to start the chain toward the Celestial Gardens."),
	))

	# --- Victoria ---
	e.append({
		"category": _L("Victoria", "Victory"),
		"title": _L("Condiciones de victoria", "Victory conditions"),
		"body": _L("Hay dos formas de ganar la partida:\n\n• Dominación Territorial — Controla el 70% o más de todos los tiles del mapa al final de un turno. Los tiles de Océano se pueden colonizar y cuentan para el porcentaje igual que el resto.\n\n• Eliminación — Conquista todos los tiles del Imperio rival. Cuando un Imperio pierde su último tile controlado, queda eliminado automáticamente y el otro Imperio gana.\n\nAmbas condiciones se comprueban al final de cada turno, después de resolver todos los frentes de batalla activos.",
			"There are two ways to win the game:\n\n• Territorial Domination — Control 70% or more of all tiles on the map at the end of a turn. Ocean tiles can be colonized and count toward the percentage like any other.\n\n• Elimination — Conquer all tiles of the rival Empire. When an Empire loses its last controlled tile, it is automatically eliminated and the other Empire wins.\n\nBoth conditions are checked at the end of each turn, after resolving all active battle fronts."),
	})
	e.append({
		"category": _L("Victoria", "Victory"),
		"title": _L("Estrategia de victoria", "Victory strategy"),
		"body": _L("Para la Dominación (70%):\nRequiere expansión eficiente y sostenida. La Horda Mongola es la más adecuada gracias a la recuperación de Colonizar. Vigila el porcentaje de territorios en el panel de estadísticas. Si el rival se aproxima al 70% antes que tú, detenerle debe ser la prioridad absoluta.\n\nPara la Eliminación:\nRequiere romper la línea defensiva del rival abriendo múltiples frentes simultáneamente. Los Medici, con economía superior a largo plazo, pueden sostener ejércitos costosos en varios frentes a la vez.\n\nEl multiplicador económico es clave en ambas victorias: un Imperio con economía colapsada opera con tropas al 10% de efectividad. Forzar el colapso económico del rival, ya sea expandiendo hasta superar su producción de comida o con eventos negativos acumulados, puede ser tan decisivo como vencerle en combate directo.",
			"For Domination (70%):\nRequires efficient, sustained expansion. The Mongol Horde is best suited thanks to recovering Colonize cards. Watch the territory percentage in the stats panel. If the rival approaches 70% before you, stopping them must be the absolute priority.\n\nFor Elimination:\nRequires breaking the rival's defensive line by opening multiple fronts simultaneously. The Medici, with superior long-term economy, can sustain costly armies on several fronts at once.\n\nThe economic multiplier is key to both victories: an Empire with a collapsed economy operates with troops at 10% effectiveness. Forcing the rival's economic collapse, whether by expanding past its food production or with accumulated negative events, can be as decisive as defeating it in direct combat."),
	})

	return e


# ─────────────────────────────────────────────────────────────────────────────
# Dynamic entry builders
# ─────────────────────────────────────────────────────────────────────────────

func _entry_food_resources() -> Dictionary:
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
	return {"category": _L("Recursos Naturales", "Natural Resources"), "title": _L("Recursos alimentarios", "Food resources"), "body": body}


func _entry_wealth_resources() -> Dictionary:
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
	return {"category": _L("Recursos Naturales", "Natural Resources"), "title": _L("Recursos de riqueza", "Wealth resources"), "body": body}


func _entry_food_body() -> String:
	var troops := [_T_MILITIA, _T_RANGED, _T_PIKEMEN, _T_CAVALRY, _T_HEAVY]
	var body := _L("La comida mantiene activas tus ciudades y tropas. Cada turno se descuenta:\n• Town: −5 comida/turno\n• Megalópolis: −10 comida/turno",
		"Food keeps your cities and troops active. Each turn the following is deducted:\n• Town: −5 food/turn\n• Megalopolis: −10 food/turn")
	for t in troops:
		if t.maintenance_food > 0:
			body += _L("\n• %s: −%d comida/turno por tropa", "\n• %s: −%d food/turn per troop") % [tr(t.name), t.maintenance_food]
	body += _L("\n\nSi tu producción no cubre el consumo, el déficit degrada el multiplicador de combate igual que el déficit de oro.\n\nCuidado con la expansión rápida: colonizar muchas ciudades sin suficiente producción de comida puede colapsar tu economía de golpe.",
		"\n\nIf your production does not cover consumption, the deficit degrades the combat multiplier just like a gold deficit.\n\nBe careful with rapid expansion: colonizing many cities without enough food production can collapse your economy all at once.")
	return body


func _entry_basic_buildings() -> Dictionary:
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
	return {"category": _L("Edificios", "Buildings"), "title": _L("Edificios básicos", "Basic buildings"), "body": "\n".join(lines)}


func _entry_upgrade_buildings() -> Dictionary:
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
	return {"category": _L("Edificios", "Buildings"), "title": _L("Mejoras de edificios", "Building upgrades"), "body": body}


func _entry_biome_buildings() -> Dictionary:
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
	return {"category": _L("Edificios", "Buildings"), "title": _L("Edificios especiales de bioma", "Biome-specific buildings"), "body": body}


func _entry_town_buildings() -> Dictionary:
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
	return {"category": _L("Edificios", "Buildings"), "title": _L("Edificios para ciudades (Town+)", "City buildings (Town+)"), "body": body}


func _entry_megalopolis_buildings() -> Dictionary:
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
	return {"category": _L("Edificios", "Buildings"), "title": _L("Edificios avanzados (Megalópolis)", "Advanced buildings (Megalopolis)"), "body": body}


func _entry_troops() -> Dictionary:
	var troops := [_T_MILITIA, _T_RANGED, _T_PIKEMEN, _T_CAVALRY, _T_HEAVY]
	var lines: Array[String] = [_L("Hay 5 tipos de tropa, todas accesibles con la carta Reclutar:\n",
		"There are 5 troop types, all accessible with the Recruit card:\n")]
	for t in troops:
		lines.append(_L("• %s — ATK %d / DEF %d. Recluta: %d oro. Mantenimiento: %d oro + %d comida/turno.",
			"• %s — ATK %d / DEF %d. Recruit: %d gold. Upkeep: %d gold + %d food/turn.") % [
			tr(t.name), t.attack, t.defense, t.recruitment_cost_gold, t.maintenance_gold, t.maintenance_food])
	return {"category": _L("Militar", "Military"), "title": _L("Tipos de tropas", "Troop types"), "body": "\n\n".join(lines)}


func _entry_tactic_cards() -> Dictionary:
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
	return {"category": _L("Cartas", "Cards"), "title": _L("Cartas tácticas", "Tactic cards"), "body": "\n\n".join(lines)}


func _entry_empire(empire: Resource, ability: Resource, advice: String) -> Dictionary:
	var title: String = "%s — %s" % [tr(empire.name), tr(ability.ability_name)]
	var body: String = tr(ability.description)
	if advice != "":
		body += "\n\n" + advice
	return {"category": _L("Imperios", "Empires"), "title": title, "body": body}


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
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
	# Orden del enum Tile.biome_type: 0=Grassland,1=Forest,2=Desert,3=Swamp,
	# 4=Tundra,5=Ocean,6=Mountain. Se traduce por clave TILE_* centralizada.
	match biome:
		0: return tr("TILE_GRASSLAND")
		1: return tr("TILE_FOREST")
		2: return tr("TILE_DESERT")
		3: return tr("TILE_SWAMP")
		4: return tr("TILE_TUNDRA")
		5: return tr("TILE_OCEAN")
		6: return tr("TILE_MOUNTAIN")
		_: return "?"


func _troop_type_label(t: int) -> String:
	match t:
		0: return tr("TROOP_TYPE_CABALLERIA")
		1: return _L("Tiradores", "Ranged")
		2: return _L("Milicia", "Militia")
		3: return tr("TROOP_TYPE_INFANTERIA_PESADA")
		4: return tr("TROOP_TYPE_PIQUEROS")
		_: return "?"


# ─────────────────────────────────────────────────────────────────────────────
# UI construction
# ─────────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = UITheme.OVERLAY_DARK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 540)
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_style())
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var header := Label.new()
	header.text = tr("MENU_TUTORIAL")
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 28)
	header.add_theme_color_override("font_color", UITheme.BORDER_BROWN)
	vbox.add_child(header)

	vbox.add_child(HSeparator.new())

	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(hbox)

	_entry_list = ItemList.new()
	_entry_list.custom_minimum_size = Vector2(230, 0)
	_entry_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_list_theme(_entry_list)
	_entry_list.item_selected.connect(_on_entry_selected)
	hbox.add_child(_entry_list)

	hbox.add_child(VSeparator.new())

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(450, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	hbox.add_child(right)

	_content_title = Label.new()
	_content_title.add_theme_font_size_override("font_size", 20)
	_content_title.add_theme_color_override("font_color", UITheme.BORDER_BROWN)
	right.add_child(_content_title)

	right.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)

	_content_body = Label.new()
	_content_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_body.add_theme_font_size_override("font_size", 16)
	_content_body.add_theme_color_override("font_color", UITheme.TEXT_DARK)
	scroll.add_child(_content_body)

	vbox.add_child(HSeparator.new())

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(footer)

	footer.add_child(_make_button(tr("UI_CLOSE"), _on_close_pressed))

	_populate_list()
	_select_first_entry()


func _populate_list() -> void:
	var current_category := ""
	var entry_idx := 0
	for entry: Dictionary in _entries:
		if entry["category"] != current_category:
			current_category = entry["category"]
			_entry_list.add_item("— " + current_category + " —")
			var header_idx := _entry_list.get_item_count() - 1
			_entry_list.set_item_selectable(header_idx, false)
			_entry_list.set_item_custom_fg_color(header_idx, UITheme.BORDER_BROWN)
		_entry_list.add_item("  " + entry["title"])
		_index_map[_entry_list.get_item_count() - 1] = entry_idx
		entry_idx += 1


func _select_first_entry() -> void:
	for i: int in range(_entry_list.get_item_count()):
		if _index_map.has(i):
			_entry_list.select(i)
			_on_entry_selected(i)
			return


func _on_entry_selected(list_idx: int) -> void:
	if not _index_map.has(list_idx):
		return
	var entry: Dictionary = _entries[_index_map[list_idx]]
	_content_title.text = entry["title"]
	_content_body.text = entry["body"]


func _apply_list_theme(list: ItemList) -> void:
	list.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.BORDER_BROWN, 2, 6))
	var sel := StyleBoxFlat.new()
	sel.bg_color = Color(UITheme.BORDER_BROWN.r, UITheme.BORDER_BROWN.g, UITheme.BORDER_BROWN.b, 0.22)
	sel.corner_radius_top_left     = 4
	sel.corner_radius_top_right    = 4
	sel.corner_radius_bottom_right = 4
	sel.corner_radius_bottom_left  = 4
	sel.content_margin_left        = 6
	sel.content_margin_top         = 3
	sel.content_margin_right       = 6
	sel.content_margin_bottom      = 3
	list.add_theme_stylebox_override("selected", sel)
	list.add_theme_stylebox_override("selected_focus", sel)
	list.add_theme_stylebox_override("cursor", StyleBoxEmpty.new())
	list.add_theme_stylebox_override("cursor_unfocused", StyleBoxEmpty.new())
	list.add_theme_color_override("font_color", UITheme.TEXT_DARK)
	list.add_theme_color_override("font_selected_color", UITheme.BORDER_BROWN)
	list.add_theme_color_override("font_hovered_color", UITheme.BORDER_BROWN)
	list.add_theme_font_size_override("font_size", 15)


func _make_button(label_text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(120, 38)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", UITheme.TEXT_DARK)
	btn.add_theme_color_override("font_hover_color", UITheme.BORDER_BROWN)
	btn.add_theme_color_override("font_pressed_color", UITheme.BORDER_BROWN)
	btn.add_theme_stylebox_override("normal", UITheme.make_panel_style(UITheme.BORDER_BROWN, 2, 8))
	btn.add_theme_stylebox_override("hover", UITheme.make_panel_hover_style(UITheme.BORDER_BROWN, 2, 8))
	btn.add_theme_stylebox_override("pressed", UITheme.make_panel_style(UITheme.BORDER_BROWN, 3, 8))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pressed.connect(callback)
	return btn


func _on_close_pressed() -> void:
	queue_free()
