# MatchManager.gd (Autoload / Singleton)
extends Node

# ---------------------------------------------------------
# Señales públicas
# ---------------------------------------------------------
signal match_found(match_data: Dictionary)
signal match_started(state: GameState)
signal match_state_updated(match_data: Dictionary)
signal match_error(error_message: String)
signal match_ended(result: Dictionary)

# ---------------------------------------------------------
# Estado interno
# ---------------------------------------------------------
var current_match: Dictionary = {}  # SOLO metadata: id, players, mode, result
var game_state: GameState = null     # ESTADO REAL: cartas, vida, zonas, todo jugable
var is_in_match: bool = false

# Señal para cambios de fase (desacoplamiento de UI)
signal phase_changed(phase: String)

func _ready():
	print("🎮 MatchManager iniciado")

	# Suscripción directa a eventos WebSocket de partida
	WebSocketManager.server_event.connect(_on_server_event)
	WebSocketManager.match_updated.connect(_on_match_updated)
	WebSocketManager.match_found.connect(_on_match_found)
	WebSocketManager.match_error.connect(_on_match_error)


# =====================================================
# DISPATCH PRINCIPAL DE EVENTOS DEL SERVIDOR
# =====================================================
func _on_server_event(event: String, data: Dictionary) -> void:
	match event:

		"match_found":
			_on_match_found(data)

		"match_update", "card_played", "turn_changed":
			# TODOS actualizan el estado de la misma forma
			_on_match_updated(data)
			
			# Triggers de UI/UX según el tipo de evento
			match event:
				"card_played":
					print("🃏 Carta jugada")
				"turn_changed":
					if data.has("phase"):
						phase_changed.emit(data["phase"])

		"match_end":
			_on_match_end(data)

		_:
			pass


# =====================================================
# 🔥 MATCH FOUND → Crear GameState
# =====================================================
func _on_match_found(data: Dictionary) -> void:
	print("🔎 Match encontrado")

	# ⚠️ GUARD: Evitar procesar dos veces si la partida ya está iniciada
	if is_in_match and game_state != null:
		print("⚠️ [MatchManager] Match ya fue procesado, ignorando duplicado")
		return

	is_in_match = true

	# current_match SOLO metadata
	current_match = {
		"id": data.get("id"),
		"player1_id": data.get("player1_id"),
		"player2_id": data.get("player2_id"),
		"player1_name": data.get("player1_name"),
		"player2_name": data.get("player2_name"),
		"mode": data.get("mode", "standard"),
	}

	# game_state = ESTADO REAL
	var local_id: String = AuthManager.get_user_id()
	game_state = GameState.from_server_data(data, local_id)

	# 🎴 PRECARGA DE IMÁGENES: Obtener lista de cartas en mano y oponente
	_preload_match_images()

	emit_signal("match_found", current_match)
	emit_signal("match_started", game_state)

	# Emitir phase_changed para UI
	if game_state.current_phase:
		phase_changed.emit(game_state.current_phase.to_upper())


func _preload_match_images() -> void:
	"""Precarga de imágenes de todas las cartas en juego"""
	if not game_state:
		return
	
	var deck_cards = []
	
	# Cartas en mano del jugador
	for card_instance in game_state.player_hand:
		if card_instance and card_instance.base_data:
			deck_cards.append({
				"card_id": card_instance.base_data.id,
				"image_url": card_instance.base_data.image_url
			})
	
	# Cartas en campo del jugador
	for card_instance in game_state.player_field_knights:
		if card_instance and card_instance.base_data:
			deck_cards.append({
				"card_id": card_instance.base_data.id,
				"image_url": card_instance.base_data.image_url
			})
	
	for card_instance in game_state.player_field_techniques:
		if card_instance and card_instance.base_data:
			deck_cards.append({
				"card_id": card_instance.base_data.id,
				"image_url": card_instance.base_data.image_url
			})
	
	# Cartas en campo del oponente
	for card_instance in game_state.opponent_field_knights:
		if card_instance and card_instance.base_data:
			deck_cards.append({
				"card_id": card_instance.base_data.id,
				"image_url": card_instance.base_data.image_url
			})
	
	for card_instance in game_state.opponent_field_techniques:
		if card_instance and card_instance.base_data:
			deck_cards.append({
				"card_id": card_instance.base_data.id,
				"image_url": card_instance.base_data.image_url
			})
	
	# Escenario si hay
	if game_state.scenario and game_state.scenario.base_data:
		deck_cards.append({
			"card_id": game_state.scenario.base_data.id,
			"image_url": game_state.scenario.base_data.image_url
		})
	
	if not deck_cards.is_empty():
		print("[MatchManager] 🎴 Precargando %d imágenes de cartas..." % deck_cards.size())
		CardsManager.preload_deck_images(deck_cards)


