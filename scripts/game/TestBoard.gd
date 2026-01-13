# TestBoard.gd
# Tablero de Prueba - Cliente que controla 2 jugadores
# 🎭 El cliente levanta el telón, pero el guion lo escribe el servidor
#
# ============================================================================
# MODO DE DESARROLLO/PRUEBA
# ============================================================================
# TestBoard es una versión experimental del juego donde:
# 
# 1. Juegas contra uno de tus propios mazos (IA simplificada)
# 2. El jugador controla AMBOS jugadores (Player 1 y Player 2)
# 3. Al pasar de turno, ves la mano del otro jugador
# 4. NO requiere dos jugadores conectados
# 5. Ideal para desarrollo y pruebas de mecánicas
#
# Flujo:
# 1. Cliente solicita partida TEST al servidor
# 2. Servidor crea 2 jugadores (ambos tu mazo)
# 3. Servidor baraja, reparte mano inicial
# 4. Cliente renderiza GameBoard completo
# 5. Cliente notifica al servidor: "estoy listo para turno 1"
# 6. Servidor inicia turno 1
# 7. Al pasar turno → turno 2 con vista del otro jugador
#
# ARQUITECTURA: Server-Authoritative
# - Cliente obtiene mazo
# - Cliente valida UX mínimo
# - Cliente PIDE al servidor crear partida TEST
# - Servidor hace TODO (valida, baraja, roba, etc)
# - Cliente renderiza estado del servidor

extends Control

# ============================================================================
# REFERENCIAS A NODOS - MANO Y MAZOS
# ============================================================================
@onready var player_hand = $MainContainer/CenterColumn/PlayerArea/PlayerHeader/PlayerHand
@onready var opponent_hand = $MainContainer/CenterColumn/OpponentArea/OpponentHeader/OpponentHand
@onready var player_deck = $MainContainer/LeftColumn/PlayerDeck/DeckPile
@onready var opponent_deck = $MainContainer/LeftColumn/OpponentDeck/DeckPile

# ============================================================================
# REFERENCIAS A NODOS - CAMPOS DE JUEGO (KNIGHTS + TÉCNICAS)
# ============================================================================
@onready var player_knight_slots = [
	$MainContainer/CenterColumn/PlayerArea/PlayerKnightsRow/PlayerKnight1,
	$MainContainer/CenterColumn/PlayerArea/PlayerKnightsRow/PlayerKnight2,
	$MainContainer/CenterColumn/PlayerArea/PlayerKnightsRow/PlayerKnight3,
	$MainContainer/CenterColumn/PlayerArea/PlayerKnightsRow/PlayerKnight4,
	$MainContainer/CenterColumn/PlayerArea/PlayerKnightsRow/PlayerKnight5
]

@onready var opponent_knight_slots = [
	$MainContainer/CenterColumn/OpponentArea/OpponentKnightsRow/OpponentKnight1,
	$MainContainer/CenterColumn/OpponentArea/OpponentKnightsRow/OpponentKnight2,
	$MainContainer/CenterColumn/OpponentArea/OpponentKnightsRow/OpponentKnight3,
	$MainContainer/CenterColumn/OpponentArea/OpponentKnightsRow/OpponentKnight4,
	$MainContainer/CenterColumn/OpponentArea/OpponentKnightsRow/OpponentKnight5
]

@onready var player_tech_slots = [
	$MainContainer/CenterColumn/PlayerArea/PlayerTechRow/PlayerTech1,
	$MainContainer/CenterColumn/PlayerArea/PlayerTechRow/PlayerTech2,
	$MainContainer/CenterColumn/PlayerArea/PlayerTechRow/PlayerTech3,
	$MainContainer/CenterColumn/PlayerArea/PlayerTechRow/PlayerTech4,
	$MainContainer/CenterColumn/PlayerArea/PlayerTechRow/PlayerTech5
]

@onready var opponent_tech_slots = [
	$MainContainer/CenterColumn/OpponentArea/OpponentTechRow/OpponentTech1,
	$MainContainer/CenterColumn/OpponentArea/OpponentTechRow/OpponentTech2,
	$MainContainer/CenterColumn/OpponentArea/OpponentTechRow/OpponentTech3,
	$MainContainer/CenterColumn/OpponentArea/OpponentTechRow/OpponentTech4,
	$MainContainer/CenterColumn/OpponentArea/OpponentTechRow/OpponentTech5
]

@onready var player_helper_slot = $MainContainer/CenterColumn/PlayerArea/PlayerTechRow/PlayerHelper
@onready var opponent_helper_slot = $MainContainer/CenterColumn/OpponentArea/OpponentTechRow/OpponentHelper
@onready var player_occasion_slot = $MainContainer/CenterColumn/PlayerArea/PlayerKnightsRow/PlayerOccasion
@onready var opponent_occasion_slot = $MainContainer/CenterColumn/OpponentArea/OpponentTechRow/OpponentOccasion
@onready var scenario_slot = $MainContainer/RightColumn/ScenarioSlot

