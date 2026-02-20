# CombatAnimator.gd
# Coordinador visual de animaciones de combate (SINGLETON/STATIC)
extends Node
class_name CombatAnimator

# =============================================
# CONFIG
# =============================================
const ATTACK_DASH_TIME := 0.18
const ATTACK_RETURN_TIME := 0.14
const ATTACK_OFFSET := 40

var effects: MatchEffectsManager = null

func _ready():
	# Buscar el EffectsManager automáticamente
	effects = get_tree().get_first_node_in_group("effects_manager")


# =============================================
# DAMAGE / HEAL FLOATING TEXT
# =============================================
func show_damage(card_display: Control, amount: int, is_heal := false):
	if not effects:
		return
	
	var pos = card_display.global_position + card_display.size * 0.5
	pos = effects._to_canvas_position(pos)   # convertir a coords UI
	
	effects.spawn_damage_number(pos, amount * (1 if not is_heal else -1))


# =============================================
# SIMPLE FLASH ON CARD
# =============================================
func play_flash(card_display: Control):
	if not effects:
		return
	
	var _pos = card_display.global_position + card_display.size * 0.5
	effects.spawn_global_flash(Color(1,1,1,0.35))


# =============================================
# MAIN ATTACK ANIMATION (PRO)
# =============================================
func animate_attack(attacker: Control, target: Control):
	if not attacker or not target:
		return

	if not effects:
		return

	# ==========================================
	# Preparar posiciones convertidas
	# ==========================================
	var atk_pos = attacker.global_position + attacker.size * 0.5
	var tgt_pos = target.global_position + target.size * 0.5

	atk_pos = effects._to_canvas_position(atk_pos)
	tgt_pos = effects._to_canvas_position(tgt_pos)

	# ==========================================
	# Crear imagen clon del atacante (no mover el original)
	# ==========================================
	var clone := attacker.duplicate()
	clone.modulate = Color(1,1,1,0.9)
	clone.scale = attacker.scale
	clone.position = atk_pos
	clone.pivot_offset = attacker.size * 0.5
	effects.effects_root.add_child(clone)

	# ==========================================
	# Animación del dash hacia el objetivo
	# ==========================================
	var dir = (tgt_pos - atk_pos).normalized()
	var dash_pos = atk_pos + dir * ATTACK_OFFSET

	var tween = clone.create_tween()

	# Dash
	tween.tween_property(clone, "position", dash_pos, ATTACK_DASH_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Impacto visual
	tween.tween_callback(func ():
		effects.play_attack_effect(atk_pos, tgt_pos, 0)
	)

	# Regreso
	tween.tween_property(clone, "position", atk_pos, ATTACK_RETURN_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Desaparecer
	tween.tween_property(clone, "modulate:a", 0.0, 0.15)

	tween.finished.connect(func ():
		clone.queue_free())


# =============================================
# ATTACK + DAMAGE (wrapper)
# =============================================
func animate_attack_and_damage(attacker: Control, target: Control, dmg: int):
	animate_attack(attacker, target)
	show_damage(target, dmg)
	play_flash(target)
