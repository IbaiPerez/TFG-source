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
		"category": "Primeros Pasos",
		"title": "Inicio de partida",
		"body": "Comienzas la partida con:\n• 100 de oro en reserva\n• 10 oro de producción por turno\n• 2 cartas robadas al inicio de cada turno\n• 4 copias de la carta Colonizar en tu mazo\n\nCada turno hay un 90% de probabilidad de que ocurra un evento. Los primeros eventos no están disponibles hasta que hayas colonizado al menos 5 tiles, momento en que se activa el 'Boom de Construcción' que desbloquea el resto de eventos.",
	})
	e.append({
		"category": "Primeros Pasos",
		"title": "El flujo de turno",
		"body": "Cada turno tiene tres fases:\n\n1. Evento de turno — Al inicio puede ocurrir un evento aleatorio (90% de probabilidad). Requiere tu decisión antes de continuar.\n\n2. Fase de acción — Juegas las cartas de tu mano para colonizar, construir, reclutar, abrir frentes de batalla... No hay límite de cartas por turno.\n\n3. Fin de turno — Pulsas el botón para terminar. Se resuelven los frentes de batalla, se cobra el mantenimiento de tropas y se procesa la producción de recursos de todos tus tiles.",
	})

	# --- El Mapa ---
	e.append({
		"category": "El Mapa",
		"title": "Los biomas",
		"body": "El mapa está compuesto por tiles hexagonales de 7 tipos de bioma:\n\n• Pradera (Grassland) — Recursos: Trigo (exclusivo), Ganado (común), Piedra y Arena (raros). Permite el Molino (+20% comida). Ideal para Caballería (×1.5 en Carga).\n• Bosque (Forest) — Recursos: Madera (principal) y Caza Mayor. Permite el Santuario del Bosque (solo Aldea).\n• Desierto (Desert) — Recursos: Arena (principal), Sal, Hierro y Ganado (secundarios). Permite la Caravana Comercial (+15 oro).\n• Pantano (Swamp) — Recursos: Madera y Pesca. Permite la Granja de Sanguijuelas (solo Aldea).\n• Tundra — Recursos: Ganado (principal) y Caza Mayor. Permite el Observatorio (solo Town+).\n• Montaña (Mountain) — Recursos: Piedra (principal), Hierro (común) y Arena. Permite la Fortaleza (+5 defensa plana). El Muro de Lanzas es muy efectivo aquí (×1.5).\n• Océano (Ocean) — Se coloniza como cualquier tile. Recursos: Pesca (principal) y Sal. Solo permite construir Puertos (Town+).\n\nATENCIÓN: todas las cartas tácticas tienen multiplicador ×0.0 en Océano. Las tácticas militares son completamente inefectivas en tiles de agua.",
	})

	# --- Recursos Naturales ---
	e.append(_entry_food_resources())
	e.append(_entry_wealth_resources())

	# --- Territorios ---
	e.append({
		"category": "Territorios",
		"title": "Village, Town y Megalópolis",
		"body": "Los tiles controlados tienen tres niveles de desarrollo:\n\n• Aldea (Village) — 1 slot de construcción. Acepta edificios básicos y algunos especiales (Fortaleza, Santuario del Bosque, Caravana Comercial, Granja de Sanguijuelas, Cuartel, Molino). Consumo: 0 comida/turno.\n\n• Ciudad (Town) — 3 slots de construcción. Da acceso a edificios avanzados, mercados, templos y militares. Consumo: 5 comida/turno.\n\n• Megalópolis — 5 slots de construcción. Permite los edificios más poderosos del juego (Palacio Imperial, Gran Biblioteca, Academia Militar). Consumo: 10 comida/turno.\n\nNo urbanices más rápido de lo que tu producción de comida puede sostener: cada Town añade 5 de consumo y cada Megalópolis 10.",
	})
	e.append({
		"category": "Territorios",
		"title": "Colonizar y Urbanizar",
		"body": "Colonizar — Juega la carta Colonizar sobre un tile vacío adyacente a uno que ya controles. El tile pasa a ser una Aldea (1 slot). Es la única carta en el mazo inicial (4 copias).\n\nUrbanizar a Town — Juega la carta 'Proyecto Urbano' sobre una Aldea para convertirla en Ciudad (3 slots). Desbloquea edificios más poderosos pero añade 5 comida/turno de consumo. La carta Proyecto Urbano se desbloquea mediante un evento de turno.\n\nFundar Megalópolis — Aparece como evento de turno cuando tienes una Town con 3 o más edificios y dispones de 200 de oro. Coste fijo: 200 oro. Convierte esa Town en Megalópolis (5 slots, 10 comida/turno).\n\nEstrategia: coloniza para expandirte, urbaniza donde quieras construir edificios avanzados, y guarda la Megalópolis para las ciudades más productivas.",
	})

	# --- Economía ---
	e.append({
		"category": "Economía",
		"title": "El oro",
		"body": "El oro es el recurso principal del juego. Se usa para:\n• Jugar cartas (construir, reclutar tropas, abrir frentes)\n• Pagar costes en eventos negativos\n• Fundar una Megalópolis (200 oro fijo)\n• Firmar el Tratado Comercial (60 oro, +10% oro permanente)\n\nProducción inicial: 10 oro/turno. Cada edificio económico suma directamente a este valor.\n\nSi acumulas déficit de oro sostenido, tu multiplicador de combate se degrada progresivamente hasta un mínimo de 10% de tu capacidad total. Un ejército en un Imperio en quiebra es casi inútil en combate.",
	})
	e.append({
		"category": "Economía",
		"title": "La comida",
		"body": _entry_food_body(),
	})
	e.append({
		"category": "Economía",
		"title": "El multiplicador de combate",
		"body": "Cada Imperio tiene un multiplicador de combate entre 0.1 y 1.0 que se aplica a todo el ataque y defensa de sus tropas.\n\n• Economía sana → multiplicador 1.0 (100% de efectividad)\n• Déficit creciente → el multiplicador se degrada gradualmente\n• Colapso económico → multiplicador 0.1 (solo 10% de efectividad)\n\nEste valor se recalcula cada turno en función del déficit acumulado de oro y comida.\n\nImpacto estratégico: un Imperio rico puede vencer a uno militarmente superior simplemente agotando su economía. Forzar el colapso económico del rival mediante expansión agresiva que supere su producción de comida puede ser tan efectivo como vencerle en combate directo.",
	})

	# --- Cartas ---
	e.append({
		"category": "Cartas",
		"title": "El mazo y la mano",
		"body": "Tu mazo contiene todas las cartas disponibles para tu Imperio. Comienzas solo con 4 copias de Colonizar y robas 2 cartas por turno.\n\nCuando el mazo se agota, el montón de descarte se baraja automáticamente formando uno nuevo. Haz clic en los iconos de pila en la pantalla para ver el contenido de tu mazo y descarte.\n\nLas cartas de un solo uso (SINGLE_USE) van a una pila separada al jugarse. La carta 'Recuperar' permite devolverle una de ellas a tu mano.\n\nFormas de robar más cartas por turno:\n• Biblioteca, Observatorio, Puerto Comercial, Anfiteatro: +1 carta/turno cada uno\n• Gran Biblioteca: +1 carta/turno adicional al robar\n• Palacio Imperial: +1 carta/turno\n• Evento Sabios Viajeros: +1 carta/turno permanente",
	})
	e.append({
		"category": "Cartas",
		"title": "Tipos de cartas",
		"body": "Cartas BÁSICAS (núcleo del juego, desbloqueadas por eventos):\n• Colonizar — Toma un tile adyacente vacío. En el mazo inicial.\n• Construir — Elige y construye un edificio en un tile controlado.\n• Mejorar Edificio — Mejora un edificio existente a su siguiente nivel.\n• Reclutar — Elige un tipo de tropa y reclútala.\n• Abrir Frente — Inicia un frente de batalla contra un tile enemigo adyacente.\n\nCartas ESPECIALES:\n• Proyecto Urbano — Urbaniza una Aldea a Town.\n• Robar Carta — Roba 1 carta adicional inmediatamente.\n• Recuperar — Devuelve a tu mano una carta de un solo uso ya jugada.\n\nCartas de UN SOLO USO — Construyen directamente edificios especiales (Templo, Biblioteca, Santuario, Coliseo, Escuela, Oficina, Palacio). Se desbloquean por eventos.\n\nCartas TÁCTICAS — Se juegan sobre frentes de batalla activos.",
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
		"category": "Militar",
		"title": "La matriz de efectividad",
		"body": "El combate usa una cadena de ventajas tipo piedra-papel-tijera:\n\nCaballería → supera a Tiradores y Milicia (×1.5 ATK)\nTiradores → superan a Milicia e Infantería Pesada (×1.5 ATK)\nMilicia → supera a Piqueros e Infantería Pesada (×1.5 ATK)\nPiqueros → superan a Caballería e Infantería Pesada (×1.5 ATK)\nInfantería Pesada → supera a Caballería y Tiradores (×1.5 ATK)\n\nLos enfrentamientos inversos aplican ×0.7 (débil).\n\nEl cálculo es ponderado: si el rival tiene mezcla de tipos, el ataque de cada tropa tuya usa un promedio basado en la composición enemiga.\n\nContra-composiciones:\n• Mucha Caballería rival → Piqueros + Infantería Pesada\n• Muchos Tiradores rival → Caballería + Infantería Pesada\n• Mucha Infantería Pesada rival → Milicia + Tiradores\n• Mezcla variada → Milicia (neutra pero sin ventajas claras)",
	})
	e.append({
		"category": "Militar",
		"title": "Los frentes de batalla",
		"body": "Para abrir un frente necesitas la carta 'Abrir Frente' (desbloqueada por evento). Selecciona el tile enemigo a atacar y luego tu tile desde la que atacas. Ambas deben ser adyacentes.\n\nCada frente tiene un marcador de posición que se desplaza cada turno según la fuerza neta de ambos bandos. Cuando alcanza el umbral, el frente se resuelve: el atacante conquista el tile o el defensor lo rechaza.\n\nEl umbral se reduce con el tiempo (decay), evitando frentes eternos. Un frente no puede resolverse en sus primeros 3 turnos.\n\nFactores que determinan la fuerza:\n• Número y tipos de tropas asignadas\n• Cartas tácticas jugadas (modificadas por bioma)\n• Edificios militares en el tile propio (ej. Fortaleza: +5 defensa plana)\n• Multiplicador económico del Imperio (entre 0.1 y 1.0)\n• Matriz de efectividad tipo vs tipo",
	})

	# --- Eventos ---
	e.append({
		"category": "Eventos",
		"title": "Cómo funcionan los eventos",
		"body": "Cada turno hay un 90% de probabilidad de que ocurra un evento. Los eventos no están disponibles hasta controlar 5 o más tiles, momento en que se activa el 'Boom de Construcción' que desbloquea todos los demás.\n\nCada evento tiene condiciones específicas de aparición: número de turno mínimo, recursos necesarios, edificios construidos, tiles controlados, etc.\n\nTipos de evento:\n• Únicos — Ocurren solo una vez por partida. Muy valiosos, no los desperdicies.\n• Repetibles — Pueden ocurrir varias veces a lo largo de la partida.\n• Obligatorios — No se puede evitar su efecto (plagas, sequías).\n• Con elección — Presentan varias opciones con trade-offs distintos.\n\nLos efectos de los eventos escalan con el número de turno: los positivos dan más al avanzar la partida, pero los negativos también golpean más fuerte.",
	})
	e.append({
		"category": "Eventos",
		"title": "Eventos de prosperidad",
		"body": "Eventos que benefician a tu Imperio:\n\n• Cosecha Abundante — +15 comida + escala por turno. Disponible desde turno 5.\n• Tiempo de Abundancia — +20% comida durante 3 turnos. Requiere producción ≥ 5 comida.\n• Vientos de Comercio — +15% oro durante 3 turnos. Requiere producción ≥ 10 oro.\n• Caravana Mercante — +20 oro + escala por turno. Desde turno 3, con 3+ tiles.\n• Artesanos Ambulantes — −15% coste de construcción durante 4 turnos. Desde turno 6.\n• Feria de Ganado — Intercambia −8 comida por +15% oro durante 3 turnos. Requiere producción ≥ 10 comida.\n\nEventos únicos (solo una vez por partida):\n• Sabios Viajeros — +1 carta/turno permanente. Turno 15+, 10+ tiles controlados.\n• Tratado Comercial — +10% oro permanente por 60 oro. Turno 10+, producción ≥ 15 oro.",
	})
	e.append({
		"category": "Eventos",
		"title": "Eventos negativos",
		"body": "Eventos que causan daño a tu Imperio:\n\nEvitables (puedes pagar oro para cancelar el efecto):\n• Mala Cosecha — −10 comida durante 3 turnos. Pagar: 25 oro + escala. Desde turno 4.\n• Bandidos en los Caminos — −8 oro/turno durante 3 turnos. Pagar: 30 oro + escala. Desde turno 5, 4+ tiles.\n• Crisis de Materiales — +25% coste construcción durante 4 turnos. Pagar: 40 oro + escala. Desde turno 8.\n\nObligatorios (no se pueden evitar):\n• Plaga de Langostas — −20% comida durante 4 turnos. Ocurre entre turno 6 y 30.\n• Sequía — −15% comida durante 5 turnos. Ocurre entre turno 10 y 40.\n\nMantén siempre un margen de producción de comida para absorber las plagas y sequías sin que colapsen tu economía.",
	})
	e.append({
		"category": "Eventos",
		"title": "Eventos de decisión",
		"body": "Eventos que requieren una elección estratégica con consecuencias a largo plazo:\n\n• Reforma Agraria (turno 10+, 8+ tiles) — Intercambia −15% oro por +20% comida durante 4 turnos. Ideal si tienes déficit de comida pero superávit de oro.\n\n• Fundación de Megalópolis — Convierte una Town con 3+ edificios en Megalópolis por 200 oro. Muy valioso si tienes una ciudad bien desarrollada.\n\n• Depuración del Mazo — Elimina permanentemente una carta de tu mazo. Usa esta oportunidad para eliminar Colonizares sobrantes o cartas que ya no necesitas. Un mazo pequeño y eficiente es mucho mejor que uno grande y diluido.\n\n• Ofrenda de Cartas — Recibe una carta aleatoria del pool de cartas desbloqueadas.\n\n• Mercenarios (turno 12+) — Recibe una carta Colonizar por 50 oro + escala. Útil para expansión tardía.\n\n• Tratado Comercial (único) — +10% oro permanente por 60 oro. Acepta siempre que puedas pagarlo.",
	})
	e.append({
		"category": "Eventos",
		"title": "Los espíritus del bosque",
		"body": "Construyendo el Santuario del Bosque (en un tile de Bosque, solo Aldea) desbloqueas un conjunto especial de eventos de tipo SPIRIT:\n\n• Bendición de la Naturaleza — +25% comida durante 3 turnos.\n• Ofrenda del Bosque — +20 comida inmediata + (turno × 2) comida adicional.\n• Pacto con el Bosque — Coloniza automáticamente 1 tile adyacente (prioriza Bosque). Ideal para expansión sin gastar cartas.\n• Raíces Protectoras — −15% coste de construcción durante 3 turnos.\n• Susurros Ancestrales — +1 carta/turno durante 3 turnos.\n\nLos eventos SPIRIT tienen baja probabilidad individual pero en conjunto ofrecen bonificaciones muy valiosas a lo largo de toda la partida. El Santuario es especialmente útil en mapas con abundante terreno boscoso.",
	})
	e.append({
		"category": "Eventos",
		"title": "Tiendas",
		"body": "Dos eventos especiales permiten comprar cartas y mejoras directamente con oro:\n\n• Mercado Local — Tienda estándar. Ofrece cartas y artículos a precio moderado. Aparece con frecuencia moderada.\n\n• Bazar Exótico — Tienda especial con artículos raros y más poderosos, a un precio más elevado. Aparece menos frecuentemente.\n\nAmbas tiendas son opcionales: puedes cerrarlas sin comprar nada.\n\nLas tiendas son una de las principales formas de ampliar tu mazo con cartas nuevas fuera de los eventos de desbloqueo estándar. Si tienes oro sobrante y la tienda ofrece algo útil, suele merecer la pena.",
	})

	# --- Imperios ---
	e.append(_entry_empire(
		_EMP_MEDICI, _AB_MEDICI,
		"Estilo de juego: expansión económica progresiva. Los Medici construyen más barato y generan más oro desde el inicio. Su ventaja crece exponencialmente con el tiempo según acumulan edificios.\n\nDebilidad: vulnerables a presiones militares tempranas.\n\nConsejo: prioriza Minas de Oro y el Banco en los primeros turnos.",
	))
	e.append(_entry_empire(
		_EMP_MONGOL, _AB_MONGOL,
		"Estilo de juego: expansión agresiva desde el primer turno. La recuperación de Colonizar permite tomar muchos más territorios que cualquier otro Imperio.\n\nDebilidad: depende de expansión continua. Si la expansión se frena, puede quedarse sin recursos.\n\nConsejo: expande muy agresivamente los primeros turnos. Busca tiles de Pradera para Cargas de Caballería y tiles con Ganadería para la economía.",
	))
	e.append(_entry_empire(
		_EMP_BABYLON, _AB_BABYLON,
		"Estilo de juego: equilibrio entre economía y producción de alimentos. Babilonia puede sostener más ciudades y Megalópolis gracias al bonus en Trigo.\n\nDebilidad: crece más despacio que Medici en oro puro y más despacio que Mongol en territorio.\n\nConsejo: busca tiles con Trigo activamente. Construye el Zigurat cuanto antes para iniciar la cadena hacia los Jardines Celestiales.",
	))

	# --- Victoria ---
	e.append({
		"category": "Victoria",
		"title": "Condiciones de victoria",
		"body": "Hay dos formas de ganar la partida:\n\n• Dominación Territorial — Controla el 70% o más de todos los tiles del mapa al final de un turno. Los tiles de Océano se pueden colonizar y cuentan para el porcentaje igual que el resto.\n\n• Eliminación — Conquista todos los tiles del Imperio rival. Cuando un Imperio pierde su último tile controlado, queda eliminado automáticamente y el otro Imperio gana.\n\nAmbas condiciones se comprueban al final de cada turno, después de resolver todos los frentes de batalla activos.",
	})
	e.append({
		"category": "Victoria",
		"title": "Estrategia de victoria",
		"body": "Para la Dominación (70%):\nRequiere expansión eficiente y sostenida. La Horda Mongola es la más adecuada gracias a la recuperación de Colonizar. Vigila el porcentaje de territorios en el panel de estadísticas. Si el rival se aproxima al 70% antes que tú, detenerle debe ser la prioridad absoluta.\n\nPara la Eliminación:\nRequiere romper la línea defensiva del rival abriendo múltiples frentes simultáneamente. Los Medici, con economía superior a largo plazo, pueden sostener ejércitos costosos en varios frentes a la vez.\n\nEl multiplicador económico es clave en ambas victorias: un Imperio con economía colapsada opera con tropas al 10% de efectividad. Forzar el colapso económico del rival, ya sea expandiendo hasta superar su producción de comida o con eventos negativos acumulados, puede ser tan decisivo como vencerle en combate directo.",
	})

	return e


