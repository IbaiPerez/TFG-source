extends GutTest

## Efectos de carta que no tenían test directo (refactor §4.7).
##
## Medido: de los 6 scripts de `scripts/effects/`, solo BuildEffect y
## GenerateGoldEffect estaban cubiertos (en test_conditions_effects). Colonize,
## UpgradeBuilding y ChangeLocationType —que son reglas de carta que el jugador
## dispara cada partida— no los tocaba ningún test, y DrawCard solo aparecía
## nombrado en un comentario.
##
## Colonize y ChangeLocationType no mutan la casilla: EMITEN por el bus y es
## TilesTracker quien aplica el cambio. Por eso aquí se observa la señal, que es
## el contrato real del efecto.


var stats: Stats


func before_each() -> void:
	stats = TestBuilders.stats().with_gold(500).build()
	watch_signals(Events)


func after_each() -> void:
	TestWorld.reset()


func _tile() -> Tile:
	var t := TestBuilders.tile().build()
	add_child_autofree(t)
	return t


# ---------------------------------------------------------------------------
# ColonizeEffect
# ---------------------------------------------------------------------------

func test_colonize_pide_el_cambio_de_propietario() -> void:
	var tile := _tile()
	var effect := ColonizeEffect.new()
	effect.controller = stats.empire

	effect.execute([tile] as Array[Node])

	assert_signal_emitted_with_parameters(Events, "change_tile_controller",
		[tile, stats.empire])


func test_colonize_sin_imperio_no_hace_nada() -> void:
	# Guarda deliberada del efecto: sin controller no hay a quién dar la casilla.
	var effect := ColonizeEffect.new()
	effect.execute([_tile()] as Array[Node])
	assert_signal_not_emitted(Events, "change_tile_controller")


func test_colonize_ignora_objetivos_que_no_son_casilla() -> void:
	var effect := ColonizeEffect.new()
	effect.controller = stats.empire
	var no_casilla := Node.new()
	add_child_autofree(no_casilla)

	effect.execute([no_casilla] as Array[Node])

	assert_signal_not_emitted(Events, "change_tile_controller")


# ---------------------------------------------------------------------------
# UpgradeBuildingEffect
# ---------------------------------------------------------------------------

func test_upgrade_sustituye_el_edificio_y_cobra() -> void:
	var viejo := TestBuilders.building().with_name("Mina").with_cost(50).with_gold(3).build()
	var nuevo := TestBuilders.building().with_name("Casa de Moneda").with_cost(80) \
		.with_gold(9).build()
	viejo.upgrades_to = [nuevo] as Array[Building]

	var tile := _tile()
	tile.buildings.append(viejo)

	var effect := UpgradeBuildingEffect.new()
	effect.old_building = viejo
	effect.new_building = nuevo
	effect.stats = stats
	var oro_antes := stats.total_gold

	effect.execute([tile] as Array[Node])

	assert_eq(tile.buildings.size(), 1, "la mejora sustituye, no acumula")
	assert_eq(tile.buildings[0].name, "Casa de Moneda")
	TestAssertions.assert_gold_delta(self, stats, oro_antes,
		-nuevo.get_effective_construction_cost(stats), "cobra el coste del nuevo")


func test_upgrade_sin_edificio_nuevo_no_hace_nada() -> void:
	var viejo := TestBuilders.building().with_name("Mina").build()
	var tile := _tile()
	tile.buildings.append(viejo)

	var effect := UpgradeBuildingEffect.new()
	effect.old_building = viejo
	effect.stats = stats
	var oro_antes := stats.total_gold

	effect.execute([tile] as Array[Node])

	assert_eq(tile.buildings[0].name, "Mina", "la casilla no cambia")
	assert_eq(stats.total_gold, oro_antes, "y no se cobra nada")


# ---------------------------------------------------------------------------
# ChangeLocationTypeEffect
# ---------------------------------------------------------------------------

func test_change_location_pide_el_cambio_de_nivel() -> void:
	var destino := LocationType.new()
	destino.type = Tile.location_type.Town
	destino.max_building = 3

	var effect := ChangeLocationTypeEffect.new()
	effect.location_type = destino
	effect.stats = stats

	var tile := _tile()
	effect.execute([tile] as Array[Node])

	assert_signal_emitted_with_parameters(Events, "change_tile_location_type",
		[tile, destino])


## La regla que solo vive en este efecto: urbanizar DEMUELE los edificios que el
## nivel nuevo ya no admite (p. ej. los exclusivos de Aldea al pasar a Ciudad).
func test_urbanizar_demuele_lo_que_el_nuevo_nivel_no_admite() -> void:
	var solo_aldea := LocationType.new()
	solo_aldea.type = Tile.location_type.Village

	var santuario := TestBuilders.building().with_name("Santuario") \
		.with_allowed_locations([solo_aldea]).build()
	var mina := TestBuilders.building().with_name("Mina").build()   # sin restriccion

	var tile := _tile()
	tile.buildings.append(santuario)
	tile.buildings.append(mina)

	var destino := LocationType.new()
	destino.type = Tile.location_type.Town
	var effect := ChangeLocationTypeEffect.new()
	effect.location_type = destino
	effect.stats = stats

	effect.execute([tile] as Array[Node])

	var nombres: Array[String] = []
	for b in tile.buildings:
		nombres.append(b.name)
	assert_false(nombres.has("Santuario"), "el exclusivo de Aldea debe demolerse")
	assert_true(nombres.has("Mina"), "el que no restringe nivel se queda")


func test_change_location_sin_destino_no_hace_nada() -> void:
	var effect := ChangeLocationTypeEffect.new()
	effect.stats = stats
	effect.execute([_tile()] as Array[Node])
	assert_signal_not_emitted(Events, "change_tile_location_type")


# ---------------------------------------------------------------------------
# DrawCardEffect
# ---------------------------------------------------------------------------

func test_draw_card_sin_objetivos_no_rompe() -> void:
	# Sale por la guarda antes de tocar el arbol. Es el camino que corre en
	# headless, donde no hay PlayerHandler.
	var effect := DrawCardEffect.new()
	effect.execute([] as Array[Node])
	pass_test("sin objetivos no debe crashear")


func test_draw_card_sin_player_handler_no_rompe() -> void:
	# El efecto busca el PlayerHandler por grupo y se retira si no lo encuentra.
	# La suite corre sin escena de partida, asi que este es el caso normal aqui.
	var nodo := Node.new()
	add_child_autofree(nodo)
	var effect := DrawCardEffect.new()
	effect.execute([nodo] as Array[Node])
	pass_test("sin PlayerHandler debe retirarse en silencio")
