# AnimationEvent.gd
# Clase base para todos los eventos visuales de la cola de animaciones.
#
# Uso:
#   class MyEvent extends AnimationEvent:
#       func play(ctx: AnimationContext) -> void:
#           await ctx.player_hand_ctrl.do_something()
#
# Reglas:
#   - play() puede usar 'await' para animaciones async
#   - ctx da acceso a todos los sub-controladores
#   - label es sólo para debug/logs

class_name AnimationEvent
extends RefCounted

## Identificador legible para logs y debug
var label: String = "AnimationEvent"

## Override en subclases. Usar 'await' para animaciones asíncronas.
func play(ctx: AnimationContext) -> void:
	pass
