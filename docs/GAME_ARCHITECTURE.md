# Arquitectura del Sistema de Partidas

## 📋 Resumen Rápido

Cuando inicias una partida en Godot, esta es la cadena de archivos que se ejecuta:

```
Main.tscn (menú) → MatchSearch.gd (matchmaking) → GameBoard.tscn/GameBoard.gd (partida)
```

---

## 🎮 Archivos Principales de Partida

### 1. **GameBoard.tscn + GameBoard.gd** ⭐ CORE
**Ubicación**: `scenes/game/GameBoard.tscn` + `scenes/game/GameBoard.gd`

**Qué hace**: Es el "cerebro" de la partida. Controla todo el tablero de juego.

**Responsabilidades**:
- Recibe el estado del juego desde el servidor WebSocket
- Renderiza todas las zonas (mano, campo, cementerio, etc.)
- Maneja los turnos y fases del juego
- Coordina las acciones del jugador (atacar, usar técnicas, etc.)
- Actualiza la UI del tablero cada vez que cambia algo

**Flujo principal**:
```gdscript
_ready() → conectar WebSocket
↓
receive game state from server
↓
update_board(game_state) → render_all_zones()
↓
_place_card_in_zone() → crea CardDisplay para cada carta
```

**Variables clave**:
- `match_id`: ID de la partida actual
- `player_id`: Tu ID de usuario
- `game_state`: Estado completo del juego (JSON del servidor)
- `player_hand`, `opponent_hand`: Referencias a las manos
- `player_field_slots`, `opponent_field_slots`: Arrays de slots del campo

---

### 2. **CardDisplay.gd** 🃏 CARTAS
**Ubicación**: `scripts/cards/CardDisplay.gd`

**Qué hace**: Muestra UNA carta individual (imagen, nombre, stats).

**Responsabilidades**:
- Crear la estructura visual de la carta (imagen, nombre, rareza, stats)
- Manejar hover, clic, doble clic
- Permitir arrastrar la carta (drag & drop)
- Animación de aparición (`play_spawn_animation()`)

**Cuándo se crea**: Cada vez que GameBoard necesita mostrar una carta:
```gdscript
# En GameBoard.gd línea ~345
var card_display = CARD_DISPLAY_TEMPLATE.instantiate()
card_display.setup(card_data)  # Configura nombre, stats, etc.
```

**Señales que emite**:
- `card_clicked(card_data)`: Clic simple
- `card_double_clicked(card_data)`: Doble clic (para ver detalles)

---

### 3. **HandLayout.gd** 🎴 MANO DE CARTAS
**Ubicación**: `scripts/game/HandLayout.gd`

**Qué hace**: Organiza las cartas de la mano en forma de **abanico** (fan layout).

**Responsabilidades**:
- Posicionar cartas en arco
- Animar hover (elevar carta cuando pasas el mouse)
- Recalcular posiciones cuando agregas/quitas cartas

**Cómo funciona**:
```gdscript
add_card(card_display)  # Agrega carta a la mano
↓
arrange_cards()  # Calcula posiciones en abanico
↓
Conecta eventos mouse_entered/exited de cada carta
```

**Matemática del abanico**:
- Calcula ángulo para cada carta: `-30°` a `+30°` (max_angle = 60)
- Posiciona en arco usando seno/coseno
- Rota ligeramente cada carta según su ángulo

**IMPORTANTE**: Este script maneja el hover, NO CardDisplay (cuando está en mano).

---

### 4. **CardSlot.gd** 🔲 SLOTS DEL CAMPO
**Ubicación**: `scripts/game/CardSlot.gd`

**Qué hace**: Representa un espacio en el campo de batalla donde puedes **colocar** cartas.

**Responsabilidades**:
- Aceptar cartas arrastradas (drop zone)
- Validar si puedes colocar esa carta ahí
- Mostrar visual cuando está vacío/ocupado
- Permitir interactuar con la carta colocada

**Drag & Drop**:
```gdscript
_can_drop_data(pos, data):
    # ¿Es una carta válida? ¿Es tu turno? ¿Tienes cosmos suficiente?
    
_drop_data(pos, data):
    # Colocar carta en el slot
    # Enviar acción al servidor via WebSocket
```

**Estados visuales**:
- Vacío: Muestra watermark (ej: "Caballero 1")
- Ocupado: Muestra la carta
- Hover: Resalta cuando arrastras carta compatible

---

### 5. **WebSocketManager.gd** 🌐 COMUNICACIÓN
**Ubicación**: `scripts/managers/WebSocketManager.gd` (autoload global)

**Qué hace**: Mantiene la conexión WebSocket con el servidor para tiempo real.

**Responsabilidades**:
- Conectar al servidor (`ws://localhost:4000`)
- Enviar acciones del jugador (jugar carta, atacar, pasar turno)
- Recibir actualizaciones del servidor (nuevo estado del juego)
- Manejar reconexiones

**Mensajes típicos**:
```json
// Cliente → Servidor
{
  "type": "play_card",
  "match_id": "abc123",
  "card_id": "card_456",
  "target_slot": 0
}

// Servidor → Cliente
{
  "type": "game_state_update",
  "match_id": "abc123",
  "state": { ... }
}
```

