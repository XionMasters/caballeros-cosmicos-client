# 🎮 GameBoard Structure Guide - Reconstruir TestBoard con Zonas de Juego

**Fecha:** 24 Diciembre 2025  
**Objetivo:** Agregar zonas de campo (knights, techs, helper, occasion, scenario) a TestBoard

---

## 📋 Resumen

TestBoard actualmente solo tiene:
- ✅ Manos (player + opponent)
- ✅ Mazos (player + opponent)  
- ✅ UI básico (turn, phase, stats)

TestBoard necesita:
- ❌ Slots de caballeros (5 por jugador)
- ❌ Slots de técnicas (5 por jugador)
- ❌ Slot de ayudante (1 por jugador)
- ❌ Slot de ocasión (1 por jugador)
- ❌ Slot de escenario (compartido)

---

## 🏗️ Estructura de Zonas

### GameBoard.tscn (REFERENCIA)
La escena GameBoard.tscn tiene la estructura correcta:

```
MainContainer (HBox)
├── LeftColumn (VBox)
│   ├── OpponentDeck
│   ├── Spacer
│   └── PlayerDeck
├── CenterColumn (VBox)
│   ├── OpponentArea (VBox)
│   │   ├── OpponentHeader
│   │   │   ├── OpponentAvatar
│   │   │   └── OpponentHand (HandLayout)
│   │   ├── KnightsRow (HBox) ← 5 slots + occasion
│   │   │   ├── Knight1-5 (Panel + CardSlot)
│   │   │   └── OccasionSlot
│   │   └── TechRow (HBox) ← 5 slots + helper
│   │       ├── Tech1-5 (Panel + CardSlot)
│   │       └── HelperSlot
│   └── PlayerArea (VBox)
│       ├── TechRow (HBox) ← 5 slots + helper (ARRIBA)
│       │   ├── Tech1-5
│       │   └── HelperSlot
│       ├── KnightsRow (HBox) ← 5 slots + occasion (ABAJO)
│       │   ├── Knight1-5
│       │   └── OccasionSlot
│       └── PlayerHeader
│           ├── PlayerAvatar
│           └── PlayerHand
└── RightColumn (VBox)
    ├── OpponentPiles (Yomotsu/Cositos)
    ├── ScenarioSlot (compartido)
    └── PlayerPiles (Yomotsu/Cositos)
```

### TestBoard.tscn (ACTUAL - NECESITA EXPANSIÓN)
```
MainContainer (HBox)
├── LeftColumn (VBox)
│   ├── OpponentDeck
│   ├── Spacer
│   └── PlayerDeck
├── CenterColumn (VBox)
│   ├── OpponentArea (VBox)
│   │   ├── OpponentHeader
│   │   │   └── OpponentHand
│   │   ❌ FALTAN KnightsRow y TechRow
│   └── PlayerArea (VBox)
│       ├── PlayerHeader
│       │   └── PlayerHand
│       ❌ FALTAN KnightsRow y TechRow
└── RightColumn (VBox) ❌ FALTA COMPLETAMENTE
    └── ScenarioSlot + Piles
```

---

## 🔧 Pasos para Actualizar TestBoard.tscn

### Paso 1: Descargar/Copiar from GameBoard.tscn

La forma más fácil es copiar la estructura de GameBoard.tscn:

```bash
1. Abrir GameBoard.tscn en Godot
2. Copiar MainContainer completo
3. En TestBoard.tscn, reemplazar MainContainer con el copiado
4. Guardar
```

O hacer manualmente siguiendo pasos 2-5 abajo.

### Paso 2: Agregar OpponentArea.KnightsRow

En `MainContainer/CenterColumn/OpponentArea`, **después de OpponentHeader**, agregar:

