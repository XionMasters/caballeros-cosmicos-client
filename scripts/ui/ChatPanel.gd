# ChatPanel.gd
extends PanelContainer

@onready var messages_container = $MarginContainer/VBoxContainer/MessagesScroll/MessagesContainer
@onready var messages_scroll = $MarginContainer/VBoxContainer/MessagesScroll
@onready var message_input = $MarginContainer/VBoxContainer/InputPanel/MessageInput
@onready var send_button = $MarginContainer/VBoxContainer/InputPanel/SendButton

var websocket_manager
var max_messages = 100  # Límite de mensajes en pantalla

func _ready():
	# Conectar WebSocket
	if has_node("/root/WebSocketManager"):
		websocket_manager = get_node("/root/WebSocketManager")
		if websocket_manager.has_signal("chat_message_received"):
			websocket_manager.chat_message_received.connect(_on_chat_message_received)
	
	# Conectar eventos de UI
	send_button.pressed.connect(_send_message)
	message_input.text_submitted.connect(_on_text_submitted)
	
	# Focus en el input
	message_input.grab_focus()

func load_initial_messages(messages: Array):
	"""Cargar mensajes iniciales desde la API REST"""
	for message_data in messages:
		_add_message_to_ui(message_data)

func _on_text_submitted(_text: String):
	_send_message()

func _send_message():
	var message_text = message_input.text.strip_edges()
	
	if message_text.is_empty():
		return
	
	if message_text.length() > 500:
		_show_error("Mensaje muy largo (máximo 500 caracteres)")
		return
	
	if websocket_manager and websocket_manager.has_method("send_chat_message"):
		websocket_manager.send_chat_message(message_text)
		message_input.clear()
		message_input.grab_focus()
	else:
		_show_error("No estás conectado al servidor")

func _on_chat_message_received(data: Dictionary):
	"""Evento recibido del WebSocket cuando llega un nuevo mensaje"""
	_add_message_to_ui(data)

func _add_message_to_ui(message_data: Dictionary):
	"""Agregar un mensaje al contenedor de mensajes"""
	var message_label = RichTextLabel.new()
	message_label.bbcode_enabled = true
	message_label.fit_content = true
	message_label.scroll_active = false
	message_label.custom_minimum_size.y = 30
	
	# Formato del mensaje
	var username = message_data.get("username", "Unknown")
	var message = message_data.get("message", "")
	var timestamp = _format_timestamp(message_data.get("created_at", ""))
	
	# Color según tipo de mensaje
	var color = "#FFFFFF"
	match message_data.get("message_type", "global"):
		"system":
			color = "#FFD700"  # Dorado
			username = "SISTEMA"
		"whisper":
			color = "#FF69B4"  # Rosa
	
	message_label.text = "[color=#888]%s[/color] [color=%s][b]%s:[/b][/color] %s" % [timestamp, color, username, message]
	
	messages_container.add_child(message_label)
	
	# Limitar cantidad de mensajes
	if messages_container.get_child_count() > max_messages:
		var oldest = messages_container.get_child(0)
		oldest.queue_free()
	
	# Auto-scroll al final
	await get_tree().process_frame
	messages_scroll.scroll_vertical = int(messages_scroll.get_v_scroll_bar().max_value)

func _format_timestamp(iso_string: String) -> String:
	"""Convertir timestamp ISO a formato legible"""
	if iso_string.is_empty():
		return Time.get_time_string_from_system()
	
	# Extraer hora:minuto del ISO string (ej: "2025-11-20T15:30:45.123Z" -> "15:30")
	var parts = iso_string.split("T")
	if parts.size() > 1:
		var time_part = parts[1].split(":")
		if time_part.size() >= 2:
			return "%s:%s" % [time_part[0], time_part[1]]
	
	return Time.get_time_string_from_system()

func _show_error(error_message: String):
	"""Mostrar error en el chat"""
	var error_label = Label.new()
	error_label.text = "⚠️ " + error_message
	error_label.modulate = Color(1, 0.3, 0.3)
	messages_container.add_child(error_label)
	
	# Auto-scroll al final
	await get_tree().process_frame
	messages_scroll.scroll_vertical = int(messages_scroll.get_v_scroll_bar().max_value)
