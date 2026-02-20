# UserProfile.gd
# Modelo de datos del usuario (NO es Node, es clase de datos)
class_name UserProfile
extends RefCounted

# Datos básicos
var id: String = ""
var username: String = ""
var email: String = ""

# Datos de juego
var currency: int = 0
var avatar_url: String = ""
var level: int = 1
var experience: int = 0

# Mazos
var active_deck_id: String = ""
var deck_count: int = 0

# Estadísticas
var wins: int = 0
var losses: int = 0
var total_matches: int = 0

# Metadata
var created_at: String = ""
var last_login: String = ""


static func from_dict(data: Dictionary) -> UserProfile:
	"""Crear UserProfile desde diccionario JSON del servidor"""
	var profile := UserProfile.new()
	
	# Datos básicos
	profile.id = data.get("id", "")
	profile.username = data.get("username", "")
	profile.email = data.get("email", "")
	
	# Datos de juego
	profile.currency = data.get("currency", 0)
	profile.avatar_url = data.get("avatar_url", "")
	profile.level = data.get("level", 1)
	profile.experience = data.get("experience", 0)
	
	# Mazos
	profile.active_deck_id = data.get("active_deck_id", "")
	profile.deck_count = data.get("deck_count", 0)
	
	# Estadísticas
	profile.wins = data.get("wins", 0)
	profile.losses = data.get("losses", 0)
	profile.total_matches = data.get("total_matches", 0)
	
	# Metadata
	profile.created_at = data.get("created_at", "")
	profile.last_login = data.get("last_login", "")
	
	return profile


func to_dict() -> Dictionary:
	"""Convertir a diccionario"""
	return {
		"id": id,
		"username": username,
		"email": email,
		"currency": currency,
		"avatar_url": avatar_url,
		"level": level,
		"experience": experience,
		"active_deck_id": active_deck_id,
		"deck_count": deck_count,
		"wins": wins,
		"losses": losses,
		"total_matches": total_matches,
		"created_at": created_at,
		"last_login": last_login
	}


func get_win_rate() -> float:
	"""Calcular win rate (0.0 - 1.0)"""
	if total_matches == 0:
		return 0.0
	return float(wins) / float(total_matches)


func get_display_name() -> String:
	"""Nombre para mostrar en UI"""
	return username if username != "" else "Invitado"


func has_active_deck() -> bool:
	"""Verificar si tiene un mazo activo"""
	return active_deck_id != ""


func update_from_dict(data: Dictionary) -> void:
	"""Actualizar campos desde diccionario (merge parcial)"""
	if data.has("username"): username = data.get("username")
	if data.has("email"): email = data.get("email")
	if data.has("currency"): currency = data.get("currency")
	if data.has("avatar_url"): avatar_url = data.get("avatar_url")
	if data.has("level"): level = data.get("level")
	if data.has("experience"): experience = data.get("experience")
	if data.has("active_deck_id"): active_deck_id = data.get("active_deck_id")
	if data.has("deck_count"): deck_count = data.get("deck_count")
	if data.has("wins"): wins = data.get("wins")
	if data.has("losses"): losses = data.get("losses")
	if data.has("total_matches"): total_matches = data.get("total_matches")


func _to_string() -> String:
	return "UserProfile(id=%s, username=%s, currency=%d)" % [id, username, currency]