```
[node name="KnightsRow" type="HBoxContainer" parent="MainContainer/CenterColumn/OpponentArea"]
layout_mode = 2
size_flags_vertical = 3
theme_override_constants/separation = 5

[node name="Knight1" type="Panel" parent="MainContainer/CenterColumn/OpponentArea/KnightsRow"]
custom_minimum_size = Vector2(80, 120)
layout_mode = 2
size_flags_horizontal = 3
script = ExtResource("2_slot")  # CardSlot.gd
is_opponent = true

[node name="Knight2" type="Panel" parent="MainContainer/CenterColumn/OpponentArea/KnightsRow"]
custom_minimum_size = Vector2(80, 120)
layout_mode = 2
size_flags_horizontal = 3
script = ExtResource("2_slot")
slot_index = 1
is_opponent = true

[node name="Knight3" type="Panel" parent="MainContainer/CenterColumn/OpponentArea/KnightsRow"]
custom_minimum_size = Vector2(80, 120)
layout_mode = 2
size_flags_horizontal = 3
script = ExtResource("2_slot")
slot_index = 2
is_opponent = true

[node name="Knight4" type="Panel" parent="MainContainer/CenterColumn/OpponentArea/KnightsRow"]
custom_minimum_size = Vector2(80, 120)
layout_mode = 2
size_flags_horizontal = 3
script = ExtResource("2_slot")
slot_index = 3
is_opponent = true

[node name="Knight5" type="Panel" parent="MainContainer/CenterColumn/OpponentArea/KnightsRow"]
custom_minimum_size = Vector2(80, 120)
layout_mode = 2
size_flags_horizontal = 3
script = ExtResource("2_slot")
slot_index = 4
is_opponent = true

[node name="OccasionSlot" type="Panel" parent="MainContainer/CenterColumn/OpponentArea/KnightsRow"]
custom_minimum_size = Vector2(60, 90)
layout_mode = 2
tooltip_text = "Ocasión"
script = ExtResource("2_slot")
slot_type = 4  # OCASIÓN
is_opponent = true
```

### Paso 3: Agregar OpponentArea.TechRow

En `MainContainer/CenterColumn/OpponentArea`, **después de KnightsRow**, agregar:

```
[node name="TechRow" type="HBoxContainer" parent="MainContainer/CenterColumn/OpponentArea"]
layout_mode = 2
size_flags_vertical = 3
theme_override_constants/separation = 5

[node name="Tech1" type="Panel" parent="MainContainer/CenterColumn/OpponentArea/TechRow"]
custom_minimum_size = Vector2(80, 120)
layout_mode = 2
size_flags_horizontal = 3
script = ExtResource("2_slot")
slot_type = 1  # TÉCNICA
is_opponent = true

[node name="Tech2" type="Panel" parent="MainContainer/CenterColumn/OpponentArea/TechRow"]
custom_minimum_size = Vector2(80, 120)
layout_mode = 2
size_flags_horizontal = 3
script = ExtResource("2_slot")
slot_type = 1
slot_index = 1
is_opponent = true

[node name="Tech3" type="Panel" parent="MainContainer/CenterColumn/OpponentArea/TechRow"]
custom_minimum_size = Vector2(80, 120)
layout_mode = 2
size_flags_horizontal = 3
script = ExtResource("2_slot")
slot_type = 1
slot_index = 2
is_opponent = true

[node name="Tech4" type="Panel" parent="MainContainer/CenterColumn/OpponentArea/TechRow"]
custom_minimum_size = Vector2(80, 120)
layout_mode = 2
size_flags_horizontal = 3
script = ExtResource("2_slot")
slot_type = 1
slot_index = 3
is_opponent = true

[node name="Tech5" type="Panel" parent="MainContainer/CenterColumn/OpponentArea/TechRow"]
custom_minimum_size = Vector2(80, 120)
layout_mode = 2
size_flags_horizontal = 3
script = ExtResource("2_slot")
slot_type = 1
slot_index = 4
is_opponent = true

[node name="HelperSlot" type="Panel" parent="MainContainer/CenterColumn/OpponentArea/TechRow"]
custom_minimum_size = Vector2(60, 90)
layout_mode = 2
tooltip_text = "Ayudante"
script = ExtResource("2_slot")
slot_type = 2  # AYUDANTE
is_opponent = true
```

### Paso 4: Agregar PlayerArea.TechRow (ARRIBA de PlayerHeader)

En `MainContainer/CenterColumn/PlayerArea`, **ANTES de PlayerHeader**, agregar:

