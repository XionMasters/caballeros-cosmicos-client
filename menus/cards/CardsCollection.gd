# CardsCollection.gd
# Pantalla principal de colecciÃ³n de cartas
extends Control

@onready var back_button = $MarginContainer/VBoxContainer/Header/BackButton
@onready var cards_grid: GridContainer = $MarginContainer/VBoxContainer/ScrollContainer/CardsGrid
@onready var filter_buttons: HBoxContainer = $MarginContainer/VBoxContainer/FilterButtons
@onready var loading_label: Label = $MarginContainer/VBoxContainer/LoadingLabel

const CARD_DISPLAY_SCENE = preload("res://cards/CardDisplay.tscn")
const LOADING_SCREEN_SCENE = preload("res://ui/LoadingScreen.tscn")

var current_filter: String = "all"
var all_user_cards: Array[CardData] = []  # Cache de todas las cartas del usuario
var loading_screen: Node = null  # CanvasLayer
var is_showing_collection: bool = false


func _ready():
	# Conectar botÃ³n volver
	back_button.pressed.connect(_on_back_pressed)
	
	# Conectar seÃ±ales del CardsManager global (singleton)
	if CardsManager.has_signal("cards_loaded"):
		CardsManager.cards_loaded.connect(_on_cards_loaded)
	if CardsManager.has_signal("error_occurred"):
		CardsManager.error_occurred.connect(_on_error)
	
	# Conectar signals de carga de colecciÃ³n
	if CardsManager.has_signal("collection_loading_progress"):
		CardsManager.collection_loading_progress.connect(_on_collection_loading_progress)
	if CardsManager.has_signal("collection_images_preloaded"):
		CardsManager.collection_images_preloaded.connect(_on_collection_loading_complete)
	
	# Conectar botones de filtro
	for button in filter_buttons.get_children():
		if button is Button:
			button.pressed.connect(_on_filter_pressed.bind(button.name))
	
	# Cargar cartas del usuario
	_check_collection_and_load()

func _on_back_pressed():
	SceneTransition.go_to_mainlobby()

func _check_collection_and_load() -> void:
	"""Verificar si la colecciÃ³n estÃ¡ lista, mostrar loading si es necesario"""
	print("ðŸ“š Cargando cartas del usuario...")
	
	# Obtener colecciÃ³n del usuario
	var user_cards = _get_user_collection()
	
	if user_cards.size() == 0:
		loading_label.show()
		loading_label.text = "No tienes cartas en tu colecciÃ³n"
		return
	
	# Obtener IDs de cartas Ãºnicas
	var card_ids = []
	for card in user_cards:
		if not card_ids.has(card.id):
			card_ids.append(card.id)
	
	# Verificar si todas las imÃ¡genes estÃ¡n en cache
	var missing_count = 0
	for card_id in card_ids:
		if not CardsManager.has_card_texture(card_id):
			missing_count += 1
	
	if missing_count > 0:
		# Mostrar loading screen
		print("[CardsCollection] ðŸ”„ Faltan %d imÃ¡genes, mostrando loading..." % missing_count)
		_show_loading_screen()
		
		# Iniciar precarga de colecciÃ³n en background
		CardsManager.preload_collection_images(card_ids, "low")
	else:
		# Todas cargadas, mostrar colecciÃ³n
		print("[CardsCollection] âœ… Todas las imÃ¡genes en cache")
		load_user_cards()


func _show_loading_screen() -> void:
	"""Mostrar pantalla de loading"""
	loading_screen = LOADING_SCREEN_SCENE.instantiate()
	# Agregar a la raÃ­z del Ã¡rbol (CanvasLayer debe estar al nivel superior)
	get_tree().root.add_child(loading_screen)
	loading_screen.set_title("Cargando tu colecciÃ³n...")
	is_showing_collection = false


func _get_user_collection() -> Array[CardData]:
	"""Obtener colecciÃ³n del usuario desde CardDatabase"""
	var user_cards: Array[CardData] = []
	
	if not CardDatabase.is_loaded:
		return user_cards
	
	# Por ahora, retornar todas las cartas del CardDatabase
	# En futuro, esto vendrÃ¡ de una API que dice quÃ© cartas tiene el usuario
	return CardDatabase.get_all_cards()