# ============================================================================
# REFERENCIAS UI - PILES (YOMOTSU, COSITOS)
# ============================================================================
@onready var player_yomotsu_counter = $MainContainer/RightColumn/PlayerYomotsuCounter
@onready var player_cositos_counter = $MainContainer/RightColumn/PlayerCositosCounter
@onready var opponent_yomotsu_counter = $MainContainer/RightColumn/OpponentYomotsuCounter
@onready var opponent_cositos_counter = $MainContainer/RightColumn/OpponentCositosCounter

# ============================================================================
# REFERENCIAS UI - STATS BÁSICOS
# ============================================================================
@onready var turn_label = $UILayer/StatsOverlay/TurnLabel
@onready var phase_label = $UILayer/StatsOverlay/PhaseLabel
@onready var player_label = $UILayer/StatsOverlay/PlayerLabel
@onready var player_life_label = $UILayer/StatsOverlay/PlayerLifeLabel
@onready var player_cosmos_label = $UILayer/StatsOverlay/PlayerCosmosLabel
@onready var opponent_life_label = $UILayer/StatsOverlay/OpponentLifeLabel
@onready var opponent_cosmos_label = $UILayer/StatsOverlay/OpponentCosmosLabel
@onready var end_turn_button = $UILayer/EndTurnButton
@onready var back_button = $UILayer/BackButton
@onready var loading_label = $UILayer/LoadingLabel

# ============================================================================
# REFERENCIAS UI - PLAYER STATUS DISPLAY (Avatar + Cosmos/Life)
# ============================================================================
var player_status_display: PlayerStatusDisplay = null
var opponent_status_display: PlayerStatusDisplay = null

# ============================================================================
# REFERENCIAS UI - CARD DETAIL OVERLAY
# ============================================================================
@onready var card_detail_overlay = $CardDetailOverlay
@onready var card_detail_texture = $CardDetailOverlay/CardDetailPanel/CardTexture

# ============================================================================
# PLANTILLAS
# ============================================================================
const CARD_DISPLAY_TEMPLATE = preload("res://scenes/components/cards/CardDisplay.tscn")
const CARD_BACK_TEMPLATE = preload("res://scenes/components/cards/CardBack.tscn")

# ============================================================================
# ESTADO
# ============================================================================
var game_state: GameState = null
var player_number: int = 1  # Para TestBoard: siempre 1 (pero controlas ambos)
var _is_loading: bool = false
var board_renderer: BoardRenderer = null
var match_initializer: MatchInitializer = null  # Orquestador de match
var match_play_controller: MatchPlayController = null  # Orquestador de juego
var match_event_bridge: MatchEventBridge = null  # Puente de eventos

# --- Card Input Tracking (Drag & Drop State) ---
var hovering_card_count: int = 0
var holding_card_count: int = 0
var card_drag_ongoing: Node = null  # Compatible con Card y CardDisplay

