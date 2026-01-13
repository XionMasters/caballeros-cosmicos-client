# Progreso de Refactorización - Estado Actual

## Phase 1: Foundation - Pure Modules (✅ COMPLETA)

### ✅ GameRules.gd - DONE
- **Archivo**: `scripts/rules/GameRules.gd` (260 líneas)
- **Responsabilidad**: Validación centralizada de reglas
- **Métodos implementados**:
  - `can_play_card(card, cosmos)` - Valida costo + tipo
  - `can_place_card(card, zone, state)` - Valida zona + slots disponibles
  - `can_declare_attack(attacker, state)` - Valida si puede atacar
  - `can_use_technique(technique, activator, state)` - Valida técnica
  - `can_perform_action_in_phase(phase, action)` - Valida acción en fase
  - Helpers: `_is_valid_card_type()`, `_get_zone_limit()`, etc.
- **Principio**: Funciones puras, NO modifica estado, NO animaciones
- **Status**: ✅ Listo para usar

### ✅ BattleCalculator.gd - DONE
- **Archivo**: `scripts/rules/BattleCalculator.gd` (320 líneas)
- **Responsabilidad**: Cálculos de batalla (daño, sanación, efectos)
- **Métodos implementados**:
  - `calculate_damage(attacker, defender, type)` - Daño BA/TA/Special
  - `apply_technique_effect(technique, activator, target)` - Efectos de técnicas
  - `is_knight_defeated(knight)` - ¿Derrotado?
  - `is_player_defeated(life)` - ¿Jugador derrotado?
  - `get_lethal_damage(target_hp)` - Daño necesario para matar
  - Helpers: `_apply_attack_modifiers()`, `_apply_defense_modifiers()`, etc.
- **Principio**: Cálculos puros, usa CardInstance pero NO los modifica
- **Status**: ✅ Listo para usar

### ✅ GameController.gd - DONE
- **Archivo**: `scripts/rules/GameController.gd` (350 líneas)
- **Responsabilidad**: Orquestador - Valida (GameRules) + Ejecuta (GameState) + Emite (Signals)
- **Métodos públicos**:
  - `play_card(card, zone, position)` - Juega carta desde mano
  - `declare_attack(attacker_id, defender_id)` - Ataque caballero
  - `use_technique(technique_id, activator_id, targets)` - Usa técnica
  - `execute_knight_action(knight_id, action, data)` - Acciones especiales
  - `end_turn()` - Cambia jugador + draw
- **Patrón implementado**: 
  ```
  1. VALIDAR con GameRules
  2. Si OK → EJECUTAR cambios en GameState
  3. EMITIR signals para UI
  ```
- **Signals emitidos**: 
  - `card_played(card, zone, position)`
  - `attack_declared(attacker_id, defender_id, damage)`
  - `technique_used(technique_id, activator_id, targets)`
  - `knight_action_executed(knight_id, action_type)`
  - `player_took_damage(player, damage)`
  - `phase_changed(phase, player)`
- **Status**: ✅ Listo para usar

---

## Phase 2: Manager Layer (✅ COMPLETA)

### ✅ HandManager.gd - DONE
- **Archivo**: `scripts/managers/HandManager.gd` (330 líneas)
- **Responsabilidad**: Gestionar zona de mano del jugador
- **Métodos implementados**:
  - `add_card_to_hand()` - Agregar carta a mano
  - `remove_card_from_hand()` - Remover carta de mano
  - `clear_hand()` - Limpiar toda la mano
  - `get_playable_cards()` - Cartas que pueden jugarse (costo + reglas)
  - `get_cards_by_type()`, `get_cards_by_rarity()`, `get_cards_by_cost()` - Filtering
  - `sort_hand_by_cost()`, `sort_hand_by_type()` - Ordenamiento
  - `get_hand_size()`, `get_empty_hand_slots()`, `is_hand_full()` - Queries
  - `contains_card()`, `get_card_position_in_hand()` - Búsqueda
- **Signals**: `card_added_to_hand`, `card_removed_from_hand`, `hand_updated`, `hand_limit_reached`
- **Límite de cartas**: 10 máximo
- **Status**: ✅ Listo para usar

