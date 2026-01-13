# MatchEventBridge.gd
# Puente entre eventos del servidor (WebSocket) y el sistema de juego local
# Traduce eventos de MatchManager → GameState → MatchPlayController

class_name MatchEventBridge
extends Node

# ============================================================================
# REFERENCIAS
# ============================================================================
var match_play_controller: MatchPlayController = null
var board_renderer: BoardRenderer = null
var game_state: GameState = null

# ============================================================================
# INIT
# ============================================================================
func _init(
	p_controller: MatchPlayController,
	p_renderer: BoardRenderer,
	p_game_state: GameState
) -> void:
	match_play_controller = p_controller
	board_renderer = p_renderer
	game_state = p_game_state


# ============================================================================
# SETUP
# ============================================================================

func setup() -> void:
	"""Conectar a MatchManager para escuchar eventos"""
	print("[MatchEventBridge] 🌉 Configurando puente de eventos...")
	
	# Escuchar respuestas del servidor
	# Los signals reales de MatchManager:
	MatchManager.match_state_updated.connect(_on_match_state_updated)
	MatchManager.phase_changed.connect(_on_phase_changed)
	MatchManager.match_error.connect(_on_match_error)
	
	# Conectar solicitud de juego desde el controller
	match_play_controller.card_play_requested.connect(_on_card_play_requested)


# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_card_play_requested(
	card_instance: CardInstance,
	target_zone: String,
	target_slot: int
) -> void:
	"""El controller quiere jugar una carta → enviar al servidor"""
	print("[MatchEventBridge] 📤 Reenviando solicitud al servidor...")
	
	# Enviar al MatchManager (que hace HTTP al servidor)
	MatchManager.play_card(
		card_instance.instance_id,
		target_zone,
		target_slot
	)


func _on_phase_changed(phase: String) -> void:
	"""Fase cambió"""
	print("[MatchEventBridge] 🔄 Fase cambió: %s" % phase)
	
	# Actualizar disponibilidad de interacción
	if match_play_controller:
		match_play_controller.on_game_state_updated(game_state)


func _on_match_error(error_message: String) -> void:
	"""El servidor reportó un error"""
	print("[MatchEventBridge] ❌ Error del servidor: %s" % error_message)
	
	match_play_controller.card_play_failed.emit(error_message)


func _on_match_state_updated(_match_data: Dictionary) -> void:
	"""El servidor actualizó el estado de la partida
	
	Flujo:
	1. GameState ya fue actualizado por MatchManager
	2. Re-renderizar tablero
	3. Reconectar eventos de cartas
	"""
	print("[MatchEventBridge] 🔄 Estado actualizado del servidor")
	
	# Aquí el GameState ya fue actualizado por MatchManager
	# Solo notificar al controller que se re-renderizó
	if match_play_controller:
		match_play_controller.on_game_state_updated(game_state)
	
	# El tablero se re-renderiza en TestBoard cuando recibe este evento
	# Así que simplemente indicamos que estamos listos


# ============================================================================
# CLEANUP
# ============================================================================

func cleanup() -> void:
	"""Desconectar eventos"""
	MatchManager.match_state_updated.disconnect(_on_match_state_updated)
	MatchManager.phase_changed.disconnect(_on_phase_changed)
	MatchManager.match_error.disconnect(_on_match_error)
	
	match_play_controller.card_play_requested.disconnect(_on_card_play_requested)
