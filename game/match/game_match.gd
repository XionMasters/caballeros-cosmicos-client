# game_match.gd
# Controlador principal de la escena de match
# Responsabilidades:
# 1. Orquestar renderización delegando a controladores
# 2. NO hacer lógica de manos (eso es de PlayerHandController)
# 3. Mantener GameMatch limpio y simple

extends Control

# ============================================================================
# REFERENCIAS A COMPONENTES
# ============================================================================
@onready var player_panel: PlayerStatusPanel = $RootColumns/LeftColumn/LeftStack/PlayerPanel
@onready var opponent_panel: PlayerStatusPanel = $RootColumns/LeftColumn/LeftStack/OpponentPanel
@onready var player_deck: DeckDisplay = $RootColumns/LeftColumn/LeftStack/PlayerDeck
@onready var opponent_deck: DeckDisplay = $RootColumns/LeftColumn/LeftStack/OpponentDeck
@onready var player_hand: HandLayout = $RootColumns/CenterColumn/PlayerHand/HandLayout
@onready var opponent_hand_container: HandLayout = $RootColumns/CenterColumn/OpponentHand/HandLayout
@onready var end_turn_button: Button = $RootColumns/RightColumn/PlayerEmpty/EndTurnButton

# ============================================================================
# CONTROLADORES
# ============================================================================
var card_deal_animator: CardDealAnimator = null
var player_hand_controller: PlayerHandController = null
var opponent_hand_controller: OpponentHandController = null

# ============================================================================
# CICLO DE VIDA
# ============================================================================
func _ready() -> void:
	"""Inicializar el match
	
	Flujo:
	1. Obtener game_state de SceneTransition (si es TEST)
	2. Esperar frames para que nodos estén listos
	3. Configurar componentes
	4. Renderizar estado
	5. Avisar a MatchManager que está listo (inicia turno por WebSocket)
	"""
	print("[GameMatch] 🎮 Inicializando GameMatch...")
	print("[GameMatch] 📌 DEBUG: end_turn_button = %s" % end_turn_button)
	print("[GameMatch] 📌 DEBUG: end_turn_button es null? %s" % (end_turn_button == null))
	
	# 1️⃣ Obtener datos pasados por SceneTransition
	var pending_data = SceneTransition.get_pending_data()
	if pending_data and pending_data.has("game_state"):
		print("[GameMatch] 📥 Usando game_state de SceneTransition")
		var game_state = pending_data["game_state"] as GameState
		if game_state:
			MatchSessionService.game_state = game_state
	
	# 2️⃣ Esperar frames para que los nodos estén listos
	await get_tree().process_frame
	await get_tree().process_frame  # Doble frame para seguridad
	
	# 3️⃣ Conectar señales
	MatchSessionService.match_state_updated.connect(_on_match_state_updated)
	MatchSessionService.phase_changed.connect(_on_phase_changed)
	
	# 3️⃣b Configurar botón de End Turn
	_setup_end_turn_button()
	
	# 4️⃣ Configurar animador y controladores
	_setup_card_deal_animator()
	_setup_hand_controllers()
	
	# 5️⃣ Renderizar estado inicial
	await _render_from_match_state()
	
	# 6️⃣ Esperar a que las imágenes terminen de precargarse
	print("[GameMatch] ⏳ Esperando precarga de imágenes...")
	await get_tree().create_timer(1.0).timeout
	
	# 7️⃣ LISTO: Avisar a MatchManager que puede iniciar el primer turno
	print("[GameMatch] ✅ GameMatch completamente cargado, iniciando primer turno...")
	MatchSessionService.on_gamematch_ready()


# ============================================================================
# SETUP
# ============================================================================
func _setup_card_deal_animator() -> void:
	"""Configurar el animador de cartas del mazo a la mano"""
	card_deal_animator = CardDealAnimator.new(
		preload("res://cards/CardDisplay.tscn"),
		player_hand,
		player_deck.global_position
	)
	add_child(card_deal_animator)
	print("[GameMatch] ✅ CardDealAnimator configurado")


func _setup_hand_controllers() -> void:
	"""Configurar controladores de manos"""
	player_hand_controller = PlayerHandController.new(
		player_hand,
		player_deck,
		card_deal_animator
	)
	
	print("opponent_hand_controller",opponent_hand_container)
	opponent_hand_controller = OpponentHandController.new(
		opponent_hand_container,
		opponent_deck,
		self  # Pasar GameMatch como parent para que el animador tenga get_tree()
	)
	
	print("[GameMatch] ✅ Hand controllers configurados")


