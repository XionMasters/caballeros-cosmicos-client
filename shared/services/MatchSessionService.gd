# MatchSessionService.gd (Autoload / Singleton)
extends Node

# ---------------------------------------------------------
# Señales públicas
# ---------------------------------------------------------
signal match_started(state: GameState)
signal match_state_updated(match_data: Dictionary)
signal match_error(error_message: String)
signal match_ended(result: Dictionary)
signal render_complete  # ✅ Signal que GameMatch emite cuando termina de renderizar

# ---------------------------------------------------------
# Estado interno
# ---------------------------------------------------------
var current_match: Dictionary = {}  # SOLO metadata: id, players, mode, result
var game_state: GameState = null     # ESTADO REAL: cartas, vida, zonas, todo jugable
var is_in_match: bool = false
var is_test_mode: bool = false  # True si se solicitó test_match, False si es multiplayer normal

# Señal para cambios de fase (desacoplamiento de UI)
signal phase_changed(phase: String)

# ---------------------------------------------------------
# COLA DE ACTUALIZACIONES SECUENCIALES
# ---------------------------------------------------------
var _is_processing_update: bool = false
var _pending_updates: Array = []

func _ready():
	print("🎮 MatchSessionService iniciado")


	# Suscripción directa a eventos WebSocket de partida
	WebSocketManager.server_event.connect(_on_server_event)
	WebSocketManager.match_updated.connect(_on_match_updated)
	WebSocketManager.match_error.connect(_on_match_error)

# =====================================================
# DISPATCH PRINCIPAL DE EVENTOS DEL SERVIDOR
# =====================================================
func _on_server_event(event: String, data: Dictionary) -> void:
	match event:

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

func start_pvp_session(data: Dictionary) -> void:
	if is_in_match:
		print("⚠️ Ya existe una sesión activa")
		return

	if data.is_empty():
		print("❌ Datos inválidos para iniciar sesión PvP")
		emit_signal("match_error", "Datos inválidos de partida")
		return

	print("🎮 Iniciando sesión PvP...")
	await _initialize_match(data, "pvp")

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
	"""Encola la actualización para procesarla secuencialmente
	
	⚠️ IMPORTANTE: Las actualizaciones se encolan para garantizar que
	una se procesa completamente (incluyendo animaciones asincrónicas)
	antes de que comience la siguiente.
	"""
	_pending_updates.append(data)
	
	# Si no hay una actualización en progreso, empezar a procesar la cola
	if not _is_processing_update:
		await _process_update_queue()


func _process_update_queue() -> void:
	"""Procesa la cola de actualizaciones una por una de forma secuencial
	
	Garantiza que cada actualización se completa (incluyendo animaciones)
	antes de procesar la siguiente.
	"""
	while _pending_updates.size() > 0:
		_is_processing_update = true
		var data = _pending_updates.pop_front()
		
		print("[MatchSessionService] 🔄 Procesando actualización (%d pendientes)" % _pending_updates.size())
		
		# Procesar la initialización si es la primera vez
		if game_state == null and data.has("game_state"):
			await _initialize_match(data, "pvp")
			_is_processing_update = false
			continue
		
		# current_match: SOLO metadata
		if data.has("id"):
			current_match["id"] = data["id"]
		if data.has("player1_id"):
			current_match["player1_id"] = data["player1_id"]
		if data.has("player2_id"):
			current_match["player2_id"] = data["player2_id"]
		if data.has("player1_name"):
			current_match["player1_name"] = data["player1_name"]
		if data.has("player2_name"):
			current_match["player2_name"] = data["player2_name"]
		
		# Extraer de objetos player1/player2 si vienen así
		if data.has("player1") and data["player1"] is Dictionary:
			var p1 = data["player1"]
			if p1.has("id"):
				current_match["player1_id"] = p1["id"]
			if p1.has("username"):
				current_match["player1_name"] = p1["username"]
		
		if data.has("player2") and data["player2"] is Dictionary:
			var p2 = data["player2"]
			if p2.has("id"):
				current_match["player2_id"] = p2["id"]
			if p2.has("username"):
				current_match["player2_name"] = p2["username"]

		# game_state: ESTADO REAL (cartas, vida, zonas, todo)
		game_state.apply_update(data)

		# Emitir signal de actualización
		print("[MatchSessionService] 📡 Emitiendo match_state_updated...")
		emit_signal("match_state_updated", current_match)
		
		# ⏳ ESPERAR a que GameMatch termine de renderizar antes de procesar la siguiente actualización
		print("[MatchSessionService] ⏳ Esperando que GameMatch termine de renderizar...")
		await render_complete
		
		print("[MatchSessionService] ✅ Actualización completada")
	
	_is_processing_update = false
	print("[MatchSessionService] 📭 Cola de actualizaciones vacía")


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
func _on_match_error(code: String, message: String) -> void:
	print("❌ Error Match (%s): %s" % [code, message])
	emit_signal("match_error", code, message)


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
	"""Iniciar una partida TEST contra mi mismo
	
	Flujo:
	1. 🌐 HTTP POST /api/matches/init-match-test → Crear partida + estado inicial
	2. ✅ Si éxito: Cargar imágenes necesarias
	3. 🎬 Usar SceneTransition para ir a GameMatch.tscn
	4. 🔌 GameMatch._ready() emite signal cuando está listo
	5. 📨 Enviar por WebSocket inicio del primer turno
	
	Responsable: MatchSessionService (orquesta todo el flujo)
	"""

	if is_in_match:
		return

	print("🎭 [MatchSessionService] Iniciando partida TEST...")
	is_test_mode = true
	
	# 1️⃣ HTTP POST para crear la partida
	ApiClient.post_request_with_callback(
		"/matches/init-match-test",
		{},
		"start_test_match",
		_on_test_match_response,
		true,  # use_auth
		15.0   # timeout
	)

