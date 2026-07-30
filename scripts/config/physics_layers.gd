extends RefCounted
class_name PhysicsLayers

## Capas de física 3D, con nombre. Deben coincidir con los nombres declarados en
## project.godot (`3d_physics/layer_N`).
##
## Antes estos valores estaban escritos como literales sueltos (`collision_mask = 4`)
## con un comentario que traducía el número a mano en cada sitio; renumerar una capa
## en los ajustes del proyecto no habría dado ningún aviso.
##
## OJO: las capas 2D son un espacio de nombres DISTINTO (Tiles/DropArea/Cards) y las
## usan las escenas de carta (`card_ui.tscn`) directamente, no el código.

## Layer 1 — casillas del mapa (cuerpos físicos).
const TILES: int = 1 << 0
## Layer 2 — área de apuntado de las cartas.
const CARD_TARGET_SELECTOR: int = 1 << 1
## Layer 3 — áreas de los frentes de batalla (BattleFrontVisual).
const BATTLE_FRONT: int = 1 << 2
