# KnightSummonedEvent.gd
# Evento: animación de convocación de un caballero al campo.
# Generado desde engine_event KNIGHT_SUMMONED.
#
# Casos:
#   from_zone == "yomotsu"  → Ikki Phoenix revive (efecto fuego/fénix)
#   from_zone == "deck"     → Shun desde mazo (efecto cadenas)
#   from_zone == "cositos"  → convocación normal desde cositos (efecto dorado)
#
# El campo se sincroniza DESPUÉS vía RenderFieldEvent.
# Este evento solo muestra la animación de entrada — no coloca la carta.

class_name KnightSummonedEvent
extends AnimationEvent

var instance_id: String
var card_code: String
var owner: int             # playerNumber (1 o 2)
var from_zone: String      # "yomotsu" | "deck" | "cositos"
var position: int

func _init(
	p_instance_id: String,
	p_card_code: String,
	p_owner: int,
	p_from_zone: String,
	p_position: int
) -> void:
	label = "KnightSummoned[%s from %s]" % [p_card_code, p_from_zone]
	instance_id = p_instance_id
	card_code = p_card_code
	owner = p_owner
	from_zone = p_from_zone
	position = p_position


func play(ctx: AnimationContext) -> void:
	if not ctx.effects_mgr:
		await ctx.parent_node.get_tree().process_frame
		return

	# Posición del slot destino
	var target_pos: Vector2 = Vector2.ZERO
	if ctx.field_renderer:
		# is_opponent: si el dueño es el rival desde la perspectiva del estado actual
		# Usamos find_slot_position que no requiere que la carta esté ahí todavía
		var is_opp: bool = (owner != ctx.player_number_hint)
		target_pos = ctx.field_renderer.get_slot_center(is_opp, position)

	# Efecto según zona de origen
	match from_zone:
		"yomotsu":
			# Fénix: burst naranja + flash global tenue
			if target_pos != Vector2.ZERO:
				ctx.effects_mgr.spawn_cosmos_burst(target_pos, Color(1.0, 0.4, 0.0))
			if ctx.effects_mgr.has_method("spawn_global_flash"):
				ctx.effects_mgr.spawn_global_flash(Color(1.0, 0.3, 0.0, 0.2))
			await ctx.parent_node.get_tree().create_timer(0.6).timeout
		"deck":
			# Cadenas de Andrómeda: burst plateado
			if target_pos != Vector2.ZERO:
				ctx.effects_mgr.spawn_cosmos_burst(target_pos, Color.SILVER)
			await ctx.parent_node.get_tree().create_timer(0.5).timeout
		_:
			# Convocación genérica: burst dorado
			if target_pos != Vector2.ZERO:
				ctx.effects_mgr.spawn_cosmos_burst(target_pos, Color.GOLD)
			await ctx.parent_node.get_tree().create_timer(0.4).timeout
