# WebSocketManager.gd - Autoload (singleton) para gestionar WebSocket centralizado
extends Node

# Señales públicas
signal connected_to_server
signal disconnected_from_server
signal server_event(event_name: String, data: Dictionary)  # eventos genéricos
signal chat_message_received(data: Dictionary)
signal online_users_updated(users: Array)
signal match_found(match_data: Dictionary)
signal match_updated(match_data: Dictionary)
signal match_error(error_code: String, message: String)
## Emitida cuando comienza un ciclo de reconexión automática.
## attempt = número de intento actual, delay_secs = segundos hasta el próximo intento.
signal reconnecting(attempt: int, delay_secs: float)
## Emitida cuando la reconexión automática se abandona (superó max intentos o no hay token).
signal reconnect_failed()

# Config
var ws: WebSocketPeer = null
var connected: bool = false
var auth_token: String = ""
var reconnect_attempts: int = 0
## 0 = intentos ilimitados
@export var max_reconnect_attempts: int = 0
@export var reconnect_delay_base: float = 1.0
@export var reconnect_delay_max: float = 30.0

## match_id de una partida activa para re-pedir el estado tras reconectar.
## Asignado desde el exterior (p.ej. GameBoard) o al recibir match_found.
var active_match_id: String = ""

# Internals
var _processing: bool = false
## true sólo cuando la desconexión fue pedida explícitamente por el cliente.
var _intentional_disconnect: bool = false
## Semáforo para evitar lanzar dos ciclos de reconexión en paralelo.
var _reconnect_in_progress: bool = false

# Heartbeat de aplicación
## Segundos entre cada ping enviado al servidor.
const HEARTBEAT_INTERVAL: float = 5.0
## Segundos sin recibir pong antes de declarar la conexión muerta.
const HEARTBEAT_TIMEOUT: float = 12.0
var _heartbeat_elapsed: float = 0.0   # tiempo desde el último ping enviado
var _last_pong_elapsed: float = 0.0   # tiempo desde el último pong recibido
var _waiting_pong: bool = false       # estamos esperando pong

func _ready():
	print("🌐 WebSocketManager inicializado")

func _process(delta):
	# ---------- heartbeat ----------
	if connected:
		_heartbeat_elapsed += delta
		if _waiting_pong:
			_last_pong_elapsed += delta
			if _last_pong_elapsed >= HEARTBEAT_TIMEOUT:
				print("💀 Conexión muerta (sin pong en %.0fs) — forzando reconexión" % HEARTBEAT_TIMEOUT)
				_on_dead_connection()
				return
		if _heartbeat_elapsed >= HEARTBEAT_INTERVAL:
			_heartbeat_elapsed = 0.0
			_send_ping()

	# ---------- poll socket ----------
	if ws:
		ws.poll()
		var state := ws.get_ready_state()

		if state == WebSocketPeer.STATE_OPEN:
			# leer mensajes
			while ws.get_available_packet_count():
				var packet := ws.get_packet()
				var message := packet.get_string_from_utf8()
				_handle_message(message)

		elif state == WebSocketPeer.STATE_CLOSED or state == WebSocketPeer.STATE_CLOSING:
			if connected:
				connected = false
				_reset_heartbeat()
				if _intentional_disconnect:
					print("🔌 WebSocket cerrado intencionalmente")
					emit_signal("disconnected_from_server")
				else:
					print("❌ WebSocket desconectado por el servidor — iniciando reconexión")
					emit_signal("disconnected_from_server")
					ws = null
					_trigger_reconnect()
					return
			# limpiar objeto
			ws = null

# =========================
# Heartbeat interno
# =========================
func _send_ping() -> void:
	if not is_connected_to_server():
		return
	_waiting_pong = true
	_last_pong_elapsed = 0.0
	var err := ws.send_text(JSON.stringify({"event": "ping", "data": {}}))
	if err != OK:
		print("⚠️ Error enviando ping: ", err)

func _reset_heartbeat() -> void:
	_heartbeat_elapsed = 0.0
	_last_pong_elapsed = 0.0
	_waiting_pong = false

func _on_dead_connection() -> void:
	"""Llamado cuando se detecta conexión muerta (timeout de pong)."""
	connected = false
	_reset_heartbeat()
	if ws:
		ws.close()
		ws = null
	emit_signal("disconnected_from_server")
	_trigger_reconnect()