# ============================================================================
# CICLO DE VIDA
# ============================================================================
func _ready() -> void:
	print("[TestBoard] 🎭 Inicializando tablero de prueba (Server-Authoritative)...")
	
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if player_hand:
		(player_hand as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	if opponent_hand:
		(opponent_hand as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Conectar botones (si no están ya conectados en la escena)
	if not end_turn_button.is_connected("pressed", Callable(self, "_on_end_turn_pressed")):
		end_turn_button.pressed.connect(_on_end_turn_pressed)
	if not back_button.is_connected("pressed", Callable(self, "_on_back_pressed")):
		back_button.pressed.connect(_on_back_pressed)
	
	# 🆕 Crear displays de status (avatar + cosmos/life)
	_create_player_status_displays()
	
	# BoardRenderer no se usa más (simplificado a phases en _on_match_started)
	
	# Inicializar orquestador agnóstico (inyectar providers)
	var deck_provider = TestDeckProvider.new()
	var opponent_provider = TestOpponentProvider.new()
	
	match_initializer = MatchInitializer.new(deck_provider, opponent_provider)
	add_child(match_initializer)
	
	# Conectar señales del initializer
	match_initializer.loading.connect(_show_loading)
	match_initializer.match_error.connect(_show_error)
	match_initializer.match_ready.connect(_on_match_started)
	
	# Escuchar actualizaciones de estado del servidor
	MatchManager.match_state_updated.connect(_on_match_state_updated)
	
	# Inicializar MatchPlayController (orquestador de input + juego)
	# Se creará después de que GameState esté listo
	
	print("[TestBoard] ✅ Inicializado y escuchando servidor")
	
	# Validar que los slots de campo existen
	_validate_field_slots()
	
	# Auto-iniciar el test match
	match_initializer.start_match()



# ============================================================================
# MATCH FLOW
# ============================================================================
# La lógica de flujo está delegada a MatchFlowController
# TestBoard solo reacciona a cambios de estado


func _on_match_started(state: GameState) -> void:
	"""Callback: Partida iniciada correctamente
	
	FASE 1: Renderizar mazos (solo contadores)
	FASE 2: Animar cartas del mazo a la mano (deal animation)
	FASE 3: Renderizar campo
	FASE 4: Conectar interactividad
	"""
	print("[TestBoard] 8️⃣ Partida iniciada! Renderizando GameState del servidor...")
	
	_is_loading = false
	_hide_loading()
	
	game_state = state
	player_number = 1  # En TestBoard siempre eres player 1
	
	print("[TestBoard] ✅ GameState cargado")
	
	# FASE 1: Renderizar mazos (contadores)
	print("[TestBoard] 📊 Fase 1: Renderizando mazos...")
	_render_decks_only()
	
	# FASE 2: Esperar a que las imágenes se precarguen, luego animar
	print("[TestBoard] 🎴 Fase 2: Esperando precarga de imágenes...")
	await _wait_for_deck_images()
	print("[TestBoard] 🎴 Animando robo de cartas...")
	await _animate_initial_deal()
	
	# FASE 3: Renderizar mano del oponente
	print("[TestBoard] 🎯 Fase 3: Renderizando mano oponente...")
	_render_opponent_hand()
	
	# FASE 3B: Renderizar campos de caballeros
	print("[TestBoard] ⚔️ Fase 3B: Renderizando campos de batalla...")
	_render_knight_fields()
	
	# FASE 3C: Renderizar campos de técnicas
	print("[TestBoard] 🔮 Fase 3C: Renderizando campos de técnicas...")
	_render_technique_fields()
	
	# FASE 3D: Renderizar zonas especiales (helper, occasion, scenario)
	print("[TestBoard] 🎪 Fase 3D: Renderizando zonas especiales...")
	_render_special_zones()
	_update_pile_counters()
	
	# FASE 4: Conectar interactividad
	print("[TestBoard] 🎮 Fase 4: Configurando controllers...")
	_update_turn_display()
	_update_status_displays()  # 🆕 Mostrar avatar y stats iniciales
	_setup_match_controllers()
	
	print("\n[TestBoard] ✅ Partida lista para jugar\n")
	
	# ✅ FASE 5: Notificar al servidor que estamos listos para iniciar el turno
	await get_tree().create_timer(0.5).timeout
	_ready_to_start_game()


# ============================================================================
# IMAGE LOADING HELPERS
# ============================================================================

func _wait_for_deck_images() -> void:
	"""Esperar a que todas las imágenes del deck se precarguen"""
	# Obtener IDs de cartas en la mano
	var card_ids_to_load = []
	for card_instance in game_state.player_hand:
		card_ids_to_load.append(card_instance.base_data.id)
	
	if card_ids_to_load.is_empty():
		return
	
	# Esperar hasta 5 segundos a que se precarguen
	var start_time = Time.get_ticks_msec()
	var timeout_ms = 5000
	var loaded_count = 0
	
	print("[TestBoard] ⏳ Esperando precarga de %d imágenes..." % card_ids_to_load.size())
	
	while Time.get_ticks_msec() - start_time < timeout_ms:
		var all_loaded = true
		loaded_count = 0
		
		for card_id in card_ids_to_load:
			if CardsManager._image_cache.has(card_id):
				loaded_count += 1
			else:
				all_loaded = false
		
		if all_loaded:
			print("[TestBoard] ✅ Todas las imágenes cargadas (%d/%d)" % [loaded_count, card_ids_to_load.size()])
			return
		
		# Esperar 100ms antes de revisar de nuevo
		await get_tree().create_timer(0.1).timeout
	
	print("[TestBoard] ⚠️ Timeout esperando imágenes (%d/%d cargadas)" % [loaded_count, card_ids_to_load.size()])


func _on_match_state_updated(_match_data: Dictionary) -> void:
	"""Se ejecuta cada vez que el servidor actualiza el estado
	
	⚠️ IMPORTANTE: NO llamamos a render_all_zones()
	Eso causaba duplicación de cartas
	
	Solo actualizamos:
	- Contadores de mazos
	- Mano del jugador (si cambió)
	- Stats (vida, cosmos)
	"""
	if not game_state:
		return
	
	print("[TestBoard] 🔄 Estado actualizado desde servidor")
	
	# Actualizar solo lo mínimo
	_update_deck_counts()
	_update_turn_display()
	_update_status_displays()  # 🆕 Actualizar displays de status
	
	# Reconectar eventos de cartas (por si hubo remoción/adición)
	if match_play_controller:
		match_play_controller.setup_card_interactions()


func _on_match_error(error_message: String) -> void:
	"""Error del servidor"""
	_show_error("Error: %s" % error_message)
	_is_loading = false


# ============================================================================
# RENDERIZADO
# ============================================================================

# ============================================================================
# RENDERIZADO - Delegado a BoardRenderer
# ============================================================================

# Eliminado: render_all_zones() causaba duplicación de cartas
# Ahora usamos _update_deck_counts() en _on_match_state_updated()


func _update_turn_display() -> void:
	"""Actualizar información de turno en UI"""
	if not game_state:
		return
	
	turn_label.text = "Turno: %d" % game_state.current_turn
	phase_label.text = "Fase: %s" % game_state.current_phase.capitalize()
	if player_label:
		player_label.text = "Jugador: %d" % game_state.active_player_number
	
	# Actualizar stats
	var p1_life = game_state.get_player_life(1)
	var p2_life = game_state.get_player_life(2)
	var p1_cosmos = game_state.get_player_cosmos(1)
	var p2_cosmos = game_state.get_player_cosmos(2)
	
	if player_life_label:
		player_life_label.text = "Vida: %d" % p1_life
	if player_cosmos_label:
		player_cosmos_label.text = "Cosmos: %d" % p1_cosmos
	if opponent_life_label:
		opponent_life_label.text = "Vida: %d" % p2_life
	if opponent_cosmos_label:
		opponent_cosmos_label.text = "Cosmos: %d" % p2_cosmos


func _update_deck_counts() -> void:
	"""Actualizar contadores de mazos"""
	if game_state and player_deck:
		player_deck.set_count(game_state.player_deck_count)
	if game_state and opponent_deck:
		opponent_deck.set_count(game_state.opponent_deck_count)


# ============================================================================
# ACCIONES DEL JUGADOR
# ============================================================================

func _on_end_turn_pressed() -> void:
	"""Usuario apretó botón 'End Turn'
	
	✅ Validamos UX mínimo
	✅ Forwardeamos al servidor
	❌ NO hacemos nada localmente
	"""
	if not game_state or _is_loading:
		return
	
	# Validación UX: ¿Es mi turno?
	if game_state.active_player_number != player_number:
		print("[TestBoard] ❌ No es tu turno")
		return
	
	print("[TestBoard] ⏭️ Pidiendo fin de turno al servidor...")
	
	# Forwardear al servidor
	MatchManager.end_turn()
	
	# El servidor responderá con nuevo estado
	# → match_state_updated signal
	# → render_all_zones()
	# → UI se actualiza automáticamente


func _on_back_pressed() -> void:
	"""Volver al menú"""
	get_tree().change_scene_to_file("res://scenes/menus/MainLobby.tscn")


# ============================================================================
# UI HELPERS
# ============================================================================

func _on_close_card_detail() -> void:
	"""Cerrar el panel de detalle de carta"""
	if card_detail_overlay:
		card_detail_overlay.visible = false
		card_detail_texture.texture = null


func _on_card_detail_requested(card_data: CardData) -> void:
	"""Mostrar detalle de carta en overlay (doble-click)"""
	if not card_detail_overlay:
		return
	
	card_detail_overlay.visible = true
	
	# Cargar imagen de la carta en grande
	var card_id = card_data.id
	if CardsManager._image_cache.has(card_id):
		card_detail_texture.texture = CardsManager._image_cache[card_id]
		print("[TestBoard] 🖼️ Mostrando detalle de: %s" % card_data.name)
	elif card_data.image_url != "":
		CardsManager.fetch_card_image(card_id, card_data.image_url)
		print("[TestBoard] ⏳ Descargando imagen para detalle: %s" % card_data.name)


func _show_loading(message: String) -> void:
	"""Mostrar loading con mensaje"""
	if loading_label:
		loading_label.text = message
		loading_label.visible = true


func _hide_loading() -> void:
	"""Ocultar loading"""
	if loading_label:
		loading_label.visible = false


# ============================================================================
# CONTROLLERS SETUP
# ============================================================================

func _setup_match_controllers() -> void:
	"""Crear e inicializar los controllers de juego
	
	Orden:
	1. Crear BoardRenderer (abstrae acceso a slots)
	2. Crear MatchPlayController (maneja input de cartas)
	3. Crear MatchEventBridge (conecta servidor ↔ controller)
	4. Conectar eventos de cartas en tablero
	"""
	print("[TestBoard] 🎮 Configurando controllers de juego...")
	
	# 1️⃣ Crear BoardRenderer que abstrae los slots
	board_renderer = BoardRenderer.new(
		player_hand,
		player_knight_slots,
		player_tech_slots,
		player_helper_slot,
		player_occasion_slot,
		player_deck,
		opponent_hand,
		opponent_knight_slots,
		opponent_tech_slots,
		opponent_helper_slot,
		opponent_occasion_slot,
		opponent_deck,
		scenario_slot,
		CARD_DISPLAY_TEMPLATE,
		CARD_BACK_TEMPLATE
	)
	
	# 2️⃣ Crear MatchPlayController (con test_mode=true para permitir jugar ambos lados)
	match_play_controller = MatchPlayController.new(
		board_renderer,
		game_state,
		MatchManager,
		true  # is_test_mode=true
	)
	add_child(match_play_controller)
	
	# 3️⃣ Crear MatchEventBridge (puente servidor ↔ juego local)
	match_event_bridge = MatchEventBridge.new(
		match_play_controller,
		board_renderer,
		game_state
	)
	add_child(match_event_bridge)
	match_event_bridge.setup()
	
	# 4️⃣ Conectar eventos de cartas en tablero
	match_play_controller.setup_card_interactions()


# ============================================================================
# RENDERIZADO POR FASES (TESTBOARD REBUILD)
# ============================================================================

func _render_decks_only() -> void:
	"""FASE 1: Mostrar solo los contadores de mazo"""
	if player_deck:
		player_deck.set_count(game_state.player_deck_count)
	if opponent_deck:
		opponent_deck.set_count(game_state.opponent_deck_count)
	
	print("[TestBoard] ✅ Mazos: P1=%d, P2=%d" % [
		game_state.player_deck_count,
		game_state.opponent_deck_count
	])


func _render_opponent_hand() -> void:
	"""Renderizar mano del oponente (solo dorsos)"""
	if not opponent_hand:
		return
	
	opponent_hand.clear_cards()
	
	for i in range(game_state.opponent_hand_count):
		var card_back = CARD_BACK_TEMPLATE.instantiate()
		opponent_hand.add_card(card_back)
	
	print("[TestBoard] ✅ Mano oponente: %d dorsos" % game_state.opponent_hand_count)


func _render_knight_fields() -> void:
	"""Renderizar caballeros en el campo de batalla"""
	if not game_state:
		return
	
	# Limpiar slots existentes
	for slot in player_knight_slots:
		slot.clear()
	for slot in opponent_knight_slots:
		slot.clear()
	
	# Renderizar caballeros del jugador
	for card_instance in game_state.player_field_knights:
		if card_instance and card_instance.base_data:
			var slot_index = card_instance.position
			if slot_index < player_knight_slots.size():
				var card_display = CARD_DISPLAY_TEMPLATE.instantiate()
				card_display.setup(card_instance.base_data)
				card_display.bind_instance(card_instance)
				player_knight_slots[slot_index].add_child(card_display)
				# Conectar doble-click para detalle
				if card_display.has_signal("card_double_clicked"):
					card_display.card_double_clicked.connect(_on_card_detail_requested)
				print("[TestBoard] ⚔️ Caballero jugador: %s en slot %d" % [card_instance.base_data.name, slot_index])
	
	# Renderizar caballeros del oponente
	for card_instance in game_state.opponent_field_knights:
		if card_instance and card_instance.base_data:
			var slot_index = card_instance.position
			if slot_index < opponent_knight_slots.size():
				var card_display = CARD_DISPLAY_TEMPLATE.instantiate()
				card_display.setup(card_instance.base_data)
				card_display.bind_instance(card_instance)
				opponent_knight_slots[slot_index].add_child(card_display)
				# Conectar doble-click para detalle
				if card_display.has_signal("card_double_clicked"):
					card_display.card_double_clicked.connect(_on_card_detail_requested)
				print("[TestBoard] ⚔️ Caballero oponente: %s en slot %d" % [card_instance.base_data.name, slot_index])
	
	print("[TestBoard] ✅ Campos de batalla renderizados")

func _render_technique_fields() -> void:
	"""Renderizar técnicas en el campo de batalla"""
	if not game_state:
		return
	
	# Limpiar slots existentes
	for slot in player_tech_slots:
		slot.clear()
	for slot in opponent_tech_slots:
		slot.clear()
	
	# Renderizar técnicas del jugador
	for card_instance in game_state.player_field_techniques:
		if card_instance and card_instance.base_data:
			var slot_index = card_instance.position
			if slot_index < player_tech_slots.size():
				var card_display = CARD_DISPLAY_TEMPLATE.instantiate()
				card_display.setup(card_instance.base_data)
				card_display.bind_instance(card_instance)
				player_tech_slots[slot_index].add_child(card_display)
				if card_display.has_signal("card_double_clicked"):
					card_display.card_double_clicked.connect(_on_card_detail_requested)
				print("[TestBoard] 🔮 Técnica jugador: %s en slot %d" % [card_instance.base_data.name, slot_index])
	
	# Renderizar técnicas del oponente
	for card_instance in game_state.opponent_field_techniques:
		if card_instance and card_instance.base_data:
			var slot_index = card_instance.position
			if slot_index < opponent_tech_slots.size():
				var card_display = CARD_DISPLAY_TEMPLATE.instantiate()
				card_display.setup(card_instance.base_data)
				card_display.bind_instance(card_instance)
				opponent_tech_slots[slot_index].add_child(card_display)
				if card_display.has_signal("card_double_clicked"):
					card_display.card_double_clicked.connect(_on_card_detail_requested)
				print("[TestBoard] 🔮 Técnica oponente: %s en slot %d" % [card_instance.base_data.name, slot_index])
	
	print("[TestBoard] ✅ Campos de técnicas renderizados")

func _render_special_zones() -> void:
	"""Renderizar zonas especiales: Helper, Occasion, Scenario"""
	if not game_state:
		return
	
	# Limpiar slots
	player_helper_slot.clear()
	opponent_helper_slot.clear()
	player_occasion_slot.clear()
	scenario_slot.clear()
	
	# Helper del jugador
	if game_state.player_helper and game_state.player_helper.base_data:
		var card_display = CARD_DISPLAY_TEMPLATE.instantiate()
		card_display.setup(game_state.player_helper.base_data)
		card_display.bind_instance(game_state.player_helper)
		player_helper_slot.add_child(card_display)
		if card_display.has_signal("card_double_clicked"):
			card_display.card_double_clicked.connect(_on_card_detail_requested)
		print("[TestBoard] 🤝 Helper jugador: %s" % game_state.player_helper.base_data.name)
	
	# Helper del oponente
	# (Nota: opponent_helper no está en GameState, puede ser null o ignorado)
	
	# Occasion del jugador
	# (Nota: player_occasion no existe en GameState aún, implementar si es necesario)
	
	# Scenario (compartido)
	if game_state.scenario and game_state.scenario.base_data:
		var card_display = CARD_DISPLAY_TEMPLATE.instantiate()
		card_display.setup(game_state.scenario.base_data)
		card_display.bind_instance(game_state.scenario)
		scenario_slot.add_child(card_display)
		if card_display.has_signal("card_double_clicked"):
			card_display.card_double_clicked.connect(_on_card_detail_requested)
		print("[TestBoard] 🎪 Scenario: %s" % game_state.scenario.base_data.name)
	
	print("[TestBoard] ✅ Zonas especiales renderizadas")

func _update_pile_counters() -> void:
	"""Actualizar contadores de piles (Yomotsu y Cositos)"""
	# Nota: Los contadores de piles se actualizarían desde el servidor
	# Por ahora, inicializar en 0
	if player_yomotsu_counter:
		player_yomotsu_counter.text = "Yomotsu: 0"
	if player_cositos_counter:
		player_cositos_counter.text = "Cositos: 0"
	if opponent_yomotsu_counter:
		opponent_yomotsu_counter.text = "Yomotsu: 0"
	if opponent_cositos_counter:
		opponent_cositos_counter.text = "Cositos: 0"


func _animate_initial_deal() -> void:
	"""FASE 2: Animar cartas del mazo a la mano"""
	var cards_to_deal = game_state.get_hand_for_player(game_state.player_number)
	
	if cards_to_deal.is_empty():
		print("[TestBoard] ⚠️ No hay cartas para robar!")
		return
	
	# Crear animador
	var animator = CardDealAnimator.new(
		CARD_DISPLAY_TEMPLATE,
		player_hand,
		player_deck.global_position
	)
	add_child(animator)
	
	# Animar
	await animator.deal_cards_to_hand(cards_to_deal, 0.5)
	
	# Limpiar
	animator.queue_free()

	# ===== LOG: VERIFICAR CARTAS EN MANO =====
	_log_hand_verification()
	# ==========================================
	
	# ===== CONECTAR SEÑALES DE CARTAS =====
	_connect_hand_card_signals()
	# ======================================

	print("[TestBoard] ✅ Controllers configurados!")
	print("[TestBoard] 🎮 Las cartas ahora son interactuables")


func _show_error(message: String) -> void:
	"""Mostrar error al usuario"""
	print("[TestBoard] ❌ ERROR: %s" % message)
	if loading_label:
		loading_label.text = "❌ " + message
		loading_label.visible = true
	# TODO: Mostrar dialog de error mejor


# ============================================================================
# DEBUG - VERIFICACIÓN DE MANO
# ============================================================================

func _log_hand_verification() -> void:
	"""Verificar que las cartas visuales en mano coincidan con GameState"""
	if not game_state or not player_hand:
		return
	
	# Contar cartas visuales (CardDisplay nodes)
	var visual_cards = player_hand.get_cards()
	var visual_count = visual_cards.size()
	
	# Cartas en GameState
	var gamestate_cards = game_state.player_hand
	var gamestate_count = gamestate_cards.size()
	
	# Comparar
	var match = "✅" if visual_count == gamestate_count else "❌"
	
	print("\n" + "=".repeat(60))
	print("[HAND VERIFICATION] %s MANO JUGADOR" % match)
	print("=".repeat(60))
	print("📊 Cartas Visuales: %d" % visual_count)
	print("📊 Cartas en GameState: %d" % gamestate_count)
	print("=".repeat(60))
	
	# Listar cartas visuales
	if visual_count > 0:
		print("\n🃏 CARTAS VISUALES:")
		for i in range(visual_count):
			var card_node = visual_cards[i]
			var card_name = card_node.get_meta("card_data", {}).get("name", "DESCONOCIDA")
			print("  [%d] %s (Node: %s)" % [i, card_name, card_node.name])
	
	# Listar cartas en GameState
	if gamestate_count > 0:
		print("\n📋 GAMESTATE CARDS:")
		for i in range(gamestate_count):
			var card = gamestate_cards[i]
			var card_name = card.base_data.name if card.base_data else "DESCONOCIDA"
			print("  [%d] %s (Instance: %s, Zone: %s)" % [i, card_name, card.instance_id, card.zone])
	
	# Resumen
	print("\n" + "=".repeat(60))
	if visual_count == gamestate_count:
		print("✅ COINCIDEN: %d cartas en mano correctamente cargadas" % visual_count)
	else:
		print("❌ MISMATCH: Visual=%d, GameState=%d (Diferencia: %d)" % [
			visual_count,
			gamestate_count,
			abs(visual_count - gamestate_count)
		])
	print("=".repeat(60) + "\n")

# ============================================================================
# FIELD VALIDATION
# ============================================================================

func _validate_field_slots() -> void:
	"""Validar que todos los slots de campo existen y son accesibles"""
	print("\n[TestBoard] 🔍 Validando slots de campo...")
	
	var all_ok = true
	
	# Validar slots de caballeros
	if player_knight_slots.size() != 5:
		push_error("[TestBoard] ❌ player_knight_slots debería tener 5 elementos, tiene %d" % player_knight_slots.size())
		all_ok = false
	
	if opponent_knight_slots.size() != 5:
		push_error("[TestBoard] ❌ opponent_knight_slots debería tener 5 elementos, tiene %d" % opponent_knight_slots.size())
		all_ok = false
	
	# Validar slots de técnicas
	if player_tech_slots.size() != 5:
		push_error("[TestBoard] ❌ player_tech_slots debería tener 5 elementos, tiene %d" % player_tech_slots.size())
		all_ok = false
	
	if opponent_tech_slots.size() != 5:
		push_error("[TestBoard] ❌ opponent_tech_slots debería tener 5 elementos, tiene %d" % opponent_tech_slots.size())
		all_ok = false
	
	# Validar zonas especiales
	if not is_instance_valid(player_helper_slot):
		push_error("[TestBoard] ❌ player_helper_slot es null o inválido")
		all_ok = false
	
	if not is_instance_valid(opponent_helper_slot):
		push_error("[TestBoard] ❌ opponent_helper_slot es null o inválido")
		all_ok = false
	
	if not is_instance_valid(player_occasion_slot):
		push_error("[TestBoard] ❌ player_occasion_slot es null o inválido")
		all_ok = false
	
	if not is_instance_valid(scenario_slot):
		push_error("[TestBoard] ❌ scenario_slot es null o inválido")
		all_ok = false
	
	# Validar contadores de piles
	if not is_instance_valid(player_yomotsu_counter):
		push_error("[TestBoard] ❌ player_yomotsu_counter es null o inválido")
		all_ok = false
	
	if not is_instance_valid(player_cositos_counter):
		push_error("[TestBoard] ❌ player_cositos_counter es null o inválido")
		all_ok = false
	
	if all_ok:
		print("[TestBoard] ✅ Todos los slots de campo validados correctamente")
	else:
		print("[TestBoard] ⚠️ Algunos slots de campo no están disponibles")


# ============================================================================
# SIGNAL CONNECTIONS
# ============================================================================

func _connect_hand_card_signals() -> void:
	"""Conectar señales de doble-click de cartas en mano"""
	if not player_hand:
		return
	
	var cards = player_hand.get_cards()
	var connected_count = 0
	
	for card_display in cards:
		if card_display and card_display.has_signal("card_double_clicked"):
			if not card_display.card_double_clicked.is_connected(_on_card_detail_requested):
				card_display.card_double_clicked.connect(_on_card_detail_requested)
				connected_count += 1
	
	print("[TestBoard] ✅ Conectadas %d señales de doble-click en mano" % connected_count)

# ============================================================================
# PLAYER STATUS DISPLAY (Avatar + Cosmos/Life Wheels)
# ============================================================================
func _create_player_status_displays() -> void:
	"""Crear displays de status para jugador y oponente"""
	
	# Crear display del jugador (izquierda)
	player_status_display = PlayerStatusDisplay.new()
	player_status_display.player_name = "Player 1"
	player_status_display.is_player = true
	player_status_display.custom_minimum_size = Vector2(400, 180)
	player_status_display.anchor_left = 0.0
	player_status_display.anchor_top = 0.0
	player_status_display.anchor_right = 0.0
	player_status_display.anchor_bottom = 1.0
	add_child(player_status_display)
	print("[TestBoard] ✅ Player Status Display creado (izquierda)")
	
	# Crear display del oponente (derecha)
	opponent_status_display = PlayerStatusDisplay.new()
	opponent_status_display.player_name = "Player 2"
	opponent_status_display.is_player = false
	opponent_status_display.custom_minimum_size = Vector2(400, 180)
	opponent_status_display.anchor_left = 1.0
	opponent_status_display.anchor_top = 0.0
	opponent_status_display.anchor_right = 1.0
	opponent_status_display.anchor_bottom = 1.0
	opponent_status_display.offset_left = -400
	add_child(opponent_status_display)
	print("[TestBoard] ✅ Opponent Status Display creado (derecha)")

func _update_status_displays() -> void:
	"""Actualizar displays cuando el estado cambia"""
	if not game_state:
		return
	
	if player_status_display:
		player_status_display.update_stats(
			game_state.player_life,
			game_state.player_cosmos
		)
	
	if opponent_status_display:
		opponent_status_display.update_stats(
			game_state.opponent_life,
			game_state.opponent_cosmos
		)


func _ready_to_start_game() -> void:
	"""Notificar al servidor que el cliente está listo para iniciar el turno
	
	En TestBoard:
	- Partida TEST ya está creada
	- Mazo inicial repartido
	- Tablero renderizado completamente
	- Ahora pedimos al servidor: "¡Inicia el primer turno!"
	"""
	print("[TestBoard] 🎮 Cliente listo - pidiendo iniciar primer turno...")
	
	var match_id = MatchManager.current_match.get("id", "")
	if match_id.is_empty():
		push_error("[TestBoard] No hay match_id disponible")
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
		push_error("[TestBoard] Error enviando petición de inicio de turno:", error)
		http.queue_free()


func _on_first_turn_response(_result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http_node: HTTPRequest) -> void:
	"""Procesar respuesta del servidor al solicitar iniciar el turno
	
	En TestBoard, el servidor responderá con:
	- { "success": true, "match": {...}, "message": "Primer turno iniciado" }
	
	El WebSocket enviará match_updated automáticamente con el nuevo estado
	"""
	print("\n[TestBoard] 📨 Respuesta del servidor - Código: ", response_code)
	
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json and json.get("success", false):
			print("[TestBoard] ✅ Primer turno iniciado exitosamente")
			print("[TestBoard] 📋 Datos del servidor:")
			
			if json.has("match"):
				var match_data = json["match"]
				print("[TestBoard]   - current_turn: %d" % match_data.get("current_turn", -1))
				print("[TestBoard]   - current_player: %d" % match_data.get("current_player", -1))
				print("[TestBoard]   - player1_cosmos: %d" % match_data.get("player1_cosmos", -1))
				print("[TestBoard]   - player2_cosmos: %d" % match_data.get("player2_cosmos", -1))
				print("[TestBoard]   - player1_hand_count: %d" % match_data.get("player1_hand_count", -1))
				print("[TestBoard]   - player2_hand_count: %d" % match_data.get("player2_hand_count", -1))
				print("[TestBoard]   - player1_deck_size: %d" % match_data.get("player1_deck_size", -1))
				print("[TestBoard]   - player2_deck_size: %d" % match_data.get("player2_deck_size", -1))
				
				# 🆕 ACTUALIZAR GAMESTATE CON LOS DATOS DEL SERVIDOR
				if game_state:
					print("\n[TestBoard] 🔄 Actualizando GameState con datos del servidor...")
					# Actualizar campos de cosmos del GameState
					if match_data.has("player1_cosmos"):
						game_state.player_cosmos = match_data["player1_cosmos"]
						print("[TestBoard]   ✅ player_cosmos actualizado a: %d" % game_state.player_cosmos)
					if match_data.has("player2_cosmos"):
						game_state.opponent_cosmos = match_data["player2_cosmos"]
						print("[TestBoard]   ✅ opponent_cosmos actualizado a: %d" % game_state.opponent_cosmos)
					if match_data.has("current_turn"):
						game_state.current_turn = match_data["current_turn"]
					if match_data.has("player1_deck_size"):
						game_state.player_deck_count = match_data["player1_deck_size"]
					if match_data.has("player2_deck_size"):
						game_state.opponent_deck_count = match_data["player2_deck_size"]
					
					# 🆕 ACTUALIZAR LA UI INMEDIATAMENTE
					print("[TestBoard] 🎨 Actualizando UI...")
					_update_turn_display()
					_update_deck_counts()
					_update_status_displays()
					print("[TestBoard] ✅ UI actualizada")
				else:
					print("[TestBoard] ⚠️ GameState no está disponible para actualizar")
			else:
				print("[TestBoard] ⚠️ No se recibió 'match' en la respuesta")
				print("[TestBoard] 📦 Respuesta completa: ", json)
			
			print()
		else:
			push_error("[TestBoard] Error en respuesta del servidor:", json)
	else:
		push_error("[TestBoard] Error HTTP al iniciar turno:", response_code, body.get_string_from_utf8())
	
	http_node.queue_free()
