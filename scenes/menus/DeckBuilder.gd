extends Control

# DeckBuilder.gd
# Editor de mazos - permite agregar/quitar cartas de un mazo

const CARD_DISPLAY_TEMPLATE = preload("res://scenes/components/cards/CardDisplay.tscn")
const CARD_DETAIL_VIEW_SCENE = preload("res://scenes/components/cards/CardDetailView.tscn")
const MIN_DECK_SIZE = 40
const MAX_DECK_SIZE = 50
const MAX_COPIES_PER_CARD = 3

# Estado
var current_deck: Dictionary = {}
var user_cards: Array = []
var deck_cards: Dictionary = {}  # card_id -> quantity
var is_modified: bool = false

# Referencias a nodos
@onready var deck_name_label = $MarginContainer/VBoxContainer/Header/DeckInfo/DeckNameLabel
@onready var deck_stats_label = $MarginContainer/VBoxContainer/Header/DeckInfo/DeckStatsLabel
@onready var validation_label = $MarginContainer/VBoxContainer/Header/DeckInfo/ValidationLabel
@onready var back_button = $MarginContainer/VBoxContainer/Header/BackButton
@onready var save_button = $MarginContainer/VBoxContainer/Header/SaveButton
@onready var set_active_button = $MarginContainer/VBoxContainer/Header/SetActiveButton
@onready var auto_generate_button = $MarginContainer/VBoxContainer/Header/AutoGenerateButton
@onready var collection_container = $MarginContainer/VBoxContainer/Content/CollectionPanel/MarginContainer/VBoxContainer/ScrollContainer/CollectionGrid
@onready var deck_container = $MarginContainer/VBoxContainer/Content/DeckPanel/MarginContainer/VBoxContainer/ScrollContainer/DeckGrid
@onready var loading_label = $LoadingLabel
@onready var error_label = $ErrorLabel
var card_detail_view: Control

func _ready():
	# Conectar señales de botones
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
	var deck_panel = $MarginContainer/VBoxContainer/Content/DeckPanel
	deck_panel.card_dropped.connect(_on_card_dropped_to_deck)

	# Conectar señales de managers
	CardsManager.cards_loaded.connect(_on_cards_loaded)
	CardsManager.card_image_loaded.connect(_on_card_image_loaded)
	DecksManager.deck_updated.connect(_on_deck_updated)
	DecksManager.card_added_to_deck.connect(_on_card_added)
	DecksManager.card_removed_from_deck.connect(_on_card_removed)
	DecksManager.deck_validated.connect(_on_deck_validated)
	DecksManager.deck_generated.connect(_on_deck_generated)
	DecksManager.error_occurred.connect(_on_error_occurred)
	
	# Verificar si hay un deck pendiente para cargar
	if SceneTransition.has_pending_deck():
		var deck = SceneTransition.get_pending_deck()
		load_deck(deck)
	
 



func load_deck(deck: Dictionary):
	"""Carga un mazo para editar"""
	current_deck = deck
	deck_name_label.text = deck.get("name", "Sin nombre")
	
	# Actualizar estado del botón de activo
	var is_active = deck.get("is_active", false)
	set_active_button.text = "✓ Mazo Activo" if is_active else "Marcar como Activo"
	set_active_button.disabled = is_active
	
	# Cargar cartas del mazo
	deck_cards.clear()
	var cards = deck.get("cards", [])
	for card in cards:
		var card_id = card.get("id", "")
		var quantity = card.get("DeckCard", {}).get("quantity", 1)
		deck_cards[card_id] = quantity
	
	# Cargar colección del usuario
	loading_label.visible = true
	CardsManager.fetch_user_cards()
	
	# Actualizar estadísticas
	update_deck_stats()
	validate_deck()

func _on_cards_loaded(cards: Array):
	"""Callback cuando se cargan las cartas del usuario"""
	loading_label.visible = false
	user_cards = cards
	display_collection()
	display_deck_cards()



func display_collection():
	"""Muestra las cartas disponibles en la colección"""
	if not collection_container:
		return
	
	# Limpiar contenedor
	for child in collection_container.get_children():
		child.queue_free()
	
	# Mostrar todas las cartas del usuario
	for card in user_cards:
		var card_display = CARD_DISPLAY_TEMPLATE.instantiate()
		collection_container.add_child(card_display)
		
		# user_cards contiene CardData; configurar display directamente
		card_display.setup(card)
		# Conectar señal sin bind adicional (emite CardData)
		card_display.card_clicked.connect(_on_collection_card_clicked)
		
		# Cargar imagen si está en cache
		var card_id = card.id
		if CardsManager._image_cache.has(card_id):
			card_display.set_card_image(CardsManager._image_cache[card_id])
		elif card.image_url != "":
			CardsManager.fetch_card_image(card_id, card.image_url)

