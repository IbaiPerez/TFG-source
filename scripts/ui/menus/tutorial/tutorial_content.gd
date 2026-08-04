extends TutorialText
class_name TutorialContent

## Contenido del manual del tutorial, separado del panel que lo muestra.
##
## Aquí vive la prosa fija y el ORDEN del manual. Las entradas que se componen
## leyendo los .tres de balance viven en [TutorialBalanceEntries]: se separaron
## porque son las que arrastran los ~50 preload y las que no pueden
## desincronizarse del juego — si se toca un coste en su .tres, el manual lo
## refleja solo.
##
## El texto NO puede convertirse en un recurso estático: congelaría esas cifras.

var _balance := TutorialBalanceEntries.new()


## Construye el manual completo, en el orden en que se muestra. Cada sección
## agrupa las entradas de una categoría (el panel usa el cambio de categoría
## para insertar las cabeceras de la lista, así que el orden importa).
func build() -> Array[TutorialEntry]:
	var e: Array[TutorialEntry] = []
	e.append_array(_first_steps())
	e.append_array(_map())
	e.append_array(_natural_resources())
	e.append_array(_territories())
	e.append_array(_economy())
	e.append_array(_cards())
	e.append_array(_buildings())
	e.append_array(_military())
	e.append_array(_events())
	e.append_array(_empires())
	e.append_array(_victory())
	return e


# ─────────────────────────────────────────────────────────────────────────────
# Secciones
# ─────────────────────────────────────────────────────────────────────────────


func _first_steps() -> Array[TutorialEntry]:
	var cat := _L("Primeros Pasos", "Getting Started")
	return [
		TutorialEntry.new(cat,
			_L("Inicio de partida", "Starting a game"),
			_L("Comienzas la partida con:\n• 100 de oro en reserva\n• 10 oro de producción por turno\n• 2 cartas robadas al inicio de cada turno\n• 4 copias de la carta Colonizar en tu mazo\n\nCada turno hay un 90% de probabilidad de que ocurra un evento. Los primeros eventos no están disponibles hasta que hayas colonizado al menos 5 tiles, momento en que se activa el 'Boom de Construcción' que desbloquea el resto de eventos.",
				"You start the game with:\n• 100 gold in reserve\n• 10 gold of production per turn\n• 2 cards drawn at the start of each turn\n• 4 copies of the Colonize card in your deck\n\nEach turn there is a 90% chance an event will occur. The first events are not available until you have colonized at least 5 tiles, at which point the 'Construction Boom' triggers and unlocks the rest of the events.")),
		TutorialEntry.new(cat,
			_L("El flujo de turno", "The turn flow"),
			_L("Cada turno tiene tres fases:\n\n1. Evento de turno — Al inicio puede ocurrir un evento aleatorio (90% de probabilidad). Requiere tu decisión antes de continuar.\n\n2. Fase de acción — Juegas las cartas de tu mano para colonizar, construir, reclutar, abrir frentes de batalla... No hay límite de cartas por turno.\n\n3. Fin de turno — Pulsas el botón para terminar. Se resuelven los frentes de batalla, se cobra el mantenimiento de tropas y se procesa la producción de recursos de todos tus tiles.",
				"Each turn has three phases:\n\n1. Turn event — At the start a random event may occur (90% chance). It requires your decision before continuing.\n\n2. Action phase — You play cards from your hand to colonize, build, recruit, open battle fronts... There is no card limit per turn.\n\n3. End of turn — You press the button to end it. Battle fronts are resolved, troop upkeep is charged, and the resource production of all your tiles is processed.")),
	]


