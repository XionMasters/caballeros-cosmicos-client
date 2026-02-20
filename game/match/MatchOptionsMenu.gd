# MatchOptionsMenu.gd
# Menú desplegable para opciones de partida (abandonar, etc)
extends MenuButton
class_name MatchOptionsMenu

var game_match: Control = null

func _ready() -> void:
	print("[MatchOptionsMenu] 🎯 Inicializando menú de opciones...")
	
	# Obtener referencia a GameMatch
	game_match = $"../../../.."
	
	# Crear menú desplegable
	var popup = get_popup()
	popup.add_item("Abandonar Partida", 0)
	popup.add_separator()
	popup.add_item("Cerrar", 1)
	
	# Conectar signals
	popup.id_pressed.connect(_on_menu_option_selected)
	
	print("[MatchOptionsMenu] ✅ Menú de opciones creado")


func _on_menu_option_selected(id: int) -> void:
	"""Manejar selección de opción del menú"""
	print("[MatchOptionsMenu] 📋 Opción seleccionada: %d" % id)
	
	match id:
		0:  # Abandonar partida
			_confirm_abandon()
		1:  # Cerrar (sin hacer nada)
			pass


func _confirm_abandon() -> void:
	"""Mostrar confirmación antes de abandonar"""
	print("[MatchOptionsMenu] ❓ Pidiendo confirmación para abandonar...")
	
	var dialog = ConfirmationDialog.new()
	dialog.title = "Abandonar Partida"
	dialog.dialog_text = "¿Estás seguro de que deseas abandonar la partida?\n\nSerá registrada como una derrota."
	dialog.ok_button_text = "Sí, abandonar"
	dialog.cancel_button_text = "Cancelar"
	
	# Conectar respuesta
	dialog.confirmed.connect(_on_abandon_confirmed)
	
	# Agregar y mostrar
	add_child(dialog)
	dialog.popup_centered_ratio(0.5)


func _on_abandon_confirmed() -> void:
	"""Proceder a abandonar la partida"""
	print("[MatchOptionsMenu] 🚪 Abandonando partida...")
	
	# Mostrar pantalla de espera
	var loading = _show_loading_screen("Finalizando partida...")
	
	if MatchSessionService.is_in_match:
		var match_id = MatchSessionService.current_match.get("id", "")
		print("[MatchOptionsMenu] 📤 Enviando abandono del match: %s" % match_id)
		
		# Enviar solicitud de abandono (callback maneja todo)
		_send_abandon_request(match_id, loading)
	else:
		print("[MatchOptionsMenu] ⚠️ No hay match activa")
		if loading:
			loading.queue_free()
		_return_to_lobby()


func _send_abandon_request(match_id: String, loading_screen: Control) -> void:
	"""Enviar solicitud de abandono al servidor"""
	print("[MatchOptionsMenu] 📤 Enviando solicitud de abandono: %s" % match_id)
	
	var callback = func(success: bool, data: Variant, error: String) -> void:
		if success:
			print("[MatchOptionsMenu] ✅ Partida abandonada exitosamente")
			print("[MatchOptionsMenu] 📊 Datos recibidos: %s" % data)
			
			# Limpiar estado del cliente INMEDIATAMENTE
			MatchSessionService.is_in_match = false
			MatchSessionService.current_match = {}
			MatchSessionService.game_state = null
			print("[MatchOptionsMenu] 🧹 Estado del MatchManager limpiado")
			print("[MatchOptionsMenu]    - is_in_match: %s" % MatchSessionService.is_in_match)
			print("[MatchOptionsMenu]    - current_match vacío: %s" % MatchSessionService.current_match.is_empty())
			print("[MatchOptionsMenu]    - game_state: %s" % MatchSessionService.game_state)
			
			# Esperar 3 segundos para que el servidor procese completamente la finalización
			# El servidor hace await match.save() + 500ms delay interno
			print("[MatchOptionsMenu] ⏳ Esperando 3 segundos para que el servidor finalice la partida...")
			await get_tree().create_timer(3.0).timeout
			
			print("[MatchOptionsMenu] 🔔 Tiempo de espera completado, verificando y retornando al lobby")
			
			if loading_screen:
				loading_screen.queue_free()
			
			_return_to_lobby()
		else:
			print("[MatchOptionsMenu] ❌ Error abandonando partida: %s" % error)
			if loading_screen:
				loading_screen.queue_free()
			
			_show_error_and_return("Error al abandonar: %s" % error)
	
	# Llamar endpoint de abandono
	ApiClient.post_request_with_callback(
		"/matches/%s/abandon" % match_id,
		{},  # Sin body
		"abandon_%s" % match_id,
		callback,
		true  # Con autenticación
	)


func _show_loading_screen(message: String) -> Control:
	"""Mostrar pantalla de carga"""
	var loading = ColorRect.new()
	loading.color = Color(0, 0, 0, 0.8)
	loading.anchors_preset = Control.PRESET_FULL_RECT
	
	var label = Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchors_preset = Control.PRESET_CENTER
	
	loading.add_child(label)
	add_child(loading)
	
	return loading


func _return_to_lobby() -> void:
	"""Volver al lobby principal"""
	print("[MatchOptionsMenu] 🔙 Retornando al lobby...")
	
	# Desconectar WebSocket si es necesario
	if MatchSessionService.is_in_match:
		MatchSessionService.is_in_match = false
	
	# Cambiar escena al lobby
	SceneTransition.go_to_mainlobby()


func _show_error_and_return(error_msg: String) -> void:
	"""Mostrar error y retornar al lobby"""
	print("[MatchOptionsMenu] ⚠️ Error: %s" % error_msg)
	
	var dialog = AcceptDialog.new()
	dialog.title = "Error"
	dialog.dialog_text = error_msg
	dialog.ok_button_text = "Aceptar"
	
	dialog.confirmed.connect(func(): _return_to_lobby())
	
	add_child(dialog)
	dialog.popup_centered_ratio(0.5)
