extends Button
## Botón "CONTRA LA IA" del lobby: pide al servidor una partida inmediata contra la IA
## (evento request_ai_match). El servidor responde con match_found, como al encontrar
## rival en PvP, y MatchSessionService abre el tablero.

const IDLE_TEXT := "CONTRA LA IA"
const LOADING_TEXT := "PREPARANDO RIVAL…"


func _ready() -> void:
	pressed.connect(_on_pressed)
	MatchmakingService.match_error.connect(_on_match_error)
	MatchmakingService.match_found.connect(_on_match_found)


func _on_pressed() -> void:
	if disabled:
		return
	disabled = true
	text = LOADING_TEXT
	MatchmakingService.request_ai_match()


func _on_match_found(_data: Dictionary) -> void:
	# La escena va a cambiar: no se restaura el botón
	pass


func _on_match_error(_message: String) -> void:
	disabled = false
	text = IDLE_TEXT
