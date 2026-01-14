# GameBoard_v2: Modo Normal vs Test Mode

## Resumen
GameBoard_v2 ahora soporta DOS modos de juego, **automáticamente detectados** según el origen:

### 1. **Modo Normal (Multiplayer Real)**
- Acceso: Botón "Buscar Partida" en MainLobby
- Control del servidor: Servidor controla toda la lógica
- Tu cliente: Solo renderiza y recibe updates
- `MatchManager.is_test_mode = false` (automático)

### 2. **Modo Test (Desarrollo/Pruebas)**
- Acceso: Botón "Test" en MainLobby
- Control: Juegas contra ti mismo (controlas ambos jugadores)
- Código del lado del cliente: Maneja algunas acciones
- `MatchManager.is_test_mode = true` (automático)

---

## Cómo Funciona (Automático - NO Requiere Configuración)

### **Flujo Automático**

#### Opción A: Búsqueda Normal (Multiplayer)
```
1. Usuario hace click en "Buscar Partida"
   ↓
2. MatchSearch._on_search_pressed()
   ├─ Llama: MatchmakingManager.search_match()
   ↓
3. Servidor encuentra oponente
   ↓
4. MatchSearch._on_match_found()
   ├─ MatchManager.is_test_mode = false ← SETEA AUTOMÁTICO
   ├─ Carga GameBoard.tscn
   ↓
5. GameBoard_v2._ready()
   ├─ Lee: is_test_mode = MatchManager.is_test_mode (FALSE)
   ├─ MatchPlayController NO se crea
   ├─ Solo renderiza cards (read-only, servidor valida)
```

#### Opción B: Test Mode
```
1. Usuario hace click en "Test"
   ↓
2. MainLobby._on_test_pressed()
   ├─ MatchManager.is_test_mode = true ← SETEA AUTOMÁTICO
   ├─ Llama: MatchManager.start_test_match()
   ↓
3. Servidor crea TEST partida
   ├─ Ambos jugadores = tu mazo
   ↓
4. WebSocket envía match_found event
   ↓
5. MatchManager._on_match_found()
   ├─ is_test_mode ya = true (no cambia)
   ├─ Carga GameBoard.tscn
   ↓
6. GameBoard_v2._ready()
   ├─ Lee: is_test_mode = MatchManager.is_test_mode (TRUE)
   ├─ MatchPlayController SE CREA ← Permite drag-drop
   ├─ Renderiza TODAS las cartas (incluyendo opponent)
```

---

## Cambios en el Código

### MatchManager.gd (Central)
```gdscript
var is_test_mode: bool = false  # Central control

func start_test_match():
    is_test_mode = true  # Automático al solicitar test
    WebSocketManager.request_test_match()
```

### MatchSearch.gd (Multiplayer)
```gdscript
func _on_match_found(match_data: Dictionary):
    MatchManager.is_test_mode = false  # Automático al encontrar normal
    # ... continúa
```

### MainLobby.gd (Test)
```gdscript
func _on_test_pressed():
    MatchManager.is_test_mode = true  # Automático al presionar Test
    MatchManager.start_test_match()
```

### GameBoard_v2.gd (Smart Detection)
```gdscript
func _ready():
    # NO necesita configuración manual
    is_test_mode = MatchManager.is_test_mode  # Lee valor automático
    
    if is_test_mode:
        # Crear MatchPlayController para test
        match_play_controller = MatchPlayController.new(...)
```

---

## Comparación: Antes vs Después

### ANTES (Manual)
```
1. Usuario abre escena
2. Inspector → enable_test_mode = true/false
3. Compilar, probar
❌ Error-prone, olvida setear
❌ No refleja intención del usuario
```

### AHORA (Automático)
```
1. Usuario hace click en "Test" o "Buscar"
2. Sistema automáticamente setea is_test_mode
3. GameBoard_v2 lee y se auto-configura
✅ Imposible olvidar
✅ Refleja exactamente la intención del usuario
✅ Funciona para ambos flujos
```

---

## Matriz de Operación

| Escenario | Botón | MatchManager.is_test_mode | GameBoard Comportamiento | MatchPlayController |
|-----------|-------|---------------------------|--------------------------|---------------------|
| **Test Mode** | Test | TRUE | Ambas manos visibles | ✅ Creado (drag-drop) |
| **Normal Multiplayer** | Buscar | FALSE | Solo mano propia | ❌ No creado (servidor valida) |

---

## Testing

### Verificar Test Mode
```
1. Click "Test" button
2. Esperar a que cargue GameBoard_new
3. Observar: [GameBoard] 🧪 Test Mode: Creando MatchPlayController...
4. Ambas manos visibles → ✅ Test mode activo
5. Drag-drop funcional → ✅ Interactividad habilitada
```

### Verificar Normal Mode
```
1. Click "Buscar Partida"
2. Esperar oponente
3. Carga GameBoard_new
4. Observar: NO ve en logs "Test Mode"
5. Solo mano propia visible → ✅ Normal mode
6. Espera validación servidor → ✅ Correcto
```

---

## Ventajas del Nuevo Sistema

✅ **Sin Configuración**: El usuario no necesita cambiar nada  
✅ **Automático**: El origen determina el modo  
✅ **Seguro**: Imposible tener modo equivocado  
✅ **Mantenible**: Un punto de verdad (MatchManager.is_test_mode)  
✅ **Flexible**: Fácil agregar nuevos orígenes (IA, tutorial, etc)  

---

**Última actualización**: Enero 14, 2026 - Sistema Automático

