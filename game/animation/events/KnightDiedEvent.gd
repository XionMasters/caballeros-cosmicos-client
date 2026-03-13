# KnightDiedEvent.gd
# Evento: animación de muerte de un caballero.
# Generado desde engine_event KNIGHT_DIED.
#
# Efecto visual:
#   - Flash negro/gris expansivo en la posición del slot
#   - Fade-out y escala a 0 del nodo de carta (si existe)
#   - El campo se sincroniza después vía RenderFieldEvent

class_name KnightDiedEvent
extends AnimationEvent

var instance_id: String    # instance_id de la carta que muere
var card_code: String      # ej: "ikki_phoenix" (para efectos especiales futuros)
var owner: int             # 1 o 2

func _init(p_instance_id: String, p_card_code: String, p_owner: int) -> void:
	label = "KnightDied[%s]" % p_card_code
	instance_id = p_instance_id
	card_code = p_card_code
	owner = p_owner


func play(ctx: AnimationContext) -> void:
	if not ctx.effects_mgr or not ctx.field_renderer:
		await ctx.parent_node.get_tree().process_frame
		return

	var pos: Vector2 = ctx.field_renderer.find_card_position(instance_id)

	# Flash de muerte (oscuro, expansivo)
	if ctx.effects_mgr.has_method("spawn_death_flash"):
		ctx.effects_mgr.spawn_death_flash(pos)
	else:
		ctx.effects_mgr.spawn_cosmos_burst(pos, Color(0.3, 0.0, 0.0, 0.9))

	# Fade-out del nodo de carta físico en el slot
	var card_node: Control = ctx.field_renderer.find_card_node(instance_id)
	if card_node and is_instance_valid(card_node):
		var tween = ctx.parent_node.create_tween()
		tween.set_parallel(true)
		tween.tween_property(card_node, "modulate:a", 0.0, 0.4)
		tween.tween_property(card_node, "scale", Vector2(0.1, 0.1), 0.4)
		await tween.finished
	else:
		await ctx.parent_node.get_tree().create_timer(0.4).timeout