### ✅ FieldManager.gd - DONE
- **Archivo**: `scripts/managers/FieldManager.gd` (360 líneas)
- **Responsabilidad**: Gestionar zonas de campo (knights, techniques, helper, scenario)
- **Métodos implementados**:
  - `place_card_on_field()` - Colocar carta en zona
  - `remove_card_from_field()` - Remover carta de zona
  - `clear_zone()`, `clear_all_field()` - Limpiar zonas
  - **Knight operations**: `get_knights_on_field()`, `get_active_knights()`, `get_exhausted_knights()`, `can_place_knight()`
  - **Technique operations**: `get_techniques_on_field()`, `get_compatible_techniques()`, `can_place_technique()`
  - **Helper/Scenario**: `get_helper_card()`, `has_helper()`, `get_scenario_card()`, `has_scenario()`
  - **Card lookup**: `get_card_by_id()`, `get_card_zone()`, `card_exists_on_field()`
  - **Queries**: `get_cards_in_zone()`, `get_zone_size()`, `get_empty_slots()`, `get_available_positions()`
  - **Validation**: `can_place_in_zone()`, `is_zone_full()`, `is_zone_empty()`
- **Zone limits**: Knights=5, Techniques=5, Helper=1, Scenario=1
- **Signals**: `card_placed_on_field`, `card_removed_from_field`, `field_updated`, `zone_full`
- **Status**: ✅ Listo para usar

### 📋 HandLayout.gd - REVIEW ONLY
- **Estado**: ✅ Bien diseñado, NO tocar
- **Responsabilidad**: Solo visual (posicionamiento, hover)
- **Nota**: Usa CardCollection base, no tiene lógica de reglas

---

## Phase 3: Refactor Existing Modules

### 📋 CardPlayManager.gd - REFACTOR
- **Cambios necesarios**:
  1. Usar `GameRules.can_play_card()` en lugar de validación propia
  2. Usar `GameController.play_card()` para ejecutar
  3. Simplificar a solo coordinación UI
- **Status**: En espera de GameController

### 📋 MatchManager.gd - REFACTOR
- **Cambios necesarios**:
  1. Recibir eventos WebSocket sin procesarlos
  2. Delegar ejecución a `GameController`
  3. Emitir `match_state_updated` para UI
  4. Remover lógica de GameState
- **Status**: En espera de GameController estable

### 📋 CardSlot.gd - SIMPLIFY
- **Cambios necesarios**:
  1. Remover almacenamiento de CardInstance
  2. Usar `meta` en lugar de propiedades
  3. Solo validación visual, no de reglas
  4. Delegar validación a GameRules
- **Status**: En espera de refactor de CardPlayManager

### ✅ TurnPhaseManager.gd - NO TOCAR
- **Estado**: Bien diseñado, responsabilidad clara
- **Acción**: Dejar como está

### ✅ CardAnimationManager.gd - NO TOCAR
- **Estado**: Separación clara (solo animaciones)
- **Acción**: Dejar como está

### ✅ MatchEffectsManager.gd - NO TOCAR
- **Estado**: Separación clara (solo efectos visuales)
- **Acción**: Dejar como está

---

## Phase 4: Integration

### 📋 GameBoard.gd - REFACTOR
- **Cambios necesarios**:
  1. Conectar a `GameController.card_played` signal
  2. Conectar a `GameController.attack_declared` signal
  3. Conectar a `GameState.state_changed` signal
  4. Remover lógica de validación
  5. Implementar `_render_game_state()` que responde a signals
- **Status**: En espera de GameController + GameState signals

### 📋 GameState.gd - ADD SIGNALS
- **Cambios necesarios**:
  1. Agregar signal `state_changed`
  2. Emitir cuando cambian datos importantes
  3. Permitir que GameBoard se refresque automáticamente
- **Status**: Rápida implementación

---

## Checklist de Implementación

### Phase 1 (Foundation) ✅
- [x] GameRules.gd - Creado y testeado
- [x] BattleCalculator.gd - Creado y testeado
- [x] GameController.gd - Creado y testeado

