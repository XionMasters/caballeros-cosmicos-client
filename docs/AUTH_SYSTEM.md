# 🎮 Sistema de Autenticación Completo - Godot + Backend

## ✅ Lo que se ha implementado

### 1. Backend - Autenticación y JWT
- **✅ Modelos actualizados**: `User`, `Deck`, `DeckCard` con todas las relaciones
- **✅ Controladores**: Auth, Decks, Packs con autenticación JWT
- **✅ Rutas protegidas**: Middleware `authenticateToken` en todas las rutas privadas
- **✅ Base de datos**: Tablas `decks` y `deck_cards` creadas/actualizadas

### 2. Godot - Sistema de Autenticación

#### AuthManager (Singleton)
**Archivo**: `scripts/managers/AuthManager.gd`
- **Login/Registro**: Métodos `login()` y `register()`
- **Persistencia**: Guarda/carga token en `user://auth_token.save`
- **Auto-login**: Si existe token guardado, intenta autenticar
- **Gestión de perfil**: Método `fetch_user_profile()` para obtener datos de usuario
- **Headers**: Método `get_auth_headers()` devuelve headers con Bearer token
- **Señales**:
  - `login_successful(user_data)`
  - `login_failed(error)`
  - `logout_completed`

#### LoginScreen
**Archivos**: `scenes/menus/LoginScreen.gd` + `.tscn`
- **Modo dual**: Login y Registro en la misma pantalla
- **Validaciones**: Email requerido, password mínimo 6 caracteres
- **Auto-redirección**: Si ya hay sesión, va directo al menú principal
- **Estados**: Loading, error, éxito con colores y mensajes claros

#### Main Menu
**Archivos**: `scenes/main/main.gd` (actualizado)
- **Verificación automática**: Redirige a login si no está autenticado
- **Display de usuario**: Muestra username y monedas en header
- **Logout**: Botón para cerrar sesión y volver a login
- **Navegación**: Botones a colección, packs, batalla, perfil

### 3. Integración Completa con API

#### CardsManager
- **Método nuevo**: `fetch_user_cards()` - Obtiene cartas del usuario autenticado
- **Headers automáticos**: Usa `AuthManager.get_auth_headers()`

#### DeckBuilder
- **Carga de decks**: GET `/api/decks` con autenticación
- **Crear deck**: POST `/api/decks` 
- **Agregar cartas**: POST `/api/decks/:id/cards` con validación

#### PacksShop
- **Monedas en tiempo real**: `AuthManager.get_user_currency()`
- **Compra de packs**: POST `/api/packs/buy` con token JWT
- **Actualización automática**: Refresca perfil después de compra

#### PackOpening
- **Apertura autenticada**: POST `/api/packs/open` con token JWT
- **ID correcto**: Usa `user_pack_id` en lugar de `pack_id`

### 4. Configuración del Proyecto

#### project.godot
```gdscript
[autoload]
NetworkManager="*res://scripts/managers/NetworkManager.gd"
CardsManager="*res://scripts/managers/CardsManager.gd"
AuthManager="*res://scripts/managers/AuthManager.gd"  # NUEVO

[application]
run/main_scene="res://scenes/menus/LoginScreen.tscn"  # Inicia en login
```

## 🔄 Flujo de Autenticación

```
1. App inicia → LoginScreen
   ├─ Si hay token guardado → Auto-login → Main
   └─ Si no hay token → Mostrar formulario

2. Usuario hace login
   ├─ Email + Password → POST /api/auth/login
   ├─ Recibe: { token, user: {...} }
   ├─ AuthManager guarda token y user_data
   ├─ Guarda token en disco (user://auth_token.save)
   └─ Redirige a Main.tscn

3. Usuario navega por la app
   ├─ Todas las requests usan AuthManager.get_auth_headers()
   ├─ Backend valida JWT en cada request
   └─ Si token inválido → 401 → Redirigir a login

4. Usuario hace logout
   ├─ AuthManager.logout()
   ├─ Borra token de memoria y disco
   └─ Redirige a LoginScreen
```

