# MainLobby.gd
extends Control

@onready var chat_panel = $MainContainer/TopArea/ChatPanel
@onready var username_label = $MainContainer/Header/HeaderContent/UserInfo/UsernameLabel
@onready var coins_label = $MainContainer/Header/HeaderContent/UserInfo/CoinsLabel
@onready var library_button = $MainContainer/NavigationBar/MarginContainer/NavButtons/LibraryButton
@onready var profile_button = $MainContainer/NavigationBar/MarginContainer/NavButtons/ProfileButton
@onready var shop_button = $MainContainer/NavigationBar/MarginContainer/NavButtons/ShopButton
@onready var decks_button = $MainContainer/NavigationBar/MarginContainer/NavButtons/DecksButton
##@onready var match_button = $MainContainer/NavigationBar/MarginContainer/NavButtons/MatchButton
@onready var test_button = $MainContainer/NavigationBar/MarginContainer/NavButtons/TestButton
@onready var chat_button = $MainContainer/NavigationBar/MarginContainer/NavButtons/ChatButton
@onready var logout_button = $MainContainer/NavigationBar/MarginContainer/NavButtons/LogoutButton

var websocket_manager

func _ready():
	# Cargar info del usuario
	_load_user_info()
	
	# Precargar colección en background (LOW priority)
	_preload_collection_background()
	
	# Configurar modulate hover para los botones
	_setup_button_hover(library_button)
	_setup_button_hover(profile_button)
	_setup_button_hover(shop_button)
	_setup_button_hover(decks_button)
	#_setup_button_hover(match_button)
	#_setup_button_hover(test_button)
	
	# Chat button deshabilitado tiene modulate diferente
	chat_button.modulate = Color(0.5, 0.5, 0.5, 1.0)
	_setup_button_hover(logout_button)
	
	# Conectar WebSocket si está disponible
	if has_node("/root/WebSocketManager"):
		websocket_manager = get_node("/root/WebSocketManager")
		if websocket_manager.has_signal("connected_to_server"):
			websocket_manager.connected_to_server.connect(_on_websocket_connected)
		
		# Si ya está conectado, solicitar usuarios en línea
		if websocket_manager.is_connected_to_server():
			_request_initial_data()
	
	# Conectar botones de navegación
	library_button.pressed.connect(_on_library_pressed)
	profile_button.pressed.connect(_on_profile_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	decks_button.pressed.connect(_on_decks_pressed)
	#match_button.pressed.connect(_on_match_pressed)
	#test_button.pressed.connect(_on_test_pressed)
	logout_button.pressed.connect(_on_logout_pressed)
	
	# Chat button está deshabilitado (ya estamos en chat)
	chat_button.disabled = true
	
func _load_user_info():
	"""Cargar información del usuario desde UserManager"""
	if has_node("/root/UserManager"):
		var user_manager = get_node("/root/UserManager")
		var username = user_manager.get_username()
		
		if username:
			username_label.text = "👤 " + username
		
		# Obtener monedas desde el perfil cargado
		var currency = user_manager.get_currency()
		coins_label.text = "💰 " + str(currency)
		
		# Conectar señal de cambio de monedas
		if not user_manager.currency_changed.is_connected(_on_currency_changed):
			user_manager.currency_changed.connect(_on_currency_changed)

func _on_currency_changed(new_amount: int):
	"""Callback cuando las monedas cambian"""
	coins_label.text = "💰 " + str(new_amount)

func _setup_button_hover(button: Button):
	"""Configurar efecto hover para botones"""
	button.mouse_entered.connect(func():
		button.modulate = Color(1.3, 1.3, 1.3, 1.0)
	)
	button.mouse_exited.connect(func():
		button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	)

func _on_websocket_connected():
	_request_initial_data()

func _request_initial_data():
	if websocket_manager:
		# Solicitar mensajes recientes vía REST API
		_load_recent_messages()
		
		# Solicitar usuarios en línea vía WebSocket
		websocket_manager.request_online_users()

func _load_recent_messages():
	# Cargar últimos mensajes del chat vía ApiClient
	ApiClient.get_request_with_callback(
		"/chat/messages",
		"chat_messages",
		_on_messages_loaded
	)

func _on_messages_loaded(success: bool, data: Variant, error: String):
	if not success:
		push_error("[MainLobby] Error cargando mensajes: %s" % error)
		return
	
	if data is Dictionary:
		var messages = data.get("messages", []) as Array
		if chat_panel and chat_panel.has_method("load_initial_messages"):
			chat_panel.load_initial_messages(messages)
	elif data is Array:
		if chat_panel and chat_panel.has_method("load_initial_messages"):
			chat_panel.load_initial_messages(data)

func _on_library_pressed():
	# Navegar a la biblioteca de cartas
	SceneTransition.go_to_mycards()

func _on_profile_pressed():
	# Navegar a la pantalla de perfil
	SceneTransition.go_to_profile()

func _on_shop_pressed():
	# Navegar a la tienda (abrir packs)
	SceneTransition.go_to_shop()

func _on_decks_pressed():
	# Navegar a la lista de mazos
	SceneTransition.go_to_decks()

func _on_match_pressed():
	# Navegar a búsqueda de partida
	if MatchmakingService.is_searching:
		MatchmakingService.cancel_search()
	else:
		MatchmakingService.search_match()


func _on_test_pressed():
	# Solicitar partida de prueba (test_mode)
	print("[MainLobby] 🧪 Solicitando partida TEST")
	MatchSessionService.start_test_match()  # Enviar solicitud al servidor

func _on_logout_pressed():
	if has_node("/root/AuthManager"):
		get_node("/root/AuthManager").logout()
	# Opcional: cerrar WebSocket si sigue vivo
	if has_node("/root/WebSocketManager"):
		var ws = get_node("/root/WebSocketManager")
		if ws.has_method("disconnect_from_server"):
			ws.disconnect_from_server()
	SceneTransition.go_to_login()

func _preload_collection_background() -> void:
	"""Precargar colección en background (LOW priority)"""
	if not has_node("/root/CardDatabase"):
		return
	
	var card_database = get_node("/root/CardDatabase")
	
	# Esperar a que CardDatabase cargue los datos
	if not card_database.is_loaded:
		await card_database.cards_loaded
	
	# Obtener todos los IDs de cartas
	var all_cards = card_database.get_all_cards()
	if all_cards.size() == 0:
		return
	
	var card_ids = []
	for card in all_cards:
		if not card_ids.has(card.id):
			card_ids.append(card.id)
	
	# Iniciar precarga en background
	if has_node("/root/CardsManager"):
		var cards_manager = get_node("/root/CardsManager")
		print("[MainLobby] 🔄 Iniciando precarga de colección en background...")
		cards_manager.preload_collection_images(card_ids, "low")
