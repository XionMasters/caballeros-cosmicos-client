# Card Drop Validation System

## Overview
El sistema de validación permite agregar reglas personalizadas a cada drop zone para controlar qué cartas pueden ser soltadas en cada una.

## Architecture

### CardDropValidator.gd
Clase utility que proporciona:
- Sistema de validación por zona
- Validadores predefinidos
- Combinación de validadores (AND/OR logic)

## Validadores Disponibles

### 1. validator_by_rarity()
Permite solo cartas de cierta rareza
```gdscript
validator.add_rule("Zona Elite", validator.validator_by_rarity(["legendary", "epic"]))
```

### 2. validator_by_type()
Permite solo cartas de cierto tipo
```gdscript
# Solo caballeros
validator.add_rule("Zona Criaturas", validator.validator_by_type(["knight"]))

# Solo técnicas
validator.add_rule("Zona Hechizos", validator.validator_by_type(["technique"]))
```

### 3. validator_by_max_cost()
Permite solo cartas hasta cierto costo
```gdscript
# Costo máximo 3
validator.add_rule("Zona Económica", validator.validator_by_max_cost(3))
```

### 4. validator_by_element()
Permite solo cartas de cierto elemento
```gdscript
# Solo fuego
validator.add_rule("Zona Fuego", validator.validator_by_element(["fire"]))

# Múltiples elementos
validator.add_rule("Zona Agua/Hielo", validator.validator_by_element(["water", "ice"]))
```

### 5. validator_max_cards()
Limita cantidad de cartas en una zona
```gdscript
var zone_container = drop_zone_containers["Zona 1"]
var count_checker = func() -> int:
    return zone_container.get_child_count()

validator.add_rule("Zona 1", validator.validator_max_cards(3, count_checker))
```

## Combinadores

### AND Logic (Todas las condiciones deben cumplirse)
```gdscript
var type_check = validator.validator_by_type(["knight"])
var cost_check = validator.validator_by_max_cost(5)

var combined = validator.validator_and([type_check, cost_check])
validator.add_rule("Zona Caballeros Económicos", combined)
```

### OR Logic (Al menos una condición debe cumplirse)
```gdscript
var fire = validator.validator_by_element(["fire"])
var water = validator.validator_by_element(["water"])

var combined = validator.validator_or([fire, water])
validator.add_rule("Zona Calor/Agua", combined)
```

## Preset Configurations

### setup_creature_zone()
Solo cartas de tipo "knight"
```gdscript
validator.setup_creature_zone("Zona 1")
```

### setup_spell_zone()
Solo técnicas, máximo 3
```gdscript
validator.setup_spell_zone("Zona 2", zone_container)
```

### setup_low_cost_zone()
Solo cartas de costo <= 3
```gdscript
validator.setup_low_cost_zone("Zona Económica")
```

### setup_element_zone()
Solo cartas de elemento específico
```gdscript
validator.setup_element_zone("Zona Fuego", "fire")
```

## TestBoard Current Configuration

En TestBoard, se configura así:

```gdscript
func _setup_drop_zone_validation() -> void:
    # Zona 1: Solo "knight" type cards
    validator.setup_creature_zone("Zona 1")
    
    # Zona 2: Solo cartas con costo <= 2
    validator.add_rule("Zona 2", validator.validator_by_max_cost(2))
    
    # Zona 3: Permite todas
    # (no hay rule = default ALLOW_ALL)
```

## Custom Validators

Para crear validadores personalizados:

```gdscript
# Ejemplo: Solo cartas con nombre que empiece con "Test"
var custom_validator = func(card: Card) -> bool:
    return card.card_data.name.begins_with("Test")

validator.add_rule("Zona Custom", custom_validator)
```

## Drop Validation Flow

```
Usuario arrastra carta X
Usuario suelta en Zona Y
↓
TestBoard._on_card_dropped(card_x, "Zona Y")
↓
validator.can_drop_card(card_x, "Zona Y")
↓
Si hay regla: ejecutar rule function
Si no hay regla: permitir (ALLOW_ALL)
↓
Retorna true → Carta se mueve
Retorna false → Drop rechazado, mensaje de error
```

## Visual Feedback

Cuando un drop es rechazado:
- Status label muestra: `❌ [Nombre] no puede ir a [Zona]`
- Console muestra: `[TEST] Drop rechazado: ...`
- Carta vuelve a posición original

Cuando un drop es aceptado:
- Status label muestra: `✓ Dropped in [Zona]: [Nombre]`
- Carta se mueve al contenedor de zona
- Console muestra: `[TEST] Card dropped in [Zona]: [Nombre]`

## Testing Scenarios

### Scenario 1: Knight-only Zone
```
Crear 5 cartas (todas knight por defecto)
Arrastrar carta 1 a Zona 1 → ✓ Permite
Resultado: Zona 1 contiene carta 1
```

### Scenario 2: Low Cost Zone
```
Crear cartas con costo 1, 2, 3, 4, 5
Arrastrar carta costo 2 a Zona 2 → ✓ Permite
Arrastrar carta costo 5 a Zona 2 → ❌ Rechaza
Resultado: Solo cartas <=2 en Zona 2
```

### Scenario 3: Free Zone
```
Arrastrar cualquier carta a Zona 3 → ✓ Permite siempre
Resultado: Zona 3 acepta todas
```

## Extensión a GameBoard

Para aplicar al GameBoard:

```gdscript
# En GameBoard._ready():
var validator = CardDropValidator.new()

# Configurar cada slot con reglas
validator.setup_creature_zone("field_knight_1")
validator.setup_creature_zone("field_knight_2")
# ... etc

# En la lógica de drop:
if validator.can_drop_card(card, target_zone):
    move_card_to_zone(card, target_zone)
else:
    show_error_feedback(card, target_zone)
```

## Performance

- Validación es O(1) para una regla
- Combinadores AND/OR son O(n) donde n = número de validadores
- Sin impacto measurable en fps

## Future Enhancements

1. **Condicional por turno**: Solo permitir ciertos tipos en cierto turno
2. **Limitación dinámica**: Cambiar reglas durante partida
3. **Feedback visual**: Resaltar zonas válidas mientras dragging
4. **Combo detection**: Detectar combinaciones de cartas
5. **Audio feedback**: Sonido diferente para accept/reject

---

**Status**: Sistema de validación completado  
**Próximo**: Integración en GameBoard  
**Complejidad**: Baja (fácil extender)
