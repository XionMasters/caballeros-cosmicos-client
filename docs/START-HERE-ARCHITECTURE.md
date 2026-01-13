# 🚀 START HERE - Nueva Arquitectura

## Bienvenida

Hola. En esta sesión se implementó una **arquitectura completamente nueva** para el sistema de juego. Lee este archivo primero.

---

## 5 Cosas Que Necesitas Saber

### 1️⃣ Hay 5 Módulos Nuevos

| Módulo | Responsabilidad | Ubicación |
|--------|-----------------|-----------|
| **GameRules** | ¿Es legal? | `scripts/rules/` |
| **BattleCalculator** | ¿Cuánto daño? | `scripts/rules/` |
| **GameController** | Ejecutar acción | `scripts/rules/` |
| **HandManager** | Gestionar mano | `scripts/managers/` |
| **FieldManager** | Gestionar campo | `scripts/managers/` |

### 2️⃣ El Patrón es Siempre Igual

```
VALIDAR (GameRules) → EJECUTAR (GameState) → EMITIR (Signal)
```

### 3️⃣ GameState es el "Guardián"

Solo GameController puede modificarlo. Todos los demás solo leen.

### 4️⃣ Los Signals Conectan Lógica con UI

Cuando algo importante pasa, se emite un signal. GameBoard escucha y actualiza.

### 5️⃣ Todo Está Documentado

Hay 10 documentos con explicaciones, ejemplos y tablas de referencia.

---

## Inicio Rápido (5 minutos)

### Para Jugar una Carta

```gdscript
# Solo necesitas una línea
GameController.play_card(card, "field_knight", position)

# Internamente GameController:
# 1. Valida con GameRules
# 2. Modifica GameState
# 3. Emite signal card_played
# 4. GameBoard escucha y renderiza
```

### Para Atacar

```gdscript
# Solo necesitas una línea
GameController.declare_attack(attacker_id, defender_id)

# Internamente GameController:
# 1. Valida con GameRules
# 2. Calcula daño con BattleCalculator
# 3. Modifica GameState
# 4. Emite signal attack_declared
# 5. GameBoard escucha y anima
```

### Para Terminar Turno

```gdscript
# Solo necesitas una línea
GameController.end_turn()

# Internamente GameController:
# 1. Cambia jugador
# 2. Reset cards exhausted
# 3. Roba carta
# 4. Emite signal phase_changed
```

---

## Arquitectura Visual

```
GameBoard (UI)
    ↑
    │ escucha signals
    │
GameController (Lógica)
    ├─ Valida con GameRules
    ├─ Calcula con BattleCalculator
    ├─ Modifica GameState
    └─ Emite Signals
        │
        ├─ card_played
        ├─ attack_declared
        ├─ technique_used
        ├─ knight_action_executed
        └─ phase_changed

GameState (Datos)
    ├─ Jugadores
    ├─ Cartas
    ├─ Cosmos
    ├─ Vida
    └─ Zonas

HandManager (Gestor)
    └─ Coordina: agregar/quitar/buscar en mano

FieldManager (Gestor)
    └─ Coordina: agregar/quitar/buscar en campo
```

---

## Documentación: Qué Leer

### Si Tienes 5 Minutos
Leer este archivo + QUICK-REFERENCE.md

### Si Tienes 15 Minutos
1. ARCHITECTURE-MODULES-README.md
2. ARCHITECTURE-VISUAL.md
3. QUICK-REFERENCE.md

### Si Tienes 30 Minutos
1. ARCHITECTURE-MODULES-README.md (10 min)
2. INTEGRATION-QUICK-START.md (15 min)
3. QUICK-REFERENCE.md (5 min)

### Si Tienes 1 Hora
Lee todos los documentos en orden:
1. ARCHITECTURE-MODULES-README.md
2. INTEGRATION-QUICK-START.md
3. QUICK-REFERENCE.md
4. ARCHITECTURE-VISUAL.md
5. MODULES-INDEX.md
6. COMPLETION-SUMMARY.md

---

## Códigos en `scripts/rules/`

### GameRules.gd (260 líneas)
Pregunta si algo es legal:
```gdscript
game_rules.can_play_card(card, cosmos)      # ¿Puedo jugar?
game_rules.can_place_card(card, zone)       # ¿Puedo colocar?
game_rules.can_declare_attack(knight)       # ¿Puedo atacar?
game_rules.can_use_technique(technique)     # ¿Compatible?
game_rules.can_perform_action_in_phase(p)  # ¿Válido en fase?
```

