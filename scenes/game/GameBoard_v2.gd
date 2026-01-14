# GameBoard.gd (REFACTORIZADO v2 - CORREGIDO)
# Tablero principal del juego - Coordinación de zonas
extends Control

# ============================================================================
# CONFIGURACIÓN (Exportada - Editable en Inspector Godot)
# ============================================================================
@export var enable_test_mode: bool = false  # Cambiar a true para jugar contra ti mismo

# ============================================================================
# REFERENCIAS A COMPONENTES PRINCIPALES
# ============================================================================
@onready var player_zone: PlayerZone = $MainContainer/CenterColumn/PlayerZone
@onready var opponent_zone: OpponentZone = $MainContainer/CenterColumn/OpponentZone
@onready var player_deck = $MainContainer/LeftColumn/PlayerDeck/DeckPile
@onready var opponent_deck = $MainContainer/LeftColumn/OpponentDeck/DeckPile

# UI generales
@onready var turn_label = $UILayer/StatsOverlay/TurnLabel
@onready var phase_label = $UILayer/StatsOverlay/PhaseLabel
@onready var end_turn_button = $UILayer/EndTurnButton

# ============================================================================
# REFERENCIAS A SLOTS (Para BoardRenderer - Renderización de cartas)
# ============================================================================
@onready var player_hand = $MainContainer/CenterColumn/PlayerZone/HandContainer/PlayerHand
@onready var opponent_hand = $MainContainer/CenterColumn/OpponentZone/HandContainer/PlayerHand
@onready var player_knight_slots = [
	$MainContainer/CenterColumn/PlayerZone/FieldContainer/KnightZone/HBoxContainer/Slot1,
	$MainContainer/CenterColumn/PlayerZone/FieldContainer/KnightZone/HBoxContainer/Slot2,
	$MainContainer/CenterColumn/PlayerZone/FieldContainer/KnightZone/HBoxContainer/Slot3,
	$MainContainer/CenterColumn/PlayerZone/FieldContainer/KnightZone/HBoxContainer/Slot4,
	$MainContainer/CenterColumn/PlayerZone/FieldContainer/KnightZone/HBoxContainer/Slot5,
]
@onready var opponent_knight_slots = [
	$MainContainer/CenterColumn/OpponentZone/VBoxContainer/FieldContainer/KnightZone/HBoxContainer/Slot1,
	$MainContainer/CenterColumn/OpponentZone/VBoxContainer/FieldContainer/KnightZone/HBoxContainer/Slot2,
	$MainContainer/CenterColumn/OpponentZone/VBoxContainer/FieldContainer/KnightZone/HBoxContainer/Slot3,
	$MainContainer/CenterColumn/OpponentZone/VBoxContainer/FieldContainer/KnightZone/HBoxContainer/Slot4,
	$MainContainer/CenterColumn/OpponentZone/VBoxContainer/FieldContainer/KnightZone/HBoxContainer/Slot5,
]
@onready var player_tech_slots = [
	$MainContainer/CenterColumn/PlayerZone/FieldContainer/TechniqueZone/HBoxContainer/Slot1,
	$MainContainer/CenterColumn/PlayerZone/FieldContainer/TechniqueZone/HBoxContainer/Slot2,
	$MainContainer/CenterColumn/PlayerZone/FieldContainer/TechniqueZone/HBoxContainer/Slot3,
	$MainContainer/CenterColumn/PlayerZone/FieldContainer/TechniqueZone/HBoxContainer/Slot4,
	$MainContainer/CenterColumn/PlayerZone/FieldContainer/TechniqueZone/HBoxContainer/Slot5,
]
@onready var opponent_tech_slots = [
	$MainContainer/CenterColumn/OpponentZone/VBoxContainer/FieldContainer/TechniqueZone/HBoxContainer/Slot1,
	$MainContainer/CenterColumn/OpponentZone/VBoxContainer/FieldContainer/TechniqueZone/HBoxContainer/Slot2,
	$MainContainer/CenterColumn/OpponentZone/VBoxContainer/FieldContainer/TechniqueZone/HBoxContainer/Slot3,
	$MainContainer/CenterColumn/OpponentZone/VBoxContainer/FieldContainer/TechniqueZone/HBoxContainer/Slot4,
	$MainContainer/CenterColumn/OpponentZone/VBoxContainer/FieldContainer/TechniqueZone/HBoxContainer/Slot5,
]
@onready var player_helper_slot = $MainContainer/CenterColumn/PlayerZone/SpecialZonesContainer/HelperSlot
@onready var opponent_helper_slot = $MainContainer/CenterColumn/OpponentZone/SpecialZonesContainer/HelperSlot
@onready var player_occasion_slot = $MainContainer/CenterColumn/PlayerZone/SpecialZonesContainer/OccasionSlot
@onready var opponent_occasion_slot = $MainContainer/CenterColumn/OpponentZone/SpecialZonesContainer/OccasionSlot
@onready var scenario_slot = $MainContainer/RightColumn/ScenarioContainer/ScenarioSlot

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
var board_renderer: BoardRenderer = null
var match_play_controller: MatchPlayController = null
var is_test_mode: bool = false  # Si false = multiplayer real, si true = puedes jugar ambos lados

