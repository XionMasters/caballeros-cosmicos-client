# CardDatabase.gd
# Almacena METADATOS de todas las cartas del juego (texto puro, sin imágenes)
# Se carga UNA SOLA VEZ después del login y queda en memoria toda la sesión
# 
# Responsabilidades:
# - Orquestar la carga de cartas (usando ApiClient)
# - Parsear respuesta JSON (CardData es un DTO, no parsea)
# - Almacenar en memoria para búsquedas rápidas
# - Proporcionar API de consulta (por ID, tipo, rareza, etc)
extends Node

# ============================================================================
# DATOS
# ============================================================================
var all_cards: Array[CardData] = []  # Todas las cartas como CardData
var cards_by_id: Dictionary = {}  # card_id -> CardData (búsqueda rápida)
var is_loaded: bool = false
var is_loading: bool = false
var _total_cards_on_server: int = 0  # Cantidad real en el servidor
var _loaded_so_far: int = 0
var _language: String = "es"
var _page_retry_count: Dictionary = {}  # offset -> intentos fallidos

# ============================================================================
# SIGNALS
# ============================================================================
signal cards_loaded(count: int)
signal cards_failed(error_msg: String)
signal loading_progress(loaded: int, total: int)

# ============================================================================
# CONFIGURACIÓN
# ============================================================================
const CARDS_PER_PAGE = 100  # Cargar de a 100 (mejor para paginación escalable)
const INCLUDE_STATS = "true"  # Incluir stats de caballeros
const INCLUDE_ABILITIES = "true"  # Incluir habilidades


func _ready() -> void:
	# Conectar a ApiClient si existe
	if has_node("/root/ApiClient"):
		var api_client = get_node("/root/ApiClient")
		if not api_client.request_completed.is_connected(_on_api_request_completed):
			api_client.request_completed.connect(_on_api_request_completed)


func reload_for_language(new_lang: String) -> void:
	"""Recargar todas las cartas cuando el usuario cambia de idioma."""
	if new_lang == _language and is_loaded:
		return
	is_loaded = false
	is_loading = false
	print("[CardDatabase] 🌐 Recargando para idioma: %s" % new_lang)
	fetch_all_cards(new_lang)


func fetch_all_cards(lang: String = "en") -> void:
	"""
	Cargar todos los metadatos de cartas del servidor.
	Usa PAGINACIÓN para ser escalable (si el servidor crece a 1000+ cartas).
	"""
	if is_loaded:
		print("[CardDatabase] ✅ Ya está cargado, emitiendo señal")
		cards_loaded.emit(all_cards.size())
		return
	
	if is_loading:
		print("[CardDatabase] ⏳ Ya está cargando, esperando...")
		return
	
	_language = lang
	is_loading = true
	_loaded_so_far = 0
	all_cards.clear()
	cards_by_id.clear()
	
	print("[CardDatabase] 📡 Iniciando carga pagina (lang=%s)..." % lang)
	
	# Pedir primera página
	_fetch_cards_page(0)


func _fetch_cards_page(offset: int) -> void:
	"""Pedir una página de cartas al servidor usando ApiClient"""
	if not has_node("/root/ApiClient"):
		push_error("[CardDatabase] ApiClient no está disponible")
		_loading_failed("ApiClient no disponible")
		return
	
	var api_client = get_node("/root/ApiClient")
	
	# Construir endpoint con query params
	var endpoint = "/cards?limit=%d&offset=%d&lang=%s&include_stats=%s&include_abilities=%s" % [
		CARDS_PER_PAGE,
		offset,
		_language,
		INCLUDE_STATS,
		INCLUDE_ABILITIES
	]
	
	print("[CardDatabase] 📥 Pidiendo página: offset=%d, limit=%d" % [offset, CARDS_PER_PAGE])
	
	# ApiClient hace la petición y emite signal request_completed
	# No requiere autenticación (endpoint público)
	api_client.get_request(endpoint, "card_database_fetch", false)


