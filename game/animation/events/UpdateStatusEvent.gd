# UpdateStatusEvent.gd
# Evento: actualizar paneles de vida, cosmos, contadores de mazo y pilas.
# Síncrono — en el futuro puede animar el delta de vida con un tween de número.

class_name UpdateStatusEvent
extends AnimationEvent

var game_state: GameState
var match_data: Dictionary

func _init(gs: GameState, cm: Dictionary) -> void:
	label = "UpdateStatusEvent"
	game_state = gs
	match_data = cm

func play(ctx: AnimationContext) -> void:
	ctx.status_ctrl.render(game_state, match_data)
	# Síncrono por ahora