# ============================================================================
# CICLO DE VIDA
# ============================================================================
func _ready() -> void:
	print("[GameBoard] 🎮 Inicializando tablero (refactorizado)")
	
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Establecer modo de prueba desde la configuración exportada
	is_test_mode = enable_test_mode
	
	# Crear BoardRenderer con referencias a todos los slots
	board_renderer = BoardRenderer.new(
		player_hand,
		player_knight_slots,
		player_tech_slots,
		player_helper_slot,
		player_occasion_slot,
		player_deck,
		opponent_hand,
		opponent_knight_slots,
		opponent_tech_slots,
		opponent_helper_slot,
		opponent_occasion_slot,
		opponent_deck,
		scenario_slot,
		CARD_DISPLAY_TEMPLATE,
		CARD_BACK_TEMPLATE
	)
	
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
		get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
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
		
		if player_zone:
			player_zone.setup(p1_name, p1_life, p1_cosmos)
		if opponent_zone:
			opponent_zone.setup(p2_name, p2_life, p2_cosmos)
		
	elif current_match.get("player2_id", "") == user_id:
		player_number = 2
		var p1_name = current_match.get("player1_name", "Oponente")
		var p2_name = current_match.get("player2_name", "Jugador")
		var p1_life = current_match.get("player1_life", 12)
		var p1_cosmos = current_match.get("player1_cosmos", 0)
		var p2_life = current_match.get("player2_life", 12)
		var p2_cosmos = current_match.get("player2_cosmos", 0)
		
		if player_zone:
			player_zone.setup(p2_name, p2_life, p2_cosmos)
		if opponent_zone:
			opponent_zone.setup(p1_name, p1_life, p1_cosmos)
	else:
		push_error("[GameBoard] No eres parte de esta partida")
		return
	
	# Crear MatchPlayController si es test_mode (permite jugar ambos lados)
	if is_test_mode:
		print("[GameBoard] 🧪 Test Mode: Creando MatchPlayController para jugar ambos lados")
		match_play_controller = MatchPlayController.new(
			board_renderer,
			game_state,
			MatchManager,
			true  # is_test_mode=true
		)
		add_child(match_play_controller)
		match_play_controller.setup_card_interactions()
	
	print("[GameBoard] ✅ Inicialización completada (Player %d, Test Mode: %s)" % [player_number, is_test_mode])


# ============================================================================
# ACTUALIZACIÓN DE ESTADO (Main Entry Point)
# ============================================================================
func _on_match_updated(match_data: Dictionary) -> void:
	"""Callback: El servidor actualizó el estado de la partida"""
	print("[GameBoard] 🔄 Estado actualizado del servidor")
	
	current_match = match_data
	
	# Crear/actualizar GameState
	game_state = GameState.from_server_data(match_data, player_id)
	
	# Si estamos en test_mode, actualizar el MatchPlayController
	if is_test_mode and match_play_controller:
		match_play_controller.on_game_state_updated(game_state)
	
	# Renderizar zonas completas (mano, campos, stats)
	_render_all_zones()
	
	# Actualizar UI
	_update_ui()
	
	# Actualizar interactividad según turno
	_update_input_state()


# ============================================================================
# RENDERIZACIÓN DE ZONAS
# ============================================================================
func _render_all_zones() -> void:
	"""Renderizar todas las zonas del tablero desde GameState"""
	if not game_state or not board_renderer:
		return
	
	print("[GameBoard] 🎨 Renderizando zonas del tablero con BoardRenderer...")
	
	# Usar BoardRenderer para renderizar todas las cartas en sus zonas
	# GameState ya contiene player_number establecido correctamente
	board_renderer.render(game_state)
	
	# Si en test_mode, re-configurar interacciones de cartas después de renderizar
	if is_test_mode and match_play_controller:
		match_play_controller.setup_card_interactions()
	
	# Actualizar contadores de mazos
	_update_deck_counts()


func _update_deck_counts() -> void:
	"""Actualizar contadores visuales de mazos"""
	if not game_state:
		return
	
	var player_deck_count = game_state.get_player_deck_count(player_number)
	var opponent_number = 3 - player_number
	var opponent_deck_count = game_state.get_player_deck_count(opponent_number)
	
	if player_deck:
		player_deck.set_count(player_deck_count)
	if opponent_deck:
		opponent_deck.set_count(opponent_deck_count)


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
	
	if player_zone:
		player_zone.enable_input(is_my_turn)
	if opponent_zone:
		opponent_zone.enable_input(false)  # Siempre deshabilitado, solo visualización
	
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
