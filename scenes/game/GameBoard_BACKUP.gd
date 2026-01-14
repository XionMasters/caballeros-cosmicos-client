# GameBoard.gd
# Tablero principal del juego - Layout reorganizado con 3 columnas
extends Control

# Referencias a zonas del jugador
@onready var player_hand = $MainContainer/CenterColumn/PlayerArea/PlayerHeader/PlayerHand
@onready var player_knight_slots = [
	$MainContainer/CenterColumn/PlayerArea/KnightsRow/Knight1,
	$MainContainer/CenterColumn/PlayerArea/KnightsRow/Knight2,
	$MainContainer/CenterColumn/PlayerArea/KnightsRow/Knight3,
	$MainContainer/CenterColumn/PlayerArea/KnightsRow/Knight4,
	$MainContainer/CenterColumn/PlayerArea/KnightsRow/Knight5
]
@onready var player_tech_slots = [
	$MainContainer/CenterColumn/PlayerArea/TechRow/Tech1,
	$MainContainer/CenterColumn/PlayerArea/TechRow/Tech2,
	$MainContainer/CenterColumn/PlayerArea/TechRow/Tech3,
	$MainContainer/CenterColumn/PlayerArea/TechRow/Tech4,
	$MainContainer/CenterColumn/PlayerArea/TechRow/Tech5
]
@onready var player_helper_slot = $MainContainer/CenterColumn/PlayerArea/TechRow/HelperSlot
@onready var player_occasion_slot = $MainContainer/CenterColumn/PlayerArea/KnightsRow/OccasionSlot
@onready var player_deck = $MainContainer/LeftColumn/PlayerDeck/DeckPile
@onready var player_yomotsu_count = $MainContainer/RightColumn/PlayerPiles/YomotsuPile/Count
@onready var player_cositos_count = $MainContainer/RightColumn/PlayerPiles/CositosPile/Count
@onready var player_avatar = $MainContainer/CenterColumn/PlayerArea/PlayerHeader/PlayerAvatar

# Referencias a zonas del oponente
@onready var opponent_knight_slots = [
	$MainContainer/CenterColumn/OpponentArea/KnightsRow/Knight1,
	$MainContainer/CenterColumn/OpponentArea/KnightsRow/Knight2,
	$MainContainer/CenterColumn/OpponentArea/KnightsRow/Knight3,
	$MainContainer/CenterColumn/OpponentArea/KnightsRow/Knight4,
	$MainContainer/CenterColumn/OpponentArea/KnightsRow/Knight5
]
@onready var opponent_tech_slots = [
	$MainContainer/CenterColumn/OpponentArea/TechRow/Tech1,
	$MainContainer/CenterColumn/OpponentArea/TechRow/Tech2,
	$MainContainer/CenterColumn/OpponentArea/TechRow/Tech3,
	$MainContainer/CenterColumn/OpponentArea/TechRow/Tech4,
	$MainContainer/CenterColumn/OpponentArea/TechRow/Tech5
]
@onready var opponent_helper_slot = $MainContainer/CenterColumn/OpponentArea/TechRow/HelperSlot
@onready var opponent_occasion_slot = $MainContainer/CenterColumn/OpponentArea/KnightsRow/OccasionSlot
@onready var opponent_hand = $MainContainer/CenterColumn/OpponentArea/OpponentHeader/OpponentHand
@onready var opponent_deck = $MainContainer/LeftColumn/OpponentDeck/DeckPile
@onready var opponent_yomotsu_count = $MainContainer/RightColumn/OpponentPiles/YomotsuPile/Count
@onready var opponent_cositos_count = $MainContainer/RightColumn/OpponentPiles/CositosPile/Count
@onready var opponent_avatar = $MainContainer/CenterColumn/OpponentArea/OpponentHeader/OpponentAvatar

# Referencias al escenario compartido
@onready var scenario_slot = $MainContainer/RightColumn/ScenarioContainer/ScenarioSlot

# Referencias UI generales
@onready var turn_label = $UILayer/StatsOverlay/TurnLabel
@onready var phase_label = $UILayer/StatsOverlay/PhaseLabel
@onready var end_turn_button = $UILayer/EndTurnButton
@onready var card_detail_overlay = $CardDetailOverlay
@onready var card_detail_texture = $CardDetailOverlay/CardDetailPanel/CardTexture
@onready var effects_manager = $EffectsLayer
@onready var combat_animator = $EffectsLayer/CombatAnimator
@onready var knight_actions_panel = $UILayer/KnightActionsPanel

# Plantilla de carta
const CARD_DISPLAY_TEMPLATE = preload("res://scenes/components/cards/CardDisplay.tscn")
const CARD_BACK_TEMPLATE = preload("res://scenes/components/cards/CardBack.tscn")

var card_back_texture: ImageTexture = null  # Se cargará dinámicamente
var player_number: int = 0  # 1 o 2
var current_match: Dictionary = {}
var game_state: GameState = null  # Estado completo de la partida
var player_id: String = ""  # ID del jugador local
var selected_card_for_play: CardInstance = null  # Carta seleccionada de la mano para jugar
var knight_moving: Node = null  # Slot del caballero que se está moviendo
var is_selecting_move_target: bool = false  # Estado de selección de destino

