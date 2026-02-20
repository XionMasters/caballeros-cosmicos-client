# InstanceManager.gd
# Previene múltiples instancias del programa con el mismo usuario
# Usa un archivo de lock para sincronizar
class_name InstanceManager
extends Node

const LOCK_DIR := "user_data"  # Carpeta donde guardar locks
const LOCK_EXTENSION := ".lock"

var current_user_id: String = ""
var lock_file_path: String = ""


func _notification(what: int) -> void:
	"""Cleanup al salir"""
	if what == NOTIFICATION_PREDELETE:
		release_lock()


func create_lock(user_id: String, force_replace: bool = false) -> bool:
	"""Crear un archivo de lock para un usuario
	
	Args:
		user_id: ID del usuario
		force_replace: Si true, reemplaza lock anterior aunque esté "activo" (para login/auto-login)
	
	Returns:
		true si se creó exitosamente
		false si hay otra instancia (y force_replace=false)
	"""
	current_user_id = user_id
	lock_file_path = get_lock_file_path(user_id)
	
	# Crear directorio si no existe
	_ensure_lock_dir_exists()
	
	# Si el archivo ya existe, verificar si es un lock stale
	if FileAccess.file_exists(lock_file_path):
		# Intentar leer el lock anterior
		var lock_data = _read_lock_file(lock_file_path)
		if lock_data:
			var old_pid = lock_data.get("pid", -1)
			var lock_timestamp = lock_data.get("timestamp", 0)
			var current_time = Time.get_ticks_msec()
			var lock_age = current_time - lock_timestamp
			
			# Si el proceso PID no existe Y el lock tiene más de 30 segundos, es stale
			if old_pid != -1 and not _is_process_alive(old_pid) and lock_age > 30000:
				print("[InstanceManager] 🧹 Lock stale detectado (PID %d, edad: %.1fs), limpiando..." % [old_pid, lock_age / 1000.0])
				DirAccess.remove_absolute(lock_file_path)
				# Continuar para crear nuevo lock
			elif force_replace:
				# force_replace=true: reemplazar lock aunque parezca activo
				print("[InstanceManager] 🔄 Reemplazando lock anterior (PID %d) - force_replace=true" % old_pid)
				DirAccess.remove_absolute(lock_file_path)
				# Continuar para crear nuevo lock
			else:
				# Lock es válido (proceso vivo o lock reciente) y NO forzar
				print("[InstanceManager] ⚠️ ADVERTENCIA: Usuario '%s' ya tiene una sesión abierta (PID: %d)" % [user_id, old_pid])
				return false
		else:
			# No se pudo leer lock pero existe - asumir stale
			print("[InstanceManager] 🧹 Lock corrupto detectado, limpiando...")
			DirAccess.remove_absolute(lock_file_path)
	
	# Crear el archivo de lock con info del proceso
	var file := FileAccess.open(lock_file_path, FileAccess.WRITE)
	if file:
		# Guardar PID del proceso para debugging
		var lock_data = {
			"user_id": user_id,
			"pid": OS.get_process_id(),
			"timestamp": Time.get_ticks_msec()
		}
		file.store_string(JSON.stringify(lock_data))
		file.close()
		print("[InstanceManager] ✅ Lock creado para usuario '%s'" % user_id)
		return true
	else:
		push_error("[InstanceManager] Error al crear lock: " + str(FileAccess.get_open_error()))
		return false


func _read_lock_file(path: String) -> Dictionary:
	"""Leer contenido del archivo de lock"""
	var file := FileAccess.open(path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		var json_result = JSON.parse_string(content)
		if json_result and json_result is Dictionary:
			return json_result as Dictionary
	return {}


func _is_process_alive(pid: int) -> bool:
	"""Verificar si un proceso con el PID especificado está vivo"""
	# En Windows, usar tasklist
	if OS.get_name() == "Windows":
		var output = []
		var err = OS.execute("tasklist", [], output)
		if err == OK and output.size() > 0:
			var tasklist_output = "\n".join(output)
			return str(pid) in tasklist_output
	# En Linux/Mac, usar ps
	else:
		var output = []
		var err = OS.execute("ps", ["-p", str(pid)], output)
		if err == OK and output.size() > 1:  # Header + proceso
			return true
	
	# Si no se puede verificar, asumir que está vivo para ser seguro
	return true


func release_lock() -> void:
	"""Liberar el lock al cerrar sesión"""
	if lock_file_path and FileAccess.file_exists(lock_file_path):
		DirAccess.remove_absolute(lock_file_path)
		print("[InstanceManager] ✅ Lock liberado para usuario '%s'" % current_user_id)
		current_user_id = ""
		lock_file_path = ""


func get_lock_file_path(user_id: String) -> String:
	"""Obtener ruta del archivo de lock para un usuario"""
	var data_dir = ProjectSettings.globalize_path(LOCK_DIR)
	return data_dir.path_join(user_id + LOCK_EXTENSION)


func _ensure_lock_dir_exists() -> void:
	"""Crear directorio de locks si no existe"""
	var data_dir = ProjectSettings.globalize_path(LOCK_DIR)
	DirAccess.make_dir_recursive_absolute(data_dir)