func _map() -> Array[TutorialEntry]:
	return [
		TutorialEntry.new(_L("El Mapa", "The Map"),
			_L("Los biomas", "The biomes"),
			_L("El mapa está compuesto por tiles hexagonales de 7 tipos de bioma:\n\n• Pradera (Grassland) — Recursos: Trigo (exclusivo), Ganado (común), Piedra y Arena (raros). Permite el Molino (+20% comida). Ideal para Caballería (×1.5 en Carga).\n• Bosque (Forest) — Recursos: Madera (principal) y Caza Mayor. Permite el Santuario del Bosque (solo Aldea).\n• Desierto (Desert) — Recursos: Arena (principal), Sal, Hierro y Ganado (secundarios). Permite la Caravana Comercial (+15 oro).\n• Pantano (Swamp) — Recursos: Madera y Pesca. Permite la Granja de Sanguijuelas (solo Aldea).\n• Tundra — Recursos: Ganado (principal) y Caza Mayor. Permite el Observatorio (solo Town+).\n• Montaña (Mountain) — Recursos: Piedra (principal), Hierro (común) y Arena. Permite la Fortaleza (+5 defensa plana). El Muro de Lanzas es muy efectivo aquí (×1.5).\n• Océano (Ocean) — Se coloniza como cualquier tile. Recursos: Pesca (principal) y Sal. Solo permite construir Puertos (Town+).\n\nATENCIÓN: todas las cartas tácticas tienen multiplicador ×0.0 en Océano. Las tácticas militares son completamente inefectivas en tiles de agua.",
				"The map is made up of hexagonal tiles of 7 biome types:\n\n• Grassland — Resources: Wheat (exclusive), Livestock (common), Stone and Sand (rare). Allows the Mill (+20% food). Ideal for Cavalry (×1.5 on Charge).\n• Forest — Resources: Wood (main) and Wild Game. Allows the Forest Sanctuary (Village only).\n• Desert — Resources: Sand (main), Salt, Iron and Livestock (secondary). Allows the Trade Caravan (+15 gold).\n• Swamp — Resources: Wood and Fish. Allows the Leech Farm (Village only).\n• Tundra — Resources: Livestock (main) and Wild Game. Allows the Observatory (Town+ only).\n• Mountain — Resources: Stone (main), Iron (common) and Sand. Allows the Fortress (+5 flat defense). The Pike Wall is very effective here (×1.5).\n• Ocean — Colonized like any tile. Resources: Fish (main) and Salt. Only allows building Ports (Town+).\n\nWARNING: all tactic cards have a ×0.0 multiplier on Ocean. Military tactics are completely ineffective on water tiles.")),
	]


func _natural_resources() -> Array[TutorialEntry]:
	return _balance.entries_natural_resources()


func _territories() -> Array[TutorialEntry]:
	var cat := _L("Territorios", "Territories")
	return [
		TutorialEntry.new(cat,
			_L("Village, Town y Megalópolis", "Village, Town and Megalopolis"),
			_L("Los tiles controlados tienen tres niveles de desarrollo:\n\n• Aldea (Village) — 1 slot de construcción. Acepta edificios básicos y algunos especiales (Fortaleza, Santuario del Bosque, Caravana Comercial, Granja de Sanguijuelas, Cuartel, Molino). Consumo: 0 comida/turno.\n\n• Ciudad (Town) — 3 slots de construcción. Da acceso a edificios avanzados, mercados, templos y militares. Consumo: 5 comida/turno.\n\n• Megalópolis — 5 slots de construcción. Permite los edificios más poderosos del juego (Palacio Imperial, Gran Biblioteca, Academia Militar). Consumo: 10 comida/turno.\n\nNo urbanices más rápido de lo que tu producción de comida puede sostener: cada Town añade 5 de consumo y cada Megalópolis 10.",
				"Controlled tiles have three development levels:\n\n• Village — 1 building slot. Accepts basic buildings and a few special ones (Fortress, Forest Sanctuary, Trade Caravan, Leech Farm, Barracks, Mill). Consumption: 0 food/turn.\n\n• Town — 3 building slots. Grants access to advanced, market, temple and military buildings. Consumption: 5 food/turn.\n\n• Megalopolis — 5 building slots. Allows the most powerful buildings in the game (Imperial Palace, Great Library, Military Academy). Consumption: 10 food/turn.\n\nDo not urbanize faster than your food production can sustain: each Town adds 5 consumption and each Megalopolis 10.")),
		TutorialEntry.new(cat,
			_L("Colonizar y Urbanizar", "Colonize and Urbanize"),
			_L("Colonizar — Juega la carta Colonizar sobre un tile vacío adyacente a uno que ya controles. El tile pasa a ser una Aldea (1 slot). Es la única carta en el mazo inicial (4 copias).\n\nUrbanizar a Town — Juega la carta 'Proyecto Urbano' sobre una Aldea para convertirla en Ciudad (3 slots). Desbloquea edificios más poderosos pero añade 5 comida/turno de consumo. La carta Proyecto Urbano se desbloquea mediante un evento de turno.\n\nFundar Megalópolis — Aparece como evento de turno cuando tienes una Town con 3 o más edificios y dispones de 200 de oro. Coste fijo: 200 oro. Convierte esa Town en Megalópolis (5 slots, 10 comida/turno).\n\nEstrategia: coloniza para expandirte, urbaniza donde quieras construir edificios avanzados, y guarda la Megalópolis para las ciudades más productivas.",
				"Colonize — Play the Colonize card on an empty tile adjacent to one you already control. The tile becomes a Village (1 slot). It is the only card in the starting deck (4 copies).\n\nUrbanize to Town — Play the 'Urban Project' card on a Village to turn it into a Town (3 slots). It unlocks more powerful buildings but adds 5 food/turn of consumption. The Urban Project card is unlocked through a turn event.\n\nFound a Megalopolis — Appears as a turn event when you have a Town with 3 or more buildings and you have 200 gold. Fixed cost: 200 gold. It turns that Town into a Megalopolis (5 slots, 10 food/turn).\n\nStrategy: colonize to expand, urbanize where you want to build advanced buildings, and save the Megalopolis for your most productive cities.")),
	]


