# CombatCalculator.gd
# Calcula daño según las reglas del juego
class_name CombatCalculator
extends RefCounted

enum AttackMode {
	NORMAL,     # Ataque normal: CE - AR = Daño
	BLOCK,      # Modo defensa: (CE/2) - AR = Daño
	EVADE       # Modo evasión: 50% chance de esquivar completamente
}

# Calcular daño de un ataque
static func calculate_damage(attacker_ce: int, defender_ar: int, attack_mode: AttackMode = AttackMode.NORMAL, is_technique: bool = false) -> Dictionary:
	"""
	Calcula el daño de un ataque según el modo
	
	Retorna:
		{
			"damage": int,
			"evaded": bool,
			"attack_mode": AttackMode,
			"calculation": String (para mostrar al usuario)
		}
	"""
	var result = {
		"damage": 0,
		"evaded": false,
		"attack_mode": attack_mode,
		"calculation": ""
	}
	
	match attack_mode:
		AttackMode.NORMAL:
			var raw_damage = attacker_ce - defender_ar
			result.damage = max(1, raw_damage)  # Mínimo 1 de daño
			result.calculation = "%d (CE) - %d (AR) = %d" % [attacker_ce, defender_ar, result.damage]
		
		AttackMode.BLOCK:
			var half_ce = int(attacker_ce / 2.0)
			var raw_damage = half_ce - defender_ar
			result.damage = max(0, raw_damage)  # Puede ser 0 si la defensa es muy alta
			result.calculation = "(%d CE / 2) - %d AR = %d" % [attacker_ce, defender_ar, result.damage]
		
		AttackMode.EVADE:
			# Solo BA (ataques básicos) pueden ser evadidos
			# Técnicas (TA) ignoran evasión
			if is_technique:
				var raw_damage = attacker_ce - defender_ar
				result.damage = max(1, raw_damage)
				result.evaded = false
				result.calculation = "%d (CE) - %d (AR) = %d (Técnica ignora evasión)" % [attacker_ce, defender_ar, result.damage]
			else:
				# Tirar moneda: 50% de evadir
				var coin_flip = randf() < 0.5
				if coin_flip:
					result.damage = 0
					result.evaded = true
					result.calculation = "EVADIDO! (Coin flip: Tails)"
				else:
					var raw_damage = attacker_ce - defender_ar
					result.damage = max(1, raw_damage)
					result.evaded = false
					result.calculation = "%d (CE) - %d (AR) = %d (Coin flip: Heads)" % [attacker_ce, defender_ar, result.damage]
	
	return result

# Calcular daño con técnica
static func calculate_technique_damage(technique_power: int, attacker_ce: int, defender_ar: int, defender_mode: AttackMode) -> Dictionary:
	"""
	Calcula daño de técnica
	La técnica agrega poder adicional al CE del atacante
	"""
	var effective_ce = attacker_ce + technique_power
	return calculate_damage(effective_ce, defender_ar, defender_mode, true)

# Verificar si un ataque puede ejecutarse
static func can_attack(attacker_cosmos: int, attack_cost: int) -> bool:
	"""Verificar si hay suficiente cosmos para atacar"""
	return attacker_cosmos >= attack_cost

# Calcular cosmos ganado por turno
static func calculate_cosmos_gain(base_gain: int = 1, charge_ability: bool = false) -> int:
	"""
	Calcular cosmos ganado
	- Base: 1 CP por turno
	- Cargar Cosmo: +3 CP adicionales
	"""
	var total = base_gain
	if charge_ability:
		total += 3
	return total

# Verificar si una carta puede ser jugada
static func can_play_card(player_cosmos: int, card_cost: int) -> bool:
	"""Verificar si hay suficiente cosmos para jugar una carta"""
	return player_cosmos >= card_cost
