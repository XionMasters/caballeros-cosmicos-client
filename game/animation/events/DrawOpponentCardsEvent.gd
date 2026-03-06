# DrawOpponentCardsEvent.gd
# Evento: el oponente roba carta(s) (sólo se ven los dorsos).
# Delega en OpponentHandController que ya sabe si es reparto inicial o robo normal.

class_name DrawOpponentCardsEvent
extends AnimationEvent

var game_state: GameState

func _init(gs: GameState) -> void:
	label = "DrawOpponentCardsEvent"
	game_state = gs

func play(ctx: AnimationContext) -> void:
	await ctx.opponent_hand_ctrl.update_from_state(game_state)
