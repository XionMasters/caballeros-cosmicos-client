# GameBoard.gd (REFACTORIZADO v2)
# Tablero principal del juego - Coordinación de zonas
# Objetivo: ~200 líneas, solo coordinación (no renderización)
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
@onready var card_detail_texture = $CardDetailOverlay/CardDetailPanel/VBoxContainer/CardTexture
@onready var card_detail_close_button = $CardDetailOverlay/CardDetailPanel/VBoxContainer/CloseButton
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
	print("[GameBoard] 🎮 Inicializando tablero (refactorizado v2)")
	
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Conectar botones
	if not end_turn_button.pressed.is_connected(_on_end_turn_pressed):
		end_turn_button.pressed.connect(_on_end_turn_pressed)
	if not card_detail_close_button.pressed.is_connected(_on_card_detail_closed):
		card_detail_close_button.pressed.connect(_on_card_detail_closed)
	
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
		var p1_life = current_match.get("player1_life", 12)
		var p1_cosmos = current_match.get("player1_cosmos", 0)
		var p2_life = current_match.get("player2_life", 12)
		var p2_cosmos = current_match.get("player2_cosmos", 0)
		
		player_zone.setup(p1_name, p1_life, p1_cosmos)
		opponent_zone.setup(p2_name, p2_life, p2_cosmos)
		
	elif current_match.get("player2_id", "") == user_id:
		player_number = 2
		var p1_name = current_match.get("player1_name", "Oponente")
		var p2_name = current_match.get("player2_name", "Jugador")
		var p1_life = current_match.get("player1_life", 12)
		var p1_cosmos = current_match.get("player1_cosmos", 0)
		var p2_life = current_match.get("player2_life", 12)
		var p2_cosmos = current_match.get("player2_cosmos", 0)
		
		# En perspectiva del player 2, el player2 es el "local"
		player_zone.setup(p2_name, p2_life, p2_cosmos)
		opponent_zone.setup(p1_name, p1_life, p1_cosmos)
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
	var player_deck_count = game_state.get_player_deck_count(player_number)
	var opponent_deck_count = game_state.get_player_deck_count(opponent_number)
	
	if player_deck:
		player_deck.set_count(player_deck_count)
	if opponent_deck:
		opponent_deck.set_count(opponent_deck_count)
	
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
	if not game_state:
		return
	
	var is_my_turn = (game_state.active_player_number == player_number)
	
	player_zone.enable_input(is_my_turn)
	opponent_zone.enable_input(false)  # Siempre deshabilitado, solo visualización
	
	end_turn_button.disabled = not is_my_turn
	
	var turn_text = "tu equipo (%d)" % player_number if is_my_turn else "oponente"
	print("[GameBoard] 🎮 Turno de %s" % turn_text)


func _update_texts(language_code: String) -> void:
	"""Actualizar textos localizados"""
	end_turn_button.text = LocalizationManager.tr("ui.end_turn") if LocalizationManager else "End Turn"


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


func _on_knight_action_selected(action: String) -> void:
	"""Evento: Usuario seleccionó una acción de caballero"""
	print("[GameBoard] 🗡️ Acción seleccionada: %s" % action)
	# TODO: Delegar al controlador de acciones


func _on_card_detail_closed() -> void:
	"""Cerrar overlay de detalle de carta"""
	card_detail_overlay.visible = false


# ============================================================================
# MÉTODOS AUXILIARES (Para uso futuro)
# ============================================================================
func show_card_detail(card_data: CardData) -> void:
	"""Mostrar detalle de una carta"""
	if not card_detail_overlay or not card_detail_texture:
		return
	
	# Cargar imagen de la carta
	if CardsManager and CardsManager._image_cache.has(card_data.id):
		card_detail_texture.texture = CardsManager._image_cache[card_data.id]
	
	card_detail_overlay.visible = true
