# AnimationContext.gd
# Contenedor de referencias que los AnimationEvent necesitan para ejecutarse.
# Se crea una vez en AnimationOrchestrator y se pasa a cada event.play().
#
# Ventaja: los eventos no necesitan referencias directas al árbol de escena —
# sólo reciben un contexto limpio con lo que necesitan.

class_name AnimationContext
extends RefCounted

# ============================================================================
# SUB-CONTROLADORES
# ============================================================================
var player_hand_ctrl: PlayerHandController
var opponent_hand_ctrl: OpponentHandController
var field_renderer: FieldRenderer
var status_ctrl: StatusPanelController
var effects_mgr: MatchEffectsManager

## Nodo padre (GameMatch) necesario para get_tree(), create_tween(), etc.
var parent_node: Node

## Número de jugador local — usado por eventos que necesitan resolver perspectiva
## (ej. KnightSummonedEvent para saber si el dueño es oponente o jugador).
var player_number_hint: int = 1

# ============================================================================
# CONSTRUCTOR
# ============================================================================
func _init(
	p_hand: PlayerHandController,
	o_hand: OpponentHandController,
	field: FieldRenderer,
	status: StatusPanelController,
	effects: MatchEffectsManager,
	parent: Node,
	p_player_number: int = 1
) -> void:
	player_hand_ctrl = p_hand
	opponent_hand_ctrl = o_hand
	field_renderer = field
	status_ctrl = status
	effects_mgr = effects
	parent_node = parent
	player_number_hint = p_player_number
