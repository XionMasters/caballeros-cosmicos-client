extends Control

# DeckBuilder.gd
# Editor de mazos - permite agregar/quitar cartas de un mazo

const CARD_DISPLAY_TEMPLATE = preload("res://cards/CardDisplay.tscn")
const CARD_DETAIL_VIEW_SCENE = preload("res://cards/CardDetailView.tscn")
const MIN_DECK_SIZE = 40
const MAX_DECK_SIZE = 60
const MAX_COPIES_PER_CARD = 3

# Estado
var current_deck: Dictionary = {}
var user_cards: Array = []
var deck_cards: Dictionary = {}  # card_id -> quantity
var is_modified: bool = false
var available_deck_backs: Array = []  # Dorsos disponibles para el usuario
var selected_deck_back: Dictionary = {}  # Dorso actual del mazo
var _loading_dorso_images: int = 0  # Contador de imÃ¡genes cargÃ¡ndose

# Referencias a nodos
@onready var deck_name_label = $MarginContainer/VBoxContainer/Header/DeckInfo/DeckNameLabel
@onready var deck_stats_label = $MarginContainer/VBoxContainer/Header/DeckInfo/DeckStatsLabel
@onready var validation_label = $MarginContainer/VBoxContainer/Header/DeckInfo/ValidationLabel
@onready var back_button = $MarginContainer/VBoxContainer/Header/BackButton
@onready var save_button = $MarginContainer/VBoxContainer/Header/SaveButton
@onready var set_active_button = $MarginContainer/VBoxContainer/Header/SetActiveButton
@onready var auto_generate_button = $MarginContainer/VBoxContainer/Header/AutoGenerateButton
@onready var collection_container = $MarginContainer/VBoxContainer/Content/CartasTab/HSplitContainer/CollectionPanel/MarginContainer/VBoxContainer/ScrollContainer/CollectionGrid
@onready var deck_container = $MarginContainer/VBoxContainer/Content/CartasTab/HSplitContainer/DeckPanel/MarginContainer/VBoxContainer/ScrollContainer/DeckGrid
@onready var current_dorso_name = $MarginContainer/VBoxContainer/Content/DorsoTab/PanelContainer/MarginContainer2/VBoxContainer2/DorsoContentContainer/CurrentDorsoPanel/CurrentMargin/CurrentVBox/CurrentDorsoName
@onready var current_dorso_preview = $MarginContainer/VBoxContainer/Content/DorsoTab/PanelContainer/MarginContainer2/VBoxContainer2/DorsoContentContainer/CurrentDorsoPanel/CurrentMargin/CurrentVBox/CurrentDorsoPreview
@onready var available_dorsos_grid = $MarginContainer/VBoxContainer/Content/DorsoTab/PanelContainer/MarginContainer2/VBoxContainer2/DorsoContentContainer/AvailableDorsosPanel/AvailableMargin/AvailableVBox/AvailableDorsosScroll/AvailableDorsosGrid
@onready var loading_label = $LoadingLabel
@onready var error_label = $ErrorLabel
var card_detail_view: Control

func _ready():
	# Conectar seÃ±ales de botones
	back_button.pressed.connect(_on_back_pressed)
	save_button.pressed.connect(_on_save_pressed)
	set_active_button.pressed.connect(_on_set_active_pressed)
	auto_generate_button.pressed.connect(_on_auto_generate_pressed)
	
	# Instanciar vista detallada
	card_detail_view = CARD_DETAIL_VIEW_SCENE.instantiate()
	add_child(card_detail_view)
	card_detail_view.hide()
	card_detail_view.card_add_requested.connect(_on_detail_add_requested)
	card_detail_view.card_remove_requested.connect(_on_detail_remove_requested)

	# Conectar drag-and-drop del DeckPanel (todo el panel, no solo el grid)
	var deck_panel = $MarginContainer/VBoxContainer/Content/CartasTab/HSplitContainer/DeckPanel
	deck_panel.card_dropped.connect(_on_card_dropped_to_deck)

	# Conectar seÃ±ales de managers
	CardsManager.cards_loaded.connect(_on_cards_loaded)
	CardsManager.card_image_loaded.connect(_on_card_image_loaded)
	DecksManager.deck_updated.connect(_on_deck_updated)
	DecksManager.card_added_to_deck.connect(_on_card_added)
	DecksManager.card_removed_from_deck.connect(_on_card_removed)
	DecksManager.deck_validated.connect(_on_deck_validated)
	DecksManager.deck_generated.connect(_on_deck_generated)
	DecksManager.error_occurred.connect(_on_error_occurred)
	
	# Configurar nombres de solapas
	var tab_container = $MarginContainer/VBoxContainer/Content as TabContainer
	tab_container.set_tab_title(0, "Cartas")
	tab_container.set_tab_title(1, "Dorso")
	
	# Verificar si hay un deck pendiente para cargar
	if SceneTransition.has_pending_deck():
		var deck = SceneTransition.get_pending_deck()
		load_deck(deck)
	
 

