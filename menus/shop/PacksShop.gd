# PacksShop.gd
# Tienda de sobres: catálogo, compra (abrir ahora o guardar), sobres sin abrir
# y apertura con revelado de cartas.
extends Control

const PACK_CARD_SCENE = preload("res://menus/packs/PackCard.tscn")

# Probabilidades por carta (mismos pesos que RARITY_WEIGHTS del servidor)
const RARITY_PROBABILITIES = {
	"common": 60,
	"rare": 25,
	"epic": 12,
	"legendary": 3
}

@onready var back_button: Button = %BackButton
@onready var packs_grid: HFlowContainer = %PacksGrid
@onready var currency_label: Label = %CurrencyLabel
@onready var coin_icon: TextureRect = %CoinIcon
@onready var loading_label: Label = %LoadingLabel
@onready var my_packs_panel: PanelContainer = %MyPacksPanel
@onready var my_packs_row: HBoxContainer = %MyPacksRow
@onready var pack_opening_result: Control = %PackOpeningResult
@onready var toast: ToastNotice = %Toast

var available_packs: Array = []
var user_currency: int = 0
# Sobre que se está abriendo (user_pack_id); evita mostrar aperturas ajenas
var _opening_user_pack_id: String = ""
# Tras comprar: abrir el sobre al momento o guardarlo
var _open_after_purchase := true
var _busy := false


func _ready():
	back_button.pressed.connect(_on_back_pressed)
	UserManager.currency_changed.connect(_on_currency_changed)

	PacksManager.available_packs_loaded.connect(_on_available_packs_loaded)
	PacksManager.user_packs_loaded.connect(_on_user_packs_loaded)
	PacksManager.pack_purchased.connect(_on_pack_purchased)
	PacksManager.pack_opened.connect(_on_pack_opened)
	PacksManager.error_occurred.connect(_on_error)

	pack_opening_result.closed.connect(_on_pack_result_closed)

	user_currency = UserManager.get_currency()
	update_currency_display()
	load_available_packs()
	PacksManager.fetch_user_packs()



func _on_back_pressed():
	SceneTransition.go_to_mainlobby()


# ============================================================================
# CATÁLOGO
# ============================================================================

func load_available_packs():
	loading_label.show()
	loading_label.text = "Cargando sobres…"
	PacksManager.fetch_available_packs()


func _on_available_packs_loaded(packs: Array):
	loading_label.hide()
	available_packs = packs
	display_packs()


func display_packs():
	for child in packs_grid.get_children():
		child.queue_free()

	if available_packs.is_empty():
		loading_label.show()
		loading_label.text = "No hay sobres a la venta ahora mismo"
		return

	for pack_data in available_packs:
		var pack_card = PACK_CARD_SCENE.instantiate()
		pack_card.pack_selected.connect(buy_pack)
		pack_card.probabilities_requested.connect(show_probabilities)
		packs_grid.add_child(pack_card)
		pack_card.setup(pack_data)
		pack_card.set_can_afford(user_currency >= int(pack_data.get("price", 0)))


func _refresh_affordability() -> void:
	for card in packs_grid.get_children():
		if card.has_method("set_can_afford") and not card.is_queued_for_deletion():
			card.set_can_afford(user_currency >= int(card.pack_data.get("price", 0)))


# ============================================================================
# COMPRA
# ============================================================================

func buy_pack(pack_data: Dictionary):
	var price := int(pack_data.get("price", 0))
	if user_currency < price:
		toast.show_message("Te faltan %s monedas para este sobre" % PackArt.format_coins(price - user_currency), true)
		return
	if _busy:
		return

	var dialog := ConfirmationDialog.new()
	dialog.title = "Confirmar compra"
	dialog.dialog_text = "¿Comprar «%s» por %s monedas?\nTe quedarán %s." % [
		pack_data.get("name", ""), PackArt.format_coins(price), PackArt.format_coins(user_currency - price)]
	dialog.ok_button_text = "Comprar y abrir"
	dialog.cancel_button_text = "Cancelar"
	dialog.add_button("Comprar y guardar", true, "save")
	dialog.confirmed.connect(func(): _confirm_purchase(pack_data, true))
	dialog.custom_action.connect(func(action: StringName):
		if action == &"save":
			dialog.hide()
			_confirm_purchase(pack_data, false)
	)
	dialog.visibility_changed.connect(func(): if not dialog.visible: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


func _confirm_purchase(pack_data: Dictionary, open_now: bool) -> void:
	_busy = true
	_open_after_purchase = open_now
	loading_label.show()
	loading_label.text = "Comprando…"
	PacksManager.purchase_pack(pack_data.get("id", ""), 1)


func _on_pack_purchased(user_pack_id: String, pack_data: Dictionary, new_currency: int):
	user_currency = new_currency
	update_currency_display()
	_refresh_affordability()

	if _open_after_purchase:
		_open_pack(user_pack_id)
	else:
		_busy = false
		loading_label.hide()
		toast.show_message("«%s» guardado en «Mis sobres»" % pack_data.get("name", "Sobre"))
		PacksManager.fetch_user_packs()


# ============================================================================
# SOBRES SIN ABRIR
# ============================================================================

func _on_user_packs_loaded(user_packs: Array) -> void:
	for child in my_packs_row.get_children():
		child.queue_free()

	var owned := user_packs.filter(func(p): return int(p.get("quantity", 0)) > 0)
	my_packs_panel.visible = not owned.is_empty()
	for user_pack in owned:
		my_packs_row.add_child(_create_owned_pack(user_pack))


func _create_owned_pack(user_pack: Dictionary) -> Control:
	var pack: Dictionary = user_pack.get("Pack", {}) if user_pack.get("Pack") is Dictionary else {}

	var card := PanelContainer.new()
	card.theme_type_variation = &"ItemCard"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var image := TextureRect.new()
	image.texture = PackArt.texture_for(pack)
	image.custom_minimum_size = Vector2(80, 112)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(image)

	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 6)
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = pack.get("name", "Sobre")
	name_label.theme_type_variation = &"SectionTitle"
	info.add_child(name_label)

	var quantity := Label.new()
	quantity.text = "× %d" % int(user_pack.get("quantity", 0))
	quantity.theme_type_variation = &"StatValue"
	info.add_child(quantity)

	var open_button := Button.new()
	open_button.text = "Abrir"
	open_button.theme_type_variation = &"PlayButton"
	open_button.add_theme_font_size_override("font_size", 16)
	open_button.pressed.connect(func(): _open_pack(str(user_pack.get("id", ""))))
	info.add_child(open_button)
	return card


