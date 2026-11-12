class_name UIPalette
extends RefCounted
## Paleta única del cliente («Cosmos eléctrico y oro»).
## El tema global (ui/theme/cosmic_theme.tres) se genera con ui/theme/build_theme.gd
## a partir de estos valores; los scripts que pintan estilos por código deben
## tomarlos de aquí en vez de escribir Color(...) sueltos.

# ── Superficies (de más oscura a más clara) ──────────────────────────────────
const ABYSS     := Color("#060317")  ## Fondo de escena y tablero
const NIGHT     := Color("#0D0730")  ## Fondo base de pantallas
const PANEL     := Color("#170D45")  ## Paneles y tarjetas
const RAISED    := Color("#2A1A7A")  ## Botones y campos
const HIGHLIGHT := Color("#3D27A8")  ## Hover y pestaña activa
const EDGE      := Color("#7A66FF")  ## Borde luminoso de paneles y botones
const SLAB      := Color("#05021A")  ## "Canto" inferior de los botones (relieve)

# ── Oro y texto ───────────────────────────────────────────────────────────────
const GOLD        := Color("#FFC83D")  ## Bordes, iconos, acentos
const GOLD_LIGHT  := Color("#FFE38A")  ## Títulos, foco, hover
const GOLD_STRONG := Color("#FFB21A")  ## Botón principal
const GOLD_DEEP   := Color("#A85A00")  ## Canto del botón principal
const TEXT        := Color("#F5F2FF")  ## Texto principal
const TEXT_MUTED  := Color("#A9A1DB")  ## Subtítulos y ayudas
const ON_GOLD     := Color("#2B1300")  ## Texto sobre oro
const OUTLINE     := Color("#12063A")  ## Contorno de los títulos

# ── Acentos ──────────────────────────────────────────────────────────────────
const ACCENT  := Color("#3EE6FF")  ## Cian eléctrico: selección, foco, novedades
const MAGENTA := Color("#FF4FD8")  ## Destellos y avisos especiales
const DANGER  := Color("#FF5A6A")  ## Acciones destructivas

# ── Colores de juego ─────────────────────────────────────────────────────────
const LIFE     := Color("#FF5F57")  ## Vida (LP) y ataques
const COSMOS   := Color("#6F9BFF")  ## Cosmo (CP) y movimiento
const POWER    := Color("#FF8A3D")  ## Fuerza (CE) y técnicas
const ARMOR    := Color("#A9B4C2")  ## Armadura (AR)
const HEAL     := Color("#6EE7A8")  ## Curación
const TARGET   := ACCENT            ## Objetivo válido / drop válido
const SELECTED := GOLD_LIGHT        ## Carta o posición seleccionada
const ABILITY  := Color("#C38BFF")  ## Habilidades
const INVALID  := POWER             ## Drop no válido (naranja: se distingue del cian sin depender del rojo/verde)

# ── Rarezas (valores internos en inglés, como en el servidor) ────────────────
const RARITY := {
	"common": Color("#B8B8C7"),
	"uncommon": Color("#5CC46A"),
	"rare": Color("#4FA8FF"),
	"epic": Color("#B66BFF"),
	"legendary": Color("#FFC83D"),
	"divine": Color("#FF6FD0"),
}

## Orden de rarezas, de menor a mayor (para elegir las cartas más vistosas)
const RARITY_ORDER := ["common", "uncommon", "rare", "epic", "legendary", "divine"]

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


static func rarity_rank(key: String) -> int:
	return RARITY_ORDER.find(key.to_lower())


static func element(key: String) -> Color:
	return ELEMENT.get(key.to_lower(), TEXT_MUTED)


## Mismo color con otra opacidad (atajo para estilos translúcidos).
static func alpha(color: Color, a: float) -> Color:
	return Color(color.r, color.g, color.b, a)