func _refresh_deck_from_server() -> void:
	"""Recarga el mazo desde el servidor para asegurar datos actualizados"""
	var deck_id = current_deck.get("id", "")
	if deck_id.is_empty():
		return
	
	loading_label.visible = true
	DecksManager.fetch_deck(deck_id)

func load_deck(deck: Dictionary):
	"""Carga un mazo para editar"""
	current_deck = deck
	is_modified = false  # Reset modification flag when loading a new deck
	deck_name_label.text = deck.get("name", "Sin nombre")
	
	# Actualizar estado del botÃ³n de activo
	var is_active = deck.get("is_active", false)
	set_active_button.text = "âœ“ Mazo Activo" if is_active else "Marcar como Activo"
	set_active_button.disabled = is_active
	
	# Cargar dorso actual del mazo
	if deck.get("current_deck_back_id"):
		selected_deck_back = {
			"id": deck.get("current_deck_back_id"),
			"name": deck.get("deck_back", {}).get("name", "Desconocido"),
			"image_url": deck.get("deck_back", {}).get("image_url", "")
		}
	
	# Cargar cartas del mazo
	deck_cards.clear()
	var cards = deck.get("cards", [])
	for card in cards:
		var card_id = card.get("id", "")
		var quantity = card.get("DeckCard", {}).get("quantity", 1)
		deck_cards[card_id] = quantity
	
	# Cargar colecciÃ³n del usuario
	loading_label.visible = true
	CardsManager.fetch_user_cards()
	
	# Recargar mazo desde servidor para asegurar datos frescos
	_refresh_deck_from_server()
	
	# Cargar dorsos disponibles
	_load_available_deck_backs()
	
	# Actualizar estadÃ­sticas
	update_deck_stats()
	validate_deck()

func _on_cards_loaded(cards: Array):
	"""Callback cuando se cargan las cartas del usuario"""
	loading_label.visible = false
	user_cards = cards
	display_collection()
	display_deck_cards()



func display_collection():
	"""Muestra las cartas disponibles en la colecciÃ³n"""
	if not collection_container:
		return
	
	# Limpiar contenedor
	for child in collection_container.get_children():
		child.queue_free()
	
	# Mostrar todas las cartas del usuario
	for card_dict in user_cards:
		var card_display = CARD_DISPLAY_TEMPLATE.instantiate()
		collection_container.add_child(card_display)
		
		# Convertir diccionario a CardData si es necesario
		var card_data: CardData
		if card_dict is CardData:
			card_data = card_dict
		else:
			card_data = _dict_to_card_data(card_dict)
		
		# Configurar display con CardData (cargarÃ¡ imagen automÃ¡ticamente)
		card_display.setup(card_data)
		# Conectar seÃ±al sin bind adicional (emite CardData)
		card_display.card_clicked.connect(_on_collection_card_clicked)

