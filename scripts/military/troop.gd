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
	match type:
		TroopType.CABALLERIA: return "Caballería"
		TroopType.A_DISTANCIA: return "A Distancia"
		TroopType.INFANTERIA_LIGERA: return "Infantería Ligera"
		TroopType.INFANTERIA_PESADA: return "Infantería Pesada"
		TroopType.PIQUEROS: return "Piqueros"
		_: return "?"


## Helper estático: devuelve la etiqueta legible de un valor del enum.
static func type_label_for(t: int) -> String:
	match t:
		TroopType.CABALLERIA: return "Caballería"
		TroopType.A_DISTANCIA: return "A Distancia"
		TroopType.INFANTERIA_LIGERA: return "Infantería Ligera"
		TroopType.INFANTERIA_PESADA: return "Infantería Pesada"
		TroopType.PIQUEROS: return "Piqueros"
		_: return "?"
