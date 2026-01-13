# ProfileScene.gd
extends Control

@onready var back_button = $MarginContainer/VBoxContainer/TopBar/BackButton
@onready var current_avatar = $MarginContainer/VBoxContainer/ContentContainer/LeftPanel/CurrentAvatarPanel/MarginContainer/VBoxContainer/CurrentAvatar
@onready var username_label = $MarginContainer/VBoxContainer/ContentContainer/LeftPanel/CurrentAvatarPanel/MarginContainer/VBoxContainer/Username
@onready var wins_label = $MarginContainer/VBoxContainer/ContentContainer/LeftPanel/StatsPanel/MarginContainer/VBoxContainer/WinsLabel
@onready var losses_label = $MarginContainer/VBoxContainer/ContentContainer/LeftPanel/StatsPanel/MarginContainer/VBoxContainer/LossesLabel
@onready var total_label = $MarginContainer/VBoxContainer/ContentContainer/LeftPanel/StatsPanel/MarginContainer/VBoxContainer/TotalLabel
@onready var winrate_label = $MarginContainer/VBoxContainer/ContentContainer/LeftPanel/StatsPanel/MarginContainer/VBoxContainer/WinRateLabel
@onready var avatars_grid = $MarginContainer/VBoxContainer/ContentContainer/RightPanel/AvatarsScroll/AvatarsGrid
@onready var loading_label = $LoadingLabel
@onready var confirm_dialog = $ConfirmDialog

var profile_data: Dictionary = {}
var available_avatars: Array = []
var selected_avatar_id: String = ""
var API_URL = GameConfig.API_URL

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	confirm_dialog.confirmed.connect(_on_confirm_change_avatar)
	
	_load_profile_data()

func _load_profile_data():
	"""Cargar datos del perfil y avatares disponibles"""
	loading_label.visible = true
	
	# Cargar perfil
	var http_profile = HTTPRequest.new()
	add_child(http_profile)
	http_profile.request_completed.connect(_on_profile_loaded)
	http_profile.request(API_URL + "/profile", AuthManager.get_auth_headers())
	
	# Cargar avatares disponibles
	var http_avatars = HTTPRequest.new()
	add_child(http_avatars)
	http_avatars.request_completed.connect(_on_avatars_loaded)
	http_avatars.request(API_URL + "/profile/avatars", AuthManager.get_auth_headers())

func _on_profile_loaded(_result, response_code, _headers, body):
	if response_code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			profile_data = json.data
			_update_profile_ui()
	else:
		push_error("Error cargando perfil: " + str(response_code))

func _on_avatars_loaded(_result, response_code, _headers, body):
	loading_label.visible = false
	
	if response_code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			# Servidor envía { avatars: [...] }, extraer el array
			var response_data = json.data
			if response_data is Dictionary:
				available_avatars = response_data.get("avatars", [])
			else:
				available_avatars = response_data
			_populate_avatar_gallery()
	else:
		push_error("Error cargando avatares: " + str(response_code))

func _update_profile_ui():
	"""Actualizar UI con datos del perfil"""
	# Usuario desde UserManager
	username_label.text = UserManager.get_username()
	
	# Avatar actual
	var profile = profile_data.get("profile", {})
	var avatar = profile.get("avatar", {})
	var avatar_url = avatar.get("image_url", "")
	print("[ProfileUI] Avatar URL:", avatar_url)
	if not avatar_url.is_empty():
		_load_avatar_image(current_avatar, avatar_url)
	
	# Stats desde UserManager
	var stats = UserManager.get_stats()
	var wins = stats.get("wins", 0)
	var losses = stats.get("losses", 0)
	var total = stats.get("total_matches", 0)
	var winrate = stats.get("win_rate", 0.0) * 100.0
	
	wins_label.text = "Victorias: %d" % wins
	losses_label.text = "Derrotas: %d" % losses
	total_label.text = "Total partidas: %d" % total
	winrate_label.text = "%% Victorias: %.1f%%" % winrate

func _populate_avatar_gallery():
	"""Poblar galería con avatares disponibles"""
	# Limpiar grid
	for child in avatars_grid.get_children():
		child.queue_free()
	
	# Agregar cada avatar
	for avatar_data in available_avatars:
		var avatar_item = _create_avatar_item(avatar_data)
		avatars_grid.add_child(avatar_item)