# Sistema de carga asíncrona (usando DeckLoadingManager genérico)
var deck_loader: DeckLoadingManager = null
var _initial_hand_drawn: bool = false

func _ready():
	# Configurar mouse_filter para que los eventos pasen a las cartas
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Seguridad extra: asegurar que las manos reciban eventos de mouse
	if player_hand and player_hand is Control:
		(player_hand as Control).mouse_filter = Control.MOUSE_FILTER_PASS
		print("[DBG] GameBoard: player_hand mouse_filter=PASS")
	if opponent_hand and opponent_hand is Control:
		(opponent_hand as Control).mouse_filter = Control.MOUSE_FILTER_PASS
		print("[DBG] GameBoard: opponent_hand mouse_filter=PASS")
	
	# Conectar botón de terminar turno solo si no está conectado
	if not end_turn_button.pressed.is_connected(_on_end_turn_pressed):
		end_turn_button.pressed.connect(_on_end_turn_pressed)
	
	# Conectar señales del MatchManager
	MatchManager.match_state_updated.connect(_on_match_updated)
	MatchManager.match_error.connect(_on_match_error)
	
	# Conectar cambios de idioma
	LocalizationManager.language_changed.connect(_update_texts)
	
	# Conectar panel de acciones de caballero
	knight_actions_panel.action_selected.connect(_on_knight_action_selected)
	
	# Conectar todos los slots para recibir eventos de drop
	_connect_all_slots()
	
	# Precarga de dorsos de cartas (optimización TestBoard)
	if CardsManager:
		CardsManager.preload_card_back()
	
	# Crear DeckLoadingManager
	deck_loader = DeckLoadingManager.new()
	add_child(deck_loader)
	deck_loader.all_images_loaded.connect(_on_deck_loading_complete)
	
	# Inicializar estado de la partida
	_initialize_match()


func _initialize_match() -> void:
	"""Inicializar la partida una sola vez"""
	# Cargar estado inicial de la partida
	current_match = MatchManager.current_match
	if current_match.is_empty():
		push_error("No hay partida activa")
		get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
		return
	
	# Determinar número de jugador y establecer player_id
	var user_id = AuthManager.get_user_id()
	player_id = user_id  # Guardar player_id para GameState
	
	if current_match.get("player1_id", "") == user_id:
		player_number = 1
		var p1_name = current_match.get("player1_name", "Jugador")
		var p2_name = current_match.get("player2_name", "Oponente")
		var p1_health = current_match.get("player1_life", 12)
		var p1_cosmos = current_match.get("player1_cosmos", 0)
		var p2_health = current_match.get("player2_life", 12)
		var p2_cosmos = current_match.get("player2_cosmos", 0)
		
		player_avatar.setup(p1_name, p1_health, p1_cosmos)
		opponent_avatar.setup(p2_name, p2_health, p2_cosmos)
	elif current_match.get("player2_id", "") == user_id:
		player_number = 2
		var p1_name = current_match.get("player1_name", "Oponente")
		var p2_name = current_match.get("player2_name", "Jugador")
		var p1_health = current_match.get("player1_life", 12)
		var p1_cosmos = current_match.get("player1_cosmos", 0)
		var p2_health = current_match.get("player2_life", 12)
		var p2_cosmos = current_match.get("player2_cosmos", 0)
		
		player_avatar.setup(p2_name, p2_health, p2_cosmos)
		opponent_avatar.setup(p1_name, p1_health, p1_cosmos)
	else:
		push_error("No eres parte de esta partida")
		return
	
	# Actualizar textos iniciales
	_update_texts(LocalizationManager.get_language_code())
	
	# Renderizar estado inicial
	update_board()
	
	# Iniciar carga asíncrona del mazo
	_start_deck_loading()


func _input(event: InputEvent):
	"""Manejar input global (ESC para cancelar movimiento)"""
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if is_selecting_move_target:
				_cancel_knight_movement()
				print("🚫 Movimiento cancelado")

func _connect_all_slots():
	"""Conectar señales de todos los slots"""
	# Slots del jugador
	for slot in player_knight_slots:
		if slot.has_signal("card_placed"):
			slot.card_placed.connect(_on_card_placed_in_slot)
		if slot.has_signal("card_double_clicked"):
			slot.card_double_clicked.connect(_on_card_detail_requested)
		if slot.has_signal("knight_right_clicked"):
			slot.knight_right_clicked.connect(_on_knight_right_clicked)
		if slot.has_signal("slot_clicked"):
			slot.slot_clicked.connect(_on_slot_clicked)
	
	for slot in player_tech_slots:
		if slot.has_signal("card_placed"):
			slot.card_placed.connect(_on_card_placed_in_slot)
		if slot.has_signal("card_double_clicked"):
			slot.card_double_clicked.connect(_on_card_detail_requested)
	
	if player_helper_slot.has_signal("card_placed"):
		player_helper_slot.card_placed.connect(_on_card_placed_in_slot)
	if player_helper_slot.has_signal("card_double_clicked"):
		player_helper_slot.card_double_clicked.connect(_on_card_detail_requested)
		
	if player_occasion_slot.has_signal("card_placed"):
		player_occasion_slot.card_placed.connect(_on_card_placed_in_slot)
	if player_occasion_slot.has_signal("card_double_clicked"):
		player_occasion_slot.card_double_clicked.connect(_on_card_detail_requested)
	
	# Escenario
	if scenario_slot.has_signal("card_placed"):
		scenario_slot.card_placed.connect(_on_card_placed_in_slot)
	if scenario_slot.has_signal("card_double_clicked"):
		scenario_slot.card_double_clicked.connect(_on_card_detail_requested)

