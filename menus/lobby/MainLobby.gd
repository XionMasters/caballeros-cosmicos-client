# MainLobby.gd
# Menú principal: cabecera con usuario y monedas, banner del Santuario con los
# botones de juego, accesos a Colección/Mazos/Tienda/Perfil, novedades,
# usuarios en línea y chat global.
extends Control

@onready var chat_panel = %ChatPanel
@onready var username_label: Label = %UsernameLabel
@onready var coins_label: Label = %CoinsLabel
@onready var coin_icon: TextureRect = %CoinIcon
@onready var library_button: Button = %LibraryButton
@onready var decks_button: Button = %DecksButton
@onready var shop_button: Button = %ShopButton
@onready var profile_button: Button = %ProfileButton
@onready var logout_button: Button = %LogoutButton
@onready var emblem: TextureRect = %Emblem
@onready var banner_art: TextureRect = %BannerArt
@onready var verify_notice: PanelContainer = %VerifyNotice
@onready var verify_button: Button = %VerifyButton
@onready var toast: ToastNotice = %Toast

var websocket_manager
var _displayed_coins: int = 0


func _ready():
	# Cargar info del usuario
	_load_user_info()

	# Precargar colección en background (LOW priority)
	_preload_collection_background()

	for tile in [library_button, decks_button, shop_button, profile_button]:
		_setup_tile_hover(tile)

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
	logout_button.pressed.connect(_on_logout_pressed)

	_setup_match_feedback()

	_play_intro()
	_start_ambient_animations()


func _load_user_info():
	"""Cargar información del usuario desde UserManager"""
	if has_node("/root/UserManager"):
		var user_manager = get_node("/root/UserManager")
		var username = user_manager.get_username()

		if username:
			username_label.text = username

		# Obtener monedas desde el perfil cargado
		_displayed_coins = user_manager.get_currency()
		coins_label.text = _format_coins(_displayed_coins)

		# Conectar señal de cambio de monedas
		if not user_manager.currency_changed.is_connected(_on_currency_changed):
			user_manager.currency_changed.connect(_on_currency_changed)


func _on_currency_changed(new_amount: int):
	"""Callback cuando las monedas cambian: cuenta animada y destello de la moneda"""
	var tween := create_tween().set_parallel()
	tween.tween_method(_set_coins_display, _displayed_coins, new_amount, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	coin_icon.pivot_offset = coin_icon.size / 2.0
	tween.tween_property(coin_icon, "scale", Vector2(1.3, 1.3), 0.15).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_property(coin_icon, "scale", Vector2.ONE, 0.25)
	_displayed_coins = new_amount


func _set_coins_display(value: int) -> void:
	coins_label.text = _format_coins(value)


func _format_coins(amount: int) -> String:
	# 12500 -> "12.500"
	var digits := str(absi(amount))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += "."
		out += digits[i]
	return ("-" if amount < 0 else "") + out


func _setup_match_feedback() -> void:
	"""Mostrar los rechazos del servidor al jugar y el aviso de email sin verificar"""
	# El mismo error puede llegar por los dos servicios; ToastNotice ignora el duplicado
	MatchmakingService.match_error.connect(_on_match_error)
	MatchSessionService.match_error.connect(_on_match_error)

	verify_button.pressed.connect(AuthManager.show_email_verification)
	AuthManager.email_verified.connect(func():
		_update_verify_notice()
		toast.show_message("¡Email verificado! Ya puedes jugar partidas")
	)
	UserManager.profile_loaded.connect(func(_profile): _update_verify_notice())
	_update_verify_notice()


func _update_verify_notice() -> void:
	var profile = UserManager.get_profile()
	verify_notice.visible = profile != null and not profile.is_email_verified


func _on_match_error(message: String) -> void:
	toast.show_message(message, true)


func _setup_tile_hover(tile: Button):
	"""Las tarjetas de navegación crecen un poco al pasar el ratón"""
	tile.mouse_entered.connect(func():
		tile.pivot_offset = tile.size / 2.0
		create_tween().tween_property(tile, "scale", Vector2(1.04, 1.04), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	tile.mouse_exited.connect(func():
		create_tween().tween_property(tile, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SINE)
	)


func _play_intro() -> void:
	"""Entrada escalonada: cabecera, columnas y tarjetas aparecen con un leve desplazamiento"""
	var parts: Array[Control] = [%Header, %LeftColumn, %HeroBanner, %NavGrid, %ChatPanel]
	for i in parts.size():
		var part := parts[i]
		part.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(0.06 * i)
		tween.tween_property(part, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)


func _start_ambient_animations() -> void:
	# El emblema gira muy despacio, como el anillo zodiacal del login
	emblem.pivot_offset = emblem.custom_minimum_size / 2.0
	var spin := create_tween().set_loops()
	spin.tween_property(emblem, "rotation", TAU, 60.0).from(0.0)

	# Ligero "respirar" del arte del Santuario
	var glow := create_tween().set_loops()
	glow.tween_property(banner_art, "modulate", Color(1.08, 1.05, 1.0), 4.0).set_trans(Tween.TRANS_SINE)
	glow.tween_property(banner_art, "modulate", Color.WHITE, 4.0).set_trans(Tween.TRANS_SINE)


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
