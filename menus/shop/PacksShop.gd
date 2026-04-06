# PacksShop.gd
# Tienda de sobres con probabilidades
extends Control

@onready var back_button: Button = $MarginContainer/VBoxContainer/TopBar/BackButton
@onready var packs_grid: GridContainer = $MarginContainer/VBoxContainer/ScrollContainer/PacksGrid
@onready var currency_label: Label = $MarginContainer/VBoxContainer/TopBar/CurrencyLabel
@onready var loading_label: Label = $MarginContainer/VBoxContainer/LoadingLabel
@onready var pack_details_panel: Panel = $PackDetailsPanel
@onready var pack_opening_result: Control = $PackOpeningResult

const PACK_CARD_SCENE = preload("res://menus/packs/PackCard.tscn")

var available_packs: Array = []
var user_currency: int = 0
var last_purchased_pack_id: String = ""  # Para abrir automáticamente después de comprar
var last_purchased_pack_data: Dictionary = {}

# Probabilidades (del backend)
const RARITY_PROBABILITIES = {
	"common": 60,
	"rare": 25,
	"epic": 12,
	"legendary": 3
}

func _ready():
	# Conectar botón volver
	back_button.pressed.connect(_on_back_pressed)
	
	# Conectar señal de cambio de monedas desde UserManager
	if UserManager:
		UserManager.currency_changed.connect(_on_currency_changed)

	if PacksManager:
		PacksManager.available_packs_loaded.connect(_on_available_packs_loaded)
		PacksManager.pack_purchased.connect(_on_pack_purchased)
		PacksManager.pack_opened.connect(_on_pack_opened)
		PacksManager.error_occurred.connect(show_error)
	
	load_available_packs()
	load_user_currency()
	
	# Conectar señal de cierre del resultado
	if pack_opening_result:
		pack_opening_result.closed.connect(_on_pack_result_closed)

	resized.connect(_on_resized)
	_update_grid_columns()

func _on_back_pressed():
	SceneTransition.go_to_mainlobby()

func _on_currency_changed(new_amount: int):
	"""Callback cuando las monedas cambian"""
	user_currency = new_amount
	update_currency_display()

func load_available_packs():
	loading_label.show()
	loading_label.text = "Cargando sobres disponibles..."
	PacksManager.fetch_available_packs()

func load_user_currency():
	user_currency = UserManager.get_currency()
	update_currency_display()

func _on_available_packs_loaded(packs: Array):
	loading_label.hide()
	available_packs = packs
	print("📦 Packs disponibles: ", available_packs.size())
	display_packs()

func display_packs():
	print("📦 Mostrando packs en el grid...")
	# Limpiar grid
	for child in packs_grid.get_children():
		child.queue_free()
	
	if available_packs.size() == 0:
		loading_label.show()
		loading_label.text = "No hay sobres disponibles"
		return
	
	# Mostrar cada pack disponible
	for pack_data in available_packs:
		print("  - Creando card para pack: ", pack_data.get("name", "???"))
		var pack_card = create_pack_card(pack_data)
		packs_grid.add_child(pack_card)
		pack_card.setup(pack_data)
		pack_card.set_can_afford(user_currency >= int(pack_data.get("price", 0)))

func create_pack_card(pack_data: Dictionary) -> Control:
	var card = PACK_CARD_SCENE.instantiate()
	card.pack_selected.connect(buy_pack)
	card.probabilities_requested.connect(show_probabilities)
	return card

func show_probabilities(pack_data: Dictionary):
	# Mostrar panel con gráfico de probabilidades
	var dialog = AcceptDialog.new()
	dialog.title = "Probabilidades - " + pack_data.get("name", "")
	dialog.size = Vector2(400, 500)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	
	# Título
	var title = Label.new()
	title.text = "Probabilidades de Rareza"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Barras de probabilidad
	for rarity in ["common", "rare", "epic", "legendary"]:
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		
		# Nombre rareza
		var name_label = Label.new()
		name_label.text = _rarity_label_es(rarity)
		name_label.custom_minimum_size = Vector2(100, 0)
		name_label.add_theme_color_override("font_color", get_rarity_color(rarity))
		hbox.add_child(name_label)
		
		# Barra de progreso
		var progress = ProgressBar.new()
		progress.custom_minimum_size = Vector2(200, 30)
		progress.max_value = 100
		progress.value = RARITY_PROBABILITIES[rarity]
		progress.show_percentage = true
		
		# Color de la barra según rareza
		var style = StyleBoxFlat.new()
		style.bg_color = get_rarity_color(rarity)
		progress.add_theme_stylebox_override("fill", style)
		
		hbox.add_child(progress)
		
		# Porcentaje
		var percent_label = Label.new()
		percent_label.text = "%d%%" % RARITY_PROBABILITIES[rarity]
		percent_label.add_theme_font_size_override("font_size", 16)
		hbox.add_child(percent_label)
		
		vbox.add_child(hbox)
	
	# Nota sobre rareza garantizada
	if pack_data.has("guaranteed_rarity") and pack_data.guaranteed_rarity:
		var note = Label.new()
		note.text = "\n⭐ Este sobre garantiza al menos\nuna carta %s" % _rarity_label_es(pack_data.guaranteed_rarity)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.add_theme_color_override("font_color", get_rarity_color(pack_data.guaranteed_rarity))
		vbox.add_child(note)
	
	dialog.add_child(vbox)
	add_child(dialog)
	dialog.popup_centered()