func update_board():
	"""Actualizar visualización del tablero completo"""
	if current_match.is_empty():
		return
	
	# Convertir current_match a GameState si no está ya creado o si cambió
	var needs_full_render = false
	if not game_state or game_state.match_id != current_match.get("id", ""):
		game_state = GameState.from_server_data(current_match, player_id)
		print("DEBUG: GameState creado - Match ID: ", game_state.match_id)
		needs_full_render = true
	else:
		# Actualizar game_state existente para detectar cambios en cards_in_play
		var old_cards_count = game_state.player_hand.size() + game_state.player_field_knights.size()
		game_state = GameState.from_server_data(current_match, player_id)
		var new_cards_count = game_state.player_hand.size() + game_state.player_field_knights.size()
		needs_full_render = (old_cards_count != new_cards_count)
	
	# Actualizar avatares con vida y cosmos
	_update_avatars()
	
	# Actualizar contadores de pilas
	_update_pile_counts()
	
	# Actualizar info de turno
	var current_turn = current_match.get("current_turn", 1)
	turn_label.text = "Turno: %d" % current_turn
	
	var is_my_turn = game_state.is_my_turn()
	_refresh_turn_indicators(is_my_turn)
	
	# Detectar cambio de turno para reproducir sonido
	var previous_turn = get_meta("previous_turn", -1)
	if previous_turn != -1 and previous_turn != current_turn:
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_turn_change()
	set_meta("previous_turn", current_turn)
	
	if is_my_turn:
		phase_label.text = "Tu Turno"
		phase_label.add_theme_color_override("font_color", Color.GREEN)
		end_turn_button.disabled = false
		_start_turn_button_pulse()
	else:
		phase_label.text = "Turno del Oponente"
		phase_label.add_theme_color_override("font_color", Color.RED)
		end_turn_button.disabled = true
		_stop_turn_button_pulse()
	
	# Solo re-renderizar si hubo cambios significativos
	if needs_full_render:
		render_all_zones()

func _update_avatars():
	"""Actualizar vida y cosmos en los avatares"""
	if player_number == 1:
		player_avatar.update_health(current_match.get("player1_life", 12))
		player_avatar.update_cosmos(current_match.get("player1_cosmos", 0))
		opponent_avatar.update_health(current_match.get("player2_life", 12))
		opponent_avatar.update_cosmos(current_match.get("player2_cosmos", 0))
	else:
		player_avatar.update_health(current_match.get("player2_life", 12))
		player_avatar.update_cosmos(current_match.get("player2_cosmos", 0))
		opponent_avatar.update_health(current_match.get("player1_life", 12))
		opponent_avatar.update_cosmos(current_match.get("player1_cosmos", 0))

func _update_pile_counts():
	"""Actualizar contadores de mazos, yomotsu y cositos"""
	if player_number == 1:
		player_deck.set_count(current_match.get("player1_deck_size", 40))
		player_yomotsu_count.text = str(current_match.get("player1_yomotsu_size", 0))
		player_cositos_count.text = str(current_match.get("player1_cositos_size", 0))
		opponent_deck.set_count(current_match.get("player2_deck_size", 40))
		opponent_yomotsu_count.text = str(current_match.get("player2_yomotsu_size", 0))
		opponent_cositos_count.text = str(current_match.get("player2_cositos_size", 0))
	else:
		player_deck.set_count(current_match.get("player2_deck_size", 40))
		player_yomotsu_count.text = str(current_match.get("player2_yomotsu_size", 0))
		player_cositos_count.text = str(current_match.get("player2_cositos_size", 0))
		opponent_deck.set_count(current_match.get("player1_deck_size", 40))
		opponent_yomotsu_count.text = str(current_match.get("player1_yomotsu_size", 0))
		opponent_cositos_count.text = str(current_match.get("player1_cositos_size", 0))
		
func _refresh_turn_indicators(is_my_turn: bool):
	"""Mostrar punto azul en el avatar correspondiente"""
	var opponent_present = current_match.get("player2_id", "") != ""
	player_avatar.set_turn_active(is_my_turn)
	opponent_avatar.set_turn_active(opponent_present and not is_my_turn)
	opponent_yomotsu_count.text = str(current_match.get("player1_yomotsu_size", 0))
	opponent_cositos_count.text = str(current_match.get("player1_cositos_size", 0))

