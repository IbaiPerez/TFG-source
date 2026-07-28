extends RefCounted
class_name WorldMutator

## Puerto de MUTACIÓN del mundo (refactor C6 §1.6.1). Invierte la dependencia de los
## efectos que mutaban tiles directamente por el bus global `Events`. Así los efectos
## dejan de depender del bus y podrán aplicarse sobre el snapshot del MCTS sin
## disparar el estado real del juego (el bloqueo #1 que documenta AIRealEvents).
##
##   - LiveWorldMutator     → emite por `Events` (comportamiento en vivo, byte-idéntico).
##   - SnapshotWorldMutator → aplica sobre AIRealState (pendiente; requiere reconciliar
##                            RNG inyectado y representación TileSnap → [CAMBIA COMPORTAMIENTO]).
##
## La clase base declara el contrato; cada implementación lo sobrescribe.

## Pasa el control de `tile` al imperio `empire`.
func set_controller(_tile, _empire) -> void:
	push_error("WorldMutator.set_controller() sin implementar")

## Cambia el tipo de ubicación de `tile` (p.ej. Town → Megalópolis).
func set_location_type(_tile, _location_type) -> void:
	push_error("WorldMutator.set_location_type() sin implementar")

## Demuele `building` de `tile` (con las stats para la contabilidad).
func demolish(_tile, _building, _stats) -> void:
	push_error("WorldMutator.demolish() sin implementar")