func _on_test_match_response(success: bool, data: Variant, error: String) -> void:
	"""Maneja la respuesta HTTP de crear partida TEST
	
	Args:
	- success: bool - Si la petición fue exitosa
	- data: Variant - Datos de la respuesta (Dictionary si succes=true)
	- error: String - Mensaje de error (si success=false)
	"""
	print("📡 Respuesta HTTP test_match - Success:", success)

	if not success:
		var error_msg = error if error != "" else "Error desconocido al crear partida TEST"

		if "Ya tienes una partida TEST activa" in error_msg:
			print("♻️ Partida TEST activa detectada. Reanudando...")
			_resume_test_match()
			return

		emit_signal("match_error", error_msg)
		is_test_mode = false
		return

	if data is not Dictionary:
		emit_signal("match_error", "Respuesta inválida del servidor")
		is_test_mode = false
		return

	var result := data as Dictionary

	if not result.get("success", false):
		var error_msg = result.get("error", "Error del servidor")
		emit_signal("match_error", error_msg)
		is_test_mode = false
		return

	print("✅ Partida TEST creada correctamente")
	await _initialize_match(result, "test")


func _initialize_match(match_data: Dictionary, mode: String):
	# 1️⃣ Validación estructural mínima
	if not match_data.has("match_id"):
		emit_signal("match_error", "match_id faltante")
		return

	if not match_data.has("game_state"):
		emit_signal("match_error", "game_state faltante")
		return
	
	print("[MatchSessionService] 📥 match_data recibido:")
	print("  player1_id: %s" % match_data.get("player1_id", "NOT_FOUND"))
	print("  player2_id: %s" % match_data.get("player2_id", "NOT_FOUND"))
	
	# 2️⃣ Configurar modo
	is_test_mode = mode == "test"

	# 3️⃣ Crear GameState
	var state_data = match_data["game_state"]
	if state_data is not Dictionary:
		emit_signal("match_error", "game_state inválido")
		return
	
	print("[MatchSessionService] 📥 game_state recibido:")
	print("  player1_id: %s" % state_data.get("player1_id", "NOT_FOUND"))
	print("  player2_id: %s" % state_data.get("player2_id", "NOT_FOUND"))
	
	var local_id = AuthManager.get_user_id()
	game_state = GameState.from_match_payload(state_data, local_id)
	
	# 4️⃣ Construir metadata limpia CON información de jugadores
	current_match = {
		"id": match_data["match_id"],
		"mode": mode,
		"created_at": Time.get_unix_time_from_system()
	}
	
	# Extraer información de jugadores si está disponible
	if match_data.has("player1"):
		var p1 = match_data["player1"]
		if p1 is Dictionary:
			current_match["player1_id"] = p1.get("id", "")
			current_match["player1_name"] = p1.get("username", "Jugador 1")
	
	if match_data.has("player2"):
		var p2 = match_data["player2"]
		if p2 is Dictionary:
			current_match["player2_id"] = p2.get("id", "")
			current_match["player2_name"] = p2.get("username", "Jugador 2")
	
	# Fallback si no vienen en ese formato
	if not current_match.has("player1_id") and match_data.has("player1_id"):
		current_match["player1_id"] = match_data["player1_id"]
	if not current_match.has("player2_id") and match_data.has("player2_id"):
		current_match["player2_id"] = match_data["player2_id"]

	# 5️⃣ Marcar sesión activa
	is_in_match = true
	
	# 6️⃣ Emitir señal para UI / sistemas reactivos
	emit_signal("match_started", game_state)

	# 7️⃣ Precargar recursos necesarios (esperar a que termine)
	await _verify_and_preload_images()

	# 8️⃣ Preparar transición
	SceneTransition.set_pending_data({
		"match_id": current_match["id"],
		"mode": mode
	})

	SceneTransition.go_to_gamematch()

