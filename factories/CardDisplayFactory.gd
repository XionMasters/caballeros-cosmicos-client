## @brief Factory pattern para crear y configurar CardDisplay instancias
## Elimina duplicación de código en GameBoard y TestBoard
## 
## Uso:
##   var card_display = CardDisplayFactory.create_from_instance(card_instance, CARD_SCENE)
##   hand_layout.add_card(card_display)

class_name CardDisplayFactory
extends Node

## Escena template de CardDisplay
var card_display_scene: PackedScene = null
var card_back_scene: PackedScene = null

## Configuración de animación por defecto
var animation_duration: float = 0.6
var animate_from_deck: bool = true

func _init(p_card_scene: PackedScene, p_card_back_scene: PackedScene = null) -> void:
	card_display_scene = p_card_scene
	card_back_scene = p_card_back_scene


## Crea una CardDisplay desde un CardInstance
## Retorna: CardDisplay configurado y listo para agregar a la escena
func create_from_instance(
	card_instance: CardInstance,
	start_position: Vector2 = Vector2.ZERO,
	animate: bool = true
) -> Control:
	if not card_display_scene:
		push_error("CardDisplayFactory: card_display_scene no configurada")
		return Control.new()
	
	var card_display = card_display_scene.instantiate()
	
	# Configurar datos de la carta
	card_display.setup_from_instance(card_instance)
	
	# Configurar posición inicial
	if start_position != Vector2.ZERO:
		card_display.global_position = start_position
	
	# Almacenar la instancia en metadata
	card_display.set_meta("card_instance", card_instance)
	card_display.set_meta("instance_id", card_instance.instance_id)
	
	# Agregar card back visual
	if card_back_scene:
		_add_card_back(card_display)
	
	# Aplicar animaciones si se requiere
	if animate and start_position != Vector2.ZERO:
		_apply_animation(card_display, start_position)
	
	return card_display


## Crea una CardDisplay con animación desde el mazo
## Parámetro deck_position: Posición global del mazo en pantalla
func create_with_deck_animation(
	card_instance: CardInstance,
	deck_position: Vector2,
	animation_delay: float = 0.0
) -> Control:
	var card_display = create_from_instance(card_instance, deck_position, false)
	
	# Agregar delay si es necesario
	if animation_delay > 0:
		await get_tree().create_timer(animation_delay).timeout
	
	# Animar volteada desde el mazo
	if card_display.has_method("animate_flip_from_deck"):
		card_display.animate_flip_from_deck(deck_position, animation_duration)
	
	return card_display


## Crea múltiples CardDisplay desde un array de CardInstance
func create_batch(
	card_instances: Array[CardInstance],
	stagger_animation: bool = false
) -> Array[Control]:
	var results: Array[Control] = []
	var delay: float = 0.0
	
	for card_instance in card_instances:
		var card_display: Control
		
		if stagger_animation:
			# Crear con delay progresivo
			card_display = await create_with_deck_animation(card_instance, Vector2.ZERO, delay)
			delay += 0.1  # 100ms entre cada carta
		else:
			card_display = create_from_instance(card_instance, Vector2.ZERO, false)
		
		results.append(card_display)
	
	return results


## Crea una CardDisplay a partir de CardData (sin instancia en juego)
## Útil para browsear cartas, colección, etc
func create_from_data(
	card_data: CardData,
	preview_mode: bool = true
) -> Control:
	if not card_display_scene:
		push_error("CardDisplayFactory: card_display_scene no configurada")
		return Control.new()
	
	var card_display = card_display_scene.instantiate()
	
	# Para preview, crear CardInstance temporal
	var temp_instance = CardInstance.new()
	temp_instance.base_data = card_data
	temp_instance.instance_id = card_data.id  # Usar card_id como instance_id para preview
	temp_instance.mode = "normal"
	temp_instance.is_exhausted = false
	
	card_display.setup_from_instance(temp_instance)
	
	if card_back_scene:
		_add_card_back(card_display)
	
	# Marcar como preview
	if preview_mode:
		card_display.set_meta("is_preview", true)
	
	return card_display


## Reset de una CartaDisplay existente
## Útil para reutilizar CardDisplay en pools
func reset_card_display(card_display: Control) -> void:
	if not card_display.has_method("reset"):
		return
	
	card_display.reset()
	card_display.set_meta("card_instance", null)
	card_display.set_meta("instance_id", "")


# ==================== MÉTODOS PRIVADOS ====================

## Agrega el visual del card back a la CardDisplay
func _add_card_back(card_display: Control) -> void:
	if not card_back_scene or not card_display.has_method("add_child"):
		return
	
	var card_back = card_back_scene.instantiate()
	card_display.add_child(card_back)
	
	# Posicionar detrás de la carta
	if card_display.has_method("move_child"):
		card_display.move_child(card_back, 0)


## Aplica animación de entrada a la CartaDisplay
func _apply_animation(card_display: Control, from_position: Vector2) -> void:
	if not card_display.has_method("animate_from_position"):
		return
	
	card_display.animate_from_position(from_position, animation_duration)
