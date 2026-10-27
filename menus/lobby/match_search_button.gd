extends Control

@onready var button: Button = $Button
@onready var icon: TextureRect = $Content/Icon
@onready var spinner: TextureRect = $Content/Spinner
@onready var label: Label = $Content/StatusLabel
@onready var overlay: ColorRect = $Overlay

var spinning := false
var _glow_tween: Tween


func _ready():
	button.pressed.connect(_on_pressed)

	MatchmakingService.searching_match.connect(_on_searching)
	MatchmakingService.search_cancelled.connect(_on_cancelled)
	MatchmakingService.match_found.connect(_on_match_found)
	MatchmakingService.match_error.connect(_on_match_error)

	_set_idle_state()


func _process(delta):
	if spinning:
		# El tamaño lo fija el contenedor: recalcular el pivote para girar sobre el centro
		spinner.pivot_offset = spinner.size / 2.0
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
	icon.visible = true
	overlay.visible = false
	button.disabled = false
	button.tooltip_text = "Buscar un rival en línea"
	label.text = "BUSCAR PARTIDA"
	_start_idle_glow()


func _set_searching_state():
	spinning = true
	spinner.visible = true
	icon.visible = false
	overlay.visible = false
	button.tooltip_text = "Pulsa para cancelar la búsqueda"
	label.text = "BUSCANDO… (CANCELAR)"
	_stop_idle_glow()


func _set_locked_state(text: String):
	spinning = false
	spinner.visible = false
	icon.visible = true
	overlay.visible = true
	button.disabled = true
	label.text = text
	_stop_idle_glow()


# Pulso suave para atraer la atención al botón principal
func _start_idle_glow():
	_stop_idle_glow()
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(button, "self_modulate", Color(1.12, 1.08, 1.0), 1.4).set_trans(Tween.TRANS_SINE)
	_glow_tween.tween_property(button, "self_modulate", Color.WHITE, 1.4).set_trans(Tween.TRANS_SINE)


func _stop_idle_glow():
	if _glow_tween:
		_glow_tween.kill()
		_glow_tween = null
	button.self_modulate = Color.WHITE


# -------------------------------------------------------
# SEÑALES MATCHMAKING
# -------------------------------------------------------

func _on_searching():
	_set_searching_state()


func _on_cancelled():
	_set_idle_state()


func _on_match_found(match_data: Dictionary):
	_set_locked_state("¡PARTIDA ENCONTRADA!")

	# Delegamos completamente la sesión
	MatchSessionService.start_pvp_session(match_data)


func _on_match_error(message: String):
	_set_idle_state()
	print("[MatchSearchButton] Error:", message)
