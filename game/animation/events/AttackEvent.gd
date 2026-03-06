# AttackEvent.gd
# Evento: animación de ataque entre dos caballeros en el campo.
# Usa MatchEffectsManager para spawnar el flash y el número de daño.
#
# El contexto exacto del ataque (tipo, técnica, evasión) llega via last_action
# del servidor. AnimationRegistry resuelve color/duración a partir de él.

class_name AttackEvent
extends AnimationEvent

var attacker_is_opponent: bool
var attacker_slot: int
var defender_is_opponent: bool
var defender_slot: int
var damage: int
var last_action: Dictionary  # contexto completo del servidor (enriquecido por StateDiffer)

func _init(
	p_attacker_is_opponent: bool,
	p_attacker_slot: int,
	p_defender_is_opponent: bool,
	p_defender_slot: int,
	p_damage: int,
	p_last_action: Dictionary = {}
) -> void:
	var atk_side := "opp" if p_attacker_is_opponent else "pl"
	var def_side := "opp" if p_defender_is_opponent else "pl"
	label = "Attack[%s%d→%s%d]" % [atk_side, p_attacker_slot, def_side, p_defender_slot]
	attacker_is_opponent = p_attacker_is_opponent
	attacker_slot = p_attacker_slot
	defender_is_opponent = p_defender_is_opponent
	defender_slot = p_defender_slot
	damage = p_damage
	last_action = p_last_action


func play(ctx: AnimationContext) -> void:
	if not ctx.effects_mgr:
		# Sin effects_mgr: esperar un frame para no romper el grupo paralelo
		await ctx.parent_node.get_tree().process_frame
		return
	var meta := AnimationRegistry.lookup(last_action)
	var color: Color  = meta.get("color",    Color.GOLD)
	var duration: float = meta.get("duration", 0.4)

	# defender_slot == -1 → ataque directo, burlar al panel del defensor
	var def_pos: Vector2
	if defender_slot >= 0:
		def_pos = ctx.field_renderer.get_slot_center(defender_is_opponent, defender_slot)
	else:
		# Posición aproximada del panel del jugador/oponente atacado
		def_pos = ctx.field_renderer.get_zone_center(defender_is_opponent)

	# Flash de impacto en el defensor
	ctx.effects_mgr.spawn_cosmos_burst(def_pos, color)
	# Número de daño flotante
	if ctx.effects_mgr.has_method("spawn_damage_number"):
		ctx.effects_mgr.spawn_damage_number(def_pos, damage)
	# Pausa configurable por tipo de ataque
	await ctx.parent_node.get_tree().create_timer(duration).timeout