# =========================
# Conexión / Reconexión
# =========================
func connect_to_server(token: String) -> void:
	"""Conectar al servidor WS. Pasa token (string) para handshake (?token=)."""
	auth_token = token
	_intentional_disconnect = false

	# Si ya hay conexión abierta, evitar reconectar
	if ws and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		print("⚠️ WebSocket ya conectado")
		return

	var full_url := GameConfig.WS_URL + "?token=" + auth_token
	print("🔌 Conectando a WebSocket: ", full_url)

	ws = WebSocketPeer.new()
	var err := ws.connect_to_url(full_url)
	if err != OK:
		print("❌ Error conectando WebSocket:", err)
		_schedule_reconnect()
		return

	# activar process para poll
	if not _processing:
		set_process(true)
		_processing = true

	# Esperar handshake (no bloqueante)
	await get_tree().create_timer(0.5).timeout

	if ws and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		connected = true
		reconnect_attempts = 0
		_reconnect_in_progress = false
		_reset_heartbeat()
		print("✅ WebSocket conectado (handshake OK)")
		emit_signal("connected_to_server")
		# Si había una partida activa, re-solicitar su estado
		if active_match_id != "":
			print("🔄 Partida activa detectada tras reconexión — solicitando estado: ", active_match_id)
			# Pequeño delay para que el server procese la autenticación
			await get_tree().create_timer(0.3).timeout
			request_match_state(active_match_id)
	else:
		@warning_ignore("incompatible_ternary")
		print("⚠️ Handshake pendiente/Falló. Estado:", ws.get_ready_state() if ws else "no socket")
		_schedule_reconnect()

func _trigger_reconnect() -> void:
	"""Inicia reconexión si no hay un ciclo activo ya."""
	if _reconnect_in_progress:
		return
	if auth_token == "":
		print("⚠️ Sin token — no se puede reconectar automáticamente")
		emit_signal("reconnect_failed")
		return
	_reconnect_in_progress = true
	reconnect_attempts = 0
	_schedule_reconnect()

func _schedule_reconnect() -> void:
	if not _reconnect_in_progress:
		return
	if _intentional_disconnect:
		_reconnect_in_progress = false
		return
	if max_reconnect_attempts > 0 and reconnect_attempts >= max_reconnect_attempts:
		print("❌ Máximos intentos de reconexión alcanzados (%d)" % max_reconnect_attempts)
		_reconnect_in_progress = false
		emit_signal("reconnect_failed")
		return

	reconnect_attempts += 1
	# Backoff exponencial con cap
	var delay := minf(reconnect_delay_base * pow(2.0, reconnect_attempts - 1), reconnect_delay_max)
	var attempts_label := "∞" if max_reconnect_attempts == 0 else str(max_reconnect_attempts)
	print("🔁 Reconectando en %.1f s (intento %d/%s)" % [delay, reconnect_attempts, attempts_label])
	emit_signal("reconnecting", reconnect_attempts, delay)
	await get_tree().create_timer(delay).timeout
	if _intentional_disconnect:
		_reconnect_in_progress = false
		return
	connect_to_server(auth_token)

func disconnect_from_server() -> void:
	_intentional_disconnect = true
	_reconnect_in_progress = false
	active_match_id = ""
	_reset_heartbeat()
	if ws:
		ws.close()
		ws = null
	connected = false
	if _processing:
		set_process(false)
		_processing = false
	emit_signal("disconnected_from_server")

func is_connected_to_server() -> bool:
	return connected and ws and ws.get_ready_state() == WebSocketPeer.STATE_OPEN

# =========================
# Envío de JSON / Eventos
# =========================
func send_event(event_name: String, data: Dictionary = {}) -> void:
	"""Envía {"event": name, "data": data} por WS si está conectado."""
	if not is_connected_to_server():
		push_error("WebSocket no conectado, no se envia evento: %s" % event_name)
		return

	var payload := {
		"event": event_name,
		"data": data
	}
	var json_str := JSON.stringify(payload)
	var err := ws.send_text(json_str)
	if err != OK:
		print("⚠️ Error enviando evento WS:", err, "evento:", event_name)