func render_all_zones():
	"""Renderizar cartas en todas las zonas desde el GameState"""
	print("🎨 render_all_zones() llamado - Player hand size: ", game_state.player_hand.size() if game_state else 0)
	if not game_state:
		print("WARNING: No hay game_state para renderizar")
		return
	
	# Limpiar todas las zonas
	_clear_all_zones()
	
	# Renderizar mano del jugador
	for card_instance in game_state.player_hand:
		_add_card_to_hand(card_instance)
	
	# Renderizar mano del oponente (solo dorsos)
	_render_opponent_hand(game_state.opponent_hand_count)
	
	# Renderizar caballeros del jugador
	for i in range(game_state.player_field_knights.size()):
		var card_instance = game_state.player_field_knights[i]
		if card_instance and i < player_knight_slots.size():
			_place_card_in_slot(player_knight_slots[i], card_instance, false)
	
	# Renderizar técnicas del jugador
	for i in range(game_state.player_field_techniques.size()):
		var card_instance = game_state.player_field_techniques[i]
		if card_instance and i < player_tech_slots.size():
			_place_card_in_slot(player_tech_slots[i], card_instance, false)
	
	# Renderizar caballeros del oponente (boca arriba)
	for i in range(game_state.opponent_field_knights.size()):
		var card_instance = game_state.opponent_field_knights[i]
		if card_instance and i < opponent_knight_slots.size():
			_place_card_in_slot(opponent_knight_slots[i], card_instance, false)
	
	# Renderizar técnicas del oponente (boca arriba)
	for i in range(game_state.opponent_field_techniques.size()):
		var card_instance = game_state.opponent_field_techniques[i]
		if card_instance and i < opponent_tech_slots.size():
			_place_card_in_slot(opponent_tech_slots[i], card_instance, false)
	
	# Renderizar otras zonas especiales si existen
	if game_state.player_helper:
		_place_card_in_slot(player_helper_slot, game_state.player_helper, false)
	if game_state.opponent_helper:
		_place_card_in_slot(opponent_helper_slot, game_state.opponent_helper, false)
	if game_state.player_occasion:
		_place_card_in_slot(player_occasion_slot, game_state.player_occasion, false)
	if game_state.opponent_occasion:
		_place_card_in_slot(opponent_occasion_slot, game_state.opponent_occasion, false)
	if game_state.scenario:
		_place_card_in_slot(scenario_slot, game_state.scenario, false)

func _clear_all_zones():
	"""Limpiar todas las cartas de todas las zonas"""
	# Limpiar slots del jugador
	for slot in player_knight_slots:
		slot.clear()
	for slot in player_tech_slots:
		slot.clear()
	player_helper_slot.clear()
	player_occasion_slot.clear()
	
	# Limpiar slots del oponente
	for slot in opponent_knight_slots:
		slot.clear()
	for slot in opponent_tech_slots:
		slot.clear()
	opponent_helper_slot.clear()
	opponent_occasion_slot.clear()
	
	# Limpiar escenario
	scenario_slot.clear()
	
	# Limpiar mano del jugador
	if player_hand.has_method("clear_cards"):
		player_hand.clear_cards()
	else:
		for child in player_hand.get_children():
			child.queue_free()
	
	# Limpiar mano del oponente
	if opponent_hand.has_method("clear_cards"):
		opponent_hand.clear_cards()
	else:
		for child in opponent_hand.get_children():
			child.queue_free()

func _add_card_to_hand(card_instance: CardInstance):
	"""Agregar carta a la mano del jugador"""
	var card_display = CARD_DISPLAY_TEMPLATE.instantiate()

	# Asegurar captura de input en la carta
	if card_display is Control:
		(card_display as Control).mouse_filter = Control.MOUSE_FILTER_STOP
		(card_display as Control).focus_mode = Control.FOCUS_ALL
		print("[DBG] GameBoard: CardDisplay mouse_filter=STOP, focus_mode=FOCUS_ALL")
	
	# CRÍTICO: Forzar estados de interacción
	card_display.interaction_enabled = true
	card_display.is_disabled = false
	card_display.is_exhausted = false
	print("[DBG] GameBoard: FORZADO interaction_enabled=true, is_disabled=false, is_exhausted=false")

	# CRÍTICO: Conectar gui_input manualmente porque _ready() puede no hacerlo
	# Ya se conecta en _setup_state_machine de CardDisplay

	# Conectar señal de doble clic
	if card_display.has_signal("card_double_clicked"):
		card_display.card_double_clicked.connect(_on_card_detail_requested)

	# Conectar señales de interacción explícitamente
	if card_display.has_signal("card_clicked"):
		card_display.card_clicked.connect(_on_card_clicked_from_hand)
		print("[DBG] GameBoard: conectado card_clicked")
	if card_display.has_signal("drag_started"):
		card_display.drag_started.connect(_on_card_drag_started_from_hand)
		print("[DBG] GameBoard: conectado drag_started")

	# CRÍTICO: Usar setup_from_instance para vincular CardInstance
	card_instance.zone = "hand"
	card_display.setup_from_instance(card_instance)

	# Crear dorso visual y agregarlo (mejora TestBoard)
	var card_back = CARD_BACK_TEMPLATE.instantiate()
	card_display.add_child(card_back)
	card_display.set_meta("card_back", card_back)

	# Agregar a la mano usando el HandLayout manager
	if player_hand.has_method("add_card"):
		player_hand.add_card(card_display)
	else:
		player_hand.add_child(card_display)

	# Log de hitbox y jerarquía
	if card_display is Control:
		var c: Control = card_display
		print("[DBG] GameBoard: card pos=", c.global_position, " size=", c.size)

	# Cargar imagen si está disponible
	var card_id = card_instance.base_data.id
	if CardsManager._image_cache.has(card_id):
		card_display.set_card_image(CardsManager._image_cache[card_id])
	elif card_instance.base_data.image_url != "":
		CardsManager.fetch_card_image(card_id, card_instance.base_data.image_url)
	
	# Animar carta desde el mazo con flip (mejora TestBoard)
	if player_deck and card_display.has_method("animate_flip_from_deck"):
		var deck_global_pos = player_deck.global_position
		# Esperar un frame para que la carta se posicione en la mano primero
		await get_tree().process_frame
		card_display.animate_flip_from_deck(deck_global_pos, 0.6)

