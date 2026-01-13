## Ejemplo completo de integración en GameBoard
## Este archivo muestra cómo integrar todos los managers
## Puede ser copiado y adaptado directamente en GameBoard.gd

extends Control

## ======== IMPORT DE MANAGERS ========
## (Ya están en el proyecto, aquí solo se usan)

# Managers
var deck_loader: DeckLoadingManager = null
var card_play_manager: CardPlayManager = null
var animation_manager: CardAnimationManager = null
var card_factory: CardDisplayFactory = null

# Estado del jugador (dos instancias, una por jugador)
var player_state: PlayerState = null
var opponent_state: PlayerState = null

# Slot groups para gestión unificada
var player_knight_slots_group: SlotGroup = null
var player_technique_slots_group: SlotGroup = null
var opponent_knight_slots_group: SlotGroup = null
var opponent_technique_slots_group: SlotGroup = null

# Scenes y referencias existentes
@onready var player_hand = $MainContainer/CenterColumn/PlayerArea/PlayerHeader/PlayerHand
@onready var opponent_hand = $MainContainer/CenterColumn/OpponentArea/OpponentHeader/OpponentHand
@onready var player_deck = $MainContainer/LeftColumn/PlayerDeck/DeckPile
@onready var opponent_deck = $MainContainer/LeftColumn/OpponentDeck/DeckPile

# Template scenes
const CARD_DISPLAY_SCENE = preload("res://scenes/components/cards/CardDisplay.tscn")
const CARD_BACK_TEMPLATE = preload("res://scenes/components/cards/CardBack.tscn")

# Slots arrays (existentes)
var player_knight_slots: Array = []
var opponent_knight_slots: Array = []
var player_technique_slots: Array = []
var opponent_technique_slots: Array = []


func _ready() -> void:
	# IMPORTANTE: Esto reemplaza _initialize_match() si lo tienes
	await _initialize_match()


## ======== INICIALIZACIÓN PRINCIPAL ========

func _initialize_match() -> void:
	print("[GameBoard] Inicializando partida...")
	
	# 1. Setup de managers
	_setup_managers()
	
	# 2. Setup de estado del jugador
	_setup_player_states()
	
	# 3. Setup de slot groups
	_setup_slot_groups()
	
	# 4. Cargar mazo desde servidor
	await _load_deck()
	
	# 5. Conectar señales
	_connect_signals()
	
	print("[GameBoard] Partida inicializada correctamente")


## ======== SETUP DE MANAGERS ========

func _setup_managers() -> void:
	print("[GameBoard] Configurando managers...")
	
	# 1. DeckLoadingManager (cargar mazos)
	deck_loader = DeckLoadingManager.new()
	add_child(deck_loader)
	print("  ✓ DeckLoadingManager creado")
	
	# 2. CardPlayManager (orquestar juego)
	card_play_manager = CardPlayManager.new()
	add_child(card_play_manager)
	print("  ✓ CardPlayManager creado")
	
	# 3. CardAnimationManager (animar cartas)
	animation_manager = CardAnimationManager.new()
	add_child(animation_manager)
	# Configurar duraciones opcionalmente
	animation_manager.card_play_duration = 0.4
	animation_manager.hover_scale = 1.1
	print("  ✓ CardAnimationManager creado")
	
	# 4. CardDisplayFactory (crear cartas)
	card_factory = CardDisplayFactory.new(CARD_DISPLAY_SCENE, CARD_BACK_TEMPLATE)
	print("  ✓ CardDisplayFactory creado")


## ======== SETUP DE ESTADO DEL JUGADOR ========

func _setup_player_states() -> void:
	print("[GameBoard] Configurando estado del jugador...")
	
	# Crear instancia para jugador local
	var current_user_id = AuthManager.get_user_id()  # O: SessionManager.get_user_id()
	player_state = PlayerState.new(current_user_id, 1)
	player_state.max_cosmos = 10
	player_state.current_cosmos = 3  # Comenzar con 3
	player_state.current_health = 20
	print("  ✓ Player state: cosmos=%d/%d, hp=%d" % [
		player_state.current_cosmos,
		player_state.max_cosmos,
		player_state.current_health
	])
	
	# Crear instancia para oponente
	opponent_state = PlayerState.new("opponent-id", 2)
	opponent_state.max_cosmos = 10
	opponent_state.current_cosmos = 3
	opponent_state.current_health = 20
	print("  ✓ Opponent state: cosmos=%d/%d, hp=%d" % [
		opponent_state.current_cosmos,
		opponent_state.max_cosmos,
		opponent_state.current_health
	])


