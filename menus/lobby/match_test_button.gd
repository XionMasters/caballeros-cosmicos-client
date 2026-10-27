extends Button

const IDLE_TEXT := "Partida de prueba"
const LOADING_TEXT := "Preparando partida…"

var _active_match_id: String = ""
var _confirm_dialog: ConfirmationDialog = null

func _ready() -> void:
	pressed.connect(_on_pressed)

	# Escuchar señales del servicio
	MatchSessionService.match_started.connect(_on_match_started)
	MatchSessionService.match_error.connect(_on_match_error)
	MatchSessionService.active_test_match_exists.connect(_on_active_test_match_exists)


func _on_pressed() -> void:
	if disabled:
		return

	_set_loading_state()
	MatchSessionService.start_test_match()


func _set_loading_state() -> void:
	disabled = true
	text = LOADING_TEXT


func _restore_idle_state() -> void:
	disabled = false
	text = IDLE_TEXT


func _on_match_started(_game_state) -> void:
	# No restauramos el botón: la transición de escena va a ocurrir.
	pass


func _on_match_error(message: String) -> void:
	print("❌ Error iniciando partida TEST:", message)
	_restore_idle_state()


func _on_active_test_match_exists(match_id: String) -> void:
	"""Hay una partida TEST activa: preguntar al usuario qué hacer"""
	_active_match_id = match_id
	_restore_idle_state()
	_show_active_match_dialog()


func _show_active_match_dialog() -> void:
	# Limpiar diálogo anterior si existe
	if _confirm_dialog and is_instance_valid(_confirm_dialog):
		_confirm_dialog.queue_free()

	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "Partida activa encontrada"
	_confirm_dialog.dialog_text = "Tienes una partida de prueba en curso.\n¿Qué quieres hacer?"
	_confirm_dialog.ok_button_text = "Reanudar"
	_confirm_dialog.cancel_button_text = "Abandonar y empezar otra"

	add_child(_confirm_dialog)

	_confirm_dialog.confirmed.connect(_on_resume_confirmed)
	_confirm_dialog.canceled.connect(_on_abandon_confirmed)
	_confirm_dialog.popup_centered()


func _on_resume_confirmed() -> void:
	print("▶️ Usuario eligió REANUDAR partida TEST")
	_set_loading_state()
	MatchSessionService.request_resume_test_match()


func _on_abandon_confirmed() -> void:
	print("🗑️ Usuario eligió ABANDONAR y crear nueva partida TEST")
	_set_loading_state()
	MatchSessionService.request_abandon_test_match(_active_match_id)
