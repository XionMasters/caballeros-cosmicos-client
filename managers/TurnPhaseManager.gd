# TurnPhaseManager.gd
# Gestiona las fases del turno del jugador local y del oponente
extends Node

signal phase_changed(phase: String)
signal available_actions_changed(actions: Array)
signal turn_started(is_player_turn: bool)
signal turn_ended(is_player_turn: bool)

enum Phase {
	DRAW,
	MAIN,
	BATTLE,
	END
}

var current_phase: Phase = Phase.DRAW
var is_player_turn: bool = false   # true = mi turno, false = oponente

# Acciones base por fase
const BASE_ACTIONS := {
	Phase.DRAW:   ["draw_card"],
	Phase.MAIN:   ["play_card", "activate_technique"],
	Phase.BATTLE: ["declare_attack"],
	Phase.END:    ["end_turn"]
}

# Acciones dinámicas (MatchManager las puede activar/desactivar)
var extra_actions: Array = []

func start_player_turn():
	is_player_turn = true
	extra_actions.clear()
	_go_to_phase(Phase.DRAW)
	turn_started.emit(true)

func start_opponent_turn():
	is_player_turn = false
	extra_actions.clear()
	_go_to_phase(Phase.DRAW)
	turn_started.emit(false)

func end_turn():
	turn_ended.emit(is_player_turn)
	current_phase = Phase.END

func _go_to_phase(phase: Phase):
	current_phase = phase

	var phase_name: String = Phase.keys()[phase]
	print("📘 Nueva fase:", phase_name)
	phase_changed.emit(phase_name)

	_emit_available_actions()

func add_extra_action(action: String):
	if action not in extra_actions:
		extra_actions.append(action)
		_emit_available_actions()

func remove_extra_action(action: String):
	if action in extra_actions:
		extra_actions.erase(action)
		_emit_available_actions()

func clear_extra_actions():
	extra_actions.clear()
	_emit_available_actions()

func _emit_available_actions():
	var actions = BASE_ACTIONS.get(current_phase, []) + extra_actions
	available_actions_changed.emit(actions)

func can_perform(action: String) -> bool:
	if not is_player_turn:
		return false
	var actions = BASE_ACTIONS.get(current_phase, []) + extra_actions
	return action in actions

func advance_phase():
	match current_phase:
		Phase.DRAW:
			_go_to_phase(Phase.MAIN)
		Phase.MAIN:
			_go_to_phase(Phase.BATTLE)
		Phase.BATTLE:
			_go_to_phase(Phase.END)
		Phase.END:
			end_turn()

func get_phase_name() -> String:
	return Phase.keys()[current_phase]
