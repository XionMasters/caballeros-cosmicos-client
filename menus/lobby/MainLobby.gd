# MainLobby.gd
# Menú principal: el mazo activo en abanico como protagonista, el botón JUGAR,
# novedades a la izquierda, tu récord a la derecha, usuario y monedas arriba,
# chat y jugadores en línea en un panel lateral desplegable y la barra de
# navegación abajo.
extends Control

const DeckItemScript := preload("res://menus/decks/DeckItem.gd")

## Proporción de las imágenes de carta (1024×1536)
const CARD_RATIO := 2.0 / 3.0
const FAN_SIZE := 5
const FAN_STEP_DEGREES := 6.0
## Separación horizontal entre cartas del abanico (fracción del ancho de carta)
const FAN_SPREAD := 0.42
## Altura del pivote de rotación (en altos de carta desde arriba): cuanto más bajo, más arco
const FAN_PIVOT := 1.5
const DRAWER_SLIDE := 60.0

const NEWS := [
	{
		"tag": "ÚLTIMA ACTUALIZACIÓN",
		"title": "Nuevo Santuario",
		"body": "Menús renovados, chat en tiempo real y repeticiones de tus partidas.",
		"color": "#3EE6FF",
	},
	{
		"tag": "PRÓXIMAMENTE",
		"title": "Torneos semanales",
		"body": "Nuevos sobres de cartas y ranking de caballeros.",
		"color": "#FFC83D",
	},
	{
		"tag": "EVENTO ESPECIAL",
		"title": "Monedas de bienvenida",
		"body": "Recibe monedas al registrarte para abrir tus primeros sobres.",
		"color": "#FF4FD8",
	},
]

@onready var chat_panel = %ChatPanel
@onready var top_bar: Control = %TopBar
@onready var profile_badge: Button = %ProfileBadge
@onready var avatar: TextureRect = %Avatar
@onready var username_label: Label = %UsernameLabel
@onready var level_label: Label = %LevelLabel
@onready var coins_label: Label = %CoinsLabel
@onready var coin_icon: TextureRect = %CoinIcon
@onready var online_button: Button = %OnlineButton
@onready var chat_button: Button = %ChatButton
@onready var chat_badge: PanelContainer = %ChatBadge
@onready var chat_badge_label: Label = %ChatBadgeLabel
@onready var logout_button: Button = %LogoutButton
@onready var left_column: Control = %LeftColumn
@onready var right_column: Control = %RightColumn
@onready var news_list: VBoxContainer = %NewsList
@onready var stats_grid: GridContainer = %StatsGrid
@onready var shop_promo: Button = %ShopPromo
@onready var deck_showcase: Control = %DeckShowcase
@onready var deck_name_label: Label = %DeckNameLabel
@onready var deck_count_label: Label = %DeckCountLabel
@onready var change_deck_button: Button = %ChangeDeckButton
@onready var play_row: Control = %PlayRow
@onready var verify_notice: PanelContainer = %VerifyNotice
@onready var verify_button: Button = %VerifyButton
@onready var social_drawer: Control = %SocialDrawer
@onready var close_drawer_button: Button = %CloseDrawerButton
@onready var toast: ToastNotice = %Toast

var websocket_manager
var _displayed_coins: int = 0
var _fan_cards: Array[Control] = []
var _unread_messages := 0
var _drawer_tween: Tween