# ─────────────────────────────────────────────────────────────────────────────
# Dynamic entry builders
# ─────────────────────────────────────────────────────────────────────────────

func _entry_food_resources() -> Dictionary:
	var fp := _B_FISHING_PORT
	var fm := _B_FISH_MARKET
	var body := "Cuatro recursos naturales producen principalmente comida:\n\n"
	body += "• Trigo (Wheat) [solo Pradera] — Cultivos (coste %d): +%d comida/turno. Mejora a Granero (%d): +%d comida/turno.\n\n" % [
		_B_CROPS.construction_cost, _B_CROPS.food_produced,
		_B_GRANARY.construction_cost, _B_GRANARY.food_produced]
	body += "• Ganadería (Livestock) [Tundra, Pradera, Desierto] — Granja de Ganado (%d): +%d comida, +%d oro/turno. Mejora a Rancho (%d): +%d comida, +%d oro/turno.\n\n" % [
		_B_LIVESTOCK_FARM.construction_cost, _B_LIVESTOCK_FARM.food_produced, _B_LIVESTOCK_FARM.gold_produced,
		_B_RANCH.construction_cost, _B_RANCH.food_produced, _B_RANCH.gold_produced]
	body += "• Pesca (Fish) [Océano, Pantano] — Pesquería (%d): +%d comida, +%d oro/turno. Mejora a Puerto Pesquero (%d, solo Océano, Town+): +%d comida, +%d oro; o a Mercado de Pescado (%d): +%d comida, +%d oro.\n\n" % [
		_B_FISHERY.construction_cost, _B_FISHERY.food_produced, _B_FISHERY.gold_produced,
		fp.construction_cost, fp.food_produced, fp.gold_produced,
		fm.construction_cost, fm.food_produced, fm.gold_produced]
	body += "• Caza Mayor (Wild Game) [Bosque, Tundra] — Zona de Caza (%d): +%d comida, +%d oro/turno. Mejora a Tenería (%d): +%d comida, +%d oro/turno." % [
		_B_HUNTING.construction_cost, _B_HUNTING.food_produced, _B_HUNTING.gold_produced,
		_B_TANNERY.construction_cost, _B_TANNERY.food_produced, _B_TANNERY.gold_produced]
	return {"category": "Recursos Naturales", "title": "Recursos alimentarios", "body": body}


