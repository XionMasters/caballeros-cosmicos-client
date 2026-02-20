# CardsManager.gd
extends Node

# Cache
var _image_cache: Dictionary = {}
var _pending_requests: Dictionary = {}
var _card_back_texture: ImageTexture = null
var _is_loading_card_back: bool = false

# Decks
var _pending_deck_images: int = 0

# Colección
var _pending_collection_images: int = 0
var _collection_total: int = 0
var _collection_loaded: int = 0

# Señales
signal cards_loaded()
signal card_image_loaded(card_id: String, texture: ImageTexture)
signal card_back_loaded(texture: ImageTexture)
signal deck_images_preloaded()
signal collection_loading_progress(loaded: int, total: int)
signal collection_images_preloaded()

func fetch_user_cards() -> void:
	"""Obtener todas las cartas del usuario desde la API"""
	ApiClient.get_request_with_callback(
		"/user-cards",
		"fetch_user_cards",
		func(success: bool, data: Variant, error: String):
			if success and data is Dictionary:
				var cards_array = data.get("data", [])
				if cards_array is Array:
					cards_loaded.emit(cards_array)
				else:
					push_error("CardsManager: Formato inesperado en respuesta de cartas")
			else:
				push_error("CardsManager: Error cargando cartas del usuario: " + error)
	)

func fetch_card_image(card_id: String, image_url: String):
	"""Descarga la imagen de una carta si no está en cache"""
	if _image_cache.has(card_id):
		card_image_loaded.emit(card_id, _image_cache[card_id])
		return
	
	# Validar que la URL sea válida
	if image_url == null or image_url.is_empty():
		push_error("CardsManager: image_url vacía para carta " + card_id)
		# Emitir null para notificar que falló
		card_image_loaded.emit(card_id, null)
		return

	print("CardsManager: Descargando imagen de %s: %s" % [card_id, image_url])	

	ApiClient.get_image_with_callback(
		image_url,
		func(image: Image, _tag = null):
			_on_card_image_loaded(card_id, image)
	)

func _on_card_image_loaded(card_id: String, image: Image) -> void:
	if image == null:
		push_error("CardsManager: Error cargando imagen de carta " + card_id)
		return
	
	var texture := ImageTexture.create_from_image(image)
	_image_cache[card_id] = texture
	card_image_loaded.emit(card_id, texture)

func preload_card_back() -> void:
	if _card_back_texture:
		card_back_loaded.emit(_card_back_texture)
		return
	
	if _is_loading_card_back:
		return
	
	_is_loading_card_back = true
	
	ApiClient.get_image_with_callback(
		"/assets/cards/card_back.png",
		func(image: Image, _tag = null):
			_on_card_back_loaded(image)
	)

func _on_card_back_loaded(image: Image) -> void:
	_is_loading_card_back = false
	
	if image == null:
		push_error("CardsManager: Error cargando dorso")
		card_back_loaded.emit(null)
		return
	
	_card_back_texture = ImageTexture.create_from_image(image)
	card_back_loaded.emit(_card_back_texture)

func get_card_back_texture() -> ImageTexture:
	"""Obtener el dorso cacheado (null si no está cargado)"""
	return _card_back_texture

func preload_deck_images(deck_cards: Array):
	"""Pre-cargar todas las imágenes de un deck antes de la partida
	
	Args:
		deck_cards: Array de objetos con {card_id: String, image_url: String}
	
	⚠️ IMPORTANTE: Esta función es async. Espera a que todas las imágenes terminen de cargar.
	"""
	var cards_to_load := []
	for card_data in deck_cards:
		var card_id = card_data.get("card_id", "")
		if card_id and not _image_cache.has(card_id):
			cards_to_load.append(card_data)
	
	if cards_to_load.is_empty():
		print("[CardsManager] ✅ Todas las imágenes ya están en cache")
		deck_images_preloaded.emit()
		return
	
	print("[CardsManager] 🎴 Precargando %d imágenes..." % cards_to_load.size())
	_pending_deck_images = cards_to_load.size()
	
	for card_data in cards_to_load:
		var card_id = card_data["card_id"]
		var image_url = card_data["image_url"]
		
		ApiClient.get_image_with_callback(
			image_url,
			func(image: Image, _tag = null):
				_on_deck_image_loaded(card_id, image)
		)
	
	# 🔄 Esperar a que se emita la signal deck_images_preloaded
	print("[CardsManager] ⏳ Esperando carga de %d imágenes..." % _pending_deck_images)
	await deck_images_preloaded
	print("[CardsManager] ✅ Precarga completada")