func _ready():
	_load_user_info()
	_build_news()
	_build_stats()
	_build_fan(FAN_SIZE)
	_load_active_deck()

	# Precargar colección en background (LOW priority)
	_preload_collection_background()

	# Conectar WebSocket si está disponible
	if has_node("/root/WebSocketManager"):
		websocket_manager = get_node("/root/WebSocketManager")
		if websocket_manager.has_signal("connected_to_server"):
			websocket_manager.connected_to_server.connect(_on_websocket_connected)
		if websocket_manager.has_signal("online_users_updated"):
			websocket_manager.online_users_updated.connect(_on_online_users_updated)
		if websocket_manager.has_signal("chat_message_received"):
			websocket_manager.chat_message_received.connect(_on_chat_message_received)

		# Si ya está conectado, solicitar usuarios en línea
		if websocket_manager.is_connected_to_server():
			_request_initial_data()

	profile_badge.pressed.connect(SceneTransition.go_to_profile)
	shop_promo.pressed.connect(SceneTransition.go_to_shop)
	change_deck_button.pressed.connect(SceneTransition.go_to_decks)
	deck_showcase.gui_input.connect(_on_showcase_input)
	deck_showcase.resized.connect(_layout_fan)
	logout_button.pressed.connect(_on_logout_pressed)
	chat_button.pressed.connect(_toggle_drawer)
	online_button.pressed.connect(_toggle_drawer)
	close_drawer_button.pressed.connect(_close_drawer)

	_setup_match_feedback()
	_play_intro()


# ============================================================================
# USUARIO Y MONEDAS
# ============================================================================

func _load_user_info():
	"""Cargar información del usuario desde UserManager"""
	if not has_node("/root/UserManager"):
		return
	var user_manager = get_node("/root/UserManager")
	var username = user_manager.get_username()
	if username:
		username_label.text = username

	var profile = user_manager.get_profile()
	if profile:
		level_label.text = "NIVEL %d" % profile.level
		_load_avatar(profile.avatar_url)

	# Obtener monedas desde el perfil cargado
	_displayed_coins = user_manager.get_currency()
	coins_label.text = _format_coins(_displayed_coins)

	if not user_manager.currency_changed.is_connected(_on_currency_changed):
		user_manager.currency_changed.connect(_on_currency_changed)


func _load_avatar(url: String) -> void:
	if url.is_empty():
		return
	var target: WeakRef = weakref(avatar)
	ApiClient.get_image_with_callback(url, func(image: Image, _tag = null):
		var rect: TextureRect = target.get_ref()
		if image and rect:
			rect.texture = ImageTexture.create_from_image(image)
	, "lobby_avatar_%s" % url.hash())


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


# ============================================================================
# NOVEDADES Y RÉCORD
# ============================================================================

func _build_news() -> void:
	for item in NEWS:
		var accent := Color(item.color)
		var card := PanelContainer.new()
		card.theme_type_variation = &"NewsCard"
		var style := card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		style.border_color = accent
		card.add_theme_stylebox_override("panel", style)

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		card.add_child(box)

		var tag := Label.new()
		tag.theme_type_variation = &"Eyebrow"
		tag.add_theme_font_size_override("font_size", 15)
		tag.add_theme_color_override("font_color", accent)
		tag.text = item.tag
		box.add_child(tag)

		var title := Label.new()
		title.theme_type_variation = &"SectionTitle"
		title.add_theme_color_override("font_color", UIPalette.TEXT)
		title.text = item.title
		box.add_child(title)

		var body := Label.new()
		body.theme_type_variation = &"Subtitle"
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.text = item.body
		box.add_child(body)

		news_list.add_child(card)


func _build_stats() -> void:
	for child in stats_grid.get_children():
		child.queue_free()

	var profile = UserManager.get_profile() if has_node("/root/UserManager") else null
	var wins: int = profile.wins if profile else 0
	var losses: int = profile.losses if profile else 0
	var total: int = profile.total_matches if profile else 0
	var rate := int(round(profile.get_win_rate() * 100.0)) if profile else 0

	_add_stat(str(wins), "VICTORIAS", UIPalette.HEAL)
	_add_stat(str(losses), "DERROTAS", UIPalette.LIFE)
	_add_stat("%d%%" % rate, "% VICTORIAS", UIPalette.GOLD_LIGHT)
	_add_stat(str(total), "PARTIDAS", UIPalette.ACCENT)