func _resume_test_match() -> void:
	"""Reanuda una partida TEST existente del servidor"""
	print("🔄 Intentando reanudar partida TEST...")
	
	if not ApiClient:
		print("❌ ApiClient no disponible")
		emit_signal("match_error", "ApiClient no disponible")
		is_test_mode = false
		return
	
	# Llamar al endpoint de resume
	ApiClient.get_request_with_callback(
		"/matches/test/resume",
		"resume_test_match",
		_on_resume_test_match_response,
		true,
		15.0
	)


func _on_resume_test_match_response(success: bool, data: Variant, error: String) -> void:
	"""Maneja la respuesta al intentar reanudar partida TEST"""
	print("📡 [MatchManager] Respuesta HTTP resume_test_match - Success: ", success)
	
	if not success:
		var error_msg = error if error != "" else "Error desconocido al reanudar partida TEST"
		print("❌ Error reanudando TEST match: ", error_msg)
		emit_signal("match_error", error_msg)
		is_test_mode = false
		return
	
	# ✅ Petición HTTP fue exitosa
	if data is not Dictionary:
		print("❌ Respuesta inválida del servidor")
		emit_signal("match_error", "Respuesta inválida del servidor")
		is_test_mode = false
		return
	
	var result = data as Dictionary
	if not result.has("success") or not result.success:
		var error_msg = result.get("error", "Error del servidor")
		print("❌ Error del servidor: ", error_msg)
		emit_signal("match_error", error_msg)
		is_test_mode = false
		return
	
	# ✅ Partida reanudada exitosamente
	print("✅ Partida TEST reanudada correctamente")
	await _initialize_match(result, "test")


func _verify_and_preload_images():
	"""Precargar todas las imágenes necesarias antes de ir a GameMatch
	
	⚠️ IMPORTANTE: Esta función es async. Espera a que todas las imágenes terminen de cargar.
	"""
	if not game_state:
		emit_signal("match_error", "GameState no disponible")
		return
	
	# Obtener lista de cartas que necesitamos
	var required_cards = []
	
	# Cartas en mano del jugador
	for card_instance in game_state.player_hand:
		if card_instance and card_instance.base_data:
			required_cards.append({
				"card_id": card_instance.base_data.id,
				"image_url": card_instance.base_data.image_url
			})
	
	# Cartas en campo del oponente (visible)
	for card_instance in game_state.opponent_field_knights:
		if card_instance and card_instance.base_data:
			required_cards.append({
				"card_id": card_instance.base_data.id,
				"image_url": card_instance.base_data.image_url
			})
	
	# Dorso de cartas (una sola)
	required_cards.append({
		"card_id": "card_back",
		"image_url": "/assets/cards/card_back.png"
	})
	
	print("[MatchSessionService] 🎴 Precargando %d imágenes..." % required_cards.size())
	
	# 🔄 Esperar a que TERMINEN de cargar todas las imágenes
	print("[MatchSessionService] ⏳ Esperando precarga de imágenes...")
	await CardsManager.preload_deck_images(required_cards)
	print("[MatchSessionService] ✅ Todas las imágenes precargadas")
	
	# 4️⃣ Navegar a GameMatch usando SceneTransition
	print("[MatchSessionService] 🎬 Navegando a GameMatch...")
	SceneTransition.set_pending_data({
		"match_id": current_match["id"],
		"game_state": game_state,
		"initial_state": current_match
	})
	SceneTransition.go_to_gamematch()
	# La escena GameMatch._ready() emitirá una signal cuando esté lista
	# y entonces enviaremos el mensaje WebSocket para iniciar el turno


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


func on_gamematch_ready() -> void:
	"""Llamada por GameMatch cuando está lista la escena y todo está renderizado
	
	En este punto:
	- GameMatch cargó todos los elementos UI
	- Las imágenes están precargadas
	- El tablero está renderizado
	
	Ahora enviamos mensaje WebSocket para iniciar el primer turno
	"""
	if not is_test_mode or not is_in_match:
		print("⚠️ [MatchManager] No estamos en partida TEST")
		return
	
	print("🎮 [MatchManager] GameMatch está lista, iniciando primer turno por WebSocket...")
	
	# Enviar por WebSocket para iniciar el turno
	var match_id = current_match.get("id", "")
	WebSocketManager.start_first_turn(match_id)
