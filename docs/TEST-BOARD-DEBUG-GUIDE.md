# Guía de Prueba: TestBoard - Debuggeo de Interactividad

## ¿Qué es TestBoard?

TestBoard es un **entorno de prueba simplificado** creado para aislar y debuggear por qué las cartas no responden a clicks y drags en el juego principal.

### Estructura Simple
```
TestBoard
├── PlayerHand (3 cartas de ejemplo)
├── DropZone (zona para soltar cartas)
└── Botones: Back, Clear, Reload
```

### Comparación: GameBoard vs TestBoard

| Aspecto | GameBoard | TestBoard |
|--------|-----------|-----------|
| **Nodos** | 100+ nodos | ~20 nodos |
| **Complejidad** | Tablero completo (campos, oponente, UI) | Solo mano + drop zone |
| **Objetivo** | Juego real | Debuggeo de clicks |
| **Acceso** | Click en "⚔️ Batalla" | Click en "🧪 Test" |

---

## Cómo Probar

### Paso 1: Lanzar el Cliente
```bash
# En VS Code terminal del proyecto ccg/
# O abre Godot y ejecuta la escena
```

### Paso 2: Navegar a TestBoard
1. **En MainLobby** (menú principal):
   - Busca el botón **"🧪 Test"** en la barra de navegación
   - Click en él → Se abre TestBoard

### Paso 3: Observar la Consola
**CRÍTICO**: Abre la consola de Godot:
- **F8** o **View → Toggle Panel → Output** en Godot
- En VS Code Remote: Ver logs en el terminal

### Paso 4: Interactuar con Cartas

#### Prueba A: Click Simple
1. Click izquierdo en una carta en la mano
2. **ESPERADO**: Ver en consola:
   ```
   [TEST] CLICK: <nombre_de_la_carta>
   ```
3. **ACTUAL**: ¿Aparece el log? ¿No aparece?

#### Prueba B: Drag & Drop
1. Click y mantén sobre una carta
2. Arrastra hacia la zona roja (DropZone) a la derecha
3. Suelta el botón
4. **ESPERADO**: Ver en consola:
   ```
   [TEST] DRAG START
   [TEST] DRAG END
   ```

#### Prueba C: Botones
- **Clear**: Limpia la mano
- **Reload**: Recarga cartas del servidor
- **Back**: Vuelve al menú

---

## Interpretación de Resultados

### ✅ ESCENARIO 1: TestBoard funciona (clicks/drags trabajan)

**Qué significa**:
- El patrón de interactividad **SÍ funciona**
- El problema está en GameBoard específicamente

**Siguiente paso**:
- Comparar mouse_filter en GameBoard vs TestBoard
- Buscar nodos ocultos que bloqueen input en GameBoard
- Ejemplo: ¿Hay un overlay no visible sobre las cartas?

**Investigación**:
```gdscript
# En GameBoard, agregar esto temporalmente:
func _debug_input_blockers():
    var node = get_tree().root
    _print_mouse_filter_tree(node, 0)

func _print_mouse_filter_tree(node: Node, depth: int):
    var indent = "  ".repeat(depth)
    if node is Control:
        print(indent, node.name, " - mouse_filter=", node.mouse_filter, " visible=", node.visible)
    for child in node.get_children():
        _print_mouse_filter_tree(child, depth + 1)
```

---

### ❌ ESCENARIO 2: TestBoard NO funciona (clicks/drags no responden)

**Qué significa**:
- El patrón de interactividad está **ROTO**
- El problema NO es GameBoard, es fundamental

**Siguiente paso**:
Validar que eventos de mouse llegan a Godot:

```gdscript
# En TestBoard._ready() o temporalmente:
func _input(event: InputEvent):
    if event is InputEventMouseButton or event is InputEventMouseMotion:
        print("[INPUT DEBUG] ", event)
    super._input(event)
```

**Si `[INPUT DEBUG]` aparece**:
- ✅ Mouse events sí llegan a Godot
- ❌ Problema está en `gui_input` wiring o `mouse_filter` hierarchy
- Solución: Revisar manualmente que `gui_input.connect()` se ejecute sin errores

**Si `[INPUT DEBUG]` NO aparece**:
- ❌ Los eventos de mouse ni siquiera llegan a Godot
- Causa: Posible problema de Godot, ventana, o driver

---

## Qué Está Sucediendo Técnicamente

### Flujo de Eventos en TestBoard

