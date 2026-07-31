extends Control
class_name ShopPanel

## Panel de tienda. Muestra items comprables y opcion de purga.
## Se integra en el flujo de eventos: al cerrar emite shop_event_resolved.

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


func _ready() -> void:
	if UIState:
		UIState.register_menu()


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
		gold_label.text = tr("FMT_GOLD") % stats.total_gold


func _set_mode(mode:Mode) -> void:
	_current_mode = mode
	buy_section.visible = (mode == Mode.BUY)
	purge_section.visible = (mode == Mode.PURGE)
	buy_tab_button.disabled = (mode == Mode.BUY)
	purge_tab_button.disabled = (mode == Mode.PURGE)

	if mode == Mode.PURGE:
		_populate_purge_view()


func _populate_items() -> void:
	UILayout.clear_children(items_container)

	for item in shop_config.items:
		if not item.is_available():
			continue
		_add_shop_item_ui(item)


func _add_shop_item_ui(item:ShopItem) -> void:
	var view := ShopItemView.new()
	items_container.add_child(view)
	view.setup(item, card_tooltip_popup.show_tooltip)
	view.refresh(stats.total_gold)
	view.purchase_requested.connect(_on_buy_pressed)


func _populate_purge_view() -> void:
	UILayout.clear_children(purge_container)

	card_tooltip_popup.hide_tooltip()

	var purges_left := shop_config.max_purges - shop_config._purges_done_this_visit
	if shop_config.max_purges == -1:
		purge_cost_label.text = tr("SHOP_PURGE_COST") % shop_config.purge_cost
	else:
		purge_cost_label.text = tr("SHOP_PURGE_COST_USES") % [
			shop_config.purge_cost, purges_left]
	purge_cost_label.visible = shop_config.allow_purge

	# Mostrar todas las cartas del mazo (draw_pile + discard_pile)
	var all_cards:Array[Card] = []
	all_cards.append_array(stats.draw_pile.cards)
	all_cards.append_array(stats.discard_pile.cards)

	for card in all_cards:
		var container := VBoxContainer.new()
		container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		CardUIFactory.create(card, container, card_tooltip_popup.show_tooltip)

		var purge_button := Button.new()
		purge_button.text = tr("UI_REMOVE")
		purge_button.disabled = not shop_config.can_purge(stats.total_gold)
		purge_button.pressed.connect(_on_purge_pressed.bind(card))
		container.add_child(purge_button)

		purge_container.add_child(container)


func _on_buy_pressed(item:ShopItem) -> void:
	if not item.can_afford(stats.total_gold) or not item.is_available():
		return

	item.purchase(stats)
	_update_gold_display()
	# Repinta TODOS los artículos, no solo el comprado: gastar oro puede dejar sin
	# fondos a los demás. Antes el artículo comprado se repintaba a mano aquí y el
	# resto en _refresh_buy_buttons; ahora cada vista sabe repintarse sola.
	_refresh_buy_buttons()


func _on_purge_pressed(card:Card) -> void:
	if shop_config.purge_card(card, stats):
		_update_gold_display()
		# Refrescar vista de purga
		_populate_purge_view()
		# Actualizar asequibilidad de compra tambien
		_refresh_buy_buttons()


func _refresh_buy_buttons() -> void:
	for view in items_container.get_children():
		if view is ShopItemView:
			view.refresh(stats.total_gold)


func _on_buy_tab_pressed() -> void:
	card_tooltip_popup.hide_tooltip()
	_set_mode(Mode.BUY)


func _on_purge_tab_pressed() -> void:
	card_tooltip_popup.hide_tooltip()
	_set_mode(Mode.PURGE)


func _on_close_pressed() -> void:
	Events.shop_event_resolved.emit()
	queue_free()


func _input(event:InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if card_tooltip_popup.visible:
			card_tooltip_popup.hide_tooltip()
		else:
			_on_close_pressed()


## Patrón único de limpieza: la desconexión estaba en `_on_close_pressed`, así que
## solo ocurría al cerrar con el botón o con ESC. Cerrar por cualquier otra vía
## dejaba la conexión, y como `_on_close_pressed` desconectaba sin guarda, una
## segunda pulsación antes de que el `queue_free` se hiciera efectivo daba error.
func _exit_tree() -> void:
	if UIState:
		UIState.unregister_menu()
	if stats and stats.stats_changed.is_connected(_update_gold_display):
		stats.stats_changed.disconnect(_update_gold_display)