func _on_collection_loading_progress(loaded: int, total: int) -> void:
	"""Callback de progreso de carga"""
	if loading_screen:
		# Loading screen maneja esto automÃ¡ticamente
		pass


func _on_collection_loading_complete() -> void:
	"""Callback cuando termina la precarga de colecciÃ³n"""
	if loading_screen:
		# Cerrar loading screen
		loading_screen.queue_free()
		loading_screen = null
		await get_tree().process_frame  # Esperar un frame para que se cierre
	
	# Reaplicar filtro actual (ahora con imÃ¡genes cargadas)
	if is_showing_collection:
		apply_filter()
	else:
		# Primera carga
		load_user_cards()


func load_user_cards():
	print("ðŸ“š Mostrar colecciÃ³n del usuario...")
	loading_label.hide()
	
	# Obtener colecciÃ³n y mostrar
	all_user_cards = _get_user_collection()
	
	if all_user_cards.size() == 0:
		loading_label.show()
		loading_label.text = "No tienes cartas en tu colecciÃ³n"
		return
	
	is_showing_collection = true
	
	# Aplicar filtro actual
	apply_filter()

func clear_cards():
	print("ðŸ§¹ Limpiando grid de cartas")
	for child in cards_grid.get_children():
		child.queue_free()

func _on_cards_loaded(cards: Array[CardData]):
	print("âœ… Cartas cargadas: ", cards.size())
	loading_label.hide()
	
	# Guardar todas las cartas del usuario
	all_user_cards = cards
	
	if cards.size() == 0:
		loading_label.show()
		loading_label.text = "No tienes cartas en tu colecciÃ³n"
		return
	
	# Aplicar filtro actual
	apply_filter()

func apply_filter():
	clear_cards()
	
	var filtered_cards = all_user_cards
	
	# Filtrar por rareza si no es "all"
	if current_filter != "all":
		filtered_cards = []
		for card in all_user_cards:
			if card.rarity == current_filter:
				filtered_cards.append(card)
	
	if filtered_cards.size() == 0:
		loading_label.show()
		loading_label.text = "No tienes cartas de esta rareza"
		return
	
	# Verificar si todas las imÃ¡genes de cartas filtradas estÃ¡n en cache
	var missing_images = 0
	var card_ids = []
	for card in filtered_cards:
		card_ids.append(card.id)
		if not CardsManager.has_card_texture(card.id):
			missing_images += 1
	
	# Si faltan imÃ¡genes y no estamos mostrando loading, mostrarlo
	if missing_images > 0 and not loading_screen:
		print("[CardsCollection] ðŸ”„ Faltan %d imÃ¡genes en filtro, mostrando loading..." % missing_images)
		_show_loading_screen()
		# Iniciar precarga de cartas filtradas
		CardsManager.preload_collection_images(card_ids, "low")
		return
	
	# Si estamos mostrando loading screen, esperar a que termine
	if loading_screen:
		print("[CardsCollection] â³ Esperando a que LoadingScreen termine...")
		return
	
	# Mostrar cartas filtradas
	loading_label.hide()
	for card in filtered_cards:
		print("  - Agregando carta: ", card.name)
		var card_display = CARD_DISPLAY_SCENE.instantiate()
		cards_grid.add_child(card_display)
		card_display.setup(card)
		card_display.card_clicked.connect(_on_card_clicked)

func _on_card_clicked(card: CardData):
	print("Carta clickeada: ", card.name)
	# Mostrar vista detallada usando el manager global
	CardDetailManager.show_card(card, null)

func _on_filter_pressed(filter_name: String):
	print("ðŸ” Filtro seleccionado: ", filter_name)
	
	# Si estamos cargando, no permitir cambio de filtro
	if loading_screen and not loading_screen.is_queued_for_deletion():
		print("â³ Esperando a que termine la carga...")
		return
	
	match filter_name:
		"AllButton":
			current_filter = "all"
		"CommonButton":
			current_filter = "comun"
		"RareButton":
			current_filter = "rara"
		"EpicButton":
			current_filter = "epica"
		"LegendaryButton":
			current_filter = "legendaria"
	
	apply_filter()

func _on_error(message: String):
	loading_label.text = "Error: " + message
	loading_label.add_theme_color_override("font_color", Color.RED)