```
[node name="TechRow" type="HBoxContainer" parent="MainContainer/CenterColumn/PlayerArea"]
layout_mode = 2
size_flags_vertical = 3
theme_override_constants/separation = 5

[node name="Tech1" type="Panel" parent="MainContainer/CenterColumn/PlayerArea/TechRow"]
custom_minimum_size = Vector2(80, 120)
layout_mode = 2
size_flags_horizontal = 3
script = ExtResource("2_slot")
slot_type = 1  # TÉCNICA

[node name="Tech2" type="Panel" parent="MainContainer/CenterColumn/PlayerArea/TechRow"]
custom_minimum_size = Vector2(80, 120)
layout_mode = 2
size_flags_horizontal = 3
script = ExtResource("2_slot")
slot_type = 1
slot_index = 1

[node name="Tech3" type="Panel" parent="MainContainer/CenterColumn/PlayerArea/TechRow"]
custom_minimum_size = Vector2(80, 120)
layout_mode = 2
size_flags_horizontal = 3
script = ExtResource("2_slot")
slot_type = 1
slot_index = 2

[node name="Tech4" type="Panel" parent="MainContainer/CenterColumn/PlayerArea/TechRow"]
custom_minimum_size = Vector2(80, 120)
layout_mode = 2
size_flags_horizontal = 3
script = ExtResource("2_slot")
slot_type = 1
slot_index = 3

[node name="Tech5" type="Panel" parent="MainContainer/CenterColumn/PlayerArea/TechRow"]
custom_minimum_size = Vector2(80, 120)
layout_mode = 2
size_flags_horizontal = 3
script = ExtResource("2_slot")
slot_type = 1
slot_index = 4

[node name="HelperSlot" type="Panel" parent="MainContainer/CenterColumn/PlayerArea/TechRow"]
custom_minimum_size = Vector2(60, 90)
layout_mode = 2
tooltip_text = "Ayudante"
script = ExtResource("2_slot")
slot_type = 2  # AYUDANTE
```

### Paso 5: Agregar PlayerArea.KnightsRow (ABAJO de TechRow)

En `MainContainer/CenterColumn/PlayerArea`, **DESPUÉS de TechRow**, agregar:

```
[node name="KnightsRow" type="HBoxContainer" parent="MainContainer/CenterColumn/PlayerArea"]
layout_mode = 2
size_flags_vertical = 3
theme_override_constants/separation = 5

[node name="Knight1" type="Panel" parent="MainContainer/CenterColumn/PlayerArea/KnightsRow"]
custom_minimum_size = Vector2(80, 120)
layout_mode = 2
size_flags_horizontal = 3
script = ExtResource("2_slot")

[node name="Knight2" type="Panel" parent="MainContainer/CenterColumn/PlayerArea/KnightsRow"]
custom_minimum_size = Vector2(80, 120)
layout_mode = 2
size_flags_horizontal = 3
script = ExtResource("2_slot")
slot_index = 1

[node name="Knight3" type="Panel" parent="MainContainer/CenterColumn/PlayerArea/KnightsRow"]
custom_minimum_size = Vector2(80, 120)
layout_mode = 2
size_flags_horizontal = 3
script = ExtResource("2_slot")
slot_index = 2

[node name="Knight4" type="Panel" parent="MainContainer/CenterColumn/PlayerArea/KnightsRow"]
custom_minimum_size = Vector2(80, 120)
layout_mode = 2
size_flags_horizontal = 3
script = ExtResource("2_slot")
slot_index = 3

[node name="Knight5" type="Panel" parent="MainContainer/CenterColumn/PlayerArea/KnightsRow"]
custom_minimum_size = Vector2(80, 120)
layout_mode = 2
size_flags_horizontal = 3
script = ExtResource("2_slot")
slot_index = 4

[node name="OccasionSlot" type="Panel" parent="MainContainer/CenterColumn/PlayerArea/KnightsRow"]
custom_minimum_size = Vector2(60, 90)
layout_mode = 2
tooltip_text = "Ocasión"
script = ExtResource("2_slot")
slot_type = 4  # OCASIÓN
```