func display_deck_cards():
	"""Muestra las cartas actuales en el mazo"""
	if not deck_container:
		return
	
	# Limpiar contenedor
	for child in deck_container.get_children():
		child.queue_free()
	
	# Mostrar mensaje si el mazo está vacío
	if deck_cards.is_empty():
		var label = Label.new()
		label.text = "Mazo vacío\nAgrega cartas desde tu colección"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		deck_container.add_child(label)
		return
	
	# Mostrar cartas del mazo
	for card_id in deck_cards.keys():
		var card = find_card_by_id(card_id)
		if card == null:
			continue
		
		var card_display = CARD_DISPLAY_TEMPLATE.instantiate()
		deck_container.add_child(card_display)
		
		card_display.setup(card)
		# Conectar señal sin bind adicional (emite CardData)
		card_display.card_clicked.connect(_on_deck_card_clicked)
		
		# Indicador de cantidad
		var quantity_label = Label.new()
		quantity_label.text = "x%d" % deck_cards[card_id]
		quantity_label.add_theme_font_size_override("font_size", 20)
		quantity_label.add_theme_color_override("font_color", Color.YELLOW)
		quantity_label.position = Vector2(10, 10)
		card_display.add_child(quantity_label)
		
		# Cargar imagen si está en cache o solicitarla
		if CardsManager._image_cache.has(card_id):
			card_display.set_card_image(CardsManager._image_cache[card_id])
		elif card.image_url != "":
			CardsManager.fetch_card_image(card_id, card.image_url)

func _on_collection_card_clicked(card: CardData):
	"""Mostrar detalle de carta con opción de agregar al mazo"""
	var tex: ImageTexture = null
	if card and CardsManager._image_cache.has(card.id):
		tex = CardsManager._image_cache[card.id]
	card_detail_view.show_card(card, tex, true)

func _on_deck_card_clicked(card: CardData):
	"""Mostrar detalle de carta del mazo con opción de quitar"""
	var tex: ImageTexture = null
	if card and CardsManager._image_cache.has(card.id):
		tex = CardsManager._image_cache[card.id]
	card_detail_view.show_card(card, tex, false, true)

func _on_detail_add_requested(card: CardData):
	"""Callback del detalle para agregar carta al mazo"""
	var card_id = card.id
	
	# Verificar cantidad disponible en la colección
	var owned_quantity = get_user_card_quantity(card_id)
	if owned_quantity == 0:
		show_error("Carta no disponible en tu colección")
		return
	
	var current_in_deck = deck_cards.get(card_id, 0)
	
	if current_in_deck >= owned_quantity:
		show_error("No tienes más copias disponibles de esta carta")
		return
	
	# Usar max_copies de la carta o valor por defecto
	var max_allowed = card.max_copies if card.max_copies > 0 else MAX_COPIES_PER_CARD
	
	# Verificar límites
	if current_in_deck >= max_allowed:
		if card.unique:
			show_error("'%s' es una carta única (máximo 1 copia)" % card.name)
		else:
			show_error("Máximo %d copias de '%s'" % [max_allowed, card.name])
		return
	
	if get_total_deck_size() >= MAX_DECK_SIZE:
		show_error("Máximo %d cartas en el mazo" % MAX_DECK_SIZE)
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
	"""Actualiza las estadísticas del mazo"""
	var total = get_total_deck_size()
	deck_stats_label.text = "%d/%d cartas" % [total, MAX_DECK_SIZE]
	
	# Actualizar color según validez
	if total < MIN_DECK_SIZE or total > MAX_DECK_SIZE:
		deck_stats_label.add_theme_color_override("font_color", Color.RED)
	else:
		deck_stats_label.add_theme_color_override("font_color", Color.GREEN)


func validate_deck() -> bool:
	"""Valida si el mazo cumple con las reglas"""
	var total = get_total_deck_size()
	var is_valid = total >= MIN_DECK_SIZE and total <= MAX_DECK_SIZE
	
	# Actualizar botón de guardar
	save_button.disabled = not is_valid or not is_modified
	
	# Validar contra el servidor si el deck ya existe
	var deck_id = current_deck.get("id", "")
	if deck_id != "" and total > 0:
		DecksManager.validate_deck(deck_id)
	else:
		# Validación local básica
		if not is_valid:
			if total < MIN_DECK_SIZE:
				validation_label.text = "⚠ Necesitas al menos %d cartas" % MIN_DECK_SIZE
				validation_label.add_theme_color_override("font_color", Color.ORANGE)
			elif total > MAX_DECK_SIZE:
				validation_label.text = "⚠ Máximo %d cartas permitidas" % MAX_DECK_SIZE
				validation_label.add_theme_color_override("font_color", Color.RED)
		else:
			validation_label.text = ""
	
	return is_valid