func _open_pack(user_pack_id: String) -> void:
	if user_pack_id.is_empty():
		return
	_busy = true
	_opening_user_pack_id = user_pack_id
	loading_label.show()
	loading_label.text = "Abriendo sobre…"
	PacksManager.open_pack(user_pack_id)


func _on_pack_opened(user_pack_id: String, pack_name: String, cards: Array, new_currency: int):
	if user_pack_id != _opening_user_pack_id:
		return
	_busy = false
	_opening_user_pack_id = ""
	loading_label.hide()
	if new_currency != user_currency:
		user_currency = new_currency
		update_currency_display()
	pack_opening_result.show_cards(pack_name, cards)
	PacksManager.fetch_user_packs()


func _on_pack_result_closed():
	pass


func _on_error(message: String) -> void:
	# Si la compra o la apertura fallan, desbloquear la tienda y avisar
	_busy = false
	_opening_user_pack_id = ""
	loading_label.hide()
	toast.show_message(message, true)
	# Un sobre pagado cuya apertura falló sigue en «Mis sobres»
	PacksManager.fetch_user_packs()


# ============================================================================
# PROBABILIDADES
# ============================================================================

func show_probabilities(pack_data: Dictionary):
	var dialog := AcceptDialog.new()
	dialog.title = "Probabilidades · %s" % pack_data.get("name", "")
	dialog.ok_button_text = "Entendido"

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.custom_minimum_size = Vector2(380, 0)

	var intro := Label.new()
	intro.text = "Probabilidad de cada carta del sobre:"
	vbox.add_child(intro)

	for rarity in ["common", "rare", "epic", "legendary"]:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)

		var name_label := Label.new()
		name_label.text = PackArt.rarity_label(rarity)
		name_label.custom_minimum_size = Vector2(100, 0)
		name_label.add_theme_color_override("font_color", PackArt.rarity_color(rarity))
		hbox.add_child(name_label)

		var progress := ProgressBar.new()
		progress.custom_minimum_size = Vector2(200, 22)
		progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		progress.value = RARITY_PROBABILITIES[rarity]
		progress.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = PackArt.rarity_color(rarity)
		progress.add_theme_stylebox_override("fill", fill)
		hbox.add_child(progress)

		var percent := Label.new()
		percent.text = "%d%%" % RARITY_PROBABILITIES[rarity]
		percent.custom_minimum_size = Vector2(40, 0)
		hbox.add_child(percent)
		vbox.add_child(hbox)

	var guaranteed = pack_data.get("guaranteed_rarity")
	if guaranteed:
		var note := Label.new()
		note.text = "Garantizado: al menos una carta %s. Si no sale antes, la última lo será." % PackArt.rarity_label(str(guaranteed)).to_lower()
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_color_override("font_color", PackArt.rarity_color(str(guaranteed)))
		vbox.add_child(note)

	dialog.add_child(vbox)
	dialog.visibility_changed.connect(func(): if not dialog.visible: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


# ============================================================================
# MONEDAS
# ============================================================================

func _on_currency_changed(new_amount: int):
	user_currency = new_amount
	update_currency_display()
	_refresh_affordability()


func update_currency_display():
	currency_label.text = PackArt.format_coins(user_currency)
	coin_icon.pivot_offset = coin_icon.size / 2.0
	var tween := create_tween()
	tween.tween_property(coin_icon, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_BACK)
	tween.tween_property(coin_icon, "scale", Vector2.ONE, 0.2)
