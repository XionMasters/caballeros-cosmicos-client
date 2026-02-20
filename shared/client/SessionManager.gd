# SessionManager.gd
# Gestiona la persistencia de sesión (tokens, settings)
class_name SessionManager
extends Node

# Guardar en carpeta local (junto a ejecutable) en lugar de user://
const TOKEN_FILE := "user_data/auth_token.save"
const SETTINGS_FILE := "user_data/session_settings.save"

signal token_loaded(token: String)
signal token_saved()
signal token_deleted()


func _ensure_data_dir() -> void:
	"""Crear directorio user_data si no existe"""
	var data_dir = ProjectSettings.globalize_path("user_data")
	DirAccess.make_dir_recursive_absolute(data_dir)


func save_token(token: String) -> bool:
	"""Guardar token JWT en disco (carpeta local)"""
	_ensure_data_dir()
	
	var file_path = ProjectSettings.globalize_path(TOKEN_FILE)
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(token)
		file.close()
		print("[Session] Token guardado en: %s" % file_path)
		token_saved.emit()
		return true
	else:
		push_error("[Session] Error al guardar token: " + str(FileAccess.get_open_error()))
		return false


func load_token() -> String:
	"""Cargar token JWT desde disco (carpeta local)"""
	var file_path = ProjectSettings.globalize_path(TOKEN_FILE)
	
	if not FileAccess.file_exists(file_path):
		print("[Session] No hay token guardado en: %s" % file_path)
		return ""
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file:
		var token := file.get_as_text().strip_edges()
		file.close()
		
		if token != "":
			print("[Session] Token cargado desde disco: %s" % file_path)
			# Validar que no esté expirado
			if _is_token_expired(token):
				print("[Session] ⚠️ Token expirado, eliminando...")
				delete_token()
				return ""
			
			token_loaded.emit(token)
			return token
	
	return ""


func delete_token() -> void:
	"""Eliminar token guardado"""
	var file_path = ProjectSettings.globalize_path(TOKEN_FILE)
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		print("[Session] Token eliminado")
		token_deleted.emit()


func has_saved_token() -> bool:
	"""Verificar si existe un token guardado"""
	var file_path = ProjectSettings.globalize_path(TOKEN_FILE)
	return FileAccess.file_exists(file_path)


func _is_token_expired(token: String) -> bool:
	"""Verificar si el JWT está expirado"""
	# JWT tiene 3 partes separadas por puntos: header.payload.signature
	var parts = token.split(".")
	if parts.size() != 3:
		print("[Session] ⚠️ Token JWT inválido (no tiene 3 partes)")
		return true
	
	# Decodificar payload (está en base64)
	var payload_b64 = parts[1]
	
	# Agregar padding si falta (base64 requiere múltiplos de 4)
	while payload_b64.length() % 4 != 0:
		payload_b64 += "="
	
	# Decodificar
	var decoded = Marshalls.base64_to_utf8(payload_b64)
	var payload = JSON.parse_string(decoded)
	
	if payload == null or not payload.has("exp"):
		print("[Session] ⚠️ Token sin claim 'exp', asumiendo válido")
		return false
	
	# Comparar con tiempo actual (en segundos)
	var current_time = int(float(Time.get_ticks_msec()) / 1000.0)
	var expiration_time = payload["exp"]
	
	if current_time > expiration_time:
		print("[Session] ⚠️ Token expirado hace %d segundos" % (current_time - expiration_time))
		return true
	
	var remaining = expiration_time - current_time
	print("[Session] ✅ Token válido, vence en %d segundos (~%.1f horas)" % [remaining, remaining / 3600.0])
	return false


func save_setting(key: String, value: Variant) -> bool:
	"""Guardar configuración de sesión"""
	var settings := load_all_settings()
	settings[key] = value
	
	var file := FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings))
		file.close()
		return true
	return false


func load_setting(key: String, default_value: Variant = null) -> Variant:
	"""Cargar configuración de sesión"""
	var settings := load_all_settings()
	return settings.get(key, default_value)


func load_all_settings() -> Dictionary:
	"""Cargar todas las configuraciones"""
	if not FileAccess.file_exists(SETTINGS_FILE):
		return {}
	
	var file := FileAccess.open(SETTINGS_FILE, FileAccess.READ)
	if file:
		var json_string := file.get_as_text()
		file.close()
		
		var json := JSON.new()
		if json.parse(json_string) == OK and typeof(json.data) == TYPE_DICTIONARY:
			return json.data
	
	return {}


func clear_all() -> void:
	"""Limpiar toda la sesión"""
	delete_token()
	if FileAccess.file_exists(SETTINGS_FILE):
		DirAccess.remove_absolute(SETTINGS_FILE)
	print("[Session] Sesión limpiada completamente")
