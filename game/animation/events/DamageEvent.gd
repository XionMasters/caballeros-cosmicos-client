# DamageEvent.gd
# Evento: mostrar daño recibido por un caballero en el campo.
# Generado desde engine_event DAMAGE_DEALT o DAMAGE_LETHAL.
#
# Efecto visual:
#   - Línea de ataque desde el atacante al defensor
#   - Número de daño flotante sobre el defensor
#   - Burst de color en la posición del defensor
#   - Screen shake en daño alto (>= 5)

class_name DamageEvent
extends AnimationEvent

var instance_id: String    # instance_id del defensor
var amount: int
var is_lethal: bool        # true → animación de muerte a continuación
var source_id: String      # instance_id del atacante (puede estar vacío)

func _init(
	p_instance_id: String,
	p_amount: int,
	p_is_lethal: bool = false,
	p_source_id: String = ""
) -> void:
	label = "Damage[%s -%d%s]" % [p_instance_id.left(8), p_amount, " LETHAL" if p_is_lethal else ""]
	instance_id = p_instance_id
	amount = p_amount
	is_lethal = p_is_lethal
	source_id = p_source_id


func play(ctx: AnimationContext) -> void:
	if not ctx.effects_mgr:
		await ctx.parent_node.get_tree().process_frame
		return

	# Resolver posición del defensor en pantalla
	var def_pos: Vector2 = _resolve_position(ctx, instance_id)
	var src_pos: Vector2 = _resolve_position(ctx, source_id) if not source_id.is_empty() else Vector2.ZERO

	# Línea de ataque si tenemos ambas posiciones
	if not source_id.is_empty() and src_pos != Vector2.ZERO and def_pos != Vector2.ZERO:
		ctx.effects_mgr.spawn_attack_line(src_pos, def_pos)

	# Flash de impacto en el defensor
	var color := Color.RED if is_lethal else Color.GOLD
	ctx.effects_mgr.spawn_cosmos_burst(def_pos, color)

	# Número de daño flotante
	if ctx.effects_mgr.has_method("spawn_damage_number"):
		ctx.effects_mgr.spawn_damage_number(def_pos, amount)

	# Shake en daño alto
	if amount >= 5 and ctx.effects_mgr.has_method("shake_camera"):
		ctx.effects_mgr.shake_camera(0.25, 12)
	elif is_lethal and ctx.effects_mgr.has_method("shake_camera"):
		ctx.effects_mgr.shake_camera(0.3, 16)

	var duration := 0.5 if is_lethal else 0.35
	await ctx.parent_node.get_tree().create_timer(duration).timeout


static func _resolve_position(ctx: AnimationContext, iid: String) -> Vector2:
	"""Busca la posición global del slot que contiene la carta con ese instance_id."""
	if iid.is_empty() or not ctx.field_renderer:
		return Vector2.ZERO
	return ctx.field_renderer.find_card_position(iid)