func find_card_by_id(card_id: String):
	"""Busca una carta (CardData) por ID en la colección del usuario"""
	for card in user_cards:
		if card.id == card_id:
			return card
	return null

func get_user_card_quantity(card_id: String) -> int:
	"""Obtiene la cantidad disponible de una carta en la colección del usuario"""
	var card = find_card_by_id(card_id)
	if card == null:
		return 0
	# Acceder directamente a la propiedad user_quantity
	return card.user_quantity



# Señales de UI
func _on_back_pressed():
	"""Volver a la pantalla anterior"""
	if is_modified:
		# TODO: Mostrar diálogo de confirmación para cambios no guardados
		show_error("Tienes cambios sin guardar")
		return
	
	# Volver al menú principal
	get_tree().change_scene_to_file("res://scenes/menus/MainLobby.tscn")

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



# Señales de Managers
func _on_deck_updated(deck: Dictionary):
	"""Callback cuando se actualiza el mazo (incluye sync exitoso)"""
	loading_label.visible = false
	
	# Actualizar current_deck
	if deck.has("id"):
		var deck_id = deck.get("id", "")
		var current_id = current_deck.get("id", "")
		
		if deck_id == current_id:
			current_deck = deck
			
			# Actualizar estado del botón activo
			var is_active = deck.get("is_active", false)
			set_active_button.text = "✓ Mazo Activo" if is_active else "Marcar como Activo"
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
				
				# Marcar como no modificado después de guardar
				is_modified = false
				display_deck_cards()
				update_deck_stats()
				show_error("Mazo guardado correctamente", Color.GREEN)
			else:
				# Si no tiene cartas en la respuesta, solo marcar como guardado
				is_modified = false
				update_deck_stats()
				show_error("Mazo actualizado correctamente", Color.GREEN)

func _on_card_added(_deck_id: String, _card_id: String):
	"""Callback cuando se agrega una carta al mazo"""
	loading_label.visible = false

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
		# Deck válido sin advertencias
		validation_label.text = "✓ Mazo válido"
		validation_label.add_theme_color_override("font_color", Color.GREEN)

func _on_error_occurred(error_message: String):
	"""Callback cuando ocurre un error"""
	loading_label.visible = false
	show_error(error_message)

func _on_card_image_loaded(card_id: String, texture: ImageTexture):
	# Actualizar imágenes en colección
	for child in collection_container.get_children():
		if child.has_method("set_card_image") and "card_data" in child and child.card_data and child.card_data.id == card_id:
			child.set_card_image(texture)
	# Actualizar imágenes en mazo
	for child in deck_container.get_children():
		if child.has_method("set_card_image") and "card_data" in child and child.card_data and child.card_data.id == card_id:
			child.set_card_image(texture)

func _on_deck_generated(deck: Dictionary, info: Dictionary):
	"""Callback cuando se genera el deck automáticamente"""
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
	
	# Marcar como NO modificado (el deck ya fue guardado automáticamente)
	is_modified = false
	save_button.disabled = true  # Deshabilitar botón guardar
	
	# Actualizar vistas
	display_deck_cards()
	update_deck_stats()
	validate_deck()
	
	# Mostrar información de generación
	var stats = info.get("stats", {})
	var total = stats.get("total_cards", 0)
	var avg_cost = stats.get("avg_cost", 0)
	var strategy = info.get("strategy_used", "balanced")
	
	show_error("✅ Mazo generado y guardado: %d cartas, costo promedio: %.1f\nEstrategia: %s" % [total, avg_cost, strategy], Color.GREEN)

func _on_auto_generate_pressed():
	"""Mostrar diálogo de selección de estrategia"""
	# TODO: Crear diálogo con opciones de estrategia
	# Por ahora, usar estrategia balanceada
	var deck_id = current_deck.get("id", "")
	if deck_id == "":
		show_error("Error: No hay mazo cargado")
		return
	
	loading_label.visible = true
	loading_label.text = "Generando mazo balanceado..."
	
	DecksManager.auto_generate_deck(deck_id, "balanced")

# Utilidades
func show_error(message: String, color: Color = Color.RED):
	# Muestra un mensaje de error
	error_label.text = message
	error_label.add_theme_color_override("font_color", color)
	error_label.visible = true
	
	# Ocultar después de 3 segundos
	await get_tree().create_timer(3.0).timeout
	error_label.visible = false