func _on_card_clicked_from_hand(card: CardData):
	print("[DBG] GameBoard: card_clicked recibido desde mano | card=", card.name if card else "(null)")

func _on_card_drag_started_from_hand(card_display):
	var card_name = card_display.card_data.name if card_display and card_display.card_data else "(null)"
	print("[DBG] GameBoard: drag_started recibido desde mano | card=", card_name)

func _debug_draw_hitboxes() -> void:
	# Visualizar área de la mano del jugador y cartas
	if player_hand and player_hand is Control:
		var ph: Control = player_hand
		print("[DBG] Hitbox PlayerHand pos=", ph.global_position, " size=", ph.size)
		# Dibujar rectángulo verde tenue
		var overlay := ColorRect.new()
		overlay.color = Color(0,1,0,0.12)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.global_position = ph.global_position
		overlay.size = ph.size
		add_child(overlay)
		overlay.z_index = 999
		# Remover luego de un corto tiempo
		var t := Timer.new()
		t.one_shot = true
		t.wait_time = 0.75
		add_child(t)
		t.timeout.connect(func():
			overlay.queue_free()
			t.queue_free()
		)
		# Dibujar rectángulos rojos para cada carta
		if ph.has_method("get_cards"):
			for card_node in ph.get_cards():
				if card_node is Control:
					var cd: Control = card_node
					var c_overlay := ColorRect.new()
					c_overlay.color = Color(1,0,0,0.12)
					c_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
					c_overlay.global_position = cd.global_position
					c_overlay.size = cd.size
					add_child(c_overlay)
					c_overlay.z_index = 999
					var ct := Timer.new()
					ct.one_shot = true
					ct.wait_time = 0.75
					add_child(ct)
					ct.timeout.connect(func():
						c_overlay.queue_free()
						ct.queue_free()
					)

func _render_opponent_hand(card_count: int):
	"""Renderizar mano del oponente como dorsos de carta"""
	# Limpiar primero
	if opponent_hand.has_method("clear_cards"):
		opponent_hand.clear_cards()
	
	# Agregar dorsos según la cantidad de cartas
	for i in range(card_count):
		var card_back = CARD_BACK_TEMPLATE.instantiate()
		opponent_hand.add_card(card_back)

func _place_card_in_slot(slot: Node, card_instance: CardInstance, show_back: bool = false):
	"""Colocar carta en un slot específico"""
	if slot.has_method("place_card"):
		var card_display
		
		if show_back:
			card_display = CARD_BACK_TEMPLATE.instantiate()
		else:
			card_display = CARD_DISPLAY_TEMPLATE.instantiate()
			card_display.setup_from_instance(card_instance)
			card_display.set_meta("card_instance", card_instance)
			card_display.set_meta("instance_id", card_instance.instance_id)
			
			var card_id = card_instance.base_data.id
			if CardsManager._image_cache.has(card_id):
				card_display.set_card_image(CardsManager._image_cache[card_id])
			elif card_instance.base_data.image_url != "":
				CardsManager.fetch_card_image(card_id, card_instance.base_data.image_url)
			
			if card_display.has_method("play_spawn_animation"):
				card_display.play_spawn_animation()
		
		slot.place_card(card_display)

func _on_card_placed_in_slot(slot: Node, card_display: Node):
	"""Callback cuando se coloca una carta en un slot"""
	var instance_id = card_display.get_meta("instance_id", "")
	var slot_type = slot.slot_type
	var slot_index = slot.slot_index
	var zone_name = _get_zone_name_from_slot_type(slot_type)
	
	# Emitir señal global de movimiento si tenemos instancia
	var card_instance: CardInstance = card_display.get_instance() if card_display.has_method("get_instance") else card_display.get_meta("card_instance", null)
	if card_instance:
		var from_zone := card_instance.zone if card_instance.zone != "" else "hand"
		card_instance.zone = zone_name
		var signals = Engine.get_singleton("Signals") if Engine.has_singleton("Signals") else null
		if signals and signals.has_method("emit_card_moved_to_zone"):
			signals.emit_card_moved_to_zone(card_instance, from_zone, zone_name)
		if signals and signals.has_method("emit_card_played"):
			signals.emit_card_played(card_instance, player_id)
	
	if instance_id != "" and zone_name != "":
		MatchManager.play_card(instance_id, zone_name, slot_index)

