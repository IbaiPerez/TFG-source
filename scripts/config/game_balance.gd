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
## Recargo progresivo de oro Y comida por la n-ésima tropa asignada a un frente:
## la tropa i (0-based) cuesta (i + 1) · este valor por turno.
const FRONT_SURCHARGE_PER_TROOP: int = 5

## Frentes simultáneos máximos = MAX_FRONTS_BASE + tiles / TILES_PER_EXTRA_FRONT.
const MAX_FRONTS_BASE: int = 1
const TILES_PER_EXTRA_FRONT: int = 5


# ---------------------------------------------------------------------------
# Condición de victoria
# ---------------------------------------------------------------------------

## Fracción de casillas del mapa que da la victoria por dominación.
const VICTORY_TILE_SHARE: float = 0.70


# ---------------------------------------------------------------------------
# Detección de fase de partida (AIGamePhase.detect / AIRealEval.detect_phase)
# ---------------------------------------------------------------------------

## Tamaño del mapa de referencia (r=6 ≈ 127 tiles). Escala el umbral GPT de LATE
## con el tamaño real del mapa: late_gpt = PHASE_LATE_GPT · total / DEFAULT_MAP_TILE_COUNT.
const DEFAULT_MAP_TILE_COUNT: int = 127

## LATE si se controla ≥ esta fracción del mapa.
const PHASE_LATE_SHARE: float = 0.30
## EARLY solo si se controla < esta fracción del mapa (y economía inicial).
const PHASE_EARLY_SHARE: float = 0.08
## Umbral de GPT para EARLY (por debajo, con poco territorio, es fase inicial).
const PHASE_EARLY_GPT: int = 100
## Umbral de GPT para LATE al tamaño de mapa de referencia. También es el umbral
## LATE del fallback legacy sin info de mapa.
const PHASE_LATE_GPT: int = 350
## Fallback legacy (sin info de mapa): LATE con ≥ estas tiles.
const PHASE_LATE_TILES_LEGACY: int = 30
## Fallback legacy: EARLY con < estas tiles.
const PHASE_EARLY_TILES_LEGACY: int = 12
