# CardInstance.gd
# Instancia dinámica de una carta en partida
# Mantiene estado actual: vida, buffs, posición, acciones, etc.
class_name CardInstance

# ---------------------------------------------------------
# Señales
# ---------------------------------------------------------
signal stats_changed(inst)
signal died(inst)
signal status_added(inst, status)
signal buff_added(inst, buff)
# signal position_changed(inst, old_pos, new_pos)  # Actualmente no usado
# signal mode_changed(inst, old_mode, new_mode)  # Actualmente no usado

# ---------------------------------------------------------
# Datos base (no cambian)
# ---------------------------------------------------------
var base_data: CardData               # Template de la carta
var instance_id: String               # ID único en la partida
var owner_id: String                  # Jugador dueño

# ---------------------------------------------------------
# Posición en partida
# ---------------------------------------------------------
var position: int = 0         # Position SIEMPRE es int
var field_slot: int = -1              # slot en el tablero
var is_revealed: bool = true          # false permite ocultar al oponente
var zone: String = "deck"     # Zona: hand / field / deck / graveyard

# ---------------------------------------------------------
# Estado de combate
# ---------------------------------------------------------
var mode: String = "normal"           # normal, defense, evade, prayer
var is_exhausted: bool = false        # ¿ya actuó este turno?

# ---------------------------------------------------------
# Stats dinámicos (modificados por daño o buffs)
# ---------------------------------------------------------
var current_health: int = 0
var max_health: int = 0              # HP máximo (puede aumentar con buffs)
var current_attack: int = 0
var current_defense: int = 0

# ---------------------------------------------------------
# Efectos temporales
# ---------------------------------------------------------
var status_effects: Array = []        # [{type, duration, value}]
var temporary_buffs: Array = []       # [{stat, value, duration}]
var actions_this_turn: Array[String] = []

# ---------------------------------------------------------
# Adjuntos / Equipos
# ---------------------------------------------------------
var attached_cards: Array[CardInstance] = []
var equipped_item: CardInstance = null

# =========================================================
# CONSTRUCTORES
# =========================================================
static func from_card_data(card: CardData, owner: String) -> CardInstance:
	var inst = CardInstance.new()
	inst.base_data = card
	inst.owner_id = owner
	inst.instance_id = "%s_%d_%d" % [card.id, Time.get_ticks_msec(), randi()]

	# Stats iniciales (solo para knights)
	if card.type == "knight":
		inst.max_health = card.health
		inst.current_health = card.health
		inst.current_attack = card.attack
		inst.current_defense = card.defense

	return inst


static func from_server_data(data: Dictionary) -> CardInstance:
	var inst = CardInstance.new()
	inst.instance_id = data.get("id", "")
	inst.owner_id = data.get("owner_id", "")
	
	# Normalizar position a int (puede venir como float o string)
	var raw_pos = data.get("position", 0)
	inst.position = int(raw_pos)
	
	# Normalizar zone a string
	inst.zone = str(data.get("zone", "deck"))
	inst.field_slot = data.get("field_slot", -1)
	inst.mode = data.get("mode", "normal")
	inst.is_exhausted = data.get("is_exhausted", false)
	inst.is_revealed = data.get("is_revealed", true)

	# Buscar base_data o card (servidor puede enviar ambos)
	var card_data = data.get("base_data", data.get("card", {}))
	if card_data:
		inst.base_data = CardData.from_json(card_data)

	var bd = inst.base_data
	inst.max_health = data.get("max_health", bd.health if bd else 0)
	inst.current_health = data.get("current_health", bd.health if bd else 0)
	inst.current_attack = data.get("current_attack", bd.attack if bd else 0)
	inst.current_defense = data.get("current_defense", bd.defense if bd else 0)

	# Validar arrays
	var raw_status = data.get("status_effects", [])
	inst.status_effects = raw_status if typeof(raw_status) == TYPE_ARRAY else []
	var raw_buffs = data.get("buffs", [])
	inst.temporary_buffs = raw_buffs if typeof(raw_buffs) == TYPE_ARRAY else []
	
	var actions_array = data.get("actions_this_turn", [])
	if actions_array is Array:
		inst.actions_this_turn.clear()
		for action in actions_array:
			inst.actions_this_turn.append(str(action))

	return inst

