# PlayerZone.gd (CORREGIDO)
# Zona completa del jugador: status + mano + campos de batalla
extends Control
class_name PlayerZone

# ============================================================================
# REFERENCIAS A COMPONENTES
# ============================================================================
@onready var status_panel: PlayerStatusPanel = $StatusPanel
@onready var player_hand: Control = $HandContainer/PlayerHand
@onready var knight_zone: CardZone = $FieldContainer/KnightZone
@onready var technique_zone: CardZone = $FieldContainer/TechniqueZone
@onready var piles_panel: PilesPanel = $PilesContainer/PilesPanel

# ============================================================================
# PARÁMETROS
# ============================================================================
@export var zone_name: String = "Player"
@export var is_opponent: bool = false

# ============================================================================
# ESTADO
# ============================================================================
var game_state: GameState = null
var player_number: int = 1

# ============================================================================
# CICLO DE VIDA
# ============================================================================
func _ready() -> void:
	print("[PlayerZone] Inicializando zona del jugador: %s" % zone_name)
	
	# Verificar que los componentes existen
	if not status_panel:
		push_warning("[PlayerZone] StatusPanel no encontrado")
	if not knight_zone:
		push_warning("[PlayerZone] KnightZone no encontrado")
	if not technique_zone:
		push_warning("[PlayerZone] TechniqueZone no encontrado")


# ============================================================================
# MÉTODOS PÚBLICOS - SETUP
# ============================================================================
func setup(player_name: String, life: int, cosmos: int, avatar_url: String = "") -> void:
	"""Configurar la zona inicial"""
	if status_panel:
		status_panel.setup(player_name, life, cosmos, avatar_url)


# ============================================================================
# MÉTODOS PÚBLICOS - ACTUALIZACIONES
# ============================================================================
func update_status(new_life: int, new_cosmos: int) -> void:
	"""Actualizar vida y cosmos"""
	if status_panel:
		status_panel.update_both(new_life, new_cosmos)


func update_piles(yomotsu: int, cositos: int) -> void:
	"""Actualizar contadores de pilas"""
	if piles_panel:
		piles_panel.update_both(yomotsu, cositos)


# ============================================================================
# RENDERIZACIÓN DESDE GAMESTATE
# ============================================================================
func render_from_game_state(state: GameState, player_num: int) -> void:
	"""Renderizar zona desde GameState
	
	NOTA: La renderización actual de cartas está en BoardRenderer.
	Este método actualiza solo status y contadores.
	"""
	game_state = state
	player_number = player_num
	
	if not state:
		return
	
	print("[PlayerZone] 🎨 Actualizando status para player %d" % player_num)
	
	# Actualizar status
	var life = state.get_player_life(player_num)
	var cosmos = state.get_player_cosmos(player_num)
	update_status(life, cosmos)
	
	# TODO: Actualizar Yomotsu/Cositos desde state si existen


# ============================================================================
# MÉTODOS PARA INPUT/INTERACTIVIDAD
# ============================================================================
func enable_input(enabled: bool) -> void:
	"""Habilitar/deshabilitar input en esta zona"""
	mouse_filter = Control.MOUSE_FILTER_PASS if enabled else Control.MOUSE_FILTER_IGNORE