func _add_stat(value: String, caption: String, color: Color) -> void:
	var tile := PanelContainer.new()
	tile.theme_type_variation = &"StatTile"
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := tile.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = UIPalette.alpha(color, 0.85)
	tile.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -6)
	tile.add_child(box)

	var value_label := Label.new()
	value_label.theme_type_variation = &"StatValue"
	value_label.add_theme_color_override("font_color", color)
	value_label.text = value
	box.add_child(value_label)

	var caption_label := Label.new()
	caption_label.theme_type_variation = &"Eyebrow"
	caption_label.add_theme_font_size_override("font_size", 15)
	caption_label.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
	caption_label.text = caption
	box.add_child(caption_label)

	stats_grid.add_child(tile)


# ============================================================================
# MAZO ACTIVO EN ABANICO
# ============================================================================

func _build_fan(count: int) -> void:
	for card in _fan_cards:
		card.queue_free()
	_fan_cards.clear()

	var back: Texture2D = CardsManager.get_default_card_back() if has_node("/root/CardsManager") else null
	for i in count:
		var card := _make_fan_card(back)
		deck_showcase.add_child(card)
		_fan_cards.append(card)
	_restack_fan()
	_layout_fan()


## Orden de dibujo: de los extremos hacia el centro, para que la carta central quede encima.
## (Se usa el orden de hijos y no z_index para no tapar el panel social ni los avisos.)
func _restack_fan() -> void:
	var mid := (_fan_cards.size() - 1) / 2.0
	var by_depth := _fan_cards.duplicate()
	by_depth.sort_custom(func(a, b): return absf(_fan_cards.find(a) - mid) > absf(_fan_cards.find(b) - mid))
	for card in by_depth:
		deck_showcase.move_child(card, -1)


func _make_fan_card(texture: Texture2D) -> Control:
	var card := Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS

	var shadow := Panel.new()
	shadow.name = "Shadow"
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.0)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 26
	style.shadow_offset = Vector2(0, 16)
	shadow.add_theme_stylebox_override("panel", style)
	card.add_child(shadow)
	shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var art := TextureRect.new()
	art.name = "Art"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture = texture
	card.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	card.mouse_entered.connect(_on_fan_card_hover.bind(card, true))
	card.mouse_exited.connect(_on_fan_card_hover.bind(card, false))
	return card


func _layout_fan() -> void:
	var area := deck_showcase.size
	var count := _fan_cards.size()
	if count == 0 or area.y <= 0.0:
		return
	var mid := (count - 1) / 2.0
	# Alto limitado por el espacio vertical y por el ancho total del abanico: la mitad del
	# abanico es el desplazamiento de la carta exterior + media carta + lo que la rotación
	# (con pivote FAN_PIVOT·h por debajo) desplaza su esquina superior
	var outer_angle := deg_to_rad(mid * FAN_STEP_DEGREES)
	var half_factor := mid * FAN_SPREAD * CARD_RATIO + CARD_RATIO / 2.0 + FAN_PIVOT * sin(outer_angle)
	var h := minf(minf(area.y * 0.92, 480.0), area.x * 0.96 / (2.0 * half_factor))
	var w := h * CARD_RATIO
	var spread := w * FAN_SPREAD
	for i in count:
		var card := _fan_cards[i]
		var k := i - mid
		card.size = Vector2(w, h)
		# Pivote muy por debajo de la carta: al rotar, el abanico forma un arco
		card.pivot_offset = Vector2(w / 2.0, h * FAN_PIVOT)
		card.position = Vector2(area.x / 2.0 - w / 2.0 + k * spread, (area.y - h) / 2.0 + 10.0)
		card.rotation_degrees = k * FAN_STEP_DEGREES
		card.set_meta("base_y", card.position.y)


