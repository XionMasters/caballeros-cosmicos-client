# SessionManager.gd
# Gestiona la persistencia de sesión (tokens, settings)
class_name SessionManager
extends Node

# user:// es la carpeta de datos del usuario del SO (AppData en Windows):
# el token no viaja si alguien copia la carpeta del juego.
const TOKEN_FILE := "user://auth_token.save"
const SETTINGS_FILE := "user://session_settings.save"
# Ubicación anterior (junto al ejecutable); se migra y se borra al cargar.
const LEGACY_TOKEN_FILE := "user_data/auth_token.save"
const LEGACY_SETTINGS_FILE := "user_data/session_settings.save"
# Margen para no usar un token a punto de vencer
const EXPIRY_MARGIN_SECONDS := 60

signal token_loaded(token: String)
signal token_saved()
signal token_deleted()


func _ready() -> void:
	_migrate_legacy_files()


func _migrate_legacy_files() -> void:
	"""Mover token/settings de la carpeta junto al ejecutable a user:// y borrar los antiguos"""
	for pair in [[LEGACY_TOKEN_FILE, TOKEN_FILE], [LEGACY_SETTINGS_FILE, SETTINGS_FILE]]:
		var legacy_path := ProjectSettings.globalize_path(pair[0])
		if not FileAccess.file_exists(legacy_path):
			continue
		if not FileAccess.file_exists(pair[1]):
			var content := FileAccess.get_file_as_string(legacy_path)
			var file := FileAccess.open(pair[1], FileAccess.WRITE)
			if file:
				file.store_string(content)
				file.close()
		DirAccess.remove_absolute(legacy_path)
		print("[Session] Archivo de sesión migrado a user://: %s" % pair[0])


func save_token(token: String) -> bool:
	"""Guardar token JWT en la carpeta de datos del usuario"""
	var file := FileAccess.open(TOKEN_FILE, FileAccess.WRITE)
	if file:
		file.store_string(token)
		file.close()
		print("[Session] Token guardado")
		token_saved.emit()
		return true
	else:
		push_error("[Session] Error al guardar token: " + str(FileAccess.get_open_error()))
		return false


func load_token() -> String:
	"""Cargar token JWT guardado"""
	if not FileAccess.file_exists(TOKEN_FILE):
		print("[Session] No hay token guardado")
		return ""

	var file := FileAccess.open(TOKEN_FILE, FileAccess.READ)
	if file:
		var token := file.get_as_text().strip_edges()
		file.close()
		
		if token != "":
			print("[Session] Token cargado desde disco")
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
	if FileAccess.file_exists(TOKEN_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TOKEN_FILE))
		print("[Session] Token eliminado")
		token_deleted.emit()


func has_saved_token() -> bool:
	"""Verificar si existe un token guardado"""
	return FileAccess.file_exists(TOKEN_FILE)


func _is_token_expired(token: String) -> bool:
	"""Verificar si el JWT está expirado"""
	# JWT tiene 3 partes separadas por puntos: header.payload.signature
	var parts = token.split(".")
	if parts.size() != 3:
		print("[Session] ⚠️ Token JWT inválido (no tiene 3 partes)")
		return true
	
	# El payload del JWT está en base64url: pasar a base64 estándar
	var payload_b64: String = parts[1].replace("-", "+").replace("_", "/")

	# Agregar padding si falta (base64 requiere múltiplos de 4)
	while payload_b64.length() % 4 != 0:
		payload_b64 += "="

	var decoded := Marshalls.base64_to_utf8(payload_b64)
	var payload = JSON.parse_string(decoded)

	# Sin poder leer 'exp' no se puede confiar en el token: descartarlo
	# (el servidor siempre emite tokens con exp)
	if not payload is Dictionary or not payload.has("exp"):
		print("[Session] ⚠️ Token sin claim 'exp' legible, descartando")
		return true

	# exp es tiempo Unix en segundos: comparar con la hora real del sistema
	var current_time := int(Time.get_unix_time_from_system())
	var expiration_time := int(payload["exp"])

	if current_time + EXPIRY_MARGIN_SECONDS > expiration_time:
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