func display_deck_cards():
	"""Muestra las cartas actuales en el mazo"""
	if not deck_container:
		return
	
	# Limpiar contenedor
	for child in deck_container.get_children():
		child.queue_free()
	
	# Mostrar mensaje si el mazo estÃ¡ vacÃ­o
	if deck_cards.is_empty():
		var label = Label.new()
		label.text = "Mazo vacÃ­o\nAgrega cartas desde tu colecciÃ³n"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		deck_container.add_child(label)
		return
	
	# Mostrar cartas del mazo
	for card_id in deck_cards.keys():
		var card_dict = find_card_dict_by_id(card_id)
		if card_dict == null:
			continue
		
		var card_display = CARD_DISPLAY_TEMPLATE.instantiate()
		deck_container.add_child(card_display)
		
		# Convertir diccionario a CardData
		var card_data: CardData
		if card_dict is CardData:
			card_data = card_dict
		else:
			card_data = _dict_to_card_data(card_dict)
		
		card_display.setup(card_data)
		# Conectar seÃ±al sin bind adicional (emite CardData)
		card_display.card_clicked.connect(_on_deck_card_clicked)
		
		# Indicador de cantidad
		var quantity_label = Label.new()
		quantity_label.text = "x%d" % deck_cards[card_id]
		quantity_label.add_theme_font_size_override("font_size", 20)
		quantity_label.add_theme_color_override("font_color", Color.YELLOW)
		quantity_label.position = Vector2(10, 10)
		card_display.add_child(quantity_label)
		
		# Botón de portada (estrella) en esquina superior derecha
		var is_cover = current_deck.get("deck_cover_card_id", "") == card_id
		var cover_btn = Button.new()
		cover_btn.text = "★" if is_cover else "☆"
		cover_btn.tooltip_text = "Portada del mazo" if is_cover else "Usar como portada"
		cover_btn.add_theme_font_size_override("font_size", 16)
		cover_btn.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0) if is_cover else Color.WHITE)
		cover_btn.flat = true
		cover_btn.size = Vector2(26, 26)
		cover_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		cover_btn.position = Vector2(-30, 4)
		cover_btn.pressed.connect(_on_set_cover_card.bind(card_id))
		card_display.add_child(cover_btn)

func _on_collection_card_clicked(card: CardData):
	"""Mostrar detalle de carta con opciÃ³n de agregar al mazo"""
	var tex: ImageTexture = null
	if card and CardsManager._image_cache.has(card.id):
		tex = CardsManager._image_cache[card.id]
	card_detail_view.show_card(card, tex, true)

func _on_deck_card_clicked(card: CardData):
	"""Mostrar detalle de carta del mazo con opciÃ³n de quitar"""
	var tex: ImageTexture = null
	if card and CardsManager._image_cache.has(card.id):
		tex = CardsManager._image_cache[card.id]
	card_detail_view.show_card(card, tex, false, true)

func _on_detail_add_requested(card: CardData):
	"""Callback del detalle para agregar carta al mazo"""
	var card_id = card.id
	
	# Verificar cantidad disponible en la colecciÃ³n
	var owned_quantity = get_user_card_quantity(card_id)
	if owned_quantity == 0:
		show_error("Carta no disponible en tu colecciÃ³n")
		return
	
	var current_in_deck = deck_cards.get(card_id, 0)
	
	if current_in_deck >= owned_quantity:
		show_error("No tienes mÃ¡s copias disponibles de esta carta")
		return
	
	# Usar max_copies de la carta o valor por defecto
	var max_allowed = card.max_copies if card.max_copies > 0 else MAX_COPIES_PER_CARD
	
	# Verificar lÃ­mites
	if current_in_deck >= max_allowed:
		if card.unique:
			show_error("'%s' es una carta Ãºnica (mÃ¡ximo 1 copia)" % card.name)
		else:
			show_error("MÃ¡ximo %d copias de '%s'" % [max_allowed, card.name])
		return
	
	if get_total_deck_size() >= MAX_DECK_SIZE:
		show_error("MÃ¡ximo %d cartas en el mazo" % MAX_DECK_SIZE)
		return
	
	# Agregar
	deck_cards[card_id] = current_in_deck + 1
	is_modified = true
	display_deck_cards()
	update_deck_stats()
	validate_deck()

func _on_detail_remove_requested(card: CardData):
	"""Callback del detalle para quitar carta del mazo"""
	var card_id = card.id
	if deck_cards.has(card_id):
		deck_cards[card_id] -= 1
		if deck_cards[card_id] <= 0:
			deck_cards.erase(card_id)
	is_modified = true
	display_deck_cards()
	update_deck_stats()
	validate_deck()

func _on_card_dropped_to_deck(card: CardData):
	"""Callback cuando se arrastra una carta al mazo"""
	_on_detail_add_requested(card)

func get_total_deck_size() -> int:
	"""Calcula el total de cartas en el mazo"""
	var total = 0
	for quantity in deck_cards.values():
		total += quantity
	return total

