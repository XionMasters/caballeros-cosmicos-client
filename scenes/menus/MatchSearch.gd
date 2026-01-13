# MatchSearch.gd
# Pantalla de búsqueda de partida
extends Control

@onready var back_button = $TopBar/BackButton
@onready var back_button_center = $CenterContainer/VBoxContainer/BackButton if has_node("CenterContainer/VBoxContainer/BackButton") else null
@onready var status_label = $CenterContainer/VBoxContainer/StatusLabel
@onready var deck_info_label = $CenterContainer/VBoxContainer/DeckInfoLabel
@onready var search_button = $CenterContainer/VBoxContainer/SearchButton
@onready var cancel_button = $CenterContainer/VBoxContainer/CancelButton

var is_searching: bool = false
var can_search: bool = false
var deck_status: Dictionary = {}

func _ready():

	# Botones
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if back_button_center:
		back_button_center.queue_free()
	if search_button:
		search_button.pressed.connect(_on_search_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)

	# ============================
	# 🔌 Conectar señales nuevas:
	# ============================
	MatchmakingManager.deck_check_completed.connect(_on_deck_check_completed)
	MatchmakingManager.searching_match.connect(_on_searching_match)
	MatchmakingManager.match_found.connect(_on_match_found)
	MatchmakingManager.match_error.connect(_on_match_error)
	MatchmakingManager.search_cancelled.connect(_on_search_cancelled)
	MatchmakingManager.connected_to_server.connect(_on_connected_to_server)
	MatchmakingManager.disconnected_from_server.connect(_on_disconnected_from_server)

	# ============================
	# 🔌 Conectarse al WS
	# ============================
	MatchmakingManager.connect_to_server()

	# Estados iniciales UI
	cancel_button.visible = false
	search_button.visible = true
	back_button.disabled = false

	# Verificar estado inicial del mazo
	_check_deck_status()


# ======================================================
# 🔙 Botón volver
# ======================================================
func _on_back_pressed():
	print("[MatchSearch] Volver")

	if is_searching:
		_on_cancel_pressed()
		return

	MatchmakingManager.disconnect_from_server()
	get_tree().change_scene_to_file("res://scenes/menus/MainLobby.tscn")


# ======================================================
# 📦 Verificar deck
# ======================================================
func _check_deck_status():
	status_label.text = "Verificando mazo activo..."
	search_button.disabled = true
	
	# NUEVO: ahora lo hace MatchmakingManager
	MatchmakingManager.check_can_search_match()


func _on_deck_check_completed(result: Dictionary):
	deck_status = result
	can_search = result.get("can_search", false)

	if can_search:
		var deck = result.get("deck", {})
		var deck_name = deck.get("name", "Sin nombre")
		var total_cards = deck.get("total_cards", 0)

		deck_info_label.text = "Mazo activo: %s (%d cartas)" % [deck_name, total_cards]
		status_label.text = "Listo para buscar partida"
		search_button.disabled = false

		var warnings = result.get("warnings", [])
		if warnings.size() > 0:
			deck_info_label.text += "\n⚠ " + warnings[0]
	else:
		var reason = result.get("reason", "UNKNOWN")
		var message = result.get("message", "Error desconocido")
		var deck = result.get("deck", null)

		search_button.disabled = true

		if reason == "NO_ACTIVE_DECK":
			status_label.text = "❌ " + message
			deck_info_label.text = "Ve a 'Mazos' y marca un mazo como activo"

		elif reason == "INVALID_DECK":
			var deck_name = deck.get("name", "Sin nombre") if deck else "Desconocido"
			status_label.text = "❌ Mazo '%s' no válido" % deck_name

			var errors = result.get("errors", [])
			if errors.size() > 0:
				deck_info_label.text = "Error: " + errors[0]
			else:
				deck_info_label.text = "El mazo no cumple con las reglas"

		else:
			status_label.text = "❌ " + message
			deck_info_label.text = ""


# ======================================================
# 🔎 Buscar partida
# ======================================================
func _on_search_pressed():
	is_searching = true
	search_button.visible = false
	cancel_button.visible = true
	back_button.disabled = true
	status_label.text = "Buscando partida..."

	MatchmakingManager.search_match()


# ======================================================
# ❌ Cancelar búsqueda
# ======================================================
func _on_cancel_pressed():
	is_searching = false
	status_label.text = "Cancelando búsqueda..."
	cancel_button.disabled = true

	MatchmakingManager.cancel_search()


# ======================================================
# 🔁 Estado de matchmaking
# ======================================================
func _on_searching_match():
	status_label.text = "⏳ Esperando oponente..."
	search_button.visible = false
	cancel_button.visible = true
	cancel_button.disabled = false
	back_button.disabled = true


func _on_search_cancelled():
	status_label.text = "Búsqueda cancelada"
	is_searching = false
	search_button.visible = true
	cancel_button.visible = false
	back_button.disabled = false


func _on_connected_to_server():
	print("✅ Conectado al servidor de matchmaking")


func _on_disconnected_from_server():
	print("❌ Desconectado del servidor")
	if is_searching:
		_on_match_error("Desconectado del servidor")


# ======================================================
# 🎉 Partida encontrada
# ======================================================
func _on_match_found(match_data: Dictionary):
	status_label.text = "¡Partida encontrada! Cargando recursos..."
	
	# Pre-cargar el dorso de carta
	CardsManager.preload_card_back()
	
	# Pre-cargar las imágenes del deck del jugador
	var player_deck_cards = _get_player_deck_cards(match_data)
	if player_deck_cards.size() > 0:
		status_label.text = "Cargando imágenes del deck..."
		CardsManager.preload_deck_images(player_deck_cards)
		
		# Esperar a que termine de cargar
		await CardsManager.deck_images_preloaded
	
	status_label.text = "¡Entrando a la partida!"
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/game/GameBoard.tscn")


func _get_player_deck_cards(match_data: Dictionary) -> Array:
	"""Extraer las cartas del deck del jugador desde match_data"""
	var user_id = UserManager.get_user_id()
	var cards_in_play = match_data.get("cards_in_play", [])
	var deck_cards = []
	
	# Buscar todas las cartas del jugador en la zona "deck"
	for card_data in cards_in_play:
		var player_id = card_data.get("player_id", "")
		var _zone = card_data.get("zone", "")
		
		if player_id == user_id or card_data.get("player_number", 0) == 1:
			var card = card_data.get("card", {})
			var card_id = card.get("id", "")
			var image_url = card.get("image_url", "")
			
			if card_id and image_url:
				# Evitar duplicados
				var already_added = false
				for existing in deck_cards:
					if existing.get("card_id") == card_id:
						already_added = true
						break
				
				if not already_added:
					deck_cards.append({
						"card_id": card_id,
						"image_url": image_url
					})
	
	return deck_cards


# ======================================================
# ⚠ Errores
# ======================================================
func _on_match_error(message: String):
	status_label.text = "Error: " + message
	is_searching = false
	search_button.visible = true
	cancel_button.visible = false
	back_button.disabled = false