**Usado por**: GameBoard escucha las señales de WebSocketManager.

---

### 6. **CardsManager.gd** 📦 CACHÉ DE CARTAS
**Ubicación**: `scripts/managers/CardsManager.gd` (autoload global)

**Qué hace**: Descarga y cachea las imágenes de las cartas desde el servidor.

**Responsabilidades**:
- Descargar imágenes de cartas (HTTPRequest)
- Guardar en caché (`_image_cache` diccionario)
- Proveer texturas a CardDisplay

**Flujo**:
```gdscript
CardsManager.fetch_card_image(card_id, image_url)
↓
HTTPRequest descarga imagen
↓
Convierte a ImageTexture
↓
Guarda en _image_cache[card_id]
↓
Emite señal card_image_loaded(card_id, texture)
↓
CardDisplay.set_card_image(texture)
```

---

### 7. **CardData.gd** 📊 MODELO DE DATOS
**Ubicación**: `scripts/cards/CardData.gd`

**Qué hace**: Define la estructura de datos de una carta (clase).

**Propiedades**:
```gdscript
class_name CardData

var id: String
var name: String
var type: String  # "caballero", "tecnica", "objeto", etc.
var rarity: String  # "comun", "rara", "epica", "legendaria"
var attack: int
var defense: int
var health: int
var image_url: String
```

**Métodos útiles**:
- `get_rarity_color(rarity)`: Retorna Color según rareza
- `get_rarity_name(rarity)`: Traduce rareza a texto

---

## 🔄 Flujo Completo de una Partida

### 1. **Iniciar Partida**
```
Usuario en Main.tscn → clic "Buscar Partida"
↓
MatchSearch.gd → WebSocket "search_match"
↓
Servidor matchmaking encuentra oponente
↓
Servidor envía "match_found" con match_id
↓
Godot cambia escena a GameBoard.tscn
```

### 2. **Cargar Tablero Inicial**
```
GameBoard._ready()
↓
WebSocket.connect_to_match(match_id)
↓
Servidor envía initial_state
↓
GameBoard.update_board(state)
↓
render_all_zones() crea CardDisplay para cada carta
```

### 3. **Jugador Coloca Carta**
```
Usuario arrastra CardDisplay desde mano
↓
Suelta en CardSlot
↓
CardSlot._drop_data() valida acción
↓
WebSocket.send("play_card", {card_id, slot})
↓
Servidor valida y actualiza estado
↓
Servidor broadcast nuevo state a ambos jugadores
↓
GameBoard recibe update → render_all_zones()
```

### 4. **Turnos y Fases**
```
Servidor controla turnos (cada jugador tiene tiempo límite)
↓
Envía "turn_changed" event
↓
GameBoard actualiza UI (habilitar/deshabilitar controles)
```

---

## 🐛 Problema Actual: Cartas Titilando

**Causa**: Dos sistemas manejando hover simultáneamente:
1. **HandLayout** conecta `mouse_entered`/`exited` en línea 68-71
2. **CardDisplay** también tiene `_on_mouse_entered()`/`_on_mouse_exited()`

**Conflicto**:
- HandLayout anima posición de la carta
- Cambio de posición hace que el mouse "salga" de la carta
- Se dispara `mouse_exited` → carta baja
- Mouse vuelve a entrar → `mouse_entered` → carta sube
- **Loop infinito** = titileo

**Solución**: Desactivar eventos de CardDisplay cuando está en HandLayout.

---

## 📝 Modificar el Código

### Agregar una carta al campo
**Archivo**: `GameBoard.gd` → función `_place_card_in_zone()`

### Cambiar animación de cartas
**Archivo**: `CardDisplay.gd` → función `_on_mouse_entered()`

### Ajustar layout de mano
**Archivo**: `HandLayout.gd` → variables `@export` (max_angle, radius, etc.)

### Agregar nueva acción (ej: atacar)
1. Crear función en `GameBoard.gd`: `_on_attack_button_pressed()`
2. Enviar mensaje WebSocket: `WebSocketManager.send_action("attack", data)`
3. Backend procesa en `websocket.service.ts`

---

## 🎯 Archivos que NO Debes Tocar (Normalmente)

- **Main.gd**: Solo navegación de menús
- **LoginScreen.gd**: Autenticación
- **WebSocketManager.gd**: Ya está completo (a menos que agregues nuevos tipos de mensajes)
- **CardsManager.gd**: Funciona bien para caché de imágenes

---

## ✅ Checklist para Debuggear Partidas

1. ¿El WebSocket está conectado? → Ver consola de GameBoard
2. ¿Llega el `game_state` del servidor? → Agregar `print(game_state)` en `update_board()`
3. ¿Las cartas se crean? → Ver si `CARD_DISPLAY_TEMPLATE` se instancia
4. ¿Las imágenes cargan? → Verificar `CardsManager._image_cache`
5. ¿Los slots aceptan cartas? → Debuggear `CardSlot._can_drop_data()`

---

¿Necesitas más detalle sobre algún archivo específico?