func _economy() -> Array[TutorialEntry]:
	var cat := _L("Economía", "Economy")
	return [
		TutorialEntry.new(cat,
			_L("El oro", "Gold"),
			_L("El oro es el recurso principal del juego. Se usa para:\n• Jugar cartas (construir, reclutar tropas, abrir frentes)\n• Pagar costes en eventos negativos\n• Fundar una Megalópolis (200 oro fijo)\n• Firmar el Tratado Comercial (60 oro, +10% oro permanente)\n\nProducción inicial: 10 oro/turno. Cada edificio económico suma directamente a este valor.\n\nSi acumulas déficit de oro sostenido, tu multiplicador de combate se degrada progresivamente hasta un mínimo de 10% de tu capacidad total. Un ejército en un Imperio en quiebra es casi inútil en combate.",
				"Gold is the game's main resource. It is used to:\n• Play cards (build, recruit troops, open fronts)\n• Pay costs in negative events\n• Found a Megalopolis (200 gold fixed)\n• Sign the Trade Agreement (60 gold, +10% permanent gold)\n\nStarting production: 10 gold/turn. Each economic building adds directly to this value.\n\nIf you build up a sustained gold deficit, your combat multiplier degrades progressively down to a minimum of 10% of your full capacity. An army in a bankrupt Empire is nearly useless in combat.")),
		TutorialEntry.new(cat,
			_L("La comida", "Food"),
			_balance.food_body()),
		TutorialEntry.new(cat,
			_L("El multiplicador de combate", "The combat multiplier"),
			_L("Cada Imperio tiene un multiplicador de combate entre 0.1 y 1.0 que se aplica a todo el ataque y defensa de sus tropas.\n\n• Economía sana → multiplicador 1.0 (100% de efectividad)\n• Déficit creciente → el multiplicador se degrada gradualmente\n• Colapso económico → multiplicador 0.1 (solo 10% de efectividad)\n\nEste valor se recalcula cada turno en función del déficit acumulado de oro y comida.\n\nImpacto estratégico: un Imperio rico puede vencer a uno militarmente superior simplemente agotando su economía. Forzar el colapso económico del rival mediante expansión agresiva que supere su producción de comida puede ser tan efectivo como vencerle en combate directo.",
				"Each Empire has a combat multiplier between 0.1 and 1.0 that applies to all of its troops' attack and defense.\n\n• Healthy economy → multiplier 1.0 (100% effectiveness)\n• Growing deficit → the multiplier degrades gradually\n• Economic collapse → multiplier 0.1 (only 10% effectiveness)\n\nThis value is recalculated each turn based on the accumulated gold and food deficit.\n\nStrategic impact: a wealthy Empire can beat a militarily superior one simply by draining its economy. Forcing the rival's economic collapse through aggressive expansion that exceeds its food production can be as effective as defeating it in direct combat.")),
	]


