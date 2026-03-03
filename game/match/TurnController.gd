# TurnController.gd
# Maneja el botón End Turn, el estado de turno y los indicadores visuales.
# Llama a MatchSessionService directamente (singleton global).

class_name TurnController
extends RefCounted

var _button: Button
var _player_panel: PlayerStatusPanel
var _opponent_panel: PlayerStatusPanel


func _init(button: Button, player_panel: PlayerStatusPanel, opponent_panel: PlayerStatusPanel) -> void:
	_button = button
	_player_panel = player_panel
	_opponent_panel = opponent_panel


# ============================================================================
# API PÚBLICA
# ============================================================================

func setup() -> void:
	"""Conectar el botón y cargar su imagen. Llamar una sola vez en _ready."""
	if not _button:
		print("[TurnController] ❌ end_turn_button es NULL")
		return

	_button.pressed.connect(_on_end_turn_pressed)

	var img_path := "res://assets/ui-icons/end_turn_button.png"
	if ResourceLoader.exists(img_path):
		var tex := load(img_path) as Texture2D
		if tex:
			_button.icon = tex
			_button.text = ""
		else:
			_button.text = "▶"
	else:
		_button.text = "▶"

	update_state()
	print("[TurnController] ✅ End Turn configurado")


func update_state() -> void:
	"""Habilitar/deshabilitar el botón según si es turno del jugador local."""
	if not _button:
		return
	var my_turn := is_local_player_turn()
	_button.disabled = not my_turn
	_update_turn_indicator(my_turn)

	var phase_dbg := str(MatchSessionService.game_state.current_phase) \
		if MatchSessionService.game_state else "?"
	var cur_pl_dbg := str(MatchSessionService.current_match.get("current_player", "?")) \
		if MatchSessionService.current_match else "?"
	print("[TurnController] 🔘 habilitado=%s | phase=%s | current_player=%s" % [
		my_turn, phase_dbg, cur_pl_dbg
	])


func on_phase_changed(phase: String) -> void:
	"""Callback desde GameMatch cuando MatchSessionService emite phase_changed."""
	print("[TurnController] 📊 Fase: %s" % phase)
	update_state()


func is_local_player_turn() -> bool:
	"""Determina de forma robusta si es turno del jugador local."""
	if not MatchSessionService.game_state:
		return false
	var gs := MatchSessionService.game_state
	var pn := int(gs.player_number)
	var ph := str(gs.current_phase).to_lower()

	match ph:
		"player1_turn": return pn == 1
		"player2_turn": return pn == 2
		"my_turn":      return true
		"opponent_turn": return false

	var cm := MatchSessionService.current_match
	if cm and cm.has("current_player"):
		return int(cm["current_player"]) == pn
	return false


# ============================================================================
# INTERNOS
# ============================================================================

func _update_turn_indicator(is_my_turn: bool) -> void:
	if _player_panel:
		_player_panel.set_active_turn(is_my_turn)
	if _opponent_panel:
		_opponent_panel.set_active_turn(not is_my_turn)


func _on_end_turn_pressed() -> void:
	print("[TurnController] 🎯 End Turn presionado")
	if not MatchSessionService.is_in_match:
		print("[TurnController] ⚠️ No hay match activa"); return
	if not MatchSessionService.current_match:
		print("[TurnController] ⚠️ current_match es NULL"); return
	var match_id: String = MatchSessionService.current_match.get("id", "")
	if match_id.is_empty():
		print("[TurnController] ⚠️ Match ID vacío"); return

	_button.disabled = true
	MatchSessionService.end_turn()