## ======== SETUP DE SLOT GROUPS ========

func _setup_slot_groups() -> void:
	print("[GameBoard] Configurando slot groups...")
	
	# Obtener referencias a slots desde la escena
	# (Esto depende de cómo estructures tu escena)
	if player_knight_slots.size() == 0:
		# Si no están inicializadas, obtenerlas del árbol
		var knight_container = $MainContainer/CenterColumn/PlayerArea/KnightsRow
		for child in knight_container.get_children():
			if child is CardSlot:
				player_knight_slots.append(child)
	
	# Crear y configurar slot groups para jugador
	player_knight_slots_group = SlotGroup.new("knights", 5)
	player_knight_slots_group.initialize_from_nodes(player_knight_slots)
	print("  ✓ Player knights: %s" % player_knight_slots_group.get_debug_status())
	
	player_technique_slots_group = SlotGroup.new("techniques", 5)
	player_technique_slots_group.initialize_from_nodes(player_technique_slots)
	print("  ✓ Player techniques: %s" % player_technique_slots_group.get_debug_status())
	
	# Crear y configurar slot groups para oponente
	opponent_knight_slots_group = SlotGroup.new("knights", 5)
	opponent_knight_slots_group.initialize_from_nodes(opponent_knight_slots)
	print("  ✓ Opponent knights: %s" % opponent_knight_slots_group.get_debug_status())
	
	opponent_technique_slots_group = SlotGroup.new("techniques", 5)
	opponent_technique_slots_group.initialize_from_nodes(opponent_technique_slots)
	print("  ✓ Opponent techniques: %s" % opponent_technique_slots_group.get_debug_status())


## ======== CARGAR MAZO ========

func _load_deck() -> void:
	print("[GameBoard] Cargando mazo...")
	
	# Usar DeckLoadingManager para cargar
	await deck_loader.fetch_and_load_active_deck()
	
	print("[GameBoard] Mazo cargado, dibujando mano inicial...")
	
	# Dibujar 7 cartas iniciales
	await _draw_initial_hand()


func _draw_initial_hand() -> void:
	print("[GameBoard] Dibujando mano inicial...")
	
	# Obtener 7 cartas del mazo
	var initial_cards = deck_loader.draw_cards_from_deck(7)
	if initial_cards.size() == 0:
		push_error("No hay cartas en el mazo!")
		return
	
	print("[GameBoard] Dibujadas %d cartas" % initial_cards.size())
	
	# Crear CardDisplay para cada carta con animación
	var card_displays = await card_factory.create_batch(initial_cards, true)
	
	# Agregar a la mano
	for i in range(card_displays.size()):
		var card_display = card_displays[i]
		
		# Agregar a HandLayout (se auto-organiza)
		player_hand.add_card(card_display)
		
		# Conectar señal de click
		card_display.card_clicked.connect(_on_card_clicked_from_hand.bind(card_display))
	
	print("[GameBoard] Mano inicial dibujada con %d cartas" % card_displays.size())


## ======== CONECTAR SEÑALES ========

func _connect_signals() -> void:
	print("[GameBoard] Conectando señales...")
	
	# Señales del jugador
	player_state.cosmos_changed.connect(_on_player_cosmos_changed)
	player_state.health_changed.connect(_on_player_health_changed)
	
	# Señales del oponente
	opponent_state.cosmos_changed.connect(_on_opponent_cosmos_changed)
	opponent_state.health_changed.connect(_on_opponent_health_changed)
	
	# Señales de juego
	card_play_manager.card_played.connect(_on_card_played)
	card_play_manager.cost_not_affordable.connect(_on_cost_not_affordable)
	
	# Señales de servidor (WebSocket)
	MatchManager.match_state_updated.connect(_on_match_state_updated)
	
	print("  ✓ Todas las señales conectadas")


## ======== MANEJADORES DE SEÑALES: ESTADO JUGADOR ========