func _cards() -> Array[TutorialEntry]:
	var cat := _L("Cartas", "Cards")
	return [
		TutorialEntry.new(cat,
			_L("El mazo y la mano", "The deck and the hand"),
			_L("Tu mazo contiene todas las cartas disponibles para tu Imperio. Comienzas solo con 4 copias de Colonizar y robas 2 cartas por turno.\n\nCuando el mazo se agota, el montón de descarte se baraja automáticamente formando uno nuevo. Haz clic en los iconos de pila en la pantalla para ver el contenido de tu mazo y descarte.\n\nLas cartas de un solo uso (SINGLE_USE) van a una pila separada al jugarse. La carta 'Recuperar' permite devolverle una de ellas a tu mano.\n\nFormas de robar más cartas por turno:\n• Biblioteca, Observatorio, Puerto Comercial, Anfiteatro: +1 carta/turno cada uno\n• Gran Biblioteca: +1 carta/turno adicional al robar\n• Palacio Imperial: +1 carta/turno\n• Evento Sabios Viajeros: +1 carta/turno permanente",
				"Your deck contains all the cards available to your Empire. You start with only 4 copies of Colonize and draw 2 cards per turn.\n\nWhen the deck runs out, the discard pile is automatically shuffled to form a new one. Click the pile icons on screen to see the contents of your deck and discard.\n\nSingle-use cards (SINGLE_USE) go to a separate pile when played. The 'Recover' card lets you return one of them to your hand.\n\nWays to draw more cards per turn:\n• Library, Observatory, Trade Port, Amphitheater: +1 card/turn each\n• Great Library: +1 additional card/turn when drawing\n• Imperial Palace: +1 card/turn\n• Wise Travelers event: +1 card/turn permanently")),
		TutorialEntry.new(cat,
			_L("Tipos de cartas", "Card types"),
			_L("Cartas BÁSICAS (núcleo del juego, desbloqueadas por eventos):\n• Colonizar — Toma un tile adyacente vacío. En el mazo inicial.\n• Construir — Elige y construye un edificio en un tile controlado.\n• Mejorar Edificio — Mejora un edificio existente a su siguiente nivel.\n• Reclutar — Elige un tipo de tropa y reclútala.\n• Abrir Frente — Inicia un frente de batalla contra un tile enemigo adyacente.\n\nCartas ESPECIALES:\n• Proyecto Urbano — Urbaniza una Aldea a Town.\n• Robar Carta — Roba 1 carta adicional inmediatamente.\n• Recuperar — Devuelve a tu mano una carta de un solo uso ya jugada.\n\nCartas de UN SOLO USO — Construyen directamente edificios especiales (Templo, Biblioteca, Santuario, Coliseo, Escuela, Oficina, Palacio). Se desbloquean por eventos.\n\nCartas TÁCTICAS — Se juegan sobre frentes de batalla activos.",
				"BASIC cards (the game's core, unlocked by events):\n• Colonize — Take an empty adjacent tile. In the starting deck.\n• Build — Choose and build a building on a controlled tile.\n• Upgrade Building — Upgrade an existing building to its next level.\n• Recruit — Choose a troop type and recruit it.\n• Open Front — Start a battle front against an adjacent enemy tile.\n\nSPECIAL cards:\n• Urban Project — Urbanize a Village to a Town.\n• Draw Card — Draw 1 additional card immediately.\n• Recover — Return a played single-use card to your hand.\n\nSINGLE-USE cards — Directly build special buildings (Temple, Library, Sanctuary, Colosseum, School, Office, Palace). Unlocked by events.\n\nTACTIC cards — Played on active battle fronts.")),
		_balance.entry_tactic_cards(),
	]


func _buildings() -> Array[TutorialEntry]:
	return _balance.entries_buildings()


