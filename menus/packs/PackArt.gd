# PackArt.gd
# Arte y textos compartidos por la tienda y la apertura de sobres:
# categoría visual de cada sobre, nombres y colores de rareza.
class_name PackArt
extends RefCounted

const TEXTURES := {
	"basic": preload("res://assets/ui-icons/packs/basic.svg"),
	"bronze": preload("res://assets/ui-icons/packs/bronze.svg"),
	"silver": preload("res://assets/ui-icons/packs/silver.svg"),
	"gold": preload("res://assets/ui-icons/packs/gold.svg"),
	"mega": preload("res://assets/ui-icons/packs/mega.svg"),
}

# El servidor guarda algunas rarezas en español; se aceptan ambas formas
const RARITY_ALIASES := {
	"comun": "common", "rara": "rare", "epica": "epic", "legendaria": "legendary", "divina": "divine",
}


static func normalize_rarity(rarity: String) -> String:
	var key := rarity.to_lower()
	return RARITY_ALIASES.get(key, key)


static func tier_for(pack: Dictionary) -> String:
	"""Categoría visual: por nombre si es explícito, si no por la rareza garantizada"""
	var name := str(pack.get("name", "")).to_lower()
	if "mega" in name:
		return "mega"
	for tier in [["oro", "gold"], ["plata", "silver"], ["bronce", "bronze"]]:
		if tier[0] in name:
			return tier[1]

	var guaranteed = pack.get("guaranteed_rarity")
	match normalize_rarity(str(guaranteed) if guaranteed != null else ""):
		"legendary", "divine":
			return "gold"
		"epic":
			return "silver"
		"rare":
			return "bronze"
	return "basic"


static func texture_for(pack: Dictionary) -> Texture2D:
	return TEXTURES[tier_for(pack)]


static func rarity_label(rarity: String) -> String:
	match normalize_rarity(rarity):
		"common": return "Común"
		"rare": return "Rara"
		"epic": return "Épica"
		"legendary": return "Legendaria"
		"divine": return "Divina"
	return rarity.capitalize()


static func rarity_color(rarity: String) -> Color:
	match normalize_rarity(rarity):
		"common": return Color(0.8, 0.8, 0.85)
		"rare": return Color(0.45, 0.7, 1.0)
		"epic": return Color(0.78, 0.5, 1.0)
		"legendary": return Color(1.0, 0.82, 0.3)
		"divine": return Color(1.0, 0.6, 0.85)
	return Color.WHITE


static func format_coins(amount: int) -> String:
	# 12500 -> "12.500"
	var digits := str(absi(amount))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += "."
		out += digits[i]
	return ("-" if amount < 0 else "") + out