func update_deck_stats():
	"""Actualiza las estadÃ­sticas del mazo"""
	var total = get_total_deck_size()
	deck_stats_label.text = "%d/%d cartas" % [total, MAX_DECK_SIZE]
	
	# Actualizar color segÃºn validez
	if total < MIN_DECK_SIZE or total > MAX_DECK_SIZE:
		deck_stats_label.add_theme_color_override("font_color", Color.RED)
	else:
		deck_stats_label.add_theme_color_override("font_color", Color.GREEN)


func validate_deck() -> bool:
	"""Valida si el mazo cumple con las reglas"""
	var total = get_total_deck_size()
	var is_valid = total >= MIN_DECK_SIZE and total <= MAX_DECK_SIZE
	
	# Actualizar botÃ³n de guardar
	save_button.disabled = not is_valid or not is_modified
	
	# Validar contra el servidor si el deck ya existe
	var deck_id = current_deck.get("id", "")
	if deck_id != "" and total > 0:
		DecksManager.validate_deck(deck_id)
	else:
		# ValidaciÃ³n local bÃ¡sica
		if not is_valid:
			if total < MIN_DECK_SIZE:
				validation_label.text = "âš  Necesitas al menos %d cartas" % MIN_DECK_SIZE
				validation_label.add_theme_color_override("font_color", Color.ORANGE)
			elif total > MAX_DECK_SIZE:
				validation_label.text = "âš  MÃ¡ximo %d cartas permitidas" % MAX_DECK_SIZE
				validation_label.add_theme_color_override("font_color", Color.RED)
		else:
			validation_label.text = ""
	
	return is_valid


# ============================================================
#   DECK BACK (DORSO) MANAGEMENT
# ============================================================

func _load_available_deck_backs() -> void:
	"""Cargar dorsos disponibles desde el servidor"""
	print("[DeckBuilder] ðŸ“¥ Iniciando carga de dorsos disponibles...")
	
	# Mostrar loader
	if loading_label:
		loading_label.visible = true
		loading_label.text = "Cargando dorsos..."
		print("[DeckBuilder] â„¹ï¸  Loader activado")
	
	var callback = func(success: bool, data: Variant, error: String) -> void:
		print("[DeckBuilder] ðŸ“¡ Respuesta del servidor - Success: %s, Data type: %s" % [success, typeof(data)])
		
		# Ocultar loader
		if loading_label:
			loading_label.visible = false
		
		if not success:
			print("[DeckBuilder] âŒ Error cargando dorsos: '%s'" % error)
			show_error("Error al cargar dorsos: " + error)
			return
		
		# Verificar que tenemos datos
		if data == null:
			print("[DeckBuilder] âš ï¸  Respuesta nula del servidor")
			show_error("El servidor devolviÃ³ una respuesta vacÃ­a")
			return
		
		# Type detection para array directo vs diccionario
		if data is Array:
			print("[DeckBuilder] âœ… Respuesta es Array directamente - %d dorsos" % data.size())
			available_deck_backs = data
		elif data is Dictionary:
			print("[DeckBuilder] âœ… Respuesta es Dictionary")
			# Intentar obtener la lista del diccionario
			if data.has("data"):
				available_deck_backs = data["data"] if data["data"] is Array else [data["data"]]
				print("[DeckBuilder] âœ… ExtraÃ­do array de 'data' - %d dorsos" % available_deck_backs.size())
			else:
				# Si no hay "data", asumir que el diccionario mismo es la respuesta
				available_deck_backs = [data]
				print("[DeckBuilder] âš ï¸  Sin campo 'data', usando el diccionario completo")
		else:
			print("[DeckBuilder] âŒ Tipo de respuesta inesperado: %s" % typeof(data))
			show_error("Formato de respuesta inesperado del servidor")
			return
		
		# Validar que cada dorso tenga campos requeridos
		var valid_count = 0
		for back in available_deck_backs:
			if back is Dictionary and back.has("id") and back.has("name"):
				valid_count += 1
			else:
				print("[DeckBuilder] âš ï¸  Dorso invÃ¡lido: %s" % str(back))
		
		print("[DeckBuilder] âœ… %d dorsos vÃ¡lidos de %d cargados" % [valid_count, available_deck_backs.size()])
		
		if available_deck_backs.is_empty():
			print("[DeckBuilder] âš ï¸  NingÃºn dorso disponible para el usuario")
		else:
			print("[DeckBuilder] ðŸŽ¨ Primer dorso: %s" % available_deck_backs[0].get("name", "Sin nombre"))
		
		_display_deck_back_options()
		_update_deck_back_preview()
	
	ApiClient.get_request_with_callback(
		"/profile/deck-backs",
		"load_deck_backs",
		callback
	)


