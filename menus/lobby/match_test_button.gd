extends Button

@onready var spinner = $Spinner   # opcional
@onready var status_label = $StatusLabel  # opcional

func _ready() -> void:
	pressed.connect(_on_pressed)

	# Escuchar señales del servicio
	MatchSessionService.match_started.connect(_on_match_started)
	MatchSessionService.match_error.connect(_on_match_error)


func _on_pressed() -> void:
	if disabled:
		return

	_set_loading_state()
	MatchSessionService.start_test_match()


func _set_loading_state() -> void:
	disabled = true
	text = "Iniciando partida de prueba..."
	
	if spinner:
		spinner.show()
	
	if status_label:
		status_label.text = "Preparando entorno..."


func _restore_idle_state() -> void:
	disabled = false
	text = "Test Match"
	
	if spinner:
		spinner.hide()
	
	if status_label:
		status_label.text = ""


func _on_match_started(_game_state) -> void:
	# No restauramos botón.
	# La transición va a ocurrir.
	pass


func _on_match_error(message: String) -> void:
	print("❌ Error iniciando partida TEST:", message)
	_restore_idle_state()
