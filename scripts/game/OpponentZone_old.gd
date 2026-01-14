# OpponentZone.gd
# Zona del oponente: extiende PlayerZone pero con inversión visual
extends PlayerZone
class_name OpponentZone

# ============================================================================
# PARÁMETROS ESPECÍFICOS PARA OPONENTE
# ============================================================================

func _ready() -> void:
	print("[OpponentZone] Inicializando zona del oponente")
	super._ready()
	
	# Aplicar transformaciones visuales de inversión
	_apply_opponent_visuals()


# ============================================================================
# MÉTODOS ESPECÍFICOS PARA OPONENTE
# ============================================================================
func _apply_opponent_visuals() -> void:
	"""Invertir visualmente elementos para que se vea desde perspectiva del oponente"""
	
	# Invertir escala Y para que caballeros/técnicas se vean de cabeza
	scale.y = -1
	
	# Rotar 180 grados la mano
	if player_hand:
		player_hand.rotation = PI
	
	print("[OpponentZone] ✅ Aplicadas inversiones visuales")


func render_from_game_state(state: GameState, player_num: int) -> void:
	"""Renderizar zona del oponente (igual que jugador pero invertido)"""
	print("[OpponentZone] 🎨 Renderizando zona oponente para player %d" % player_num)
	super.render_from_game_state(state, player_num)
