# AuthManager.gd
# Gestiona SOLO autenticación JWT - Responsabilidad única
extends Node

signal login_successful(user_profile: UserProfile)
signal login_failed(error: String)
signal registration_successful(user_profile: UserProfile)
signal registration_failed(error: String)
signal logout_completed()
signal instance_conflict(username: String)  # Emitir si hay otra sesión abierta
signal session_expired()  # Nueva señal para token expirado

var auth_token: String = ""
var is_authenticated: bool = false
var current_user_id: String = ""  # Para trackear qué usuario tiene lock

var _session_manager: SessionManager = null
var _instance_manager: InstanceManager = null
var _login_in_flight: bool = false
var _register_in_flight: bool = false
var _api: Node = null


func _ready() -> void:
	# Inicializar dependencias
	_session_manager = SessionManager.new()
	add_child(_session_manager)
	
	_instance_manager = InstanceManager.new()
	add_child(_instance_manager)
	
	# Esperar a que ApiClient esté listo
	await get_tree().process_frame
	_api = get_node_or_null("/root/ApiClient")
	
	# Conectar a respuestas de ApiClient (ya debe estar disponible como autoload)
	if _api:
		_api.request_completed.connect(_on_api_request_completed)
	
	# Auto-login si hay token guardado
	_try_auto_login()


func login(email: String, password: String) -> void:
	"""Autenticar usuario con email y contraseña"""
	if _login_in_flight:
		return
	
	_login_in_flight = true
	
	var body := {
		"email": email,
		"password": password
	}
	
	if _api:
		_api.post("/auth/login", body, "auth_login", false)


func register(email: String, password: String, username: String = "") -> void:
	"""Registrar nuevo usuario"""
	if _register_in_flight:
		return
	
	_register_in_flight = true
	
	var body := {
		"email": email,
		"password": password,
		"username": username if username else email.split("@")[0]
	}
	
	if _api:
		_api.post("/auth/register", body, "auth_register", false)


func logout() -> void:
	"""Cerrar sesión"""
	auth_token = ""
	is_authenticated = false
	if _api:
		_api.set_auth_token("")
	_session_manager.delete_token()
	
	# Liberar lock de usuario
	if _instance_manager and current_user_id:
		_instance_manager.release_lock()
		current_user_id = ""
	
	# Limpiar perfil de usuario
	if has_node("/root/UserManager"):
		get_node("/root/UserManager").clear_profile()
	
	print("[Auth] Sesión cerrada")
	logout_completed.emit()


func get_token() -> String:
	"""Obtener token JWT actual"""
	return auth_token


func get_user_id() -> String:
	"""Obtener ID del usuario autenticado"""
	return current_user_id


func get_auth_headers() -> PackedStringArray:
	"""Obtener headers con autenticación (delegado a ApiClient)"""
	if _api:
		return _api.get_auth_headers()
	return ["Content-Type: application/json"]


func is_logged_in() -> bool:
	"""Verificar si está autenticado"""
	return is_authenticated and auth_token != ""


# ============================================================================
# PRIVATE - Auto-login
# ============================================================================

func _try_auto_login() -> void:
	"""Intentar auto-login con token guardado"""
	var saved_token := _session_manager.load_token()
	if saved_token != "":
		print("[Auth] Token encontrado, validando...")
		auth_token = saved_token
		if _api:
			_api.set_auth_token(saved_token)
		
		# Validar token obteniendo perfil
		if has_node("/root/UserManager"):
			var user_manager = get_node("/root/UserManager")
			# Conectar solo si no está ya conectada (evitar duplicados)
			if not user_manager.profile_loaded.is_connected(_on_auto_login_profile_loaded):
				user_manager.profile_loaded.connect(_on_auto_login_profile_loaded)
			user_manager.fetch_profile(saved_token)


func _on_auto_login_profile_loaded(profile: UserProfile) -> void:
	"""Callback cuando se carga el perfil en auto-login"""
	is_authenticated = true
	current_user_id = profile.id
	
	# Crear lock de instancia - force_replace=true porque es login intencional
	if not _instance_manager.create_lock(profile.id, true):
		print("[Auth] ❌ ERROR: Este usuario ya tiene una sesión abierta")
		instance_conflict.emit(profile.username)
		is_authenticated = false
		current_user_id = ""
		login_failed.emit("Este usuario ya tiene una sesión abierta en otra instancia")
		return
	
	print("[Auth] ✅ Auto-login exitoso: %s (ID: %s)" % [profile.username, profile.id])
	
	# Conectar WebSocket con el token actual
	_connect_websocket()
	
	# Precarga ESENCIAL después del login
	_preload_essentials()
	
	login_successful.emit(profile)


# ============================================================================
# CALLBACKS - ApiClient Responses
# ============================================================================

func _on_api_request_completed(tag: String, success: bool, data: Variant, error: String) -> void:
	match tag:
		"auth_login":
			_on_login_response(success, data, error)
		"auth_register":
			_on_register_response(success, data, error)
		_:
			pass


# ============================================================================
# CALLBACKS - Login
# ============================================================================

