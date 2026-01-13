extends Node
class_name BoardRenderer

"""
BoardRenderer.gd

Responsabilidad ÚNICA: Renderizar el tablero desde GameState

Internamente maneja:
- Renderizar mano del jugador
- Renderizar zonas del jugador
- Renderizar mano del oponente
- Renderizar zonas del oponente
- Renderizar decks
- Renderizar escenario

NO sabe:
- Cómo obtener el GameState
- Cómo conectar al servidor
- Cómo manejar inputs

TestBoard le pasa solo: render(game_state)
"""

# ============================================================================
# REFERENCIAS A ZONAS (Del tablero)
# ============================================================================

# Player
var player_hand: Control
var player_knight_slots: Array
var player_tech_slots: Array
var player_helper_slot: Control
var player_occasion_slot: Control
var player_deck: Control

# Opponent
var opponent_hand: Control
var opponent_knight_slots: Array
var opponent_tech_slots: Array
var opponent_helper_slot: Control
var opponent_occasion_slot: Control
var opponent_deck: Control

# Shared
var scenario_slot: Control

# Templates
var CARD_DISPLAY_TEMPLATE: PackedScene
var CARD_BACK_TEMPLATE: PackedScene

# ============================================================================
# INIT
# ============================================================================

func _init(
	p_hand: Control,
	p_knight_slots: Array,
	p_tech_slots: Array,
	p_helper: Control,
	p_occasion: Control,
	p_deck: Control,
	o_hand: Control,
	o_knight_slots: Array,
	o_tech_slots: Array,
	o_helper: Control,
	o_occasion: Control,
	o_deck: Control,
	scenario: Control,
	card_display_tpl: PackedScene,
	card_back_tpl: PackedScene
) -> void:
	# Player zones
	player_hand = p_hand
	player_knight_slots = p_knight_slots
	player_tech_slots = p_tech_slots
	player_helper_slot = p_helper
	player_occasion_slot = p_occasion
	player_deck = p_deck
	
	# Opponent zones
	opponent_hand = o_hand
	opponent_knight_slots = o_knight_slots
	opponent_tech_slots = o_tech_slots
	opponent_helper_slot = o_helper
	opponent_occasion_slot = o_occasion
	opponent_deck = o_deck
	
	# Shared
	scenario_slot = scenario
	
	# Templates
	CARD_DISPLAY_TEMPLATE = card_display_tpl
	CARD_BACK_TEMPLATE = card_back_tpl


# ============================================================================
# MAIN RENDER ENTRY POINT
# ============================================================================

func render(game_state: GameState) -> void:
	"""Renderizar TODO el tablero desde GameState
	
	Punto de entrada único desde TestBoard
	"""
	_clear_all_zones()
	
	# Renderizar player
	_render_player_hand(game_state)
	_render_player_field(game_state)
	_render_player_deck(game_state)
	
	# Renderizar opponent
	_render_opponent_hand(game_state)
	_render_opponent_field(game_state)
	_render_opponent_deck(game_state)
	
	# Renderizar scenario
	_render_scenario(game_state)


# ============================================================================
# PLAYER RENDERING
# ============================================================================

func _render_player_hand(game_state: GameState) -> void:
	"""Renderizar mano del jugador (cartas conocidas)"""
	if not player_hand:
		return
	
	player_hand.clear_cards()
	
	for card_instance in game_state.get_hand_for_player(game_state.player_number):
		var card_display = CARD_DISPLAY_TEMPLATE.instantiate()
		card_display.setup(card_instance.base_data)
		card_display.set_meta("card_instance", card_instance)
		player_hand.add_card(card_display)


func _render_player_field(game_state: GameState) -> void:
	"""Renderizar field del jugador (knights, techniques, helper)"""
	_render_field_slots(
		game_state.get_cards_in_zone("field_knight", game_state.player_number),
		player_knight_slots
	)
	
	_render_field_slots(
		game_state.get_cards_in_zone("field_technique", game_state.player_number),
		player_tech_slots
	)
	
	# Helper
	var helper_cards = game_state.get_cards_in_zone("field_helper", game_state.player_number)
	if helper_cards.size() > 0:
		_render_card_in_slot(helper_cards[0], player_helper_slot)
	
	# Occasion
	var occasion_cards = game_state.get_cards_in_zone("field_occasion", game_state.player_number)
	if occasion_cards.size() > 0:
		_render_card_in_slot(occasion_cards[0], player_occasion_slot)


func _render_player_deck(game_state: GameState) -> void:
	"""Actualizar contador del deck del jugador"""
	if player_deck:
		var deck_size = game_state.get_deck_size(game_state.player_number)
		if player_deck.has_method("set_count"):
			player_deck.set_count(deck_size)


