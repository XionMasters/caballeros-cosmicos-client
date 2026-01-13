# OnlineUsersList.gd
extends VBoxContainer

@onready var users_title = $UsersTitle
@onready var users_list = $UsersScroll/UsersList

var websocket_manager
var user_entries = {}  # Dictionary para trackear entries por user_id

func _ready():
	# Conectar WebSocket
	if has_node("/root/WebSocketManager"):
		websocket_manager = get_node("/root/WebSocketManager")
		if websocket_manager.has_signal("online_users_updated"):
			websocket_manager.online_users_updated.connect(_on_online_users_updated)

func _on_online_users_updated(users: Array):
	"""Actualizar lista de usuarios en línea"""
	# Actualizar título con cantidad
	users_title.text = "👥 Usuarios en línea (%d)" % users.size()
	
	# Limpiar usuarios que ya no están
	var current_user_ids = []
	for user in users:
		current_user_ids.append(user.get("user_id", user.get("userId", "")))
	
	for user_id in user_entries.keys():
		if user_id not in current_user_ids:
			var entry = user_entries[user_id]
			entry.queue_free()
			user_entries.erase(user_id)
	
	# Agregar o actualizar usuarios
	for user in users:
		_update_or_create_user_entry(user)

func _update_or_create_user_entry(user_data: Dictionary):
	"""Crear o actualizar entrada de usuario"""
	var user_id = user_data.get("user_id", user_data.get("userId", ""))
	
	if user_id in user_entries:
		# Actualizar existente
		_update_user_entry(user_entries[user_id], user_data)
	else:
		# Crear nuevo
		var entry = _create_user_entry(user_data)
		users_list.add_child(entry)
		user_entries[user_id] = entry

func _create_user_entry(user_data: Dictionary) -> HBoxContainer:
	"""Crear UI para un usuario"""
	var container = HBoxContainer.new()
	container.custom_minimum_size.y = 60
	
	# Avatar
	var avatar_rect = TextureRect.new()
	avatar_rect.custom_minimum_size = Vector2(50, 50)
	avatar_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar_rect.name = "Avatar"
	container.add_child(avatar_rect)
	
	# Cargar avatar
	var avatar_url = user_data.get("avatar_url", user_data.get("avatarUrl", ""))
	if avatar_url.is_empty():
		avatar_url = "/assets/avatars/avatar_1.png" # Fallback
	_load_avatar_texture(avatar_rect, avatar_url)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.x = 10
	container.add_child(spacer)
	
	# Info container
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(info)
	
	# Username
	var username_label = Label.new()
	username_label.name = "Username"
	username_label.text = user_data.get("username", "Unknown")
	username_label.add_theme_font_size_override("font_size", 16)
	info.add_child(username_label)
	
	# Status
	var status_label = Label.new()
	status_label.name = "Status"
	_update_status_label(status_label, user_data.get("status", "online"))
	info.add_child(status_label)
	
	# Separador
	var separator = HSeparator.new()
	separator.modulate = Color(1, 1, 1, 0.2)
	container.add_child(separator)
	
	return container

func _update_user_entry(entry: HBoxContainer, user_data: Dictionary):
	"""Actualizar datos de una entrada existente"""
	# Actualizar username
	var username_label = entry.get_node_or_null("Username")
	if username_label:
		username_label.text = user_data.get("username", "Unknown")
	
	# Actualizar status
	var status_label = entry.get_node_or_null("Status")
	if status_label:
		_update_status_label(status_label, user_data.get("status", "online"))
	
	# Actualizar avatar si cambió
	var avatar_rect = entry.get_node_or_null("Avatar")
	var new_avatar_url = user_data.get("avatar_url", user_data.get("avatarUrl", ""))
	if avatar_rect:
		if new_avatar_url.is_empty():
			new_avatar_url = "/assets/avatars/avatar_1.png"
		_load_avatar_texture(avatar_rect, new_avatar_url)

func _update_status_label(label: Label, status: String):
	"""Actualizar label de estado con emoji y color"""
	var status_text = ""
	var status_color = Color.WHITE
	
	match status:
		"online":
			status_text = "🟢 En línea"
			status_color = Color(0.3, 1, 0.3)
		"in_match":
			status_text = "⚔️ En partida"
			status_color = Color(1, 0.8, 0.2)
		"away":
			status_text = "🌙 Ausente"
			status_color = Color(0.6, 0.6, 0.6)
		_:
			status_text = "❓ Desconocido"
	
	label.text = status_text
	label.modulate = status_color
	label.add_theme_font_size_override("font_size", 12)

func _load_avatar_texture(texture_rect: TextureRect, avatar_url: String):
	"""Cargar imagen de avatar desde URL"""
	var http = HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(_result, code, _headers, body):
		if code == 200:
			var image = Image.new()
			var error
			
			# Detectar formato por extensión
			if avatar_url.ends_with(".webp"):
				error = image.load_webp_from_buffer(body)
			elif avatar_url.ends_with(".png"):
				error = image.load_png_from_buffer(body)
			elif avatar_url.ends_with(".jpg") or avatar_url.ends_with(".jpeg"):
				error = image.load_jpg_from_buffer(body)
			else:
				# Intentar WebP por defecto
				error = image.load_webp_from_buffer(body)
			
			if error == OK:
				var texture = ImageTexture.create_from_image(image)
				texture_rect.texture = texture
		
		http.queue_free()
	)
	
	# Construir URL completa
	var api_base = GameConfig.API_URL.replace("/api", "")
	var full_url = api_base + avatar_url if avatar_url.begins_with("/") else avatar_url
	if not full_url.begins_with("http"):
		full_url = api_base + "/" + avatar_url.trim_prefix("/")
	http.request(full_url)
