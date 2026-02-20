# PacksManager.gd
# Gestiona sobres: disponibles, compras y aperturas
extends Node

signal available_packs_loaded(packs: Array)
signal user_packs_loaded(user_packs: Array)
signal pack_purchased(user_pack_id: String, pack_data: Dictionary, new_currency: int)
signal pack_opened(user_pack_id: String, pack_name: String, cards: Array, new_currency: int)
signal error_occurred(message: String)

var _service: PackService = null

func _ready() -> void:
	_service = PackService.new()
	add_child(_service)
	
	# Esperar a que ApiClient esté listo
	await get_tree().process_frame
	
	# Conectar a respuestas de ApiClient
	if ApiClient:
		ApiClient.request_completed.connect(_on_api_request_completed)


func _refresh_token() -> void:
	if AuthManager:
		_service.set_auth_token(AuthManager.get_token())


func fetch_available_packs() -> void:
	_refresh_token()
	_service.fetch_available_packs()


func fetch_user_packs() -> void:
	_refresh_token()
	_service.fetch_user_packs()


func purchase_pack(pack_id: String, quantity: int = 1) -> void:
	if pack_id.is_empty():
		error_occurred.emit("ID de pack inválido")
		return
	_refresh_token()
	_service.purchase_pack(pack_id, quantity)


func open_pack(user_pack_id: String) -> void:
	if user_pack_id.is_empty():
		error_occurred.emit("ID de sobre inválido")
		return
	_refresh_token()
	_service.open_pack(user_pack_id)



# ============================================================================
# SIGNAL HANDLING FOR API RESPONSES
# ============================================================================

func _on_api_request_completed(tag: String, success: bool, data: Variant, error: String) -> void:
	match tag:
		"fetch_available_packs":
			if success and data:
				var packs: Array = []
				if data is Dictionary:
					packs = (data as Dictionary).get("data", data) as Array
				else:
					packs = data as Array
				if packs is Array:
					available_packs_loaded.emit(packs)
					return
				error_occurred.emit(error if error else "No se pudieron cargar los sobres disponibles")
		"fetch_user_packs":
			if success and data:
				var packs: Array = []
				if data is Dictionary:
					packs = (data as Dictionary).get("data", data) as Array
				else:
					packs = data as Array
				if packs is Array:
					user_packs_loaded.emit(packs)
					return
				error_occurred.emit(error if error else "No se pudieron cargar tus sobres")
		"purchase_pack":
			if success and data:
				var payload: Dictionary = {}
				if data is Dictionary:
					payload = (data as Dictionary).get("data", data) as Dictionary
				var user_pack_id: String = payload.get("user_pack_id", "")
				var pack_data: Dictionary = payload.get("pack", payload.get("pack_data", {}))
				var new_currency: int = payload.get("currency", UserManager.get_currency())
				if new_currency != UserManager.get_currency():
					UserManager.update_currency(new_currency)
				if user_pack_id == "":
					error_occurred.emit("Compra realizada pero falta user_pack_id")
					return
				pack_purchased.emit(user_pack_id, pack_data, new_currency)
				return
			else:
				error_occurred.emit(error if error else "No se pudo completar la compra del sobre")
		"open_pack":
			if success and data:
				var payload: Dictionary = {}
				if data is Dictionary:
					payload = (data as Dictionary).get("data", data) as Dictionary
				var pack_name: String = payload.get("pack_name", "Sobre")
				var cards: Array = payload.get("cards", [])
				var new_currency: int = payload.get("currency", UserManager.get_currency())
				if new_currency != UserManager.get_currency():
					UserManager.update_currency(new_currency)
				pack_opened.emit(payload.get("user_pack_id", ""), pack_name, cards, new_currency)
				return
			else:
				error_occurred.emit(error if error else "No se pudo abrir el sobre")
		_:
			pass
