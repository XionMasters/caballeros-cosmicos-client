# Arquitectura de Red - Caballeros Cósmicos

## 📦 Nueva Arquitectura (Implementada)

### Principios de Diseño
- ✅ **Responsabilidad Única**: Cada manager tiene una función específica
- ✅ **Separación de Capas**: Core → Managers → UI
- ✅ **Señales sobre Callbacks**: Sistema nativo de Godot
- ✅ **Reutilización**: ApiClient genérico para todas las peticiones HTTP

---

## 🏗️ Estructura de Capas

```
┌─────────────────────────────────────────┐
│           UI Layer (Scenes)             │
│  LoginScreen, MainLobby, PacksShop...   │
└──────────────────┬──────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────┐
│        Manager Layer (Autoloads)        │
│  AuthManager, UserManager, CardsManager │
└──────────────────┬──────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────┐
│         Core Layer (Utils)              │
│    ApiClient, SessionManager            │
└─────────────────────────────────────────┘
```

---

## 🔧 Componentes Core

### ApiClient (scripts/core/ApiClient.gd)
**Propósito**: Cliente HTTP genérico reutilizable

**Características**:
- ✅ Retry automático (hasta 2 reintentos)
- ✅ Timeout configurable (10s default)
- ✅ Headers con autenticación automática
- ✅ Cola de peticiones
- ✅ Señales nativas de Godot

**Métodos**:
```gdscript
func post(endpoint: String, body: Dictionary, callback: Callable, use_auth: bool = false)
func fetch(endpoint: String, callback: Callable, use_auth: bool = false)  # GET
func put(endpoint: String, body: Dictionary, callback: Callable, use_auth: bool = false)
func delete(endpoint: String, callback: Callable, use_auth: bool = false)
```

**Ejemplo**:
```gdscript
var api = ApiClient.new()
api.set_auth_token("jwt_token_here")

api.post("/auth/login", {"email": "user@test.com"}, func(success, data, error):
    if success:
        print("Login OK: ", data)
    else:
        print("Error: ", error)
)
```

---

### SessionManager (scripts/core/SessionManager.gd)
**Propósito**: Persistencia de sesión local

**Métodos**:
```gdscript
func save_token(token: String) -> bool
func load_token() -> String
func delete_token() -> void
func save_setting(key: String, value: Variant) -> bool
func load_setting(key: String, default_value: Variant = null) -> Variant
func clear_all() -> void
```

**Archivos**:
- `user://auth_token.save` - Token JWT
- `user://session_settings.save` - Settings JSON

---

## 👔 Managers (Autoloads)

### AuthManager (scripts/managers/AuthManager.gd)
**Responsabilidad**: Solo autenticación JWT

**Señales**:
```gdscript
signal login_successful(user_profile: UserProfile)
signal login_failed(error: String)
signal registration_successful(user_profile: UserProfile)
signal registration_failed(error: String)
signal logout_completed()
```

**Métodos**:
```gdscript
func login(email: String, password: String) -> void
func register(email: String, password: String, username: String = "") -> void
func logout() -> void
func get_token() -> String
func is_logged_in() -> bool
```

**NO hace**:
- ❌ Almacenar datos de usuario (usa `UserManager`)
- ❌ HTTP directo (usa `ApiClient`)
- ❌ Persistencia (usa `SessionManager`)

---

### UserManager (scripts/managers/UserManager.gd)
**Responsabilidad**: Gestión de perfil de usuario

**Señales**:
```gdscript
signal profile_updated(profile: UserProfile)
signal profile_loaded(profile: UserProfile)
signal currency_changed(new_amount: int)
signal active_deck_changed(deck_id: String)
```

**Métodos**:
```gdscript
func set_profile(profile: UserProfile) -> void
func get_profile() -> UserProfile
func get_username() -> String
func get_currency() -> int
func get_user_id() -> String
func get_active_deck_id() -> String
func update_currency(new_amount: int) -> void
func set_active_deck(deck_id: String) -> void
func get_stats() -> Dictionary
```

**Modelo de Datos**:
```gdscript
# UserProfile (scripts/models/UserProfile.gd)
var id: String
var username: String
var email: String
var currency: int
var avatar_url: String
var active_deck_id: String
var wins: int
var losses: int
var total_matches: int
```

---

### CardsManager (scripts/managers/CardsManager.gd)
**Responsabilidad**: Gestión de cartas y colección

**Señales**:
```gdscript
signal cards_loaded(cards: Array[CardData])
signal card_image_loaded(card_id: String, texture: Texture2D)
signal error_occurred(error: String)
```

