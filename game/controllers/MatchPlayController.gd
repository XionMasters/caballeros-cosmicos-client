# MatchPlayController.gd
# Orquesta TODO lo relacionado con JUGAR en una partida
# - Conecta eventos de cartas (drag/drop, click)
# - Valida acciones de UX
# - Envía al servidor
# - Renderiza feedback

class_name MatchPlayController
extends Node

# ============================================================================
# SIGNALS
# ============================================================================
signal card_play_requested(card_instance: CardInstance, target_zone: String, target_slot: int)
signal card_play_failed(reason: String)

# ============================================================================
# REFERENCIAS
# ============================================================================
var board_renderer: BoardRenderer = null
var game_state: GameState = null
var match_manager: MatchManager = null

# Mapeo: CardDisplay → CardInstance (para validación rápida)
var _card_display_to_instance: Dictionary = {}

# ============================================================================
# CONFIGURACIÓN
# ============================================================================
var is_test_mode: bool = false  # En TestBoard, permite jugar aunque no sea tu turno

# ============================================================================
# STATE
# ============================================================================
var current_dragging_card: CardDisplay = null
var is_card_play_in_progress: bool = false

# Energy Reservation System
# Mantiene un registro de energía reservada para plays pendientes
var _pending_energy_costs: Array = []  # Array de {card_id, cost, timestamp}

# ============================================================================
# INIT
# ============================================================================
func _init(
	p_board_renderer: BoardRenderer,
	p_game_state: GameState,
	p_match_manager: MatchManager = null,
	p_is_test_mode: bool = false
) -> void:
	board_renderer = p_board_renderer
	game_state = p_game_state
	match_manager = p_match_manager if p_match_manager else MatchManager
	is_test_mode = p_is_test_mode


# ============================================================================
# SETUP - Conectar eventos de cartas
# ============================================================================

func setup_card_interactions() -> void:
	"""Conectar todos los eventos de cartas del tablero
	
	Se llama después de cada renderizado
	"""
	print("[MatchPlayController] 🎮 Configurando interacciones de cartas...")
	
	_connect_hand_cards()
	_connect_slot_signals()


func _connect_slot_signals() -> void:
	"""Conectar card_dropped signals de todos los slots
	
	Los slots son targets de drag-drop
	"""
	if not board_renderer:
		print("[MatchPlayController] ❌ No hay board_renderer para conectar slots")
		return
	
	var all_slots = []
	
	# Recolectar todos los slots
	all_slots += board_renderer.player_knight_slots
	all_slots += board_renderer.player_tech_slots
	if board_renderer.player_helper_slot:
		all_slots.append(board_renderer.player_helper_slot)
	if board_renderer.player_occasion_slot:
		all_slots.append(board_renderer.player_occasion_slot)
	
	# Conectar signal card_dropped de cada slot
	for slot in all_slots:
		if not slot:
			continue
		
		if not slot.card_dropped.is_connected(_on_card_dropped_in_slot):
			slot.card_dropped.connect(_on_card_dropped_in_slot)
			print("[MatchPlayController] ✅ Conectado slot: %s" % slot.name)
	
	print("[MatchPlayController] ✅ Slots conectados: %d" % all_slots.size())


func _connect_hand_cards() -> void:
	"""Conectar eventos de cartas en mano (jugador)"""
	# Obtener referencia a HandLayout desde el nodo raíz
	var root = get_tree().root.get_child(0)
	var player_hand = root.get_node_or_null("MainContainer/CenterColumn/PlayerArea/PlayerHeader/PlayerHand")
	
	if not player_hand:
		print("[MatchPlayController] ❌ No se encontró player_hand")
		return
	
	var cards = player_hand.get_cards()
	for card_display in cards:
		if card_display is CardDisplay:
			_connect_card_signals(card_display)


func _connect_field_cards() -> void:
	"""Campo vacío (sin field slots en versión simplificada)"""
	# Esta función se deja vacía ya que no hay field slots en TestBoard minimal
	pass


