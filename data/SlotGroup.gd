## @brief Gestor unificado de groups de slots
## Elimina duplicación de arrays manual de slots en GameBoard
##
## Uso:
##   var knight_slots = SlotGroup.new("knights", 5)
##   knight_slots.initialize_from_nodes(board.player_knight_slots)
##   knight_slots.all_slots -> Array[CardSlot]
##   knight_slots.get_empty_slots() -> Array[CardSlot]

class_name SlotGroup
extends Node

## Tipo de slot (knights, techniques, items, etc)
var slot_type: String = ""

## Array de todos los slots en este grupo
var all_slots: Array[CardSlot] = []

## Máximo de slots permitidos
var max_slots: int = 5

## Configuración por tipo
var config: Dictionary = {}


func _init(p_slot_type: String, p_max_slots: int = 5) -> void:
	slot_type = p_slot_type
	max_slots = p_max_slots
	_setup_default_config()


## Inicializa slots desde nodos en la escena
func initialize_from_nodes(slot_nodes: Array) -> void:
	all_slots.clear()
	
	for i in range(mini(slot_nodes.size(), max_slots)):
		var node = slot_nodes[i]
		if node is CardSlot:
			all_slots.append(node)
		else:
			push_warning("SlotGroup: Node no es CardSlot: %s" % node.name)


## Obtiene todos los slots vacíos
func get_empty_slots() -> Array[CardSlot]:
	var empty: Array[CardSlot] = []
	
	for slot in all_slots:
		if slot.is_empty():
			empty.append(slot)
	
	return empty


## Obtiene el primer slot vacío disponible
func get_first_empty_slot() -> CardSlot:
	for slot in all_slots:
		if slot.is_empty():
			return slot
	return null


## Obtiene slots ocupados
func get_occupied_slots() -> Array[CardSlot]:
	var occupied: Array[CardSlot] = []
	
	for slot in all_slots:
		if not slot.is_empty():
			occupied.append(slot)
	
	return occupied


## Obtiene slot por índice
func get_slot_at(index: int) -> CardSlot:
	if index >= 0 and index < all_slots.size():
		return all_slots[index]
	return null


## Limpia todos los slots
func clear_all() -> void:
	for slot in all_slots:
		slot.clear()


## Obtiene cantidad de slots disponibles
func get_available_count() -> int:
	return get_empty_slots().size()


## Obtiene cantidad de slots ocupados
func get_occupied_count() -> int:
	return get_occupied_slots().size()


## Verifica si el grupo está lleno
func is_full() -> bool:
	return get_available_count() == 0


## Conecta señal a todos los slots
func connect_signal_all(signal_name: String, callable: Callable) -> void:
	for slot in all_slots:
		if slot.has_signal(signal_name):
			slot.connect(signal_name, callable)


## Desconecta señal de todos los slots
func disconnect_signal_all(signal_name: String, callable: Callable) -> void:
	for slot in all_slots:
		if slot.is_connected(signal_name, callable):
			slot.disconnect(signal_name, callable)


## Itera sobre cada slot (utility method)
func for_each(callback: Callable) -> void:
	for slot in all_slots:
		callback.call(slot)


## Itera sobre slots vacíos
func for_each_empty(callback: Callable) -> void:
	for slot in get_empty_slots():
		callback.call(slot)


## Itera sobre slots ocupados
func for_each_occupied(callback: Callable) -> void:
	for slot in get_occupied_slots():
		callback.call(slot)


## Obtiene representación visual de estado (debug)
func get_debug_status() -> String:
	var occupied = get_occupied_count()
	var total = all_slots.size()
	var status = "%s: %d/%d (" % [slot_type.to_upper(), occupied, total]
	
	for slot in all_slots:
		status += "■" if not slot.is_empty() else "□"
	
	status += ")"
	return status


## Imprime debug de estado
func debug_print() -> void:
	print(get_debug_status())


# ==================== MÉTODOS PRIVADOS ====================

## Configura valores por defecto según tipo
func _setup_default_config() -> void:
	config = {
		"type": slot_type,
		"max_slots": max_slots,
		"allow_multiple_same_card": false,
		"require_min_stats": false,
	}
	
	match slot_type:
		"knights":
			config["max_slots"] = 5
			config["require_min_stats"] = true
		"techniques":
			config["max_slots"] = 5
			config["allow_multiple_same_card"] = true
		"items":
			config["max_slots"] = 3
		"helpers":
			config["max_slots"] = 1
		"scenarios":
			config["max_slots"] = 1
		"piles":
			config["max_slots"] = 999  # Unlimited