## 📋 Endpoints Protegidos

### Con Autenticación JWT
- `GET /api/decks` - Lista decks del usuario
- `POST /api/decks` - Crear deck
- `PUT /api/decks/:id` - Actualizar deck
- `DELETE /api/decks/:id` - Eliminar deck
- `POST /api/decks/:id/cards` - Agregar carta a deck
- `DELETE /api/decks/:id/cards/:card_id` - Quitar carta
- `PUT /api/decks/:id/cards/:card_id` - Actualizar cantidad

- `POST /api/packs/buy` - Comprar pack
- `POST /api/packs/open` - Abrir pack

- `GET /api/users/me` - Perfil del usuario
- `GET /api/user-cards` - Cartas del usuario

### Sin Autenticación (Públicas)
- `POST /api/auth/login`
- `POST /api/auth/register`
- `GET /api/cards` - Ver todas las cartas
- `GET /api/packs` - Ver packs disponibles

## 🧪 Cómo Probar

### 1. Backend
```bash
cd "d:\Disco E\Proyectos\Server-SS"
npm run dev
```
- Servidor en `http://localhost:3000`

### 2. Godot
1. Abrir proyecto en Godot 4.5
2. Presionar F5 (Run)
3. Debería aparecer LoginScreen
4. Registrarse o iniciar sesión
5. Explorar funciones:
   - Ver colección de cartas
   - Crear deck (30-40 cartas)
   - Comprar packs
   - Abrir packs

### 3. Crear Usuario de Prueba (Backend)
```bash
# Usar Postman o curl
POST http://localhost:3000/api/auth/register
{
  "email": "test@test.com",
  "password": "test123",
  "username": "TestUser"
}
```

Respuesta:
```json
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "user": {
    "id": "uuid",
    "username": "TestUser",
    "email": "test@test.com",
    "currency": 1000
  }
}
```

## 🐛 Solución de Problemas

### Token guardado no funciona
- Borrar archivo: `user://auth_token.save`
- En Windows: `%APPDATA%\Godot\app_userdata\CCG\auth_token.save`

### Error 401 en requests
- Verificar que token sea válido (no expirado)
- Verificar `JWT_SECRET` en `.env` del backend
- Rehacer login

### Monedas no se actualizan
- Después de compra, esperar 0.5s para refresh
- Método `load_user_currency()` llama a `AuthManager.fetch_user_profile()`

### Decks no cargan
- Verificar que usuario tenga decks creados
- Endpoint: `GET /api/decks` debe devolver array de decks

## 📊 Datos de Usuario

### Estructura de user_data (AuthManager)
```gdscript
{
  "id": "uuid",
  "username": "JohnDoe",
  "email": "john@example.com",
  "currency": 1500,
  "is_email_verified": false
}
```

### Métodos útiles
```gdscript
AuthManager.get_username() -> String
AuthManager.get_user_currency() -> int
AuthManager.get_user_id() -> String
AuthManager.is_authenticated -> bool
```

## 🎯 Próximos Pasos Sugeridos

1. **Imágenes de packs**: Diseñar sprites 300x400px y actualizar Pack.image_url
2. **Animaciones de UI**: Transiciones entre pantallas
3. **Sistema de batalla**: Implementar mecánicas de juego
4. **Chat/Multiplayer**: Integrar WebSockets
5. **Achievements**: Sistema de logros con recompensas
6. **Daily rewards**: Bonos diarios de monedas
7. **Trading**: Intercambio de cartas entre usuarios

## 📝 Notas de Desarrollo

- **Seguridad**: JWT expira según `JWT_EXPIRES_IN` en `.env` (default: 24h)
- **Monedas iniciales**: 1000 (configurado en modelo User)
- **Token refresh**: No implementado (requiere refresh_token)
- **Validación de email**: Backend tiene campo pero no envía emails
- **Deck activo**: Solo un deck puede estar activo (`is_active=true`)

---

**Estado**: ✅ Sistema completo y funcional
**Última actualización**: Noviembre 2025
