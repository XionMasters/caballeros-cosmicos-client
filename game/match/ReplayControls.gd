# ReplayControls.gd
# Controles de una repetición sobre GameMatch: reproducir/pausar, paso a paso, velocidad,
# reiniciar y salir. Bloquea el tablero (no se puede jugar) y aplica los fotogramas guardados
# en orden a través de MatchSessionService, con las mismas animaciones que en directo.
extends CanvasLayer

const BASE_DELAY := 1.6  # segundos entre fotogramas a velocidad x1
const SPEEDS := [1.0, 2.0, 4.0]
const ACTION_LABELS := {
	"match_start": "Inicio de la partida",
	"end_turn": "Fin de turno",
	"play_card": "Juega una carta",
	"attack": "Ataque básico",
	"technique_attack": "Técnica",
	"change_mode": "Cambio de modo",
	"charge_cosmos": "Carga cosmo",
	"sacrifice": "Sacrificio",
	"move": "Mueve un caballero",
	"use_ability": "Habilidad",
	"resolve_selection": "Elige un objetivo",
	"abandon": "Abandono",
}

var _frames: Array = []
var _index := 0          # último fotograma aplicado (0 = tablero inicial)
var _playing := true
var _speed_index := 0
var _busy := false
var _finished := false

var _title: Label
var _step_label: Label
var _action_label: Label
var _play_button: Button
var _next_button: Button
var _speed_button: Button


func _ready() -> void:
	layer = 50
	_build_ui()


func start() -> void:
	_frames = MatchSessionService.get_replay_frames()
	_index = 0
	_update_labels()
	_run()


# ============================================================================
# REPRODUCCIÓN
# ============================================================================
func _run() -> void:
	while is_inside_tree() and _index < _frames.size() - 1:
		if not _playing:
			await get_tree().create_timer(0.1).timeout
			continue
		await _step()
		if not is_inside_tree():
			return
		await get_tree().create_timer(BASE_DELAY / SPEEDS[_speed_index]).timeout
	if is_inside_tree():
		_show_finished()


func _step() -> void:
	if _busy or _index >= _frames.size() - 1:
		return
	_busy = true
	_index += 1
	MatchSessionService.apply_replay_frame(_frames[_index])
	while is_inside_tree() and MatchSessionService.is_update_in_progress():
		await get_tree().process_frame
	_busy = false
	if is_inside_tree():
		_update_labels()


# ============================================================================
# BOTONES
# ============================================================================
func _on_play_pressed() -> void:
	if _finished:
		_on_restart_pressed()
		return
	_playing = not _playing
	_update_labels()


func _on_next_pressed() -> void:
	if not _playing:
		await _step()
		if _index >= _frames.size() - 1:
			_show_finished()


func _on_speed_pressed() -> void:
	_speed_index = (_speed_index + 1) % SPEEDS.size()
	_update_labels()


func _on_restart_pressed() -> void:
	MatchSessionService.restart_replay()


func _on_exit_pressed() -> void:
	MatchSessionService.end_replay()
	SceneTransition.go_to_profile()


# ============================================================================
# INTERFAZ
# ============================================================================
func _update_labels() -> void:
	var total := maxi(_frames.size() - 1, 0)
	var frame: Dictionary = _frames[_index] if _index < _frames.size() else {}
	var turn := int(frame.get("current_turn", 1))
	var player := int(frame.get("current_player", 1))
	_step_label.text = "Paso %d de %d · Turno %d · Juega %s" % [_index, total, turn, _player_name(player)]

	var action: Dictionary = frame.get("last_action", {}) if frame.get("last_action") is Dictionary else {}
	_action_label.text = ACTION_LABELS.get(str(action.get("type", "")), "")

	_play_button.text = "Ver de nuevo" if _finished else ("Pausa" if _playing else "Reproducir")
	_next_button.disabled = _playing or _finished
	_speed_button.text = "x%d" % int(SPEEDS[_speed_index])


func _show_finished() -> void:
	_finished = true
	_playing = false
	_update_labels()
	var info := MatchSessionService.get_replay_info()
	var winner := str(info.get("winner_id", ""))
	var result := "Fin de la repetición"
	if info.get("is_test", false):
		result += " · Partida de prueba"
	elif winner != "":
		result += " · Victoria" if winner == AuthManager.get_user_id() else " · Derrota"
	_action_label.text = result


func _player_name(number: int) -> String:
	var info := MatchSessionService.get_replay_info()
	var player = info.get("player%d" % number, {})
	var name := str(player.get("username", "")) if player is Dictionary else ""
	if info.get("is_test", false):
		return "Jugador %d" % number
	return name if name != "" else "Jugador %d" % number


func _build_ui() -> void:
	# Bloqueador: durante la repetición no se puede interactuar con el tablero
	var blocker := Control.new()
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Sí se pueden inspeccionar las cartas: clic derecho o doble clic sobre ellas
	blocker.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and (
				event.button_index == MOUSE_BUTTON_RIGHT
				or (event.button_index == MOUSE_BUTTON_LEFT and event.double_click)):
			CardDetailManager.show_at_global_position(event.global_position)
	)
	add_child(blocker)

	var bar := PanelContainer.new()
	bar.theme_type_variation = &"HeaderPanel"
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.offset_left = -520
	bar.offset_right = 520
	bar.offset_top = 12
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	bar.add_child(row)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)

	var info := MatchSessionService.get_replay_info()
	_title = Label.new()
	_title.theme_type_variation = &"SectionTitle"
	if info.get("is_test", false):
		_title.text = "Repetición · Partida de prueba"
	else:
		_title.text = "Repetición · %s contra %s" % [_player_name(1), _player_name(2)]
	texts.add_child(_title)

	_step_label = Label.new()
	_step_label.theme_type_variation = &"Subtitle"
	texts.add_child(_step_label)

	_action_label = Label.new()
	_action_label.add_theme_color_override("font_color", UIPalette.GOLD_LIGHT)
	texts.add_child(_action_label)

	_play_button = _make_button("Pausa", _on_play_pressed)
	_next_button = _make_button("Siguiente", _on_next_pressed)
	_speed_button = _make_button("x1", _on_speed_pressed)
	_speed_button.custom_minimum_size.x = 64
	_speed_button.tooltip_text = "Velocidad"
	row.add_child(_play_button)
	row.add_child(_next_button)
	row.add_child(_speed_button)
	row.add_child(_make_button("Reiniciar", _on_restart_pressed))

	var exit := _make_button("Salir", _on_exit_pressed)
	exit.theme_type_variation = &"DangerButton"
	row.add_child(exit)


func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(110, 44)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	return button
