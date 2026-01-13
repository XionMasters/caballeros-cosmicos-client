# CardPlayManager.gd
# Validador ligero de UX para jugar cartas
# Forwardea al servidor (MatchManager) tras validación mínima
# ⚠️ NO realiza cálculos. ⚠️ NO modifica GameState.
class_name CardPlayManager
extends Node

signal card_played(card_instance: CardInstance, success: bool)
signal cost_not_affordable(card_instance: CardInstance, required: int, available: int)
signal card_played_feedback(message: String)

var match_manager: MatchManager = null
var game_state: GameState = null

var _is_playing_card: bool = false  # Evitar múltiples juegos simultáneos


func _ready() -> void:
	match_manager = MatchManager.instance if MatchManager.has_meta("instance") else null
	if not match_manager:
		match_manager = get_node_or_null("/root/MatchManager")
	
	game_state = match_manager.get_game_state() if match_manager else null


func can_play_card(card_instance: CardInstance, player_cosmos: int) -> bool:
	"""Validar mínimo: ¿puede jugarse desde UX?
	⚠️ NO valida si costo es legal (eso decide servidor)
	✅ Solo verifica que existe la carta y estoy en fase correcta
	"""
	if not card_instance or not card_instance.base_data:
		return false
	
	if not game_state:
		return false
	
	# ✅ Validación mínima de UX
	if game_state.current_player != game_state.local_player:
		print("[CardPlayManager] ❌ No es tu turno")
		return false
	
	if card_instance.is_exhausted:
		print("[CardPlayManager] ❌ Carta agotada")
		return false
	
	# ✅ Validación mínima: ¿existe en mi mano?
	var my_hand = game_state.get_hand_for_player(game_state.local_player)
	if card_instance not in my_hand:
		print("[CardPlayManager] ❌ Carta no está en tu mano")
		return false
	
	# ⚠️ NO validar costo aquí - el servidor lo hace
	# ⚠️ NO validar zona - el servidor lo hace
	
	return true


func play_card_to_field(card_instance: CardInstance, target_zone: String, target_slot: int, _player_cosmos: int = 0) -> void:
	"""Jugar carta: valida UX mínimo, forwardea al servidor
	
	Flujo:
	1. Validar condiciones mínimas (¿está en mi mano? ¿es mi turno?)
	2. Enviar a MatchManager
	3. Servidor valida TODO (costo, zona válida, etc)
	4. Servidor responde con estado actualizado
	5. MatchManager actualiza GameState local
	"""
	if _is_playing_card:
		print("[CardPlayManager] ⏳ Ya hay un card play en progreso")
		return
	
	# ✅ Validar que pueda jugarse desde UX
	if not can_play_card(card_instance, 0):  # No validamos cosmos
		card_played.emit(card_instance, false)
		return
	
	_is_playing_card = true
	
	print("[CardPlayManager] 🃏 Enviando solicitud al servidor: %s → %s[%d]" % [
		card_instance.base_data.name,
		target_zone,
		target_slot
	])
	
	# ✅ FORWARDEAR al MatchManager (no hacer HTTP directo)
	if match_manager:
		match_manager.play_card(card_instance.instance_id, target_zone, target_slot)
		# MatchManager internamente usa APIClient + WebSocket
		# No hacemos HTTPRequest directo aquí
		_on_request_sent(card_instance)
	else:
		print("[CardPlayManager] ❌ MatchManager no disponible")
		_is_playing_card = false
		card_played.emit(card_instance, false)


func play_card_from_hand(card_display: Node, target_zone: String, target_slot: int) -> void:
	"""Versión simplificada: jugar carta desde CardDisplay
	
	Forwardea a play_card_to_field
	"""
	if not card_display or not card_display.has_method("get_instance"):
		print("[CardPlayManager] ❌ Card display inválido")
		return
	
	var card_instance = card_display.get_instance()
	if not card_instance:
		print("[CardPlayManager] ❌ Card instance no encontrado")
		return
	
	play_card_to_field(card_instance, target_zone, target_slot)


func _on_request_sent(card_instance: CardInstance) -> void:
	"""Callback cuando la solicitud se envía (ligeramente)
	
	El servidor responderá vía WebSocket → MatchManager → GameState
	No esperamos respuesta directa aquí
	"""
	print("[CardPlayManager] ✅ Solicitud enviada al servidor, esperando confirmación...")
	# El servidor actualizará GameState vía WebSocket
	# GameBoard se re-renderizará automáticamente


func _is_valid_zone_for_card(card_instance: CardInstance) -> bool:
	"""Verificar que el tipo de carta pueda ir a esta zona
	✅ Validación MÍNIMA - no es exhaustiva
	"""
	if not card_instance or not card_instance.base_data:
		return false
	
	var card_type = card_instance.base_data.type
	
	# Solo validar que el tipo existe
	match card_type:
		"knight", "technique", "item", "stage", "helper", "event":
			return true  # Todos los tipos pueden intentarse
		_:
			return false


func debug_test_play_card(card_instance: CardInstance) -> void:
	"""Función de DEBUG ÚNICAMENTE
	
	⚠️ Usa solo para testing
	No ejecuta request real al servidor
	"""
	print("\n[CardPlayManager] === DEBUG TEST PLAY CARD ===")
	print("Carta: %s" % card_instance.base_data.name)
	print("Tipo: %s" % card_instance.base_data.type)
	
	if can_play_card(card_instance, 0):
		print("✅ Pasaría validación UX")
	else:
		print("❌ Fallaría validación UX")
	
	print("[CardPlayManager] ================================================\n")

