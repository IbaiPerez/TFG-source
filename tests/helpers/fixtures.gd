extends RefCounted
class_name TestFixtures

## Escenarios completos y reutilizables construidos sobre TestBuilders. Encapsulan
## configuraciones habituales (early/mid/late game, imperio con vecina libre…) para
## que los tests no repitan el montaje. Devuelven un Dictionary con las piezas
## nombradas para que el test acceda a lo que necesite.
##
##   var f := TestFixtures.early_expansion()
##   var ctx := f.ctx        # AITurnContext listo
##   var free := f.free_tile # tile colonizable adyacente


## Early game: un imperio con 1 tile propia y 1 vecina libre colonizable.
## Devuelve {stats, ctx, owned_tile, free_tile}.
static func early_expansion() -> Dictionary:
	var stats := TestBuilders.stats().with_turn(2).with_gold(50).with_gpt(30).build()
	var owned := TestBuilders.tile().with_controller(stats.empire).build()
	var free := TestBuilders.tile().build()
	owned.neighbors = [free]
	free.neighbors = [owned]
	stats.empire.controlled_tiles = [owned] as Array[Tile]
	var ctx := TestBuilders.context(stats).with_colonizable(1).build()
	return {"stats": stats, "ctx": ctx, "owned_tile": owned, "free_tile": free}


## Mid game: economía holgada, sin frentes, mapa parcialmente saturado.
## Devuelve {stats, ctx}.
static func mid_economy() -> Dictionary:
	var stats := TestBuilders.stats().with_turn(15).with_gold(800).with_gpt(200) \
		.with_food(30).build()
	var ctx := TestBuilders.context(stats).with_colonizable(3) \
		.with_total_map_tiles(127).build()
	return {"stats": stats, "ctx": ctx}


## Late game: mucho territorio y producción, presión hacia lo militar.
## Devuelve {stats, ctx}.
static func late_dominance() -> Dictionary:
	var tiles: Array = []
	for _i in range(12):
		tiles.append(TestBuilders.tile().build())
	var stats := TestBuilders.stats().with_turn(40).with_gold(5000).with_gpt(600) \
		.with_food(60).with_tiles(tiles).build()
	var ctx := TestBuilders.context(stats).with_colonizable(2) \
		.with_total_map_tiles(127).build()
	return {"stats": stats, "ctx": ctx}