func _entry_wealth_resources() -> Dictionary:
	var body := "Seis recursos naturales generan principalmente oro:\n\n"
	body += "• Oro (Gold) [todos los biomas] — Mina de Oro (coste %d): +%d oro/turno. Mejora a Casa de la Moneda (%d): +%d oro/turno. El más rentable del juego.\n\n" % [
		_B_GOLD_MINE.construction_cost, _B_GOLD_MINE.gold_produced,
		_B_ROYAL_MINT.construction_cost, _B_ROYAL_MINT.gold_produced]
	body += "• Hierro (Iron) [Montaña, Desierto] — Mina de Hierro (%d): +%d oro/turno. Mejora a Herrería (%d): +%d oro/turno.\n\n" % [
		_B_IRON_MINE.construction_cost, _B_IRON_MINE.gold_produced,
		_B_FORGE.construction_cost, _B_FORGE.gold_produced]
	body += "• Sal (Salt) [Océano, Desierto] — Mina de Sal (%d): +%d oro/turno. Mejora a Refinería de Sal (%d): +%d oro/turno.\n\n" % [
		_B_SALT_MINE.construction_cost, _B_SALT_MINE.gold_produced,
		_B_SALT_REF.construction_cost, _B_SALT_REF.gold_produced]
	body += "• Madera (Wood) [Bosque, Pantano] — Campamento Forestal (%d): +%d oro/turno. Mejora a Serrería (%d): +%d oro/turno.\n\n" % [
		_B_LOGGING_CAMP.construction_cost, _B_LOGGING_CAMP.gold_produced,
		_B_SAWMILL.construction_cost, _B_SAWMILL.gold_produced]
	body += "• Piedra (Stone) [Montaña, Pradera] — Cantera (%d): +%d oro/turno. Mejora a Taller de Cantería (%d): +%d oro/turno.\n\n" % [
		_B_QUARRY.construction_cost, _B_QUARRY.gold_produced,
		_B_STONECUTTER.construction_cost, _B_STONECUTTER.gold_produced]
	body += "• Arena (Sand) [Desierto, Montaña] — Foso de Arena (%d): +%d oro/turno. Mejora a Vidriera (%d): +%d oro/turno." % [
		_B_SAND_PIT.construction_cost, _B_SAND_PIT.gold_produced,
		_B_GLASSWORKS.construction_cost, _B_GLASSWORKS.gold_produced]
	return {"category": "Recursos Naturales", "title": "Recursos de riqueza", "body": body}


