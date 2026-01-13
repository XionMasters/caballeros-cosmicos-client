# CardCostValidator.gd
# Validador genérico para costos de cartas (mana, cosmos, energía, etc)
# Reutilizable por GameBoard, TestBoard, y cualquier sistema de juego
class_name CardCostValidator
extends Node

# Tipos de recursos disponibles
enum ResourceType {
	MANA,      # Azul (magia)
	COSMOS,    # Dorado (poder cósmico)
	ENERGY,    # Rojo (energía)
	HEALTH,    # Verde (vida)
	GENERIC    # Gris (genérico)
}

# Información de costo de una carta
class CostInfo:
	var card_instance: CardInstance
	var primary_cost: int      # Costo principal (cosmos, mana, etc)
	var secondary_costs: Dictionary = {}  # Costos adicionales { ResourceType: amount }
	var special_conditions: Array = []    # Condiciones especiales para jugar
	
	func _init(instance: CardInstance) -> void:
		card_instance = instance
		primary_cost = instance.base_data.cost if instance and instance.base_data else 0


# Variables de sistema
var player_resources: Dictionary = {}  # { ResourceType: amount }
var cost_modifiers: Dictionary = {}    # Multiplicadores/ajustes de costo


func _ready() -> void:
	# Inicializar recursos del jugador
	reset_player_resources()


func reset_player_resources() -> void:
	"""Resetear recursos del jugador al valor por defecto"""
	player_resources = {
		ResourceType.COSMOS: 0,
		ResourceType.MANA: 0,
		ResourceType.ENERGY: 0,
		ResourceType.HEALTH: 20
	}


func set_player_resource(resource_type: ResourceType, amount: int) -> void:
	"""Establecer cantidad de un recurso"""
	player_resources[resource_type] = max(0, amount)


func add_player_resource(resource_type: ResourceType, amount: int) -> int:
	"""Agregar recurso al jugador, retorna nueva cantidad"""
	var current = player_resources.get(resource_type, 0)
	var new_amount = current + amount
	player_resources[resource_type] = new_amount
	print("[CardCostValidator] +%d %s (Anterior: %d → Nuevo: %d)" % [amount, ResourceType.keys()[resource_type], current, new_amount])
	return new_amount


func subtract_player_resource(resource_type: ResourceType, amount: int) -> bool:
	"""Restar recurso, retorna true si hay suficiente"""
	var current = player_resources.get(resource_type, 0)
	if current >= amount:
		player_resources[resource_type] = current - amount
		print("[CardCostValidator] -%d %s (Anterior: %d → Nuevo: %d)" % [amount, ResourceType.keys()[resource_type], current, player_resources[resource_type]])
		return true
	return false


func can_afford_card(card_instance: CardInstance) -> bool:
	"""Verificar si el jugador puede permitirse jugar esta carta"""
	if not card_instance or not card_instance.base_data:
		return false
	
	var cost = card_instance.base_data.cost
	var current_cosmos = player_resources.get(ResourceType.COSMOS, 0)
	
	var can_afford = current_cosmos >= cost
	
	if not can_afford:
		print("[CardCostValidator] ❌ NO puede permitirse %s (Costo: %d, Cosmos: %d)" % [card_instance.base_data.name, cost, current_cosmos])
	else:
		print("[CardCostValidator] ✅ Puede permitirse %s (Costo: %d, Cosmos: %d)" % [card_instance.base_data.name, cost, current_cosmos])
	
	return can_afford


func get_card_cost(card_instance: CardInstance) -> int:
	"""Obtener costo final de una carta (con modificadores)"""
	if not card_instance or not card_instance.base_data:
		return 0
	
	var base_cost = card_instance.base_data.cost
	var modifier = cost_modifiers.get("global_multiplier", 1.0)
	var adjusted_cost = int(base_cost * modifier)
	
	return max(0, adjusted_cost)


func play_card(card_instance: CardInstance) -> bool:
	"""Jugar una carta - valida costo y resta recurso"""
	if not can_afford_card(card_instance):
		return false
	
	var cost = get_card_cost(card_instance)
	return subtract_player_resource(ResourceType.COSMOS, cost)


func get_remaining_resources() -> Dictionary:
	"""Obtener copia de recursos actuales del jugador"""
	return player_resources.duplicate()


func debug_print_resources() -> void:
	"""Imprimir estado de recursos para debugging"""
	print("\n[CardCostValidator] === RECURSOS DEL JUGADOR ===")
	for resource_type in ResourceType.values():
		var type_name = ResourceType.keys()[resource_type]
		var amount = player_resources.get(resource_type, 0)
		print("  %s: %d" % [type_name, amount])
	print("[CardCostValidator] ============================\n")

