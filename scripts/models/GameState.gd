# GameState.gd
# 📌 Modelo de datos (snapshot) del estado actual de la partida
# 
# RESPONSABILIDADES:
# ✅ Almacenar datos de la partida (turno, fase, vida, cosmos)
# ✅ Mantener listas organizadas de cartas por zona
# ✅ Convertir JSON del servidor en objetos CardInstance
# ✅ Proveer métodos de consulta (is_my_turn, get_card_by_id)
#
# LO QUE NO HACE (responsabilidad de otras clases):
# ❌ NO decide si una acción es válida (GameRules)
# ❌ NO modifica estados del juego (MatchController)
# ❌ NO calcula daño/efectos (CardInstance, EffectResolver)
# ❌ NO maneja animaciones (CombatAnimator)
# ❌ NO controla turnos (TurnManager)
#
class_name GameState

# Información de la partida
var match_id: String
var current_turn: int = 1
var current_phase: String = "draw"  # "draw", "main", "battle", "end"
var active_player_number: int = 1  # 1 o 2, indica qué jugador tiene el turno

# Recursos de jugadores
var player_id: String  # ID del jugador local (UUID)
var player_number: int = 1  # 1 o 2
var opponent_id: String

var player_life: int = 12
var opponent_life: int = 12
var player_cosmos: int = 0  # CP disponible
var opponent_cosmos: int = 0

# Zonas del jugador
var player_hand: Array[CardInstance] = []
var player_field_knights: Array[CardInstance] = []  # Max 5
var player_field_techniques: Array[CardInstance] = []  # Max 5
var player_helper: CardInstance = null
var player_occasion: CardInstance = null
var player_deck_count: int = 40
var player_graveyard: Array[CardInstance] = []

# Zonas del oponente (info limitada)
var opponent_hand_count: int = 0
var opponent_field_knights: Array[CardInstance] = []
var opponent_field_techniques: Array[CardInstance] = []
var opponent_helper: CardInstance = null
var opponent_occasion: CardInstance = null
var opponent_deck_count: int = 40
var opponent_graveyard: Array[CardInstance] = []

# Zona compartida
var scenario: CardInstance = null

# =========================================================
# MÉTODOS ESTÁTICOS - CONSTRUCCIÓN
# =========================================================

static func from_server_data(data: Dictionary, local_player_id: String) -> GameState:
	"""Crear GameState desde datos del servidor (formato actual)"""
	var state = GameState.new()
	
	state.match_id = data.get("id", "")
	state.current_turn = data.get("current_turn", 1)
	state.current_phase = data.get("phase", "main")
	state.player_id = local_player_id
	state.active_player_number = data.get("current_player", 1)
	
	# Determinar número de jugador
	state.player_number = 1 if data.get("player1_id") == local_player_id else 2
	
	# Parsear vida y cosmos
	if state.player_number == 1:
		state.player_life = data.get("player1_life", 12)
		state.player_cosmos = data.get("player1_cosmos", 0)
		state.opponent_life = data.get("player2_life", 12)
		state.opponent_cosmos = data.get("player2_cosmos", 0)
		state.opponent_id = data.get("player2_id", "")
	else:
		state.player_life = data.get("player2_life", 12)
		state.player_cosmos = data.get("player2_cosmos", 0)
		state.opponent_life = data.get("player1_life", 12)
		state.opponent_cosmos = data.get("player1_cosmos", 0)
		state.opponent_id = data.get("player1_id", "")
	
	# Parsear contadores de mazos y mano
	if state.player_number == 1:
		state.player_deck_count = data.get("player1_deck_size", 40)
		state.opponent_deck_count = data.get("player2_deck_size", 40)
		state.opponent_hand_count = data.get("player2_hand_count", 0)
	else:
		state.player_deck_count = data.get("player2_deck_size", 40)
		state.opponent_deck_count = data.get("player1_deck_size", 40)
		state.opponent_hand_count = data.get("player1_hand_count", 0)
	
	# Parsear cartas en juego desde el array cards_in_play
	var cards_in_play = data.get("cards_in_play", [])
	
	for card_in_play in cards_in_play:
		var card_player = card_in_play.get("player_number", 0)
		var zone = card_in_play.get("zone", "")
		var position = card_in_play.get("position", 0)
		
		# ✅ CORRECCIÓN: Usar from_server_data en vez de new()
		# Esto preserva: buffs, status, mode, is_exhausted, etc.
		var card_instance = CardInstance.from_server_data(card_in_play)
		
		# Asignar field_slot desde position (el servidor puede enviar "position" en vez de "field_slot")
		if card_in_play.has("position"):
			card_instance.field_slot = card_in_play.get("position", -1)
		
		# Clasificar en zonas según player_number
		var is_mine = (card_player == state.player_number)
		
		if zone == "hand" and is_mine:
			state.player_hand.append(card_instance)
		elif zone == "field_knight":
			if is_mine:
				_set_in_array(state.player_field_knights, position, card_instance)
			else:
				_set_in_array(state.opponent_field_knights, position, card_instance)
		elif zone == "field_support":
			if is_mine:
				_set_in_array(state.player_field_techniques, position, card_instance)
			else:
				_set_in_array(state.opponent_field_techniques, position, card_instance)
		elif zone == "field_helper":
			if is_mine:
				state.player_helper = card_instance
			else:
				state.opponent_helper = card_instance
		elif zone == "field_occasion":
			if is_mine:
				state.player_occasion = card_instance
			else:
				state.opponent_occasion = card_instance
		elif zone == "field_scenario":
			state.scenario = card_instance
		elif zone == "yomotsu":
			if is_mine:
				state.player_graveyard.append(card_instance)
			else:
				state.opponent_graveyard.append(card_instance)
	
	return state


