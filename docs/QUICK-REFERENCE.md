# 📌 Quick Reference - Métodos por Módulo

## GameRules - Validación

| Método | Input | Output | Propósito |
|--------|-------|--------|-----------|
| `can_play_card()` | card, cosmos | bool | ¿Puedo jugar esta carta? |
| `can_place_card()` | card, zone, state, player | bool | ¿Puedo colocar en esta zona? |
| `can_declare_attack()` | attacker, state | bool | ¿Puedo atacar con este knight? |
| `can_use_technique()` | technique, activator, state | bool | ¿Puedo usar esta técnica? |
| `can_use_knight_action()` | action, knight, state | bool | ¿Puedo ejecutar esta acción? |
| `can_perform_action_in_phase()` | phase, action | bool | ¿Esta acción es válida en esta fase? |

---

## BattleCalculator - Cálculos

| Método | Input | Output | Propósito |
|--------|-------|--------|-----------|
| `calculate_damage()` | attacker, defender, type | int | Daño de ataque |
| `apply_technique_effect()` | technique, activator, target | Dict | Efectos de técnica |
| `is_knight_defeated()` | knight | bool | ¿Knight muerto? |
| `is_player_defeated()` | life | bool | ¿Player derrotado? |
| `get_lethal_damage()` | target_hp | int | Daño para matar |
| `get_damage_type()` | card | String | Tipo de daño |
| `get_defense_effectiveness()` | attack_type, defender_element | float | Multiplicador |

---

## GameController - Orquestación

| Método | Input | Output | Propósito |
|--------|-------|--------|-----------|
| `play_card()` | card, zone, position | bool | Jugar carta desde mano |
| `declare_attack()` | attacker_id, defender_id | bool | Atacar |
| `use_technique()` | technique_id, activator_id, targets | bool | Usar técnica |
| `execute_knight_action()` | knight_id, action, data | bool | Acción especial |
| `end_turn()` | - | bool | Cambiar turno |
| `set_game_state()` | state | void | Configurar GameState |

**Signals emitidos**:
- `card_played(card, zone, position)`
- `attack_declared(attacker_id, defender_id, damage)`
- `technique_used(technique_id, activator_id, targets)`
- `knight_action_executed(knight_id, action_type)`
- `player_took_damage(player, damage)`
- `player_life_updated(player, life)`
- `phase_changed(phase, player)`

---

## HandManager - Gestión de Mano

### Modificación
| Método | Input | Output | Propósito |
|--------|-------|--------|-----------|
| `add_card_to_hand()` | card, player | bool | Agregar carta |
| `remove_card_from_hand()` | card_id, player | CardInstance | Quitar carta |
| `clear_hand()` | player | Array | Limpiar mano |

### Búsqueda
| Método | Input | Output | Propósito |
|--------|-------|--------|-----------|
| `get_playable_cards()` | player, cosmos | Array | Cartas jugables |
| `get_cards_by_type()` | player, type | Array | Por tipo |
| `get_cards_by_rarity()` | player, rarity | Array | Por rareza |
| `get_cards_by_cost()` | player, cost | Array | Por costo exacto |
| `get_lowest_cost_card()` | player | CardInstance | Más barata |
| `get_highest_cost_card()` | player | CardInstance | Más cara |
| `get_card_by_id()` | card_id, player | CardInstance | Por ID |
| `get_card_position_in_hand()` | card_id, player | int | Posición (0-9) |
| `contains_card()` | card_id, player | bool | ¿Existe? |

### Información
| Método | Input | Output | Propósito |
|--------|-------|--------|-----------|
| `get_cards_in_hand()` | player | Array | Todas cartas |
| `get_hand_size()` | player | int | Cantidad |
| `get_empty_hand_slots()` | player | int | Espacios libres |
| `get_hand_limit()` | - | int | 10 (límite) |
| `is_hand_full()` | player | bool | ¿Llena? |
| `is_hand_empty()` | player | bool | ¿Vacía? |

### Ordenamiento
| Método | Input | Output | Propósito |
|--------|-------|--------|-----------|
| `sort_hand_by_cost()` | player, ascending | void | Por costo |
| `sort_hand_by_type()` | player | void | Por tipo |

**Signals emitidos**:
- `card_added_to_hand(card, player)`
- `card_removed_from_hand(card, player)`
- `hand_updated(player, count)`
- `hand_limit_reached(player)`

---

## FieldManager - Gestión de Campo

### Modificación
| Método | Input | Output | Propósito |
|--------|-------|--------|-----------|
| `place_card_on_field()` | card, zone, position, player | bool | Colocar |
| `remove_card_from_field()` | card_id, zone, player | CardInstance | Quitar |
| `clear_zone()` | zone, player | Array | Limpiar zona |
| `clear_all_field()` | player | void | Limpiar todo |

### Búsqueda General
| Método | Input | Output | Propósito |
|--------|-------|--------|-----------|
| `get_card_by_id()` | card_id, player | CardInstance | Buscar por ID |
| `get_card_zone()` | card_id, player | String | ¿En qué zona? |
| `card_exists_on_field()` | card_id, player | bool | ¿Existe? |

### Knights
| Método | Input | Output | Propósito |
|--------|-------|--------|-----------|
| `get_knights_on_field()` | player | Array | Todos |
| `get_active_knights()` | player | Array | Sin exhausted |
| `get_exhausted_knights()` | player | Array | Con exhausted |
| `get_knight_count()` | player | int | Cantidad |
| `can_place_knight()` | player | bool | ¿Hay espacio? |

