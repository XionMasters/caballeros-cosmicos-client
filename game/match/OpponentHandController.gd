# OpponentHandController.gd
# Controlador de la mano del oponente
# Responsabilidades:
# 1. Renderizar dorsos de cartas (no tenemos detalles)
# 2. Mostrar count actualizado
# 3. Animar cambios visuales sin revelar información

extends Node
class_name OpponentHandController

# ============================================================================
# REFERENCIAS
# ============================================================================
var hand_layout: HandLayout
var opponent_deck: DeckDisplay  # Para obtener la textura del dorso
var opponent_card_deal_animator: OpponentCardDealAnimator
var parent_node: Node  # Para que el animador tenga get_tree()

# ============================================================================
# ESTADO LOCAL
# ============================================================================
var last_hand_count: int = 0
var initialized: bool = false
var initial_deal_done: bool = false

# ============================================================================
# INICIALIZACIÓN
# ============================================================================
func _init(p_hand: HandLayout, p_deck: Control, p_parent: Node):
	hand_layout = p_hand
	opponent_deck = p_deck  # Guardar el DeckDisplay
	parent_node = p_parent
	
	# Crear animador (sin agregarlo aún)
	opponent_card_deal_animator = OpponentCardDealAnimator.new(
		preload("res://cards/CardBack.tscn"),
		p_hand,
		p_deck.global_position,
		p_parent,  # Pasar el parent para que tenga acceso a get_tree()
		p_deck  # Pasar el DeckDisplay para obtener la textura del dorso
	)


# ============================================================================
# MAIN ENTRY POINT
# ============================================================================
func update_from_state(game_state: GameState):
	"""Punto de entrada único desde GameMatch"""
	
	# Primera inicialización
	if not initialized:
		await _initialize_hand(game_state)
		initialized = true
		# Asegurarse de que last_hand_count está actualizado después de init
		last_hand_count = game_state.opponent_hand_count
		return
	
	# Detectar cambios en count (oponente robó o jugó cartas)
	if game_state.opponent_hand_count != last_hand_count:
		var diff = game_state.opponent_hand_count - last_hand_count
		if diff > 0:
			print("[OpponentHandController] 🎴 Oponente robó %d cartas" % diff)
			# Animar los nuevos dorsos
			await opponent_card_deal_animator.deal_cards_to_hand(diff)
		else:
			print("[OpponentHandController] 🎴 Oponente jugó %d cartas" % abs(diff))
	
	# Renderizar dorsos (estado final sin animaciones)
	_render_opponent_hand(game_state)
	
	# ⚠️ IMPORTANTE: Actualizar contador DESPUÉS de renderizar
	# Esto previene que los updates subsecuentes del servidor se interpreten como cambios
	last_hand_count = game_state.opponent_hand_count