func _on_player_cosmos_changed(new_amount: int, old_amount: int) -> void:
	print("[GameBoard] Cosmos del jugador: %d → %d" % [old_amount, new_amount])
	
	# Actualizar UI
	if has_node("CosmosLabel"):
		$CosmosLabel.text = str(new_amount)
	
	# Actualizar barra visual
	if has_node("CosmosBar"):
		$CosmosBar.value = new_amount
	
	# Efecto visual opcional
	if new_amount > old_amount:
		# Subió cosmos (adquirida de algún lado)
		animation_manager.animate_mode_change($CosmosLabel, "change", 0.2)
	elif new_amount < old_amount:
		# Bajó cosmos (se gastó)
		animation_manager.animate_take_damage($CosmosLabel)


func _on_player_health_changed(new_amount: int, old_amount: int) -> void:
	print("[GameBoard] Salud del jugador: %d → %d" % [old_amount, new_amount])
	
	# Actualizar UI
	if has_node("HealthLabel"):
		$HealthLabel.text = str(new_amount)
	
	if has_node("HealthBar"):
		$HealthBar.value = new_amount
	
	# Efecto visual si recibió daño
	if new_amount < old_amount:
		animation_manager.animate_take_damage($PlayerAvatar)
		
		# Verificar si fue derrotado
		if new_amount <= 0:
			player_state.player_defeated.emit()
			_on_player_defeated()


func _on_opponent_cosmos_changed(new_amount: int, old_amount: int) -> void:
	print("[GameBoard] Cosmos del oponente: %d → %d" % [old_amount, new_amount])
	if has_node("OpponentCosmosLabel"):
		$OpponentCosmosLabel.text = str(new_amount)


func _on_opponent_health_changed(new_amount: int, old_amount: int) -> void:
	print("[GameBoard] Salud del oponente: %d → %d" % [old_amount, new_amount])
	if has_node("OpponentHealthLabel"):
		$OpponentHealthLabel.text = str(new_amount)


## ======== MANEJADORES DE SEÑALES: JUEGO ========

func _on_card_clicked_from_hand(card_display: Control) -> void:
	print("[GameBoard] Click en carta desde mano")
	
	# Obtener CardInstance del metadata
	var card_instance = card_display.get_meta("card_instance") as CardInstance
	if not card_instance or not card_instance.base_data:
		push_error("CardInstance no válida en metadata")
		return
	
	print("[GameBoard] Intentando jugar: %s (costo=%d)" % [
		card_instance.base_data.name,
		card_instance.base_data.cost
	])
	
	# Validar que puede jugar
	if not card_play_manager.can_play_card(card_instance, player_state.current_cosmos):
		print("[GameBoard] No puede jugar, cosmos insuficiente")
		return
	
	# Determinar zona según tipo de carta
	var zone: String
	match card_instance.base_data.type:
		"knight":
			zone = "field_knight"
		"technique":
			zone = "field_technique"
		"item":
			zone = "field_item"
		_:
			push_error("Tipo de carta desconocido: %s" % card_instance.base_data.type)
			return
	
	# Obtener grupo de slots correspondiente
	var slot_group: SlotGroup = null
	match zone:
		"field_knight":
			slot_group = player_knight_slots_group
		"field_technique":
			slot_group = player_technique_slots_group
	
	# Verificar que hay slots disponibles
	var target_slot = slot_group.get_first_empty_slot()
	if not target_slot:
		print("[GameBoard] No hay slots disponibles")
		return
	
	# Jugar la carta
	print("[GameBoard] Jugando carta a zona '%s', slot %d" % [zone, target_slot.slot_index])
	card_play_manager.play_card_to_field(
		card_instance,
		zone,
		target_slot.slot_index,
		player_state.current_cosmos
	)


func _on_card_played(card_instance: CardInstance, success: bool) -> void:
	print("[GameBoard] Resultado de juego: %s" % ("éxito" if success else "fallo"))
	
	if success:
		# Restar cosmos
		var cost = card_instance.base_data.cost
		player_state.subtract_cosmos(cost)
		
		# Encontrar CardDisplay y animar
		var card_display = _find_card_display_by_instance(card_instance)
		if card_display:
			var slot = _find_slot_for_instance(card_instance)
			if slot:
				# Animar hacia el slot
				animation_manager.animate_card_play(
					card_display,
					slot.global_position
				)
			
			# Remover de mano después de animación
			await get_tree().create_timer(0.4).timeout
			player_hand.remove_card(card_display)


