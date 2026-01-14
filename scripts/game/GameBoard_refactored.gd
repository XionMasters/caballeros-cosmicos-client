# GameBoard.gd (REFACTORIZADO)
# Tablero principal del juego - Coordinación de zonas
# Objetivo: ~150 líneas, solo coordinación (no renderización)
extends Control

# ============================================================================
# REFERENCIAS A COMPONENTES PRINCIPALES
# ============================================================================
@onready var player_zone: PlayerZone = $MainContainer/CenterColumn/PlayerZone
@onready var opponent_zone: OpponentZone = $MainContainer/CenterColumn/OpponentZone
@onready var player_deck = $MainContainer/LeftColumn/PlayerDeck/DeckPile
@onready var opponent_deck = $MainContainer/LeftColumn/OpponentDeck/DeckPile
@onready var scenario_slot = $MainContainer/RightColumn/ScenarioContainer/ScenarioSlot

# UI generales
@onready var turn_label = $UILayer/StatsOverlay/TurnLabel
@onready var phase_label = $UILayer/StatsOverlay/PhaseLabel
@onready var end_turn_button = $UILayer/EndTurnButton
@onready var card_detail_overlay = $CardDetailOverlay
@onready var card_detail_texture = $CardDetailOverlay/CardDetailPanel/CardTexture
@onready var knight_actions_panel = $UILayer/KnightActionsPanel

# ============================================================================
# PLANTILLAS
# ============================================================================
const CARD_DISPLAY_TEMPLATE = preload("res://scenes/components/cards/CardDisplay.tscn")
const CARD_BACK_TEMPLATE = preload("res://scenes/components/cards/CardBack.tscn")

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
	if not end_turn_button.pressed.is_connected(_on_end_turn_pressed):
		end_turn_button.pressed.connect(_on_end_turn_pressed)
	
	# Conectar señales del MatchManager
	MatchManager.match_state_updated.connect(_on_match_updated)
	MatchManager.match_error.connect(_on_match_error)
	
	# Conectar cambios de idioma
	LocalizationManager.language_changed.connect(_update_texts)
	
	# Conectar panel de acciones de caballero
	if knight_actions_panel:
		knight_actions_panel.action_selected.connect(_on_knight_action_selected)
	
	# Inicializar partida
	_initialize_match()


func _initialize_match() -> void:
	"""Inicializar la partida una sola vez"""
	current_match = MatchManager.current_match
	if current_match.is_empty():
		push_error("[GameBoard] No hay partida activa")
		get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
		return
	
	# Determinar número de jugador
	var user_id = AuthManager.get_user_id()
	player_id = user_id
	
	if current_match.get("player1_id", "") == user_id:
		player_number = 1
		var p1_name = current_match.get("player1_name", "Jugador")
		var p2_name = current_match.get("player2_name", "Oponente")
		player_zone.setup(p1_name, 12, 0)
		opponent_zone.setup(p2_name, 12, 0)
	elif current_match.get("player2_id", "") == user_id:
		player_number = 2
		var p1_name = current_match.get("player1_name", "Oponente")
		var p2_name = current_match.get("player2_name", "Jugador")
		player_zone.setup(p2_name, 12, 0)
		opponent_zone.setup(p1_name, 12, 0)
	else:
		push_error("[GameBoard] No eres parte de esta partida")
		return
	
	print("[GameBoard] ✅ Inicialización completada")


# ============================================================================
# ACTUALIZACIÓN DE ESTADO (Main Entry Point)
# ============================================================================
func _on_match_updated(match_data: Dictionary) -> void:
	"""Callback: El servidor actualizó el estado de la partida"""
	print("[GameBoard] 🔄 Estado actualizado del servidor")
	
	# Crear/actualizar GameState
	game_state = GameState.from_server_data(match_data, player_id)
	
	# Renderizar zonas
	_render_all_zones()
	
	# Actualizar UI
	_update_ui()
	
	# Actualizar interactividad según turno
	_update_input_state()


# ============================================================================
# RENDERIZACIÓN (Delegada a componentes)
# ============================================================================
func _render_all_zones() -> void:
	"""Renderizar todas las zonas desde game_state"""
	if not game_state:
		return
	
	print("[GameBoard] 🎨 Renderizando zonas")
	
	# Renderizar zona del jugador (desde perspectiva local)
	player_zone.render_from_game_state(game_state, player_number)
	
	# Renderizar zona del oponente
	var opponent_number = 3 - player_number  # 1→2, 2→1
	opponent_zone.render_from_game_state(game_state, opponent_number)
	
	# Actualizar mazos
	player_deck.set_count(game_state.get_player_deck_count(player_number))
	opponent_deck.set_count(game_state.get_player_deck_count(opponent_number))
	
	# TODO: Renderizar escenario si existe


# ============================================================================
# ACTUALIZACIÓN DE UI
# ============================================================================
func _update_ui() -> void:
	"""Actualizar información general de la UI"""
	if not game_state:
		return
	
	turn_label.text = "Turno: %d" % game_state.current_turn
	phase_label.text = "Fase: %s" % game_state.current_phase.capitalize()


func _update_input_state() -> void:
	"""Habilitar/deshabilitar input según si es mi turno"""
	var is_my_turn = (game_state.active_player_number == player_number)
	
	player_zone.enable_input(is_my_turn)
	opponent_zone.enable_input(false)  # Siempre deshabilitado, solo visualización
	
	end_turn_button.disabled = not is_my_turn
	
	print("[GameBoard] 🎮 Turno de %s" % ("tu equipo" if is_my_turn else "oponente"))


func _update_texts(language_code: String) -> void:
	"""Actualizar textos localizados"""
	# Implementar si es necesario
	pass


# ============================================================================
# MANEJO DE EVENTOS
# ============================================================================
func _on_end_turn_pressed() -> void:
	"""Usuario apretó botón 'End Turn'"""
	if not game_state or game_state.active_player_number != player_number:
		return
	
	print("[GameBoard] ⏭️ Pidiendo fin de turno al servidor")
	MatchManager.end_turn()


func _on_match_error(error_message: String) -> void:
	"""Error del servidor"""
	print("[GameBoard] ❌ Error: %s" % error_message)
	# TODO: Mostrar en UI


func _on_knight_action_selected(action: String) -> void:
	"""Evento: Usuario seleccionó una acción de caballero"""
	print("[GameBoard] 🗡️ Acción seleccionada: %s" % action)
	# TODO: Delegar al controlador de acciones
