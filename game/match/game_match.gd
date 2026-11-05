# game_match.gd
# Clase base para los modos de partida.
# NO instanciar directamente — usar PvPMatch o TestMatch según el contexto.
#
# Sub-controladores:
#   FieldRenderer          → renderizar zonas de caballeros
#   TurnController         → botón End Turn y estado de turno
#   KnightActionController → acciones e interacción con slots
#   StatusPanelController  → paneles de vida/cosmos y contadores de mazo
#   PlayerHandController   → mano del jugador
#   OpponentHandController → mano del rival

class_name GameMatch
extends Control

# ============================================================================
# REFERENCIAS A NODOS
# ============================================================================
@onready var player_panel: PlayerStatusPanel = $RootColumns/LeftColumn/LeftStack/PlayerPanel
@onready var opponent_panel: PlayerStatusPanel = $RootColumns/LeftColumn/LeftStack/OpponentPanel
@onready var player_deck: DeckDisplay = $RootColumns/LeftColumn/LeftStack/PlayerDeck
@onready var opponent_deck: DeckDisplay = $RootColumns/LeftColumn/LeftStack/OpponentDeck
@onready var player_piles: PilesPanel = $RootColumns/LeftColumn/LeftStack/PlayerPiles
@onready var opponent_piles: PilesPanel = $RootColumns/LeftColumn/LeftStack/OpponentPiles
@onready var player_hand: HandLayout = $RootColumns/CenterColumn/PlayerHand/HandLayout
@onready var opponent_hand_container: HandLayout = $RootColumns/CenterColumn/OpponentHand/HandLayout
@onready var end_turn_button: Button = $RootColumns/RightColumn/PlayerEmpty/EndTurnButton
@onready var player_knight_slots_zone = $RootColumns/CenterColumn/PlayerKnights/plKnightsZone
@onready var opponent_knight_slots_zone = $RootColumns/CenterColumn/OpponentKnights/opKnightsZone
@onready var battle_background: Control = $BattleBackground  # BattleBackground.gd

const CARD_DISPLAY_SCENE = preload("res://cards/CardDisplay.tscn")
const REPLAY_CONTROLS_SCRIPT = preload("res://game/match/ReplayControls.gd")
const BOARD_MAT_SCRIPT = preload("res://game/match/BoardMat.gd")

var _replay_controls: CanvasLayer = null  # Solo en modo repetición
var _board_mat: Control = null            # Tapete del campo + rótulo de turno

# ============================================================================
# SUB-CONTROLADORES
# ============================================================================
var card_deal_animator: CardDealAnimator = null
var player_hand_controller: PlayerHandController = null
var opponent_hand_controller: OpponentHandController = null

var _field_renderer: FieldRenderer = null
var _turn_controller: TurnController = null
var _knight_controller: KnightActionController = null
var _status_controller: StatusPanelController = null

var _last_player_number: int = 0  # Para detectar cambios de perspectiva (TEST match)
var _orchestrator: AnimationOrchestrator = null

