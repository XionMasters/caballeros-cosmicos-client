# PlayerZone.gd
# Zona completa del jugador: status + mano + campos de batalla
extends Control
class_name PlayerZone

# ============================================================================
# REFERENCIAS A COMPONENTES
# ============================================================================
@onready var status_panel: PlayerStatusPanel = $StatusPanel
@onready var player_hand: Control = $HandContainer/PlayerHand
@onready var knight_zone: KnightZone = $FieldContainer/KnightZone
@onready var technique_zone: TechniqueZone = $FieldContainer/TechniqueZone
@onready var helper_slot: SingleCardSlot = $SpecialZonesContainer/HelperSlot
@onready var occasion_slot: SingleCardSlot = $SpecialZonesContainer/OccasionSlot
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
# SEÑALES
# ============================================================================
signal card_placement_requested(card_instance: CardInstance, zone: String, position: int)

# ============================================================================
# CICLO DE VIDA
# ============================================================================
func _ready() -> void:
	print("[PlayerZone] Inicializando zona del jugador: %s" % zone_name)
	
	# Asegurarse de que los componentes están listos
	if not status_panel:
		push_error("[PlayerZone] StatusPanel no encontrado")
	if not knight_zone:
		push_error("[PlayerZone] KnightZone no encontrado")
	if not technique_zone:
		push_error("[PlayerZone] TechniqueZone no encontrado")


# ============================================================================
# MÉTODOS PÚBLICOS - SETUP
# ============================================================================
func setup(name: String, life: int, cosmos: int, avatar_url: String = "") -> void:
	"""Configurar la zona inicial"""
	status_panel.setup(name, life, cosmos, avatar_url)


# ============================================================================
# MÉTODOS PÚBLICOS - ACTUALIZACIONES
# ============================================================================
func update_status(new_life: int, new_cosmos: int) -> void:
	"""Actualizar vida y cosmos"""
	status_panel.update_both(new_life, new_cosmos)


func update_piles(yomotsu: int, cositos: int) -> void:
	"""Actualizar contadores de pilas"""
	piles_panel.update_both(yomotsu, cositos)


# ============================================================================
# RENDERIZACIÓN DESDE GAMESTATE
# ============================================================================
func render_from_game_state(state: GameState, player_num: int) -> void:
	"""Renderizar toda la zona desde GameState"""
	game_state = state
	player_number = player_num
	
	print("[PlayerZone] 🎨 Renderizando zona para player %d" % player_num)
	
	# Actualizar status
	var life = state.get_player_life(player_num)
	var cosmos = state.get_player_cosmos(player_num)
	update_status(life, cosmos)
	
	# Renderizar campos de batalla
	var knight_cards = state.get_player_field_knights(player_num)
	knight_zone.render_from_game_state(knight_cards, "field_knight")
	
	var technique_cards = state.get_player_field_techniques(player_num)
	technique_zone.render_from_game_state(technique_cards, "field_technique")
	
	# TODO: Renderizar helper, occasion, scenario
	
	# TODO: Actualizar Yomotsu/Cositos desde state


# ============================================================================
# MÉTODOS PARA INPUT/INTERACTIVIDAD
# ============================================================================
func enable_input(enabled: bool) -> void:
	"""Habilitar/deshabilitar input en esta zona"""
	mouse_filter = Control.MOUSE_FILTER_PASS if enabled else Control.MOUSE_FILTER_IGNORE


func clear_zone() -> void:
	"""Limpiar todos los campos"""
	knight_zone.clear_zone()
	technique_zone.clear_zone()
	helper_slot.clear()
	occasion_slot.clear()