func buy_pack(pack_data: Dictionary):
	var pack_id = pack_data.get("id", "")
	var price = pack_data.get("price", 0)
	
	if user_currency < price:
		show_error("No tienes suficientes monedas!\nNecesitas: %d\nTienes: %d" % [price, user_currency])
		return
	
	# Confirmar compra
	var dialog = ConfirmationDialog.new()
	dialog.title = "Confirmar compra"
	dialog.ok_button_text = "Comprar"
	dialog.cancel_button_text = "Cancelar"
	dialog.dialog_text = "¿Comprar %s por %d monedas?" % [pack_data.get("name", ""), price]
	dialog.confirmed.connect(func(): confirm_purchase(pack_id, price))
	add_child(dialog)
	dialog.popup_centered()

func _on_resized() -> void:
	_update_grid_columns()

func _update_grid_columns() -> void:
	if not is_instance_valid(packs_grid):
		return

	var viewport_width = get_viewport_rect().size.x
	var content_width = max(320.0, viewport_width - 80.0)
	var target_card_width = 280.0
	var gap = 20.0
	var columns = int(floor((content_width + gap) / (target_card_width + gap)))
	packs_grid.columns = clamp(columns, 1, 4)

func confirm_purchase(pack_id: String, _price: int):
	PacksManager.purchase_pack(pack_id, 1)

func _on_pack_purchased(user_pack_id: String, pack_data: Dictionary, new_currency: int):
	last_purchased_pack_id = user_pack_id
	last_purchased_pack_data = pack_data
	user_currency = new_currency
	update_currency_display()
	display_packs()
	show_message("✅ ¡Compra exitosa!\nTe quedan %d monedas" % user_currency)
	open_purchased_pack()

func open_purchased_pack():
	"""Abre el sobre recién comprado y muestra las cartas recibidas"""
	if last_purchased_pack_id.is_empty():
		return
	PacksManager.open_pack(last_purchased_pack_id)

func _on_pack_opened(user_pack_id: String, pack_name: String, cards: Array, new_currency: int):
	if user_pack_id != last_purchased_pack_id:
		return
	if new_currency != user_currency:
		user_currency = new_currency
		update_currency_display()
	if pack_opening_result:
		pack_opening_result.show_cards(pack_name, cards)
	last_purchased_pack_id = ""
	last_purchased_pack_data.clear()

func _on_pack_result_closed():
	"""Cuando se cierra la vista de resultados, no hacer nada especial en la tienda"""
	pass

func show_opened_cards(pack_data: Dictionary):
	"""Muestra un diálogo con las cartas recibidas del sobre"""
	var cards = pack_data.get("cards", [])
	var pack_name = pack_data.get("pack_name", "Sobre")
	
	var dialog = AcceptDialog.new()
	dialog.title = "¡" + pack_name + " abierto!"
	dialog.size = Vector2(500, 600)
	add_child(dialog)
	
	# Crear texto con las cartas recibidas
	var text = "🎉 Cartas recibidas:\n\n"
	for card in cards:
		var rarity_emoji = get_rarity_emoji(card.rarity)
		var foil_text = " ✨FOIL" if card.get("is_foil", false) else ""
		text += rarity_emoji + " " + card.name + " (" + card.rarity + ")" + foil_text + "\n"
	
	if pack_data.has("summary"):
		var summary = pack_data.summary
		var by_rarity = summary.get("by_rarity", summary)
		text += "\n📊 Resumen:\n"
		if by_rarity.get("common", 0) > 0 or by_rarity.get("comun", 0) > 0:
			text += "Comunes: " + str(by_rarity.get("common", by_rarity.get("comun", 0))) + "\n"
		if by_rarity.get("rare", 0) > 0 or by_rarity.get("rara", 0) > 0:
			text += "Raras: " + str(by_rarity.get("rare", by_rarity.get("rara", 0))) + "\n"
		if by_rarity.get("epic", 0) > 0 or by_rarity.get("epica", 0) > 0:
			text += "Épicas: " + str(by_rarity.get("epic", by_rarity.get("epica", 0))) + "\n"
		if by_rarity.get("legendary", 0) > 0 or by_rarity.get("legendaria", 0) > 0:
			text += "Legendarias: " + str(by_rarity.get("legendary", by_rarity.get("legendaria", 0))) + "\n"
	
	dialog.dialog_text = text
	dialog.popup_centered()

func get_rarity_emoji(rarity: String) -> String:
	match rarity:
		"legendary", "legendaria":
			return "💎"
		"epic", "epica":
			return "🔮"
		"rare", "rara":
			return "⭐"
		_:
			return "🃏"

func update_currency_display():
	currency_label.text = "💰 %d Monedas" % user_currency

func show_message(text: String):
	var dialog = AcceptDialog.new()
	dialog.dialog_text = text
	add_child(dialog)
	dialog.popup_centered()

func show_error(text: String):
	var dialog = AcceptDialog.new()
	dialog.title = "Error"
	dialog.dialog_text = text
	add_child(dialog)
	dialog.popup_centered()

func get_rarity_color(rarity: String) -> Color:
	match rarity:
		"common", "comun":
			return Color(0.75, 0.75, 0.75)
		"rare", "rara":
			return Color(0.29, 0.56, 0.89)
		"epic", "epica":
			return Color(0.61, 0.35, 0.71)
		"legendary", "legendaria":
			return Color(1.0, 0.84, 0.0)
		_:
			return Color.WHITE

func _rarity_label_es(rarity: String) -> String:
	match rarity:
		"common", "comun":
			return "Común"
		"rare", "rara":
			return "Rara"
		"epic", "epica":
			return "Épica"
		"legendary", "legendaria":
			return "Legendaria"
		_:
			return rarity.capitalize()