func _connect_card_signals(card_display: CardDisplay) -> void:
	"""Conectar todos los eventos de una carta"""
	if not card_display:
		return
	
	# Guardar instancia para validación rápida
	if card_display.has_meta("card_instance"):
		var card_instance = card_display.get_meta("card_instance")
		_card_display_to_instance[card_display] = card_instance
	
	# Conectar eventos de interactividad
	if not card_display.is_connected("drag_started", Callable(self, "_on_card_drag_started")):
		card_display.drag_started.connect(_on_card_drag_started.bind(card_display))
	
	if not card_display.is_connected("drag_ended", Callable(self, "_on_card_drag_ended")):
		card_display.drag_ended.connect(_on_card_drag_ended.bind(card_display))
	
	if not card_display.is_connected("card_clicked", Callable(self, "_on_card_clicked")):
		card_display.card_clicked.connect(_on_card_clicked.bind(card_display))


# ============================================================================
# CARD INTERACTION HANDLERS
# ============================================================================

func _on_card_drag_started(card_data: CardData, card_display: CardDisplay) -> void:
	"""Usuario comenzó a arrastrar una carta"""
	if not _can_interact():
		return
	
	print("[MatchPlayController] 🎯 Drag iniciado: %s" % card_data.name)
	current_dragging_card = card_display
	
	# Feedback visual (subrayar o destacar)
	if card_display.has_method("set_highlighted"):
		card_display.set_highlighted(true)


func _on_card_drag_ended(card_data: CardData, card_display: CardDisplay) -> void:
	"""Usuario soltó la carta"""
	if not current_dragging_card:
		return
	
	print("[MatchPlayController] 🎯 Drag finalizado: %s" % card_data.name)
	
	# Reset visual
	if card_display.has_method("set_highlighted"):
		card_display.set_highlighted(false)
	
	# Detectar target (slot donde se soltó)
	var target_zone = _detect_drop_zone(card_display.global_position)
	var target_slot = _detect_drop_slot(target_zone, card_display.global_position)
	
	if target_zone and target_slot >= 0:
		_attempt_play_card(card_display, target_zone, target_slot)
	else:
		print("[MatchPlayController] ❌ Zona de drop inválida")
	
	current_dragging_card = null


func _on_card_clicked(card_data: CardData, card_display: CardDisplay) -> void:
	"""Usuario hizo click en una carta (para acciones secundarias)"""
	if not _can_interact():
		return
	
	print("[MatchPlayController] 👆 Click en: %s" % card_data.name)
	
	# Por ahora solo mostrar detalles
	if card_display.has_method("show_details"):
		card_display.show_details()


# ============================================================================
# SLOT DROP HANDLING (Drag-Drop from Hand to Field)
# ============================================================================

func _on_card_dropped_in_slot(payload: Dictionary) -> void:
	"""CardSlot recibió una carta de drag-drop → validar y enviar al servidor
	
	Flujo:
	1. Usuario arrastra carta de mano
	2. CardDisplay.get_drag_data() prepara data
	3. CardSlot._can_drop_data() valida tipo
	4. CardSlot._drop_data() emite card_dropped
	5. AQUÍ: Validamos intención completa y enviamos
	"""
	print("[MatchPlayController] 🎯 Carta soltada en slot")
	
	if not (payload is Dictionary):
		print("[MatchPlayController] ❌ Payload inválido")
		return
	
	var card_instance: CardInstance = payload.get("card_instance")
	var card_display = payload.get("card_display")
	var target_slot = payload.get("target_slot")
	var slot_type = payload.get("slot_type")
	var slot_index: int = payload.get("slot_index", -1)
	
	if not card_instance or not target_slot:
		print("[MatchPlayController] ❌ Falta card_instance o target_slot")
		return
	
	# Convertir slot_type a zone string
	var target_zone = _slot_type_to_zone(slot_type)
	if not target_zone:
		print("[MatchPlayController] ❌ Slot type inválido: %s" % str(slot_type))
		return
	
	print("[MatchPlayController] 📍 Drop zone: %s, slot: %d" % [target_zone, slot_index])
	
	# ✅ NUEVA: Validar energía
	if not _validate_energy_cost(card_instance, card_display):
		print("[MatchPlayController] ❌ Energía insuficiente")
		return
	
	# ✅ NUEVA: Animar el drop
	_animate_card_drop(card_display, target_slot)
	
	# Usar lógica de validación existente (pasando card_display para consumir energía)
	_attempt_play_card_in_slot(card_instance, target_zone, slot_index, card_display)