static func _set_in_array(array: Array, index: int, value):
	"""Helper: Asegurar que el array tenga tamaño suficiente y asignar valor"""
	while array.size() <= index:
		array.append(null)
	array[index] = value


# =========================================================
# MÉTODOS DE CONSULTA (SOLO LECTURA)
# =========================================================

func is_my_turn() -> bool:
	"""Verificar si es el turno del jugador local"""
	return active_player_number == player_number


# =========================================================
# MÉTODOS DE CONSULTA - PARA RENDERIZADO (TestBoard, GameBoard)
# =========================================================

func get_hand_for_player(player_num: int) -> Array[CardInstance]:
	"""Obtener la mano del jugador especificado"""
	if player_num == player_number:
		return player_hand
	else:
		# La mano del oponente NO está disponible en el cliente
		# Devolver array vacío (el cliente solo ve conteo)
		return []


func get_cards_in_zone(zone: String, player_num: int) -> Array[CardInstance]:
	"""Obtener todas las cartas en una zona específica
	
	Zonas válidas:
	- "hand" (solo para player_number)
	- "field_knight"
	- "field_technique"
	- "field_helper"
	- "field_occasion"
	- "deck"
	- "graveyard"
	"""
	var is_mine = (player_num == player_number)
	var result: Array[CardInstance] = []
	
	match zone:
		"hand":
			if is_mine:
				result = player_hand
		"field_knight":
			result = player_field_knights if is_mine else opponent_field_knights
		"field_technique":
			result = player_field_techniques if is_mine else opponent_field_techniques
		"graveyard":
			result = player_graveyard if is_mine else opponent_graveyard
	
	return result


func get_deck_size(player_num: int) -> int:
	"""Obtener cantidad de cartas en el deck"""
	if player_num == player_number:
		return player_deck_count
	else:
		return opponent_deck_count


func get_player_life(player_num: int) -> int:
	"""Obtener vida del jugador"""
	if player_num == player_number:
		return player_life
	else:
		return opponent_life


func get_player_cosmos(player_num: int) -> int:
	"""Obtener cosmos disponible del jugador"""
	if player_num == player_number:
		return player_cosmos
	else:
		return opponent_cosmos


