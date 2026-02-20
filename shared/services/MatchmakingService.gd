# MatchmakingService.gd
extends Node

# --------------------------------------------------------------
# Señales que MatchSearch.gd usa actualmente
# --------------------------------------------------------------
signal searching_match
signal search_cancelled
signal match_found(match_data: Dictionary)
signal match_error(message: String)
signal connected_to_server
signal disconnected_from_server

# Estado interno
var is_searching: bool = false


func _ready():
	print("🟦 MatchmakingService inicializado")

	# Escuchar eventos del WebSocketManager
	WebSocketManager.connected_to_server.connect(_on_connected)
	WebSocketManager.disconnected_from_server.connect(_on_disconnected)
	WebSocketManager.server_event.connect(_on_server_event)


# -------------------------------------------------------------------
#   CONEXIÓN / DESCONEXIÓN
# -------------------------------------------------------------------
func connect_to_server():
	var token := AuthManager.get_token()
	if token.is_empty():
		push_error("No hay token para conectar al matchmaking")
		return

	WebSocketManager.connect_to_server(token)


func disconnect_from_server():
	WebSocketManager.disconnect_from_server()


func _on_connected():
	print("🟩 Matchmaking conectado al servidor")
	emit_signal("connected_to_server")


func _on_disconnected():
	print("🟥 Matchmaking desconectado del servidor")
	emit_signal("disconnected_from_server")


# -------------------------------------------------------------------
#   SEARCH MATCH
# -------------------------------------------------------------------
func search_match():
	if is_searching:
		print("⚠️ Ya estás buscando")
		return

	if not WebSocketManager.is_connected_to_server():
		emit_signal("match_error", "No conectado al servidor")
		return

	print("🎯 enviando search_match")
	is_searching = true
	emit_signal("searching_match")

	WebSocketManager.send_event("search_match", {})


func cancel_search():
	if not is_searching:
		return

	print("❌ enviando cancel_search")
	is_searching = false
	emit_signal("search_cancelled")

	WebSocketManager.send_event("cancel_search", {})


# -------------------------------------------------------------------
#   DISPATCH: Eventos del servidor relacionados con matchmaking
# -------------------------------------------------------------------
func _on_server_event(event_name: String, data: Dictionary):
	match event_name:

		# -----------------------------
		#   MATCH FOUND
		# -----------------------------
		"match_found":
			is_searching = false
			emit_signal("match_found", data)

		# -----------------------------
		#   MATCHMAKING ERROR
		# -----------------------------
		"match_error":
			var msg : String = data.get("message", "Error desconocido")
			is_searching = false
			emit_signal("match_error", msg)

		# -----------------------------
		#   SEARCH CANCELLED (server-side)
		# -----------------------------
		"search_cancelled":
			is_searching = false
			emit_signal("search_cancelled")

		_:
			# Otros eventos no son de matchmaking
			pass
