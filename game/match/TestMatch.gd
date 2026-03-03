# TestMatch.gd
# Modo partida de prueba (solitario).
# Un solo jugador controla ambos lados — el rival no es humano.
#
# Diferencias respecto a PvPMatch:
#   · Al ser turno del rival (PLAYER2_TURN / OPPONENT_TURN) se muestran
#     sus cartas reales en lugar de dorsos, para poder jugar ambos lados.
#   · En el futuro: IA básica, replay, modo sandbox

class_name TestMatch
extends GameMatch


func _on_phase_changed(phase: String) -> void:
	"""En test, cuando es turno del rival mostramos sus cartas reales."""
	super._on_phase_changed(phase)  # Actualiza el botón de turno

	if phase == "PLAYER2_TURN" or phase == "OPPONENT_TURN":
		print("[TestMatch] 🧪 Turno del rival — mostrando cartas reales")
		if MatchSessionService.game_state:
			await opponent_hand_controller.update_from_state(MatchSessionService.game_state)
