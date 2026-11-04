class_name UIPalette
extends RefCounted
## Paleta única del cliente («Noche cósmica y oro»).
## El tema global (ui/theme/cosmic_theme.tres) usa estos mismos valores; los scripts
## que pintan estilos por código deben tomarlos de aquí en vez de escribir Color(...) sueltos.

# ── Superficies (de más oscura a más clara) ──────────────────────────────────
const ABYSS     := Color("#07051A")  ## Fondo de escena y tablero
const NIGHT     := Color("#0E0921")  ## Fondo base de pantallas
const PANEL     := Color("#170E33")  ## Paneles y tarjetas
const RAISED    := Color("#241747")  ## Botones y campos
const HIGHLIGHT := Color("#38216A")  ## Hover y pestaña activa

# ── Oro y texto ───────────────────────────────────────────────────────────────
const GOLD        := Color("#F5C459")  ## Bordes, iconos, acentos
const GOLD_LIGHT  := Color("#FFDB85")  ## Títulos, foco, hover
const GOLD_STRONG := Color("#EDAD3D")  ## Botón principal
const TEXT        := Color("#EBE3FF")  ## Texto principal
const TEXT_MUTED  := Color("#B9ACDA")  ## Subtítulos y ayudas
const ON_GOLD     := Color("#2E1405")  ## Texto sobre oro

# ── Colores de juego ─────────────────────────────────────────────────────────
const LIFE     := Color("#F0625A")  ## Vida (LP) y ataques
const COSMOS   := Color("#6F9BFF")  ## Cosmo (CP) y movimiento
const POWER    := Color("#FF8A3D")  ## Fuerza (CE) y técnicas
const ARMOR    := Color("#A9B4C2")  ## Armadura (AR)
const HEAL     := Color("#6EE7A8")  ## Curación
const TARGET   := Color("#5CE1E6")  ## Objetivo válido / drop válido
const SELECTED := GOLD_LIGHT        ## Carta o posición seleccionada
const ABILITY  := Color("#C38BFF")  ## Habilidades
const INVALID  := POWER             ## Drop no válido (naranja: se distingue del cian sin depender del rojo/verde)

# ── Rarezas (valores internos en inglés, como en el servidor) ────────────────
const RARITY := {
	"common": Color("#B8B8C7"),
	"rare": Color("#6FB2FF"),
	"epic": Color("#C38BFF"),
	"legendary": Color("#FFD15C"),
	"divine": Color("#FF9AD9"),
}

# ── Elementos ────────────────────────────────────────────────────────────────
const ELEMENT := {
	"steel": Color("#A9B4C2"),
	"fire": Color("#FF7A3D"),
	"water": Color("#3FA9F5"),
	"earth": Color("#B98A4E"),
	"wind": Color("#7DDCB0"),
	"light": Color("#FFE58A"),
	"dark": Color("#8C5BD6"),
}


static func rarity(key: String) -> Color:
	return RARITY.get(key.to_lower(), RARITY["common"])


static func element(key: String) -> Color:
	return ELEMENT.get(key.to_lower(), TEXT_MUTED)


## Mismo color con otra opacidad (atajo para estilos translúcidos).
static func alpha(color: Color, a: float) -> Color:
	return Color(color.r, color.g, color.b, a)
