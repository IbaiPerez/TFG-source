extends AIDecisionPolicy
class_name ManualPolicy

## Política de decisión GUIONIZADA: en vez de elegir por heurística o por MCTS,
## reproduce una lista de decisiones tomadas desde fuera. Sirve para que un
## agente externo —una persona, o Claude— juegue un bando contra la IA sin
## tocar el bucle de turno, que sigue siendo el del juego real.
##
## CÓMO FUNCIONA EL PROTOCOLO. No hay estado persistente entre invocaciones: la
## partida es determinista con semilla fija, así que cada vez se REJUEGA entera
## desde el principio aplicando el guion, que crece de una decisión por vuelta.
## Cuando el guion se agota, la política:
##   1. captura el estado y las opciones legales de ese instante, y
##   2. pasa turno el resto de la partida (da igual: solo se lee la captura).
## Quien juega lee la captura, añade su decisión al guion y vuelve a lanzar.
##
## El guion es una lista de enteros: índice dentro de las opciones enumeradas en
## ese momento, o -1 para pasar. Los índices son estables dentro de una misma
## repetición porque la enumeración es determinista, y APPEND-ONLY: añadir al
## final no altera ninguna decisión anterior.

var guion: Array = []                ## decisiones ya tomadas (int; -1 = pasar)
var cursor: int = 0                  ## cuántas se han consumido
var captura: Dictionary = {}         ## estado + opciones del primer punto sin decidir


func pick_best(options: Array[AIPlayOption], ctx: AITurnContext) -> AIPlayOption:
	if cursor < guion.size():
		var idx: int = int(guion[cursor])
		cursor += 1
		if idx < 0 or idx >= options.size():
			return AIPlayOption.create_pass()
		return options[idx]

	if captura.is_empty():
		captura = _capturar(options, ctx)
	return AIPlayOption.create_pass()


## Todo lo que quien juega necesita para decidir. Deliberadamente NO incluye el
## score heurístico de cada opción: con él, jugar sería copiar a la IA en vez de
## medirse con ella.
func _capturar(options: Array[AIPlayOption], ctx: AITurnContext) -> Dictionary:
	var st := ctx.stats
	var emp := st.empire
	var rival := _rival_de(emp)
	var opciones: Array = []
	for i in range(options.size()):
		opciones.append({"i": i, "que": options[i].describe(),
			"donde": _donde(options[i], emp)})
	opciones.append({"i": -1, "que": "PASAR (cerrar el turno)", "donde": ""})

	return {
		"turno": st.turn_number,
		"decision_n": cursor,
		"yo": {
			"oro": st.total_gold,
			"oro_por_turno": st.gold_per_turn,
			"comida": st.food,
			"casillas": emp.controlled_tiles.size() if emp != null else 0,
			"combat_multiplier": emp.combat_multiplier if emp != null else 1.0,
		},
		"rival": {
			"casillas": rival.controlled_tiles.size() if rival != null else 0,
		},
		"mapa": {
			"total": ctx.total_map_tiles,
			"colonizables": ctx.colonizable_tiles_count,
			"para_dominar": int(ceil(0.7 * float(ctx.total_map_tiles))),
		},
		"mis_casillas": _mis_casillas(emp),
		"mano": _mano(ctx),
		"frentes": _frentes(ctx),
		"opciones": opciones,
	}


## `describe()` dice el TIPO de jugada pero no sobre qué casilla, y con doce
## "Colonize" indistinguibles no se puede decidir. Esto añade lo que un jugador
## vería mirando el mapa: dónde cae, qué produce y si toca al rival.
func _donde(op: AIPlayOption, emp) -> String:
	var t: Tile = op.anchor_tile()
	if t == null:
		return ""
	var partes: Array[String] = []
	partes.append(t.province_name if t.province_name != "" else "(sin nombre)")
	partes.append(t.biome)
	if t.natural_resource != null:
		partes.append("rec:%s" % t.natural_resource.name)
	partes.append("oro %+d / com %+d" % [t.gold_production, t.food_production])
	if t.location != null:
		partes.append(Tile.location_type.keys()[t.location.type])
	if _toca_al_rival(t, emp):
		partes.append("LINDA CON EL RIVAL")
	return " · ".join(partes)


func _toca_al_rival(t: Tile, emp) -> bool:
	for n in t.neighbors:
		if n != null and n.controller != null and n.controller != emp:
			return true
	return false


## Lo que ya controlo, con su produccion: sin esto no se puede juzgar si una
## colonizacion aporta o solo suma casillas.
func _mis_casillas(emp) -> Array:
	var out: Array = []
	if emp == null:
		return out
	for t in emp.controlled_tiles:
		if t == null:
			continue
		out.append("%s (oro %+d / com %+d)" % [
			t.province_name, t.gold_production, t.food_production])
	return out


func _mano(ctx: AITurnContext) -> Array:
	var out: Array = []
	for c in ctx.drawn_cards:
		out.append(c.get_display_name() if c != null else "?")
	return out


func _frentes(ctx: AITurnContext) -> Array:
	var out: Array = []
	if ctx.battle_front_manager == null:
		return out
	for f in BattleFront.get_active_instances():
		if f == null:
			continue
		out.append({
			"marcador": f.marker,
			"umbral": f.get_current_threshold(),
			"turnos": f.turns_elapsed,
		})
	return out


func _rival_de(emp) -> Variant:
	if emp == null:
		return null
	for e in get_tree_empires():
		if e != emp:
			return e
	return null


## Los imperios vivos, leídos del registro de casillas del mundo. El arnés no
## expone el rival directamente y la política no debe conocer al arnés.
func get_tree_empires() -> Array:
	var vistos: Array = []
	for t in WorldMap.map:
		if t == null or t.controller == null:
			continue
		if not vistos.has(t.controller):
			vistos.append(t.controller)
	return vistos
