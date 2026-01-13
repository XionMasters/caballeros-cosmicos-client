# DecksManager.gd
# Manager para gestionar mazos (decks) del usuario
extends Node

signal decks_loaded(decks: Array)
signal deck_created(deck: Dictionary)
signal deck_updated(deck: Dictionary)
signal deck_deleted(deck_id: String)
signal card_added_to_deck(deck_id: String, card_id: String)
signal card_removed_from_deck(deck_id: String, card_id: String)
signal deck_validated(validation: Dictionary)
signal deck_stats_loaded(stats: Dictionary)
signal deck_generated(deck: Dictionary, info: Dictionary)
signal error_occurred(message: String)

var _decks: Array = []
var _active_deck: Dictionary = {}
var _decks_cached: bool = false

# ==========================================================
# Fetch
# ==========================================================

func fetch_user_decks(force_refresh: bool = false):
	if _decks_cached and not force_refresh:
		print("[DecksManager] 💾 Usando caché local de %d mazos" % _decks.size())
		decks_loaded.emit(_decks)
		return

	ApiClient.get_request_with_callback(
		"/decks",
		"fetch_user_decks",
		_on_decks_loaded
	)

func fetch_deck(deck_id: String):
	ApiClient.get_request_with_callback(
		"/decks/%s" % deck_id,
		"fetch_deck",
		_on_deck_loaded
	)

# ==========================================================
# Deck CRUD
# ==========================================================

func create_deck(deck_name: String, description: String = ""):
	ApiClient.post_request_with_callback(
		"/decks",
		{
			"name": deck_name,
			"description": description
		},
		"create_deck",
		_on_deck_created
	)

func update_deck(deck_id: String, deck_name := "", description := "", is_active := false):
	if deck_id == "":
		push_error("[DecksManager] ❌ deck_id requerido")
		error_occurred.emit("deck_id requerido")
		return

	var body := {}

	if deck_name != "":
		body.name = deck_name
	if description != "":
		body.description = description

	body.is_active = is_active

	ApiClient.put_request_with_callback(
		"/decks/%s" % deck_id,
		body,
		"update_deck",
		_on_deck_updated
	)

func delete_deck(deck_id: String):
	ApiClient.delete_request_with_callback(
		"/decks/%s" % deck_id,
		"delete_deck",
		func(success: bool, _data: Variant, error: String):
			_on_deck_deleted(deck_id, success, error)
	)

# ==========================================================
# Cards
# ==========================================================

func add_card_to_deck(deck_id: String, card_id: String, quantity: int = 1):
	if quantity <= 0:
		push_error("[DecksManager] ❌ Cantidad debe ser > 0, recibido: %d" % quantity)
		error_occurred.emit("Cantidad debe ser positiva")
		return

	ApiClient.post_request_with_callback(
		"/decks/%s/cards" % deck_id,
		{
			"card_id": card_id,
			"quantity": quantity
		},
		"add_card_to_deck",
		func(success: bool, _data: Variant, error: String):
			if not success:
				push_error("[DecksManager] ❌ Error agregando carta: %s" % error)
				error_occurred.emit(error)
				return
			print("[DecksManager] ✅ Carta %s agregada a mazo" % card_id)
			card_added_to_deck.emit(deck_id, card_id)
	)

func remove_card_from_deck(deck_id: String, card_id: String):
	ApiClient.delete_request_with_callback(
		"/decks/%s/cards/%s" % [deck_id, card_id],
		"remove_card_from_deck",
		func(success: bool, _data: Variant, error: String):
			if not success:
				error_occurred.emit(error)
				return
			card_removed_from_deck.emit(deck_id, card_id)
	)

func update_card_quantity(deck_id: String, card_id: String, quantity: int):
	ApiClient.put_request_with_callback(
		"/decks/%s/cards/%s" % [deck_id, card_id],
		{ "quantity": quantity },
		"update_card_quantity",
		func(success: bool, _data: Variant, error: String):
			if not success:
				error_occurred.emit(error)
				return
			card_added_to_deck.emit(deck_id, card_id)
	)

func sync_deck_cards(deck_id: String, cards_array: Array):
	ApiClient.put_request_with_callback(
		"/decks/%s/sync-cards" % deck_id,
		{ "cards": cards_array },
		"sync_deck_cards",
		_on_deck_synced
	)

# ==========================================================
# Extra
# ==========================================================

func validate_deck(deck_id: String):
	ApiClient.get_request_with_callback(
		"/decks/%s/validate" % deck_id,
		"validate_deck",
		_on_deck_validated
	)