func _military() -> Array[TutorialEntry]:
	var cat := _L("Militar", "Military")
	return [
		_balance.entry_troops(),
		TutorialEntry.new(cat,
			_L("La matriz de efectividad", "The effectiveness matrix"),
			_L("El combate usa una cadena de ventajas tipo piedra-papel-tijera:\n\nCaballería → supera a Tiradores y Milicia (×1.5 ATK)\nTiradores → superan a Milicia e Infantería Pesada (×1.5 ATK)\nMilicia → supera a Piqueros e Infantería Pesada (×1.5 ATK)\nPiqueros → superan a Caballería e Infantería Pesada (×1.5 ATK)\nInfantería Pesada → supera a Caballería y Tiradores (×1.5 ATK)\n\nLos enfrentamientos inversos aplican ×0.7 (débil).\n\nEl cálculo es ponderado: si el rival tiene mezcla de tipos, el ataque de cada tropa tuya usa un promedio basado en la composición enemiga.\n\nContra-composiciones:\n• Mucha Caballería rival → Piqueros + Infantería Pesada\n• Muchos Tiradores rival → Caballería + Infantería Pesada\n• Mucha Infantería Pesada rival → Milicia + Tiradores\n• Mezcla variada → Milicia (neutra pero sin ventajas claras)",
				"Combat uses a rock-paper-scissors chain of advantages:\n\nCavalry → beats Ranged and Militia (×1.5 ATK)\nRanged → beats Militia and Heavy Infantry (×1.5 ATK)\nMilitia → beats Pikemen and Heavy Infantry (×1.5 ATK)\nPikemen → beat Cavalry and Heavy Infantry (×1.5 ATK)\nHeavy Infantry → beats Cavalry and Ranged (×1.5 ATK)\n\nThe reverse matchups apply ×0.7 (weak).\n\nThe calculation is weighted: if the rival has a mix of types, each of your troops' attack uses an average based on the enemy composition.\n\nCounter-compositions:\n• Lots of enemy Cavalry → Pikemen + Heavy Infantry\n• Lots of enemy Ranged → Cavalry + Heavy Infantry\n• Lots of enemy Heavy Infantry → Militia + Ranged\n• Varied mix → Militia (neutral but with no clear advantages)")),
		TutorialEntry.new(cat,
			_L("Los frentes de batalla", "Battle fronts"),
			_L("Para abrir un frente necesitas la carta 'Abrir Frente' (desbloqueada por evento). Selecciona el tile enemigo a atacar y luego tu tile desde la que atacas. Ambas deben ser adyacentes.\n\nCada frente tiene un marcador de posición que se desplaza cada turno según la fuerza neta de ambos bandos. Cuando alcanza el umbral, el frente se resuelve: el atacante conquista el tile o el defensor lo rechaza.\n\nEl umbral se reduce con el tiempo (decay), evitando frentes eternos. Un frente no puede resolverse en sus primeros 3 turnos.\n\nFactores que determinan la fuerza:\n• Número y tipos de tropas asignadas\n• Cartas tácticas jugadas (modificadas por bioma)\n• Edificios militares en el tile propio (ej. Fortaleza: +5 defensa plana)\n• Multiplicador económico del Imperio (entre 0.1 y 1.0)\n• Matriz de efectividad tipo vs tipo",
				"To open a front you need the 'Open Front' card (unlocked by event). Select the enemy tile to attack and then your tile to attack from. Both must be adjacent.\n\nEach front has a position marker that shifts each turn according to the net strength of both sides. When it reaches the threshold, the front resolves: the attacker conquers the tile or the defender repels it.\n\nThe threshold decreases over time (decay), preventing endless fronts. A front cannot resolve in its first 3 turns.\n\nFactors that determine strength:\n• Number and types of assigned troops\n• Tactic cards played (modified by biome)\n• Military buildings on your own tile (e.g. Fortress: +5 flat defense)\n• The Empire's economic multiplier (between 0.1 and 1.0)\n• Type-vs-type effectiveness matrix")),
	]