func _entry_food_body() -> String:
	var troops := [_T_MILITIA, _T_RANGED, _T_PIKEMEN, _T_CAVALRY, _T_HEAVY]
	var body := "La comida mantiene activas tus ciudades y tropas. Cada turno se descuenta:\n• Town: −5 comida/turno\n• Megalópolis: −10 comida/turno"
	for t in troops:
		if t.maintenance_food > 0:
			body += "\n• %s: −%d comida/turno por tropa" % [t.name, t.maintenance_food]
	body += "\n\nSi tu producción no cubre el consumo, el déficit degrada el multiplicador de combate igual que el déficit de oro.\n\nCuidado con la expansión rápida: colonizar muchas ciudades sin suficiente producción de comida puede colapsar tu economía de golpe."
	return body


func _entry_basic_buildings() -> Dictionary:
	var lines: Array[String] = [
		"Todos los edificios básicos requieren solo Aldea. Cada uno necesita el recurso natural específico en el tile:\n",
		"Recurso [biomas principales] → Edificio (coste) → Producción/turno",
		"Trigo [Pradera] → Cultivos (%d) → +%d comida" % [_B_CROPS.construction_cost, _B_CROPS.food_produced],
		"Pesca [Océano, Pantano] → Pesquería (%d) → +%d comida, +%d oro" % [_B_FISHERY.construction_cost, _B_FISHERY.food_produced, _B_FISHERY.gold_produced],
		"Oro [todos los biomas] → Mina de Oro (%d) → +%d oro" % [_B_GOLD_MINE.construction_cost, _B_GOLD_MINE.gold_produced],
		"Caza Mayor [Bosque, Tundra] → Zona de Caza (%d) → +%d comida, +%d oro" % [_B_HUNTING.construction_cost, _B_HUNTING.food_produced, _B_HUNTING.gold_produced],
		"Hierro [Montaña, Desierto] → Mina de Hierro (%d) → +%d oro" % [_B_IRON_MINE.construction_cost, _B_IRON_MINE.gold_produced],
		"Ganado [Tundra, Pradera, Desierto] → Granja de Ganado (%d) → +%d comida, +%d oro" % [_B_LIVESTOCK_FARM.construction_cost, _B_LIVESTOCK_FARM.food_produced, _B_LIVESTOCK_FARM.gold_produced],
		"Madera [Bosque, Pantano] → Campamento Forestal (%d) → +%d oro" % [_B_LOGGING_CAMP.construction_cost, _B_LOGGING_CAMP.gold_produced],
		"Piedra [Montaña, Pradera] → Cantera (%d) → +%d oro" % [_B_QUARRY.construction_cost, _B_QUARRY.gold_produced],
		"Sal [Océano, Desierto] → Mina de Sal (%d) → +%d oro" % [_B_SALT_MINE.construction_cost, _B_SALT_MINE.gold_produced],
		"Arena [Desierto, Montaña] → Foso de Arena (%d) → +%d oro" % [_B_SAND_PIT.construction_cost, _B_SAND_PIT.gold_produced],
		"\nLa Mina de Oro (%d oro/turno, coste %d) es la inversión con mejor retorno. El Oro puede aparecer en todos los biomas aunque es poco frecuente." % [_B_GOLD_MINE.gold_produced, _B_GOLD_MINE.construction_cost],
	]
	return {"category": "Edificios", "title": "Edificios básicos", "body": "\n".join(lines)}