### Paso 6: Agregar RightColumn (ScenarioSlot + Piles)

En la raíz `MainContainer`, **DESPUÉS de CenterColumn**, agregar:

```
[node name="RightColumn" type="VBoxContainer" parent="MainContainer"]
custom_minimum_size = Vector2(150, 0)
layout_mode = 2
theme_override_constants/separation = 10
alignment = 1

[node name="OpponentPiles" type="VBoxContainer" parent="MainContainer/RightColumn"]
layout_mode = 2
size_flags_vertical = 3
theme_override_constants/separation = 5

[node name="YomotsuPile" type="VBoxContainer" parent="MainContainer/RightColumn/OpponentPiles"]
layout_mode = 2
tooltip_text = "Yomotsu (Graveyard)"

[node name="Label" type="Label" parent="MainContainer/RightColumn/OpponentPiles/YomotsuPile"]
text = "Yomotsu"

[node name="Count" type="Label" parent="MainContainer/RightColumn/OpponentPiles/YomotsuPile"]
text = "0"

[node name="CositosPile" type="VBoxContainer" parent="MainContainer/RightColumn/OpponentPiles"]
layout_mode = 2
tooltip_text = "Cositos (Exiled)"

[node name="Label" type="Label" parent="MainContainer/RightColumn/OpponentPiles/CositosPile"]
text = "Cositos"

[node name="Count" type="Label" parent="MainContainer/RightColumn/OpponentPiles/CositosPile"]
text = "0"

[node name="ScenarioContainer" type="CenterContainer" parent="MainContainer/RightColumn"]
layout_mode = 2
size_flags_vertical = 3

[node name="ScenarioSlot" type="Panel" parent="MainContainer/RightColumn/ScenarioContainer"]
custom_minimum_size = Vector2(100, 140)
layout_mode = 2
tooltip_text = "Escenario"
script = ExtResource("2_slot")
slot_type = 3  # ESCENARIO

[node name="PlayerPiles" type="VBoxContainer" parent="MainContainer/RightColumn"]
layout_mode = 2
size_flags_vertical = 3
theme_override_constants/separation = 5

[node name="YomotsuPile" type="VBoxContainer" parent="MainContainer/RightColumn/PlayerPiles"]
layout_mode = 2
tooltip_text = "Yomotsu (Graveyard)"

[node name="Label" type="Label" parent="MainContainer/RightColumn/PlayerPiles/YomotsuPile"]
text = "Yomotsu"

[node name="Count" type="Label" parent="MainContainer/RightColumn/PlayerPiles/YomotsuPile"]
text = "0"

[node name="CositosPile" type="VBoxContainer" parent="MainContainer/RightColumn/PlayerPiles"]
layout_mode = 2
tooltip_text = "Cositos (Exiled)"

[node name="Label" type="Label" parent="MainContainer/RightColumn/PlayerPiles/CositosPile"]
text = "Cositos"

[node name="Count" type="Label" parent="MainContainer/RightColumn/PlayerPiles/CositosPile"]
text = "0"
```

### Paso 7: Agregar las referencias en TestBoard.gd

Reemplazar el comentario TODO con:

