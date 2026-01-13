# UserManager.gd
# Gestiona el perfil del usuario actual (NO autenticación)
extends Node

signal profile_updated(profile: UserProfile)
signal profile_loaded(profile: UserProfile)
signal currency_changed(new_amount: int)
signal active_deck_changed(deck_id: String)

var current_profile: UserProfile = null


func _ready() -> void:
	# Esperar a que ApiClient esté listo
	await get_tree().process_frame
	
	# Conectar a las respuestas de ApiClient
	if ApiClient:
		ApiClient.request_completed.connect(_on_api_request_completed)


func set_profile(profile: UserProfile) -> void:
	"""Establecer perfil actual"""
	current_profile = profile
	print("[UserManager] Perfil cargado: ", profile.get_display_name())
	profile_loaded.emit(profile)


func clear_profile() -> void:
	"""Limpiar perfil actual"""
	current_profile = null


func has_profile() -> bool:
	"""Verificar si hay un perfil cargado"""
	return current_profile != null


func get_profile() -> UserProfile:
	"""Obtener perfil actual"""
	return current_profile


func fetch_profile(token: String) -> void:
	"""Obtener perfil desde el servidor"""
	if ApiClient:
		ApiClient.set_auth_token(token)
		ApiClient.get_request("/users/me", "fetch_profile", true)


func update_profile_field(field: String, value: Variant) -> void:
	"""Actualizar un campo del perfil en el servidor"""
	if not current_profile:
		push_error("[UserManager] No hay perfil cargado")
		return
	var body := {field: value}
	if ApiClient:
		ApiClient.put("/users/me", body, "update_profile_field", true)


func get_username() -> String:
	"""Obtener nombre de usuario"""
	if current_profile:
		return current_profile.get_display_name()
	return "Invitado"


func get_currency() -> int:
	"""Obtener monedas del usuario"""
	if current_profile:
		return current_profile.currency
	return 0


func get_user_id() -> String:
	"""Obtener ID del usuario"""
	if current_profile:
		return current_profile.id
	return ""


func get_active_deck_id() -> String:
	"""Obtener ID del mazo activo"""
	if current_profile:
		return current_profile.active_deck_id
	return ""


func has_active_deck() -> bool:
	"""Verificar si tiene mazo activo"""
	if current_profile:
		return current_profile.has_active_deck()
	return false


func update_currency(new_amount: int) -> void:
	"""Actualizar monedas localmente (desde servidor)"""
	if current_profile:
		current_profile.currency = new_amount
		currency_changed.emit(new_amount)
		profile_updated.emit(current_profile)


func set_active_deck(deck_id: String) -> void:
	"""Establecer mazo activo"""
	if current_profile:
		current_profile.active_deck_id = deck_id
		active_deck_changed.emit(deck_id)
		profile_updated.emit(current_profile)
	
	# Actualizar en servidor
	update_profile_field("active_deck_id", deck_id)


func get_win_rate() -> float:
	"""Obtener win rate"""
	if current_profile:
		return current_profile.get_win_rate()
	return 0.0


func get_stats() -> Dictionary:
	"""Obtener estadísticas del usuario"""
	if current_profile:
		return {
			"wins": current_profile.wins,
			"losses": current_profile.losses,
			"total_matches": current_profile.total_matches,
			"win_rate": current_profile.get_win_rate()
		}
	return {"wins": 0, "losses": 0, "total_matches": 0, "win_rate": 0.0}


# ============================================================================
# SIGNAL HANDLING FOR API RESPONSES
# ============================================================================

func _on_api_request_completed(tag: String, success: bool, data: Variant, error: String) -> void:
	match tag:
		"fetch_profile":
			if success and data:
				var profile := UserProfile.from_dict(data)
				set_profile(profile)
				print("[UserManager] ✅ Perfil obtenido: ", profile.username)
				print("[UserManager] 💰 Monedas: ", profile.currency)
				profile_loaded.emit(profile)
			else:
				push_error("[UserManager] Error al obtener perfil: " + error)
		
		"update_profile_field":
			if success and data:
				if current_profile:
					current_profile.update_from_dict(data)
					profile_updated.emit(current_profile)
					print("[UserManager] ✅ Perfil actualizado")
			else:
				push_error("[UserManager] Error al actualizar perfil: " + error)
		
		_:
			pass
