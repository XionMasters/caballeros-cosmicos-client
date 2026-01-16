extends Control

@onready var player_panel: PlayerStatusPanel = $RootColumns/LeftColumn/LeftStack/PlayerPanel
@onready var opponent_panel: PlayerStatusPanel = $RootColumns/LeftColumn/LeftStack/OpponentPanel

func _ready():
	# Obtener datos de la partida actual
	var current_match = MatchManager.current_match
	var game_state = MatchManager.game_state
	
	if current_match and game_state:
		# Configurar panel del jugador local
		var player_name = current_match.get("player1_name") if game_state.player_number == 1 else current_match.get("player2_name")
		var player_id = current_match.get("player1_id") if game_state.player_number == 1 else current_match.get("player2_id")
		var opponent_name = current_match.get("player2_name") if game_state.player_number == 1 else current_match.get("player1_name")
		var opponent_id = current_match.get("player2_id") if game_state.player_number == 1 else current_match.get("player1_id")
		
		# Setup con user_ids para cargar avatares desde servidor
		player_panel.setup(player_name, game_state.player_life, game_state.player_cosmos, player_id)
		opponent_panel.setup(opponent_name, game_state.opponent_life, game_state.opponent_cosmos, opponent_id)
	else:
		# Fallback si no hay datos (ej: editor de escenas)
		player_panel.setup("Tu", 12, 1, "")
		opponent_panel.setup("Rival", 12, 0, "")
