## @brief Gestor centralizado de animaciones de cartas
## Separa lógica de animación de CardDisplay, permitiendo reutilización
##
## Uso:
##   var anim_mgr = CardAnimationManager.new()
##   anim_mgr.animate_card_play(card_display, destination_position)
##   anim_mgr.animate_card_hover(card_display, true)

class_name CardAnimationManager
extends Node

## Configuración de animaciones
var card_play_duration: float = 0.4
var card_hover_duration: float = 0.2
var card_flip_duration: float = 0.6
var card_draw_duration: float = 0.5

## Configuración de valores de animación
var hover_scale: float = 1.1
var hover_offset_y: float = -50.0
var card_rotation_amount: float = 2.0  # Para pequeña rotación

## Almacenar animaciones en progreso (para cancelar si es necesario)
var active_tweens: Dictionary = {}  # card_display → Tween


## Anima una carta cuando se juega (desaparece hacia el campo)
func animate_card_play(
	card_display: Control,
	destination: Vector2,
	duration: float = -1.0
) -> void:
	if not is_instance_valid(card_display):
		return
	
	var anim_duration = duration if duration > 0 else card_play_duration
	_cancel_existing_tween(card_display)
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Mover hacia destino
	tween.tween_property(card_display, "global_position", destination, anim_duration)
	
	# Desaparecer (fade out)
	tween.tween_property(card_display, "modulate:a", 0.7, anim_duration)
	
	# Escalar mientras se mueve
	tween.tween_property(card_display, "scale", Vector2(0.8, 0.8), anim_duration)
	
	_store_tween(card_display, tween)


## Anima el hover/unhover de una carta
func animate_card_hover(
	card_display: Control,
	is_hovering: bool,
	duration: float = -1.0
) -> void:
	if not is_instance_valid(card_display):
		return
	
	var anim_duration = duration if duration > 0 else card_hover_duration
	_cancel_existing_tween(card_display)
	
	var tween = create_tween()
	
	if is_hovering:
		# Elevar y escalar
		tween.tween_property(card_display, "position:y", card_display.position.y - hover_offset_y, anim_duration)
		tween.parallel().tween_property(card_display, "scale", Vector2(hover_scale, hover_scale), anim_duration)
	else:
		# Volver a posición original
		tween.tween_property(card_display, "position:y", card_display.position.y + hover_offset_y, anim_duration)
		tween.parallel().tween_property(card_display, "scale", Vector2.ONE, anim_duration)
	
	_store_tween(card_display, tween)


## Anima volteada de carta desde el mazo
func animate_flip_from_deck(
	card_display: Control,
	deck_position: Vector2,
	target_position: Vector2 = Vector2.ZERO,
	duration: float = -1.0
) -> void:
	if not is_instance_valid(card_display):
		return
	
	var anim_duration = duration if duration > 0 else card_flip_duration
	_cancel_existing_tween(card_display)
	
	# Si no hay posición objetivo, usar posición final
	var final_pos = target_position if target_position != Vector2.ZERO else card_display.position
	
	var tween = create_tween()
	
	# Posicionar en el mazo inicialmente
	card_display.global_position = deck_position
	card_display.scale = Vector2(0.1, 0.1)
	card_display.modulate.a = 0.3
	
	# Animar
	tween.tween_property(card_display, "global_position", final_pos, anim_duration)
	tween.parallel().tween_property(card_display, "scale", Vector2.ONE, anim_duration)
	tween.parallel().tween_property(card_display, "modulate:a", 1.0, anim_duration)
	
	_store_tween(card_display, tween)


## Anima descarte de carta (hacia descarte)
func animate_card_discard(
	card_display: Control,
	discard_position: Vector2,
	duration: float = -1.0
) -> void:
	if not is_instance_valid(card_display):
		return
	
	var anim_duration = duration if duration > 0 else card_play_duration
	_cancel_existing_tween(card_display)
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Rotación mientras cae
	tween.tween_property(card_display, "rotation", card_rotation_amount, anim_duration)
	
	# Movimiento al descarte
	tween.tween_property(card_display, "global_position", discard_position, anim_duration)
	
	# Fade out
	tween.tween_property(card_display, "modulate:a", 0.0, anim_duration)
	
	_store_tween(card_display, tween)


