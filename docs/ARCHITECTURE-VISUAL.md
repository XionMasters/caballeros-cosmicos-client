# 🏗️ Arquitectura del Sistema - Diagrama Visual

## Level 1: Datos
```
┌────────────────────────────────────────────────────────────┐
│                      GAMESTATE                             │
│                                                            │
│  match_id, current_turn, current_phase                    │
│  player1_life, player1_cosmos, player1_hand[]             │
│  player2_life, player2_cosmos, player2_hand[]             │
│  field_knights[], field_techniques[], field_helper        │
│  opponent_knights[], opponent_techniques[], opponent_... │
│                                                            │
│  Métodos: get_hand(), get_cards_in_zone(), modify_cosmos()│
│  ⚠️ Solo lectura desde GameRules                          │
│  ⚠️ Modificación solo desde GameController               │
└────────────────────────────────────────────────────────────┘
```

## Level 2: Validación & Cálculos
```
┌──────────────────────┐      ┌─────────────────────────┐
│   GAMERULES          │      │  BATTLECALCULATOR       │
│  (Validación)        │      │  (Cálculos)             │
│                      │      │                         │
│ can_play_card()      │      │ calculate_damage()      │
│ can_place_card()     │      │ apply_technique_effect()│
│ can_declare_attack() │      │ is_knight_defeated()    │
│ can_use_technique()  │      │ get_lethal_damage()     │
│ can_perform_action() │      │ _apply_modifiers()      │
│                      │      │                         │
│ ✅ Pure functions    │      │ ✅ Pure functions       │
│ ✅ NO state change   │      │ ✅ NO state change      │
│ ✅ Atomic validity   │      │ ✅ Math only            │
└──────────────────────┘      └─────────────────────────┘
         △                              △
         │                              │
         └──────────────┬───────────────┘
                        │
```

## Level 3: Orquestación
```
                    ┌─────────────────────────┐
                    │  GAMECONTROLLER         │
                    │  (Orquestador Principal)│
                    │                         │
                    │ play_card()             │
                    │ declare_attack()        │
                    │ use_technique()         │
                    │ execute_knight_action() │
                    │ end_turn()              │
                    │                         │
                    │ Patrón:                 │
                    │ 1. Validar (GameRules)  │
                    │ 2. Si OK: Ejecutar      │
                    │ 3. Emitir signals       │
                    │                         │
                    │ Signals: 7 diferentes   │
                    │ ✅ Nexo entre Rules    │
                    │    y State              │
                    └─────────────────────────┘
                            △
                            │
                    ┌───────┴────────┐
                    │                │
```

## Level 4: Gestión de Estado
```
┌──────────────────────────┐    ┌───────────────────────────┐
│    HANDMANAGER           │    │    FIELDMANAGER           │
│  (Zona de Mano)          │    │  (Zonas de Campo)         │
│                          │    │                           │
│ add_card_to_hand()       │    │ place_card_on_field()     │
│ remove_card_from_hand()  │    │ remove_card_from_field()  │
│ get_playable_cards()     │    │                           │
│ get_cards_by_type()      │    │ get_knights_on_field()    │
│ get_hand_size()          │    │ get_techniques()          │
│ sort_hand_by_cost()      │    │ get_active_knights()      │
│ is_hand_full()           │    │ get_helper_card()         │
│                          │    │ get_scenario_card()       │
│ Signals: 4               │    │ can_place_knight()        │
│ Limit: 10 cartas         │    │ is_zone_full()            │
│                          │    │                           │
│                          │    │ Zones: 4 (K/T/H/S)        │
│ ✅ Coordina agregar/     │    │ Signals: 4                │
│    quitar desde mano     │    │                           │
│                          │    │ ✅ Coordina agregar/      │
│                          │    │    quitar desde campo     │
└──────────────────────────┘    └───────────────────────────┘
         △                               △
         │                               │
         └───────────────┬───────────────┘
                         │
                    Usa GameState
                    Valida con GameRules
                    Emite Signals
```

