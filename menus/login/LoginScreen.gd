extends Control

@onready var email_input = $CenterContainer/LoginPanel/VBoxContainer/EmailInput
@onready var password_input = $CenterContainer/LoginPanel/VBoxContainer/PasswordInput
@onready var username_input = $CenterContainer/LoginPanel/VBoxContainer/UsernameInput
@onready var login_button = $CenterContainer/LoginPanel/VBoxContainer/LoginButton
@onready var register_button = $CenterContainer/LoginPanel/VBoxContainer/RegisterButton
@onready var toggle_mode_button = $CenterContainer/LoginPanel/VBoxContainer/ToggleModeButton
@onready var error_label = $CenterContainer/LoginPanel/VBoxContainer/ErrorLabel
@onready var loading_label = $CenterContainer/LoginPanel/VBoxContainer/LoadingLabel
@onready var background = $Background
@onready var login_panel: PanelContainer = $CenterContainer/LoginPanel
@onready var title_label: Label = $CenterContainer/LoginPanel/VBoxContainer/Title
@onready var subtitle_label: Label = $CenterContainer/LoginPanel/VBoxContainer/Subtitle

var is_login_mode: bool = true

func _ready():
	# Verificar que los nodos existen
	if not register_button:
		push_error("RegisterButton no encontrado")
		return
	if not login_button:
		push_error("LoginButton no encontrado")
		return
		
	AuthManager.login_successful.connect(_on_login_successful)
	AuthManager.login_failed.connect(_on_login_failed)
	AuthManager.registration_successful.connect(_on_registration_successful)
	AuthManager.registration_failed.connect(_on_registration_failed)
	
	login_button.pressed.connect(_on_login_pressed)
	register_button.pressed.connect(_on_register_pressed)
	toggle_mode_button.pressed.connect(_on_toggle_mode_pressed)
	
	# Conectar Enter en password input para hacer login
	password_input.text_submitted.connect(_on_password_submitted)
	
	update_mode_ui()
	apply_translations()
	_apply_styles()
	_play_intro()

	# Conectar cambios de idioma
	LocalizationManager.language_changed.connect(_on_language_changed)

	if AuthManager.is_logged_in():
		go_to_main_menu()

func _on_login_pressed():
	var email = email_input.text.strip_edges()
	var password = password_input.text
	
	if email.is_empty() or password.is_empty():
		show_error("Por favor completa todos los campos")
		return
	
	show_loading(true)
	error_label.text = ""
	_ignite_cosmos()
	AuthManager.login(email, password)

func _on_register_pressed():
	print("🎯 Botón de registro presionado")
	var email = email_input.text.strip_edges()
	var password = password_input.text
	var username = username_input.text.strip_edges()
	
	print("📝 Email: ", email)
	print("📝 Username: ", username)
	
	if email.is_empty() or password.is_empty() or username.is_empty():
		show_error("Por favor completa todos los campos")
		return
	
	if username.length() < 3:
		show_error("El nombre de usuario debe tener al menos 3 caracteres")
		return
	
	if password.length() < 6:
		show_error("La contraseña debe tener al menos 6 caracteres")
		return
	
	show_loading(true)
	error_label.text = ""
	_ignite_cosmos()
	AuthManager.register(email, password, username)

func _on_toggle_mode_pressed():
	print("🔄 Cambiando modo. Antes: ", is_login_mode)
	is_login_mode = !is_login_mode
	print("🔄 Después: ", is_login_mode)
	update_mode_ui()

func update_mode_ui():
	if is_login_mode:
		username_input.visible = false
		login_button.visible = true
		register_button.visible = false
		toggle_mode_button.text = "¿No tienes cuenta? Regístrate"
		error_label.text = ""
	else:
		username_input.visible = true
		login_button.visible = false
		register_button.visible = true
		toggle_mode_button.text = "¿Ya tienes cuenta? Inicia sesión"
		error_label.text = ""

func _on_login_successful(user_profile: UserProfile):
	show_loading(false)
	print("✅ Login exitoso: ", user_profile.username)
	if is_inside_tree():
		go_to_main_menu()

func _on_login_failed(error_msg):
	show_loading(false)
	show_error(error_msg)

func _on_registration_successful(user_profile: UserProfile):
	show_loading(false)
	print("✅ Registro exitoso: ", user_profile.username)
	go_to_main_menu()

func _on_registration_failed(error_msg):
	show_loading(false)
	show_error(error_msg)