func _entry_upgrade_buildings() -> Dictionary:
	var body := "Mejoras construidas con la carta 'Mejorar Edificio'. La mejora requiere el mismo bioma que el edificio base.\n\n"
	body += "Solo Aldea (misma restricción que la base):\n"
	body += "• Cultivos → Granero (%d): +%d comida/turno\n" % [_B_GRANARY.construction_cost, _B_GRANARY.food_produced]
	body += "• Mina de Oro → Casa de la Moneda (%d): +%d oro/turno\n" % [_B_ROYAL_MINT.construction_cost, _B_ROYAL_MINT.gold_produced]
	body += "• Granja de Ganado → Rancho (%d): +%d comida, +%d oro/turno\n" % [_B_RANCH.construction_cost, _B_RANCH.food_produced, _B_RANCH.gold_produced]
	body += "• Zona de Caza → Tenería (%d): +%d comida, +%d oro/turno\n" % [_B_TANNERY.construction_cost, _B_TANNERY.food_produced, _B_TANNERY.gold_produced]
	body += "• Mina de Sal → Refinería de Sal (%d): +%d oro/turno\n" % [_B_SALT_REF.construction_cost, _B_SALT_REF.gold_produced]
	body += "\nCualquier nivel de tile (sin restricción):\n"
	body += "• Mina de Hierro → Herrería (%d): +%d oro/turno\n" % [_B_FORGE.construction_cost, _B_FORGE.gold_produced]
	body += "• Campamento Forestal → Serrería (%d): +%d oro/turno\n" % [_B_SAWMILL.construction_cost, _B_SAWMILL.gold_produced]
	body += "• Cantera → Taller de Cantería (%d): +%d oro/turno\n" % [_B_STONECUTTER.construction_cost, _B_STONECUTTER.gold_produced]
	body += "• Foso de Arena → Vidriera (%d): +%d oro/turno\n" % [_B_GLASSWORKS.construction_cost, _B_GLASSWORKS.gold_produced]
	body += "• Pesquería → Puerto Pesquero (%d, solo Océano): +%d comida, +%d oro/turno\n" % [_B_FISHING_PORT.construction_cost, _B_FISHING_PORT.food_produced, _B_FISHING_PORT.gold_produced]
	body += "• Pesquería → Mercado de Pescado (%d): +%d comida, +%d oro/turno\n" % [_B_FISH_MARKET.construction_cost, _B_FISH_MARKET.food_produced, _B_FISH_MARKET.gold_produced]
	body += "\nLa Casa de la Moneda (%d oro, inversión total %d) tiene el mejor retorno absoluto a largo plazo." % [
		_B_ROYAL_MINT.gold_produced, _B_GOLD_MINE.construction_cost + _B_ROYAL_MINT.construction_cost]
	return {"category": "Edificios", "title": "Mejoras de edificios", "body": body}


