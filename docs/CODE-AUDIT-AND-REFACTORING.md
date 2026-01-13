# CÓDIGO AUDIT Y REFACTORIZACIÓN
# Documento de mapeo de duplicaciones y mejoras identificadas en el proyecto
# Creado: Diciembre 15, 2025

## 📋 RESUMEN DE DUPLICACIONES ENCONTRADAS

### 1. **Sistema de Carga de Mazo** ✅ YA REFACTORIZADO
**Archivos afectados**: TestBoard.gd, GameBoard.gd
**Problema**: Mismo código ~200 líneas duplicado
**Solución**: `DeckLoadingManager.gd` (Genérico reutilizable)
**Estado**: COMPLETADO

### 2. **Validación de Costos de Cartas** ✅ CREADO
**Archivos afectados**: GameBoard, TestBoard, HandLayout
**Problema**: Sin validación centralizada de costos
**Solución**: `CardCostValidator.gd` (Genérico reutilizable)
**Estado**: COMPLETADO

### 3. **Lógica de Jugar Cartas** ✅ CREADO
**Archivos afectados**: GameBoard.gd
**Problema**: Lógica de juego mezclada con UI
**Solución**: `CardPlayManager.gd` (Gestor genérico)
**Estado**: COMPLETADO

### 4. **Estado del Jugador** ✅ CREADO
**Archivos afectados**: GameBoard.gd (sin centralizar actualmente)
**Problema**: Estado distribuido en múltiples variables
**Solución**: `PlayerState.gd` (Modelo genérico)
**Estado**: COMPLETADO

---

## 🔍 DUPLICACIONES SECUNDARIAS A RESOLVER

### 5. **Setup de CardDisplay**
**Ubicación**: GameBoard.gd líneas ~400-450
**Código duplicado en**: TestBoard.gd líneas ~320-360
**Duplicación**: ~50 líneas de setup de carta
```gdscript
# Ambos hacen esto:
var card_display = CARD_DISPLAY_SCENE.instantiate()
card_display.setup_from_instance(card_instance)
var card_back = CARD_BACK_TEMPLATE.instantiate()
card_display.add_child(card_back)
player_hand.add_card(card_display)
await get_tree().process_frame
card_display.animate_flip_from_deck(deck_global_pos, 0.6)
```
**Solución propuesta**: `CardDisplayFactory` o método genérico en HandLayout

### 6. **Animaciones de Cartas**
**Ubicación**: CardDisplay.gd (animate_flip_from_deck, animate_from_position, etc)
**Problema**: Lógica de animación mezclada con lógica de estado
**Solución propuesta**: `CardAnimationManager` (clase separada)

### 7. **Gestión de Slots**
**Ubicación**: GameBoard.gd (player_knight_slots, opponent_knight_slots, etc)
**Problema**: Arrays manuales para cada tipo de slot
**Solución propuesta**: Sistema genérico de "Slot Groups"

### 8. **Conexión de Señales**
**Ubicación**: GameBoard.gd `_connect_all_slots()` (50 líneas)
**Problema**: Mucho código repetitivo para conectar señales
**Solución propuesta**: Bucles automáticos sobre arrays de slots

### 9. **Validación de Drop Zones**
**Ubicación**: CardDropValidator.gd, CardSlot.gd
**Problema**: Lógica de validación duplicada
**Solución propuesta**: Centralizar en CardDropValidator

### 10. **Actualización de Visuales**
**Ubicación**: GameBoard.gd `render_all_zones()` (70 líneas)
**Problema**: Mucho código de renderizado manual
**Solución propuesta**: Sistema de "Renderer" genérico

---

## 🎯 PRIORIZACI Ó́N DE MEJORAS

### ALTA PRIORIDAD (Impacto máximo, Esfuerzo bajo)
1. ✅ CardCostValidator - DONE
2. ✅ PlayerState - DONE
3. ✅ CardPlayManager - DONE
4. CardDisplayFactory - Eliminaría 40 líneas duplicadas
5. Automático slot connection - Eliminaría 50 líneas

### MEDIA PRIORIDAD (Impacto alto, Esfuerzo medio)
6. CardAnimationManager - Separar lógica de animación
7. Unified Slot System - Reemplazar arrays manuales
8. Generic Renderer - Simplificar render_all_zones()

### BAJA PRIORIDAD (Mejoras de arquitectura)
9. Component-Based CardDisplay - Fase 2+
10. Plugin System - Fases posteriores

---

## 📊 IMPACTO DE REFACTORIZACIÓN

### Antes (Actual)
- GameBoard.gd: 1000+ líneas
- TestBoard.gd: 500+ líneas
- CardDisplay.gd: 600+ líneas
- Mucho código duplicado
- Difícil de mantener
- Difícil de testear

### Después (Con las mejoras)
- GameBoard.gd: ~700 líneas (delegación a managers)
- TestBoard.gd: ~200 líneas (solo UI)
- CardDisplay.gd: ~400 líneas (visual + input)
- CardPlayManager: ~150 líneas
- CardCostValidator: ~100 líneas
- PlayerState: ~150 líneas
- DeckLoadingManager: ~150 líneas
- Cada componente tiene responsabilidad única
- Fácil de testear y mantener
- Reutilizable en otros proyectos

---

## 🔧 PRÓXIMAS ACCIONES

### Ahora (Completado)
- [x] Crear DeckLoadingManager genérico
- [x] Crear CardCostValidator genérico
- [x] Crear CardPlayManager genérico
- [x] Crear PlayerState genérico

### Siguiente sesión
- [ ] CardDisplayFactory para setup de cartas
- [ ] Refactorizar _connect_all_slots() con bucles automáticos
- [ ] CardAnimationManager para separar lógica de animación
- [ ] Unified Slot System

---

## 📝 NOTAS DE IMPLEMENTACIÓN

### CardCostValidator
```gdscript
# Uso:
validator = CardCostValidator.new()
if validator.can_afford_card(card_instance):
    validator.play_card(card_instance)
```

### CardPlayManager
```gdscript
# Uso:
play_manager = CardPlayManager.new()
play_manager.card_played.connect(_on_card_played)
play_manager.play_card_from_hand(card_display, "field_knight", 0)
```

### PlayerState
```gdscript
# Uso:
player_state = PlayerState.new("player-id", 1)
player_state.cosmos_changed.connect(_on_cosmos_changed)
player_state.add_cosmos(5)
player_state.subtract_cosmos(3)
```

---

## ✅ CHECKLIST DE INTEGRACIÓN

- [ ] Integrar PlayerState en GameBoard._initialize_match()
- [ ] Integrar CardPlayManager en GameBoard cuando se juega carta
- [ ] Conectar PlayerState.cosmos_changed con UI de cosmos
- [ ] Conectar CardPlayManager.card_played con MatchManager
- [ ] Validar que CardCostValidator funciona correctamente
- [ ] Testear flujo completo: seleccionar carta → validar costo → jugar
- [ ] Testear animación de cartas sigue funcionando
- [ ] Testear actualización de cosmos en UI

---

**Archivo generado por: Análisis de código automático**
**Fecha**: Diciembre 15, 2025
**Versión**: 1.0