func _events() -> Array[TutorialEntry]:
	var cat := _L("Eventos", "Events")
	return [
		TutorialEntry.new(cat,
			_L("Cómo funcionan los eventos", "How events work"),
			_L("Cada turno hay un 90% de probabilidad de que ocurra un evento. Los eventos no están disponibles hasta controlar 5 o más tiles, momento en que se activa el 'Boom de Construcción' que desbloquea todos los demás.\n\nCada evento tiene condiciones específicas de aparición: número de turno mínimo, recursos necesarios, edificios construidos, tiles controlados, etc.\n\nTipos de evento:\n• Únicos — Ocurren solo una vez por partida. Muy valiosos, no los desperdicies.\n• Repetibles — Pueden ocurrir varias veces a lo largo de la partida.\n• Obligatorios — No se puede evitar su efecto (plagas, sequías).\n• Con elección — Presentan varias opciones con trade-offs distintos.\n\nLos efectos de los eventos escalan con el número de turno: los positivos dan más al avanzar la partida, pero los negativos también golpean más fuerte.",
				"Each turn there is a 90% chance an event will occur. Events are not available until you control 5 or more tiles, at which point the 'Construction Boom' triggers and unlocks all the others.\n\nEach event has specific appearance conditions: minimum turn number, required resources, constructed buildings, controlled tiles, etc.\n\nEvent types:\n• Unique — Occur only once per game. Very valuable, don't waste them.\n• Repeatable — Can occur several times during the game.\n• Mandatory — Their effect cannot be avoided (plagues, droughts).\n• With choices — Present several options with different trade-offs.\n\nEvent effects scale with the turn number: positive ones give more as the game advances, but negative ones also hit harder.")),
		TutorialEntry.new(cat,
			_L("Eventos de prosperidad", "Prosperity events"),
			_L("Eventos que benefician a tu Imperio:\n\n• Cosecha Abundante — +15 comida + escala por turno. Disponible desde turno 5.\n• Tiempo de Abundancia — +20% comida durante 3 turnos. Requiere producción ≥ 5 comida.\n• Vientos de Comercio — +15% oro durante 3 turnos. Requiere producción ≥ 10 oro.\n• Caravana Mercante — +20 oro + escala por turno. Desde turno 3, con 3+ tiles.\n• Artesanos Ambulantes — −15% coste de construcción durante 4 turnos. Desde turno 6.\n• Feria de Ganado — Intercambia −8 comida por +15% oro durante 3 turnos. Requiere producción ≥ 10 comida.\n\nEventos únicos (solo una vez por partida):\n• Sabios Viajeros — +1 carta/turno permanente. Turno 15+, 10+ tiles controlados.\n• Tratado Comercial — +10% oro permanente por 60 oro. Turno 10+, producción ≥ 15 oro.",
				"Events that benefit your Empire:\n\n• Abundant Harvest — +15 food + scales per turn. Available from turn 5.\n• Time of Plenty — +20% food for 3 turns. Requires production ≥ 5 food.\n• Trade Winds — +15% gold for 3 turns. Requires production ≥ 10 gold.\n• Merchant Caravan — +20 gold + scales per turn. From turn 3, with 3+ tiles.\n• Traveling Artisans — −15% construction cost for 4 turns. From turn 6.\n• Cattle Fair — Trade −8 food for +15% gold for 3 turns. Requires production ≥ 10 food.\n\nUnique events (only once per game):\n• Wise Travelers — +1 card/turn permanently. Turn 15+, 10+ controlled tiles.\n• Trade Agreement — +10% permanent gold for 60 gold. Turn 10+, production ≥ 15 gold.")),
		TutorialEntry.new(cat,
			_L("Eventos negativos", "Negative events"),
			_L("Eventos que causan daño a tu Imperio:\n\nEvitables (puedes pagar oro para cancelar el efecto):\n• Mala Cosecha — −10 comida durante 3 turnos. Pagar: 25 oro + escala. Desde turno 4.\n• Bandidos en los Caminos — −8 oro/turno durante 3 turnos. Pagar: 30 oro + escala. Desde turno 5, 4+ tiles.\n• Crisis de Materiales — +25% coste construcción durante 4 turnos. Pagar: 40 oro + escala. Desde turno 8.\n\nObligatorios (no se pueden evitar):\n• Plaga de Langostas — −20% comida durante 4 turnos. Ocurre entre turno 6 y 30.\n• Sequía — −15% comida durante 5 turnos. Ocurre entre turno 10 y 40.\n\nMantén siempre un margen de producción de comida para absorber las plagas y sequías sin que colapsen tu economía.",
				"Events that harm your Empire:\n\nAvoidable (you can pay gold to cancel the effect):\n• Bad Harvest — −10 food for 3 turns. Pay: 25 gold + scaling. From turn 4.\n• Bandits on the Roads — −8 gold/turn for 3 turns. Pay: 30 gold + scaling. From turn 5, 4+ tiles.\n• Material Crisis — +25% construction cost for 4 turns. Pay: 40 gold + scaling. From turn 8.\n\nMandatory (cannot be avoided):\n• Locust Plague — −20% food for 4 turns. Occurs between turn 6 and 30.\n• Drought — −15% food for 5 turns. Occurs between turn 10 and 40.\n\nAlways keep a margin of food production to absorb plagues and droughts without collapsing your economy.")),
		TutorialEntry.new(cat,
			_L("Eventos de decisión", "Decision events"),
			_L("Eventos que requieren una elección estratégica con consecuencias a largo plazo:\n\n• Reforma Agraria (turno 10+, 8+ tiles) — Intercambia −15% oro por +20% comida durante 4 turnos. Ideal si tienes déficit de comida pero superávit de oro.\n\n• Fundación de Megalópolis — Convierte una Town con 3+ edificios en Megalópolis por 200 oro. Muy valioso si tienes una ciudad bien desarrollada.\n\n• Depuración del Mazo — Elimina permanentemente una carta de tu mazo. Usa esta oportunidad para eliminar Colonizares sobrantes o cartas que ya no necesitas. Un mazo pequeño y eficiente es mucho mejor que uno grande y diluido.\n\n• Ofrenda de Cartas — Recibe una carta aleatoria del pool de cartas desbloqueadas.\n\n• Mercenarios (turno 12+) — Recibe una carta Colonizar por 50 oro + escala. Útil para expansión tardía.\n\n• Tratado Comercial (único) — +10% oro permanente por 60 oro. Acepta siempre que puedas pagarlo.",
				"Events that require a strategic choice with long-term consequences:\n\n• Agrarian Reform (turn 10+, 8+ tiles) — Trade −15% gold for +20% food for 4 turns. Ideal if you have a food deficit but a gold surplus.\n\n• Founding a Megalopolis — Turn a Town with 3+ buildings into a Megalopolis for 200 gold. Very valuable if you have a well-developed city.\n\n• Deck Purge — Permanently remove a card from your deck. Use this chance to remove surplus Colonize cards or cards you no longer need. A small, efficient deck is much better than a large, diluted one.\n\n• Card Offering — Receive a random card from the pool of unlocked cards.\n\n• Mercenaries (turn 12+) — Receive a Colonize card for 50 gold + scaling. Useful for late expansion.\n\n• Trade Agreement (unique) — +10% permanent gold for 60 gold. Always accept it if you can afford it.")),
		TutorialEntry.new(cat,
			_L("Los espíritus del bosque", "The forest spirits"),
			_L("Construyendo el Santuario del Bosque (en un tile de Bosque, solo Aldea) desbloqueas un conjunto especial de eventos de tipo SPIRIT:\n\n• Bendición de la Naturaleza — +25% comida durante 3 turnos.\n• Ofrenda del Bosque — +20 comida inmediata + (turno × 2) comida adicional.\n• Pacto con el Bosque — Coloniza automáticamente 1 tile adyacente (prioriza Bosque). Ideal para expansión sin gastar cartas.\n• Raíces Protectoras — −15% coste de construcción durante 3 turnos.\n• Susurros Ancestrales — +1 carta/turno durante 3 turnos.\n\nLos eventos SPIRIT tienen baja probabilidad individual pero en conjunto ofrecen bonificaciones muy valiosas a lo largo de toda la partida. El Santuario es especialmente útil en mapas con abundante terreno boscoso.",
				"By building the Forest Sanctuary (on a Forest tile, Village only) you unlock a special set of SPIRIT-type events:\n\n• Blessing of Nature — +25% food for 3 turns.\n• Forest Offering — +20 immediate food + (turn × 2) additional food.\n• Pact with the Forest — Automatically colonizes 1 adjacent tile (prioritizes Forest). Ideal for expansion without spending cards.\n• Protective Roots — −15% construction cost for 3 turns.\n• Ancestral Whispers — +1 card/turn for 3 turns.\n\nSPIRIT events have a low individual probability but together they offer very valuable bonuses throughout the game. The Sanctuary is especially useful on maps with abundant forest terrain.")),
		TutorialEntry.new(cat,
			_L("Tiendas", "Shops"),
			_L("Dos eventos especiales permiten comprar cartas y mejoras directamente con oro:\n\n• Mercado Local — Tienda estándar. Ofrece cartas y artículos a precio moderado. Aparece con frecuencia moderada.\n\n• Bazar Exótico — Tienda especial con artículos raros y más poderosos, a un precio más elevado. Aparece menos frecuentemente.\n\nAmbas tiendas son opcionales: puedes cerrarlas sin comprar nada.\n\nLas tiendas son una de las principales formas de ampliar tu mazo con cartas nuevas fuera de los eventos de desbloqueo estándar. Si tienes oro sobrante y la tienda ofrece algo útil, suele merecer la pena.",
				"Two special events let you buy cards and upgrades directly with gold:\n\n• Local Market — Standard shop. Offers cards and items at a moderate price. Appears with moderate frequency.\n\n• Exotic Bazaar — Special shop with rare and more powerful items, at a higher price. Appears less frequently.\n\nBoth shops are optional: you can close them without buying anything.\n\nShops are one of the main ways to expand your deck with new cards outside the standard unlock events. If you have spare gold and the shop offers something useful, it is usually worth it.")),
	]


