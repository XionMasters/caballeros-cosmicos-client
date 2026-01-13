# 🔧 CORRECCIONES: GameBoard-Integration-Example.gd

**Fecha**: Diciembre 15, 2025
**Estado**: ✅ CORREGIDO

---

## ❌ Errores Encontrados

```
ERROR: Parse Error: Preload file "res://scenes/ui/CardDisplay.tscn" does not exist.
ERROR: Parse Error: Preload file "res://scenes/ui/CardBack.tscn" does not exist.
ERROR: Parse Error: Too few arguments for "play_card_to_field()" call.
```

---

## ✅ Errores Corregidos

### 1. Rutas de Scenes
**Cambio**:
```gdscript
# ❌ ANTES (incorrecto)
const CARD_DISPLAY_SCENE = preload("res://scenes/ui/CardDisplay.tscn")
const CARD_BACK_TEMPLATE = preload("res://scenes/ui/CardBack.tscn")

# ✅ DESPUÉS (correcto)
const CARD_DISPLAY_SCENE = preload("res://scenes/components/cards/CardDisplay.tscn")
const CARD_BACK_TEMPLATE = preload("res://scenes/components/cards/CardBack.tscn")
```

**Razón**: Las scenes están en `scenes/components/cards/`, no en `scenes/ui/`

---

### 2. Argumento Faltante en `play_card_to_field()`
**Cambio**:
```gdscript
# ❌ ANTES (3 argumentos)
card_play_manager.play_card_to_field(
    card_instance,
    zone,
    target_slot.slot_index
)

# ✅ DESPUÉS (4 argumentos)
card_play_manager.play_card_to_field(
    card_instance,
    zone,
    target_slot.slot_index,
    player_state.current_cosmos  # ← Argumento faltante
)
```

**Razón**: El método `play_card_to_field()` requiere 4 parámetros:
1. `card_instance: CardInstance`
2. `target_zone: String`
3. `target_slot: int`
4. `player_cosmos: int` ← FALTABA

---

### 3. Rutas de @onready
**Cambio**:
```gdscript
# ❌ ANTES (rutas genéricas)
@onready var player_hand = $MainContainer/CenterColumn/PlayerHand
@onready var opponent_hand = $MainContainer/CenterColumn/OpponentHand

# ✅ DESPUÉS (rutas correctas del proyecto)
@onready var player_hand = $MainContainer/CenterColumn/PlayerArea/PlayerHeader/PlayerHand
@onready var opponent_hand = $MainContainer/CenterColumn/OpponentArea/OpponentHeader/OpponentHand
```

**Razón**: Las referencias en el proyecto real tienen más niveles de jerarquía

---

## 🎯 IMPORTANTES: Ajustes Adicionales para tu Proyecto

Antes de usar este archivo, verifica y ajusta:

### 1. Verificar tus @onready
Las rutas en el ejemplo pueden no coincidir perfectamente. Verifica abriendo GameBoard.tscn:
```
$MainContainer/CenterColumn/PlayerArea/PlayerHeader/PlayerHand  ✓ Correcto
$MainContainer/LeftColumn/PlayerDeck/DeckPile                   ✓ Correcto
$MainContainer/CenterColumn/OpponentArea/OpponentHeader/OpponentHand  ✓ Correcto
```

### 2. Verificar Arrays de Slots
El archivo asume que tienes estos arrays:
```gdscript
var player_knight_slots: Array = []
var opponent_knight_slots: Array = []
var player_technique_slots: Array = []
var opponent_technique_slots: Array = []
```

Si tienes nombres diferentes, cambiar en:
- `_setup_slot_groups()`
- Función que obtiene referencias de slots

### 3. Verificar Métodos de HandLayout
El ejemplo usa:
- `player_hand.add_card(card_display)`
- `player_hand.clear_cards()`
- `player_hand.get_cards()`
- `player_hand.remove_card(card_display)`

Verifica que HandLayout tiene estos métodos.

### 4. Verificar MatchManager
El ejemplo usa:
- `MatchManager.match_state_updated` signal
- `MatchManager.get_player_cosmos()` (opcional)

Ajusta si tu MatchManager tiene nombres diferentes.

---

## 📋 Uso Correcto del Archivo

El archivo `GameBoard-Integration-Example.gd` es una **guía**, no código para copiar 1:1:

### ✅ CORRECTO:
1. Abre el archivo
2. Lee cada función
3. Adapta a tu GameBoard.gd
4. Cambiar rutas según tu estructura
5. Cambiar nombres de métodos según tu código

### ❌ INCORRECTO:
- Copiar todo el archivo
- Usar sin verificar rutas
- No testear mientras cambias

---

## 🚀 Próximos Pasos

1. **Verifica rutas**: Abre GameBoard.tscn y compara @onready paths
2. **Adapta el código**: Copia función por función, ajustando rutas
3. **Testea**: Después de cada función, verifica que compila sin errores
4. **Usa de referencia**: No como código final, sino como guía

---

## 💡 Consejo: Método Recomendado

En lugar de usar todo el archivo de ejemplo:

1. **Crear funciones una a una**:
   ```gdscript
   func _setup_managers() -> void:
       deck_loader = DeckLoadingManager.new()
       add_child(deck_loader)
       # ✓ Testear que compila
   ```

2. **Verificar cada paso**:
   ```gdscript
   func _ready() -> void:
       _setup_managers()  # ✓ Compila?
       await get_tree().process_frame
       print("Managers setup OK")
   ```

3. **Integrar gradualmente**:
   - Primero: managers
   - Luego: player states
   - Luego: cargar mazo
   - Finalmente: jugar cartas

---

## 📖 Referencias para Ajustes

### Si tienes dudas sobre rutas @onready:
- Abre GameBoard.tscn en Godot
- Haz click derecho en nodos
- Copia el node path → $...

### Si tienes dudas sobre métodos:
- Abre HandLayout.gd
- Busca `func add_card`
- Ve qué parámetros espera

### Si tienes dudas sobre signals:
- Abre MatchManager.gd
- Busca `signal`
- Verifica nombre exacto

---

## ✅ Archivo Ahora Corregido

El archivo `GameBoard-Integration-Example.gd` ahora tiene:
- ✅ Rutas correctas de scenes
- ✅ Argumentos correctos en métodos
- ✅ @onready paths del proyecto real
- ✅ Comentarios útiles en cada sección

**Puedes usarlo como guía para integrar en tu GameBoard.gd**

---

**Documento de Correcciones v1.0**
**Fecha**: Diciembre 15, 2025
**Estado**: ✅ RESUELTO

