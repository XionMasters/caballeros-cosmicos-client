extends Control
## Botón principal JUGAR del lobby: busca rival por WebSocket y refleja el estado
## de la búsqueda (inactivo con halo pulsante, buscando con spinner, bloqueado).

@onready var button: Button = $Button
@onready var glow: Panel = $Glow
@onready var icon: TextureRect = $Content/Icon
@onready var spinner: TextureRect = $Content/Spinner
@onready var label: Label = $Content/Texts/StatusLabel
@onready var hint: Label = $Content/Texts/HintLabel
@onready var overlay: ColorRect = $Overlay

var spinning := false
var _glow_tween: Tween


func _ready():
	button.pressed.connect(_on_pressed)
	button.mouse_entered.connect(_on_hover.bind(true))
	button.mouse_exited.connect(_on_hover.bind(false))

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
	_punch()
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
	label.text = "JUGAR"
	hint.text = "BUSCAR RIVAL EN LÍNEA"
	_start_idle_glow()


func _set_searching_state():
	spinning = true
	spinner.visible = true
	icon.visible = false
	overlay.visible = false
	button.tooltip_text = "Pulsa para cancelar la búsqueda"
	label.text = "BUSCANDO…"
	hint.text = "PULSA PARA CANCELAR"
	_start_searching_glow()


func _set_locked_state(text: String):
	spinning = false
	spinner.visible = false
	icon.visible = true
	overlay.visible = true
	button.disabled = true
	label.text = text
	hint.text = "PREPARANDO EL CAMPO DE BATALLA"
	_stop_glow()


# Halo que respira para atraer la atención al botón principal
func _start_idle_glow():
	_stop_glow()
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(glow, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE)
	_glow_tween.tween_property(glow, "modulate:a", 0.35, 1.2).set_trans(Tween.TRANS_SINE)


# Buscando: halo más rápido, como un latido
func _start_searching_glow():
	_stop_glow()
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(glow, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	_glow_tween.tween_property(glow, "modulate:a", 0.2, 0.45).set_trans(Tween.TRANS_SINE)


func _stop_glow():
	if _glow_tween:
		_glow_tween.kill()
		_glow_tween = null
	glow.modulate.a = 0.0


func _on_hover(entered: bool) -> void:
	if button.disabled:
		return
	pivot_offset = size / 2.0
	var target := Vector2(1.04, 1.04) if entered else Vector2.ONE
	create_tween().tween_property(self, "scale", target, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Pequeño "golpe" al pulsar
func _punch() -> void:
	pivot_offset = size / 2.0
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.06)
	tween.tween_property(self, "scale", Vector2(1.04, 1.04), 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# -------------------------------------------------------
# SEÑALES MATCHMAKING
# -------------------------------------------------------

func _on_searching():
	_set_searching_state()


func _on_cancelled():
	_set_idle_state()


func _on_match_found(match_data: Dictionary):
	_set_locked_state("¡RIVAL!")

	# Delegamos completamente la sesión
	MatchSessionService.start_pvp_session(match_data)


func _on_match_error(message: String):
	_set_idle_state()
	print("[MatchSearchButton] Error:", message)