```
Usuario hace click
    ↓
Sistema operativo → Godot recibe InputEventMouseButton
    ↓
Godot emite _input() a nodes del árbol
    ↓
PlayerHand (mouse_filter=PASS) → propaga al hijo
    ↓
CardDisplay (mouse_filter=STOP) → recibe y procesa
    ↓
CardDisplay._on_gui_input(event) se llama
    ↓
Valida: interaction_enabled=true, is_disabled=false
    ↓
Emite signal "card_clicked" → TestBoard recibe
    ↓
TestBoard imprime "[TEST] CLICK: ..."
```

### Puntos de Posible Fallo

1. **PlayerHand.mouse_filter ≠ PASS** → eventos no alcanzan cartas
2. **CardDisplay.mouse_filter ≠ STOP** → no captura eventos
3. **CardDisplay._on_gui_input no conectada** → función nunca se llama
4. **Señal no emitida** → TestBoard nunca recibe callback
5. **Godot no envía eventos** → problema del sistema

---

## Logs a Buscar

### Inicialización (cuando abres TestBoard)
```
[TEST] TestBoard._ready completado
[TEST] Solicitando mazos del usuario...
[TEST] _on_decks_loaded: 1 mazos encontrados
[TEST] Usando deck: Starter Deck (uuid...)
[TEST] Fetching cards from: http://localhost:3000/api/decks/uuid.../cards
[TEST] Deck tiene 40 cartas
[TEST] Cargadas 7 cartas en la mano
[TEST] Card added: Athena
[TEST] Card added: Ikki
[TEST] Card added: Shun
[TEST] gui_input conectado para Athena
[TEST] gui_input conectado para Ikki
[TEST] gui_input conectado para Shun
```

### Interactividad (cuando interactúas con cartas)
```
[TEST] CLICK: Athena        ← Buscas esto cuando haces click
[TEST] DRAG START           ← Buscas esto cuando empiezas a arrastrar
[TEST] DRAG END             ← Buscas esto cuando sueltas
```

### Errores Comunes
```
[TEST] ERROR - No hay mazos           ← Usuario no tiene decks
[TEST] ERROR HTTP: 401                ← Token expirado
[TEST] ERROR HTTP: 404                ← Deck ID no existe
[TEST] ERROR: JSON inválido           ← Respuesta corrupta del servidor
```

---

## Checklist de Debugging

- [ ] TestBoard aparece al clickear botón "🧪 Test"
- [ ] Cartas se cargan en la mano (ves 3-7 cartas)
- [ ] Cartas tienen imagenes
- [ ] Haces click en una carta → ¿Aparece `[TEST] CLICK`?
- [ ] Haces drag sobre una carta → ¿Aparece `[TEST] DRAG START`?
- [ ] Sueltas la carta → ¿Aparece `[TEST] DRAG END`?
- [ ] Botón "Clear" limpia la mano
- [ ] Botón "Reload" recarga cartas
- [ ] Botón "Back" vuelve a MainLobby

---

## Comandos para Terminal (Debugging Avanzado)

### Ver logs en tiempo real (si ejecutas desde terminal)
```bash
cd "d:\Disco E\Nacho\Projects\ccg"
godot --console
# O en Godot: F8 para Output console
```

### Validar que DecksManager está inicializado
```gdscript
# En TestBoard._ready():
print("[TEST] DecksManager ready: ", DecksManager != null)
print("[TEST] AuthManager ready: ", AuthManager != null)
print("[TEST] CardsManager ready: ", CardsManager != null)
```

### Simular click programáticamente
```gdscript
# En TestBoard._ready() o tras cargar cartas:
var card = cards_in_hand[0] if cards_in_hand.size() > 0 else null
if card:
    print("[TEST] Simulando click...")
    card.emit_signal("card_clicked", card.get_meta("card_data") if card.has_meta("card_data") else {})
```

---

## Siguiente: Interpretación de Resultados

Una vez ejecutes TestBoard y reportes qué logs ves (o no ves), estaremos en posición de:

1. **Si funciona en TestBoard** → Debuggear diferencias en GameBoard
2. **Si no funciona en TestBoard** → Validar setup de Godot/engine
3. **Si funciona parcialmente** → Identificar qué parte está rota (clicks vs drag, etc.)

---

## Resumen

**TestBoard es tu "laboratorio de pruebas"** para aislar si el problema es:
- ✅ Sistema de interactividad (funciona en TestBoard → problema en GameBoard)
- ❌ Patrón fundamental (no funciona en TestBoard → problema profundo)
- ⚠️ Específico a tipos de eventos (clicks vs drag, etc.)

**Próximo paso**: Abre TestBoard, haz clicks, y **reporta exactamente qué logs ves en la consola**.

---

**Creado**: Diciembre 2025 | **Estado**: En Debugging
