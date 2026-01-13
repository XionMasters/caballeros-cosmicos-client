# 🎮 PlayerStatusDisplay - Integración en GameBoard

## Overview

`PlayerStatusDisplay` es un componente UI que muestra:
- ✅ Avatar del jugador (circular, centrado)
- ✅ Rueda de Cosmos (azul, izquierda) - 💫 energía para jugar cartas
- ✅ Rueda de Vida (roja, derecha) - ❤️ puntos de vida
- ✅ Nombre del jugador (debajo del avatar)

Visual similar a la imagen proporcionada.

## Instalación

### 1. Crear nodo Control en la escena

En `TestBoard.tscn` (o tu `GameBoard.tscn`):

```
GameBoard (Control)
├── MainContainer
│   ├── LeftColumn
│   ├── CenterColumn
│   ├── RightColumn
└── ⭐ PlayerStatus (Control) ← AGREGAR AQUÍ
```

El Control puede ser un hijo directo de GameBoard.

### 2. Asignar el script

- Selecciona el nodo Control
- En el Inspector → Attach Script
- Selecciona `scripts/ui/PlayerStatusDisplay.gd`

O en el código:

```gdscript
# En _ready() de TestBoard.gd
var player_status = PlayerStatusDisplay.new()
player_status.player_name = "Diego"
player_status.is_player = true
add_child(player_status)
```

### 3. Configurar los exports (en el Inspector)

- **player_name**: "Diego" (nombre que se muestra)
- **is_player**: true (true=jugador, false=oponente)
- **avatar_size**: Vector2(120, 120) (tamaño del avatar)

## Integración en Código

### Opción A: Nodo en la escena (RECOMENDADO)

```gdscript
# En TestBoard.gd
extends Control

@onready var player_status = $PlayerStatus  # Referencia al nodo en la escena
@onready var opponent_status = $OpponentStatus

func _ready():
	# Conectar a actualizaciones del estado
	MatchManager.match_state_updated.connect(_on_match_state_updated)
	
	# Configurar nombres
	player_status.player_name = MatchManager.current_match.get("player1_name", "Player 1")
	opponent_status.player_name = MatchManager.current_match.get("player2_name", "Player 2")

func _on_match_state_updated(_data):
	"""Actualizar cuando el estado del juego cambia"""
	if MatchManager.game_state:
		# Actualizar jugador local
		player_status.update_stats(
			MatchManager.game_state.player_life,
			MatchManager.game_state.player_cosmos
		)
		
		# Actualizar oponente
		opponent_status.update_stats(
			MatchManager.game_state.opponent_life,
			MatchManager.game_state.opponent_cosmos
		)
```

### Opción B: Crear por código

```gdscript
# En TestBoard.gd
func _ready():
	# Crear displays de status
	var player_status = PlayerStatusDisplay.new()
	player_status.player_name = "Diego"
	player_status.is_player = true
	player_status.custom_minimum_size = Vector2(400, 180)
	add_child(player_status)
	
	# Conectar actualizaciones
	MatchManager.match_state_updated.connect(
		func(_data): _update_status_display(player_status, true)
	)
```

## API de PlayerStatusDisplay

### Métodos

```gdscript
# Actualizar vida y cosmos
update_stats(life: int, cosmos: int) -> void

# Establecer avatar
set_avatar(texture: Texture2D) -> void

# Actualizar nombre
player_status.player_name = "Nuevo Nombre"
player_status.name_label.text = "Nuevo Nombre"
```

### Propiedades

```gdscript
var player_name: String              # Nombre mostrado
var is_player: bool                  # true=jugador, false=oponente
var avatar_size: Vector2             # Tamaño del avatar (default 120x120)
var current_life: int                # Vida actual (read-only)
var current_cosmos: int              # Cosmos actual (read-only)
var max_life: int                    # Vida máxima (default 12)
```

## Cosmos - Fix Implementado

### Problema
No se estaba dando cosmos (💫) al inicio del primer turno.

### Solución
Agregada función `_handle_turn_start()` en `MatchManager.gd` que:
1. Se activa cuando el servidor envía evento "turn_changed"
2. Asegura que SIEMPRE hay al menos 1 cosmos al inicio del turno
3. Funciona incluso si el servidor falla en hacerlo

```gdscript
# En MatchManager.gd
func _handle_turn_start(data: Dictionary) -> void:
	"""Asegurar 1 cosmos al inicio de CADA turno"""
	if not game_state:
		return
	
	var current_player = data.get("current_player", 0)
	var is_player_turn = (current_player == game_state.player_number)
	
	if is_player_turn:
		game_state.player_cosmos = max(game_state.player_cosmos, 1)
```

**Resultado**: Al iniciar cada turno (incluyendo el turno 1), el jugador recibe automáticamente 1 cosmos.

## Estilo Visual

### Rueda de Cosmos (Azul)
```
┌─────────────────┐
│   COSMOS 💫     │
│      5          │
│   (azul claro)  │
└─────────────────┘
```

### Rueda de Vida (Rojo)
```
┌─────────────────┐
│     LIFE ❤️      │
│      12         │
│   (rojo claro)  │
└─────────────────┘
```

## Ejemplo Completo (TestBoard.gd)

```gdscript
extends Control

@onready var player_status = $PlayerStatus
@onready var opponent_status = $OpponentStatus

func _ready():
	# Conectar cambios de estado
	MatchManager.match_state_updated.connect(_on_match_state_updated)
	MatchManager.match_found.connect(_on_match_found)

func _on_match_found(match_data: Dict):
	"""Cuando se encuentra una partida"""
	player_status.player_name = match_data.get("player1_name", "Player 1")
	opponent_status.player_name = match_data.get("player2_name", "Player 2")
	
	# Cargar avatares (si tienes)
	# player_status.set_avatar(load("user://avatars/player1.png"))

func _on_match_state_updated(_data):
	"""Actualizar displays cada vez que cambia el estado"""
	if MatchManager.game_state:
		player_status.update_stats(
			MatchManager.game_state.player_life,
			MatchManager.game_state.player_cosmos
		)
		opponent_status.update_stats(
			MatchManager.game_state.opponent_life,
			MatchManager.game_state.opponent_cosmos
		)
```

## Notas

- PlayerStatusDisplay crea su propia UI, no necesita nodos hijos predefinidos
- Los valores de vida y cosmos se actualizan instantáneamente
- Compatible con cualquier tamaño de pantalla (usa anchors/offsets)
- El avatar es opcional - si no se asigna, muestra un placeholder vacío

## Troubleshooting

**P**: El avatar no se muestra
**R**: Llama a `player_status.set_avatar(texture)` después de _ready()

**P**: Los números no se actualizan
**R**: Asegúrate de conectar `MatchManager.match_state_updated` y llamar `update_stats()`

**P**: El cosmos sigue siendo 0
**R**: El fix en `_handle_turn_start()` está activo. Espera a que el servidor envíe "turn_changed"

---

**Last Updated**: Diciembre 26, 2025

