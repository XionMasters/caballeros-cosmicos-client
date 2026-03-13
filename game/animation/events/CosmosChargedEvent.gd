# CosmosChargedEvent.gd
# Evento: animación de "Cargar Cosmo" (+CP al jugador).
# Generado desde engine_event COSMOS_CHARGED.
#
# Efecto visual:
#   - Burst azul en el panel del jugador que cargó
#   - Flash global tenue azul (cosmos = energía cósmica)

class_name CosmosChargedEvent
extends AnimationEvent

var player_number_owner: int   # 1 o 2 — quién cargó cosmo
var amount: int
var total_cosmos: int

func _init(p_player_number: int, p_amount: int, p_total: int) -> void:
	label = "CosmosCharged[P%d +%d → %d]" % [p_player_number, p_amount, p_total]
	player_number_owner = p_player_number
	amount = p_amount
	total_cosmos = p_total


func play(ctx: AnimationContext) -> void:
	if not ctx.effects_mgr:
		await ctx.parent_node.get_tree().process_frame
		return

	# Flash global azul tenue
	if ctx.effects_mgr.has_method("spawn_global_flash"):
		ctx.effects_mgr.spawn_global_flash(Color(0.2, 0.4, 1.0, 0.15))

	# Burst en el panel de estado del jugador correspondiente
	if ctx.status_ctrl and ctx.status_ctrl.has_method("get_panel_position"):
		var panel_pos: Vector2 = ctx.status_ctrl.get_panel_position(player_number_owner)
		if panel_pos != Vector2.ZERO:
			ctx.effects_mgr.spawn_cosmos_burst(panel_pos, Color(0.3, 0.5, 1.0))

	await ctx.parent_node.get_tree().create_timer(0.3).timeout