func find_card_location(instance_id: String) -> Dictionary:
	"""Encontrar la ubicación de una carta (zona, índice, dueño, card)
	Retorna siempre un diccionario con 'found' para evitar errores silenciosos"""
	# Buscar en mano
	for i in range(player_hand.size()):
		if player_hand[i].instance_id == instance_id:
			return {"found": true, "card": player_hand[i], "zone": "hand", "index": i, "owner": player_number}
	
	# Buscar en campo propio
	for i in range(player_field_knights.size()):
		if player_field_knights[i] and player_field_knights[i].instance_id == instance_id:
			return {"found": true, "card": player_field_knights[i], "zone": "field_knight", "index": i, "owner": player_number}
	
	for i in range(player_field_techniques.size()):
		if player_field_techniques[i] and player_field_techniques[i].instance_id == instance_id:
			return {"found": true, "card": player_field_techniques[i], "zone": "field_tech_object", "index": i, "owner": player_number}
	
	if player_helper and player_helper.instance_id == instance_id:
		return {"found": true, "card": player_helper, "zone": "field_helper", "index": 0, "owner": player_number}
	
	if player_occasion and player_occasion.instance_id == instance_id:
		return {"found": true, "card": player_occasion, "zone": "field_occasion", "index": 0, "owner": player_number}
	
	# Buscar en campo oponente
	var opponent_num = 3 - player_number  # Si soy 1, oponente es 2; si soy 2, oponente es 1
	
	for i in range(opponent_field_knights.size()):
		if opponent_field_knights[i] and opponent_field_knights[i].instance_id == instance_id:
			return {"found": true, "card": opponent_field_knights[i], "zone": "field_knight", "index": i, "owner": opponent_num}
	
	for i in range(opponent_field_techniques.size()):
		if opponent_field_techniques[i] and opponent_field_techniques[i].instance_id == instance_id:
			return {"found": true, "card": opponent_field_techniques[i], "zone": "field_tech_object", "index": i, "owner": opponent_num}
	
	if opponent_helper and opponent_helper.instance_id == instance_id:
		return {"found": true, "card": opponent_helper, "zone": "field_helper", "index": 0, "owner": opponent_num}
	
	if opponent_occasion and opponent_occasion.instance_id == instance_id:
		return {"found": true, "card": opponent_occasion, "zone": "field_occasion", "index": 0, "owner": opponent_num}
	
	if scenario and scenario.instance_id == instance_id:
		return {"found": true, "card": scenario, "zone": "field_scenario", "index": 0, "owner": 0}  # Scenario no tiene dueño
	
	# Buscar en cementerio
	for i in range(player_graveyard.size()):
		if player_graveyard[i].instance_id == instance_id:
			return {"found": true, "card": player_graveyard[i], "zone": "yomotsu", "index": i, "owner": player_number}
	
	for i in range(opponent_graveyard.size()):
		if opponent_graveyard[i].instance_id == instance_id:
			return {"found": true, "card": opponent_graveyard[i], "zone": "yomotsu", "index": i, "owner": opponent_num}
	
	return {"found": false}  # No encontrada - formato consistente


func get_card_by_instance_id(instance_id: String) -> CardInstance:
	"""Buscar carta por su instance_id en todas las zonas"""
	var location = find_card_location(instance_id)
	return location.get("card", null)


func to_dict() -> Dictionary:
	"""Serializar para debug o guardar estado"""
	return {
		"match_id": match_id,
		"turn": current_turn,
		"phase": current_phase,
		"active_player": active_player_number,
		"player_number": player_number,
		"player_life": player_life,
		"opponent_life": opponent_life,
		"player_cosmos": player_cosmos,
		"opponent_cosmos": opponent_cosmos,
		"player_hand_count": player_hand.size(),
		"player_field_count": _count_non_null(player_field_knights),
		"opponent_field_count": _count_non_null(opponent_field_knights),
		"is_my_turn": is_my_turn()
	}


func _count_non_null(array: Array) -> int:
	"""Helper: Contar elementos no-null en array"""
	var count = 0
	for item in array:
		if item != null:
			count += 1
	return count