func _setup_end_turn_button() -> void:
		
	if end_turn_button == null:
		print("[GameMatch] ❌ ERROR: end_turn_button es NULL!")
		print("═══════════════════════════════════════\n")
		return
	
	print("[GameMatch] ✅ end_turn_button EXISTE")
	
	# Intentar conectar la signal
	print("[GameMatch] 🔗 CONECTANDO signal pressed...")
	end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	print("[GameMatch] ✅ SIGNAL CONECTADA!")
	print("═══════════════════════════════════════\n")
	
	# Cargar imagen del botón
	var button_image_path = "res://assets/ui-icons/end_turn_button.png"
	if ResourceLoader.exists(button_image_path):
		var texture = load(button_image_path) as Texture2D
		if texture:
			end_turn_button.icon = texture
			end_turn_button.text = ""
			print("[GameMatch] ✅ Imagen del botón End Turn cargada")
		else:
			end_turn_button.text = "▶"  # Fallback: flecha como texto
			print("[GameMatch] ⚠️ No se pudo cargar imagen del botón, usando fallback")
	else:
		end_turn_button.text = "▶"  # Fallback: flecha como texto
		print("[GameMatch] ℹ️ Imagen del botón no encontrada, usando fallback")
	
	# Inicialmente deshabilitado hasta que sea el turno del jugador
	_update_end_turn_button_state()
	print("[GameMatch] ✅ End Turn button configurado")


# ============================================================================
# MAIN CALLBACKS
# ============================================================================
func _on_match_state_updated(_match_data: Dictionary) -> void:
	"""Callback cuando MatchManager actualiza el estado"""
	await _render_from_match_state()
	
	# ✅ Avisar que terminamos de renderizar
	MatchSessionService.render_complete.emit()
	print("[GameMatch] 📡 Render completado, emitiendo signal render_complete")


func _render_from_match_state() -> void:
	"""Renderizar el tablero desde el estado actual del match"""
	var current_match = MatchSessionService.current_match
	var game_state = MatchSessionService.game_state
	
	# Validación básica
	if not game_state or not current_match:
		_render_fallback()
		return
	
	# Renderizar todo (delegando a controladores)
	await _render_all(game_state, current_match)


# ============================================================================
# RENDERIZACIÓN (Orquestación)
# ============================================================================
func _render_all(game_state: GameState, current_match: Dictionary):
	"""Renderer principal: delega a controladores especializados
	
	GameMatch NO SABE cómo funciona cada UI.
	Solo orquesta.
	"""
	_render_status_and_deck(game_state, current_match)
	
	# Los controladores se encargan de TODO sobre sus manos
	await player_hand_controller.update_from_state(game_state)
	await opponent_hand_controller.update_from_state(game_state)


func _render_status_and_deck(game_state: GameState, current_match: Dictionary) -> void:
	"""Actualizar paneles de status y contadores de decks"""
	var player_number = game_state.player_number
	
	# Obtener datos según perspectiva del jugador
	var player_name: String
	var player_id: String
	var opponent_name: String
	var opponent_id: String
	
	# 🔑 IMPORTANTE: Los IDs vienen de GameState, no de current_match
	player_id = game_state.player_id
	opponent_id = game_state.opponent_id
	
	# Fallback si faltan IDs
	if player_id.is_empty():
		player_id = AuthManager.get_user_id()
		print("[GameMatch] ⚠️ player_id vacío, usando de AuthManager: %s" % player_id)
	
	if opponent_id.is_empty():
		print("[GameMatch] ⚠️ opponent_id vacío! El servidor no está enviando player2_id en game_state")
		opponent_id = ""
	
	# Los nombres vienen de current_match (si existen)
	if player_number == 1:
		player_name = current_match.get("player1_name", "Jugador")
		opponent_name = current_match.get("player2_name", "Oponente")
	else:
		player_name = current_match.get("player2_name", "Jugador")
		opponent_name = current_match.get("player1_name", "Oponente")
	
	print("[GameMatch] 👤 Datos de jugadores:")
	print("[GameMatch]    - Jugador (%d): %s (ID: %s)" % [player_number, player_name, player_id])
	print("[GameMatch]    - Oponente: %s (ID: %s)" % [opponent_name, opponent_id])
	
	# Actualizar paneles
	player_panel.setup(
		player_name,
		game_state.get_player_life(player_number),
		game_state.get_player_cosmos(player_number),
		player_id
	)
	
	opponent_panel.setup(
		opponent_name,
		game_state.get_player_life(3 - player_number),
		game_state.get_player_cosmos(3 - player_number),
		opponent_id
	)
	
	# Actualizar decks
	player_deck.setup(game_state.player_deck_count, player_id)
	opponent_deck.setup(game_state.opponent_deck_count, opponent_id)


