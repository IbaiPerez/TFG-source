extends GutTest

## Cubre [ShopItemView], el artículo de tienda que sustituye al contenedor genérico
## del que el panel extraía cosas con `set_meta` y `child is Button`.
##
## Lo que se fija es el repintado: tras cualquier compra o purga el panel llama a
## `refresh` sobre TODOS los artículos, porque gastar oro puede dejar sin fondos a
## los demás.


func _item(price: int, stock: int = 1) -> ShopItem:
	var item := ShopItem.new()
	item.card = load("res://resources/cards/colonize_card.tres") as Card
	item.price = price
	item.stock = stock
	return item


func _view(item: ShopItem) -> ShopItemView:
	var view := ShopItemView.new()
	add_child_autofree(view)
	# `tooltip_requested(card)` es de un solo argumento: conectarle un Callable de
	# otra aridad es error de motor.
	view.setup(item, func(_card: Card) -> void: pass)
	return view


func test_con_oro_suficiente_el_boton_queda_activo() -> void:
	var view := _view(_item(30))
	view.refresh(100)
	assert_false(_buy_button(view).disabled)


func test_sin_oro_suficiente_el_boton_queda_desactivado() -> void:
	var view := _view(_item(30))
	view.refresh(29)
	assert_true(_buy_button(view).disabled)


func test_con_el_oro_justo_se_puede_comprar() -> void:
	var view := _view(_item(30))
	view.refresh(30)
	assert_false(_buy_button(view).disabled, "precio == oro debe permitirse")


func test_refresh_reacciona_a_que_baje_el_oro() -> void:
	# Es el motivo de repintar todos los artículos tras cada compra.
	var view := _view(_item(30))
	view.refresh(100)
	assert_false(_buy_button(view).disabled)
	view.refresh(10)
	assert_true(_buy_button(view).disabled, "al quedarse sin oro debe bloquearse")


func test_al_agotarse_el_stock_se_marca_como_vendido() -> void:
	var item := _item(10, 1)
	var view := _view(item)
	var stats := TestBuilders.stats().with_gold(100).build()

	item.purchase(stats)
	view.refresh(stats.total_gold)

	var button := _buy_button(view)
	assert_true(button.disabled, "agotado no se puede comprar")
	assert_eq(button.text, tr("SHOP_SOLD_OUT"))
	assert_eq(view.modulate, UITheme.DISABLED_MUTED, "debe quedar atenuado")


func test_el_contador_de_stock_baja_al_comprar() -> void:
	var item := _item(10, 3)
	var view := _view(item)
	var stats := TestBuilders.stats().with_gold(100).build()

	view.refresh(stats.total_gold)
	assert_eq(_stock_label(view).text, tr("SHOP_STOCK") % 3)

	item.purchase(stats)
	view.refresh(stats.total_gold)
	assert_eq(_stock_label(view).text, tr("SHOP_STOCK") % 2)


func test_con_stock_ilimitado_no_se_muestra_contador() -> void:
	var view := _view(_item(10, -1))
	view.refresh(100)
	assert_null(_stock_label(view), "stock -1 no debe pintar contador")
	assert_false(_buy_button(view).disabled)


func test_pulsar_comprar_avisa_al_panel_con_su_articulo() -> void:
	var item := _item(10)
	var view := _view(item)
	var received: Array[ShopItem] = []
	view.purchase_requested.connect(func(i: ShopItem): received.append(i))

	_buy_button(view).pressed.emit()

	assert_eq(received.size(), 1)
	if received.size() == 1:
		assert_eq(received[0], item, "la vista no toca stats: solo avisa de cual es")


func _buy_button(view: ShopItemView) -> Button:
	for child in view.get_children():
		if child is Button:
			return child
	return null


func _stock_label(view: ShopItemView) -> Label:
	# El contador es la etiqueta cuyo texto sale de SHOP_STOCK; la de precio usa
	# FMT_GOLD. Se distinguen por posición: precio primero, stock después.
	var labels: Array[Label] = []
	for child in view.get_children():
		if child is Label:
			labels.append(child)
	return labels[1] if labels.size() > 1 else null
