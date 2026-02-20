extends Control

@onready var email_input = $CenterContainer/LoginPanel/VBoxContainer/EmailInput
@onready var password_input = $CenterContainer/LoginPanel/VBoxContainer/PasswordInput
@onready var username_input = $CenterContainer/LoginPanel/VBoxContainer/UsernameInput
@onready var login_button = $CenterContainer/LoginPanel/VBoxContainer/LoginButton
@onready var register_button = $CenterContainer/LoginPanel/VBoxContainer/RegisterButton
@onready var toggle_mode_button = $CenterContainer/LoginPanel/VBoxContainer/ToggleModeButton
@onready var error_label = $CenterContainer/LoginPanel/VBoxContainer/ErrorLabel
@onready var loading_label = $CenterContainer/LoginPanel/VBoxContainer/LoadingLabel

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
	
	# Conectar cambios de idioma
	LocalizationManager.language_changed.connect(_on_language_changed)
	
	print("🔍 Login mode: ", is_login_mode)
	print("🔍 Register button visible: ", register_button.visible)
	print("🔍 Login button visible: ", login_button.visible)
	
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
	print("📡 Enviando registro a AuthManager...")
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
	error_label.text = "❌ " + msg
	error_label.add_theme_color_override("font_color", Color.RED)

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
	
	email_input.placeholder_text = LocalizationManager.tr("email")
	password_input.placeholder_text = LocalizationManager.tr("password")
	username_input.placeholder_text = LocalizationManager.tr("username")
	
	if is_login_mode:
		login_button.text = LocalizationManager.tr("login")
		toggle_mode_button.text = "¿No tienes cuenta? " + LocalizationManager.tr("register")
	else:
		register_button.text = LocalizationManager.tr("register")
		toggle_mode_button.text = "¿Ya tienes cuenta? " + LocalizationManager.tr("login")

func _on_language_changed(_language: String) -> void:
	"""Callback cuando cambia el idioma"""
	apply_translations()