func _display_deck_back_options() -> void:
	"""Mostrar opciones de dorsos disponibles en la solapa"""
	# Limpiar opciones anteriores
	for child in available_dorsos_grid.get_children():
		child.queue_free()
	
	if available_deck_backs.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No hay dorsos disponibles"
		empty_label.add_theme_font_size_override("font_size", 14)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		available_dorsos_grid.add_child(empty_label)
		return
	
	print("[DeckBuilder] ðŸŽ¨ Creando %d tarjetas de dorsos" % available_deck_backs.size())
	
	# Crear botÃ³n con preview para cada dorso
	for back in available_deck_backs:
		var back_panel = PanelContainer.new()
		back_panel.custom_minimum_size = Vector2(140, 200)
		available_dorsos_grid.add_child(back_panel)
		
		var back_vbox = VBoxContainer.new()
		back_panel.add_child(back_vbox)
		
		# Nombre del dorso
		var name_label = Label.new()
		name_label.text = back.get("name", "Dorso")
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		back_vbox.add_child(name_label)
		
		# Rarity badge (opcional)
		if back.has("rarity"):
			var rarity_label = Label.new()
			rarity_label.text = "[%s]" % back.get("rarity", "").to_upper()
			rarity_label.add_theme_font_size_override("font_size", 9)
			rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			rarity_label.add_theme_color_override("font_color", Color.YELLOW)
			back_vbox.add_child(rarity_label)
		
		# Preview de la imagen
		var preview = TextureRect.new()
		preview.custom_minimum_size = Vector2(130, 140)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_SCALE
		back_vbox.add_child(preview)
		
		# Cargar imagen del dorso
		var image_url = back.get("image_url", "")
		if not image_url.is_empty():
			_loading_dorso_images += 1
			print("[DeckBuilder] ðŸ“¥ Iniciando carga de imagen %d - %s" % [_loading_dorso_images, back.get("name", "")])
			if loading_label and not loading_label.visible:
				loading_label.visible = true
				loading_label.text = "Cargando imÃ¡genes..."

			var image_callback = func(image: Image, _tag = null) -> void:
				if image:
					var texture = ImageTexture.create_from_image(image)
					preview.texture = texture
					print("[DeckBuilder] âœ… Imagen cargada: %s" % back.get("name", ""))
				else:
					print("[DeckBuilder] âš ï¸  No se pudo cargar imagen de: %s" % image_url)

				# Decrementar contador
				_loading_dorso_images -= 1
				print("[DeckBuilder] ðŸ“Š ImÃ¡genes pendientes: %d" % _loading_dorso_images)

				# Ocultar loader cuando terminen todas
				if _loading_dorso_images <= 0 and loading_label:
					loading_label.visible = false
					_loading_dorso_images = 0

			ApiClient.get_image_with_callback(
				image_url,
				image_callback,
				"available_back_%s" % back.get("id", "")
			)
		
		# BotÃ³n para seleccionar
		var select_btn = Button.new()
		var back_id = back.get("id", "")
		var is_selected = selected_deck_back.get("id") == back_id
		select_btn.set_meta("back_id", back_id)
		select_btn.text = "âœ“ Seleccionado" if is_selected else "Seleccionar"
		select_btn.disabled = is_selected
		select_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		select_btn.pressed.connect(_on_deck_back_selected.bind(back))
		back_vbox.add_child(select_btn)