func _render_fallback() -> void:
	"""Renderización de fallback (editor de escenas, sin datos)"""
	player_panel.setup("Tu", 12, 1, "")
	opponent_panel.setup("Rival", 12, 0, "")


# ============================================================================
# TURN MANAGEMENT
# ============================================================================
func _on_phase_changed(phase: String) -> void:
	"""Callback cuando cambia la fase desde MatchManager"""
	print("[GameMatch] 📊 Fase cambió a: %s" % phase)
	_update_end_turn_button_state()
	
	# Para TEST mode: mostrar cartas del rival cuando es su turno
	if MatchSessionService.is_test_mode and (phase == "PLAYER2_TURN" or phase == "OPPONENT_TURN"):
		print("[GameMatch] 🧪 TEST MODE: Mostrando cartas del rival")
		_show_opponent_cards_test()


func _update_end_turn_button_state() -> void:
	"""Actualizar estado (habilitado/deshabilitado) del botón según fase actual"""
	if not end_turn_button or not MatchSessionService.game_state:
		return
	
	var game_state = MatchSessionService.game_state
	var is_player_turn = false
	
	# Detectar si es el turno del jugador
	match game_state.current_phase:
		"player1_turn":
			is_player_turn = (game_state.player_number == 1)
		"player2_turn":
			is_player_turn = (game_state.player_number == 2)
		_:
			is_player_turn = false
	
	end_turn_button.disabled = not is_player_turn
	print("[GameMatch] 🔘 End Turn button habilitado: %s" % is_player_turn)


func _on_end_turn_button_pressed() -> void:
	"""Manejador cuando se presiona el botón de End Turn"""
	print("\n╔════════════════════════════════════════╗")
	print("║          🎯 BOTÓN PRESIONADO 🎯       ║")
	print("╚════════════════════════════════════════╝\n")
	
	print("[GameMatch] 📊 Estado actual:")
	print("[GameMatch]    - is_in_match: %s" % MatchSessionService.is_in_match)
	print("[GameMatch]    - current_match: %s" % (MatchSessionService.current_match if MatchSessionService.current_match else "NULL"))
	print("[GameMatch]    - game_state: %s" % (MatchSessionService.game_state if MatchSessionService.game_state else "NULL"))
	
	if not MatchSessionService.is_in_match:
		print("[GameMatch] ⚠️ No hay match activa (is_in_match=false)")
		return
	
	if not MatchSessionService.current_match:
		print("[GameMatch] ⚠️ current_match es NULL")
		return
	
	var match_id = MatchSessionService.current_match.get("id", "")
	print("[GameMatch]    - match_id obtenido: '%s'" % match_id)
	
	if match_id.is_empty():
		print("[GameMatch] ⚠️ Match ID está vacío")
		return
	
	print("[GameMatch] ✅ Todos los checks pasaron")
	print("[GameMatch] 🔄 PASANDO TURNO al servidor...")
	print("[GameMatch] 📤 POST /matches/%s/pass-turn" % match_id)
	
	# Deshabilitar botón
	end_turn_button.disabled = true
	
	# Crear callback para respuesta
	var callback = func(success: bool, data: Variant, error: String) -> void:
		print("[GameMatch] 📡 RESPUESTA RECIBIDA DEL SERVIDOR")
		print("[GameMatch]    - success: %s" % success)
		print("[GameMatch]    - error: %s" % error)
		
		if success:
			print("[GameMatch] ✅ ¡TURNO PASADO EXITOSAMENTE!")
		else:
			print("[GameMatch] ❌ Error: %s" % error)
			end_turn_button.disabled = false
	
	# Enviar al servidor
	ApiClient.post_request_with_callback(
		"/matches/%s/pass-turn" % match_id,
		{},
		"pass_turn_%s" % match_id,
		callback,
		true
	)


func _show_opponent_cards_test() -> void:
	"""En TEST mode: mostrar las cartas reales del rival en lugar de dorsos"""
	if not MatchSessionService.game_state or not MatchSessionService.is_test_mode:
		return
	
	var game_state = MatchSessionService.game_state
	
	# Obtener cartas del rival según perspectiva
	# (El GameState ya debería tener toda la información del rival en TEST mode)
	print("[GameMatch] 🧪 TEST: Mostrando cartas del rival")
	
	# Actualizar mano del rival con cartas reales
	await opponent_hand_controller.update_from_state(game_state)
