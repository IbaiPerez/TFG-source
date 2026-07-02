extends RefCounted
class_name MapScenePaths

## Rutas y nombres de nodo internos de la escena Map (scenes/world_generation/map.tscn),
## relativos a su raíz.
##
## Centralizados aquí porque antes vivían como literales de cadena dispersos por
## `map.gd` y `GameStateSerializer`: un rename de nodo en el .tscn obligaba a
## cazar cada literal a mano y un typo fallaba en silencio en runtime
## (`get_node_or_null(...)` → null). Con estas constantes, creación y lookup
## comparten una única fuente de verdad.

# Contenedores directos bajo la raíz Map.
const SCENE := "Scene"
const NODE := "Node"

# Nodos persistentes definidos en el .tscn, por ruta relativa a la raíz.
const TILE_PARENT := "Scene/TileParent"
const UI_LAYER := "Scene/UI_layer"
const WORLD_GENERATOR := "Node/WorldGenerator"
const PLAYER_HANDLER := "Node/PlayerHandler"
const AI_CONTROLLER := "Node/AIController"

# Nodos creados en runtime como hijos directos de la raíz Map: su ruta coincide
# con su `name`. Se usan tanto al crearlos (`.name = ...`) como al buscarlos.
const TURN_MANAGER := "TurnManager"
const EVENT_TILE_SELECTOR := "EventTileSelector"
const AI_ACTION_FEEDBACK := "AIActionFeedback"

# Nombre hoja (leaf) del PlayerHandler creado bajo el contenedor NODE.
const PLAYER_HANDLER_NAME := "PlayerHandler"