func _update_deck_back_preview() -> void:
	"""Actualizar preview del dorso actual en la solapa"""
	if selected_deck_back.is_empty():
		current_dorso_name.text = "Sin dorso"
		current_dorso_preview.texture = null
		return
	
	current_dorso_name.text = selected_deck_back.get("name", "Desconocido")
	
	var image_url = selected_deck_back.get("image_url", "")
	if not image_url.is_empty():
		var callback = func(image: Image, _tag = null) -> void:
			if image:
				var texture = ImageTexture.create_from_image(image)
				current_dorso_preview.texture = texture
		
		ApiClient.get_image_with_callback(
			image_url,
			callback,
			"current_dorso_preview_%s" % selected_deck_back.get("id", "")
		)
	
	# Actualizar botones de selecciÃ³n
	var selected_back_id = selected_deck_back.get("id", "")
	for child in available_dorsos_grid.get_children():
		if child is PanelContainer:
			var vbox = child.get_child(0)
			if vbox is VBoxContainer and vbox.get_child_count() >= 3:
				var btn = vbox.get_child(vbox.get_child_count() - 1)
				if btn is Button:
					var is_selected = btn.has_meta("back_id") and btn.get_meta("back_id") == selected_back_id
					if is_selected:
						btn.text = "âœ“ Seleccionado"
						btn.disabled = true
					else:
						btn.text = "Seleccionar"
						btn.disabled = false


func _animate_selection_feedback() -> void:
	"""Animar feedback visual cuando se selecciona un dorso"""
	var tween = create_tween()
	tween.set_parallel(true)  # Ejecutar en paralelo
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	
	# Escalar levemente el preview del dorso actual
	tween.tween_property(current_dorso_preview, "scale", Vector2(1.1, 1.1), 0.3)
	
	# Esperar y volver a tamaÃ±o original
	await tween.finished
	var tween2 = create_tween()
	tween2.set_trans(Tween.TRANS_SINE)
	tween2.set_ease(Tween.EASE_OUT)
	tween2.tween_property(current_dorso_preview, "scale", Vector2(1.0, 1.0), 0.2)

func _on_deck_back_selected(back: Dictionary) -> void:
	"""Cuando el usuario selecciona un dorso"""
	selected_deck_back = back
	_display_deck_back_options()
	_update_deck_back_preview()
	_save_deck_back_selection()
	
	# Animar la selecciÃ³n
	_animate_selection_feedback()


func _save_deck_back_selection() -> void:
	"""Guardar la selecciÃ³n del dorso en el servidor"""
	var deck_id = current_deck.get("id", "")
	var back_id = selected_deck_back.get("id", "")
	
	if deck_id.is_empty() or back_id.is_empty():
		print("[DeckBuilder] No se puede guardar dorso sin deck_id o back_id")
		return
	
	var body = {
		"deck_id": deck_id,
		"deck_back_id": back_id
	}
	
	var callback = func(success: bool, data: Variant, error: String) -> void:
		if success:
			print("[DeckBuilder] Dorso guardado correctamente")
			current_deck["current_deck_back_id"] = back_id
			show_error("Dorso guardado automáticamente", Color.GREEN)
		else:
			print("[DeckBuilder] Error guardando dorso: " + error)
			show_error("Error al guardar dorso: " + error, Color.RED)
	
	ApiClient.put_request_with_callback(
		"/profile/deck-back",
		body,
		"save_deck_back",
		callback
	)


# ============================================================
#   COVER CARD
# ============================================================

func _on_set_cover_card(card_id: String) -> void:
	"""Establece (o quita) la carta de portada del mazo"""
	var deck_id = current_deck.get("id", "")
	if deck_id.is_empty():
		return
	
	# Toggle: si ya es portada, limpiar
	var new_cover_id = null if current_deck.get("deck_cover_card_id", "") == card_id else card_id
	
	var callback = func(success: bool, _data: Variant, error: String) -> void:
		if not success:
			show_error("Error al guardar portada: " + error)
			return
		current_deck["deck_cover_card_id"] = new_cover_id
		display_deck_cards()
		show_error("Portada guardada automáticamente", Color.GREEN)
	
	var body = { "card_id": new_cover_id }
	ApiClient.put_request_with_callback(
		"/decks/%s/cover-card" % deck_id,
		body,
		"set_cover_card",
		callback
	)


func find_card_dict_by_id(card_id: String):
	"""Busca una carta (como diccionario) por ID en la colecciÃ³n del usuario"""
	for card in user_cards:
		if card is CardData and card.id == card_id:
			return card
		if card is Dictionary and card.get("id", "") == card_id:
			return card
	return null

func find_card_by_id(card_id: String) -> CardData:
	"""Busca una carta (CardData) por ID en la colecciÃ³n del usuario"""
	var card_dict = find_card_dict_by_id(card_id)
	if card_dict == null:
		return null
	
	if card_dict is CardData:
		return card_dict
	else:
		return _dict_to_card_data(card_dict)

