# PacksInventory.gd
# Inventario de sobres del usuario
extends Control

@onready var packs_grid: GridContainer = $MarginContainer/VBoxContainer/ScrollContainer/PacksGrid
@onready var loading_label: Label = $MarginContainer/VBoxContainer/LoadingLabel
@onready var empty_label: Label = $MarginContainer/VBoxContainer/EmptyLabel
@onready var pack_opening_result: Control = $PackOpeningResult

var user_packs: Array = []

func _ready():
	if PacksManager:
		PacksManager.user_packs_loaded.connect(_on_user_packs_loaded)
		PacksManager.pack_opened.connect(_on_pack_opened)
		PacksManager.error_occurred.connect(show_error)

	load_user_packs()
	AuthManager.login_successful.connect(_on_auth_changed)
	
	# Conectar señal de cierre del resultado
	if pack_opening_result:
		pack_opening_result.closed.connect(_on_pack_result_closed)

func _on_auth_changed(_user_data):
	load_user_packs()

func load_user_packs():
	loading_label.show()
	empty_label.hide()
	PacksManager.fetch_user_packs()

func _on_user_packs_loaded(packs: Array):
	loading_label.hide()
	user_packs = packs
	display_packs()

func display_packs():
	# Limpiar grid
	for child in packs_grid.get_children():
		child.queue_free()
	
	if user_packs.size() == 0:
		empty_label.show()
		empty_label.text = "No tienes sobres sin abrir\n¡Ve a la tienda a comprar algunos!"
		return
	
	empty_label.hide()
	
	# Agrupar sobres por pack_id y contar
	var packs_count: Dictionary = {}
	for user_pack in user_packs:
		var pack_id = user_pack.get("pack_id", "")
		if pack_id:
			if not packs_count.has(pack_id):
				packs_count[pack_id] = {
					"count": 0,
					"pack_data": user_pack.get("Pack", {}),
					"user_pack_ids": []
				}
			packs_count[pack_id]["count"] += 1
			packs_count[pack_id]["user_pack_ids"].append(user_pack.get("id", ""))
	
	# Mostrar cada tipo de sobre con su cantidad
	for pack_id in packs_count.keys():
		var pack_info = packs_count[pack_id]
		var card = create_pack_card(pack_info["pack_data"], pack_info["count"], pack_info["user_pack_ids"])
		packs_grid.add_child(card)

func create_pack_card(pack_data: Dictionary, count: int, user_pack_ids: Array) -> Control:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(280, 380)
	
	# Estilo del panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.25, 0.3)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.4, 0.7, 0.9)
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
	
	# Badge con cantidad
	var count_badge = Label.new()
	count_badge.text = "x" + str(count)
	count_badge.add_theme_font_size_override("font_size", 32)
	count_badge.add_theme_color_override("font_color", Color.GOLD)
	count_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(count_badge)
	
	# Nombre del pack
	var name_label = Label.new()
	name_label.text = pack_data.get("name", "Sobre Misterioso")
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(name_label)
	
	# Imagen del pack (placeholder)
	var image = ColorRect.new()
	image.custom_minimum_size = Vector2(180, 180)
	image.color = Color(0.3, 0.35, 0.4)
	content.add_child(image)
	
	# Información
	var cards_label = Label.new()
	cards_label.text = "🎴 %d cartas por sobre" % pack_data.get("cards_per_pack", 5)
	cards_label.add_theme_font_size_override("font_size", 12)
	cards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(cards_label)
	
	# Rareza garantizada
	if pack_data.has("guaranteed_rarity") and pack_data.guaranteed_rarity:
		var guaranteed_label = Label.new()
		guaranteed_label.text = "✨ Garantiza: " + pack_data.guaranteed_rarity.capitalize()
		guaranteed_label.add_theme_color_override("font_color", get_rarity_color(pack_data.guaranteed_rarity))
		guaranteed_label.add_theme_font_size_override("font_size", 12)
		guaranteed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(guaranteed_label)
	
	# Separador
	content.add_child(HSeparator.new())
	
	# Botón para abrir
	var open_button = Button.new()
	open_button.text = "✨ Abrir Sobre"
	open_button.add_theme_font_size_override("font_size", 16)
	open_button.pressed.connect(func(): open_pack(user_pack_ids[0], pack_data))
	content.add_child(open_button)
	
	# Botón para abrir todos si hay más de 1
	if count > 1:
		var open_all_button = Button.new()
		open_all_button.text = "✨ Abrir Todos (%d)" % count
		open_all_button.add_theme_font_size_override("font_size", 14)
		open_all_button.pressed.connect(func(): open_all_packs(user_pack_ids, pack_data))
		content.add_child(open_all_button)
	
	return card

func open_pack(user_pack_id: String, _pack_data: Dictionary):
	"""Abre un solo sobre"""
	PacksManager.open_pack(user_pack_id)

func open_all_packs(user_pack_ids: Array, pack_data: Dictionary):
	"""Abre todos los sobres del mismo tipo"""
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "¿Abrir todos los %d sobres de %s?" % [user_pack_ids.size(), pack_data.get("name", "")]
	dialog.confirmed.connect(func(): 
		for pack_id in user_pack_ids:
			open_pack(pack_id, pack_data)
			await get_tree().create_timer(0.3).timeout
	)
	add_child(dialog)
	dialog.popup_centered()

func _on_pack_opened(user_pack_id: String, pack_name: String, cards: Array, _new_currency: int):
	if pack_opening_result and cards.size() > 0:
		pack_opening_result.show_cards(pack_name, cards)
	# Remover localmente el sobre abierto y refrescar UI
	user_packs = user_packs.filter(func(p): return p.get("id", "") != user_pack_id)
	display_packs()

func _on_pack_result_closed():
	"""Cuando se cierra la vista de resultados, recargar inventario"""
	load_user_packs()

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

func show_error(text: String):
	var dialog = AcceptDialog.new()
	dialog.title = "Error"
	dialog.dialog_text = text
	add_child(dialog)
	dialog.popup_centered()
