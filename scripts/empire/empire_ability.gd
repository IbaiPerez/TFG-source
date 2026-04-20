extends Resource
class_name EmpireAbility

@export var id:String
@export var ability_name:String
@export_multiline var description:String
@export var icon:Texture2D

## Edificios que solo este imperio puede construir
@export var exclusive_buildings:Array[Building] = []


## Devuelve los modificadores permanentes de esta habilidad.
## Cada subclase sobreescribe este metodo para crear sus propios modificadores.
func create_modifiers() -> Array[Modifier]:
	return []
