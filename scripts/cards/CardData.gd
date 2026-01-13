# CardData.gd
# Datos inmutables de una carta (template estático)
class_name CardData
extends Resource

# ============================================================
# IDENTIFICACIÓN Y METADATA
# ============================================================
@export var id: String = ""
@export var name: String = ""
@export var type: String = ""          # knight / technique / item / stage / helper / event
@export var rarity: String = ""
@export var card_set: String = ""
@export var tags: Array[String] = []
@export var power_level: int = 0        # 0-100 para balance / matchmaking
@export var faction: String = ""
@export var element: String = ""

# ============================================================
# ENERGÍA Y COSTOS
# ============================================================
@export var cost: int = 0               # Cosmos necesario
@export var generate: int = 0           # Cosmos generado

# ============================================================
# STATS BASE (Knight u otros tipos que tengan stats)
# ============================================================
@export var attack: int = 0
@export var defense: int = 0
@export var health: int = 0
@export var cosmos: int = 0
@export var can_defend: bool = true
@export var defense_reduction: float = 0.5

# ============================================================
# RESTRICCIONES / REGLAS DE JUEGO
# ============================================================
@export var max_copies: int = 3
@export var unique: bool = false
@export var playable_zones: Array[String] = ["battlefield"]

# ============================================================
# VISUAL / UI
# ============================================================
@export var image_url: String = ""
@export var description: String = ""

# ============================================================
# HELPERS INTERNOS
# (NO exportar estos; los usa CardInstance)
# ============================================================

func has_tag(tag: String) -> bool:
	return tag in tags

func is_type(t: String) -> bool:
	return type == t

func matches_text(search: String) -> bool:
	search = search.to_lower()
	return (
		name.to_lower().find(search) != -1 or
		description.to_lower().find(search) != -1 or
		tags.any(func(t): return t.to_lower().find(search) != -1)
	)

func get_power_score() -> int:
	# Score derivado, útil para ordenamiento
	return cost * 2 + attack + defense + health + power_level

# ============================================================
# CONVERSIÓN / SERIALIZACIÓN
# ============================================================

static func from_json(json: Dictionary) -> CardData:
	var card = CardData.new()
	
	# Identidad
	card.id = json.get("id", "")
	card.name = json.get("name", "")
	
	# Tipo y rareza: pueden venir en español del servidor
	var type_val = json.get("type", "")
	card.type = _normalize_type(str(type_val))
	
	var rarity_val = json.get("rarity", "")
	card.rarity = _normalize_rarity(str(rarity_val))
	
	# Backend puede omitir card_set; usar string seguro
	var card_set_value = json.get("card_set", "")
	card.card_set = card_set_value if typeof(card_set_value) == TYPE_STRING else ""
	
	# Facción / elemento - pueden venir nulos
	var faction_value = json.get("faction", "")
	card.faction = faction_value if typeof(faction_value) == TYPE_STRING else ""
	
	var element_value = json.get("element", "")
	card.element = element_value if typeof(element_value) == TYPE_STRING else ""
	
	# Recursos - convertir float a int de forma segura
	card.cost = int(json.get("cost", 0)) if json.get("cost") != null else 0
	card.generate = int(json.get("generate", 0)) if json.get("generate") != null else 0
	
	# Metadata
	var tags_array = json.get("tags", [])
	if tags_array is Array:
		card.tags.clear()
		for tag in tags_array:
			card.tags.append(str(tag))
	
	# power_level puede ser null
	var power_level_val = json.get("power_level", 0)
	card.power_level = int(power_level_val) if power_level_val != null else 0
	
	# Imagen y descripción
	card.description = json.get("description", "")
	card.image_url = json.get("image_url", "")
	
	# Reglas
	card.max_copies = int(json.get("max_copies", 3)) if json.get("max_copies") != null else 3
	card.unique = bool(json.get("unique", false))
	var zones_array = json.get("playable_zones", ["battlefield"])
	if zones_array is Array:
		card.playable_zones.clear()
		for zone in zones_array:
			card.playable_zones.append(str(zone))
	
	# Knight Stats (si existen)
	var knight = null
	if json.has("card_knight"):
		knight = json["card_knight"]
	elif json.has("knight_attributes"):
		knight = json["knight_attributes"]
	
	if knight is Dictionary:
		card.attack = int(knight.get("attack", 0)) if knight.get("attack") != null else 0
		card.defense = int(knight.get("defense", 0)) if knight.get("defense") != null else 0
		card.health = int(knight.get("health", 0)) if knight.get("health") != null else 0
		card.cosmos = int(knight.get("cosmos", 0)) if knight.get("cosmos") != null else 0
		card.can_defend = bool(knight.get("can_defend", true))
		card.defense_reduction = float(knight.get("defense_reduction", 0.5)) if knight.get("defense_reduction") != null else 0.5
	
	return card


# Normalizar tipos de carta: caballero → knight, etc
static func _normalize_type(type_str: String) -> String:
	match type_str.to_lower():
		"caballero":
			return "knight"
		"técnica":
			return "technique"
		"objeto":
			return "item"
		"escenario":
			return "stage"
		"asistente":
			return "helper"
		"evento":
			return "event"
		_:
			return type_str


# Normalizar rareza: rara → rare, etc
static func _normalize_rarity(rarity_str: String) -> String:
	match rarity_str.to_lower():
		"común":
			return "common"
		"rara":
			return "rare"
		"épica":
			return "epic"
		"legendaria":
			return "legendary"
		"divina":
			return "divine"
		_:
			return rarity_str

# ============================================================
# COLOR HELPERS (UI)
# ============================================================

static func get_rarity_color(r: String) -> Color:
	match r:
		"common": return Color(0.75, 0.75, 0.75)
		"rare": return Color(0.29, 0.56, 0.89)
		"epic": return Color(0.61, 0.35, 0.71)
		"legendary": return Color(1.0, 0.84, 0.0)
		"divine": return Color(1.0, 0.2, 0.3)
		_: return Color.WHITE

static func get_element_color(e: String) -> Color:
	match e:
		"steel": return Color(0.75, 0.75, 0.75)
		"fire": return Color(1.0, 0.4, 0.2)
		"water": return Color(0.2, 0.6, 1.0)
		"earth": return Color(0.6, 0.4, 0.2)
		"wind": return Color(0.6, 1.0, 0.8)
		"light": return Color(1.0, 1.0, 0.8)
		"dark": return Color(0.3, 0.2, 0.4)
		_: return Color.WHITE
		
static func get_rarity_name(r: String) -> String:
	match r.to_lower():
		"common": return "Common"
		"rare": return "Rare"
		"epic": return "Epic"
		"legendary": return "Legendary"
		"divine": return "Divine"
		_: return r.capitalize()
