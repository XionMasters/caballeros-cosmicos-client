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
@onready var player_knight_slots_zone = $RootColumns/CenterColumn/PlayerKnights/plKnightsZone
@onready var opponent_knight_slots_zone = $RootColumns/CenterColumn/OpponentKnights/opKnightsZone

const CARD_DISPLAY_SCENE = preload("res://cards/CardDisplay.tscn")

# ============================================================================
# CONTROLADORES
# ============================================================================
var card_deal_animator: CardDealAnimator = null
var player_hand_controller: PlayerHandController = null
var opponent_hand_controller: OpponentHandController = null
var _last_player_number: int = 0  # Para detectar cambios de perspectiva (TEST match)

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
	5. Avisar a MatchSessionService que está listo (inicia turno por WebSocket)
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
	MatchSessionService.match_error.connect(_on_match_error_received)
	
	# 3️⃣b Configurar botón de End Turn
	_setup_end_turn_button()
	
	# 3️⃣c Conectar slots del campo
	_setup_card_slots()
	
	# 4️⃣ Configurar animador y controladores
	_setup_card_deal_animator()
	_setup_hand_controllers()
	
	# 5️⃣ Renderizar estado inicial
	await _render_from_match_state()

	# ✅ Revalidar botón después del primer render (inicio/reanudar)
	_update_end_turn_button_state()
	
	# 6️⃣ Esperar a que las imágenes terminen de precargarse
	print("[GameMatch] ⏳ Esperando precarga de imágenes...")
	await get_tree().create_timer(1.0).timeout
	
	# 7️⃣ LISTO: Avisar a MatchSessionService que puede iniciar el primer turno
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


func _setup_card_slots() -> void:
	"""Conectar card_dropped de todos los slots del campo del jugador"""
	if not player_knight_slots_zone:
		print("[GameMatch] ❌ player_knight_slots_zone no encontrado")
		return

	var connected := 0
	for slot in player_knight_slots_zone.get_children():
		if slot.has_signal("card_dropped"):
			if not slot.card_dropped.is_connected(_on_card_dropped_in_slot):
				slot.card_dropped.connect(_on_card_dropped_in_slot)
				connected += 1
	print("[GameMatch] ✅ Slots conectados: %d" % connected)


func _on_card_dropped_in_slot(payload: Dictionary) -> void:
	"""Una carta fue soltada en un slot del campo → enviar al servidor"""
	var card_instance: CardInstance = payload.get("card_instance")
	if not card_instance:
		print("[GameMatch] ❌ card_dropped: sin card_instance")
		return

	var target_slot = payload.get("target_slot")
	var slot_type = payload.get("slot_type", CardSlot.SlotType.KNIGHT)

	var target_zone := _slot_type_to_zone(slot_type)
	if target_zone.is_empty():
		print("[GameMatch] ❌ card_dropped: zona desconocida %s" % slot_type)
		return

	# Posición = índice del slot dentro de su contenedor padre
	var position := 0
	if target_slot and is_instance_valid(target_slot):
		position = target_slot.get_index()

	print("[GameMatch] 🃏 Jugando carta %s → %s[%d]" % [
		card_instance.instance_id, target_zone, position
	])
	MatchSessionService.play_card(card_instance.instance_id, target_zone, position)


func _slot_type_to_zone(slot_type: int) -> String:
	match slot_type:
		CardSlot.SlotType.KNIGHT:      return "field_knight"
		CardSlot.SlotType.TECH_OBJECT: return "field_technique"
		CardSlot.SlotType.HELPER:      return "field_helper"
		CardSlot.SlotType.SCENARIO:    return "field_scenario"
		CardSlot.SlotType.OCCASION:    return "field_occasion"
	return ""


func _on_match_error_received(error_message: String) -> void:
	"""El servidor rechazó una acción. Re-renderizar para revertir cambios visuales."""
	print("[GameMatch] ❌ Error del servidor: %s" % error_message)
	# Re-renderizar desde el estado del servidor (revierte la carta al lugar correcto)
	await _render_from_match_state()


# ============================================================================
# MAIN CALLBACKS
# ============================================================================
func _on_match_state_updated(_match_data: Dictionary) -> void:
	"""Callback cuando MatchSessionService actualiza el estado"""
	await _render_from_match_state()
	_update_end_turn_button_state()


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
	# Detectar cambio de perspectiva (TEST match: END_TURN invierte perspectiva)
	if _last_player_number != 0 and game_state.player_number != _last_player_number:
		print("[GameMatch] 🔄 Perspectiva cambió %d → %d — reseteando controllers" % [_last_player_number, game_state.player_number])
		player_hand_controller.reset()
		opponent_hand_controller.reset()
		# Limpiar campo (las cartas cambian de "mías" a "del rival" y viceversa)
		_clear_all_slots(player_knight_slots_zone)
		_clear_all_slots(opponent_knight_slots_zone)
	_last_player_number = game_state.player_number

	_render_status_and_deck(game_state, current_match)
	_render_field(game_state)
	
	# Los controladores se encargan de TODO sobre sus manos
	await player_hand_controller.update_from_state(game_state)
	await opponent_hand_controller.update_from_state(game_state)