# ============================================================================
# INICIALIZACIÓN DE LA MANO
# ============================================================================
func _initialize_hand(game_state: GameState):
	"""Primera inicialización: decidir entre reparto inicial vs render directo"""
	print("[OpponentHandController] 🔍 _initialize_hand() called - current_turn=%d, initial_deal_done=%s" % [game_state.current_turn, initial_deal_done])
	
	# DEBUG: Verificar visibilidad de HandLayout
	print("[OpponentHandController] 📊 HandLayout debug:")
	print("  → name: %s" % hand_layout.name)
	print("  → visible: %s" % hand_layout.visible)
	print("  → size: %s" % hand_layout.size)
	print("  → global_position: %s" % hand_layout.global_position)
	var parent_name: String = hand_layout.get_parent().name if hand_layout.get_parent() else "NULL"
	print("  → parent: %s" % parent_name)
	print("  → clip_contents: %s" % hand_layout.clip_contents)
	print("  → custom_minimum_size: %s" % hand_layout.custom_minimum_size)
	
	# FIX: Si el contenedor no tiene altura, asignar uno
	if hand_layout.custom_minimum_size.y == 0:
		hand_layout.custom_minimum_size = Vector2(0, 140)
		print("[OpponentHandController] ✅ Asignado custom_minimum_size: (0, 140)")
	
	# FIX: También revisar el padre (OpponentHand)
	var parent = hand_layout.get_parent()
	if parent:
		# Asegurar que el padre tiene altura suficiente
		if parent.custom_minimum_size.y == 0:
			parent.custom_minimum_size = Vector2(0, 140)
			print("[OpponentHandController] ✅ Asignado custom_minimum_size a parent: (0, 140)")
		
		# IMPORTANTE: Deshabilitar clip_contents para que las cartas se vean aunque se salgan del contenedor
		if parent.clip_contents:
			parent.clip_contents = false
			print("[OpponentHandController] ✅ Deshabilitado clip_contents en parent")
	
	# Si es NUEVO MATCH: empezar vacío y animar reparto
	if game_state.current_turn == 0 or not initial_deal_done:
		print("[OpponentHandController] 🎬 Iniciando _start_with_empty_hand()...")
		await _start_with_empty_hand(game_state)
		print("[OpponentHandController] ✅ _start_with_empty_hand() completado")
		initial_deal_done = true
		print("[OpponentHandController] ✅ Reparto inicial completado")
		return
	
	# Si es REANUDACIÓN: render directo
	print("[OpponentHandController] 🔄 Reanudación - render directo")
	_render_opponent_hand(game_state)
	print("[OpponentHandController] ✅ Mano renderizada (reanudación)")


# ============================================================================
# RESET (CAMBIO DE PERSPECTIVA)
# ============================================================================
func reset() -> void:
	"""Resetear estado local cuando cambia la perspectiva (TEST match)"""
	initialized = false
	initial_deal_done = false
	last_hand_count = 0
	if hand_layout:
		hand_layout.clear_cards()
	print("[OpponentHandController] 🔄 Reset por cambio de perspectiva")


# ============================================================================
# REPARTO INICIAL (LA MAGIA ✨)
# ============================================================================
func _start_with_empty_hand(game_state: GameState):
	"""Empezar con mano vacía y animar reparto inicial"""
	# Limpiar cualquier contenido previo
	hand_layout.clear_cards()
	last_hand_count = 0
	
	# Animar todos los dorsos iniciales
	await opponent_card_deal_animator.deal_cards_to_hand(
		game_state.opponent_hand_count,
		0.5  # Delay inicial: 500ms después del jugador
	)

	# Reemplazar dorsos por CardDisplay en cartas visibles (ej: DEBUG reveal)
	_render_opponent_hand(game_state)

	# Guardar estado
	last_hand_count = game_state.opponent_hand_count
	print("[OpponentHandController] 🎴 Reparto inicial: %d dorsos animados" % last_hand_count)


# ============================================================================
# RENDERIZACIÓN (SIN ANIMACIONES)
# ============================================================================
func _render_opponent_hand(game_state: GameState) -> void:
	"""Renderizar mano del oponente: dorso para cartas ocultas, cara para cartas visibles"""
	if not hand_layout:
		return
	
	var card_back_tpl = preload("res://cards/CardBack.tscn")
	var card_display_tpl = preload("res://cards/CardDisplay.tscn")
	
	hand_layout.clear_cards()
	
	for card_instance in game_state.opponent_hand:
		if card_instance.hidden or card_instance.base_data == null:
			# Mostrar dorso
			var card_back = card_back_tpl.instantiate()
			if opponent_deck and opponent_deck.get_back_texture():
				card_back.set_back_texture(opponent_deck.get_back_texture())
			hand_layout.add_card(card_back)
		else:
			# Mostrar cara (carta visible del oponente)
			var card_display = card_display_tpl.instantiate()
			card_display.setup(card_instance.base_data)
			card_display.bind_instance(card_instance)
			hand_layout.add_card(card_display)
			print("[OpponentHandController] 👁️ Carta visible: %s" % card_instance.base_data.name)
	
	print("[OpponentHandController] 🔙 Mano renderizada: %d cartas (%d visibles)" % [
		game_state.opponent_hand.size(),
		game_state.opponent_hand.filter(func(c): return not c.hidden).size()
	])