### BattleCalculator.gd (320 líneas)
Calcula números:
```gdscript
battle_calculator.calculate_damage(atk, def)        # ¿Cuánto daño?
battle_calculator.calculate_healing(healer)         # ¿Cuánta sanación?
battle_calculator.is_knight_defeated(knight)        # ¿Muerto?
battle_calculator.get_lethal_damage(health)         # ¿Daño letal?
```

### GameController.gd (350 líneas)
Ejecuta acciones:
```gdscript
game_controller.play_card(card, zone)               # Jugar
game_controller.declare_attack(attacker, defender)  # Atacar
game_controller.use_technique(technique, targets)   # Técnica
game_controller.execute_knight_action(action)       # Acción
game_controller.end_turn()                          # Fin turno
```

---

## Códigos en `scripts/managers/`

### HandManager.gd (330 líneas)
Gestiona mano:
```gdscript
hand_manager.add_card_to_hand(card, player)         # Agregar
hand_manager.remove_card_from_hand(card_id, player) # Quitar
hand_manager.get_playable_cards(player, cosmos)     # ¿Cuáles puedo jugar?
hand_manager.get_hand_size(player)                  # ¿Cuántas cartas?
hand_manager.is_hand_full(player)                   # ¿Mano llena?
```

### FieldManager.gd (360 líneas)
Gestiona campo:
```gdscript
field_manager.place_card_on_field(card, zone, pos)  # Colocar
field_manager.remove_card_from_field(card_id, zone) # Quitar
field_manager.get_knights_on_field(player)          # ¿Qué knights?
field_manager.get_active_knights(player)            # ¿Knights activos?
field_manager.can_place_knight(player)              # ¿Hay espacio?
```

---

## Principales Cambios Respecto a Antes

### Antes ❌
```gdscript
# Validación esparcida en varios módulos
if card.cost <= cosmos and is_zone_free:
    game_state.player_hand.remove(card)
    game_state.field.append(card)
    animate_card(card)
    update_ui()
```

### Ahora ✅
```gdscript
# Una sola línea - el resto se coordina automáticamente
GameController.play_card(card, "field_knight", position)
```

---

## Cómo Usar en GameBoard

### Inicialización

```gdscript
func _ready() -> void:
    # Crear instancias
    var game_controller = GameController.new()
    game_controller.set_game_state(game_state)
    add_child(game_controller)
    
    var hand_manager = HandManager.new()
    hand_manager.set_game_state(game_state)
    add_child(hand_manager)
    
    var field_manager = FieldManager.new()
    field_manager.set_game_state(game_state)
    add_child(field_manager)
    
    # Conectar signals
    game_controller.card_played.connect(_on_card_played)
    game_controller.attack_declared.connect(_on_attack_declared)
    game_controller.phase_changed.connect(_on_phase_changed)
```

### Escuchar Cambios

```gdscript
func _on_card_played(card, zone, position):
    # Animar carta
    CardAnimationManager.animate_card_play(card)
    
    # Efecto visual
    MatchEffectsManager.spawn_cosmos_burst(card.position)
    
    # Actualizar UI
    update_cosmos_display()

func _on_attack_declared(attacker_id, defender_id, damage):
    # Animar ataque
    var attacker = field_manager.get_card_by_id(attacker_id, 1)
    var defender = field_manager.get_card_by_id(defender_id, 2)
    
    CardAnimationManager.animate_attack(attacker, defender, damage)
    MatchEffectsManager.spawn_damage_number(defender, damage)
```

---

## Cómo Testear en TestBoard

```gdscript
# Agregar botones de test
func _on_test_play_card():
    var hand = game_state.get_hand_for_player(1)
    if hand.size() > 0:
        var card = hand[0]
        if GameController.play_card(card, "field_knight", 0):
            print("✓ Carta jugada exitosamente")
        else:
            print("✗ No se puede jugar")

func _on_test_attack():
    var my_knights = field_manager.get_knights_on_field(1)
    var opp_knights = field_manager.get_knights_on_field(2)
    
    if my_knights.size() > 0 and opp_knights.size() > 0:
        if GameController.declare_attack(my_knights[0].instance_id, opp_knights[0].instance_id):
            print("✓ Ataque exitoso")
        else:
            print("✗ No se puede atacar")

func _on_test_end_turn():
    GameController.end_turn()
    print("✓ Turno terminado - Ahora es turno del jugador 2")
```

---

## Reglas de Oro

### ❌ NUNCA HAGAS ESTO