func _validate_energy_cost(card_instance: CardInstance, card_display) -> bool:
	"""Validar que el jugador tiene suficiente energía (cosmos) para jugar la carta
	
	Fuente de verdad: CardInstance.base_data.cost (CardData object)
	Fallback: card_display.get_data().cost (Dictionary)
	
	Returns: true si puede jugar, false si no tiene energía
	"""
	if not game_state:
		print("[MatchPlayController] ❌ Sin game_state")
		return false
	
	if not card_instance:
		print("[MatchPlayController] ❌ Sin card_instance")
		return false
	
	# ✅ FUENTE DE VERDAD: CardInstance.base_data (siempre CardData)
	var card_cost: int = 0
	if card_instance.base_data:
		card_cost = card_instance.base_data.cost
	
	# ⚠️ FALLBACK: card_display (solo si CardInstance no tiene costo válido)
	if card_cost == 0 and card_display and card_display.has_method("get_data"):
		var card_data = card_display.get_data()
		if card_data is Dictionary:
			card_cost = card_data.get("cost", 0)
	
	var player_cosmos = game_state.player_cosmos
	
	print("[MatchPlayController] ⚡ Validando energía: tengo=%d, costo=%d (source: %s)" % [
		player_cosmos, 
		card_cost,
		"CardInstance" if card_instance.base_data else "CardDisplay"
	])
	
	if player_cosmos < card_cost:
		print("[MatchPlayController] ❌ Energía insuficiente! Necesitas %d, tienes %d" % [card_cost, player_cosmos])
		return false
	
	print("[MatchPlayController] ✅ Energía válida")
	return true


func _reserve_energy(card_instance: CardInstance, card_display) -> bool:
	"""RESERVAR energía para un play pendiente
	
	Patrón: Reservation
	1. Restar del cosmos local
	2. Guardar en _pending_energy_costs
	3. Cuando llega ACK: confirmar (limpiar pending)
	4. Si rechaza: revertir (devolver energía)
	"""
	if not game_state or not card_instance:
		return false
	
	# Obtener costo (FUENTE DE VERDAD: CardInstance.base_data es siempre CardData)
	var card_cost: int = 0
	if card_instance.base_data:
		card_cost = card_instance.base_data.cost
	
	# Fallback si CardInstance no tiene costo
	if card_cost == 0 and card_display and card_display.has_method("get_data"):
		var card_data = card_display.get_data()
		if card_data is Dictionary:
			card_cost = card_data.get("cost", 0)
	
	if card_cost == 0:
		return true  # No hay costo, sin reserva necesaria
	
	# Restar del cosmos
	game_state.player_cosmos -= card_cost
	
	# Guardar en pending
	var card_name = ""
	if card_instance.base_data:
		card_name = card_instance.base_data.name
	
	var pending_entry = {
		"card_id": card_instance.id,
		"card_name": card_name,
		"cost": card_cost,
		"timestamp": Time.get_ticks_msec()
	}
	_pending_energy_costs.append(pending_entry)
	
	print("[MatchPlayController] ⚡ Energía RESERVADA: %d (pending: %d, cosmos: %d)" % [
		card_cost,
		_pending_energy_costs.size(),
		game_state.player_cosmos
	])
	
	return true


func _confirm_pending_energy(card_instance: CardInstance) -> void:
	"""CONFIRMAR energía de un play aceptado por el servidor
	
	Limpia el registro de pendientes cuando el play fue exitoso
	"""
	if not card_instance:
		return
	
	# Buscar y eliminar de pending
	for i in range(_pending_energy_costs.size() - 1, -1, -1):
		var entry = _pending_energy_costs[i]
		if entry["card_id"] == card_instance.id:
			print("[MatchPlayController] ⚡ Energía CONFIRMADA: %s (%d cosmos)" % [
				entry["card_name"],
				entry["cost"]
			])
			_pending_energy_costs.remove_at(i)
			break