func _to_match_action_type(event_name: String) -> String:
	var normalized := event_name.strip_edges().to_lower()
	match normalized:
		"play_card":
			return "PLAY_CARD"
		"declare_attack", "attack":
			return "ATTACK"
		"end_turn":
			return "END_TURN"
		"change_defensive_mode":
			return "CHANGE_DEFENSIVE_MODE"
		"charge_cosmos":
			return "CHARGE_COSMOS"
		"sacrifice_knight":
			return "SACRIFICE_KNIGHT"
		"move_knight":
			return "MOVE_KNIGHT"
		_:
			return event_name.strip_edges().to_upper()

func _generate_action_id() -> String:
	return _uuid_v4()

func send_match_event(event_name: String, data: Dictionary = {}) -> void:
	"""Envía una acción de partida por evento genérico: match_action."""
	if not is_connected_to_server():
		push_error("WebSocket no conectado, no se envia match_action: %s" % event_name)
		return

	var action_data := data.duplicate(true)
	action_data["type"] = _to_match_action_type(event_name)

	if not action_data.has("action_id"):
		action_data["action_id"] = _generate_action_id()

	send_event("match_action", action_data)

# =========================
# Funciones de Chat / UI
# =========================
func send_chat_message(message: String, message_type: String = "global", target_id: String = "") -> void:
	if not is_connected_to_server():
		push_error("No conectado al servidor (chat)")
		return

	var data := {
		"message": message,
		"message_type": message_type
	}
	if message_type == "whisper" and target_id != "":
		data["target_user_id"] = target_id

	send_event("chat_message", data)

func request_online_users() -> void:
	if not is_connected_to_server():
		return
	send_event("request_online_users", {})

func update_status(status: String) -> void:
	if not is_connected_to_server():
		return
	send_event("update_status", {"status": status})

# =========================
# Funciones de Match (helpers)
# =========================
func search_match() -> void:
	if not is_connected_to_server():
		push_error("No conectado - no se puede buscar partida")
		return
	send_event("search_match", {})

func request_test_match() -> void:
	"""Solicitar una partida TEST al servidor
	
	Flujo:
	- Cliente envía: request_test_match event
	- Servidor: crea partida TEST
	- Servidor: responde con match_found + match_update
	"""
	if not is_connected_to_server():
		push_error("No conectado - no se puede iniciar TEST")
		return
	print("🎭 [WebSocketManager] Pidiendo partida TEST...")
	send_event("request_test_match", {})

func cancel_search() -> void:
	if not is_connected_to_server():
		return
	send_event("cancel_search", {})

func play_card(match_id: String, card_id: String, zone: String = "", position: int = 0) -> void:
	if not is_connected_to_server():
		push_error("No conectado - no se puede enviar play_card")
		return
	send_match_event("play_card", {
		"match_id": match_id,
		"card_id": card_id,
		"zone": zone,
		"position": position
	})

func declare_attack(match_id: String, attacker_id: String, defender_id: String) -> void:
	"""Declarar ataque en una partida
	
	Args:
	- match_id: ID de la partida
	- attacker_id: ID de instancia del atacante
	- defender_id: ID de instancia del defensor
	"""
	if not is_connected_to_server():
		push_error("No conectado - no se puede enviar declare_attack")
		return
	send_match_event("declare_attack", {
		"match_id": match_id,
		"attacker_id": attacker_id,
		"defender_id": defender_id
	})

func end_turn(match_id: String) -> void:
	if not is_connected_to_server():
		push_error("No conectado - no se puede enviar end_turn")
		return
	send_match_event("end_turn", {"match_id": match_id})

func send_change_defensive_mode(match_id: String, card_in_play_id: String, mode: String) -> void:
	"""Cambiar modo defensivo de un caballero (evasion / defense / normal)"""
	if not is_connected_to_server():
		push_error("No conectado - no se puede enviar change_defensive_mode")
		return
	send_match_event("change_defensive_mode", {
		"match_id": match_id,
		"card_id": card_in_play_id,
		"mode": mode
	})

func send_charge_cosmos(match_id: String) -> void:
	"""Cargar cosmo (+3 CP para el jugador)"""
	if not is_connected_to_server():
		push_error("No conectado - no se puede enviar charge_cosmos")
		return
	send_match_event("charge_cosmos", {"match_id": match_id})

