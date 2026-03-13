# EngineEventTranslator.gd
# Traduce engine_events del servidor (Array de Dictionaries) a AnimationEvents.
#
# El servidor envía:
#   [
#     { "type": "DAMAGE_DEALT",  "playerNumber": 1, "targetCardId": "...", "payload": { "amount": 5, "instanceId": "..." } },
#     { "type": "DAMAGE_LETHAL", "playerNumber": 1, "targetCardId": "...", "payload": { "amount": 5, "instanceId": "..." } },
#     { "type": "KNIGHT_DIED",   "playerNumber": 1, "payload": { "instanceId": "...", "owner": 1, "card_code": "ikki_phoenix" } },
#     { "type": "KNIGHT_SUMMONED", ... },
#     ...
#   ]
#
# Este traductor los convierte en AnimationEvent concretos para la cola del Orchestrator.
# DAMAGE_LETHAL no genera evento propio — DamageEvent(is_lethal=true) ya lo maneja.

class_name EngineEventTranslator
extends RefCounted

## Convierte un array de engine_events del servidor en AnimationEvents listos para la cola.
## @param events   Array de Dictionary (gs.engine_events)
## @param player_number_hint   Número de jugador del cliente local (para resolver perspectiva)
static func translate(events: Array, player_number_hint: int) -> Array:
	var result: Array = []
	var i := 0
	while i < events.size():
		var evt: Dictionary = events[i]
		var type: String = evt.get("type", "")
		var payload: Dictionary = evt.get("payload", {})
		var player_num: int = evt.get("playerNumber", 0)
		var source_id: String = evt.get("sourceCardId", "")
		var target_id: String = evt.get("targetCardId", "")

		match type:
			"DAMAGE_DEALT":
				# Mirar si el siguiente evento es DAMAGE_LETHAL para el mismo instanceId
				var amount: int = payload.get("amount", 0)
				var instance_id: String = payload.get("instanceId", target_id)
				var is_lethal := false
				if i + 1 < events.size():
					var next: Dictionary = events[i + 1]
					if next.get("type", "") == "DAMAGE_LETHAL" and \
							next.get("payload", {}).get("instanceId", "") == instance_id:
						is_lethal = true
						i += 1  # saltar DAMAGE_LETHAL — absorbido por DamageEvent
				result.append(DamageEvent.new(instance_id, amount, is_lethal, source_id))

			"DAMAGE_LETHAL":
				# Solo llega aquí si NO fue absorbido por el DAMAGE_DEALT anterior.
				# Crear un DamageEvent lethal mínimo.
				var instance_id: String = payload.get("instanceId", target_id)
				var amount: int = payload.get("amount", 0)
				result.append(DamageEvent.new(instance_id, amount, true, source_id))

			"KNIGHT_DIED":
				var instance_id: String = payload.get("instanceId", target_id)
				var card_code: String = payload.get("card_code", "")
				var owner: int = payload.get("owner", player_num)
				result.append(KnightDiedEvent.new(instance_id, card_code, owner))

			"HEAL_RECEIVED":
				var instance_id: String = payload.get("instanceId", target_id)
				var amount: int = payload.get("amount", 0)
				result.append(HealEvent.new(instance_id, amount))

			"KNIGHT_SUMMONED":
				var instance_id: String = payload.get("instanceId", source_id)
				var card_code: String = payload.get("card_code", "")
				var owner: int = payload.get("owner", player_num)
				var from_zone: String = payload.get("from_zone", "yomotsu")
				var position: int = payload.get("position", 0)
				var ev := KnightSummonedEvent.new(instance_id, card_code, owner, from_zone, position)
				ev.player_number_hint = player_number_hint
				result.append(ev)

			"CARD_PLAYED":
				var zone: String = payload.get("zone", "field_knight")
				var position: int = payload.get("position", 0)
				result.append(CardPlayedEvent.new(source_id, zone, position))

			"COSMOS_CHARGED":
				var amount: int = payload.get("amount", 0)
				var total: int = payload.get("totalCosmos", 0)
				result.append(CosmosChargedEvent.new(player_num, amount, total))

			"ALLY_DREW_CARD", "OPPONENT_DREW_CARD":
				# El robo de carta se maneja por DrawCardsEvent / DrawOpponentCardsEvent
				# del StateDiffer — no duplicamos aquí.
				pass

			"TURN_END", "TURN_START":
				# Sin animación visual propia por ahora.
				pass

			# ALLY_DIED es un alias semántico de KNIGHT_DIED — ignorar para no duplicar.
			"ALLY_DIED":
				pass

		i += 1

	return result