# ============================================================================
# OPPONENT RENDERING
# ============================================================================

func _render_opponent_hand(game_state: GameState) -> void:
	"""Renderizar mano del oponente (solo card backs)"""
	if not opponent_hand:
		return
	
	opponent_hand.clear_cards()
	var hand_count = game_state.opponent_hand_count
	
	for i in range(hand_count):
		var card_back = CARD_BACK_TEMPLATE.instantiate()
		opponent_hand.add_card(card_back)


func _render_opponent_field(game_state: GameState) -> void:
	"""Renderizar field del oponente (knights, techniques, helper)"""
	var opponent_num = 3 - game_state.player_number  # Si player=1 → opponent=2
	
	_render_field_slots(
		game_state.get_cards_in_zone("field_knight", opponent_num),
		opponent_knight_slots
	)
	
	_render_field_slots(
		game_state.get_cards_in_zone("field_technique", opponent_num),
		opponent_tech_slots
	)
	
	# Helper
	var helper_cards = game_state.get_cards_in_zone("field_helper", opponent_num)
	if helper_cards.size() > 0:
		_render_card_in_slot(helper_cards[0], opponent_helper_slot)
	
	# Occasion
	var occasion_cards = game_state.get_cards_in_zone("field_occasion", opponent_num)
	if occasion_cards.size() > 0:
		_render_card_in_slot(occasion_cards[0], opponent_occasion_slot)


func _render_opponent_deck(game_state: GameState) -> void:
	"""Actualizar contador del deck del oponente"""
	if opponent_deck:
		var opponent_num = 3 - game_state.player_number
		var deck_size = game_state.get_deck_size(opponent_num)
		if opponent_deck.has_method("set_count"):
			opponent_deck.set_count(deck_size)


# ============================================================================
# SCENARIO RENDERING
# ============================================================================

func _render_scenario(game_state: GameState) -> void:
	"""Renderizar escenario global"""
	if not scenario_slot:
		return
	
	# Buscar scenario (generalmente en zona shared o scenario_id)
	if game_state.scenario:
		_render_card_in_slot(game_state.scenario, scenario_slot)
	else:
		# Vaciar el slot si no hay scenario
		if scenario_slot.has_method("clear"):
			scenario_slot.clear()


# ============================================================================
# HELPERS
# ============================================================================

func _render_field_slots(cards: Array, slots: Array) -> void:
	"""Renderizar un grupo de cartas en sus slots correspondientes
	
	Si hay 3 cartas y 5 slots:
	- Slot 0: Carta 0
	- Slot 1: Carta 1
	- Slot 2: Carta 2
	- Slot 3: Vacío
	- Slot 4: Vacío
	"""
	for i in range(slots.size()):
		var slot = slots[i]
		
		if i < cards.size():
			_render_card_in_slot(cards[i], slot)
		else:
			# Vaciar slot
			if slot.has_method("clear"):
				slot.clear()


func _render_card_in_slot(card_instance: CardInstance, slot: Control) -> void:
	"""Renderizar una carta en un slot"""
	if not slot:
		return
	
	if slot.has_method("clear"):
		slot.clear()
	
	var card_display = CARD_DISPLAY_TEMPLATE.instantiate()
	card_display.setup(card_instance.base_data)
	card_display.set_meta("card_instance", card_instance)
	
	# Agregar a slot (asume que slot tiene API compatible)
	if slot.has_method("add_child"):
		slot.add_child(card_display)


func _clear_all_zones() -> void:
	"""Limpiar TODAS las zonas"""
	# Player zones
	if player_hand and player_hand.has_method("clear_cards"):
		player_hand.clear_cards()
	for slot in player_knight_slots:
		if slot.has_method("clear"):
			slot.clear()
	for slot in player_tech_slots:
		if slot.has_method("clear"):
			slot.clear()
	if player_helper_slot and player_helper_slot.has_method("clear"):
		player_helper_slot.clear()
	if player_occasion_slot and player_occasion_slot.has_method("clear"):
		player_occasion_slot.clear()
	
	# Opponent zones
	if opponent_hand and opponent_hand.has_method("clear_cards"):
		opponent_hand.clear_cards()
	for slot in opponent_knight_slots:
		if slot.has_method("clear"):
			slot.clear()
	for slot in opponent_tech_slots:
		if slot.has_method("clear"):
			slot.clear()
	if opponent_helper_slot and opponent_helper_slot.has_method("clear"):
		opponent_helper_slot.clear()
	if opponent_occasion_slot and opponent_occasion_slot.has_method("clear"):
		opponent_occasion_slot.clear()
	
	# Scenario
	if scenario_slot and scenario_slot.has_method("clear"):
		scenario_slot.clear()