func _on_login_response(success: bool, data: Variant, error: String) -> void:
	"""Callback de respuesta de login"""
	_login_in_flight = false
	
	if not success:
		print("[Auth] ❌ Login fallido: ", error)
		login_failed.emit(error)
		return
	
	if not data or not data is Dictionary:
		login_failed.emit("Respuesta inválida del servidor")
		return
	
	var response := data as Dictionary
	
	if not response.has("token"):
		login_failed.emit("Token no encontrado en respuesta")
		return
	
	# Guardar token
	auth_token = response["token"]
	is_authenticated = true
	current_user_id = response.get("user", {}).get("id", "")
	
	if _api:
		_api.set_auth_token(auth_token)
	_session_manager.save_token(auth_token)
	
	# Crear lock de instancia - force_replace=true para permitir recovery
	if current_user_id and not _instance_manager.create_lock(current_user_id, true):
		print("[Auth] ❌ ERROR: Este usuario ya tiene una sesión abierta")
		auth_token = ""
		is_authenticated = false
		_session_manager.delete_token()
		login_failed.emit("Este usuario ya tiene una sesión abierta en otra instancia")
		_login_in_flight = false
		return
	
	# Crear perfil de usuario
	var user_data: Dictionary = response.get("user", {})
	var profile := UserProfile.from_dict(user_data)
	
	# Guardar en UserManager
	if has_node("/root/UserManager"):
		get_node("/root/UserManager").set_profile(profile)
	
	# Conectar WebSocket
	_connect_websocket()
	
	# Obtener perfil completo
	if has_node("/root/UserManager"):
		get_node("/root/UserManager").fetch_profile(auth_token)
	
	# Precarga ESENCIAL después del login
	_preload_essentials()
	
	print("[Auth] ✅ Login exitoso: %s (ID: %s)" % [profile.username, current_user_id])
	login_successful.emit(profile)


# ============================================================================
# CALLBACKS - Registro
# ============================================================================

func _on_register_response(success: bool, data: Variant, error: String) -> void:
	"""Callback de respuesta de registro"""
	_register_in_flight = false
	
	if not success:
		print("[Auth] ❌ Registro fallido: ", error)
		registration_failed.emit(error)
		return
	
	if not data or not data is Dictionary:
		registration_failed.emit("Respuesta inválida del servidor")
		return
	
	var response := data as Dictionary
	
	if not response.has("token"):
		# Registro exitoso pero sin auto-login
		registration_successful.emit(UserProfile.new())
		return
	
	# Auto-login después de registro
	auth_token = response["token"]
	is_authenticated = true
	if _api:
		_api.set_auth_token(auth_token)
	_session_manager.save_token(auth_token)
	
	# Crear perfil
	var user_data: Dictionary = response.get("user", {})
	var profile := UserProfile.from_dict(user_data)
	
	# Guardar en UserManager
	if has_node("/root/UserManager"):
		get_node("/root/UserManager").set_profile(profile)
	
	# Conectar WebSocket
	_connect_websocket()
	
	# Obtener perfil completo
	if has_node("/root/UserManager"):
		get_node("/root/UserManager").fetch_profile(auth_token)
	
# ============================================================================
# PRELOAD ESSENTIALS - Cargar datos críticos después del login
# ============================================================================

func _preload_essentials() -> void:
	"""
	Precarga datos ESENCIALES después del login exitoso.
	Esto garantiza que todo esté listo antes de navegar al menú.
	"""
	print("[Auth] 🚀 Iniciando precarga esencial...")
	
	# 1. Cargar CardBack (necesario en todos lados)
	if has_node("/root/CardsManager"):
		print("[Auth]   → Precargando CardBack...")
		get_node("/root/CardsManager").preload_card_back()
	
	# 2. Cargar metadatos de todas las cartas
	if has_node("/root/CardDatabase"):
		print("[Auth]   → Cargando CardDatabase...")
		var lang := "en"
		if has_node("/root/LocalizationManager"):
			lang = get_node("/root/LocalizationManager").get_language_code()
		get_node("/root/CardDatabase").fetch_all_cards(lang)
	
	# 3. Precargar imágenes del MAZO ACTIVO (HIGH priority)
	_preload_active_deck_images()
	
	print("[Auth] ✅ Precarga esencial iniciada en background")


func _preload_active_deck_images() -> void:
	"""Precargar imágenes del mazo activo del usuario (HIGH priority)"""
	if not has_node("/root/DecksManager"):
		return
	
	var decks_manager = get_node("/root/DecksManager")
	var active_deck = decks_manager.get_active_deck()
	
	if not active_deck:
		print("[Auth]   → No hay mazo activo para precargar")
		return
	
	var deck_id = active_deck.get("id", "")
	if not deck_id:
		return
	
	print("[Auth]   → Precargando imágenes del mazo activo...")
	
	# Obtener cartas del mazo
	if has_node("/root/CardsManager"):
		var cards_manager = get_node("/root/CardsManager")
		
		# Crear array con las cartas del mazo
		var deck_cards = []
		if active_deck.has("cards") and active_deck.cards is Array:
			for card in active_deck.cards:
				if card is Dictionary:
					deck_cards.append({
						"card_id": card.get("card_id", ""),
						"image_url": card.get("image_url", "")
					})
		
		if deck_cards.size() > 0:
			cards_manager.preload_deck_images(deck_cards)

	
# ============================================================================
# WEBSOCKET
# ============================================================================

func _connect_websocket() -> void:
	"""Conectar al WebSocket con el token actual"""
	if has_node("/root/WebSocketManager"):
		var ws_manager = get_node("/root/WebSocketManager")
		if ws_manager.has_method("connect_to_server"):
			ws_manager.connect_to_server(auth_token)


func emit_auth_error(error: String) -> void:
	"""Emitir error de autenticación (ej: token expirado)"""
	print("[AuthManager] ❌ Error de autenticación: %s" % error)
	login_failed.emit(error)
	session_expired.emit()
	logout()  # Forzar logout