func _on_password_submitted(_text: String):
	"""Ejecutar login al presionar Enter en el campo de password"""
	if is_login_mode:
		_on_login_pressed()
	else:
		_on_register_pressed()

func show_error(msg: String):
	error_label.text = msg
	# Pequeña sacudida del panel para llamar la atención
	var origin := login_panel.position
	var shake := create_tween()
	for offset in [8.0, -6.0, 4.0, -2.0, 0.0]:
		shake.tween_property(login_panel, "position:x", origin.x + offset, 0.05)

func show_loading(state: bool):
	loading_label.visible = state
	login_button.disabled = state
	register_button.disabled = state

func go_to_main_menu():
	var tree := get_tree()
	if tree == null:
		push_error("[LoginScreen] No se puede cambiar de escena: tree es null")
		return
	# Usar llamada diferida para evitar cambios de escena durante señales tempranas
	call_deferred("_deferred_go_to_main")

func _deferred_go_to_main():
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree:
		SceneTransition.go_to_mainlobby()

func apply_translations() -> void:
	"""Aplicar traducciones a todos los elementos de UI"""
	if not LocalizationManager:
		push_error("[LoginScreen] LocalizationManager no encontrado")
		return
	
	# translate() es el del gestor; tr() es el nativo de Godot y devolvería la clave tal cual
	email_input.placeholder_text = LocalizationManager.translate("email")
	password_input.placeholder_text = LocalizationManager.translate("password")
	username_input.placeholder_text = LocalizationManager.translate("username")

	# Ambos botones llevan su texto siempre: al cambiar de modo solo cambia cuál se ve
	login_button.text = LocalizationManager.translate("login").to_upper()
	register_button.text = LocalizationManager.translate("register").to_upper()
	if is_login_mode:
		toggle_mode_button.text = "¿No tienes cuenta? " + LocalizationManager.translate("register")
	else:
		toggle_mode_button.text = "¿Ya tienes cuenta? " + LocalizationManager.translate("login")

func _on_language_changed(_language: String) -> void:
	"""Callback cuando cambia el idioma"""
	apply_translations()


# ============================================================================
# ESTILO Y ANIMACIONES
# ============================================================================

func _apply_styles() -> void:
	"""Panel y controles con las variantes del tema global (ui/theme/build_theme.gd)"""
	login_panel.theme_type_variation = &"BannerPanel"
	login_panel.add_theme_stylebox_override("panel", _login_panel_style())

	# Título enorme con contorno, como el rótulo de un juego de cartas
	title_label.theme_type_variation = &"HeroTitle"
	title_label.add_theme_font_size_override("font_size", 60)
	title_label.add_theme_color_override("font_color", UIPalette.GOLD_LIGHT)
	subtitle_label.theme_type_variation = &"Eyebrow"
	subtitle_label.add_theme_font_size_override("font_size", 20)

	for button in [login_button, register_button]:
		button.theme_type_variation = &"PlayButton"
		button.add_theme_font_size_override("font_size", 30)

	toggle_mode_button.flat = false
	toggle_mode_button.theme_type_variation = &"GhostButton"


func _login_panel_style() -> StyleBoxFlat:
	# Mismo panel protagonista del tema, con más aire interior para el formulario
	var style := login_panel.get_theme_stylebox("panel", &"BannerPanel").duplicate() as StyleBoxFlat
	style.set_content_margin_all(40)
	return style


func _play_intro() -> void:
	"""Entrada: el panel aparece desde abajo y el título empieza a pulsar"""
	login_panel.modulate.a = 0.0
	title_label.modulate.a = 0.0
	await get_tree().process_frame  # esperar a que el CenterContainer ubique el panel
	if not is_inside_tree():
		return

	login_panel.pivot_offset = login_panel.size / 2.0
	login_panel.scale = Vector2(0.94, 0.94)
	var intro := create_tween().set_parallel()
	intro.tween_property(login_panel, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	intro.tween_property(login_panel, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.tween_property(title_label, "modulate:a", 1.0, 1.2).set_delay(0.3)
	await intro.finished

	# Brillo del título como cosmos que arde
	var glow := create_tween().set_loops()
	glow.tween_property(title_label, "modulate", Color(1.25, 1.2, 1.05), 1.6).set_trans(Tween.TRANS_SINE)
	glow.tween_property(title_label, "modulate", Color.WHITE, 1.6).set_trans(Tween.TRANS_SINE)


func _ignite_cosmos() -> void:
	if background and background.has_method("ignite_cosmos"):
		background.ignite_cosmos()