func _entry_biome_buildings() -> Dictionary:
	var body := "Edificios que requieren un bioma concreto. El nivel de tile requerido varía:\n\n"
	body += "• Molino (%d, Pradera, cualquier nivel) — +%d comida, +%.0f%% comida del tile, %s.\n\n" % [
		_B_MOLINO.construction_cost, _B_MOLINO.food_produced,
		_B_MOLINO.food_percent_bonus, _sgold(_B_MOLINO.gold_produced)]
	body += "• Santuario del Bosque (%d, Bosque, solo Aldea) — %s/turno. Desbloquea eventos SPIRIT exclusivos.\n\n" % [
		_B_SANTUARIO.construction_cost, _prod(_B_SANTUARIO.gold_produced, _B_SANTUARIO.food_produced)]
	body += "• Caravana Comercial (%d, Desierto, cualquier nivel) — %s/turno.\n\n" % [
		_B_CARAVANA.construction_cost, _prod(_B_CARAVANA.gold_produced, _B_CARAVANA.food_produced)]
	body += "• Granja de Sanguijuelas (%d, Pantano, solo Aldea) — %s/turno. Muy rentable para su coste.\n\n" % [
		_B_GRANJA_SANG.construction_cost, _prod(_B_GRANJA_SANG.gold_produced, _B_GRANJA_SANG.food_produced)]
	body += "• Fortaleza (%d, Montaña, cualquier nivel) — +%d defensa plana en el tile, %s.\n\n" % [
		_B_FORTALEZA.construction_cost, _B_FORTALEZA.flat_defense_bonus, _sgold(_B_FORTALEZA.gold_produced)]
	body += "• Puerto (%d, Océano, solo Town+) — +%d oro/turno. Mejora a Puerto Comercial (%d): +%d oro, +1 carta/turno.\n\n" % [
		_B_PORT.construction_cost, _B_PORT.gold_produced,
		_B_PUERTO_COM.construction_cost, _B_PUERTO_COM.gold_produced]
	body += "• Observatorio (%d, Tundra, solo Town+) — +%d oro, +1 carta/turno, %s." % [
		_B_OBSERV.construction_cost, _B_OBSERV.gold_produced, _sfood(_B_OBSERV.food_produced)]
	return {"category": "Edificios", "title": "Edificios especiales de bioma", "body": body}