**Métodos**:
```gdscript
func fetch_all_cards() -> void
func fetch_user_cards() -> void
func fetch_card_image(card_id: String, image_url: String) -> void
func get_cached_image(card_id: String) -> Texture2D
```

---

### DecksManager (scripts/managers/DecksManager.gd)
**Responsabilidad**: Gestión de mazos

**Señales**:
```gdscript
signal decks_loaded(decks: Array)
signal deck_created(deck: Dictionary)
signal deck_updated(deck: Dictionary)
signal deck_deleted(deck_id: String)
```

**Métodos**:
```gdscript
func fetch_user_decks() -> void
func create_deck(name: String, description: String) -> void
func update_deck(deck_id: String, data: Dictionary) -> void
func delete_deck(deck_id: String) -> void
```

---

## 🚫 NetworkManager - DEPRECATED

**Archivo**: `scripts/managers/NetworkManager_DEPRECATED.gd`

**Por qué fue deprecado**:
1. ❌ Violaba responsabilidad única (auth + packs + HTTP)
2. ❌ Callbacks manuales en lugar de señales
3. ❌ Sin manejo de errores robusto (no timeout, no retry)
4. ❌ Creaba HTTPRequest por cada petición (ineficiente)
5. ❌ Token no persistente

**Migración**:
- `NetworkManager.login_user()` → `AuthManager.login()`
- `NetworkManager.register_user()` → `AuthManager.register()`
- `NetworkManager.get_available_packs()` → Usar `ApiClient` directamente

---

## 📋 Flujo de Autenticación Completo

```gdscript
# 1. Usuario hace login
AuthManager.login("user@test.com", "password123")

# 2. AuthManager usa ApiClient internamente
_api_client.post("/auth/login", body, _on_login_response)

# 3. Callback recibe respuesta
func _on_login_response(success, data, error):
    if success:
        # 4. Guardar token
        auth_token = data["token"]
        _session_manager.save_token(auth_token)
        
        # 5. Crear perfil de usuario
        var profile = UserProfile.from_dict(data["user"])
        
        # 6. Guardar en UserManager
        UserManager.set_profile(profile)
        
        # 7. Emitir señal
        login_successful.emit(profile)
        
        # 8. Conectar WebSocket
        WebSocketManager.connect_to_server(auth_token)
```

---

## 🎯 Ejemplos de Uso

### Login desde UI
```gdscript
# LoginScreen.gd
func _ready():
    AuthManager.login_successful.connect(_on_login_success)
    AuthManager.login_failed.connect(_on_login_failed)

func _on_login_button_pressed():
    AuthManager.login(email_input.text, password_input.text)

func _on_login_success(profile: UserProfile):
    print("Bienvenido: ", profile.username)
    get_tree().change_scene_to_file("res://scenes/menus/MainLobby.tscn")
```

### Actualizar Monedas en UI
```gdscript
# MainLobby.gd
func _ready():
    UserManager.currency_changed.connect(_on_currency_changed)
    coins_label.text = "💰 " + str(UserManager.get_currency())

func _on_currency_changed(new_amount: int):
    coins_label.text = "💰 " + str(new_amount)
```

### Comprar Pack
```gdscript
# PacksShop.gd
func purchase_pack(pack_id: String):
    var api = ApiClient.new()
    api.set_auth_token(AuthManager.get_token())
    
    api.post("/packs/purchase", {"pack_id": pack_id}, func(success, data, error):
        if success:
            # Actualizar monedas automáticamente
            UserManager.update_currency(data["new_balance"])
            # UserManager emite currency_changed → UI se actualiza sola
        else:
            show_error(error)
    , true)  # use_auth = true
```

---

## ✅ Ventajas de la Nueva Arquitectura

| Aspecto | Antes (NetworkManager) | Ahora (ApiClient + Managers) |
|---------|------------------------|------------------------------|
| **Responsabilidad** | Todo mezclado | Separado por dominio |
| **Errores** | Sin retry/timeout | Retry automático + timeout |
| **Persistencia** | No | SessionManager |
| **Señales** | Callbacks manuales | Señales nativas |
| **Reutilización** | Bajo | Alto (ApiClient genérico) |
| **Testing** | Difícil | Fácil (mocks) |
| **Escalabilidad** | Baja | Alta |

---

## 🔄 Checklist de Migración

- [x] Crear ApiClient genérico
- [x] Crear SessionManager para persistencia
- [x] Crear UserProfile modelo de datos
- [x] Refactorizar AuthManager (solo auth)
- [x] Crear UserManager (datos de usuario)
- [x] Deprecar NetworkManager
- [x] Actualizar todas las pantallas UI
- [x] Eliminar autoload NetworkManager

---

**Última actualización**: 10 de diciembre de 2025