func _on_api_request_completed(tag: String, success: bool, data: Variant, error: String) -> void:
	"""
	Callback de ApiClient cuando termina una petición.
	ApiClient PARSEA el JSON automáticamente y pasa como 'data'.
	CardDatabase solo procesa la lógica de negocio.
	"""
	if tag != "card_database_fetch":
		return  # No es una petición nuestra
	
	if not success:
		# Intentar reintento antes de fallar
		var offset = _loaded_so_far
		var retry_count = _page_retry_count.get(offset, 0)
		
		if retry_count < 2:  # Máximo 2 reintentos
			_page_retry_count[offset] = retry_count + 1
			print("[CardDatabase] 🔄 Reintentando página (offset=%d, intento %d/2): %s" % [offset, retry_count + 1, error])
			await get_tree().create_timer(1.0).timeout  # Esperar 1 segundo antes de reintentar
			_fetch_cards_page(offset)
			return
		
		# Falló después de reintentos
		_loading_failed("Error desde API después de reintentos: %s" % error)
		return
	
	if not data is Dictionary:
		_loading_failed("Respuesta inválida: no es diccionario")
		return
	
	var cards_in_response = data.get("cards", [])
	var total_on_server = data.get("total", 0)
	
	if total_on_server == 0:
		_loading_failed("Respuesta vacía del servidor")
		return
	
	# Primera página: guardar el total real
	if _loaded_so_far == 0:
		_total_cards_on_server = total_on_server
		print("[CardDatabase] 📊 Total de cartas en servidor: %d" % _total_cards_on_server)
	
	print("[CardDatabase] 📦 Recibida página con %d cartas" % cards_in_response.size())
	
	# Procesar cartas de esta página
	_process_cards_from_response(cards_in_response)
	
	_loaded_so_far += cards_in_response.size()
	loading_progress.emit(_loaded_so_far, _total_cards_on_server)
	
	# Limpiar contador de reintentos para esta página
	_page_retry_count.erase(_loaded_so_far)
	
	# ¿Hay más páginas?
	if _loaded_so_far < _total_cards_on_server:
		# Pedir siguiente página
		_fetch_cards_page(_loaded_so_far)
	else:
		# ✅ Listo, todas las cartas cargadas
		_loading_complete()


func _process_cards_from_response(raw_cards: Array) -> void:
	"""
	Convertir respuesta JSON a CardData.
	ApiClient ya parseó el JSON, esto es solo conversión a tipado.
	"""
	for raw in raw_cards:
		if not raw is Dictionary:
			continue
		
		if not raw.has("id"):
			continue
		
		# Usar CardData.from_json() que ya tiene validación robusta
		# Esto maneja nulos, tipos inválidos, conversiones, etc.
		var card_data = CardData.from_json(raw)
		
		if card_data == null:
			push_error("[CardDatabase] ❌ CardData inválido para: %s" % raw.get("id", "unknown"))
			continue
		
		# Agregar a arrays
		all_cards.append(card_data)
		cards_by_id[card_data.id] = card_data


func _loading_complete() -> void:
	"""Finalizar la carga exitosamente"""
	is_loading = false
	is_loaded = true
	_page_retry_count.clear()  # Limpiar reintentos
	
	print("[CardDatabase] ✅ Carga completa! %d cartas en memoria" % all_cards.size())
	cards_loaded.emit(all_cards.size())


func _loading_failed(reason: String) -> void:
	"""Falló la carga"""
	is_loading = false
	print("[CardDatabase] ❌ Error cargando: %s" % reason)
	cards_failed.emit(reason)
	
	# Limpiar estado
	all_cards.clear()
	cards_by_id.clear()
	_loaded_so_far = 0
	_total_cards_on_server = 0
	_page_retry_count.clear()  # Limpiar reintentos


# ============================================================================
# MÉTODOS DE ACCESO
# ============================================================================

func get_card(card_id: String) -> CardData:
	"""Obtener una carta por su ID"""
	return cards_by_id.get(card_id, null)


func has_card(card_id: String) -> bool:
	"""Verificar si existe una carta"""
	return cards_by_id.has(card_id)


func get_all_cards() -> Array[CardData]:
	"""Obtener todas las cartas"""
	return all_cards.duplicate()


func get_cards_by_type(card_type: String) -> Array[CardData]:
	"""Filtrar cartas por tipo"""
	var filtered: Array[CardData] = []
	for card in all_cards:
		if card.type == card_type:
			filtered.append(card)
	return filtered


func get_cards_by_rarity(rarity: String) -> Array[CardData]:
	"""Filtrar cartas por rareza"""
	var filtered: Array[CardData] = []
	for card in all_cards:
		if card.rarity == rarity:
			filtered.append(card)
	return filtered


func get_cards_by_faction(faction: String) -> Array[CardData]:
	"""Filtrar cartas por facción"""
	var filtered: Array[CardData] = []
	for card in all_cards:
		if card.faction == faction:
			filtered.append(card)
	return filtered


func search_cards(query: String) -> Array[CardData]:
	"""Buscar cartas por nombre (case-insensitive)"""
	var results: Array[CardData] = []
	var query_lower = query.to_lower()
	
	for card in all_cards:
		if card.name.to_lower().contains(query_lower):
			results.append(card)
	
	return results


func get_total_count() -> int:
	"""Obtener cantidad total de cartas cargadas"""
	return all_cards.size()


func get_load_stats() -> Dictionary:
	"""Obtener estadísticas de carga para debug"""
	var progress_percent = 0.0
	if _total_cards_on_server > 0:
		progress_percent = (float(_loaded_so_far) / float(_total_cards_on_server)) * 100.0
	
	return {
		"loaded": is_loaded,
		"loading": is_loading,
		"total_cards_in_memory": all_cards.size(),
		"total_cards_on_server": _total_cards_on_server,
		"cards_loaded_so_far": _loaded_so_far,
		"progress_percent": "%.1f%%" % progress_percent,
		"page_retries_pending": _page_retry_count.size()
	}