func _entry_town_buildings() -> Dictionary:
	var body := "La mayoría requieren Town+. Las excepciones se indican:\n\nProducción económica (Town+):\n"
	body += "• Plaza del Mercado (%d): +%d oro/turno\n" % [_B_MARKET_SQ.construction_cost, _B_MARKET_SQ.gold_produced]
	body += "• Gremio de Mercaderes (%d): +%d oro/turno\n" % [_B_GREMIO.construction_cost, _B_GREMIO.gold_produced]
	body += "• Almacén (%d): %s/turno\n" % [_B_WAREHOUSE.construction_cost, _prod(_B_WAREHOUSE.gold_produced, _B_WAREHOUSE.food_produced)]
	body += "• Huertos Urbanos (%d): +%d comida/turno\n" % [_B_HUERTOS.construction_cost, _B_HUERTOS.food_produced]
	body += "• Templo (%d): +%d oro, +%d comida, +10%% comida global → mejora a Gran Catedral\n" % [_B_TEMPLE.construction_cost, _B_TEMPLE.gold_produced, _B_TEMPLE.food_produced]
	body += "• Biblioteca (%d): +%d oro, +1 carta/turno → mejora a Gran Biblioteca\n" % [_B_LIBRARY.construction_cost, _B_LIBRARY.gold_produced]
	body += "• Anfiteatro (%d): +1 carta/turno, %s/turno\n" % [_B_ANFITEATRO.construction_cost, _prod(_B_ANFITEATRO.gold_produced, _B_ANFITEATRO.food_produced)]
	body += "\nMilitar (cualquier nivel de tile):\n"
	body += "• Cuartel (%d): +1 tropa extra al reclutar, %s → mejora a Academia Militar\n" % [_B_CUARTEL.construction_cost, _sgold(_B_CUARTEL.gold_produced)]
	body += "\nMilitar y construcción (Town+):\n"
	body += "• Coliseo (%d): +%d oro, +%d comida, −20%% coste de construcción global\n" % [_B_COLISEO.construction_cost, _B_COLISEO.gold_produced, _B_COLISEO.food_produced]
	body += "• Oficina de Construcción (%d): +15 oro cada vez que juegas Construir o Mejorar Edificio\n" % _B_OFICINA.construction_cost
	body += "• Escuela de Planificación (%d): +20 oro cada vez que juegas Proyecto Urbano" % _B_ESCUELA.construction_cost
	return {"category": "Edificios", "title": "Edificios para ciudades (Town+)", "body": body}


