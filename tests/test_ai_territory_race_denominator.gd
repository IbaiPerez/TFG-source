extends GutTest

## `territory_race_factor` amplifica colonizar y abrir frente según cómo va la
## carrera territorial. Normalizaba la cuota propia contra **propias + rival +
## colonizables**, donde «colonizables» son solo las casillas libres ADYACENTES a las
## propias. Eso tenía una consecuencia perversa y demostrable:
##
##   Como `colonizables ≤ libres_del_mapa`, el denominador es siempre ≤ el mapa, así
##   que la cuota calculada es siempre ≥ la cuota real. No hay falsos negativos —si
##   de verdad estás cerca del 70 %, dispara— pero sí falsos POSITIVOS, y el más
##   frecuente es justo el contrario de lo que el factor dice medir: **quedarse
##   encajonado encoge el denominador y sube la cuota**, disparando el «modo cierre».
##
##   Dos imperios con 20 casillas propias y 10 rivales: el que tiene 25 libres
##   alrededor daba neutro y el que tiene 3 daba ×2.0. Mismo territorio, misma
##   partida, y el que peor lo tiene recibía el doble de incentivo — por una vía
##   llamada «me estoy acercando a ganar».
##
##   Además el encierro YA tiene su propio factor (`encirclement_pressure`, hasta
##   ×6.17 con los pesos del campeón), así que se contaba dos veces.
##
## Ahora la cuota se normaliza contra el MAPA, que es lo que su comentario decía y lo
## que se copiaría a la memoria del TFG, y es coherente con `AIGamePhase` y
## `state_victory_share`, que ya derivan del mapa y de GameBalance.
##
## La rama `economy` se elimina: no tenía ningún llamante de producción.


const MAPA := 127


func _w() -> HeuristicWeights:
	return HeuristicWeights.new()


## Estado con `propias` casillas propias, `rivales` del rival y `libres` casillas
## libres ADYACENTES a las propias. `total_map_tiles` es siempre el mapa entero, así
## que lo único que varía entre escenarios es cuánto sitio queda alrededor.
func _estado(propias: int, rivales: int, libres: int) -> AIRealState:
	var s := AIRealState.new()
	s.total_map_tiles = MAPA
	var vecinos: Array[int] = []
	for k in range(libres):
		var libre := AIRealState.TileSnap.new()
		libre.id = 200 + k
		libre.owner = AIRealState.OWNER_NONE
		s.tiles[libre.id] = libre
		vecinos.append(libre.id)
	for i in range(propias):
		var t := AIRealState.TileSnap.new()
		t.id = i
		t.owner = AIRealState.OWNER_SELF
		# Solo la primera linda con el espacio libre: basta para que el conteo de
		# colonizables las vea todas, sin duplicarlas.
		t.neighbor_ids = vecinos if i == 0 else ([] as Array[int])
		s.tiles[i] = t
	for j in range(rivales):
		var r := AIRealState.TileSnap.new()
		r.id = 100 + j
		r.owner = AIRealState.OWNER_RIVAL
		s.tiles[r.id] = r
	return s


func _factor(propias: int, rivales: int, libres: int,
		mode := &"colonize") -> float:
	return AISnapshotFacts._territory_race_factor(
		_estado(propias, rivales, libres), AIRealState.OWNER_SELF, mode, _w())


# ---------------------------------------------------------------------------
# El defecto principal: el encierro no debe disparar el «modo cierre»
# ---------------------------------------------------------------------------

func test_quedarse_sin_sitio_no_puede_parecer_estar_ganando() -> void:
	# EL test que discrimina. Mismo territorio y mismo rival; solo cambia el margen
	# para crecer. Antes: 0.364 (neutro) frente a 0.606 (CIERRE ×2.0).
	assert_almost_eq(_factor(20, 10, 3), _factor(20, 10, 25), 0.001,
		"el margen para expandirse no debe cambiar la lectura de la carrera")


func test_con_poco_territorio_no_hay_modo_cierre_aunque_no_quede_sitio() -> void:
	var w := _w()
	# 20 de 127 casillas es el 16 % del mapa: muy lejos de la victoria por dominación.
	assert_almost_eq(_factor(20, 10, 3), 1.0, 0.001,
		"con el 16 %% del mapa no se está cerrando la partida, se esté encajonado o no")
	assert_lt(20.0 / float(MAPA), w.tr_close_share,
		"precondición: ese territorio está por debajo del umbral de cierre")


# ---------------------------------------------------------------------------
# Lo que sí debe seguir disparando
# ---------------------------------------------------------------------------

func test_acercarse_de_verdad_a_la_victoria_amplifica() -> void:
	var w := _w()
	# Territorio derivado del UMBRAL, no elegido a mano.
	var propias := int(MAPA * w.tr_lead_share) + 1
	assert_gt(_factor(propias, 10, 10), 1.0,
		"con cuota de liderazgo real sobre el mapa sí debe amplificar")


func test_el_rival_cerca_de_su_victoria_activa_el_bloqueo() -> void:
	var w := _w()
	var rivales := int(MAPA * w.tr_block_share) + 1
	assert_almost_eq(_factor(10, rivales, 10), w.tr_block_factor, 0.001,
		"si el rival se acerca a su límite, bloquear vale tanto como avanzar")


func test_abrir_frente_y_colonizar_comparten_la_regla() -> void:
	var w := _w()
	var propias := int(MAPA * w.tr_lead_share) + 1
	assert_eq(_factor(propias, 10, 10, &"colonize"),
		_factor(propias, 10, 10, &"open_front"),
		"ganar territorio es ganar territorio, se haga como se haga")


# ---------------------------------------------------------------------------
# La rama muerta
# ---------------------------------------------------------------------------

func test_el_modo_economy_ya_no_existe_y_es_neutro() -> void:
	# No tenía ningún llamante de producción, y su peso era una dimensión del
	# optimizador sobre la que el fitness es plano: SA/GA la movía por paseo
	# aleatorio (el campeón dejó tr_econ_factor en 0.588 sin efecto alguno).
	var w := _w()
	var propias := int(MAPA * w.tr_close_share) + 1
	assert_almost_eq(_factor(propias, 10, 10, &"economy"), 1.0, 0.001,
		"un modo sin llamante debe ser neutro, no aplicar un peso fantasma")


func test_un_modo_desconocido_nunca_amplifica() -> void:
	var w := _w()
	var propias := int(MAPA * w.tr_close_share) + 1
	assert_almost_eq(_factor(propias, 10, 10, &"modo_inventado"), 1.0, 0.001,
		"guarda: un modo que no existe no debe amplificar por accidente")


# ---------------------------------------------------------------------------
# Sin información del mapa
# ---------------------------------------------------------------------------

func test_sin_conteo_de_mapa_el_factor_es_neutro() -> void:
	# `total_map_tiles == 0` es el caso de los tests sin mapa. Sin saber el tamaño
	# no se puede juzgar la carrera: no amplificar es lo seguro.
	var s := _estado(20, 10, 5)
	s.total_map_tiles = 0
	assert_almost_eq(AISnapshotFacts._territory_race_factor(
		s, AIRealState.OWNER_SELF, &"colonize", _w()), 1.0, 0.001,
		"sin información del mapa no se amplifica nada")