# ============================================================================
# CICLO DE VIDA
# ============================================================================
func _ready() -> void:
	print("[GameMatch] 🎮 Inicializando...")

	# 1️⃣ Estado inicial vía SceneTransition (TEST match)
	var pending_data = SceneTransition.get_pending_data()
	if pending_data and pending_data.has("game_state"):
		var gs := pending_data["game_state"] as GameState
		if gs:
			MatchSessionService.game_state = gs

	# 2️⃣ Esperar que los nodos estén listos
	await get_tree().process_frame
	await get_tree().process_frame

	# 3️⃣ Señales de MatchSessionService
	MatchSessionService.match_state_updated.connect(_on_match_state_updated)
	MatchSessionService.phase_changed.connect(_on_phase_changed)
	MatchSessionService.match_error.connect(_on_match_error_received)

	# 4️⃣ Crear y configurar sub-controladores
	_setup_controllers()

	# Repetición: controles encima del tablero (que queda bloqueado)
	if MatchSessionService.is_replay:
		_replay_controls = REPLAY_CONTROLS_SCRIPT.new()
		add_child(_replay_controls)

	# 5️⃣ Render inicial
	await _render_from_match_state()
	_turn_controller.update_state()
	_update_turn_banner()
	_knight_controller.refresh_pending_selection(MatchSessionService.game_state)

	# 6️⃣ Esperar precarga de imágenes
	print("[GameMatch] ⏳ Esperando precarga de imágenes...")
	await get_tree().create_timer(1.0).timeout

	# 7️⃣ Avisar a MatchSessionService que la escena está lista
	print("[GameMatch] ✅ GameMatch listo — iniciando primer turno...")
	MatchSessionService.on_gamematch_ready()
	if _replay_controls:
		_replay_controls.start()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _knight_controller and _knight_controller.is_selecting():
		_knight_controller.cancel_selection()
		get_viewport().set_input_as_handled()


# ============================================================================
# SETUP DE CONTROLADORES
# ============================================================================
func _setup_controllers() -> void:
	# Animador de reparto (PlayerHandController lo necesita)
	card_deal_animator = CardDealAnimator.new(CARD_DISPLAY_SCENE, player_hand, player_deck.global_position)
	add_child(card_deal_animator)

	# Manos
	player_hand_controller = PlayerHandController.new(player_hand, player_deck, card_deal_animator)
	opponent_hand_controller = OpponentHandController.new(opponent_hand_container, opponent_deck, self)

	# Campo
	_field_renderer = FieldRenderer.new(player_knight_slots_zone, opponent_knight_slots_zone)

	# Turno
	_turn_controller = TurnController.new(end_turn_button, player_panel, opponent_panel)
	_turn_controller.setup()

	# Acciones de caballeros
	_knight_controller = KnightActionController.new(player_knight_slots_zone, opponent_knight_slots_zone, self)
	_knight_controller.setup()

	# Resto del campo: fila de técnicas/objetos, ayudante, ocasión y escenario
	var player_support := _card_slots_in($RootColumns/CenterColumn/PlayerCardsZone/PlayerTechniques)
	var opponent_support := _card_slots_in($RootColumns/CenterColumn/OpponentCardsZone/OpponentTechniques/opTechniqueZone)
	var singles := {
		"player_helper": $RootColumns/RightColumn/PlayerAssist/plAssist,
		"opponent_helper": $RootColumns/RightColumn/OpponentAssist/opAssist,
		"player_occasion": $RootColumns/RightColumn/PlayerOcasion/plOcasion,
		"opponent_occasion": $RootColumns/RightColumn/OpponentOcasion/opOcasion,
		"scenario": $RootColumns/RightColumn/ScenarioZone/ScenarioSlot,
	}
	_field_renderer.set_support_slots(player_support, opponent_support, singles)
	_knight_controller.connect_play_slots(player_support + [singles.player_helper, singles.player_occasion, singles.scenario])

	# Tapete: detrás de las cartas (justo encima del fondo)
	_board_mat = BOARD_MAT_SCRIPT.new()
	add_child(_board_mat)
	move_child(_board_mat, $RootColumns.get_index())
	_board_mat.setup(
		[$RootColumns/CenterColumn/OpponentCardsZone/OpponentTechniques, opponent_knight_slots_zone],
		[player_knight_slots_zone, $RootColumns/CenterColumn/PlayerCardsZone/PlayerTechniques]
	)

	# Paneles de estado
	_status_controller = StatusPanelController.new(player_panel, opponent_panel, player_deck, opponent_deck, player_piles, opponent_piles)

	# Orquestador de animaciones
	var effects_mgr := MatchEffectsManager.new()
	add_child(effects_mgr)
	_orchestrator = AnimationOrchestrator.new()
	add_child(_orchestrator)
	_orchestrator.setup(
		player_hand_controller,
		opponent_hand_controller,
		_field_renderer,
		_status_controller,
		effects_mgr
	)

	print("[GameMatch] ✅ Todos los controladores configurados")


