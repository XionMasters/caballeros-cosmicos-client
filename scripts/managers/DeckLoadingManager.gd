# DeckLoadingManager.gd
# Gestor genérico para carga asíncrona de mazos y cartas
# Reutilizable por TestBoard, GameBoard, y otros
class_name DeckLoadingManager
extends Node

signal deck_loading_started
signal deck_cards_loaded(cards: Array[CardData])
signal all_images_loaded
signal loading_progress(current: int, total: int)
signal loading_complete

var is_loading: bool = false
var loaded_cards: Array[CardData] = []
var _total_cards_to_load: int = 0
var _images_loaded: int = 0


func _ready() -> void:
	# Conectar señal de imágenes cargadas del CardsManager
	if CardsManager and not CardsManager.card_image_loaded.is_connected(_on_card_image_loaded):
		CardsManager.card_image_loaded.connect(_on_card_image_loaded)


func fetch_and_load_active_deck() -> void:
	"""Obtener el mazo activo del usuario y cargar todas sus cartas"""
	is_loading = true
	deck_loading_started.emit()
	
	# Conectar a DecksManager
	if DecksManager.has_signal("decks_loaded") and not DecksManager.decks_loaded.is_connected(_on_decks_loaded):
		DecksManager.decks_loaded.connect(_on_decks_loaded)
	
	DecksManager.fetch_user_decks()


func _on_decks_loaded(decks: Array) -> void:
	"""Callback cuando los mazos se cargan"""
	if decks.is_empty():
		print("[DeckLoadingManager] No hay mazos disponibles")
		_finish_loading()
		return
	
	# Obtener mazo activo
	var active_deck = null
	for deck in decks:
		if deck.get("is_active", false):
			active_deck = deck
			break
	
	if not active_deck and decks.size() > 0:
		active_deck = decks[0]
	
	if not active_deck:
		print("[DeckLoadingManager] No hay mazo activo")
		_finish_loading()
		return
	
	var deck_id = active_deck.get("id", "")
	print("[DeckLoadingManager] Cargando mazo: %s" % active_deck.get("name", "Unknown"))
	_fetch_deck_cards(deck_id)


func _fetch_deck_cards(deck_id: String) -> void:
	"""Obtener cartas del mazo del servidor"""
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_deck_cards_loaded.bind(http))
	
	var headers = AuthManager.get_auth_headers()
	var url = GameConfig.API_URL + "/decks/" + deck_id + "/cards"
	
	print("[DeckLoadingManager] Fetching cards from: %s" % url)
	http.request(url, headers)


func _on_deck_cards_loaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	"""Procesar cartas cargadas"""
	http.queue_free()
	
	if response_code != 200:
		print("[DeckLoadingManager] HTTP error: %d" % response_code)
		_finish_loading()
		return
	
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data or not data is Array or data.is_empty():
		print("[DeckLoadingManager] Respuesta inválida o vacía")
		_finish_loading()
		return
	
	print("[DeckLoadingManager] Cargadas %d cartas" % data.size())
	
	# Convertir a CardData
	loaded_cards.clear()
	_total_cards_to_load = data.size()
	_images_loaded = 0
	
	# Deduplicar URLs
	var unique_urls: Dictionary = {}
	for card_json in data:
		var card_data = CardData.from_json(card_json)
		loaded_cards.append(card_data)
		
		if card_data.image_url and not card_data.image_url.is_empty():
			if not unique_urls.has(card_data.id):
				unique_urls[card_data.id] = card_data.image_url
	
	_total_cards_to_load = unique_urls.size()
	print("[DeckLoadingManager] Imágenes únicas a cargar: %d / %d" % [_total_cards_to_load, loaded_cards.size()])
	
	# Emitir signal cuando las cartas están cargadas
	deck_cards_loaded.emit(loaded_cards)
	
	# Cargar imágenes
	_load_card_images(unique_urls)


func _load_card_images(unique_urls: Dictionary) -> void:
	"""Cargar todas las imágenes únicas del mazo"""
	if unique_urls.is_empty():
		_finish_loading()
		return
	
	for card_id in unique_urls.keys():
		var url = unique_urls[card_id]
		
		# Verificar si ya está en caché
		if CardsManager._image_cache.has(card_id):
			_images_loaded += 1
		else:
			CardsManager.fetch_card_image(card_id, url)
	
	_check_loading_complete()


func _on_card_image_loaded(_card_id: String, _texture: Texture2D) -> void:
	"""Callback cuando una imagen se carga"""
	_images_loaded += 1
	loading_progress.emit(_images_loaded, _total_cards_to_load)
	_check_loading_complete()


func _check_loading_complete() -> void:
	"""Verificar si todo está cargado"""
	if _images_loaded >= _total_cards_to_load and _total_cards_to_load > 0:
		_finish_loading()


func _finish_loading() -> void:
	"""Finalizar la carga"""
	is_loading = false
	print("[DeckLoadingManager] ✅ Carga completa!")
	all_images_loaded.emit()
	loading_complete.emit()


func get_deck_cards() -> Array[CardData]:
	"""Obtener las cartas cargadas"""
	return loaded_cards


func draw_cards_from_deck(count: int) -> Array[CardInstance]:
	"""Sacar N cartas del mazo y retornar como CardInstance
	
	Args:
		count: Número de cartas a sacar
	
	Returns:
		Array de CardInstance listos para usar
	"""
	var drawn: Array[CardInstance] = []
	
	for i in range(min(count, loaded_cards.size())):
		var card_data = loaded_cards[0]
		loaded_cards.pop_front()
		var card_instance = CardInstance.from_card_data(card_data, "")
		card_instance.zone = "hand"
		drawn.append(card_instance)
	
	return drawn


func get_remaining_deck_count() -> int:
	"""Obtener cantidad de cartas restantes en el mazo"""
	return loaded_cards.size()

