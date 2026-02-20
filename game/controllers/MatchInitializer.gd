# MatchInitializer.gd
# Orquestador AGNÓSTICO de iniciación de partida
# Funciona con cualquier PlayerDeckProvider + OpponentProvider
# Reutilizable en: Test, Multijugador, PvE, Tutorial

class_name MatchInitializer
extends Node

# ---------------------------------------------------------
# SIGNALS
# ---------------------------------------------------------
signal loading(status: String)
signal match_ready(game_state: GameState)
signal match_error(message: String)

# ---------------------------------------------------------
# DEPENDENCIES (inyectadas)
# ---------------------------------------------------------
var deck_provider: PlayerDeckProvider
var opponent_provider: OpponentProvider

# ---------------------------------------------------------
# ESTADO
# ---------------------------------------------------------
var is_loading: bool = false
var _current_deck: Dictionary = {}


# ---------------------------------------------------------
# CONSTRUCTOR
# ---------------------------------------------------------
func _init(p_deck_provider: PlayerDeckProvider, p_opponent_provider: OpponentProvider) -> void:
	deck_provider = p_deck_provider
	opponent_provider = p_opponent_provider


# ---------------------------------------------------------
# INICIALIZACIÓN
# ---------------------------------------------------------
func _ready() -> void:
	# Escuchar eventos de MatchManager
	MatchManager.match_started.connect(_on_match_started)
	MatchManager.match_error.connect(_on_match_error)
	
	# Escuchar eventos de los providers
	deck_provider.deck_provider_ready.connect(_on_deck_ready)
	opponent_provider.opponent_provider_ready.connect(_on_opponent_ready)


# ---------------------------------------------------------
# API PÚBLICA
# ---------------------------------------------------------
func start_match() -> void:
	"""Iniciar flujo: prepare providers → validate deck → request match"""
	if is_loading:
		return
	
	is_loading = true
	loading.emit("Preparando partida...")
	print("[MatchInitializer] 1️⃣ Iniciando flujo de partida...")
	
	# Preparar ambos providers en paralelo
	deck_provider.prepare()
	opponent_provider.prepare()


# ---------------------------------------------------------
# CALLBACKS: Providers listos
# ---------------------------------------------------------
func _on_deck_ready(deck: Dictionary) -> void:
	"""Deck provider listo"""
	_current_deck = deck
	print("[MatchInitializer] 📦 Deck listo: %d tipos de cartas" % deck.get("cards", []).size())
	
	# Si opponent también está listo → validar
	if opponent_provider.get_opponent().has("id"):
		_validate_and_request_match()


func _on_opponent_ready(opponent: Dictionary) -> void:
	"""Opponent provider listo"""
	print("[MatchInitializer] 👤 Oponente listo: %s" % opponent.get("name", "Unknown"))
	
	# Si deck también está listo → validar
	if _current_deck.has("cards"):
		_validate_and_request_match()


# ---------------------------------------------------------
# PASO 2: VALIDACIÓN
# ---------------------------------------------------------
func _validate_and_request_match() -> void:
	"""Validar deck (UX) y solicitar partida al servidor"""
	if is_loading == false:
		return  # Ya fue cancelado
	
	print("[MatchInitializer] 2️⃣ Validando deck...")
	
	var cards = _current_deck.get("cards", [])
	if cards.is_empty():
		_error("El deck no tiene cartas")
		return
	
	# Contar total de cartas
	var total_cards = _count_deck_cards(cards)
	print("[MatchInitializer] 🃏 Total de cartas: %d (de %d tipos)" % [total_cards, cards.size()])
	
	# Validaciones (servidor hace validación completa)
	if total_cards < 40:
		_error("El mazo necesita mínimo 40 cartas (%d disponibles)" % total_cards)
		return
	
	if total_cards > 100:
		_error("El mazo no puede tener más de 100 cartas (%d)" % total_cards)
		return
	
	print("[MatchInitializer] ✅ Deck válido: %d cartas" % total_cards)
	
	# PASO 3: Solicitar partida
	_request_match()


func _count_deck_cards(cards: Array) -> int:
	"""Sumar cantidad total de cartas (respetando DeckCard.quantity)"""
	var total = 0
	
	for card_entry in cards:
		var quantity = 1
		
		if card_entry is Dictionary:
			quantity = card_entry.get("quantity", 1)
			
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
	"""Solicitar creación de partida al MatchManager"""
	loading.emit("Iniciando partida en servidor...")
	print("[MatchInitializer] 3️⃣ Pidiendo partida al servidor...")
	
	# MatchManager maneja la comunicación WebSocket
	# Emitirá match_started cuando el servidor responda
	MatchManager.start_test_match()


# ---------------------------------------------------------
# CALLBACKS: Match iniciada/error
# ---------------------------------------------------------
func _on_match_started(state: GameState) -> void:
	"""Partida iniciada correctamente"""
	is_loading = false
	
	print("[MatchInitializer] ✅ Partida iniciada")
	match_ready.emit(state)


func _on_match_error(code: String, msg: String) -> void:
	"""Error en match"""
	is_loading = false
	
	print("[MatchInitializer] ❌ Error de match: %s - %s" % [code, msg])
	match_error.emit(msg)


# ---------------------------------------------------------
# HELPERS
# ---------------------------------------------------------
func _error(msg: String) -> void:
	"""Procesar error"""
	is_loading = false
	
	print("[MatchInitializer] ❌ %s" % msg)
	match_error.emit(msg)
