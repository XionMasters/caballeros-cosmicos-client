# GameBoard.gd (REFACTORIZADO v2 - CORREGIDO)
# Tablero principal del juego - Coordinación de zonas
extends Control

# ============================================================================
# REFERENCIAS A COMPONENTES PRINCIPALES
# ============================================================================
@onready var player_deck = $MainContainer/LeftColumn/PlayerDeck/DeckPile
@onready var opponent_deck = $MainContainer/LeftColumn/OpponentDeck/DeckPile

# UI generales
@onready var turn_label = $UILayer/StatsOverlay/TurnLabel
@onready var phase_label = $UILayer/StatsOverlay/PhaseLabel
@onready var end_turn_button = $UILayer/EndTurnButton

# ============================================================================
# ESTADO
# ============================================================================
var game_state: GameState = null
var player_number: int = 0
var current_match: Dictionary = {}
var player_id: String = ""

# ============================================================================
# CICLO DE VIDA
# ============================================================================
func _ready() -> void:
	print("[GameBoard] 🎮 Inicializando tablero (refactorizado)")
	
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Conectar botones
	if end_turn_button and not end_turn_button.pressed.is_connected(_on_end_turn_pressed):
		end_turn_button.pressed.connect(_on_end_turn_pressed)
	
	# Conectar señales del MatchManager
	MatchManager.match_state_updated.connect(_on_match_updated)
	MatchManager.match_error.connect(_on_match_error)
	
	# Inicializar partida
	_initialize_match()

func _initialize_match() -> void:
	"""Inicializar la partida una sola vez"""
	current_match = MatchManager.current_match
	if current_match.is_empty():
		push_error("[GameBoard] No hay partida activa")
		SceneTransition.go_to_lobby()
		return
	
	# Determinar número de jugador
	var user_id = AuthManager.get_user_id()
	player_id = user_id
	
	if current_match.get("player1_id", "") == user_id:
		player_number = 1
		var p1_name = current_match.get("player1_name", "Jugador")
		var p2_name = current_match.get("player2_name", "Oponente")
		var p1_life = current_match.get("player1_life", 12)
		var p1_cosmos = current_match.get("player1_cosmos", 0)
		var p2_life = current_match.get("player2_life", 12)
		var p2_cosmos = current_match.get("player2_cosmos", 0)
		
		# TODO: player_zone y opponent_zone no existen como clases
		# if player_zone:
		#	player_zone.setup(p1_name, p1_life, p1_cosmos)
		# if opponent_zone:
		#	opponent_zone.setup(p2_name, p2_life, p2_cosmos)
		
	elif current_match.get("player2_id", "") == user_id:
		player_number = 2
		var p1_name = current_match.get("player1_name", "Oponente")
		var p2_name = current_match.get("player2_name", "Jugador")
		var p1_life = current_match.get("player1_life", 12)
		var p1_cosmos = current_match.get("player1_cosmos", 0)
		var p2_life = current_match.get("player2_life", 12)
		var p2_cosmos = current_match.get("player2_cosmos", 0)
		
		# TODO: player_zone y opponent_zone no existen como clases
		# if player_zone:
		#	player_zone.setup(p2_name, p2_life, p2_cosmos)
		# if opponent_zone:
		#	opponent_zone.setup(p1_name, p1_life, p1_cosmos)
	else:
		push_error("[GameBoard] No eres parte de esta partida")
		return
	
	print("[GameBoard] ✅ Inicialización completada (Player %d)" % player_number)


# ============================================================================
# ACTUALIZACIÓN DE ESTADO (Main Entry Point)
# ============================================================================
func _on_match_updated(match_data: Dictionary) -> void:
	"""Callback: El servidor actualizó el estado de la partida"""
	print("[GameBoard] 🔄 Estado actualizado del servidor")
	
	current_match = match_data
	
	# Crear/actualizar GameState
	game_state = GameState.from_server_data(match_data, player_id)
	
	# Actualizar UI
	_update_ui()
	
	# Actualizar interactividad según turno
	_update_input_state()


# ============================================================================
# ACTUALIZACIÓN DE UI
# ============================================================================
func _update_ui() -> void:
	"""Actualizar información general de la UI"""
	if not game_state:
		return
	
	if turn_label:
		turn_label.text = "Turno: %d" % game_state.current_turn
	if phase_label:
		phase_label.text = "Fase: %s" % game_state.current_phase.capitalize()


func _update_input_state() -> void:
	"""Habilitar/deshabilitar input según si es mi turno"""
	if not game_state:
		return
	
	var is_my_turn = (game_state.active_player_number == player_number)
	
	# TODO: player_zone y opponent_zone no existen como clases
	# if player_zone:
	#	player_zone.enable_input(is_my_turn)
	# if opponent_zone:
	#	opponent_zone.enable_input(false)  # Siempre deshabilitado, solo visualización
	
	if end_turn_button:
		end_turn_button.disabled = not is_my_turn
	
	var turn_text = "tu equipo (%d)" % player_number if is_my_turn else "oponente"
	print("[GameBoard] 🎮 Turno de %s" % turn_text)


# ============================================================================
# MANEJO DE EVENTOS
# ============================================================================
func _on_end_turn_pressed() -> void:
	"""Usuario apretó botón 'End Turn'"""
	if not game_state or game_state.active_player_number != player_number:
		print("[GameBoard] ❌ No es tu turno")
		return
	
	print("[GameBoard] ⏭️ Pidiendo fin de turno al servidor")
	MatchManager.end_turn()


func _on_match_error(error_message: String) -> void:
	"""Error del servidor"""
	print("[GameBoard] ❌ Error: %s" % error_message)
	# TODO: Mostrar en UI
