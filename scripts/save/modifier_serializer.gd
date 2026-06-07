extends RefCounted
class_name ModifierSerializer

## Serializa los Modifier activos de un ModifierManager.
##
## Cada subclase de Modifier (StatModifier, BuildCostModifier, GoldOnCardModifier,
## CardReturnModifier) tiene un constructor distinto, así que serializamos
## campo-a-campo con un discriminador `kind`.
##
## El icono NO se serializa: lo recalcula la propia subclase en `_init`
## a partir de su tipo y signo. Lo mismo para la descripción.


enum Kind {
	UNKNOWN,
	STAT,
	BUILD_COST,
	GOLD_ON_CARD,
	CARD_RETURN,
}


## --- Serialización ------------------------------------------------------

static func serialize_manager(manager:ModifierManager) -> Array:
	var out:Array = []
	if manager == null:
		return out
	for mod in manager.active_modifiers:
		var d := to_dict(mod)
		if not d.is_empty():
			out.append(d)
	return out


static func to_dict(mod:Modifier) -> Dictionary:
	if mod == null:
		return {}
	var d := {
		"kind": _kind_for(mod),
		"id": mod.id,
		"name": mod.name,
		"duration": mod.duration,
	}

	if mod is StatModifier:
		var sm:StatModifier = mod
		d["type"] = int(sm.type)
		d["value"] = sm.value
		d["target_resource"] = sm.target_resource.resource_path if sm.target_resource else ""
		d["troop_type_filter"] = sm.troop_type_filter
	elif mod is BuildCostModifier:
		var bcm:BuildCostModifier = mod
		d["percent"] = bcm.percent
	elif mod is GoldOnCardModifier:
		var gom:GoldOnCardModifier = mod
		d["card_id"] = gom.card_id
		d["gold_amount"] = gom.gold_amount
	elif mod is CardReturnModifier:
		var crm:CardReturnModifier = mod
		d["card_id"] = crm.card_id
		d["chance"] = crm.chance
	else:
		d["kind"] = Kind.UNKNOWN

	return d


## --- Reconstrucción -----------------------------------------------------

## Aplica los modifiers serializados sobre un ModifierManager. Crea las
## instancias correctas según `kind` y las añade respetando el flujo
## normal (`add_modifier` activa señales y enlaza con stats).
static func apply_to_manager(manager:ModifierManager, data:Array, stats:Stats) -> void:
	for entry in data:
		var mod := from_dict(entry)
		if mod != null:
			manager.add_modifier(mod, stats)


static func from_dict(data:Dictionary) -> Modifier:
	if data.is_empty():
		return null

	var kind:int = int(data.get("kind", Kind.UNKNOWN))
	var id:String = data.get("id", "")
	var name:String = data.get("name", "")
	var duration:int = int(data.get("duration", -1))

	match kind:
		Kind.STAT:
			var type:int = int(data.get("type", 0))
			var value:float = float(data.get("value", 0.0))
			var target_path:String = data.get("target_resource", "")
			var target:NaturalResource = null
			if target_path != "" and ResourceLoader.exists(target_path):
				target = load(target_path) as NaturalResource
			var ttf:int = int(data.get("troop_type_filter", -1))
			return StatModifier.new(id, name, type, value, duration, null, target, ttf)
		Kind.BUILD_COST:
			var percent:float = float(data.get("percent", 0.0))
			return BuildCostModifier.new(id, name, percent, duration, null)
		Kind.GOLD_ON_CARD:
			var card_id:String = data.get("card_id", "")
			var gold_amount:int = int(data.get("gold_amount", 0))
			return GoldOnCardModifier.new(id, name, card_id, gold_amount, duration, null)
		Kind.CARD_RETURN:
			var card_id_b:String = data.get("card_id", "")
			var chance:float = float(data.get("chance", 0.0))
			return CardReturnModifier.new(id, name, card_id_b, chance, duration, null)
		_:
			# `print` y no `push_warning`: este caso aparece cuando un save
			# antiguo trae un kind retirado o cuando los tests verifican
			# explícitamente el manejo de un kind desconocido.
			GameLogger.warn("[ModifierSerializer] kind desconocido: %d" % kind)
			return null


## --- Helpers ------------------------------------------------------------

static func _kind_for(mod:Modifier) -> int:
	if mod is StatModifier:
		return Kind.STAT
	if mod is BuildCostModifier:
		return Kind.BUILD_COST
	if mod is GoldOnCardModifier:
		return Kind.GOLD_ON_CARD
	if mod is CardReturnModifier:
		return Kind.CARD_RETURN
	return Kind.UNKNOWN