# =========================================================
# COMBATE Y DAÑO
# =========================================================
func apply_damage(amount: int) -> int:
	if base_data.type != "knight":
		push_warning("Intentando aplicar daño a carta que no es knight: %s" % base_data.name)
		return 0
	
	var real_damage = max(1, amount - current_defense)
	current_health -= real_damage

	stats_changed.emit(self)

	if current_health <= 0:
		died.emit(self)

	return real_damage


func heal(amount: int) -> int:
	"""Cura HP respetando el max_health actual"""
	if base_data.type != "knight":
		return 0
	
	var old_health = current_health
	current_health = min(current_health + amount, max_health)
	var healed = current_health - old_health
	
	if healed > 0:
		stats_changed.emit(self)
	
	return healed

# =========================================================
# BUFFS Y ESTADOS
# =========================================================
func apply_buff(stat: String, value: int, duration: int = 1):
	var buff = {"stat": stat, "value": value, "duration": duration}
	temporary_buffs.append(buff)

	_recalculate_stats()
	buff_added.emit(self, buff)


func apply_status_effect(effect_type: String, duration: int, value := 0):
	var status = {"type": effect_type, "duration": duration, "value": value}
	status_effects.append(status)
	status_added.emit(self, status)


func has_status(effect_type: String) -> bool:
	for effect in status_effects:
		if effect["type"] == effect_type:
			return true
	return false

# =========================================================
# ACCIONES
# =========================================================
func can_perform_action(action: String) -> bool:
	if is_exhausted:
		return false

	match action:
		"attack":
			return not has_status("frozen")
		"technique":
			return not has_status("silenced")
		"charge_cosmos":
			return true
		"move":
			return not has_status("rooted")
		_:
			return true


func mark_action_used(action: String):
	actions_this_turn.append(action)

	if action in ["attack", "technique"]:
		is_exhausted = true

# =========================================================
# TURNO
# =========================================================
func reset_turn():
	is_exhausted = false
	actions_this_turn.clear()
	
	var had_changes = false

	# Buffs
	for i in range(temporary_buffs.size() - 1, -1, -1):
		temporary_buffs[i]["duration"] -= 1
		if temporary_buffs[i]["duration"] <= 0:
			temporary_buffs.remove_at(i)
			had_changes = true

	# Estados
	for i in range(status_effects.size() - 1, -1, -1):
		status_effects[i]["duration"] -= 1
		if status_effects[i]["duration"] <= 0:
			status_effects.remove_at(i)
			had_changes = true

	if had_changes:
		_recalculate_stats()

# =========================================================
# RECALCULAR STATS
# =========================================================
func _recalculate_stats():
	if not base_data:
		return
	
	# Solo knights tienen stats de combate
	if base_data.type != "knight":
		return

	current_attack = base_data.attack
	current_defense = base_data.defense
	max_health = base_data.health

	# Buffs temporales
	for buff in temporary_buffs:
		match buff["stat"]:
			"attack": current_attack += buff["value"]
			"defense": current_defense += buff["value"]
			"max_health": max_health += buff["value"]  # Buffs aumentan HP máximo, no current

	# Equipamiento (solo si tiene stats)
	if equipped_item and equipped_item.base_data:
		if equipped_item.base_data.attack > 0:
			current_attack += equipped_item.base_data.attack
		if equipped_item.base_data.defense > 0:
			current_defense += equipped_item.base_data.defense
		if equipped_item.base_data.health > 0:
			max_health += equipped_item.base_data.health
	
	# Clampear current_health al nuevo max_health
	current_health = min(current_health, max_health)

	stats_changed.emit(self)

# =========================================================
# UTILIDAD
# =========================================================
func is_alive() -> bool:
	if base_data and base_data.type == "knight":
		return current_health > 0
	return true  # Técnicas/objetos no "mueren"

# =========================================================
# SERIALIZACIÓN
# =========================================================
func to_dict() -> Dictionary:
	return {
		"id": instance_id,
		"card_id": base_data.id if base_data else "",
		"owner_id": owner_id,
		"position": position,
		"zone": zone,
		"field_slot": field_slot,
		"mode": mode,
		"current_health": current_health,
		"max_health": max_health,
		"current_attack": current_attack,
		"current_defense": current_defense,
		"is_exhausted": is_exhausted,
		"status_effects": status_effects,
		"buffs": temporary_buffs,
		"actions_this_turn": actions_this_turn
	}
