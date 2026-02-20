# CardDealAnimator.gd
# Anima las cartas iniciales del mazo a la mano
# Responsabilidad única: hacer la animación de robo visual

class_name CardDealAnimator
extends Node

# ============================================================================
# REFERENCIAS
# ============================================================================
var card_display_template: PackedScene = null
var target_hand: Control = null  # HandLayout (must extend CardCollection)
var deck_position: Vector2 = Vector2.ZERO

# ============================================================================
# CONFIGURACIÓN
# ============================================================================
var card_scale: Vector2 = Vector2.ZERO  # Se inicializa en _ready() o constructor
var deal_duration: float = 0.5
var delay_between_cards: float = 0.15
var target_scale: Vector2 = Vector2.ZERO  # Se inicializa en _ready() o constructor

# ============================================================================
# CONSTRUCTOR
# ============================================================================
func _init(p_card_template: PackedScene, p_hand: Control, p_deck_pos: Vector2) -> void:
	card_display_template = p_card_template
	target_hand = p_hand
	deck_position = p_deck_pos


# ============================================================================
# LIFECYCLE
# ============================================================================
func _ready() -> void:
	"""Inicializar escalas desde CardSizeConfig (autoload)"""
	if CardSizeConfig:
		# CardSizeConfig retorna tamaños absolutos en píxeles
		# Convertir a escalas relativas (base = 120x168)
		var deck_size = CardSizeConfig.get_deck_card_size()
		var hand_size = CardSizeConfig.get_hand_card_size()
		var base_size = Vector2(120, 168)  # Tamaño base de CardDisplay
		
		# Calcular escalas dividiendo tamaño por base
		if deck_size != Vector2.ZERO:
			card_scale = deck_size / base_size
		else:
			card_scale = Vector2(0.7, 0.7)  # Fallback
		
		if hand_size != Vector2.ZERO:
			target_scale = hand_size / base_size
		else:
			target_scale = Vector2.ONE  # Fallback
		
		print("[CardDealAnimator] 🎯 Escalas calculadas: deck=%.2fx%.2f → hand=%.2fx%.2f" % [card_scale.x, card_scale.y, target_scale.x, target_scale.y])
	else:
		card_scale = Vector2(0.7, 0.7)
		target_scale = Vector2.ONE
		print("[CardDealAnimator] ⚠️ CardSizeConfig no disponible, usando fallback")


# ============================================================================
# MAIN API
# ============================================================================

func deal_cards_to_hand(cards: Array[CardInstance], starting_delay: float = 0.0) -> void:
	"""Animar cartas desde el mazo a la mano
	
	Args:
		cards: Array de CardInstance a animar
		starting_delay: Esperar este tiempo antes de empezar
	"""
	if not card_display_template or not target_hand:
		push_error("[CardDealAnimator] Configuración incompleta")
		return
	
	print("[CardDealAnimator] 🎴 Robando %d cartas..." % cards.size())
	
	# Esperar delay inicial si es necesario
	if starting_delay > 0:
		await get_tree().create_timer(starting_delay).timeout
	
	# Animar cada carta con delay
	for i in range(cards.size()):
		var card_instance = cards[i]
		# Increment pending counter BEFORE animating
		if target_hand.has_method("_increment_pending_dealt"):
			target_hand._increment_pending_dealt()
		
		# Get target position from layout BEFORE animating
		var target_slot_pos = target_hand.get_next_dealt_card_position()
		
		# Wait for delay BEFORE starting animation (except first card)
		if i > 0:
			await get_tree().create_timer(delay_between_cards).timeout
		
		# Start animation and wait for it to complete
		await _deal_single_card_async(card_instance, i, target_slot_pos)
	
	print("[CardDealAnimator] ✅ Robo completado!")


# ============================================================================
# HELPERS
# ============================================================================

func _deal_single_card_async(card_instance: CardInstance, index: int, target_slot_pos: Vector2) -> void:
	"""Animar una sola carta directo al slot final (sin saltos)"""
	# Crear CardDisplay
	var card_display = card_display_template.instantiate()
	card_display.setup(card_instance.base_data)
	card_display.bind_instance(card_instance)
	
	# Inicializar estado visual
	card_display.global_position = deck_position
	card_display.scale = card_scale
	card_display.modulate.a = 0.0  # Start invisible
	
	# Agregar al árbol de nodos (temporalmente fuera del layout para animar)
	get_parent().add_child(card_display)
	
	# Animar directo al slot final (calculado por HandLayout)
	await _animate_card_deal(card_display, target_slot_pos)
	
	# Reparentear a la mano usando método público si existe
	if target_hand.has_method("add_dealt_card"):
		target_hand.add_dealt_card(card_display)
		# Decrement pending counter AFTER card is added
		if target_hand.has_method("_decrement_pending_dealt"):
			target_hand._decrement_pending_dealt()
	else:
		# Fallback: usar add_card si es CardCollection
		if target_hand is CardCollection:
			target_hand.add_card(card_display)
			# NO hacer reparent aquí - add_card() ya lo hace
			push_error("[CardDealAnimator] target_hand no es CardCollection")
			return
	
	card_display.scale = target_scale
	
	print("[CardDealAnimator] ✅ Carta %d robada" % (index + 1))


func _animate_card_deal(card_display: Control, target_pos: Vector2) -> void:
	"""Ejecutar tween de animación y esperar a que termine"""
	var tween = create_tween()
	tween.set_parallel(true)
	card_display.set_meta("deal_tween", tween)  # Store for cancellation if needed
	
	# Mover desde mazo a posición media
	tween.tween_property(
		card_display,
		"global_position",
		target_pos,
		deal_duration
	)
	
	# Crecer de tamaño
	tween.tween_property(
		card_display,
		"scale",
		target_scale,
		deal_duration
	)
	
	# Aparición suave
	tween.tween_property(
		card_display,
		"modulate:a",
		1.0,
		deal_duration
	)
	
	# Esperar a que termine
	await tween.finished