func get_user_card_quantity(card_id: String) -> int:
	"""Obtiene la cantidad disponible de una carta en la colecciÃ³n del usuario"""
	# Buscar en user_cards directamente (como diccionarios)
	for card_dict in user_cards:
		if card_dict is Dictionary and card_dict.get("id", "") == card_id:
			# La cantidad viene en UserCard.quantity
			return card_dict.get("quantity", 0)
	return 0



# SeÃ±ales de UI
func _on_back_pressed():
	"""Volver a la pantalla anterior"""
	if is_modified:
		# TODO: Mostrar diÃ¡logo de confirmaciÃ³n para cambios no guardados
		show_error("Tienes cambios sin guardar")
		return
	
	# Limpiar pendientes antes de volver
	SceneTransition.pending_deck_data.clear()
	
	# Volver al menÃº de mazos
	SceneTransition.go_to_mainlobby()

func _on_save_pressed():
	"""Guardar cambios en el mazo"""
	if not validate_deck():
		return
	
	loading_label.visible = true
	var deck_id = current_deck.get("id", "")
	
	# Preparar array de cartas para sincronizar
	var cards_array = []
	for card_id in deck_cards:
		cards_array.append({
			"card_id": card_id,
			"quantity": deck_cards[card_id]
		})
	
	# Sincronizar todas las cartas del deck en una sola llamada
	DecksManager.sync_deck_cards(deck_id, cards_array)

func _on_set_active_pressed():
	"""Marcar el mazo como activo"""
	loading_label.visible = true
	var deck_id = current_deck.get("id", "")
	var deck_name = current_deck.get("name", "")
	var desc = current_deck.get("description", "")
	DecksManager.update_deck(deck_id, deck_name, desc, true)



# SeÃ±ales de Managers
func _on_deck_updated(deck: Dictionary):
	"""Callback cuando se actualiza el mazo (incluye sync exitoso)"""
	loading_label.visible = false
	
	# Actualizar current_deck
	if deck.has("id"):
		var deck_id = deck.get("id", "")
		var current_id = current_deck.get("id", "")
		
		if deck_id == current_id:
			current_deck = deck
			
			# Actualizar estado del botÃ³n activo
			var is_active = deck.get("is_active", false)
			set_active_button.text = "âœ“ Mazo Activo" if is_active else "Marcar como Activo"
			set_active_button.disabled = is_active
			
			# Si tiene cartas, actualizar deck_cards y la vista
			if deck.has("cards"):
				deck_cards.clear()
				var cards = deck.get("cards", [])
				for card in cards:
					var card_id = card.get("id", "")
					var quantity = card.get("DeckCard", {}).get("quantity", 1)
					if card_id != "":
						deck_cards[card_id] = quantity
				
				# Marcar como no modificado despuÃ©s de guardar
				is_modified = false
				display_deck_cards()
				update_deck_stats()	
				validate_deck()  # Update save button state				
				show_error("Mazo guardado correctamente", Color.GREEN)
			else:
				# Si no tiene cartas en la respuesta, solo marcar como guardado
				is_modified = false
				update_deck_stats()
			validate_deck()  # Update save button state

func _on_card_added(_deck_id: String, _card_id: String):
	_refresh_deck_from_server()

func _on_card_removed(_deck_id: String, _card_id: String):
	"""Callback cuando se remueve una carta del mazo"""
	loading_label.visible = false

func _on_deck_validated(validation: Dictionary):
	"""Callback cuando se valida el mazo desde el servidor"""
	var is_valid = validation.get("valid", false)
	var errors = validation.get("errors", [])
	var warnings = validation.get("warnings", [])
	
	if not is_valid and errors.size() > 0:
		# Mostrar primer error
		validation_label.text = "❌ " + errors[0]
		validation_label.add_theme_color_override("font_color", Color.RED)
		save_button.disabled = true
	elif warnings.size() > 0:
		# Mostrar primera advertencia
		validation_label.text = "⚠ " + warnings[0]
		validation_label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		# Deck valido sin advertencias
		validation_label.text = "✓ Mazo valido"
		validation_label.add_theme_color_override("font_color", Color.GREEN)

func _on_error_occurred(error_message: String):
	"""Callback cuando ocurre un error"""
	loading_label.visible = false
	show_error(error_message)