func _revert_pending_energy(card_instance: CardInstance) -> void:
	"""REVERTIR energía si un play fue rechazado por el servidor
	
	Devuelve la energía al cosmos
	"""
	if not game_state or not card_instance:
		return
	
	# Buscar y revertir
	for i in range(_pending_energy_costs.size() - 1, -1, -1):
		var entry = _pending_energy_costs[i]
		if entry["card_id"] == card_instance.id:
			game_state.player_cosmos += entry["cost"]
			print("[MatchPlayController] ⚡ Energía REVERTIDA: %s (%d cosmos devueltos → total: %d)" % [
				entry["card_name"],
				entry["cost"],
				game_state.player_cosmos
			])
			_pending_energy_costs.remove_at(i)
			break

func _attempt_play_card_in_slot(
	card_instance: CardInstance,
	target_zone: String,
	target_slot_index: int,
	card_display = null  # Parámetro opcional para consumir energía
) -> void:
	"""Intentar jugar carta en slot específico
	
	Valida intención + envía al servidor + consume energía
	"""
	if is_card_play_in_progress:
		print("[MatchPlayController] ⏳ Ya hay un card play en progreso")
		return
	
	is_card_play_in_progress = true
	
	# Validaciones básicas (UX mínimas)
	if not _validate_card_play(card_instance, target_zone):
		is_card_play_in_progress = false
		return
	
	print("[MatchPlayController] ✅ Enviando al servidor: %s → %s[%d]" % [
		card_instance.base_data.name,
		target_zone,
		target_slot_index
	])
	
	# Emitir solicitud de juego (MatchEventBridge escucha esto)
	card_play_requested.emit(card_instance, target_zone, target_slot_index)
	
	# ✅ NUEVA: Reservar energía (patrón: reservation, no direct consume)
	if card_display:
		_reserve_energy(card_instance, card_display)
	
	# El servidor responderá y triggeará una actualización de GameState
	# En ese momento, confirmar o revertir la energía reservada