func _empires() -> Array[TutorialEntry]:
	return _balance.entries_empires()


func _victory() -> Array[TutorialEntry]:
	var cat := _L("Victoria", "Victory")
	return [
		TutorialEntry.new(cat,
			_L("Condiciones de victoria", "Victory conditions"),
			_L("Hay dos formas de ganar la partida:\n\n• Dominación Territorial — Controla el 70% o más de todos los tiles del mapa al final de un turno. Los tiles de Océano se pueden colonizar y cuentan para el porcentaje igual que el resto.\n\n• Eliminación — Conquista todos los tiles del Imperio rival. Cuando un Imperio pierde su último tile controlado, queda eliminado automáticamente y el otro Imperio gana.\n\nAmbas condiciones se comprueban al final de cada turno, después de resolver todos los frentes de batalla activos.",
				"There are two ways to win the game:\n\n• Territorial Domination — Control 70% or more of all tiles on the map at the end of a turn. Ocean tiles can be colonized and count toward the percentage like any other.\n\n• Elimination — Conquer all tiles of the rival Empire. When an Empire loses its last controlled tile, it is automatically eliminated and the other Empire wins.\n\nBoth conditions are checked at the end of each turn, after resolving all active battle fronts.")),
		TutorialEntry.new(cat,
			_L("Estrategia de victoria", "Victory strategy"),
			_L("Para la Dominación (70%):\nRequiere expansión eficiente y sostenida. La Horda Mongola es la más adecuada gracias a la recuperación de Colonizar. Vigila el porcentaje de territorios en el panel de estadísticas. Si el rival se aproxima al 70% antes que tú, detenerle debe ser la prioridad absoluta.\n\nPara la Eliminación:\nRequiere romper la línea defensiva del rival abriendo múltiples frentes simultáneamente. Los Medici, con economía superior a largo plazo, pueden sostener ejércitos costosos en varios frentes a la vez.\n\nEl multiplicador económico es clave en ambas victorias: un Imperio con economía colapsada opera con tropas al 10% de efectividad. Forzar el colapso económico del rival, ya sea expandiendo hasta superar su producción de comida o con eventos negativos acumulados, puede ser tan decisivo como vencerle en combate directo.",
				"For Domination (70%):\nRequires efficient, sustained expansion. The Mongol Horde is best suited thanks to recovering Colonize cards. Watch the territory percentage in the stats panel. If the rival approaches 70% before you, stopping them must be the absolute priority.\n\nFor Elimination:\nRequires breaking the rival's defensive line by opening multiple fronts simultaneously. The Medici, with superior long-term economy, can sustain costly armies on several fronts at once.\n\nThe economic multiplier is key to both victories: an Empire with a collapsed economy operates with troops at 10% effectiveness. Forcing the rival's economic collapse, whether by expanding past its food production or with accumulated negative events, can be as decisive as defeating it in direct combat.")),
	]