func _on_fan_card_hover(card: Control, entered: bool) -> void:
	var base_y: float = card.get_meta("base_y", card.position.y)
	var tween := create_tween().set_parallel()
	tween.tween_property(card, "position:y", base_y - (26.0 if entered else 0.0), 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if entered:
		deck_showcase.move_child(card, -1)
	else:
		_restack_fan()


func _on_showcase_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		SceneTransition.go_to_decks()


func _load_active_deck() -> void:
	if not has_node("/root/DecksManager"):
		return
	if not DecksManager.decks_loaded.is_connected(_on_decks_loaded):
		DecksManager.decks_loaded.connect(_on_decks_loaded)
	DecksManager.fetch_user_decks()


func _on_decks_loaded(_decks: Array) -> void:
	var deck: Dictionary = DecksManager.get_active_deck()
	if deck.is_empty():
		deck_name_label.text = "SIN MAZO ACTIVO"
		deck_count_label.text = "Elige o crea un mazo para jugar"
		change_deck_button.text = "ELEGIR MAZO"
		return

	var raw_name := str(deck.get("name", "")).strip_edges()
	deck_name_label.text = raw_name.to_upper() if raw_name != "" else "SIN NOMBRE"
	var total: int = DeckItemScript.count_cards(deck)
	deck_count_label.text = "%d cartas" % total
	change_deck_button.text = "CAMBIAR MAZO"

	var featured := _pick_featured_cards(deck)
	if featured.is_empty():
		return
	if featured.size() != _fan_cards.size():
		_build_fan(featured.size())
	for i in featured.size():
		_load_fan_card(_fan_cards[i], featured[i], i)


## Las cartas más vistosas del mazo: mayor rareza primero, luego mayor coste
func _pick_featured_cards(deck: Dictionary) -> Array:
	var cards = deck.get("cards", [])
	if cards is not Array:
		return []
	var unique: Array = []
	var seen := {}
	for card in cards:
		if card is not Dictionary or str(card.get("image_url", "")) == "":
			continue
		var id := str(card.get("id", ""))
		if seen.has(id):
			continue
		seen[id] = true
		unique.append(card)

	unique.sort_custom(func(a, b):
		var ra := UIPalette.rarity_rank(str(a.get("rarity", "common")))
		var rb := UIPalette.rarity_rank(str(b.get("rarity", "common")))
		if ra != rb:
			return ra > rb
		return int(a.get("cost", 0)) > int(b.get("cost", 0))
	)
	var top := unique.slice(0, FAN_SIZE)
	if top.size() < 3:
		return top
	# La mejor carta en el centro, las siguientes alternando a los lados
	var ordered: Array = []
	ordered.resize(top.size())
	var mid := (top.size() - 1) / 2
	for i in top.size():
		var offset := (i + 1) / 2 * (1 if i % 2 == 1 else -1)
		ordered[mid + offset] = top[i]
	return ordered


func _load_fan_card(card: Control, data: Dictionary, index: int) -> void:
	var art: TextureRect = card.get_node("Art")
	var shadow: Panel = card.get_node("Shadow")
	var rarity_color := UIPalette.rarity(str(data.get("rarity", "common")))
	var style := shadow.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.shadow_color = UIPalette.alpha(rarity_color, 0.45)
	shadow.add_theme_stylebox_override("panel", style)

	var target: WeakRef = weakref(card)
	CardsManager.get_cached_image(str(data.get("id", "")), str(data.get("image_url", "")), func(texture):
		var node: Control = target.get_ref()
		if node == null or texture == null:
			return
		# Volteo: la carta se cierra, cambia el dorso por el arte y se abre
		var flip := node.create_tween()
		flip.tween_interval(0.08 * index)
		flip.tween_property(art, "scale:x", 0.0, 0.12).set_trans(Tween.TRANS_SINE)
		flip.tween_callback(func(): art.texture = texture)
		flip.tween_property(art, "scale:x", 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		art.pivot_offset = art.size / 2.0
	)


# ============================================================================
# PANEL SOCIAL (chat y jugadores en línea)
# ============================================================================

func _toggle_drawer() -> void:
	if social_drawer.visible:
		_close_drawer()
	else:
		_open_drawer()


func _open_drawer() -> void:
	_unread_messages = 0
	chat_badge.visible = false
	social_drawer.visible = true
	var base_x := _drawer_base_x()
	social_drawer.position.x = base_x + DRAWER_SLIDE
	social_drawer.modulate.a = 0.0
	if _drawer_tween:
		_drawer_tween.kill()
	_drawer_tween = create_tween().set_parallel()
	_drawer_tween.tween_property(social_drawer, "position:x", base_x, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_drawer_tween.tween_property(social_drawer, "modulate:a", 1.0, 0.18)
	if chat_panel.has_method("focus_input"):
		chat_panel.focus_input()


func _close_drawer() -> void:
	if not social_drawer.visible:
		return
	var base_x := _drawer_base_x()
	if _drawer_tween:
		_drawer_tween.kill()
	_drawer_tween = create_tween().set_parallel()
	_drawer_tween.tween_property(social_drawer, "position:x", base_x + DRAWER_SLIDE, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_drawer_tween.tween_property(social_drawer, "modulate:a", 0.0, 0.18)
	_drawer_tween.chain().tween_callback(func():
		social_drawer.visible = false
		social_drawer.position.x = base_x
	)


func _drawer_base_x() -> float:
	# Posición según anclas: borde derecho de la pantalla + offset_left
	return size.x + social_drawer.offset_left


func _on_chat_message_received(_data: Dictionary) -> void:
	if social_drawer.visible:
		return
	_unread_messages += 1
	chat_badge_label.text = str(_unread_messages) if _unread_messages < 100 else "99+"
	chat_badge.visible = true
	chat_badge.pivot_offset = chat_badge.size / 2.0
	chat_badge.scale = Vector2(0.4, 0.4)
	create_tween().tween_property(chat_badge, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_online_users_updated(users: Array) -> void:
	online_button.text = "%d EN LÍNEA" % users.size()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and social_drawer.visible:
		_close_drawer()
		get_viewport().set_input_as_handled()


# ============================================================================
# AVISOS DE PARTIDA Y EMAIL
# ============================================================================

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
	UserManager.profile_loaded.connect(func(_profile):
		_update_verify_notice()
		_load_user_info()
		_build_stats()
	)
	_update_verify_notice()


func _update_verify_notice() -> void:
	var profile = UserManager.get_profile()
	verify_notice.visible = profile != null and not profile.is_email_verified


func _on_match_error(message: String) -> void:
	toast.show_message(message, true)


# ============================================================================
# ANIMACIONES
# ============================================================================

func _play_intro() -> void:
	"""Entrada: barra superior desde arriba, columnas laterales, cartas repartidas y botón JUGAR"""
	await get_tree().process_frame
	if not is_inside_tree():
		return

	_slide_in(top_bar, Vector2(0, -40), 0.0)
	_slide_in(left_column, Vector2(-50, 0), 0.12)
	_slide_in(right_column, Vector2(50, 0), 0.12)

	for i in _fan_cards.size():
		var card := _fan_cards[i]
		var base_y: float = card.get_meta("base_y", card.position.y)
		card.position.y = base_y + 260.0
		card.modulate.a = 0.0
		var deal := create_tween().set_parallel()
		deal.tween_property(card, "position:y", base_y, 0.5).set_delay(0.15 + 0.07 * i) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		deal.tween_property(card, "modulate:a", 1.0, 0.25).set_delay(0.15 + 0.07 * i)

	play_row.pivot_offset = play_row.size / 2.0
	play_row.scale = Vector2(0.7, 0.7)
	play_row.modulate.a = 0.0
	var pop := create_tween().set_parallel()
	pop.tween_property(play_row, "scale", Vector2.ONE, 0.45).set_delay(0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(play_row, "modulate:a", 1.0, 0.2).set_delay(0.45)


func _slide_in(node: Control, from_offset: Vector2, delay: float) -> void:
	var target := node.position
	node.position = target + from_offset
	node.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(node, "position", target, 0.4).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, 0.3).set_delay(delay)


# ============================================================================
# RED Y NAVEGACIÓN
# ============================================================================

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

	var messages: Array = []
	if data is Dictionary:
		messages = data.get("messages", []) as Array
	elif data is Array:
		messages = data
	if chat_panel and chat_panel.has_method("load_initial_messages"):
		chat_panel.load_initial_messages(messages)


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