func fetch_deck_stats(deck_id: String):
	ApiClient.get_request_with_callback(
		"/decks/%s/stats" % deck_id,
		"fetch_deck_stats",
		_on_deck_stats_loaded
	)

func auto_generate_deck(deck_id: String, strategy := "balanced", element := "", faction := ""):
	var body := {
		"strategy": strategy,
		"targetCards": 45,
		"maxLegendaries": 5
	}

	if element != "":
		body.element = element
	if faction != "":
		body.faction = faction

	ApiClient.post_request_with_callback(
		"/decks/%s/generate" % deck_id,
		body,
		"auto_generate_deck",
		_on_deck_generated
	)

# ==========================================================
# Callbacks
# ==========================================================

func _on_decks_loaded(success: bool, data: Variant, error: String):
	if not success:
		push_error("[DecksManager] ❌ Error cargando mazos: %s" % error)
		error_occurred.emit(error)
		return

	if data is not Array:
		push_error("[DecksManager] ❌ Respuesta inválida: no es array")
		error_occurred.emit("Formato de respuesta inválido")
		return

	_decks = data
	_decks_cached = true
	_active_deck = {}

	for deck in _decks:
		if deck.get("is_active", false):
			_active_deck = deck
			break

	print("[DecksManager] ✅ %d mazos cargados (mazo activo: %s)" % [_decks.size(), _active_deck.get("name", "ninguno")])
	decks_loaded.emit(_decks)

func _on_deck_loaded(success: bool, data: Variant, error: String):
	if not success:
		error_occurred.emit(error)
		return

	deck_updated.emit(data)

func _on_deck_created(success: bool, data: Variant, error: String):
	if not success:
		push_error("[DecksManager] ❌ Error creando mazo: %s" % error)
		error_occurred.emit(error)
		return

	_decks.append(data)
	_decks_cached = false  # Invalidar caché
	print("[DecksManager] ✅ Mazo '%s' creado" % data.get("name", "sin nombre"))
	deck_created.emit(data)

func _on_deck_updated(success: bool, data: Variant, error: String):
	if not success:
		push_error("[DecksManager] ❌ Error actualizando mazo: %s" % error)
		error_occurred.emit(error)
		return

	_decks_cached = false  # Invalidar caché
	print("[DecksManager] ✅ Mazo actualizado")
	deck_updated.emit(data)

func _on_deck_deleted(deck_id: String, success: bool, error: String):
	if not success:
		push_error("[DecksManager] ❌ Error eliminando mazo: %s" % error)
		error_occurred.emit(error)
		return

	_decks = _decks.filter(func(d): return d.get("id") != deck_id)
	_decks_cached = false  # Invalidar caché

	if _active_deck.get("id") == deck_id:
		_active_deck = {}

	print("[DecksManager] ✅ Mazo %s eliminado" % deck_id)
	deck_deleted.emit(deck_id)

func _on_deck_synced(success: bool, data: Variant, error: String):
	if not success:
		push_error("[DecksManager] ❌ Error sincronizando mazo: %s" % error)
		error_occurred.emit(error)
		return

	_decks_cached = false  # Invalidar caché
	print("[DecksManager] ✅ Mazo sincronizado")
	if data is Dictionary:
		deck_updated.emit(data)

func _on_deck_validated(success: bool, data: Variant, error: String):
	if not success:
		push_error("[DecksManager] ❌ Error validando mazo: %s" % error)
		error_occurred.emit(error)
		return

	var is_valid = data.get("valid", false)
	print("[DecksManager] %s Validación: %s" % ["✅" if is_valid else "⚠️", "válido" if is_valid else "inválido"])
	deck_validated.emit(data)

func _on_deck_stats_loaded(success: bool, data: Variant, error: String):
	if not success:
		push_error("[DecksManager] ❌ Error cargando estadísticas: %s" % error)
		error_occurred.emit(error)
		return

	print("[DecksManager] ✅ Estadísticas de mazo cargadas")
	deck_stats_loaded.emit(data)

func _on_deck_generated(success: bool, data: Variant, error: String):
	if not success:
		push_error("[DecksManager] ❌ Error generando mazo: %s" % error)
		error_occurred.emit(error)
		return

	var deck : Dictionary = data.get("deck", {})
	var info : Dictionary = data.get("generation_info", {})
	print("[DecksManager] ✅ Mazo generado automáticamente (%s)" % info.get("strategy", "unknown"))
	deck_generated.emit(deck, info)

# ==========================================================
# Getters
# ==========================================================

func get_active_deck() -> Dictionary:
	return _active_deck

func get_all_decks() -> Array:
	return _decks

func get_deck(deck_id: String) -> Dictionary:
	for deck in _decks:
		if deck.get("id") == deck_id:
			return deck
	return {}
