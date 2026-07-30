extends Resource
class_name Troop


## Tipos de tropa para el sistema de efectividad estilo piedra-papel-tijera.
## Independientes del nombre cosmético: dos tropas con stats distintos pueden
## compartir tipo y por tanto compartir matchups en TroopEffectiveness.
enum TroopType {
	CABALLERIA,
	A_DISTANCIA,
	INFANTERIA_LIGERA,
	INFANTERIA_PESADA,
	PIQUEROS,
}


@export var name: String
@export var icon: Texture2D
@export var type: TroopType = TroopType.INFANTERIA_LIGERA
@export var attack: int
@export var defense: int
@export var recruitment_cost_gold: int
@export var maintenance_gold: int
@export var maintenance_food: int


## Si se puede reclutar esta tropa con los recursos dados. Tres condiciones:
##
##   1. Hay oro suficiente para pagar `recruitment_cost_gold` (coste one-shot).
##   2. La producción de oro (`gold_per_turn`, que ya incluye el mantenimiento de
##      las tropas existentes) absorbe el mantenimiento de la nueva sin caer en
##      negativo.
##   3. Ídem con la producción de comida.
##
## Las condiciones 2 y 3 son un freno duro: si no puedes mantenerla, no la puedes
## reclutar. Evitan que jugador o IA sigan reclutando ya en déficit, lo que además
## debilita a las tropas existentes vía el multiplicador económico.
##
## Toma primitivas, no `Stats`, porque la regla la comparten los DOS mundos: el
## vivo entra por `Stats.can_afford_troop` y el snapshot del MCTS por `AILegality`,
## que antes la reimplementaba entera como espejo.
func is_affordable(gold: int, gold_per_turn: int, food: int) -> bool:
	if gold < recruitment_cost_gold:
		return false
	if gold_per_turn - maintenance_gold < 0:
		return false
	if food - maintenance_food < 0:
		return false
	return true


## Devuelve el nombre legible del tipo (para tooltips, debug, UI).
func get_type_label() -> String:
	return type_label_for(type)


## Helper estático: devuelve la etiqueta legible de un valor del enum.
static func type_label_for(t: int) -> String:
	match t:
		TroopType.CABALLERIA: return TranslationServer.translate("TROOP_TYPE_CABALLERIA")
		TroopType.A_DISTANCIA: return TranslationServer.translate("TROOP_TYPE_A_DISTANCIA")
		TroopType.INFANTERIA_LIGERA: return TranslationServer.translate("TROOP_TYPE_INFANTERIA_LIGERA")
		TroopType.INFANTERIA_PESADA: return TranslationServer.translate("TROOP_TYPE_INFANTERIA_PESADA")
		TroopType.PIQUEROS: return TranslationServer.translate("TROOP_TYPE_PIQUEROS")
		_: return "?"
