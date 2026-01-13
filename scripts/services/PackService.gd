# PackService.gd
# Servicio de acceso a endpoints de sobres
class_name PackService
extends Node


func _ready() -> void:
	pass


func set_auth_token(token: String) -> void:
	if ApiClient:
		ApiClient.set_auth_token(token)


func fetch_available_packs() -> void:
	if ApiClient:
		ApiClient.get_request("/packs/available", "fetch_available_packs", true)


func fetch_user_packs() -> void:
	if ApiClient:
		ApiClient.get_request("/packs/my-packs", "fetch_user_packs", true)


func purchase_pack(pack_id: String, quantity: int) -> void:
	var body := {
		"pack_id": pack_id,
		"quantity": quantity
	}
	if ApiClient:
		ApiClient.post("/packs/buy", body, "purchase_pack", true)


func open_pack(user_pack_id: String) -> void:
	var body := {"user_pack_id": user_pack_id}
	if ApiClient:
		ApiClient.post("/packs/open", body, "open_pack", true)
