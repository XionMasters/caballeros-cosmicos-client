# GameConfig.gd
# Configuración centralizada para el backend del juego
extends Resource
class_name GameConfig

# Leer de variables de environment o usar defaults
static var API_URL: String = OS.get_environment("API_URL") if OS.get_environment("API_URL") else "http://localhost:3000/api"
static var WS_URL: String = OS.get_environment("WS_URL") if OS.get_environment("WS_URL") else "ws://localhost:3000/ws"

# Opcional
const ENVIRONMENT = "development"   # "production"
const DEBUG_NETWORK = true