func _on_cost_not_affordable(card_instance: CardInstance, required: int, available: int) -> void:
	print("[GameBoard] Cosmos insuficiente: requiere %d, tiene %d" % [required, available])
	
	# Mostrar error en UI
	if has_node("ErrorLabel"):
		$ErrorLabel.text = "Cosmos insuficiente (%d/%d)" % [available, required]
		$ErrorLabel.show()
		await get_tree().create_timer(3.0).timeout
		$ErrorLabel.hide()


## ======== MANEJADORES DE SEÑALES: SERVIDOR ========

func _on_match_state_updated(match_data: Dictionary) -> void:
	print("[GameBoard] Actualización de servidor recibida")
	
	# Crear GameState a partir de datos del servidor
	var game_state = GameState.from_server_data(match_data, AuthManager.get_user_id())
	
	# Renderizar todos los elementos
	render_all_zones()


## ======== RENDERIZAR UI ========

func render_all_zones() -> void:
	print("[GameBoard] Renderizando todas las zonas...")
	
	# Limpiar todo primero
	_clear_all_zones()
	
	# Renderizar manos
	_render_player_hand()
	_render_opponent_hand()
	
	# Renderizar campos
	_render_player_field()
	_render_opponent_field()
	
	# Actualizar contadores de mazos
	_update_pile_counts()


func _clear_all_zones() -> void:
	# Limpiar usando SlotGroups (una línea por grupo!)
	player_knight_slots_group.clear_all()
	player_technique_slots_group.clear_all()
	opponent_knight_slots_group.clear_all()
	opponent_technique_slots_group.clear_all()
	
	# Limpiar manos
	player_hand.clear_cards()
	opponent_hand.clear_cards()


func _render_player_hand() -> void:
	# Aquí iría código para renderizar mano desde game_state
	print("[GameBoard] Mano del jugador renderizada")


func _render_opponent_hand() -> void:
	# Mostrar card backs (sin saber qué cartas son)
	print("[GameBoard] Mano del oponente renderizada")


func _render_player_field() -> void:
	# Renderizar caballeros y técnicas del jugador
	print("[GameBoard] Campo del jugador renderizado")


func _render_opponent_field() -> void:
	# Renderizar caballeros y técnicas del oponente
	print("[GameBoard] Campo del oponente renderizado")


func _update_pile_counts() -> void:
	# Actualizar contadores del mazo
	player_deck.set_count(deck_loader.get_remaining_deck_count())
	opponent_deck.set_count(40)  # Placeholder, obtener del servidor


## ======== UTILIDADES PRIVADAS ========

func _find_card_display_by_instance(card_instance: CardInstance) -> Control:
	# Buscar en mano del jugador
	for card in player_hand.get_cards():
		if card.get_meta("instance_id") == card_instance.instance_id:
			return card
	return null


func _find_slot_for_instance(card_instance: CardInstance) -> CardSlot:
	# Buscar en slots según tipo
	var slot_group: SlotGroup = null
	if card_instance.base_data.type == "knight":
		slot_group = player_knight_slots_group
	else:
		slot_group = player_technique_slots_group
	
	# Encontrar primer slot ocupado con esta carta (después de jugar)
	for slot in slot_group.all_slots:
		if not slot.is_empty():
			var card = slot.get_card()
			if card and card.get_meta("instance_id") == card_instance.instance_id:
				return slot
	
	return null


func _on_player_defeated() -> void:
	print("[GameBoard] ¡El jugador fue derrotado!")
	# Mostrar game over, volver a menú, etc


## ======== DEBUG ========

func _print_game_status() -> void:
	print("\n=== ESTADO DE JUEGO ===")
	print("Jugador:")
	print("  Cosmos: %d/%d" % [player_state.current_cosmos, player_state.max_cosmos])
	print("  Salud: %d/%d" % [player_state.current_health, player_state.max_health])
	print(player_knight_slots_group.get_debug_status())
	print(player_technique_slots_group.get_debug_status())
	print("\nOponente:")
	print("  Cosmos: %d/%d" % [opponent_state.current_cosmos, opponent_state.max_cosmos])
	print("  Salud: %d/%d" % [opponent_state.current_health, opponent_state.max_health])
	print(opponent_knight_slots_group.get_debug_status())
	print(opponent_technique_slots_group.get_debug_status())
	print("=====================\n")

