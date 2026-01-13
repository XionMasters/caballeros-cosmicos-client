
# ApiClient.gd (Singleton Autoload, Godot 4)
# Cliente HTTP robusto con cola, señales, manejo de errores y concurrencia limitada
extends Node

signal request_completed(tag: String, success: bool, data: Variant, error: String)

# -------------------------------------------------------------------
# Configuración
# -------------------------------------------------------------------

const MAX_CONCURRENT_REQUESTS := 4
const MAX_CONCURRENT_IMAGE_REQUESTS := 2
const DEFAULT_TIMEOUT := 10.0
const MAX_RETRIES := 2

var base_url: String = ""
var auth_token: String = ""
var default_headers: PackedStringArray = ["Content-Type: application/json"]

# Estado interno
# Cola JSON
var _queue: Array = []
var _active_requests: int = 0
var _request_id_counter: int = 0
var _callbacks: Dictionary = {} # tag -> Callable

# Cola imágenes
var _image_queue: Array = []
var _active_image_requests : int = 0

func _ready():
	base_url = GameConfig.API_URL

# -------------------------------------------------------------------
# Auth
# -------------------------------------------------------------------

func set_auth_token(token: String) -> void:
	auth_token = token

func get_auth_headers() -> PackedStringArray:
	if auth_token != "":
		return [
			"Content-Type: application/json",
			"Authorization: Bearer %s" % auth_token
		]
	if OS.is_debug_build():
		push_warning("⚠️ [ApiClient] auth_token vacío para request autenticado")
	return default_headers.duplicate()

# -------------------------------------------------------------------
# API pública con callback
# -------------------------------------------------------------------

func get_request_with_callback(endpoint: String, tag: String, callback: Callable, use_auth := true, timeout := DEFAULT_TIMEOUT):
	var request_id := request("GET", endpoint, {}, tag, use_auth, timeout)
	_register_callback(request_id, callback)

func post_request_with_callback(endpoint: String, body: Dictionary, tag: String, callback: Callable, use_auth := true, timeout := DEFAULT_TIMEOUT):
	var request_id := request("POST", endpoint, body, tag, use_auth, timeout)
	_register_callback(request_id, callback)

func put_request_with_callback(endpoint: String, body: Dictionary, tag: String, callback: Callable, use_auth := true, timeout := DEFAULT_TIMEOUT):
	var request_id := request("PUT", endpoint, body, tag, use_auth, timeout)
	_register_callback(request_id, callback)

func delete_request_with_callback(endpoint: String, tag: String, callback: Callable, use_auth := true, timeout := DEFAULT_TIMEOUT):
	var request_id := request("DELETE", endpoint, {}, tag, use_auth, timeout)
	_register_callback(request_id, callback)

func _register_callback(request_id: String, callback: Callable):
	if callback.is_valid():
		_callbacks[request_id] = callback

func get_image_with_callback(
	path: String,
	callback: Callable,
	tag: String = "",
	timeout := DEFAULT_TIMEOUT
) -> void:
	var req := {
		"path": path,
		"callback": callback,
		"tag": tag,
		"timeout": timeout
	}

	_image_queue.push_back(req)
	_process_image_queue()


# -------------------------------------------------------------------
# Request base
# -------------------------------------------------------------------

func request(method: String, endpoint: String, body: Dictionary, tag: String, use_auth := true, timeout := DEFAULT_TIMEOUT) -> String:
	var request_id := str(_request_id_counter)
	_request_id_counter += 1

	var req := {
		"id": request_id,
		"method": method,
		"endpoint": endpoint,
		"body": body,
		"use_auth": use_auth,
		"tag": tag,
		"timeout": timeout,
		"attempt": 0
	}

	_queue.push_back(req)
	_process_queue()

	return request_id

# -------------------------------------------------------------------
# API pública
# -------------------------------------------------------------------

func get_request(endpoint: String, tag: String, use_auth: bool = true, timeout: float = DEFAULT_TIMEOUT) -> void:
	request("GET", endpoint, {}, tag, use_auth, timeout)

func post(endpoint: String, body: Dictionary, tag: String, use_auth: bool = true, timeout: float = DEFAULT_TIMEOUT) -> void:
	request("POST", endpoint, body, tag, use_auth, timeout)

func put(endpoint: String, body: Dictionary, tag: String, use_auth: bool = true, timeout: float = DEFAULT_TIMEOUT) -> void:
	request("PUT", endpoint, body, tag, use_auth, timeout)

func delete(endpoint: String, tag: String, use_auth: bool = true, timeout: float = DEFAULT_TIMEOUT) -> void:
	request("DELETE", endpoint, {}, tag, use_auth, timeout)

# -------------------------------------------------------------------
# Cola y ejecución
# -------------------------------------------------------------------

func _process_queue():
	while _active_requests < MAX_CONCURRENT_REQUESTS and not _queue.is_empty():
		_start_request(_queue.pop_front())

func _start_request(req: Dictionary):
	_active_requests += 1

	var http := HTTPRequest.new()
	http.name = "HTTPRequest_%s" % req.id
	add_child(http)

	var timer := Timer.new()
	timer.name = "Timer_%s" % req.id
	timer.wait_time = req.timeout
	timer.one_shot = true
	add_child(timer)

	var headers := get_auth_headers() if req.use_auth else default_headers.duplicate()
	var body := ""

	if req.method != "GET" and not req.body.is_empty():
		body = JSON.stringify(req.body)

	var url: String = base_url + req.endpoint

	http.request_completed.connect(_on_request_completed.bind(http, timer, req))
	timer.timeout.connect(_on_timeout.bind(http, timer, req))
	timer.start()

	var err := http.request(url, headers, _method_to_constant(req.method), body)
	if err != OK:
		_cleanup_request(http, timer)
		_active_requests -= 1
		if _retry_or_fail(req, "err OK"):
			return
		_finish_request(req, false, null, "Error de conexión: %s" % err)
		_process_queue()

