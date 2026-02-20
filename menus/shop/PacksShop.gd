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

# Probabilidades (del backend)
const RARITY_PROBABILITIES = {
	"comun": 60,
	"rara": 25,
	"epica": 12,
	"legendaria": 3
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

func create_pack_card(pack_data: Dictionary) -> Control:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(300, 400)
	
	# Estilo del panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.8, 0.6, 0.2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	card.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	vbox.add_child(margin)
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	
	# Nombre del pack
	var name_label = Label.new()
	name_label.text = pack_data.get("name", "Pack Misterioso")
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(name_label)
	
	# Imagen del pack (placeholder)
	var image = ColorRect.new()
	image.custom_minimum_size = Vector2(200, 200)
	image.color = Color(0.3, 0.3, 0.4)
	content.add_child(image)
	
	# Descripción
	var desc_label = Label.new()
	desc_label.text = pack_data.get("description", "")
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_font_size_override("font_size", 12)
	content.add_child(desc_label)
	
	# Cartas por pack
	var cards_label = Label.new()
	cards_label.text = "🎴 %d cartas por sobre" % pack_data.get("cards_per_pack", 5)
	cards_label.add_theme_font_size_override("font_size", 14)
	content.add_child(cards_label)
	
	# Rareza garantizada
	if pack_data.has("guaranteed_rarity") and pack_data.guaranteed_rarity:
		var guaranteed_label = Label.new()
		guaranteed_label.text = "✨ Garantiza: " + pack_data.guaranteed_rarity.capitalize()
		guaranteed_label.add_theme_color_override("font_color", get_rarity_color(pack_data.guaranteed_rarity))
		guaranteed_label.add_theme_font_size_override("font_size", 14)
		content.add_child(guaranteed_label)
	
	# Botón de probabilidades
	var prob_button = Button.new()
	prob_button.text = "📊 Ver Probabilidades"
	prob_button.pressed.connect(func(): show_probabilities(pack_data))
	content.add_child(prob_button)
	
	# Separador
	content.add_child(HSeparator.new())
	
	# Precio y botón de compra
	var price_hbox = HBoxContainer.new()
	price_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(price_hbox)
	
	var price_label = Label.new()
	price_label.text = "💰 %d" % pack_data.get("price", 0)
	price_label.add_theme_font_size_override("font_size", 20)
	price_label.add_theme_color_override("font_color", Color.GOLD)
	price_hbox.add_child(price_label)
	
	var buy_button = Button.new()
	buy_button.text = "Comprar"
	buy_button.add_theme_font_size_override("font_size", 16)
	buy_button.pressed.connect(func(): buy_pack(pack_data))
	price_hbox.add_child(buy_button)
	
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
	for rarity in ["comun", "rara", "epica", "legendaria"]:
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		
		# Nombre rareza
		var name_label = Label.new()
		name_label.text = rarity.capitalize()
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
		note.text = "\n⭐ Este sobre garantiza al menos\nuna carta %s" % pack_data.guaranteed_rarity.capitalize()
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
	dialog.dialog_text = "¿Comprar %s por %d monedas?" % [pack_data.get("name", ""), price]
	dialog.confirmed.connect(func(): confirm_purchase(pack_id, price))
	add_child(dialog)
	dialog.popup_centered()

func confirm_purchase(pack_id: String, _price: int):
	PacksManager.purchase_pack(pack_id, 1)

func _on_pack_purchased(user_pack_id: String, pack_data: Dictionary, new_currency: int):
	last_purchased_pack_id = user_pack_id
	user_currency = new_currency
	update_currency_display()
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
		text += "\n📊 Resumen:\n"
		if summary.get("comun", 0) > 0:
			text += "Comunes: " + str(summary.comun) + "\n"
		if summary.get("rara", 0) > 0:
			text += "Raras: " + str(summary.rara) + "\n"
		if summary.get("epica", 0) > 0:
			text += "Épicas: " + str(summary.epica) + "\n"
		if summary.get("legendaria", 0) > 0:
			text += "Legendarias: " + str(summary.legendaria) + "\n"
	
	dialog.dialog_text = text
	dialog.popup_centered()

func get_rarity_emoji(rarity: String) -> String:
	match rarity:
		"legendaria":
			return "💎"
		"epica":
			return "🔮"
		"rara":
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
		"comun":
			return Color(0.75, 0.75, 0.75)
		"rara":
			return Color(0.29, 0.56, 0.89)
		"epica":
			return Color(0.61, 0.35, 0.71)
		"legendaria":
			return Color(1.0, 0.84, 0.0)
		_:
			return Color.WHITE