# =====================================================
# 🔄 MATCH UPDATE (Único camino de actualización)
# =====================================================
func _on_match_updated(data: Dictionary) -> void:
	if not is_in_match or game_state == null:
		return

	# current_match: SOLO metadata
	if data.has("id"):
		current_match["id"] = data["id"]
	if data.has("player1_id"):
		current_match["player1_id"] = data["player1_id"]
	if data.has("player2_id"):
		current_match["player2_id"] = data["player2_id"]

	# game_state: ESTADO REAL (cartas, vida, zonas, todo)
	var local_id: String = AuthManager.get_user_id()
	game_state.apply_update(data, local_id)

	# Emitir signal de actualización
	emit_signal("match_state_updated", current_match)


# =====================================================
# 🏁 MATCH END
# =====================================================
func _on_match_end(data: Dictionary) -> void:
	print("🏁 Match finalizado:", data)

	is_in_match = false
	current_match = {}
	game_state = null

	emit_signal("match_ended", data)


# =====================================================
# ❌ ERROR
# =====================================================
func _on_match_error(message: String) -> void:
	print("❌ Error Match:", message)
	emit_signal("match_error", message)


# =====================================================
# NORMALIZACIÓN
# =====================================================
func _normalize_match_data(data: Dictionary) -> Dictionary:
	var d := data.duplicate(true)

	if d.has("match_id") and not d.has("id"):
		d["id"] = d["match_id"]

	if d.has("player1") and d["player1"] is Dictionary:
		d["player1_id"] = d["player1"].get("id", "")
		d["player1_name"] = d["player1"].get("username", "")

	if d.has("player2") and d["player2"] is Dictionary:
		d["player2_id"] = d["player2"].get("id", "")
		d["player2_name"] = d["player2"].get("username", "")

	return d


# =====================================================
# API PÚBLICA PARA LA UI (ya no busca partidas)
# =====================================================

func start_test_match() -> void:
	"""Iniciar una partida TEST contra la IA
	
	Flujo:
	1. Cliente pide servidor crear partida TEST
	2. Servidor: valida, baraja, roba, decide turnos
	3. Servidor responde por WebSocket con match_updated
	4. _on_match_found() → GameState creado
	5. _on_match_updated() → GameState actualizado
	
	Responsable: WebSocketManager (envía al servidor)
	"""
	print("🎭 [MatchManager] Pidiendo partida TEST al servidor...")
	
	# WebSocketManager maneja la comunicación WebSocket
	# Internamente envia evento al servidor
	# El servidor responde con match_found/match_updated
	WebSocketManager.request_test_match()


func play_card(card_instance_id: String, zone: String, position: int = 0) -> void:
	if not is_in_match:
		return

	var match_id: String = current_match.get("id", "")
	WebSocketManager.play_card(match_id, card_instance_id, zone, position)


func send_attack(attacker_id: String, defender_id: String) -> void:
	"""Atacar a otro caballero"""
	if not is_in_match:
		return
	
	var match_id: String = current_match.get("id", "")
	WebSocketManager.declare_attack(match_id, attacker_id, defender_id)


func end_turn() -> void:
	if not is_in_match:
		return

	var match_id: String = current_match.get("id", "")
	WebSocketManager.end_turn(match_id)
