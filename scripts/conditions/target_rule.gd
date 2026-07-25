extends RefCounted
class_name TargetRule

## Regla de SELECCIÓN DE OBJETIVOS para las cartas: dada la situación del juego,
## enumera los nodos (tiles, frentes…) sobre los que una carta puede jugarse
## (`valid_targets`) y valida un objetivo concreto (`is_valid_target`).
##
## NO confundir con TurnEventCondition (scripts/turn_events/conditions/): aquella
## es una GUARDA BOOLEANA (`is_met`) que decide si un evento de turno puede
## dispararse. Jerarquías distintas y con propósitos distintos; antes esta clase
## base se llamaba `Condition`, lo que la confundía con TurnEventCondition.
##
## Subclases: AdjacentRule, BuildRule, ChangeLocationTypeRule, EnemyAdjacentRule,
## UpgradeBuildingRule.


func valid_targets() -> Array[Node]:
	return []

func is_valid_target(_target:Node) -> bool:
	return false
