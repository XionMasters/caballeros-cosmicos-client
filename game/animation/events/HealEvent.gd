# HealEvent.gd
# Evento: mostrar curación recibida por un caballero.
# Generado desde engine_event HEAL_RECEIVED.
#
# Efecto visual:
#   - Burst verde en la posición de la carta
#   - Número "+N" flotante en verde

class_name HealEvent
extends AnimationEvent

var instance_id: String
var amount: int

func _init(p_instance_id: String, p_amount: int) -> void:
	label = "Heal[%s +%d]" % [p_instance_id.left(8), p_amount]
	instance_id = p_instance_id
	amount = p_amount


func play(ctx: AnimationContext) -> void:
	if not ctx.effects_mgr or not ctx.field_renderer:
		await ctx.parent_node.get_tree().process_frame
		return

	var pos: Vector2 = ctx.field_renderer.find_card_position(instance_id)
	if pos == Vector2.ZERO:
		await ctx.parent_node.get_tree().process_frame
		return

	ctx.effects_mgr.spawn_cosmos_burst(pos, Color.GREEN)

	# Número de curación flotante (reutilizamos spawn_damage_number con texto personalizado)
	if ctx.effects_mgr.has_method("spawn_heal_number"):
		ctx.effects_mgr.spawn_heal_number(pos, amount)
	elif ctx.effects_mgr.has_method("spawn_damage_number"):
		# Fallback: spawn_damage_number con cantidad negativa (muestra "- -N" visualmente,
		# hasta implementar spawn_heal_number propiamente)
		ctx.effects_mgr.spawn_damage_number(pos, -amount)

	await ctx.parent_node.get_tree().create_timer(0.4).timeout