func _on_deck_image_loaded(card_id: String, image: Image) -> void:
	if image:
		_image_cache[card_id] = ImageTexture.create_from_image(image)
	
	_pending_deck_images -= 1
	if _pending_deck_images == 0:
		deck_images_preloaded.emit()

func preload_collection_images(card_ids: Array, priority: String = "low"):
	"""Pre-cargar imágenes de la colección del usuario con priorización
	
	Args:
		card_ids: Array de card_id a precargar
		priority: "high" (mazo activo) o "low" (colección background)
	
	Nota: Si priority=low, los descargables se espacian para no saturar
	"""
	if card_ids.size() == 0:
		return
	
	if not CardDatabase.is_loaded:
		push_warning("⚠️ CardsManager: CardDatabase no está listo para preload_collection")
		return
	
	# Filtrar solo las que no están en cache
	var cards_to_load = []
	for card_id in card_ids:
		if card_id and not _image_cache.has(card_id):
			# Obtener la carta de CardDatabase para tener la URL
			if CardDatabase.is_loaded and CardDatabase.has_card(card_id):
				var card_data = CardDatabase.get_card(card_id)
				cards_to_load.append({
					"card_id": card_id,
					"image_url": card_data.image_url
				})
	
	_collection_total = cards_to_load.size()
	_collection_loaded = 0
	_pending_collection_images = _collection_total

	if _pending_collection_images == 0:
		print("✅ CardsManager: %d imágenes ya en caché" % _image_cache.size())
		# Emitir que completó
		collection_images_preloaded.emit()
		return

	
	print("🔄 CardsManager: Pre-cargando %d imágenes (prioridad: %s, delay: %s)" % [
		_pending_collection_images, 
		priority,
		"1s/batch" if priority == "low" else "inmediato"
	])
	
	
	# Emitir progreso inicial
	collection_loading_progress.emit(_collection_loaded, _collection_total)
	
	# Si es low priority, espaciar las descargas
	if priority == "low":
		# Descargar con delay entre grupos (para no saturar)
		_preload_collection_batch(cards_to_load, 0, 5)  # 5 imágenes por batch
	else:
		# High priority: descargar todo de una
		for card_data in cards_to_load:
			_start_collection_image_load(card_data)


func _preload_collection_batch(cards: Array, start_idx: int, batch_size: int) -> void:
	"""Descargar un batch de imágenes de colección con delay"""
	var end_idx = min(start_idx + batch_size, cards.size())
	
	for i in range(start_idx, end_idx):
		_start_collection_image_load(cards[i])
	
	# Si hay más batches, programar el siguiente con delay
	if end_idx < cards.size():
		await get_tree().create_timer(1.0).timeout  # 1 segundo de delay
		_preload_collection_batch(cards, end_idx, batch_size)


func _start_collection_image_load(card_data: Dictionary) -> void:
	var card_id = card_data["card_id"]
	var image_url = card_data["image_url"]
	
	if _image_cache.has(card_id):
		return
	
	ApiClient.get_image_with_callback(
		image_url,
		func(image: Image, _tag = null):
			_on_collection_image_loaded(card_id, image)
	)

func _on_collection_image_loaded(card_id: String, image: Image) -> void:
	if image == null:
		push_error("❌ CardsManager: Error cargando imagen colección " + card_id)
	elif image:
		_image_cache[card_id] = ImageTexture.create_from_image(image)

	_collection_loaded += 1
	_pending_collection_images -= 1

	collection_loading_progress.emit(
		_collection_loaded,
		_collection_total
	)

	if _pending_collection_images == 0:
		var success_rate = (_collection_total - _collection_loaded) / float(_collection_total) * 100.0 if _collection_total > 0 else 0.0
		print("✅ CardsManager: Colección precargada. Éxito: %.1f%%" % success_rate)
		collection_images_preloaded.emit()

