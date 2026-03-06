# DrawCardsEvent.gd
# Evento: el jugador local roba carta(s).
# Delega en PlayerHandController que ya sabe si es reparto inicial o robo normal.

class_name DrawCardsEvent
extends AnimationEvent

var game_state: GameState

func _init(gs: GameState) -> void:
	label = "DrawCardsEvent"
	game_state = gs

func play(ctx: AnimationContext) -> void:
	await ctx.player_hand_ctrl.update_from_state(game_state)