func _on_card_image_loaded(card_id: String, texture: ImageTexture):
	# Actualizar imagenes en coleccion
	for child in collection_container.get_children():
		if child.has_method("set_card_image") and "card_data" in child and child.card_data and child.card_data.id == card_id:
			child.set_card_image(texture)
	# Actualizar imagenes en mazo
	for child in deck_container.get_children():
		if child.has_method("set_card_image") and "card_data" in child and child.card_data and child.card_data.id == card_id:
			child.set_card_image(texture)

func _on_deck_generated(deck: Dictionary, info: Dictionary):
	"""Callback cuando se genera el deck automaticamente"""
	loading_label.visible = false
	
	# Actualizar current_deck con el deck generado
	current_deck = deck
	
	# Actualizar deck_cards con las nuevas cartas
	deck_cards.clear()
	var cards = deck.get("cards", [])
	for card in cards:
		var card_id = card.get("id", "")
		var quantity = card.get("DeckCard", {}).get("quantity", 1)
		if card_id != "":
			deck_cards[card_id] = quantity
	
	# Marcar como no modificado porque el backend ya guardÃ³ el deck generado.
	is_modified = false
	
	# Actualizar vistas
	display_deck_cards()
	update_deck_stats()
	validate_deck()  # This will disable the save button since is_modified = false
	
	# Mostrar informacion de generacion
	var stats = info.get("stats", {})
	var total = stats.get("total_cards", 0)
	var avg_cost = stats.get("avg_cost", 0)
	var strategy = info.get("strategy_used", "balanced")
	
	show_error("✅ Mazo generado y guardado: %d cartas, costo promedio: %.1f\nEstrategia: %s" % [total, avg_cost, strategy], Color.GREEN)

func _on_auto_generate_pressed():
	"""Mostrar dialogo de seleccion de estrategia"""
	# TODO: Crear dialogo con opciones de estrategia
	# Por ahora, usar estrategia balanceada
	var deck_id = current_deck.get("id", "")
	if deck_id == "":
		show_error("Error: No hay mazo cargado")
		return
	
	loading_label.visible = true
	loading_label.text = "Generando mazo balanceado..."
	
	DecksManager.auto_generate_deck(deck_id, "balanced")

# Utilidades
func _dict_to_card_data(card_dict: Dictionary) -> CardData:
	"""Convierte un diccionario de carta del servidor a un objeto CardData"""
	var card_data = CardData.new()
	
	# Asignar todos los campos disponibles
	card_data.id = card_dict.get("id", "")
	card_data.name = card_dict.get("name", "")
	card_data.type = card_dict.get("type", "")
	card_data.rarity = card_dict.get("rarity", "")
	card_data.card_set = card_dict.get("card_set", "")
	
	# Convertir tags a Array[String]
	var tags_list: Array[String] = []
	for tag in card_dict.get("tags", []):
		tags_list.append(str(tag))
	card_data.tags = tags_list
	
	card_data.power_level = card_dict.get("power_level", 0)
	card_data.faction = card_dict.get("faction", "")
	card_data.element = card_dict.get("element", "")
	
	card_data.cost = card_dict.get("cost", 0)
	card_data.generate = card_dict.get("generate", 0)
	
	card_data.attack = card_dict.get("attack", 0)
	card_data.defense = card_dict.get("defense", 0)
	card_data.health = card_dict.get("health", 0)
	card_data.cosmos = card_dict.get("cosmos", 0)
	card_data.can_defend = card_dict.get("can_defend", true)
	card_data.defense_reduction = card_dict.get("defense_reduction", 0.5)
	
	card_data.max_copies = card_dict.get("max_copies", 3)
	card_data.unique = card_dict.get("unique", false)
	
	# Convertir playable_zones a Array[String]
	var zones_list: Array[String] = []
	for zone in card_dict.get("playable_zones", []):
		zones_list.append(str(zone))
	card_data.playable_zones = zones_list
	
	card_data.image_url = card_dict.get("image_url", "")
	card_data.description = card_dict.get("description", "")
	
	return card_data

func show_error(message: String, color: Color = Color.RED):
	# Muestra un mensaje de error
	error_label.text = message
	error_label.add_theme_color_override("font_color", color)
	error_label.visible = true
	
	# Ocultar despuÃ©s de 3 segundos
	await get_tree().create_timer(3.0).timeout
	error_label.visible = false