func _animate_card_drop(card_display: Control, target_slot) -> void:
	"""Animar la carta siendo soltada en el slot
	
	Efectos:
	- Animar desde posición actual hacia el slot
	- Escala hacia abajo y luego normal
	- Opacidad
	"""
	if not (card_display and is_instance_valid(card_display) and target_slot):
		return
	
	# Guardar posición original
	var _start_pos = card_display.global_position
	var target_pos = target_slot.global_position
	
	print("[MatchPlayController] 🎬 Animando drop: %s → %s" % [card_display.name, target_slot.name])
	
	# Crear tween para la animación
	var tw = create_tween()
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)
	
	# Animar posición (desde mano hacia slot)
	tw.tween_property(card_display, "global_position", target_pos, 0.4)
	
	# Animar escala (pequeña → normal)
	tw.tween_property(card_display, "scale", Vector2(0.7, 0.7), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(card_display, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Animar rotación (pequeño giro)
	tw.tween_property(card_display, "rotation", 0.1, 0.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(card_display, "rotation", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
	
	await tw.finished
	print("[MatchPlayController] ✅ Animación completada")


func _slot_type_to_zone(slot_type: int) -> String:
	"""Convertir CardSlot.SlotType a nombre de zona del servidor"""
	match slot_type:
		CardSlot.SlotType.KNIGHT:
			return "field_knight"
		CardSlot.SlotType.TECH_OBJECT:
			return "field_technique"
		CardSlot.SlotType.HELPER:
			return "field_helper"
		CardSlot.SlotType.SCENARIO:
			return "field_scenario"
		CardSlot.SlotType.OCCASION:
			return "field_occasion"
		_:
			return ""


# ============================================================================
# CARD PLAY LOGIC
# ============================================================================

func _attempt_play_card(card_display: CardDisplay, target_zone: String, target_slot: int) -> void:
	"""Intentar jugar carta validando primero"""
	if is_card_play_in_progress:
		print("[MatchPlayController] ⏳ Ya hay un card play en progreso")
		return
	
	# Obtener instancia
	var card_instance = _card_display_to_instance.get(card_display)
	if not card_instance:
		print("[MatchPlayController] ❌ Card instance no encontrada")
		return
	
	is_card_play_in_progress = true
	
	# Validaciones básicas
	if not _validate_card_play(card_instance, target_zone):
		is_card_play_in_progress = false
		return
	
	print("[MatchPlayController] ✅ Enviando al servidor: %s → %s[%d]" % [
		card_instance.base_data.name,
		target_zone,
		target_slot
	])
	
	# Enviar al servidor
	card_play_requested.emit(card_instance, target_zone, target_slot)
	
	# El servidor responderá y triggeará una actualización de GameState
	# Cuando MatchManager reciba la respuesta, actualizará game_state
	# Y TestBoard llamará nuevamente a setup_card_interactions()


func _validate_card_play(card_instance: CardInstance, target_zone: String) -> bool:
	"""Validaciones mínimas de UX"""
	if not game_state:
		card_play_failed.emit("Sin GameState")
		return false
	
	# ✅ ¿Es mi turno? (o estamos en test mode)
	if not is_test_mode and game_state.active_player_number != game_state.player_number:
		card_play_failed.emit("No es tu turno")
		return false
	
	# ✅ ¿Está en mano?
	# En test mode: cualquier carta que sea jugable es permitida
	# En modo normal: solo cartas de mi mano
	if not is_test_mode:
		var my_hand = game_state.get_hand_for_player(game_state.player_number)
		if card_instance not in my_hand:
			card_play_failed.emit("Carta no está en tu mano")
			return false
	
	# ✅ ¿Es tipo válido para zona?
	if not _is_valid_zone_for_card(card_instance, target_zone):
		card_play_failed.emit("Carta no puede ir a esa zona")
		return false
	
	return true


func _is_valid_zone_for_card(card_instance: CardInstance, target_zone: String) -> bool:
	"""Validar si el tipo de carta es válido para la zona"""
	var card_type = card_instance.base_data.type
	
	match target_zone:
		"field_knight":
			return card_type == "knight"
		"field_technique":
			return card_type == "technique"
		"field_helper":
			return card_type == "helper"
		"field_occasion":
			return card_type == "event"
		_:
			return false


# ============================================================================
# DROP ZONE DETECTION
# ============================================================================

func _detect_drop_zone(card_position: Vector2) -> String:
	"""Detectar qué zona fue el target del drop"""
	# Verificar knight slots
	for i in range(board_renderer.player_knight_slots.size()):
		var slot = board_renderer.player_knight_slots[i]
		if slot and _is_position_in_rect(card_position, slot.get_global_rect()):
			return "field_knight"
	
	# Verificar tech slots
	for i in range(board_renderer.player_tech_slots.size()):
		var slot = board_renderer.player_tech_slots[i]
		if slot and _is_position_in_rect(card_position, slot.get_global_rect()):
			return "field_technique"
	
	# Verificar helper
	if board_renderer.player_helper_slot and _is_position_in_rect(card_position, board_renderer.player_helper_slot.get_global_rect()):
		return "field_helper"
	
	# Verificar occasion
	if board_renderer.player_occasion_slot and _is_position_in_rect(card_position, board_renderer.player_occasion_slot.get_global_rect()):
		return "field_occasion"
	
	return ""


func _detect_drop_slot(target_zone: String, card_position: Vector2) -> int:
	"""Detectar qué slot específico fue el target"""
	var slots = []
	
	match target_zone:
		"field_knight":
			slots = board_renderer.player_knight_slots
		"field_technique":
			slots = board_renderer.player_tech_slots
		_:
			return -1
	
	for i in range(slots.size()):
		var slot = slots[i]
		if slot and _is_position_in_rect(card_position, slot.get_global_rect()):
			return i
	
	return -1


func _is_position_in_rect(pos: Vector2, rect: Rect2) -> bool:
	"""Helper: verificar si posición está dentro de rectángulo"""
	return rect.has_point(pos)


# ============================================================================
# HELPERS
# ============================================================================

func _can_interact() -> bool:
	"""Verificar si se puede interactuar"""
	if not game_state:
		return false
	
	# Solo puedes interactuar durante tu turno
	return game_state.active_player_number == game_state.player_number


# ============================================================================
# STATE UPDATE
# ============================================================================

func on_game_state_updated(new_state: GameState) -> void:
	"""Se llama cuando el servidor actualiza GameState"""
	game_state = new_state
	is_card_play_in_progress = false
	print("[MatchPlayController] Estado actualizado, listo para nuevo input")


# ============================================================================
# CLEANUP
# ============================================================================

func cleanup() -> void:
	"""Limpiar todas las conexiones"""
	_card_display_to_instance.clear()
	current_dragging_card = null