func _entry_megalopolis_buildings() -> Dictionary:
	var body := "Los edificios más poderosos del juego requieren Megalópolis:\n\n"
	body += "• Palacio Imperial (%d): +%d oro, +%d comida, +15%% oro global, +15%% comida global, +1 carta/turno. El edificio más completo del juego. Requiere carta de un solo uso.\n\n" % [
		_B_PALACIO.construction_cost, _B_PALACIO.gold_produced, _B_PALACIO.food_produced]
	body += "• Gran Biblioteca (%d): +%d oro, +%d comida, +1 carta/turno, +1 carta extra al robar. Requiere Biblioteca previa.\n\n" % [
		_B_GRAN_BIBL.construction_cost, _B_GRAN_BIBL.gold_produced, _B_GRAN_BIBL.food_produced]
	body += "• Gran Catedral (%d): +%d oro, +%d comida, +25%% comida global. Requiere Templo previo.\n\n" % [
		_B_GRAN_CATED.construction_cost, _B_GRAN_CATED.gold_produced, _B_GRAN_CATED.food_produced]
	body += "• Jardines Celestiales (%d): +%d oro, +%d comida, +15%% comida global. Solo accesible vía Zigurat (exclusivo Babilonia).\n\n" % [
		_B_JARDINES_C.construction_cost, _B_JARDINES_C.gold_produced, _B_JARDINES_C.food_produced]
	body += "• Tesoro Imperial (%d): +%d oro, +20%% oro global, %s. Exclusivo Medici (vía Banco).\n\n" % [
		_B_TESORO.construction_cost, _B_TESORO.gold_produced, _sfood(_B_TESORO.food_produced)]
	body += "• Academia Militar (%d): +1 tropa extra al reclutar, −20%% mantenimiento de tropas, %s. Requiere Cuartel previo.\n\n" % [
		_B_ACADEMIA.construction_cost, _sgold(_B_ACADEMIA.gold_produced)]
	body += "• Puerto Comercial (%d, Océano): +%d oro, +1 carta/turno. Requiere Puerto previo." % [
		_B_PUERTO_COM.construction_cost, _B_PUERTO_COM.gold_produced]
	return {"category": "Edificios", "title": "Edificios avanzados (Megalópolis)", "body": body}


func _entry_troops() -> Dictionary:
	var troops := [_T_MILITIA, _T_RANGED, _T_PIKEMEN, _T_CAVALRY, _T_HEAVY]
	var lines: Array[String] = ["Hay 5 tipos de tropa, todas accesibles con la carta Reclutar:\n"]
	for t in troops:
		lines.append("• %s — ATK %d / DEF %d. Recluta: %d oro. Mantenimiento: %d oro + %d comida/turno." % [
			t.name, t.attack, t.defense, t.recruitment_cost_gold, t.maintenance_gold, t.maintenance_food])
	return {"category": "Militar", "title": "Tipos de tropas", "body": "\n\n".join(lines)}


func _entry_tactic_cards() -> Dictionary:
	var tactics := [_TC_CAVALRY_CHARGE, _TC_PHALANX, _TC_ARROW_RAIN, _TC_AMBUSH, _TC_FRONTAL_ASSAULT]
	var lines: Array[String] = ["Las tácticas se juegan sobre un frente de batalla activo y potencian tropas concretas. Su efectividad varía según el bioma del tile en combate:\n"]
	for t in tactics:
		var type_labels: Array[String] = []
		for tt: int in t.affected_troop_types:
			type_labels.append(_troop_type_label(tt))
		var bonus_parts: Array[String] = []
		if t.attack_percent_per_type != 0.0:
			bonus_parts.append("+%.0f%% ATK" % t.attack_percent_per_type)
		if t.defense_percent_per_type != 0.0:
			bonus_parts.append("+%.0f%% DEF" % t.defense_percent_per_type)
		var header := "• %s (%s %s)" % [t.tactic_name, " / ".join(bonus_parts), ", ".join(type_labels)]
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
	lines.append("Nota: el bioma Océano (×0.0) anula todas las tácticas. Nunca las uses en frentes de agua.")
	return {"category": "Cartas", "title": "Cartas tácticas", "body": "\n\n".join(lines)}


func _entry_empire(empire: Resource, ability: Resource, advice: String) -> Dictionary:
	var title: String = "%s — %s" % [_empire_display_name(empire.name), ability.ability_name]
	var body: String = ability.description
	if advice != "":
		body += "\n\n" + advice
	return {"category": "Imperios", "title": title, "body": body}


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

func _prod(gold: int, food: int) -> String:
	var parts: Array[String] = []
	if gold > 0:
		parts.append("+%d oro" % gold)
	elif gold < 0:
		parts.append("−%d oro" % absi(gold))
	if food > 0:
		parts.append("+%d comida" % food)
	elif food < 0:
		parts.append("−%d comida" % absi(food))
	return ", ".join(parts)


func _sgold(gold: int) -> String:
	if gold >= 0:
		return "+%d oro/turno" % gold
	return "−%d oro/turno" % absi(gold)


func _sfood(food: int) -> String:
	if food >= 0:
		return "+%d comida/turno" % food
	return "−%d comida/turno" % absi(food)


func _biome_label(biome: int) -> String:
	match biome:
		0: return "Pradera"
		1: return "Bosque"
		2: return "Desierto"
		3: return "Pantano"
		4: return "Tundra"
		5: return "Océano"
		6: return "Montaña"
		_: return "?"


func _troop_type_label(t: int) -> String:
	match t:
		0: return "Caballería"
		1: return "Tiradores"
		2: return "Milicia"
		3: return "Infantería Pesada"
		4: return "Piqueros"
		_: return "?"


func _empire_display_name(internal_name: String) -> String:
	match internal_name:
		"medici": return "Medici"
		"mongol": return "Mongol"
		"babylonian": return "Babilonia"
		_: return internal_name.capitalize()


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
	header.text = "Tutorial"
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

	footer.add_child(_make_button("Cerrar", _on_close_pressed))

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