# =========================================================
# APLICAR ACTUALIZACIONES INCREMENTALES
# =========================================================
func apply_update(data: Dictionary, local_player_id: String) -> void:
	"""
	Actualizar parcialmente el estado con nuevos datos del servidor.
	NO destruye arrays, NO reemplaza todo el estado.
	Actualiza solo lo que cambia: vidas, cosmos, cartas nuevas,
	cambio de fase, turno, etc.
	"""

	# Turno y fase
	if data.has("current_turn"):
		current_turn = data["current_turn"]

	if data.has("phase"):
		current_phase = data["phase"]

	if data.has("current_player"):
		active_player_number = data["current_player"]

	# Recursos
	if player_number == 1:
		if data.has("player1_life"):
			player_life = data["player1_life"]
		if data.has("player1_cosmos"):
			player_cosmos = data["player1_cosmos"]

		if data.has("player2_life"):
			opponent_life = data["player2_life"]
		if data.has("player2_cosmos"):
			opponent_cosmos = data["player2_cosmos"]
	else:
		if data.has("player2_life"):
			player_life = data["player2_life"]
		if data.has("player2_cosmos"):
			player_cosmos = data["player2_cosmos"]

		if data.has("player1_life"):
			opponent_life = data["player1_life"]
		if data.has("player1_cosmos"):
			opponent_cosmos = data["player1_cosmos"]

	# Si llegan cartas actualizadas (ej: card_played, turn_changed)
	if data.has("cards_in_play"):
		_update_cards_in_play(data["cards_in_play"], local_player_id)

	# Mano (solo si el servidor manda conteo o los IDs)
	if data.has("player1_hand_count") or data.has("player2_hand_count"):
		opponent_hand_count = (
			data.get("player2_hand_count") if player_number == 1 else data.get("player1_hand_count")
		)

func _update_cards_in_play(cards_data: Array, _local_player_id: String) -> void:
	"""
	Reconstruye SOLO las cartas tocadas por la actualización.
	NO borra toda la mano/campo.
	"""

	# Primero limpio solo posiciones afectadas:
	# (no puedo borrar todo porque rompe animaciones/drag & drop)
	
	# Mapeo temporal para actualizar después
	var new_knights_p1 = {}
	var new_knights_p2 = {}
	var new_tech_p1 = {}
	var new_tech_p2 = {}
	var new_helpers = {}
	var new_occasions = {}
	var new_scenario = null

	for info in cards_data:
		var player_n = info.get("player_number")
		var zone = info.get("zone")
		var pos = info.get("position", 0)

		var card_instance = CardInstance.from_server_data(info)

		var is_mine = (player_n == player_number)

		match zone:
			"field_knight":
				if is_mine:
					new_knights_p1[pos] = card_instance
				else:
					new_knights_p2[pos] = card_instance

			"field_tech_object":
				if is_mine:
					new_tech_p1[pos] = card_instance
				else:
					new_tech_p2[pos] = card_instance

			"field_helper":
				new_helpers[player_n] = card_instance

			"field_occasion":
				new_occasions[player_n] = card_instance

			"field_scenario":
				new_scenario = card_instance

	# Aplicar cambios EXISTENTES sin borrar todo

	for pos in new_knights_p1.keys():
		_set_in_array(player_field_knights, pos, new_knights_p1[pos])

	for pos in new_knights_p2.keys():
		_set_in_array(opponent_field_knights, pos, new_knights_p2[pos])

	for pos in new_tech_p1.keys():
		_set_in_array(player_field_techniques, pos, new_tech_p1[pos])

	for pos in new_tech_p2.keys():
		_set_in_array(opponent_field_techniques, pos, new_tech_p2[pos])

	if new_helpers.has(player_number):
		player_helper = new_helpers[player_number]
	if new_helpers.has(3 - player_number):
		opponent_helper = new_helpers[3 - player_number]

	if new_occasions.has(player_number):
		player_occasion = new_occasions[player_number]
	if new_occasions.has(3 - player_number):
		opponent_occasion = new_occasions[3 - player_number]

	if new_scenario:
		scenario = new_scenario
