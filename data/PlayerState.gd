# PlayerState.gd
# Gestor genérico del estado del jugador (cosmos, vida, cartas dibujadas, etc)
# Reutilizable por GameBoard y TestBoard
class_name PlayerState
extends Node

signal cosmos_changed(new_amount: int, old_amount: int)
signal health_changed(new_amount: int, old_amount: int)
signal cards_drawn(count: int)
signal player_defeated

var player_id: String = ""
var player_number: int = 0  # 1 o 2

# Recursos del jugador
var current_cosmos: int = 0
var max_cosmos: int = 0
var current_health: int = 20
var max_health: int = 20

# Estadísticas de la partida
var cards_in_hand: int = 0
var cards_in_deck: int = 0
var cards_on_field: int = 0
var cards_exhausted: int = 0

# Estado de turno
var is_turn_active: bool = false


func _init(id: String, number: int) -> void:
	player_id = id
	player_number = number


func reset_for_new_match() -> void:
	"""Resetear estado para una nueva partida"""
	current_cosmos = 0
	max_cosmos = 5
	current_health = 20
	max_health = 20
	cards_in_hand = 0
	cards_in_deck = 40
	cards_on_field = 0
	cards_exhausted = 0
	is_turn_active = false


func add_cosmos(amount: int) -> void:
	"""Agregar cosmos (no excede máximo)"""
	var old_cosmos = current_cosmos
	current_cosmos = min(current_cosmos + amount, max_cosmos)
	
	if current_cosmos != old_cosmos:
		cosmos_changed.emit(current_cosmos, old_cosmos)
		print("[PlayerState] +%d Cosmos (P%d: %d → %d)" % [amount, player_number, old_cosmos, current_cosmos])


func subtract_cosmos(amount: int) -> bool:
	"""Restar cosmos, retorna true si hay suficiente"""
	if current_cosmos >= amount:
		var old_cosmos = current_cosmos
		current_cosmos -= amount
		cosmos_changed.emit(current_cosmos, old_cosmos)
		print("[PlayerState] -%d Cosmos (P%d: %d → %d)" % [amount, player_number, old_cosmos, current_cosmos])
		return true
	return false


func take_damage(amount: int) -> void:
	"""Recibir daño"""
	var old_health = current_health
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, old_health)
	
	print("[PlayerState] -%d HP (P%d: %d → %d)" % [amount, player_number, old_health, current_health])
	
	if current_health <= 0:
		player_defeated.emit()
		print("[PlayerState] ⚠️ Jugador %d derrotado!" % player_number)


func heal(amount: int) -> void:
	"""Sanar"""
	var old_health = current_health
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, old_health)
	
	print("[PlayerState] +%d HP (P%d: %d → %d)" % [amount, player_number, old_health, current_health])


func draw_cards(count: int) -> void:
	"""Registrar que se dibujaron cartas"""
	cards_in_hand += count
	cards_in_deck = max(0, cards_in_deck - count)
	cards_drawn.emit(count)
	
	print("[PlayerState] 🃏 P%d dibujó %d cartas (Mano: %d, Mazo: %d)" % [player_number, count, cards_in_hand, cards_in_deck])


func play_card() -> void:
	"""Registrar que se jugó una carta"""
	cards_in_hand = max(0, cards_in_hand - 1)
	cards_on_field += 1
	
	print("[PlayerState] 🎴 P%d jugó una carta (Mano: %d, Campo: %d)" % [player_number, cards_in_hand, cards_on_field])


func get_cosmos_percentage() -> float:
	"""Obtener cosmos como porcentaje del máximo"""
	if max_cosmos <= 0:
		return 0.0
	return float(current_cosmos) / float(max_cosmos)


func get_health_percentage() -> float:
	"""Obtener salud como porcentaje del máximo"""
	if max_health <= 0:
		return 0.0
	return float(current_health) / float(max_health)


func is_alive() -> bool:
	"""Verificar si el jugador está vivo"""
	return current_health > 0


func can_afford_cost(cost: int) -> bool:
	"""Verificar si puede permitirse un costo"""
	return current_cosmos >= cost


func debug_print_state() -> void:
	"""Imprimir estado para debugging"""
	print("\n[PlayerState] === P%d STATE ===" % player_number)
	print("  Cosmos: %d/%d" % [current_cosmos, max_cosmos])
	print("  Salud: %d/%d" % [current_health, max_health])
	print("  Mano: %d | Campo: %d | Mazo: %d" % [cards_in_hand, cards_on_field, cards_in_deck])
	print("  Turno activo: %s" % ("SÍ" if is_turn_active else "NO"))
	print("[PlayerState] =================\n")

