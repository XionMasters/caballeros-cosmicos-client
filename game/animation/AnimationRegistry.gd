# AnimationRegistry.gd
# Mapea last_action del servidor a metadata de animación y sonido.
#
# División de responsabilidades:
#   Servidor → QUÉ pasó          (type, attacker_id, defender_id, damage)
#   Cliente  → CÓMO mostrarlo    (color, duración, sonido, voz)
#
# Para agregar la animación de una técnica específica, agrega una entrada
# a TECHNIQUE_META con el UUID de la técnica como clave:
#
#   "uuid-meteoros-de-pegaso": {
#       "color": Color.ORANGE_RED,
#       "duration": 1.2,
#       "sound": "sfx_meteoros.ogg",
#       "voice": "seiya_meteoros.ogg",
#   }

class_name AnimationRegistry
extends RefCounted


# ============================================================================
# ATAQUES BÁSICOS — por tipo de carta del atacante
# ============================================================================
const ATTACK_META: Dictionary = {
	"knight":    { "color": Color.GOLD,       "duration": 0.4 },
	"technique": { "color": Color.SKY_BLUE,   "duration": 0.6 },
	"item":      { "color": Color.SILVER,     "duration": 0.3 },
	"helper":    { "color": Color.GREEN,      "duration": 0.4 },
}

# ============================================================================
# TÉCNICAS ESPECÍFICAS — clave = technique_id del servidor (UUID de la carta)
# Agrega aquí las técnicas a medida que se implementen sus animaciones.
# ============================================================================
const TECHNIQUE_META: Dictionary = {
	# Ejemplo (descomenta y reemplaza el UUID cuando tengás el audio/animación):
	# "uuid-meteoros-de-pegaso": {
	#     "color": Color.ORANGE_RED,
	#     "duration": 1.2,
	#     "sound": "sfx_meteoros.ogg",
	#     "voice": "seiya_meteoros.ogg",
	# },
	# "uuid-excalibur": {
	#     "color": Color.WHITE,
	#     "duration": 0.8,
	#     "sound": "sfx_excalibur.ogg",
	#     "voice": "aiolia_excalibur.ogg",
	# },
}


# ============================================================================
# API PÚBLICA
# ============================================================================

## Devuelve la metadata de animación para un last_action del servidor.
## Siempre retorna un Dictionary válido (con defaults si no hay entrada registrada).
## El llamador puede leer: "color", "duration", "sound", "voice".
static func lookup(last_action: Dictionary) -> Dictionary:
	var action_type: String = last_action.get("type", "")
	match action_type:
		"attack":
			var card_type: String = last_action.get("attacker_card_type", "knight")
			return ATTACK_META.get(card_type, _default_attack()).duplicate()
		"technique":
			var tid: String = last_action.get("technique_id", "")
			if TECHNIQUE_META.has(tid):
				return TECHNIQUE_META[tid].duplicate()
			return _default_technique()
		_:
			return {}


static func _default_attack() -> Dictionary:
	return { "color": Color.GOLD, "duration": 0.4 }


static func _default_technique() -> Dictionary:
	return { "color": Color.SKY_BLUE, "duration": 0.6 }
