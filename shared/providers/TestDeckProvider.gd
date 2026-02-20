# TestDeckProvider.gd
# Implementación para TEST: obtiene deck actual del usuario
# Reutilizable en: TestBoard, Tutorial, Práctica local

class_name TestDeckProvider
extends PlayerDeckProvider

# ---------------------------------------------------------
# ESTADO
# ---------------------------------------------------------
var _deck_with_cards: Dictionary = {}


# ---------------------------------------------------------
# API PÚBLICA
# ---------------------------------------------------------
func get_player_deck() -> Dictionary:
	"""Retorna el deck actual del jugador"""
	return _deck_with_cards


func prepare() -> void:
	"""Fetch: mazo activo + cartas del servidor"""
	_fetch_active_deck()


# ---------------------------------------------------------
# IMPLEMENTACIÓN: Fetch deck activo
# ---------------------------------------------------------
func _fetch_active_deck() -> void:
	"""Paso 1: Sincronizar mazos con servidor"""
	if not DecksManager:
		print("[TestDeckProvider] ❌ Error: DecksManager no disponible")
		return
	
	# Forzar refresh desde servidor
	DecksManager.fetch_user_decks(true)
	
	if not DecksManager.decks_loaded.is_connected(_on_decks_loaded):
		DecksManager.decks_loaded.connect(_on_decks_loaded)


func _on_decks_loaded(_decks: Array) -> void:
	"""Paso 2: Obtener cartas del mazo activo"""
	DecksManager.decks_loaded.disconnect(_on_decks_loaded)
	
	print("[TestDeckProvider] ✅ Mazos sincronizados: %d disponibles" % _decks.size())
	
	# Obtener mazo activo
	var deck = DecksManager.get_active_deck()
	
	if not deck or deck.is_empty():
		print("[TestDeckProvider] ❌ Error: No hay mazo activo. Crea uno primero.")
		return
	
	var deck_id = deck.get("id")
	if not deck_id:
		print("[TestDeckProvider] ❌ Error: Mazo sin ID")
		return
	
	# Obtener cartas del deck
	DecksManager.fetch_deck(deck_id)
	
	if not DecksManager.deck_updated.is_connected(_on_deck_loaded):
		DecksManager.deck_updated.connect(_on_deck_loaded)


func _on_deck_loaded(deck_with_cards: Dictionary) -> void:
	"""Paso 3: Deck cargado, emitir ready"""
	DecksManager.deck_updated.disconnect(_on_deck_loaded)
	
	print("[TestDeckProvider] ✅ Deck cargado: %d tipos de cartas" % deck_with_cards.get("cards", []).size())
	
	_deck_with_cards = deck_with_cards
	
	deck_provider_ready.emit(deck_with_cards)
