# PlayerHandController.gd
# Controlador de la mano del jugador
# Responsabilidades:
# 1. Decidir: mano vacía vs render directo
# 2. Decidir: reparto inicial vs robo normal
# 3. Animar robos usando CardDealAnimator
# 4. Mantener estado local de la mano

extends Node
class_name PlayerHandController

# ============================================================================
# REFERENCIAS
# ============================================================================
var hand_layout: HandLayout
var deck_display: DeckDisplay
var card_deal_animator: CardDealAnimator

# ============================================================================
# ESTADO LOCAL
# ============================================================================
var last_hand_size: int = 0
var initialized: bool = false
var initial_deal_done: bool = false

# ============================================================================
# INICIALIZACIÓN
# ============================================================================
func _init(
	p_hand: HandLayout,
	p_deck: DeckDisplay,
	p_animator: CardDealAnimator
):
	hand_layout = p_hand
	deck_display = p_deck
	card_deal_animator = p_animator

# ============================================================================
# MAIN ENTRY POINT
# ============================================================================
func update_from_state(game_state: GameState):
	"""Punto de entrada único desde GameMatch"""
	
	# PRIMERA VEZ: decidir si reparto inicial o render directo
	if not initialized:
		await _initialize_hand(game_state)
		initialized = true
		# Asegurarse de que last_hand_size está actualizado después de init
		last_hand_size = game_state.player_hand.size()
		return
	
	# POSTERIORES: detectar y animar robos
	if game_state.player_hand.size() > last_hand_size:
		var new_cards = _extract_new_cards(game_state)
		print("[PlayerHandController] 🎴 Detectado robo de %d cartas" % new_cards.size())
		
		# Animar robo
		await card_deal_animator.deal_cards_to_hand(new_cards)
	
	# Renderizar estado final (sin animaciones)
	_render_hand_state(game_state)
	
	# ⚠️ IMPORTANTE: Actualizar contador DESPUÉS de renderizar
	# Esto previene que los updates subsecuentes del servidor se interpreten como robos
	last_hand_size = game_state.player_hand.size()


# ============================================================================
# INICIALIZACIÓN DE LA MANO
# ============================================================================
func _initialize_hand(game_state: GameState):
	"""Primera inicialización: decidir entre reparto inicial vs render directo"""
	
	# FIX: Deshabilitar clip_contents en el contenedor (PlayerHand)
	var parent = hand_layout.get_parent()
	if parent and parent.clip_contents:
		parent.clip_contents = false
		print("[PlayerHandController] ✅ Deshabilitado clip_contents en parent")
	
	# Si es NUEVO MATCH: empezar vacío
	if game_state.current_turn == 0 or not initial_deal_done:
		await _start_with_empty_hand(game_state)
		initial_deal_done = true
		print("[PlayerHandController] ✅ Reparto inicial completado")
		return
	
	# Si es REANUDACIÓN: render directo
	_render_hand_state(game_state)
	print("[PlayerHandController] ✅ Mano renderizada (reanudación)")


# ============================================================================
# REPARTO INICIAL (LA MAGIA ✨)
# ============================================================================
func _start_with_empty_hand(game_state: GameState):
	"""Empezar con mano vacía y animar reparto inicial"""
	# Limpiar cualquier contenido previo
	hand_layout.clear_cards()
	last_hand_size = 0
	
	# Animar todas las cartas iniciales
	await card_deal_animator.deal_cards_to_hand(
		game_state.player_hand,
		0.15  # Delay entre cartas (150ms)
	)
	
	# Guardar estado
	last_hand_size = game_state.player_hand.size()
	print("[PlayerHandController] 🎴 Reparto inicial: %d cartas animadas" % last_hand_size)


# ============================================================================
# ROBO NORMAL (DURANTE EL JUEGO)
# ============================================================================
func _extract_new_cards(game_state: GameState) -> Array:
	"""Extraer las cartas nuevas que fueron robadas"""
	return game_state.player_hand.slice(
		last_hand_size,
		game_state.player_hand.size()
	)


# ============================================================================
# RESET (CAMBIO DE PERSPECTIVA)
# ============================================================================
func reset() -> void:
	"""Resetear estado local cuando cambia la perspectiva (TEST match)"""
	initialized = false
	initial_deal_done = false
	last_hand_size = 0
	if hand_layout:
		hand_layout.clear_cards()
	print("[PlayerHandController] 🔄 Reset por cambio de perspectiva")


# ============================================================================
# RENDERIZACIÓN (SIN ANIMACIONES)
# ============================================================================
func _render_hand_state(game_state: GameState) -> void:
	"""Renderizar el estado actual de la mano (solo pinta, no anima)"""
	if not hand_layout:
		return
	
	# Solo renderizar si la mano está vacía (cartas nuevas ya fueron agregadas por animator)
	if hand_layout.get_cards().is_empty() and game_state.player_hand.size() > 0:
		for card_instance in game_state.player_hand:
			var card_display = preload("res://cards/CardDisplay.tscn").instantiate()
			card_display.setup(card_instance.base_data)
			card_display.bind_instance(card_instance)
			hand_layout.add_card(card_display)
		
		print("[PlayerHandController] 🎴 Mano renderizada: %d cartas" % game_state.player_hand.size())