func send_sacrifice_knight(match_id: String, card_in_play_id: String) -> void:
	"""Sacrificar un caballero propio (-1 LP)"""
	if not is_connected_to_server():
		push_error("No conectado - no se puede enviar sacrifice_knight")
		return
	send_match_event("sacrifice_knight", {
		"match_id": match_id,
		"card_id": card_in_play_id
	})

func send_move_knight(match_id: String, card_in_play_id: String, target_position: int) -> void:
	"""Mover un caballero a una posición vacía del campo (0-4)"""
	if not is_connected_to_server():
		push_error("No conectado - no se puede enviar move_knight")
		return
	send_match_event("move_knight", {
		"match_id": match_id,
		"card_id": card_in_play_id,
		"target_position": target_position
	})

func start_first_turn(match_id: String) -> void:
	"""Iniciar el primer turno de la partida
	
	Se llama después de que la escena GameMatch está completamente cargada.
	El servidor ejecutará:
	- Dar cosmos inicial
	- Robar primera carta
	- Ejecutar efectos on_turn_start
	- Enviar match_update
	"""
	if not is_connected_to_server():
		push_error("No conectado - no se puede iniciar primer turno")
		return
	print("🎮 [WebSocketManager] Iniciando primer turno para match: ", match_id)
	send_event("start_first_turn", {"match_id": match_id})

func request_match_state(match_id: String) -> void:
	"""Solicitar al servidor el estado actual de una partida.
	Útil tras reconexiones para recuperar el estado sin reiniciar la partida."""
	if not is_connected_to_server():
		push_error("No conectado - no se puede pedir estado de partida")
		return
	print("📡 [WebSocketManager] Solicitando estado de partida: ", match_id)
	send_event("request_match_state", {"match_id": match_id})


# =========================
# Mensajes entrantes - dispatch
# =========================
func _handle_message(message: String) -> void:
	var json := JSON.new()
	if json.parse(message) != OK:
		push_error("Error parseando JSON WS")
		return

	var payload: Dictionary = json.data

	if not payload is Dictionary:
		push_error("Payload WS no es Dictionary")
		return

	var event: String = payload.get("event", "")

	var data: Dictionary = payload.get("data", {})


	# Emitir evento general para que MatchController lo maneje
	emit_signal("server_event", event, data)

	match event:
		"pong":
			# Conexión viva
			_waiting_pong = false
			_last_pong_elapsed = 0.0

		"connected":
			print("✅ Servidor WS: conectado como", data.get("username", ""))
			request_online_users()

		"chat_message":
			emit_signal("chat_message_received", data)

		"online_users":
			var users: Array = data.get("users", [])
			emit_signal("online_users_updated", users)

		"match_found":
			# Guardar match_id para reconexiones
			var mid: String = data.get("id", data.get("match_id", ""))
			if mid != "":
				active_match_id = mid
			emit_signal("match_found", data)

		"match_update":
			# Mantener active_match_id actualizado
			var mid2: String = data.get("id", data.get("match_id", ""))
			if mid2 != "":
				active_match_id = mid2
			current_match_update(data)
			emit_signal("match_updated", data)

		"match_error":
			var code: String = data.get("code", "")
			var msg: String = data.get("message", "")
			emit_signal("match_error", code, msg)

		_:
			# Ya emitimos server_event arriba
			pass  # Si no hay código, usa 'pass'

# Helper para actualizar current_match internamente si se necesita
func current_match_update(_data: Dictionary) -> void:
	# Esta función puede guardarlo en una variable si querés
	# por ahora emitimos solo la señal; MatchController puede solicitar el merge
	pass

# =========================
# Util / URL
# =========================
func get_api_base_url() -> String:
	"""Devuelve GameConfig.API_URL sin '/api' final si querés usar assets"""
	# intentar reemplazar solo la última ocurrencia de '/api'
	var base := GameConfig.API_URL
	if base.ends_with("/api"):
		return base.substr(0, base.length() - 4)
	return base

func _uuid_v4() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var b := PackedByteArray()
	b.resize(16)
	for i in range(16):
		b[i] = rng.randi_range(0, 255)

	# RFC 4122 (v4)
	b[6] = (b[6] & 0x0F) | 0x40
	b[8] = (b[8] & 0x3F) | 0x80

	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		b[0], b[1], b[2], b[3],
		b[4], b[5],
		b[6], b[7],
		b[8], b[9],
		b[10], b[11], b[12], b[13], b[14], b[15]
	]