func _get_zone_name_from_slot_type(slot_type: int) -> String:
	"""Convertir tipo de slot a nombre de zona"""
	match slot_type:
		0: return "field_knight"  # CardSlot.SlotType.KNIGHT
		1: return "field_tech_object"  # CardSlot.SlotType.TECH_OBJECT
		2: return "field_helper"  # CardSlot.SlotType.HELPER
		3: return "field_scenario"  # CardSlot.SlotType.SCENARIO
		4: return "field_occasion"  # CardSlot.SlotType.OCCASION
		_: return ""

func _on_card_detail_requested(card_data: CardData):
	"""Mostrar detalle de carta en overlay"""
	card_detail_overlay.visible = true
	
	# Cargar imagen de la carta en grande
	var card_id = card_data.id
	if CardsManager._image_cache.has(card_id):
		card_detail_texture.texture = CardsManager._image_cache[card_id]
	elif card_data.image_url != "":
		CardsManager.fetch_card_image(card_id, card_data.image_url)

func _on_close_card_detail():
	"""Cerrar overlay de detalle de carta"""
	card_detail_overlay.visible = false
	card_detail_texture.texture = null

func _on_end_turn_pressed():
	"""Terminar turno del jugador"""
	MatchManager.end_turn()

func _on_match_updated(match: Dictionary):
	"""Callback cuando se actualiza el estado de la partida via WebSocket"""
	current_match = match
	update_board()
	
	# Verificar condición de victoria
	if match.get("phase", "") == "finished":
		_show_game_over(match)

func _on_match_error(message: String):
	"""Callback cuando hay error"""
	push_error("Error en partida: " + message)
	# TODO: Mostrar mensaje al usuario

func _request_match_state():
	"""Solicitar estado completo de la partida al servidor"""
	var match_id = current_match.get("id", "")
	if match_id == "":
		return
	
	# Enviar mensaje WebSocket solicitando estado
	var message = {
		"action": "get_match_state",
		"match_id": match_id
	}
	
	if MatchManager.has_method("send_websocket_message"):
		MatchManager.send_websocket_message(message)
	else:
		print("DEBUG: MatchManager no tiene método send_websocket_message")

func _show_game_over(match: Dictionary):
	"""Mostrar pantalla de fin de juego"""
	var winner_id = match.get("winner_id", "")
	var user_id = AuthManager.get_user_id()
	
	if winner_id == user_id:
		phase_label.text = "¡VICTORIA!"
		phase_label.add_theme_color_override("font_color", Color.GOLD)
	else:
		phase_label.text = "DERROTA"
		phase_label.add_theme_color_override("font_color", Color.DARK_RED)
	
	end_turn_button.text = "Volver al Menú"
	end_turn_button.disabled = false
	end_turn_button.pressed.disconnect(_on_end_turn_pressed)
	end_turn_button.pressed.connect(_return_to_menu)

func _return_to_menu():
	"""Volver al menú principal"""
	MatchManager.leave_match()
	get_tree().change_scene_to_file("res://scenes/menus/MainLobby.tscn")

func _update_texts(_lang_code: String):
	"""Actualizar textos cuando cambia el idioma"""
	# TODO: Implementar traducciones
	pass

