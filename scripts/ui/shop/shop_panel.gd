extends Control
class_name ShopPanel

## Panel de tienda. Muestra items comprables y opcion de purga.
## Se integra en el flujo de eventos: al cerrar emite shop_event_resolved.

const CARD_MENU_UI = preload("uid://bt76i1liwhags")

enum Mode { BUY, PURGE }

@onready var title_label: Label = %TitleLabel
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var gold_label: Label = %GoldLabel
@onready var items_container: GridContainer = %ItemsContainer
@onready var purge_container: GridContainer = %PurgeContainer
@onready var purge_cost_label: Label = %PurgeCostLabel
@onready var buy_tab_button: Button = %BuyTabButton
@onready var purge_tab_button: Button = %PurgeTabButton
@onready var close_button: Button = %CloseButton
@onready var card_tooltip_popup: CardTooltipPopup = %CardTooltipPopup
@onready var buy_section: Control = %BuySection
@onready var purge_section: Control = %PurgeSection

var shop_config:ShopConfig
var stats:Stats
var _current_mode:Mode = Mode.BUY


func setup(p_shop_config:ShopConfig, p_stats:Stats, event_title:String,
		event_description:String) -> void:
	if not is_node_ready():
		await ready

	shop_config = p_shop_config
	stats = p_stats

	title_label.text = event_title
	description_label.text = event_description
	_update_gold_display()
	_populate_items()
	_set_mode(Mode.BUY)

	# Conectar cambios de stats para actualizar oro en tiempo real
	stats.stats_changed.connect(_update_gold_display)

	# Tabs
	buy_tab_button.pressed.connect(_on_buy_tab_pressed)
	purge_tab_button.pressed.connect(_on_purge_tab_pressed)
	close_button.pressed.connect(_on_close_pressed)

	# Ocultar tab de purga si no esta permitido
	if not shop_config.allow_purge:
		purge_tab_button.visible = false


func _update_gold_display() -> void:
	if gold_label:
		gold_label.text = "%d oro" % stats.total_gold


func _set_mode(mode:Mode) -> void:
	_current_mode = mode
	buy_section.visible = (mode == Mode.BUY)
	purge_section.visible = (mode == Mode.PURGE)
	buy_tab_button.disabled = (mode == Mode.BUY)
	purge_tab_button.disabled = (mode == Mode.PURGE)

	if mode == Mode.PURGE:
		_populate_purge_view()


func _populate_items() -> void:
	for child in items_container.get_children():
		child.queue_free()

	for item in shop_config.items:
		if not item.is_available():
			continue
		_add_shop_item_ui(item)


func _add_shop_item_ui(item:ShopItem) -> void:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Carta visual
	var card_ui:CardMenuUi = CARD_MENU_UI.instantiate()
	container.add_child(card_ui)
	card_ui.card = item.card
	card_ui.tooltip_requested.connect(card_tooltip_popup.show_tooltip)

	# Precio
	var price_label := Label.new()
	price_label.text = "%d oro" % item.price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_color_override("font_color", Color(0.15, 0.1, 0.08))
	price_label.add_theme_font_size_override("font_size", 14)
	container.add_child(price_label)

	# Stock
	if item.stock != -1:
		var stock_label := Label.new()
		stock_label.text = "Stock: %d" % (item.stock - item._sold_count)
		stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stock_label.add_theme_color_override("font_color", Color(0.4, 0.35, 0.3))
		stock_label.add_theme_font_size_override("font_size", 12)
		container.add_child(stock_label)

	# Boton de compra
	var buy_button := Button.new()
	buy_button.text = "Comprar"
	buy_button.disabled = not item.can_afford(stats.total_gold)
	buy_button.pressed.connect(_on_buy_pressed.bind(item, buy_button, container))
	container.add_child(buy_button)

	items_container.add_child(container)


func _populate_purge_view() -> void:
	for child in purge_container.get_children():
		child.queue_free()

	card_tooltip_popup.hide_tooltip()

	var purges_left := shop_config.max_purges - shop_config._purges_done_this_visit
	if shop_config.max_purges == -1:
		purge_cost_label.text = "Coste de purga: %d oro" % shop_config.purge_cost
	else:
		purge_cost_label.text = "Coste de purga: %d oro (%d usos restantes)" % [
			shop_config.purge_cost, purges_left]
	purge_cost_label.visible = shop_config.allow_purge

	# Mostrar todas las cartas del mazo (draw_pile + discard_pile)
	var all_cards:Array[Card] = []
	all_cards.append_array(stats.draw_pile.cards)
	all_cards.append_array(stats.discard_pile.cards)

	for card in all_cards:
		var container := VBoxContainer.new()
		container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		var card_ui:CardMenuUi = CARD_MENU_UI.instantiate()
		container.add_child(card_ui)
		card_ui.card = card
		card_ui.tooltip_requested.connect(card_tooltip_popup.show_tooltip)

		var purge_button := Button.new()
		purge_button.text = "Eliminar"
		purge_button.disabled = not shop_config.can_purge(stats.total_gold)
		purge_button.pressed.connect(_on_purge_pressed.bind(card))
		container.add_child(purge_button)

		purge_container.add_child(container)


func _on_buy_pressed(item:ShopItem, button:Button, container:VBoxContainer) -> void:
	if not item.can_afford(stats.total_gold) or not item.is_available():
		return

	item.purchase(stats)
	_update_gold_display()

	# Actualizar estado del boton y stock
	if not item.is_available():
		container.modulate = Color(0.5, 0.5, 0.5)
		button.disabled = true
		button.text = "Agotado"
	else:
		button.disabled = not item.can_afford(stats.total_gold)
		# Actualizar label de stock si existe
		for child in container.get_children():
			if child is Label and child.text.begins_with("Stock:"):
				child.text = "Stock: %d" % (item.stock - item._sold_count)

	# Actualizar asequibilidad de todos los items
	_refresh_buy_buttons()


func _on_purge_pressed(card:Card) -> void:
	if shop_config.purge_card(card, stats):
		_update_gold_display()
		# Refrescar vista de purga
		_populate_purge_view()
		# Actualizar asequibilidad de compra tambien
		_refresh_buy_buttons()


func _refresh_buy_buttons() -> void:
	for container in items_container.get_children():
		if container is VBoxContainer:
			for child in container.get_children():
				if child is Button:
					# Buscar el item asociado
					var idx := container.get_index()
					if idx < shop_config.items.size():
						var item := shop_config.items[idx]
						if item.is_available():
							child.disabled = not item.can_afford(stats.total_gold)


func _on_buy_tab_pressed() -> void:
	card_tooltip_popup.hide_tooltip()
	_set_mode(Mode.BUY)


func _on_purge_tab_pressed() -> void:
	card_tooltip_popup.hide_tooltip()
	_set_mode(Mode.PURGE)


func _on_close_pressed() -> void:
	stats.stats_changed.disconnect(_update_gold_display)
	Events.shop_event_resolved.emit()
	queue_free()


func _input(event:InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if card_tooltip_popup.visible:
			card_tooltip_popup.hide_tooltip()
		else:
			_on_close_pressed()