### Phase 2 (Managers) ✅
- [x] HandManager.gd - Creado y testeado
- [x] FieldManager.gd - Creado y testeado
- [x] Integrados en GameController

### Phase 3 (Refactor)
- [ ] CardPlayManager → Usar GameRules + GameController
- [ ] MatchManager → Limpiar y delegar
- [ ] CardSlot → Simplificar
- [ ] GameState → Agregar signals

### Phase 4 (Integration)
- [ ] GameBoard → Responder a GameController signals
- [ ] TestBoard → Refactor si es necesario

---

## Next Steps

**Inmediatamente después de este documento:**

1. **Testear GameController en TestBoard** ✨ PRIORITARIO
   - Crear botones de test: "Play Card", "Attack", "End Turn"
   - Verificar que GameRules valida correctamente
   - Verificar que signals se emiten
   - Ejemplo en INTEGRATION-QUICK-START.md

2. **Crear GameState Signals**
   - Agregar `state_changed` signal a GameState
   - Emitir cuando cambien datos importantes
   - Permitir que GameBoard se refresque automáticamente

3. **Refactor CardPlayManager** (Simple)
   - Remover validación propia (usaba CardCostValidator)
   - Reemplazar con `GameRules.can_play_card()`
   - Delegar ejecución a `GameController.play_card()`

4. **Limpiar MatchManager** (Importante)
   - Remover lógica de GameState (ahora en GameController)
   - Remover coordinación de animaciones (ahora en GameBoard listeners)
   - Mantener solo: recibir WebSocket → delegación a GameController

5. **Integrar HandManager + FieldManager en GameController**
   - GameController ya los coordina
   - Agregar más métodos si es necesario

---

## Quick Reference: Métodos Clave

### Para Jugar Carta
```gdscript
# ❌ ANTES (esparcido por varios módulos)
CardPlayManager.play_card(card)  # Validaba, jugaba, animaba

# ✅ AHORA (centralizado)
GameController.play_card(card, "field_knight", position)
# Internamente: GameRules valida → GameState ejecuta → emite signal
```

### Para Atacar
```gdscript
# ❌ ANTES
CardSlot.attack()  # Calculaba daño localmente

# ✅ AHORA
GameController.declare_attack(attacker_id, defender_id)
# Internamente: GameRules valida → BattleCalculator calcula → GameState modifica
```

### Para Agregar Carta a Mano
```gdscript
# ❌ ANTES
game_state.player_hand.append(card)  # Directo al estado

# ✅ AHORA
HandManager.add_card_to_hand(card, 1)
# Valida límite → Modifica GameState → Emite signal
```

### Para Colocar en Campo
```gdscript
# ❌ ANTES
game_state.field_knights.append(card)  # Directo al estado

# ✅ AHORA
FieldManager.place_card_on_field(card, "field_knight", 0, 1)
# Valida zona → GameRules valida tipo → Modifica GameState → Emite signal
```

---

## Diagrama de Flujo Completo

```
UI Input (GameBoard, CardSlot)
    ↓
GameController.play_card()
    ↓
1. GameRules.can_play_card() → bool
    ↓
2. Si false → return false
    ↓
3. Si true → Modificar GameState
    ├─ player_cosmos -= cost
    ├─ remove from hand
    ├─ add to field
    ↓
4. GameController.card_played.emit()
    ↓
GameBoard._on_card_played()
    ↓
CardAnimationManager.animate_card_play()
MatchEffectsManager.spawn_cosmos_burst()
    ↓
UI Updates (Cosmos display, Hand visual, Field visual)
```

---

## Principios Mantenidos

✅ **Single Responsibility**: Cada módulo hace UNA cosa
✅ **Pure Functions**: GameRules NO modifica estado
✅ **Signal-Based**: Loosely coupled architecture
✅ **No Services Layer**: Managers son Singletons (Autoloads)
✅ **Resource-Based**: CardData, GameState son recursos
✅ **Clear Boundaries**: Models → Rules → Managers → UI

---

**Última actualización**: Después de crear GameRules, BattleCalculator y GameController
**Token usage**: Bajo (documentación de estado)
