# GameController.gd
# Controlador de Intención - Validador ligero de UX
# ✅ Valida condiciones MÍNIMAS del cliente
# ✅ Forwardea al servidor (MatchSessionService)
# ❌ NO calcula daño
# ❌ NO aplica efectos
# ❌ NO modifica GameState
# ❌ NO valida reglas complejas (eso decide servidor)

class_name GameController
extends Node

var game_state: GameState = null
var match_manager: MatchSessionService = null

# Señales para UI (feedback inmediato)
signal play_card_requested(card_instance: CardInstance, zone: String)
signal attack_requested(attacker_id: String, defender_id: String)
signal end_turn_requested()

func set_game_state(state: GameState) -> void:
	game_state = state

func set_match_manager(mm: MatchSessionService) -> void:
	match_manager = mm

# =====================================================
# CARTAS - Validación de UX + Forwarding
# =====================================================
func request_play_card(card_instance: CardInstance, zone: String, position: int = -1) -> bool:
	"""Validar que UX permita jugar carta, luego forwardear al servidor"""
	
	# Validaciones MÍNIMAS
	if not game_state or not card_instance or not match_manager:
		print("[GameController] ❌ Estado incompleto")
		return false

	# ✅ ¿Es mi turno?
	if game_state.current_player != game_state.local_player:
		print("[GameController] ❌ No es tu turno")
		return false

	# ✅ ¿La carta existe en mi mano?
	var my_hand = game_state.get_hand_for_player(game_state.local_player)
	if card_instance not in my_hand:
		print("[GameController] ❌ Carta no está en tu mano")
		return false

	# ✅ ¿La carta está agotada?
	if card_instance.is_exhausted:
		print("[GameController] ❌ Carta agotada")
		return false

	# ⚠️ NO validamos:
	# - Costo (servidor lo valida)
	# - Zona válida (servidor lo valida)
	# - Efectos (servidor lo aplica)

	print("[GameController] 🃏 Enviando solicitud jugar: %s → %s" % [card_instance.base_data.name, zone])
	play_card_requested.emit(card_instance, zone)

	# ✅ Forwardear al MatchSessionService
	match_manager.play_card(card_instance.instance_id, zone, position)
	return true


# =====================================================
# ATAQUES - Validación de UX + Forwarding
# =====================================================
func request_attack(attacker_id: String, defender_id: String) -> bool:
	"""Validar que UX permita atacar, luego forwardear al servidor"""
	
	if not game_state or not match_manager:
		print("[GameController] ❌ Estado incompleto")
		return false

	# ✅ ¿El atacante existe en el campo?
	var attacker = game_state.get_card_by_instance_id(attacker_id)
	if not attacker:
		print("[GameController] ❌ Atacante no existe")
		return false

	# ✅ ¿Estoy atacando con mi propio caballero?
	if attacker.player_number != game_state.local_player:
		print("[GameController] ❌ No es tu caballero")
		return false

	# ✅ ¿El caballero está agotado?
	if attacker.is_exhausted:
		print("[GameController] ❌ Caballero agotado")
		return false

	# ⚠️ NO validamos:
	# - Si puede atacar por modo/estado (servidor lo valida)
	# - Si el defensor existe/es válido (servidor lo valida)
	# - Si hay lethal damage (servidor lo calcula)

	print("[GameController] ⚔️ Enviando solicitud atacar: %s → %s" % [attacker_id, defender_id])
	attack_requested.emit(attacker_id, defender_id)

	# ✅ Forwardear al MatchSessionService
	match_manager.send_attack(attacker_id, defender_id)
	return true


# =====================================================
# TURNO - Forwarding simple
# =====================================================
func request_end_turn() -> void:
	"""Forwardear petición de fin de turno"""
	
	if not game_state or not match_manager:
		print("[GameController] ❌ Estado incompleto")
		return

	# ✅ Validación mínima: ¿es mi turno?
	if game_state.current_player != game_state.local_player:
		print("[GameController] ❌ No es tu turno")
		return

	print("[GameController] 🔄 Enviando fin de turno")
	end_turn_requested.emit()

	# ✅ Forwardear al MatchSessionService
	match_manager.end_turn()
