extends Control

@onready var button: Button = $Button
@onready var spinner: TextureRect = $Content/Spinner
@onready var label: Label = $Content/AnimatedIcon/StatusLabel
@onready var overlay: ColorRect = $Overlay

var spinning := false

func _ready():
	button.pressed.connect(_on_pressed)

	MatchmakingService.searching_match.connect(_on_searching)
	MatchmakingService.search_cancelled.connect(_on_cancelled)
	MatchmakingService.match_found.connect(_on_match_found)
	MatchmakingService.match_error.connect(_on_match_error)
	
	spinner.pivot_offset = spinner.size / 2

	_set_idle_state()


func _process(delta):
	if spinning:
		spinner.rotation += delta * 6.0


func _on_pressed():
	if MatchmakingService.is_searching:
		MatchmakingService.cancel_search()
	else:
		MatchmakingService.search_match()


# -------------------------------------------------------
# ESTADOS VISUALES
# -------------------------------------------------------

func _set_idle_state():
	spinning = false
	spinner.visible = false
	overlay.visible = false
	label.text = "⚔️ Partida"
	$Content/AnimatedIcon.visible = true


func _set_searching_state():
	spinning = true
	spinner.visible = true
	overlay.visible = false
	$Content/AnimatedIcon.visible = false
	label.text = "Buscando..."


func _set_locked_state(text: String):
	spinning = false
	spinner.visible = false
	overlay.visible = true
	label.text = text


# -------------------------------------------------------
# SEÑALES MATCHMAKING
# -------------------------------------------------------

func _on_searching():
	_set_searching_state()


func _on_cancelled():
	_set_idle_state()


func _on_match_found(match_data: Dictionary):
	_set_locked_state("¡Partida encontrada!")
	print("¡Partida encontrada!")
	
	# Delegamos completamente la sesión
	MatchSessionService.start_pvp_session(match_data)


func _on_match_error(message: String):
	_set_idle_state()
	print("[MatchSearchButton] Error:", message)