## Level 5: Presentación (UI)
```
┌────────────────────────────────────┐
│      GAMEBOARD                     │
│  (Escucha signals y renderiza)     │
│                                    │
│ _on_card_played()                  │
│ _on_attack_declared()              │
│ _on_phase_changed()                │
│ _on_hand_updated()                 │
│ _on_field_updated()                │
│                                    │
│ Responde a:                        │
│ - CardAnimationManager (anima)     │
│ - MatchEffectsManager (efectos)    │
│ - CardDisplay (renderiza cartas)   │
│ - UI labels (cosmos, vida, etc)    │
└────────────────────────────────────┘
```

---

## Flujos de Datos Completos

### Flujo 1: Jugar una Carta
```
┌─────────────┐
│  CardSlot   │
│   .drop()   │
└──────┬──────┘
       │
       ▼
┌──────────────────────────────────┐
│ GameController.play_card()       │
└──────┬──────────────────────────┘
       │
       ├─1─▶ GameRules.can_play_card() ────────┐
       │     (Valida: costo + tipo)            │
       │                                       ├─ ✓ OK
       ├─2─▶ GameRules.can_place_card() ──────┤
       │     (Valida: zona + espacio)          │
       │                                       │
       ├─3─▶ GameState.modify_cosmos()         │
       │     (Aplica cambio)                   │
       │                                       │
       ├─4─▶ GameState.add_card_to_zone()     │
       │     (Coloca en campo)                 │
       │                                       │
       ▼                                       │
    ┌────────────────────────────────┐        │
    │ card_played.emit()             │◀───────┘
    └──────┬─────────────────────────┘
           │
           ▼
    ┌────────────────────────────┐
    │ GameBoard._on_card_played()│
    └──────┬─────────────────────┘
           │
           ├─▶ CardAnimationManager.animate()
           ├─▶ MatchEffectsManager.spawn()
           └─▶ UI.update_cosmos_display()
```

### Flujo 2: Atacar
```
┌─────────────┐
│ GameBoard   │
│  attack()   │
└──────┬──────┘
       │
       ▼
┌──────────────────────────────────┐
│ GameController.declare_attack()  │
└──────┬──────────────────────────┘
       │
       ├─1─▶ GameRules.can_declare_attack() ──┐
       │     (Valida: no exhausted, etc)      │
       │                                      ├─ ✓ OK
       ├─2─▶ BattleCalculator.calculate() ───┤
       │     (Calcula daño)                   │
       │                                      │
       ├─3─▶ GameState.modify_hp()           │
       │     (Aplica daño)                    │
       │                                      │
       ├─4─▶ GameState.is_exhausted = true   │
       │     (Marca atacante como exhausto)   │
       │                                      │
       ▼                                      │
    ┌──────────────────────────────────┐    │
    │ attack_declared.emit(damage)     │◀───┘
    └──────┬───────────────────────────┘
           │
           ▼
    ┌────────────────────────────────┐
    │ GameBoard._on_attack_declared()│
    └──────┬─────────────────────────┘
           │
           ├─▶ CardAnimationManager.animate_attack()
           ├─▶ MatchEffectsManager.spawn_damage()
           └─▶ UI.update_health_display()
```

### Flujo 3: Fin de Turno
```
┌─────────────┐
│ GameBoard   │
│ end_turn()  │
└──────┬──────┘
       │
       ▼
┌──────────────────────────────────┐
│ GameController.end_turn()        │
└──────┬──────────────────────────┘
       │
       ├─1─▶ GameState.current_player = 2
       │
       ├─2─▶ GameState.reset_exhausted()
       │
       ├─3─▶ HandManager.add_card_to_hand()
       │     (Roba una carta)
       │
       ├─4─▶ GameState.current_phase = "draw"
       │
       ▼
    ┌──────────────────────────┐
    │ phase_changed.emit()     │
    └──────┬───────────────────┘
           │
           ▼
    ┌────────────────────────────────┐
    │ GameBoard._on_phase_changed()  │
    └──────┬─────────────────────────┘
           │
           ├─▶ TurnPhaseManager.update_phase()
           ├─▶ UI.update_player_indicator()
           ├─▶ UI.update_phase_label()
           └─▶ AudioManager.play_turn_sound()
```

---

## Responsabilidades Claras