# ============================================================================
# FIELD RENDERING
# ============================================================================
func _render_field(game_state: GameState) -> void:
	"""Renderizar cartas en el campo desde el GameState del servidor"""
	_render_knight_zone(player_knight_slots_zone, game_state.player_field_knights, false)
	_render_knight_zone(opponent_knight_slots_zone, game_state.opponent_field_knights, true)


func _render_knight_zone(zone: Node, field_cards: Array[CardInstance], is_opponent: bool) -> void:
	"""Actualizar todos los slots de una zona con las cartas del GameState"""
	if not zone:
		return

	# Mapa posición → CardInstance
	var cards_by_pos: Dictionary = {}
	for ci in field_cards:
		if ci:
			cards_by_pos[ci.field_slot] = ci

	var slots = zone.get_children()
	for i in range(slots.size()):
		var slot = slots[i]
		if not slot is CardSlot:
			continue
		var expected: CardInstance = cards_by_pos.get(i, null)

		if expected == null:
			# Slot debe estar vacío
			if slot.is_occupied:
				_clear_slot_fast(slot)
		else:
			# ¿Ya tiene la carta correcta?
			if slot.is_occupied and slot.card_instance and \
					slot.card_instance.instance_id == expected.instance_id:
				continue  # Ya está, no hace falta redibujar
			if slot.is_occupied:
				_clear_slot_fast(slot)
			_place_card_in_slot(slot, expected, is_opponent)


func _clear_all_slots(zone: Node) -> void:
	"""Limpiar todos los slots de una zona (cambio de perspectiva)"""
	if not zone:
		return
	for slot in zone.get_children():
		if slot is CardSlot and slot.is_occupied:
			_clear_slot_fast(slot)


func _clear_slot_fast(slot: CardSlot) -> void:
	"""Liberar carta del slot sin animación (para re-renders sincrónicos)"""
	if slot.card_display_node and is_instance_valid(slot.card_display_node):
		slot.card_display_node.queue_free()
	slot.card_display_node = null
	slot.card_instance = null
	slot.is_occupied = false
	if slot.watermark_label:
		slot.watermark_label.visible = true


func _place_card_in_slot(slot: CardSlot, card_instance: CardInstance, is_opponent: bool) -> void:
	"""Instanciar un CardDisplay y colocarlo en el slot"""
	if not card_instance or not card_instance.base_data:
		print("[GameMatch] ⚠️ _place_card_in_slot: CardInstance sin base_data")
		return
	var card_display: CardDisplay = CARD_DISPLAY_SCENE.instantiate()
	card_display.setup_from_instance(card_instance)
	if is_opponent:
		# Cartas del rival en campo: no arrastrables
		card_display.interaction_enabled = false
		card_display.disable_hover_animation = true
	slot.place_card(card_display)


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
	"""Callback cuando cambia la fase desde MatchSessionService"""
	print("[GameMatch] 📊 Fase cambió a: %s" % phase)
	_update_end_turn_button_state()
	
	# Para TEST mode: mostrar cartas del rival cuando es su turno
	if MatchSessionService.is_test_mode and (phase == "PLAYER2_TURN" or phase == "OPPONENT_TURN"):
		print("[GameMatch] 🧪 TEST MODE: Mostrando cartas del rival")
		_show_opponent_cards_test()


func _update_end_turn_button_state() -> void:
	"""Actualizar estado (habilitado/deshabilitado) del botón según turno real"""
	if not end_turn_button:
		return

	var is_player_turn := _is_local_player_turn()
	end_turn_button.disabled = not is_player_turn

	var phase_debug := ""
	if MatchSessionService.game_state:
		phase_debug = str(MatchSessionService.game_state.current_phase)

	var current_player_debug = "n/a"
	if MatchSessionService.current_match and MatchSessionService.current_match.has("current_player"):
		current_player_debug = str(MatchSessionService.current_match["current_player"])

	print("[GameMatch] 🔘 End Turn habilitado=%s | phase=%s | current_player=%s" % [
		is_player_turn, phase_debug, current_player_debug
	])

	# Actualizar indicador visual de turno en avatares
	_update_turn_indicator(is_player_turn)


func _update_turn_indicator(is_my_turn: bool) -> void:
	"""Ilumina el avatar del jugador con el turno activo"""
	if player_panel:
		player_panel.set_active_turn(is_my_turn)
	if opponent_panel:
		opponent_panel.set_active_turn(not is_my_turn)

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
	# end_turn_button.disabled = false

	# Enviar al servidor
	MatchSessionService.end_turn()

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

func _is_local_player_turn() -> bool:
	"""Determina de forma robusta si es turno del jugador local."""
	if not MatchSessionService.game_state:
		return false

	var game_state = MatchSessionService.game_state
	var player_number := int(game_state.player_number)
	var phase := str(game_state.current_phase).to_lower()

	# 1) Fuente principal: phase
	match phase:
		"player1_turn":
			return player_number == 1
		"player2_turn":
			return player_number == 2
		"my_turn":
			return true
		"opponent_turn":
			return false

	# 2) Fallback: current_player en metadata del match
	var current_match = MatchSessionService.current_match
	if current_match and current_match.has("current_player"):
		return int(current_match["current_player"]) == player_number

	return false