func _start_turn_button_pulse():
	"""Iniciar animación de pulso en el botón de terminar turno"""
	_stop_turn_button_pulse()  # Detener cualquier animación previa
	
	var tween = create_tween()
	tween.set_loops()  # Loop infinito
	
	# Efecto de pulso: escala + brillo
	tween.tween_property(end_turn_button, "scale", Vector2(1.1, 1.1), 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(end_turn_button, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)
	
	# Guardar referencia para poder detenerlo
	end_turn_button.set_meta("pulse_tween", tween)

func _stop_turn_button_pulse():
	"""Detener animación de pulso"""
	if end_turn_button.has_meta("pulse_tween"):
		var tween = end_turn_button.get_meta("pulse_tween")
		if tween:
			tween.kill()
		end_turn_button.remove_meta("pulse_tween")
	
	# Restaurar escala normal
	end_turn_button.scale = Vector2.ONE

func _exit_tree():
	"""Limpiar al salir"""
	_stop_turn_button_pulse()

# ============================================================================
# SISTEMA DE COMBATE
# ============================================================================

func _on_knight_right_clicked(knight_slot: Node):
	"""Mostrar panel de acciones al hacer click derecho en un caballero"""
	if not current_match.get("current_player", 0) == player_number:
		print("❌ No es tu turno")
		return
	
	knight_actions_panel.show_actions_for_knight(knight_slot)

func _on_slot_clicked(slot: Node):
	"""Manejar click en slot (para seleccionar destino de movimiento)"""
	if is_selecting_move_target and slot.has_meta("can_receive_movement"):
		if knight_moving and not slot.is_occupied:
			_execute_knight_movement(knight_moving, slot)
		else:
			_cancel_knight_movement()

func _on_knight_action_selected(action: String, target_slot: Node):
	"""Manejar acción de caballero seleccionada"""
	print("Acción seleccionada: ", action)
	
	match action:
		"attack":
			_start_attack_selection(target_slot)
		"charge":
			_execute_knight_action(target_slot, "charge")
		"evade":
			_execute_knight_action(target_slot, "evade")
		"block":
			_execute_knight_action(target_slot, "block")
		"sacrifice":
			_execute_knight_action(target_slot, "sacrifice")
		"move":
			_start_knight_movement(target_slot)
		"technique":
			# TODO: Implementar selección de técnica
			print("Técnicas aún no implementadas")
		"pray":
			# TODO: Implementar oración divina
			print("Oración divina aún no implementada")

func _start_attack_selection(attacker_slot: Node):
	"""Iniciar selección de objetivo para ataque"""
	# TODO: Resaltar enemigos válidos y esperar selección
	# Por ahora, mostramos mensaje
	print("Selecciona un objetivo enemigo para atacar")
	# Guardar atacante seleccionado
	attacker_slot.set_meta("is_attacker", true)
	
	# Conectar señal de click en slots enemigos
	var enemy_slots = opponent_knight_slots if player_number == 1 else player_knight_slots
	for slot in enemy_slots:
		if slot.has_card():
			slot.set_meta("can_be_attacked", true)
			# TODO: Agregar highlight visual

func _execute_basic_attack(attacker_card_id: String, defender_card_id: String):
	"""Ejecutar ataque básico vía API"""
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_attack_completed)
	
	var body = JSON.stringify({
		"match_id": current_match.id,
		"attacker_card_id": attacker_card_id,
		"defender_card_id": defender_card_id
	})
	
	var headers = AuthManager.get_auth_headers()
	headers.append("Content-Type: application/json")
	
	http.request(GameConfig.API_URL + "/combat/attack", headers, HTTPClient.METHOD_POST, body)
	print("⚔️ Ejecutando ataque: ", attacker_card_id, " -> ", defender_card_id)

func _on_attack_completed(_result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	"""Manejar respuesta de ataque"""
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json and json.has("success") and json.success:
		var combat_result = json.combat_result
		print("✅ Ataque exitoso: ", combat_result)
		
		# Animar ataque (las posiciones se calcularían de los slots)
		# combat_animator.animate_attack(attacker_pos, defender_pos, combat_result.damage, combat_result.evaded)
	else:
		print("❌ Error en ataque: ", json.get("error", "Unknown"))

func _execute_knight_action(knight_slot: Node, action: String):
	"""Ejecutar acción de caballero vía API"""
	if not knight_slot.has_card():
		print("❌ No hay carta en el slot")
		return
	
	var card = knight_slot.get_card()
	var instance_id = card.get_meta("instance_id", "")
	
	if instance_id.is_empty():
		print("❌ Carta sin ID")
		return
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_knight_action_completed)
	
	var body = JSON.stringify({
		"match_id": current_match.id,
		"card_id": instance_id,
		"action": action
	})
	
	var headers = AuthManager.get_auth_headers()
	headers.append("Content-Type: application/json")
	
	http.request(GameConfig.API_URL + "/combat/knight-action", headers, HTTPClient.METHOD_POST, body)
	print("🎯 Ejecutando acción: ", action, " en carta ", instance_id)

func _on_knight_action_completed(_result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	"""Manejar respuesta de acción de caballero"""
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json and json.has("success") and json.success:
		print("✅ Acción ejecutada correctamente")
		# La actualización llegará por WebSocket (match_update)
	else:
		print("❌ Error en acción: ", json.get("error", "Unknown"))

func _start_knight_movement(knight_slot: Node):
	"""Iniciar proceso de movimiento de caballero"""
	if not knight_slot.has_card():
		print("❌ No hay carta para mover")
		return
	
	# Guardar el caballero que se está moviendo
	knight_moving = knight_slot
	is_selecting_move_target = true
	
	# Ocultar panel de acciones
	knight_actions_panel.hide()
	
	# Resaltar slots vacíos disponibles
	for slot in player_knight_slots:
		if not slot.is_occupied:
			slot.set_glow(true, Color.CYAN)
			slot.set_meta("can_receive_movement", true)
	
	# Actualizar fase label con instrucción
	phase_label.text = "Selecciona destino (ESC=Cancelar)"
	phase_label.add_theme_color_override("font_color", Color.CYAN)
	
	print("🔄 Selecciona un slot vacío para mover el caballero")

func _execute_knight_movement(from_slot: Node, to_slot: Node):
	"""Ejecutar movimiento de caballero vía API"""
	if not from_slot.has_card():
		print("❌ Slot de origen sin carta")
		_cancel_knight_movement()
		return
	
	var card = from_slot.get_card()
	var instance_id = card.get_meta("instance_id", "")
	
	if instance_id.is_empty():
		print("❌ Carta sin ID")
		_cancel_knight_movement()
		return
	
	# Calcular nueva posición (0-4)
	var new_position = player_knight_slots.find(to_slot)
	if new_position == -1:
		print("❌ Slot de destino inválido")
		_cancel_knight_movement()
		return
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_movement_completed)
	
	var body = JSON.stringify({
		"match_id": current_match.id,
		"card_id": from_slot.get_card().instance_id,
		"action": "move",
		"target_position": new_position
	})
	
	var headers = AuthManager.get_auth_headers()
	headers.append("Content-Type: application/json")
	
	http.request(GameConfig.API_URL + "/combat/knight-action", headers, HTTPClient.METHOD_POST, body)
	print("🔄 Moviendo caballero de posición ", from_slot.slot_index, " a ", new_position)
	
	# Limpiar estado
	_cancel_knight_movement()