```
LÓGICA (No toca UI):
  GameRules
  BattleCalculator
  GameController
  HandManager
  FieldManager
         ↓
DATOS (Observables):
  GameState
         ↓
PRESENTACIÓN (No llama lógica):
  GameBoard
  CardDisplay
  CardAnimationManager
  MatchEffectsManager
  UI Labels
```

---

## Secuencia Típica: Turno Completo

```
┌─────────────────────────────────────────────────────────┐
│ TURNO DEL JUGADOR 1 (4 fases)                          │
└─────────────────────────────────────────────────────────┘

1. DRAW (Roba)
   end_turn() [de turno anterior]
   └─ Roba 1 carta
   └─ hand_updated.emit()

2. MAIN (Juega cartas)
   play_card() x N veces
   └─ Valida (GameRules)
   └─ Ejecuta (GameState)
   └─ card_played.emit()
   └─ [Para cada una: anima + efectos]

3. BATTLE (Combate)
   declare_attack() x N veces
   └─ Valida (GameRules)
   └─ Calcula (BattleCalculator)
   └─ Ejecuta (GameState)
   └─ attack_declared.emit()
   └─ [Para cada una: anima + efectos + daño]

4. END (Termina turno)
   end_turn()
   └─ Cambiar a jugador 2
   └─ Reset exhausted
   └─ phase_changed.emit()
   └─ [Actualizar UI]

┌─────────────────────────────────────────────────────────┐
│ TURNO DEL JUGADOR 2 (repite fases 1-4)                │
└─────────────────────────────────────────────────────────┘
```

---

## Comparación: Antes vs Después

### ANTES (Responsabilidades Mezcladas)
```
CardSlot.gd
├─ Renderiza visual
├─ Valida drop
├─ Modifica CardInstance
├─ Calcula daño
├─ Modifica GameState
├─ Anima
└─ Actualiza UI

❌ 8 responsabilidades en 1 módulo
❌ Difícil de testear
❌ Difícil de mantener
```

### DESPUÉS (Responsabilidades Separadas)
```
GameRules.gd       ← Valida (puro)
BattleCalculator   ← Calcula (puro)
GameController     ← Orquesta (lógica)
GameState          ← Almacena (datos)
HandManager        ← Gestiona mano (state)
FieldManager       ← Gestiona campo (state)
GameBoard          ← Renderiza (UI)
CardDisplay        ← Muestra carta (UI)
CardAnimationMgr   ← Anima (efecto)
MatchEffectsMgr    ← Efectos visuales (efecto)

✅ 1 responsabilidad cada una
✅ Fácil de testear
✅ Fácil de mantener
```

---

## Mapa de Dependencias

```
GameBoard
  ├─ depende de → GameController (signals)
  ├─ depende de → GameState (lectura)
  ├─ depende de → CardAnimationManager
  └─ depende de → MatchEffectsManager

GameController
  ├─ depende de → GameState
  ├─ depende de → GameRules
  └─ depende de → BattleCalculator

GameRules
  ├─ depende de → GameState (solo lectura)
  └─ depende de → CardData

BattleCalculator
  └─ depende de → CardInstance (solo lectura)

HandManager
  ├─ depende de → GameState
  └─ depende de → GameRules

FieldManager
  ├─ depende de → GameState
  └─ depende de → GameRules

⚠️ NUNCA hay dependencias hacia GameBoard desde lógica
⚠️ Flujo es SIEMPRE: Lógica → Signals → GameBoard
```

---

## Checklist de Implementación

```
□ GameState configurado
□ GameController creado
□ HandManager creado
□ FieldManager creado
□ GameController.card_played signal escuchado
□ GameController.attack_declared signal escuchado
□ GameController.phase_changed signal escuchado
□ HandManager.hand_updated signal escuchado
□ FieldManager.field_updated signal escuchado
□ TestBoard con botones de test
□ Pruebas: play_card → OK
□ Pruebas: declare_attack → OK
□ Pruebas: end_turn → OK
```

---

**Imprimir o guardar para referencia rápida durante desarrollo**  
**Use este diagrama al tomar decisiones arquitectónicas**  