func get_cached_image(card_id: String, image_url: String, on_loaded: Callable) -> void:
	# 1. Cache hit
	if _image_cache.has(card_id):
		print("[CardsManager] ✅ Cache hit: %s" % card_id)
		on_loaded.call(_image_cache[card_id])
		return

	# 2. Ya se está descargando
	if _pending_requests.has(card_id):
		print("[CardsManager] ⏳ Ya en descarga: %s (agregando callback)" % card_id)
		_pending_requests[card_id].append(on_loaded)
		return

	# 3. Nueva descarga
	print("[CardsManager] 📥 Iniciando descarga: %s" % card_id)
	_pending_requests[card_id] = [on_loaded]

	ApiClient.get_image_with_callback(
		image_url,
		func(image: Image, _tag = null):
			if image == null:
				print("[CardsManager] ❌ Imagen null para: %s" % card_id)
				push_error("CardsManager: Error cargando imagen " + card_id)
				_pending_requests.erase(card_id)
				return

			var texture := ImageTexture.create_from_image(image)
			_image_cache[card_id] = texture
			print("[CardsManager] ✅ Descargada: %s (size: %.0fx%.0f)" % [card_id, image.get_size().x, image.get_size().y])

			for cb in _pending_requests[card_id]:
				cb.call(texture)

			_pending_requests.erase(card_id)
	)


func has_card_texture(card_id: String) -> bool:
	"""Verificar si una carta tiene su imagen en cache"""
	return _image_cache.has(card_id)


func get_card_texture(card_id: String) -> ImageTexture:
	"""Obtener textura de una carta (null si no está en cache)"""
	return _image_cache.get(card_id, null)


func get_default_card_back() -> ImageTexture:
	"""Obtener el dorso de carta por defecto
	
	Prioridad:
	1. Si ya está cacheado, devolverlo
	2. Si existe localmente en assets, cargarlo
	3. Si no, crear una textura de color sólido como fallback
	"""
	# Si ya está cacheado, devolverlo
	if _card_back_texture != null:
		return _card_back_texture
	
	# Intentar cargar desde archivo local (pre-descargado del servidor)
	var local_path = "res://assets/cards/card_back.png"
	if ResourceLoader.exists(local_path):
		_card_back_texture = load(local_path)
		return _card_back_texture
	
	# Fallback: crear una textura de color sólido mientras se carga
	# Crear imagen 120x168 con color gris oscuro
	var fallback_image = Image.create(120, 168, false, Image.FORMAT_RGB8)
	fallback_image.fill(Color(0.2, 0.2, 0.25, 1.0))  # Gris oscuro
	
	_card_back_texture = ImageTexture.create_from_image(fallback_image)
	
	# En paralelo, intentar descargar la mejor versión del servidor
	if not _is_loading_card_back:
		_is_loading_card_back = true
		_load_card_back_from_server()
	
	return _card_back_texture


func _load_card_back_from_server() -> void:
	"""Cargar dorso de carta desde el servidor y cachear"""
	ApiClient.get_image_with_callback(
		GameConfig.API_URL + "/assets/cards/card_back.png",
		func(image: Image, _tag = null) -> void:
			if image:
				_card_back_texture = ImageTexture.create_from_image(image)
				card_back_loaded.emit(_card_back_texture)
				print("[CardsManager] ✅ Dorso de carta cargado del servidor")
			_is_loading_card_back = false,
		"default_card_back"
	)


func get_cache_info() -> Dictionary:
	"""Obtener información de debug del cache"""
	var size_mb = 0.0
	for texture in _image_cache.values():
		if texture and texture.get_image():
			var img = texture.get_image()
			# Estimar tamaño: ancho * alto * 4 bytes (RGBA)
			size_mb += (img.get_width() * img.get_height() * 4) / (1024.0 * 1024.0)
	
	return {
		"cached_cards": _image_cache.size(),
		"estimated_memory_mb": "%.2f" % size_mb,
		"card_back_loaded": _card_back_texture != null
	}