### Techniques
| Método | Input | Output | Propósito |
|--------|-------|--------|-----------|
| `get_techniques_on_field()` | player | Array | Todas |
| `get_compatible_techniques()` | knight, player | Array | Compatible con knight |
| `get_technique_count()` | player | int | Cantidad |
| `can_place_technique()` | player | bool | ¿Hay espacio? |

### Helper & Scenario
| Método | Input | Output | Propósito |
|--------|-------|--------|-----------|
| `get_helper_card()` | player | CardInstance | Helper (o null) |
| `has_helper()` | player | bool | ¿Hay helper? |
| `get_scenario_card()` | player | CardInstance | Scenario (o null) |
| `has_scenario()` | player | bool | ¿Hay scenario? |

### Información Zona
| Método | Input | Output | Propósito |
|--------|-------|--------|-----------|
| `get_cards_in_zone()` | zone, player | Array | Cartas en zona |
| `get_zone_size()` | zone, player | int | Cantidad en zona |
| `get_zone_limit()` | zone | int | Límite de zona |
| `get_empty_slots()` | zone, player | int | Espacios libres |
| `get_available_positions()` | zone, player | Array | Índices libres |

### Validación
| Método | Input | Output | Propósito |
|--------|-------|--------|-----------|
| `can_place_in_zone()` | zone, player | bool | ¿Hay espacio? |
| `is_zone_full()` | zone, player | bool | ¿Llena? |
| `is_zone_empty()` | zone, player | bool | ¿Vacía? |

**Signals emitidos**:
- `card_placed_on_field(card, zone, position, player)`
- `card_removed_from_field(card, zone, position, player)`
- `field_updated(zone, player, count)`
- `zone_full(zone, player)`

**Límites por zona**:
- `field_knight`: 5
- `field_technique`: 5
- `field_helper`: 1
- `field_scenario`: 1

---

## GameState - Lectura (Ya existía)

| Método | Input | Output | Propósito |
|--------|-------|--------|-----------|
| `get_hand_for_player()` | player | Array | Mano |
| `get_cards_in_zone()` | zone, player | Array | Cartas en zona |
| `get_player_cosmos()` | player | int | Cosmos |
| `get_player_life()` | player | int | Vida |
| `get_card_by_instance_id()` | id | CardInstance | Buscar carta |
| `get_player_of_card()` | card_id | int | ¿De quién es? |

---

## Patrón de Uso Típico

### Para Cada Acción del Jugador:

1. **Validar** con GameRules
```gdscript
if not game_rules.can_play_card(card, cosmos):
    return false  # No se puede
```

2. **Ejecutar** con GameController O Managers
```gdscript
game_controller.play_card(card, zone, position)  # Opción 1: orquestador
# O
hand_manager.remove_card_from_hand(card_id, player)
field_manager.place_card_on_field(card, zone, position, player)  # Opción 2: directo
```

3. **Escuchar** signals en GameBoard
```gdscript
game_controller.card_played.connect(_on_card_played)

func _on_card_played(card, zone, position):
    # Animar, mostrar efectos, actualizar UI
    CardAnimationManager.animate_card_play(card)
```

---

## Atajos Comunes

### "¿Puedo jugar esta carta?"
```gdscript
game_rules.can_play_card(card, current_cosmos)
```

### "Jugar la carta"
```gdscript
game_controller.play_card(card, "field_knight", empty_position)
```

### "¿Qué cartas puedo jugar?"
```gdscript
hand_manager.get_playable_cards(player, current_cosmos)
```

### "¿Cuántas cartas tengo?"
```gdscript
hand_manager.get_hand_size(player)
```

### "¿Hay espacio para otro knight?"
```gdscript
field_manager.can_place_knight(player)
```

### "¿Qué knights tengo en campo?"
```gdscript
field_manager.get_knights_on_field(player)
```

### "¿Cuál es mi knight más fuerte?"
```gdscript
var knights = field_manager.get_knights_on_field(player)
var strongest = knights.max_by(func(k): return k.base_data.attack)
```

### "Atacar con este knight"
```gdscript
game_controller.declare_attack(knight_id, opponent_knight_id)
```

### "Terminar mi turno"
```gdscript
game_controller.end_turn()
```

---

## Constantes

| Constante | Valor | Módulo |
|-----------|-------|--------|
| `HAND_LIMIT` | 10 | HandManager |
| `ZONE_LIMITS["field_knight"]` | 5 | FieldManager |
| `ZONE_LIMITS["field_technique"]` | 5 | FieldManager |
| `ZONE_LIMITS["field_helper"]` | 1 | FieldManager |
| `ZONE_LIMITS["field_scenario"]` | 1 | FieldManager |

---

## Estados Posibles

### Fases (current_phase)
- `"draw"` - Fase de robar
- `"main"` - Fase principal (jugar cartas)
- `"battle"` - Fase de batalla
- `"end"` - Fin de turno

### Modos de Knight (knight.mode)
- `"normal"` - Normal
- `"defense"` - Modo defensa (reduce daño)
- `"evasion"` - Modo evasión (50% miss en BA)

### Zonas
- `"hand"` - En mano
- `"field_knight"` - Knights en campo
- `"field_technique"` - Técnicas activadas
- `"field_helper"` - Helper (apoyo)
- `"field_scenario"` - Scenario (escenario)
- `"graveyard"` - Descartadas
- `"exile"` - Exiliadas

---

## Documentación Completa

Para más detalles, consulta:
- `INTEGRATION-QUICK-START.md` - Ejemplos prácticos
- `MODULES-INDEX.md` - Descripción completa
- `ARCHITECTURE-MODULES-README.md` - Guía general

---

**Imprime esto o mantenlo abierto mientras codificas**  
**Last updated**: Después de crear GameRules, BattleCalculator, GameController, HandManager, FieldManager  