func _process_image_queue() -> void:
	while _active_image_requests < MAX_CONCURRENT_IMAGE_REQUESTS and not _image_queue.is_empty():
		_start_image_request(_image_queue.pop_front())

func _start_image_request(req: Dictionary) -> void:
	_active_image_requests += 1

	var http := HTTPRequest.new()
	add_child(http)

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = req.timeout
	add_child(timer)

	http.request_completed.connect(
		_on_image_request_completed.bind(http, timer, req)
	)

	timer.timeout.connect(
		_on_image_timeout.bind(http, timer, req)
	)

	timer.start()

	var url: String = base_url.trim_suffix("/api") + req.path
	var err := http.request(url)

	if err != OK:
		_cleanup_image_request(http, timer)
		_active_image_requests -= 1
		_finish_image_request(req, null)
		_process_image_queue()


# -------------------------------------------------------------------
# Callbacks internos
# -------------------------------------------------------------------

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, timer: Timer, req: Dictionary):
	_cleanup_request(http, timer)
	_active_requests -= 1

	var data: Variant = null
	var error_msg := ""

	if result != HTTPRequest.RESULT_SUCCESS:
		if _retry_or_fail(req, "Error de red"):
			return
		_finish_request(req, false, null, "Error de red")
		_process_queue()
		return

	if body.size() > 0:
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			data = json.data
		else:
			_finish_request(req, false, null, "JSON inválido")
			_process_queue()
			return

	if response_code >= 200 and response_code < 300:
		_finish_request(req, true, data, "")
	else:
		error_msg = data.get("error", "Error HTTP %d" % response_code) if data is Dictionary else "Error HTTP %d" % response_code
		_finish_request(req, false, data, error_msg)

	_process_queue()

func _on_image_request_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	http: HTTPRequest,
	timer: Timer,
	req: Dictionary
) -> void:
	_cleanup_image_request(http, timer)
	_active_image_requests -= 1

	var image: Image = null

	if response_code == 200 and body.size() > 0:
		image = _decode_image_from_buffer(body)

	_finish_image_request(req, image)
	_process_image_queue()


func _on_timeout(http: HTTPRequest, timer: Timer, req: Dictionary):
	_cleanup_request(http, timer)
	_active_requests -= 1

	if _retry_or_fail(req, "Timeout"):
		return

	_finish_request(req, false, null, "Timeout en la solicitud")
	_process_queue()

func _on_image_timeout(
	http: HTTPRequest,
	timer: Timer,
	req: Dictionary
) -> void:
	_cleanup_image_request(http, timer)
	_active_image_requests -= 1

	# Reintentar imagen una vez antes de fallar
	if req.get("attempt", 0) < 1:
		req["attempt"] = req.get("attempt", 0) + 1
		_image_queue.push_front(req)
		_process_image_queue()
		return

	_finish_image_request(req, null)
	_process_image_queue()


# -------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------

func _retry_or_fail(req: Dictionary, _reason: String) -> bool:
	if req.attempt < MAX_RETRIES:
		req.attempt += 1
		_queue.push_front(req)
		_process_queue()
		return true
	return false

func _cleanup_request(http: HTTPRequest, timer: Timer):
	if is_instance_valid(timer):
		timer.stop()
		timer.queue_free()
	if is_instance_valid(http):
		http.queue_free()

func _finish_request(req: Dictionary, success: bool, data: Variant, error: String):
	if not success and error != "":
		push_error("❌ [ApiClient] %s - %s" % [req.tag, error])

	request_completed.emit(req.tag, success, data, error)

	var request_id : String = req.id
	if _callbacks.has(request_id):
		_callbacks[request_id].call(success, data, error)
		_callbacks.erase(request_id)

func _finish_image_request(req: Dictionary, image: Image) -> void:
	if not req.has("callback"):
		return

	if req.callback.is_valid():
		if req.tag != "":
			req.callback.call(image, req.tag)
		else:
			req.callback.call(image, "finish")

func _cleanup_image_request(http: HTTPRequest, timer: Timer) -> void:
	if is_instance_valid(timer):
		timer.stop()
		timer.queue_free()
	if is_instance_valid(http):
		http.queue_free()

func _decode_image_from_buffer(body: PackedByteArray) -> Image:
	var image := Image.new()
	var error := OK

	var is_png = body.size() >= 8 and body[0] == 0x89 and body[1] == 0x50
	var is_webp = body.size() >= 12 and body[0] == 0x52 and body[8] == 0x57
	var is_jpg = body.size() >= 2 and body[0] == 0xFF and body[1] == 0xD8

	if is_png:
		error = image.load_png_from_buffer(body)
	elif is_webp:
		error = image.load_webp_from_buffer(body)
	elif is_jpg:
		error = image.load_jpg_from_buffer(body)
	else:
		return null

	return image if error == OK else null

# Map string HTTP methods to HTTPClient constants
func _method_to_constant(method: String) -> int:
	match method:
		"GET": return HTTPClient.METHOD_GET
		"POST": return HTTPClient.METHOD_POST
		"PUT": return HTTPClient.METHOD_PUT
		"DELETE": return HTTPClient.METHOD_DELETE
		_: return HTTPClient.METHOD_GET
