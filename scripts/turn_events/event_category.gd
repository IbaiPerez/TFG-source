extends RefCounted
class_name EventCategory

## Categorías de TurnEvent. Se usan para agrupar eventos por intención
## mecánica y permitir que TurnEventManager controle la probabilidad de
## aparición a nivel de grupo (no solo por evento).
##
## - CORE_PROGRESSION:     desbloqueos de mecánicas críticas para el avance
##                         del juego (Construir, Reclutar, Abrir Frente,
##                         Urbanizar, Mejorar). Disparo prioritario.
## - OPTIONAL_PROGRESSION: desbloqueos importantes pero no obligatorios
##                         (edificios de bioma, lategame, cartas tácticas).
## - FLAVOUR:              modificadores temporales repetibles, intercambios
##                         y eventos de "color".
## - DECK:                 gestión del mazo (añadir/eliminar cartas).
## - SHOP:                 eventos de tienda (ver scripts/shop/).
## - SPIRIT:               eventos atados a santuarios. Pool propia.
## - DECISION:             decisiones narrativas de gran peso (Megalópolis).

enum Type {
	CORE_PROGRESSION,
	OPTIONAL_PROGRESSION,
	FLAVOUR,
	DECK,
	SHOP,
	SPIRIT,
	DECISION,
}

