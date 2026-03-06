# RenderFieldEvent.gd
# Evento: sincronizar el campo (slots de caballeros) con el GameState actual.
# FieldRenderer es síncrono por ahora — en el futuro puede tener tweens de
# entrada/salida de cartas al campo.

class_name RenderFieldEvent
extends AnimationEvent

var game_state: GameState

func _init(gs: GameState) -> void:
	label = "RenderFieldEvent"
	game_state = gs

func play(ctx: AnimationContext) -> void:
	ctx.field_renderer.render_field(game_state)
	# Síncrono por ahora — agregar await + tween cuando tenga animación de entrada
