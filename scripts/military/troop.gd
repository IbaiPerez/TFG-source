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
