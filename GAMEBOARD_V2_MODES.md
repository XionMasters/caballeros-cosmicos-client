# GameBoard_v2: Modo Normal vs Test Mode

## Resumen
GameBoard_v2 ahora soporta DOS modos de juego:

### 1. **Modo Normal (Multiplayer Real)**
- Juegas contra otro jugador real
- El servidor controla toda la lógica
- Tu cliente solo renderiza y recibe updates
- **Por defecto**: `enable_test_mode = false`

### 2. **Modo Test (Test Mode)**
- Juegas contra ti mismo (controlas ambos jugadores)
- Permite desarrollar sin servidor
- Código del lado del cliente maneja algunas acciones
- **Activar en Editor**: `enable_test_mode = true`

---

## Cómo Cambiar el Modo

### Opción A: Desde el Editor Godot (RECOMENDADO)
1. Abre `GameBoard_new.tscn`
2. En el Inspector, busca `GameBoard_v2` script
3. Activa el checkbox `Enable Test Mode`
4. Guarda y corre la escena

```
[GameBoard_v2 (script)]
├── [+] Script
├── Node
│   └── [x] Enable Test Mode  ← Cambiar aquí
└── ...
```

### Opción B: Programáticamente
```gdscript
# En tu código
func _ready():
    game_board.enable_test_mode = true  # Activar test_mode
    game_board.enable_test_mode = false # Desactivar (normal)
```

---

## Flujo en Cada Modo

### **Modo Normal (enable_test_mode = false)**
```
1. Conectar a servidor
2. Servidor crea partida con 2 jugadores reales
3. Servidor envía estado inicial (cards_in_play, hand, etc)
4. Cliente renderiza SOLO su mano (opponent_hand = card backs)
5. Al recibir update del servidor → render_all_zones()
6. Esperar turno del cliente
7. Hacer acciones (drag-drop cartas)
8. Enviar al servidor
9. Servidor valida y responde
```

### **Modo Test (enable_test_mode = true)**
```
1. Conectar a servidor
2. Servidor crea TEST partida (ambos jugadores = tu mazo)
3. Servidor envía estado inicial
4. Cliente renderiza TODAS las cartas (incluyendo opponent hand)
5. MatchPlayController se crea en _initialize_match()
6. Puedes jugar ambos lados sin esperar turno
7. Hacer acciones (drag-drop, cambiar de jugador)
8. MatchPlayController valida localmente
9. Enviar al servidor (si es necesario)
```

---

## Componentes Principales

### GameBoard_v2.gd
```gdscript
@export var enable_test_mode: bool = false  # Cambiar aquí

# En _ready():
is_test_mode = enable_test_mode

# En _initialize_match():
if is_test_mode:
    # Crear MatchPlayController para jugar ambos lados
    match_play_controller = MatchPlayController.new(...)
    add_child(match_play_controller)
    match_play_controller.setup_card_interactions()
```

### BoardRenderer
- Renderiza TODAS las cartas (hand, field, decks, etc)
- Funciona en ambos modos
- Se llama en `_render_all_zones()`

### MatchPlayController (Solo Test Mode)
- Maneja drag-drop e interacciones de cartas
- Permite jugar sin servidor en test_mode
- Se re-crea después de cada `_render_all_zones()`

---

## Diferencias Visuales

| Feature | Normal | Test Mode |
|---------|--------|-----------|
| Ver mano propia | ✅ Cartas reales | ✅ Cartas reales |
| Ver mano oponente | ❌ Card backs | ✅ Cartas reales |
| Drag-drop | ✅ Si es tu turno | ✅ Siempre |
| Cambiar jugador | ❌ No | ✅ Al pasar turno |
| Servidor valida | ✅ Sí | ✅ Sí (pero local también) |

---

## Debugging

### Ver logs de test_mode
```
[GameBoard] 🧪 Test Mode: Creando MatchPlayController para jugar ambos lados
[GameBoard] ✅ Inicialización completada (Player 1, Test Mode: true)
[MatchPlayController] 🎮 Configurando interacciones de cartas...
```

### Cambiar durante ejecución
En la consola de Godot:
```gdscript
# Para un nodo llamado GameBoard
$GameBoard.enable_test_mode = true
$GameBoard._ready()
```

---

## Próximas Mejoras

- [ ] Selector de modo en Main Menu
- [ ] Auto-switch entre P1 ↔ P2 en test_mode
- [ ] IA simple para test_mode
- [ ] Replay de partidas en test_mode
- [ ] Estadísticas de prueba (carta más jugada, etc)

---

**Última actualización**: Enero 14, 2026
