# OpponentCardDealAnimator.gd
# Anima los dorsos de cartas del oponente desde el mazo a la mano
# Similar a CardDealAnimator pero solo usa CardBack.tscn

class_name OpponentCardDealAnimator
extends Node

# ============================================================================
# RECURSOS PRECARGADOS
# ============================================================================
# Ninguno - obtendremos la textura desde opponent_deck

# ============================================================================
# REFERENCIAS
# ============================================================================
var card_back_template: PackedScene = null
var target_hand: Control = null  # HandLayout (must extend CardCollection)
var deck_position: Vector2 = Vector2.ZERO
var parent_node: Node = null  # Para acceso a get_tree()
var opponent_deck: DeckDisplay = null  # Para obtener la textura del dorso

# ============================================================================
# CONFIGURACIÓN
# ============================================================================
var card_scale: Vector2 = Vector2.ZERO
var deal_duration: float = 0.5
var delay_between_cards: float = 0.15
var target_scale: Vector2 = Vector2.ZERO

# ============================================================================
# CONSTRUCTOR
# ============================================================================
func _init(p_card_back_template: PackedScene, p_hand: Control, p_deck_pos: Vector2, p_parent: Node, p_opponent_deck: DeckDisplay) -> void:
	card_back_template = p_card_back_template
	target_hand = p_hand
	deck_position = p_deck_pos
	parent_node = p_parent
	opponent_deck = p_opponent_deck  # Guardar la referencia
	
	# IMPORTANTE: Llamar a _initialize_scales aquí porque _ready() NO se ejecuta
	# (OpponentCardDealAnimator no está en el scene tree)
	_initialize_scales()


# ============================================================================
# LIFECYCLE
# ============================================================================
func _ready() -> void:
	"""Nunca se ejecuta porque no está en scene tree, pero se mantiene por compatibilidad"""
	_initialize_scales()


func _initialize_scales() -> void:
	"""Inicializar escalas desde CardSizeConfig"""
	if CardSizeConfig:
		var deck_size = CardSizeConfig.get_deck_card_size()
		var hand_size = CardSizeConfig.get_hand_card_size()
		var base_size = Vector2(120, 168)
		
		if deck_size != Vector2.ZERO:
			card_scale = deck_size / base_size
		else:
			card_scale = Vector2(0.7, 0.7)
		
		if hand_size != Vector2.ZERO:
			target_scale = hand_size / base_size
		else:
			target_scale = Vector2.ONE
		
		print("[OpponentCardDealAnimator] 🎯 Escalas inicializadas: deck=%.2fx%.2f → hand=%.2fx%.2f" % [card_scale.x, card_scale.y, target_scale.x, target_scale.y])
	else:
		card_scale = Vector2(0.7, 0.7)
		target_scale = Vector2.ONE
		print("[OpponentCardDealAnimator] ⚠️ CardSizeConfig no disponible, usando fallback")


# ============================================================================
# MAIN API
# ============================================================================
func deal_cards_to_hand(count: int, starting_delay: float = 0.0) -> void:
	"""Animar dorsos de cartas desde el mazo a la mano del oponente
	
	Args:
		count: Cantidad de dorsos a animar
		starting_delay: Esperar este tiempo antes de empezar
	"""
	if not card_back_template or not target_hand or not parent_node:
		push_error("[OpponentCardDealAnimator] Configuración incompleta")
		return
	
	print("[OpponentCardDealAnimator] 🎴 Robando %d cartas (dorsos)..." % count)
	
	# Esperar delay inicial (usar parent_node para acceso a get_tree)
	if starting_delay > 0:
		await parent_node.get_tree().create_timer(starting_delay).timeout
	
	# Animar cada dorso
	for i in range(count):
		# Esperar delay entre cartas
		if i > 0:
			await parent_node.get_tree().create_timer(delay_between_cards).timeout
		
		# Animar un dorso
		await _deal_single_card_back_async(i)
	
	print("[OpponentCardDealAnimator] ✅ Robo de dorsos completado!")