```gdscript
# ============================================================================
# REFERENCIAS A NODOS - CAMPOS DE JUEGO
# ============================================================================
@onready var player_knight_slots = [
	$MainContainer/CenterColumn/PlayerArea/KnightsRow/Knight1,
	$MainContainer/CenterColumn/PlayerArea/KnightsRow/Knight2,
	$MainContainer/CenterColumn/PlayerArea/KnightsRow/Knight3,
	$MainContainer/CenterColumn/PlayerArea/KnightsRow/Knight4,
	$MainContainer/CenterColumn/PlayerArea/KnightsRow/Knight5
]
@onready var player_tech_slots = [
	$MainContainer/CenterColumn/PlayerArea/TechRow/Tech1,
	$MainContainer/CenterColumn/PlayerArea/TechRow/Tech2,
	$MainContainer/CenterColumn/PlayerArea/TechRow/Tech3,
	$MainContainer/CenterColumn/PlayerArea/TechRow/Tech4,
	$MainContainer/CenterColumn/PlayerArea/TechRow/Tech5
]
@onready var player_helper_slot = $MainContainer/CenterColumn/PlayerArea/TechRow/HelperSlot
@onready var player_occasion_slot = $MainContainer/CenterColumn/PlayerArea/KnightsRow/OccasionSlot
@onready var player_yomotsu_count = $MainContainer/RightColumn/PlayerPiles/YomotsuPile/Count
@onready var player_cositos_count = $MainContainer/RightColumn/PlayerPiles/CositosPile/Count

@onready var opponent_knight_slots = [
	$MainContainer/CenterColumn/OpponentArea/KnightsRow/Knight1,
	$MainContainer/CenterColumn/OpponentArea/KnightsRow/Knight2,
	$MainContainer/CenterColumn/OpponentArea/KnightsRow/Knight3,
	$MainContainer/CenterColumn/OpponentArea/KnightsRow/Knight4,
	$MainContainer/CenterColumn/OpponentArea/KnightsRow/Knight5
]
@onready var opponent_tech_slots = [
	$MainContainer/CenterColumn/OpponentArea/TechRow/Tech1,
	$MainContainer/CenterColumn/OpponentArea/TechRow/Tech2,
	$MainContainer/CenterColumn/OpponentArea/TechRow/Tech3,
	$MainContainer/CenterColumn/OpponentArea/TechRow/Tech4,
	$MainContainer/CenterColumn/OpponentArea/TechRow/Tech5
]
@onready var opponent_helper_slot = $MainContainer/CenterColumn/OpponentArea/TechRow/HelperSlot
@onready var opponent_occasion_slot = $MainContainer/CenterColumn/OpponentArea/KnightsRow/OccasionSlot
@onready var opponent_yomotsu_count = $MainContainer/RightColumn/OpponentPiles/YomotsuPile/Count
@onready var opponent_cositos_count = $MainContainer/RightColumn/OpponentPiles/CositosPile/Count

@onready var scenario_slot = $MainContainer/RightColumn/ScenarioContainer/ScenarioSlot
```

---

## ✅ Recursos Necesarios

Asegúrate que estas scripts están en el proyecto:

- ✅ `scripts/game/CardSlot.gd` - Drop zone para cartas
- ✅ `scripts/game/HandLayout.gd` - Contenedor de cartas en mano
- ✅ `scripts/models/DeckDisplay.gd` - Visualización de pilas

Estos ya existen en GameBoard y deben estar disponibles.

---

## 🎯 Validación Final

Después de agregar todas las zonas:

```gdscript
# En TestBoard._ready(), agregar validación:
print("✅ PlayerArea references:")
print("  - hand: ", player_hand != null)
print("  - knights: ", player_knight_slots.size() == 5)
print("  - techs: ", player_tech_slots.size() == 5)
print("  - helper: ", player_helper_slot != null)
print("  - occasion: ", player_occasion_slot != null)

print("✅ Opponent references:")
print("  - hand: ", opponent_hand != null)
print("  - knights: ", opponent_knight_slots.size() == 5)
print("  - techs: ", opponent_tech_slots.size() == 5)
print("  - helper: ", opponent_helper_slot != null)
print("  - occasion: ", opponent_occasion_slot != null)

print("✅ Shared:")
print("  - scenario: ", scenario_slot != null)
```

---

## 📝 Alternativa Rápida

En lugar de hacer todo manualmente, puedes:

1. Abrir `GameBoard.tscn` en Godot
2. Seleccionar el nodo `MainContainer` completo
3. Ctrl+C (copiar)
4. Abrir `TestBoard.tscn`
5. Eliminar el `MainContainer` actual
6. Ctrl+V (pegar el de GameBoard)
7. Guardar

Esto copia **exactamente** la misma estructura.

---

## 🚀 Próximo Paso

Una vez que TestBoard tenga todas las zonas:

1. Agregar métodos en TestBoard.gd para renderizar cartas en slots
2. Conectar CardSlot.gd con MatchPlayController
3. Implementar drag/drop a los slots de campo
4. Sistema de combate (acciones de caballeros)