```gdscript
# ❌ Modificar GameState directamente
game_state.player_cosmos -= 3
game_state.player_hand.remove(card)

# ❌ Asumir que una acción es válida sin validar
game_controller.play_card(card, zone)  # Sin chequear retorno

# ❌ Modificar mano directamente
game_state.player_hand.append(card)
hand_manager.add_card_to_hand(card)  # Hay que usar manager

# ❌ Asumir que CardSlot puede jugar cartas
slot.play_card()  # CardSlot es solo UI ahora
```

### ✅ SIEMPRE HAZ ESTO

```gdscript
# ✅ Usar GameController para acciones
if GameController.play_card(card, zone, position):
    print("✓ OK")
else:
    print("✗ No se puede")

# ✅ Validar antes de ejecutar
if GameRules.can_play_card(card, cosmos):
    GameController.play_card(card, zone)

# ✅ Usar managers para mano
HandManager.add_card_to_hand(card, 1)

# ✅ Escuchar signals en GameBoard
GameController.card_played.connect(_on_card_played)

func _on_card_played(card, zone, position):
    # Actualizar visual acá
    pass
```

---

## Preguntas Frecuentes

**P: ¿Tengo que usar los 5 módulos?**  
R: SÍ. Juntos forman el sistema completo.

**P: ¿Puedo ignorar HandManager?**  
R: NO. Gestiona automáticamente la mano.

**P: ¿Puedo ignorar FieldManager?**  
R: NO. Gestiona automáticamente el campo.

**P: ¿Cuándo uso cada módulo?**  
```
GameRules:        Antes de hacer algo → ¿Puedo?
BattleCalculator: Para calcular daño
GameController:   Para ejecutar acciones
HandManager:      Para gestionar mano
FieldManager:     Para gestionar campo
```

**P: ¿Qué pasa si GameRules retorna false?**  
R: GameController retorna false y no ejecuta nada.

---

## Próximos Pasos

### Inmediato (Hoy)
- [ ] Leer ARCHITECTURE-MODULES-README.md
- [ ] Leer INTEGRATION-QUICK-START.md
- [ ] Leer QUICK-REFERENCE.md

### Muy Pronto (Mañana)
- [ ] Testear GameController en TestBoard
- [ ] Verificar signals se emiten
- [ ] Integrar en GameBoard

### Corto Plazo (Esta semana)
- [ ] Refactor CardPlayManager (usar GameRules)
- [ ] Limpiar MatchManager
- [ ] Simplificar CardSlot

---

## Documentos Importantes

| Documento | Por qué Leerlo | Tiempo |
|-----------|----------------|--------|
| **QUICK-REFERENCE.md** | Tabla rápida de métodos | 2 min |
| **ARCHITECTURE-MODULES-README.md** | Visión general | 10 min |
| **INTEGRATION-QUICK-START.md** | Cómo implementar | 15 min |
| **ARCHITECTURE-VISUAL.md** | Diagramas | 5 min |
| **QUICK-REFERENCE.md** | Búsqueda rápida | 1 min |

---

## Diagrama Simple

```
┌────────────────────────┐
│   Tu Código (UI)       │
│   (GameBoard.gd)       │
└───────────┬────────────┘
            │
            │ Llama
            ▼
┌────────────────────────┐
│  GameController        │  ← Le dices qué hacer
│  (Orquestador)         │    Él se encarga de TODO
└───────────┬────────────┘
            │
    ┌───────┴────────┐
    │                │
    ▼                ▼
┌─────────────┐  ┌──────────────┐
│GameRules    │  │BattleCalc    │
│(Valida)     │  │(Calcula)     │
└─────────────┘  └──────────────┘
    │                │
    └───────┬────────┘
            │
            ▼
    ┌──────────────────┐
    │ GameState        │  ← Datos guardados acá
    │ (Fuente de Verdad)
    └──────────────────┘
    
GameBoard escucha Signals
    └─ Renderiza cambios
```

---

## Conclusión

Acabas de heredar una **arquitectura nueva y limpia**. Los 5 módulos hacen el trabajo pesado. Tu job es:

1. Llamar a GameController para ejecutar acciones
2. Escuchar signals en GameBoard
3. Renderizar cambios

**¡Eso es todo!**

---

## Siguiente Lectura

Abre **QUICK-REFERENCE.md** para tabla rápida de métodos.

Luego abre **INTEGRATION-QUICK-START.md** para ejemplos prácticos.

---

**Bienvenido a la nueva arquitectura del juego 🎮**