## Anima cambio de modo de batalla (defensa, evasión, etc)
func animate_mode_change(
	card_display: Control,
	new_mode: String,
	duration: float = -1.0
) -> void:
	if not is_instance_valid(card_display):
		return
	
	var anim_duration = duration if duration > 0 else card_hover_duration
	_cancel_existing_tween(card_display)
	
	var tween = create_tween()
	
	match new_mode:
		"defense":
			# Inclinar ligeramente
			tween.tween_property(card_display, "rotation", 0.15, anim_duration)
			tween.parallel().tween_property(card_display, "modulate", Color.GRAY, anim_duration)
		
		"evasion":
			# Escalar hacia arriba
			tween.tween_property(card_display, "scale", Vector2(1.15, 1.15), anim_duration)
			tween.parallel().tween_property(card_display, "modulate", Color.CYAN, anim_duration)
		
		"exhausted":
			# Desaturar
			tween.tween_property(card_display, "modulate", Color(0.5, 0.5, 0.5, 1.0), anim_duration)
		
		"normal":
			# Resetear visual
			tween.tween_property(card_display, "rotation", 0.0, anim_duration)
			tween.parallel().tween_property(card_display, "scale", Vector2.ONE, anim_duration)
			tween.parallel().tween_property(card_display, "modulate", Color.WHITE, anim_duration)
	
	_store_tween(card_display, tween)


## Anima pulso de ataque (cuando ataca)
func animate_attack_pulse(
	card_display: Control,
	target_position: Vector2 = Vector2.ZERO,
	duration: float = 0.4
) -> void:
	if not is_instance_valid(card_display):
		return
	
	_cancel_existing_tween(card_display)
	
	var tween = create_tween()
	
	# Escalar hacia arriba (ataque)
	tween.tween_property(card_display, "scale", Vector2(1.2, 1.2), duration * 0.5)
	
	# Volver a normal
	tween.tween_property(card_display, "scale", Vector2.ONE, duration * 0.5)
	
	# Si hay objetivo, hacer pequeño movimiento hacia él
	if target_position != Vector2.ZERO:
		var original_pos = card_display.global_position
		tween.set_parallel(true)
		tween.tween_property(card_display, "global_position", target_position, duration * 0.25)
		tween.tween_callback(func():
			card_display.global_position = original_pos
		)


## Anima daño recibido (parpadeo rojo)
func animate_take_damage(
	card_display: Control,
	duration: float = 0.3
) -> void:
	if not is_instance_valid(card_display):
		return
	
	_cancel_existing_tween(card_display)
	
	var tween = create_tween()
	
	# Parpadear rojo
	tween.tween_property(card_display, "modulate", Color.RED, duration * 0.25)
	tween.tween_property(card_display, "modulate", Color.WHITE, duration * 0.25)
	tween.tween_property(card_display, "modulate", Color.RED, duration * 0.25)
	tween.tween_property(card_display, "modulate", Color.WHITE, duration * 0.25)


## Anima eliminación de carta (desaparición)
func animate_card_removed(
	card_display: Control,
	duration: float = -1.0
) -> void:
	if not is_instance_valid(card_display):
		return
	
	var anim_duration = duration if duration > 0 else card_draw_duration
	_cancel_existing_tween(card_display)
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Escalar hacia cero
	tween.tween_property(card_display, "scale", Vector2.ZERO, anim_duration)
	
	# Fade out
	tween.tween_property(card_display, "modulate:a", 0.0, anim_duration)
	
	_store_tween(card_display, tween)


## Anima entrada múltiple de cartas (para inicial hand, etc)
func animate_batch_draw(
	card_displays: Array[Control],
	stagger_delay: float = 0.1
) -> void:
	var delay: float = 0.0
	
	for card_display in card_displays:
		if not is_instance_valid(card_display):
			continue
		
		# Crear pequeño delay progresivo
		if delay > 0:
			await get_tree().create_timer(stagger_delay).timeout
		
		animate_flip_from_deck(card_display, Vector2.ZERO, Vector2.ZERO, card_draw_duration)
		delay += stagger_delay


# ==================== MÉTODOS PRIVADOS ====================

## Cancela la tween anterior si existe
func _cancel_existing_tween(card_display: Control) -> void:
	if active_tweens.has(card_display) and is_instance_valid(active_tweens[card_display]):
		var tween = active_tweens[card_display]
		if tween.is_valid():
			tween.kill()
	active_tweens.erase(card_display)


## Almacena la tween para poder cancelarla después
func _store_tween(card_display: Control, tween: Tween) -> void:
	active_tweens[card_display] = tween


## Limpia tweens de cartas que ya no existen
func _cleanup_invalid_tweens() -> void:
	var to_remove: Array = []
	
	for card_display in active_tweens.keys():
		if not is_instance_valid(card_display):
			to_remove.append(card_display)
	
	for card_display in to_remove:
		active_tweens.erase(card_display)


func _process(_delta: float) -> void:
	# Limpiar tweens de cartas eliminadas cada frame
	if active_tweens.size() > 0:
		_cleanup_invalid_tweens()