func _cancel_knight_movement():
	"""Cancelar proceso de movimiento"""
	knight_moving = null
	is_selecting_move_target = false
	
	# Quitar resaltado de todos los slots
	for slot in player_knight_slots:
		slot.set_glow(false)
		slot.remove_meta("can_receive_movement")
	
	# Restaurar phase label
	update_board()

func _on_movement_completed(_result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	"""Manejar respuesta de movimiento"""
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json and json.has("success") and json.success:
		print("✅ Caballero movido correctamente")
		var result = json.get("result", {})
		if result.has("old_position") and result.has("new_position"):
			# Animar movimiento
			var old_pos = result.old_position
			var new_pos = result.new_position
			if old_pos < player_knight_slots.size() and new_pos < player_knight_slots.size():
				var from_slot_pos = player_knight_slots[old_pos].global_position + player_knight_slots[old_pos].size / 2
				var to_slot_pos = player_knight_slots[new_pos].global_position + player_knight_slots[new_pos].size / 2
				combat_animator.animate_card_movement(from_slot_pos, to_slot_pos)
	else:
		print("❌ Error en movimiento: ", json.get("error", "Unknown"))

# ============================================================================
# CARGA ASÍNCRONA DE MAZO (Similar a TestBoard)
# ============================================================================

func _start_deck_loading() -> void:
	"""Iniciar carga asíncrona del mazo del jugador"""
	if deck_loader:
		deck_loader.fetch_and_load_active_deck()


func _on_deck_loading_complete() -> void:
	"""Callback cuando la carga del mazo completa"""
	print("[GameBoard] ✅ Mazo cargado completamente!")
	
	if not _initial_hand_drawn:
		_initial_hand_drawn = true
		_draw_initial_hand()
		
		# ✅ Notificar al servidor que estamos listos para iniciar el turno
		_ready_to_start_game()


func _draw_initial_hand() -> void:
	"""Dibujar 7 cartas iniciales del mazo"""
	if not deck_loader:
		return
	
	print("[GameBoard] 🃏 Dibujando 7 cartas iniciales...")
	
	# Usar el DeckLoadingManager para sacar cartas
	var drawn_cards = deck_loader.draw_cards_from_deck(7)
	
	# Agregar cada carta a la mano con animación
	for card_instance in drawn_cards:
		_add_card_to_hand(card_instance)
	
	# Actualizar contador del mazo
	if player_deck and player_deck.has_method("set_count"):
		player_deck.set_count(deck_loader.get_remaining_deck_count())
	
	print("[GameBoard] ✅ Mano inicial dibujada: %d cartas | Mazo restante: %d" % [drawn_cards.size(), deck_loader.get_remaining_deck_count()])


func _ready_to_start_game() -> void:
	"""Notificar al servidor que el cliente está listo para iniciar el turno"""
	print("[GameBoard] 🎮 Cliente listo - pidiendo iniciar primer turno...")
	
	var match_id = current_match.get("id", "")
	if match_id.is_empty():
		push_error("No hay match_id disponible")
		return
	
	# Crear petición HTTP POST al servidor
	var http = HTTPRequest.new()
	add_child(http)
	
	var auth_token = AuthManager.get_token()
	var headers = [
		"Authorization: Bearer " + auth_token,
		"Content-Type: application/json"
	]
	
	var url = GameConfig.API_URL + "/matches/" + match_id + "/start-first-turn"
	
	# Conectar señal de respuesta
	if not http.request_completed.is_connected(_on_first_turn_response.bindv([http])):
		http.request_completed.connect(_on_first_turn_response.bindv([http]))
	
	var error = http.request(url, headers, HTTPClient.METHOD_POST, "")
	
	if error != OK:
		push_error("Error enviando petición de inicio de turno:", error)
		http.queue_free()


func _on_first_turn_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http_node: HTTPRequest) -> void:
	"""Procesar respuesta del servidor al solicitar iniciar el turno"""
	print("[GameBoard] 📨 Respuesta del servidor - Código: ", response_code)
	
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json and json.get("success", false):
			print("[GameBoard] ✅ Primer turno iniciado exitosamente")
		else:
			push_error("Error en respuesta del servidor:", json)
	else:
		push_error("Error HTTP al iniciar turno:", response_code, body.get_string_from_utf8())
	
	http_node.queue_free()
