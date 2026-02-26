# MatchFlowController.gd
# Orquesta el flujo completo de iniciación de partida
# Responsabilidades:
#   ✅ Fetch deck activo
#   ✅ Validar deck
#   ✅ Coordinar con MatchSessionService para crear partida
#   ✅ Emitir señales de progreso y error
#
# NO HACE:
#   ❌ Renderizar
#   ❌ Mostrar UI
#   ❌ Lógica de match (eso es MatchSessionService)

class_name MatchFlowController
extends Node

# ---------------------------------------------------------
# SEÑALES
# ---------------------------------------------------------
signal loading(status: String)
signal match_ready(game_state: GameState)
signal match_error(message: String)

# ---------------------------------------------------------
# ESTADO
# ---------------------------------------------------------
var is_loading: bool = false


# ---------------------------------------------------------
# INICIALIZACIÓN
# ---------------------------------------------------------
func _ready() -> void:
	# Escuchar eventos internos de orquestación
	MatchSessionService.match_started.connect(_on_match_started)
	MatchSessionService.match_error.connect(_on_match_error)


# ---------------------------------------------------------
# API PÚBLICA
# ---------------------------------------------------------
func start_test_match() -> void:
	"""Iniciar flujo de partida TEST"""
	if is_loading:
		return
	
	is_loading = true
	loading.emit("Obteniendo mazo activo...")
	_fetch_active_deck()


# ---------------------------------------------------------
# PASO 1: FETCH DECK ACTIVO
# ---------------------------------------------------------
func _fetch_active_deck() -> void:
	"""Sincronizar mazos con servidor"""
	loading.emit("Sincronizando mazos...")
	
	if not DecksManager:
		_error("DecksManager no disponible")
		return
	
	# Forzar refresh desde servidor
	DecksManager.fetch_user_decks(true)
	
	# Conectar callback (una sola vez)
	if not DecksManager.decks_loaded.is_connected(_on_decks_loaded):
		DecksManager.decks_loaded.connect(_on_decks_loaded)


func _on_decks_loaded(_decks: Array) -> void:
	"""Callback: Mazos cargados → obtener cartas del mazo activo"""
	DecksManager.decks_loaded.disconnect(_on_decks_loaded)
	
	print("[MatchFlowController] ✅ Mazos sincronizados: %d disponibles" % _decks.size())
	
	# Obtener mazo activo
	var deck = DecksManager.get_active_deck()
	
	if not deck or deck.is_empty():
		_error("No hay mazo activo. Crea uno primero.")
		return
	
	var deck_id = deck.get("id")
	if not deck_id:
		_error("Error: Mazo sin ID")
		return
	
	# Obtener cartas del deck
	loading.emit("Obteniendo cartas del mazo...")
	DecksManager.fetch_deck(deck_id)
	
	if not DecksManager.deck_updated.is_connected(_on_deck_loaded):
		DecksManager.deck_updated.connect(_on_deck_loaded)


func _on_deck_loaded(deck_with_cards: Dictionary) -> void:
	"""Callback: Deck con cartas cargado → validar"""
	DecksManager.deck_updated.disconnect(_on_deck_loaded)
	
	print("[MatchFlowController] ✅ Deck cargado con cartas")
	
	var cards = deck_with_cards.get("cards", [])
	
	if cards.is_empty():
		_error("El deck no tiene cartas")
		return
	
	# PASO 2: Validar
	_validate_and_request_match(cards)


# ---------------------------------------------------------
# PASO 2: VALIDAR DECK
# ---------------------------------------------------------
func _validate_and_request_match(cards: Array) -> void:
	"""Validar deck (UX mínimo) y solicitar partida"""
	print("[MatchFlowController] 2️⃣ Validando mazo...")
	
	# Contar total de cartas
	var total_cards = _count_deck_cards(cards)
	
	print("[MatchFlowController] 🃏 Total de cartas calculado: %d (de %d tipos)" % [total_cards, cards.size()])
	
	# Validaciones UX (servidor hace validación completa)
	if total_cards < 40:
		_error("El mazo necesita mínimo 40 cartas (%d disponibles)" % total_cards)
		return
	
	if total_cards > 100:
		_error("El mazo no puede tener más de 100 cartas (%d)" % total_cards)
		return
	
	print("[MatchFlowController] ✅ Mazo válido: %d cartas (%d tipos)" % [total_cards, cards.size()])
	
	# PASO 3: Solicitar partida al servidor
	_request_match()


func _count_deck_cards(cards: Array) -> int:
	"""Sumar cantidad total de cartas (respetando DeckCard.quantity)"""
	var total = 0
	
	for card_entry in cards:
		var quantity = 1
		
		if card_entry is Dictionary:
			# Intentar obtener quantity directamente
			quantity = card_entry.get("quantity", 1)
			
			# Si no tiene, buscar en DeckCard (through table)
			if quantity == 1 and card_entry.has("DeckCard"):
				var deck_card = card_entry.get("DeckCard")
				if deck_card is Dictionary:
					quantity = deck_card.get("quantity", 1)
		
		total += int(quantity)
	
	return total


# ---------------------------------------------------------
# PASO 3: SOLICITAR PARTIDA
# ---------------------------------------------------------
func _request_match() -> void:
	"""Solicitar creación de partida TEST al servidor"""
	loading.emit("Iniciando partida en servidor...")
	print("[MatchFlowController] 3️⃣ Pidiendo partida TEST al servidor...")
	
	# MatchSessionService maneja la comunicación WebSocket
	# Emitirá match_started cuando el servidor responda
	MatchSessionService.start_test_match()


# ---------------------------------------------------------
# CALLBACKS: MATCH INICIADA/ERROR
# ---------------------------------------------------------
func _on_match_started(state: GameState) -> void:
	"""Callback: Partida iniciada correctamente"""
	is_loading = false
	
	print("[MatchFlowController] ✅ Partida iniciada correctamente")
	
	# Emitir para que TestBoard lo escuche
	match_ready.emit(state)


func _on_match_error(code: String, msg: String) -> void:
	"""Callback: Error en match"""
	is_loading = false
	
	print("[MatchFlowController] ❌ Error de match: %s - %s" % [code, msg])
	
	# Emitir para que TestBoard lo escuche
	match_error.emit(msg)


# ---------------------------------------------------------
# HELPERS
# ---------------------------------------------------------
func _error(msg: String) -> void:
	"""Procesar error: logging + signal"""
	is_loading = false
	
	print("[MatchFlowController] ❌ %s" % msg)
	match_error.emit(msg)