# ============================================================================
# HELPERS
# ============================================================================
func _deal_single_card_back_async(index: int) -> void:
	"""Animar un dorso de carta desde el mazo a la mano"""
	print("[OpponentCardDealAnimator] 🔄 Iniciando dorso %d..." % (index + 1))
	
	# Crear CardBack
	var card_back = card_back_template.instantiate()
	print("[OpponentCardDealAnimator] ✅ CardBack instanciado")
	
	# IMPORTANTE: Cargar y asignar la textura del dorso
	_assign_card_back_texture(card_back)
	
	# Inicializar estado visual
	card_back.global_position = deck_position
	card_back.scale = card_scale
	card_back.modulate.a = 0.0
	
	# Obtener posición destino
	print("[OpponentCardDealAnimator] 📍 Obteniendo posición destino...")
	var target_slot_pos = target_hand.get_next_dealt_card_position()
	print("[OpponentCardDealAnimator] 📍 Posición destino: %s" % target_slot_pos)
	
	# Agregar al árbol temporalmente
	parent_node.add_child(card_back)
	print("[OpponentCardDealAnimator] 🌳 CardBack agregado al árbol")
	
	# Animar
	print("[OpponentCardDealAnimator] 🎬 Iniciando animación...")
	await _animate_card_deal(card_back, target_slot_pos)
	print("[OpponentCardDealAnimator] ✨ Animación completada")
	
	# Agregar a la mano
	print("[OpponentCardDealAnimator] 🤝 Agregando a mano...")
	if target_hand is CardCollection:
		target_hand.add_card(card_back)
		print("[OpponentCardDealAnimator] ✅ CardBack agregado a mano")
		var parent_name: String = card_back.get_parent().name if card_back.get_parent() else "NONE"
		print("[OpponentCardDealAnimator] 📊 CardBack final - pos: %s, size: %s, scale: %s, visible: %s, parent: %s" % [
			card_back.global_position,
			card_back.size,
			card_back.scale,
			card_back.visible,
			parent_name
		])
	else:
		push_error("[OpponentCardDealAnimator] target_hand no es CardCollection, es: %s" % target_hand.get_class())
		return
	
	card_back.scale = target_scale
	print("[OpponentCardDealAnimator] 📊 CardBack después rescale - scale: %s" % card_back.scale)
	
	print("[OpponentCardDealAnimator] ✅ Dorso %d robado" % (index + 1))


func _animate_card_deal(card_back: Control, target_pos: Vector2) -> void:
	"""Ejecutar tween de animación y esperar"""
	var tween = parent_node.create_tween()
	tween.set_parallel(true)
	
	# Mover
	tween.tween_property(
		card_back,
		"global_position",
		target_pos,
		deal_duration
	)
	
	# Crecer
	tween.tween_property(
		card_back,
		"scale",
		target_scale,
		deal_duration
	)
	
	# Aparición
	tween.tween_property(
		card_back,
		"modulate:a",
		1.0,
		deal_duration
	)
	
	await tween.finished


func _assign_card_back_texture(card_back: CardBack) -> void:
	"""Obtener y asignar la textura del dorso desde opponent_deck"""
	if opponent_deck:
		# Esperar hasta que la textura esté cargada (máx 3 segundos)
		var max_wait = 30
		var wait_count = 0
		
		while opponent_deck.get_back_texture() == null and wait_count < max_wait:
			var timer = parent_node.get_tree().create_timer(0.1)
			await timer.timeout
			wait_count += 1
			if wait_count % 10 == 0:
				print("[OpponentCardDealAnimator] ⏳ Esperando textura del dorso (%d x 0.1s)..." % wait_count)
		
		if opponent_deck.get_back_texture():
			var texture = opponent_deck.get_back_texture()
			card_back.set_back_texture(texture)
			print("[OpponentCardDealAnimator] 🖼️ Textura del dorso asignada desde opponent_deck")
		else:
			print("[OpponentCardDealAnimator] ⚠️ Timeout esperando textura, usando fallback")
	else:
		print("[OpponentCardDealAnimator] ⚠️ No hay opponent_deck disponible")
