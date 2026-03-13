# CardPlayedEvent.gd
# Evento: animación de una carta jugada desde la mano al campo.
# Generado desde engine_event CARD_PLAYED.
#
# Efecto visual: burst de color según tipo de carta en la posición del slot destino.

class_name CardPlayedEvent
extends AnimationEvent

var instance_id: String    # instance_id de la CartInPlay
var zone: String           # zona destino: "field_knight", "field_support", etc.
var position: int

func _init(p_instance_id: String, p_zone: String, p_position: int) -> void:
	label = "CardPlayed[%s → %s:%d]" % [p_instance_id.left(8), p_zone, p_position]
	instance_id = p_instance_id
	zone = p_zone
	position = p_position


func play(ctx: AnimationContext) -> void:
	if not ctx.effects_mgr or not ctx.field_renderer:
		await ctx.parent_node.get_tree().process_frame
		return

	# Posición del slot destino (la carta ya debería estar ahí post-RenderField,
	# pero CARD_PLAYED corre ANTES de RenderFieldEvent para marcar la llegada)
	var target_pos: Vector2 = ctx.field_renderer.find_card_position(instance_id)
	if target_pos == Vector2.ZERO:
		# Fallback: usar centro del slot por zona + posición
		var is_opp := false  # siempre el jugador activo juega su propia carta
		target_pos = ctx.field_renderer.get_slot_center(is_opp, position)

	# Color según tipo de zona
	var color := Color.GOLD
	match zone:
		"field_support": color = Color.SKY_BLUE
		"field_helper":  color = Color.GREEN
		"field_occasion": color = Color.PURPLE
		"field_scenario": color = Color.WHITE

	ctx.effects_mgr.play_card_effect(target_pos, _zone_to_card_type(zone))

	await ctx.parent_node.get_tree().create_timer(0.35).timeout


static func _zone_to_card_type(z: String) -> String:
	match z:
		"field_knight":   return "knight"
		"field_support":  return "tecnica"
		"field_helper":   return "ayudante"
		"field_occasion": return "ocasion"
		"field_scenario": return "escenario"
		_:                return "knight"