func _update_turn_banner() -> void:
	"""Rótulo de turno en el centro del tablero."""
	var gs := MatchSessionService.game_state
	if not _board_mat or not gs:
		return
	var round_text := "Ronda %d" % int(gs.current_turn)
	if MatchSessionService.is_replay:
		var who := int(gs.active_player_number)
		var player_name: String = str(MatchSessionService.current_match.get("player%d_name" % who, "Jugador %d" % who))
		_board_mat.set_turn("Turno de %s" % player_name, round_text, false)
	elif _turn_controller.is_local_player_turn():
		_board_mat.set_turn("Tu turno", round_text, true)
	else:
		_board_mat.set_turn("Turno del rival", round_text, false)


func _card_slots_in(container: Node) -> Array:
	"""CardSlots hijos directos de un contenedor, en orden (índice = posición en el servidor)."""
	var slots: Array = []
	if container:
		for child in container.get_children():
			if child is CardSlot:
				slots.append(child)
	return slots


# ============================================================================
# CALLBACKS DE MATCHSESSIONSERVICE
# ============================================================================
func _on_match_state_updated(_match_data: Dictionary) -> void:
	var gs := MatchSessionService.game_state
	# En una repetición el último fotograma se muestra en el tablero; ReplayControls indica el final
	if gs and str(gs.current_phase).to_lower() in ["game_over", "finished"] and not MatchSessionService.is_replay:
		_show_battle_summary(gs.winner_id)
		return
	await _render_from_match_state()
	_turn_controller.update_state()
	_update_turn_banner()
	# Si el servidor espera una elección del jugador (pending_selection), activarla
	_knight_controller.refresh_pending_selection(MatchSessionService.game_state)


func _on_phase_changed(phase: String) -> void:
	"""Reacción a cambio de fase. Sobreescribir en subclases para comportamiento específico."""
	_turn_controller.on_phase_changed(phase)


func _on_match_error_received(error_message: String) -> void:
	print("[GameMatch] ❌ Error del servidor: %s" % error_message)
	await _render_from_match_state()
	_knight_controller.on_action_rejected(MatchSessionService.game_state)


# ============================================================================
# RENDER (orquestación)
# ============================================================================
func _render_from_match_state() -> void:
	var gs := MatchSessionService.game_state
	var cm := MatchSessionService.current_match
	if not gs or not cm:
		_status_controller.render_fallback()
		return
	await _render_all(gs, cm)


func _render_all(gs: GameState, cm: Dictionary) -> void:
	# Detectar cambio de perspectiva (TEST match: END_TURN invierte perspectiva)
	if _last_player_number != 0 and gs.player_number != _last_player_number:
		print("[GameMatch] 🔄 Perspectiva %d → %d — reseteando controladores" % [_last_player_number, gs.player_number])
		player_hand_controller.reset()
		opponent_hand_controller.reset()
		_field_renderer.clear_all_slots(player_knight_slots_zone)
		_field_renderer.clear_all_slots(opponent_knight_slots_zone)
		_field_renderer.clear_support_slots()
		_orchestrator.reset_state()
	_last_player_number = gs.player_number

	# El fondo sigue al escenario en juego (o vuelve al cosmos base si no hay ninguno)
	battle_background.set_stage(gs.scenario)

	await _orchestrator.render_state(gs, cm)

# ============================================================================
# FIN DE PARTIDA
# ============================================================================
func _show_battle_summary(winner_id: String) -> void:
	print("[GameMatch] 🏁 Fin de partida — winner: %s" % winner_id)
	var local_id: String = MatchSessionService.game_state.player_id \
		if MatchSessionService.game_state else ""
	SceneTransition.set_pending_data({
		"won": winner_id != "" and winner_id == local_id,
		"winner_id": winner_id
	})
	SceneTransition.go_to_battle_summary()
