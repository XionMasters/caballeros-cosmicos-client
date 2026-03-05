# StatusPanelController.gd
# Actualiza los paneles de estado (vida, cosmos, nombre) y los contadores de mazo.
# Lee IDs y nombres desde GameState + current_match dict.

class_name StatusPanelController
extends RefCounted

var _player_panel: PlayerStatusPanel
var _opponent_panel: PlayerStatusPanel
var _player_deck: DeckDisplay
var _opponent_deck: DeckDisplay
var _player_piles: PilesPanel
var _opponent_piles: PilesPanel


func _init(
	player_panel: PlayerStatusPanel,
	opponent_panel: PlayerStatusPanel,
	player_deck: DeckDisplay,
	opponent_deck: DeckDisplay,
	player_piles: PilesPanel = null,
	opponent_piles: PilesPanel = null
) -> void:
	_player_panel = player_panel
	_opponent_panel = opponent_panel
	_player_deck = player_deck
	_opponent_deck = opponent_deck
	_player_piles = player_piles
	_opponent_piles = opponent_piles


# ============================================================================
# API PÚBLICA
# ============================================================================

func render(game_state: GameState, current_match: Dictionary) -> void:
	"""Actualizar paneles y decks con los datos del estado actual."""
	var pn := game_state.player_number
	var opp := 3 - pn

	var player_id := game_state.player_id
	if player_id.is_empty():
		player_id = AuthManager.get_user_id()
		print("[StatusPanelController] ⚠️ player_id vacío, usando AuthManager: %s" % player_id)

	var opponent_id := game_state.opponent_id
	if opponent_id.is_empty():
		print("[StatusPanelController] ⚠️ opponent_id vacío")

	var player_name: String = current_match.get("player%d_name" % pn, "Jugador")
	var opponent_name: String = current_match.get("player%d_name" % opp, "Oponente")

	_player_panel.setup(
		player_name,
		game_state.get_player_life(pn),
		game_state.get_player_cosmos(pn),
		player_id
	)
	_opponent_panel.setup(
		opponent_name,
		game_state.get_player_life(opp),
		game_state.get_player_cosmos(opp),
		opponent_id
	)

	_player_deck.setup(game_state.player_deck_count, player_id)
	_opponent_deck.setup(game_state.opponent_deck_count, opponent_id)

	if _player_piles:
		_player_piles.update_yomotsu(game_state.player_graveyard_count)
	if _opponent_piles:
		_opponent_piles.update_yomotsu(game_state.opponent_graveyard_count)


func render_fallback() -> void:
	"""Renderización mínima para el editor o cuando no hay datos de match."""
	_player_panel.setup("Tú", 12, 1, "")
	_opponent_panel.setup("Rival", 12, 0, "")