func _create_avatar_item(avatar_data: Dictionary) -> Control:
	"""Crear item de avatar para la galería"""
	var container = PanelContainer.new()
	container.custom_minimum_size = Vector2(180, 220)
	
	# Determinar si está bloqueado
	var is_unlocked = avatar_data.get("is_unlocked", false)
	var profile_info = profile_data.get("profile", {})
	var current_avatar_id = profile_info.get("avatar", {}).get("id", "")
	var is_current = avatar_data.get("id") == current_avatar_id
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	container.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	
	# Imagen del avatar
	var texture_rect = TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(150, 150)
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(texture_rect)
	
	# Cargar imagen
	var image_url = avatar_data.get("image_url", "")
	if not image_url.is_empty():
		_load_avatar_image(texture_rect, image_url)
	
	# Overlay si está bloqueado
	if not is_unlocked:
		var lock_label = Label.new()
		lock_label.text = "🔒"
		lock_label.add_theme_font_size_override("font_size", 48)
		lock_label.position = Vector2(60, 50)
		texture_rect.add_child(lock_label)
		
		texture_rect.modulate = Color(0.4, 0.4, 0.4, 1)
	
	# Nombre del avatar
	var name_label = Label.new()
	name_label.text = avatar_data.get("name", "Unknown")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	# Botón de selección
	var select_button = Button.new()
	
	if is_current:
		select_button.text = "✓ Actual"
		select_button.disabled = true
	elif is_unlocked:
		select_button.text = "Seleccionar"
		select_button.pressed.connect(_on_avatar_selected.bind(avatar_data.get("id", "")))
	else:
		# Mostrar requisito
		var required_card = avatar_data.get("required_card", {})
		var card_name = required_card.get("name", "carta legendaria")
		select_button.text = "Requiere: " + card_name
		select_button.disabled = true
	
	vbox.add_child(select_button)
	
	return container

func _load_avatar_image(texture_rect: TextureRect, avatar_url: String):
	"""Cargar imagen de avatar detectando Content-Type y usando fallbacks si no hay extensión"""
	var http = HTTPRequest.new()
	add_child(http)

	http.request_completed.connect(func(_result, code, headers, body):
		# ==== LOGS TEMPORALES DE DEPURACIÓN (REMOVER LUEGO) ====
		print("[AvatarLoader] URL:", avatar_url)
		print("[AvatarLoader] HTTP Code:", code)
		print("[AvatarLoader] Headers count:", headers.size())
		for h in headers:
			if h.begins_with("Content-Type:"):
				print("[AvatarLoader] Raw Header Content-Type:", h)
		print("[AvatarLoader] Body size:", body.size())
		var preview = []
		var limit = min(16, body.size())
		for i in range(limit):
			preview.append(body[i])
		print("[AvatarLoader] Body first bytes:", preview)
		# =======================================================
		if code == 200:
			var image = Image.new()
			var content_type = ""
			for h in headers:
				if h.begins_with("Content-Type:"):
					content_type = h.substr(13).strip_edges()
					break
			print("[AvatarLoader] Parsed Content-Type:", content_type)

			var err = ERR_PARSE_ERROR
			match content_type:
				"image/png":
					err = image.load_png_from_buffer(body)
				"image/webp":
					err = image.load_webp_from_buffer(body)
				"image/jpeg":
					err = image.load_jpg_from_buffer(body)
				_:
					# Fallback secuencial si content-type desconocido o vacío
					err = image.load_png_from_buffer(body)
					if err != OK:
						err = image.load_webp_from_buffer(body)
					if err != OK:
						err = image.load_jpg_from_buffer(body)
			print("[AvatarLoader] Load error code:", err)

			if err == OK:
				var texture = ImageTexture.create_from_image(image)
				texture_rect.texture = texture
		else:
			push_error("Error HTTP avatar: " + str(code))

		http.queue_free()
	)

	# Request directo (URL completa ya proporcionada por el backend)
	http.request(avatar_url)

func _on_avatar_selected(avatar_id: String):
	"""Mostrar confirmación para cambiar avatar"""
	selected_avatar_id = avatar_id
	confirm_dialog.popup_centered()

func _on_confirm_change_avatar():
	"""Confirmar cambio de avatar"""
	if selected_avatar_id.is_empty():
		return
	
	loading_label.visible = true
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_avatar_changed)
	
	var body = JSON.stringify({"avatar_id": selected_avatar_id})
	http.request(
		API_URL + "/profile/avatar",
		AuthManager.get_auth_headers(),
		HTTPClient.METHOD_PUT,
		body
	)

func _on_avatar_changed(_result, response_code, _headers, body):
	loading_label.visible = false
	
	if response_code == 200:
		print("✅ Avatar cambiado exitosamente")
		# Recargar datos
		_load_profile_data()
	else:
		var error_msg = "Error cambiando avatar"
		
		if body.size() > 0:
			var json = JSON.new()
			if json.parse(body.get_string_from_utf8()) == OK:
				error_msg = json.data.get("error", error_msg)
		
		push_error(error_msg)
		# Mostrar mensaje al usuario
		var error_dialog = AcceptDialog.new()
		error_dialog.dialog_text = error_msg
		add_child(error_dialog)
		error_dialog.popup_centered()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/menus/MainLobby.tscn")
