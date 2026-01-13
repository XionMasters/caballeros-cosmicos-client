# GameConfig.gd
# Configuración centralizada para el backend del juego
extends Resource
class_name GameConfig

# Cambiar estos valores al publicar en producción
const API_URL = "http://localhost:3000/api"
const WS_URL  = "ws://localhost:3000/ws"

# Opcional
const ENVIRONMENT = "development"   # "production"
const DEBUG_NETWORK = true
