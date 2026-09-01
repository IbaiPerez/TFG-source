extends RefCounted
class_name GameBalance

## Constantes de REGLAS del juego, centralizadas en un único sitio.
##
## Antes cada una de estas magnitudes estaba duplicada como literal en 2-3
## ficheros (el motor de combate y su espejo para la IA, la detección de fase en
## AIGamePhase y en AIRealEval, la condición de victoria en TurnManager y en la
## evaluación de la IA…). Un cambio de balance obligaba a editar varios sitios y
## arriesgaba desincronizarlos.
##
## OJO: aquí van solo REGLAS del juego (lo que define cómo se juega). Los PESOS de
## la heurística de la IA (cuánto valora la IA cada cosa) viven en HeuristicWeights
## y son ajustables por el optimizador; no deben mezclarse con esto.


# ---------------------------------------------------------------------------
# Frentes de batalla
# ---------------------------------------------------------------------------

## Umbral inicial del marcador de un frente (BattleFront.threshold por defecto).
const FRONT_INITIAL_THRESHOLD: float = 10.0
## Umbral mínimo al que decae el frente (suelo del decaimiento).
const FRONT_MIN_THRESHOLD: float = 5.0
## Turnos en los que el umbral decae de INITIAL a MIN de forma lineal.
const FRONT_THRESHOLD_DECAY_TURNS: int = 10
## Turnos mínimos antes de que un frente pueda resolverse.
const FRONT_MIN_DURATION: int = 3
## Crecimiento del coste de guarnecer un frente. La n-ésima tropa de un bando paga
## SU PROPIO mantenimiento base multiplicado por `GROWTH^(n-1)`, con una base de
## crecimiento distinta para cada recurso.
##
## La tropa asignada NO deja de pagar su coste base —para eso es base—: lo que hace
## el frente es encarecerlo. Por eso la primera tropa tiene coste marginal CERO en
## ambos recursos y a partir de ahí crece de forma convexa.
##
## Los dos crecimientos son DISTINTOS a propósito, y eso es lo que decide qué recurso
## limita el tamaño de una guarnición:
##
##   · ORO (1.5): cruza el crecimiento lineal en la quinta tropa. Hasta cuatro sale
##     barato apilar; a partir de cinco, caro.
##   · COMIDA (2.5): cruza el lineal ya en la SEGUNDA. Tres tropas de una milicia
##     cuestan ~9.8 de comida frente a las ~4.8 que costarían con la curva del oro.
##
## Con esto la comida es el cuello de botella real de las guarniciones grandes —los
## ingresos de comida están en las decenas— mientras el oro deja margen para
## guarniciones medianas. Antes ambos recursos escalaban igual y ataba el oro, porque
## los mantenimientos base de oro son un orden de magnitud mayores.
##
## Antes de todo esto era un recargo PLANO —(i+1)·5 de oro y comida, igual para toda
## tropa— y el mantenimiento base desaparecía al asignar, con dos efectos indeseados:
## guarnecer una milicia costaba lo mismo que guarnecer infantería pesada, y meter la
## primera tropa en un frente AHORRABA oro.
const FRONT_UPKEEP_GROWTH_GOLD: float = 1.5
const FRONT_UPKEEP_GROWTH_FOOD: float = 2.5

## Frentes simultáneos máximos = MAX_FRONTS_BASE + tiles / TILES_PER_EXTRA_FRONT.
const MAX_FRONTS_BASE: int = 1
const TILES_PER_EXTRA_FRONT: int = 5


# ---------------------------------------------------------------------------
# Condición de victoria
# ---------------------------------------------------------------------------

## Fracción de casillas del mapa que da la victoria por dominación.
const VICTORY_TILE_SHARE: float = 0.70


# ---------------------------------------------------------------------------
# Pool de cartas desbloqueadas
# ---------------------------------------------------------------------------

## Curva de peso con la que una carta TÁCTICA recién desbloqueada aparece en el
## pool: empieza en BASE y decae PER_TURN por turno hasta el suelo MIN, de modo
## que la carta se ofrece mucho justo tras desbloquearla y luego se diluye entre
## el resto del pool. La comparten los cinco eventos `unlock_*` de carta táctica,
## que antes repetían la terna como literal.
##
## No es "la" curva de pool: `construction_boom` usa una propia (10 / −0.2 / 3),
## deliberadamente más agresiva. Si aparece una tercera familia con curva propia,
## darle su terna con nombre aquí en vez de reutilizar esta.
const TACTIC_POOL_WEIGHT_BASE: float = 5.0
const TACTIC_POOL_WEIGHT_PER_TURN: float = -0.1
const TACTIC_POOL_WEIGHT_MIN: float = 1.5


# ---------------------------------------------------------------------------
# Mapa de referencia
# ---------------------------------------------------------------------------

## Tamaño del mapa de referencia (r=6 ≈ 127 tiles). Lo usa la IA para escalar con
## el tamaño real del mapa el umbral de GPT con el que considera la partida
## avanzada: late_gpt = w.phase_late_gpt · total / DEFAULT_MAP_TILE_COUNT.
##
## Esto SÍ es una regla —describe el mapa, no una preferencia de la IA—, así que se
## queda aquí. Los umbrales de fase en cambio se fueron a HeuristicWeights: la fase
## de partida es una lectura que solo hace la IA, ninguna regla del juego depende de
## ella, y el optimizador debe poder mover dónde están las fronteras.
const DEFAULT_MAP_TILE_COUNT: int = 127
