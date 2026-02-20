# 📁 Estructura Completa del Proyecto CCG (Caballeros Cósmicos)

**Última actualización**: 29 de Enero 2026

---

## 📊 Resumen Rápido

Este documento mapea TODOS los archivos y carpetas del proyecto Godot CCG. El proyecto tiene una estructura modular con separación clara entre:
- **Assets** → Imágenes, sonidos, fuentes
- **Scenes** → Escenas de Godot (.tscn)
- **Scripts** → Lógica en GDScript (.gd)
- **Docs** → Documentación
- **.godot/** → Caché del editor (ignorar)

---

## 🎮 ESTRUCTURA PRINCIPAL

```
ccg/
├── assets/                           # 📦 Recursos del juego
├── buids/                            # 🏗️ Compilaciones ejecutables
├── docs/                             # 📚 Documentación
├── scenes/                           # 🎬 Escenas de Godot
├── scripts/                          # 💻 Código GDScript
├── themes/                           # 🎨 Temas visuales
├── user_data/                        # 💾 Datos de usuario
├── .godot/                           # ⚙️ Caché del editor (IGNORAR)
├── .github/                          # 📋 Configuración GitHub
├── .git/                             # 🔄 Control de versiones
├── project.godot                     # ⚙️ Configuración del proyecto
├── export_presets.cfg                # 📤 Presets de exportación
├── icon.svg                          # 🎯 Icono del proyecto
├── INDEX.md                          # 📑 Índice de documentación
├── START-HERE.md                     # 🚀 Punto de inicio
├── FINAL-SUMMARY.md                  # 📝 Resumen final
└── VERIFICATION-CHECKLIST.md         # ✅ Checklist de verificación
```

---

## 📦 CARPETA: `assets/` - Recursos del Juego

```
assets/
├── cards/                            # 🎴 Imágenes de cartas
│   ├── card_back.png                # Dorso de carta
│   ├── card_back.png.bak            # Backup del dorso
│   ├── card_back.png.import         # Metadata de importación
│   └── CARD_BACK_PROMPT.md          # Instrucciones para generar el dorso
│
├── fonts/                            # 🔤 Fuentes de texto
│   └── (vacío - agregar fuentes aquí)
│
├── images/                           # 🖼️ Imágenes generales
│   └── (vacío - agregar imágenes aquí)
│
├── shaders/                          # 🌈 Shaders gráficos
│   ├── circle_mask.gdshader         # Shader para máscaras circulares
│   └── circle_mask.gdshader.uid     # UUID del shader
│
├── sounds/                           # 🔊 Efectos de sonido y música
│   └── (vacío - agregar sonidos aquí)
│
└── ui-icons/                         # 🎨 Iconos de interfaz
    ├── chat_icon.png                # Ícono de chat
    ├── chat_icon_new.png            # Versión nueva
    ├── library_icon.png              # Ícono de librería
    ├── library_icon_new.png         # Versión nueva
    ├── match_icon.png                # Ícono de partidas
    ├── match_icon_new.png           # Versión nueva
    ├── profile_icon.png              # Ícono de perfil
    ├── profile_icon_new.png         # Versión nueva
    ├── shop_icon.png                 # Ícono de tienda
    └── shop_icon_new.png            # Versión nueva
```

---

## 🏗️ CARPETA: `buids/` - Compilaciones Ejecutables

```
buids/
├── CG.exe                            # ⚙️ Ejecutable del juego (release)
├── CG.pck                            # 📦 Datos del juego (Godot pack)
├── CG.console.exe                    # 📺 Ejecutable con consola
├── GalileoGPBalanzas.exe             # 🎮 Ejecutable alternativo
├── GalileoGPBalanzas.ini             # ⚙️ Configuración
└── user_data/
    └── auth_token.save               # 🔐 Token de autenticación guardado
```

---

## 🎬 CARPETA: `scenes/` - Escenas de Godot (Interfaz Visual)

### **📋 Estructura General**

```
scenes/
├── _deprecated/                      # 🗑️ Escenas antiguas (no usar)
│
├── components/                       # 🧩 Componentes reutilizables
│   ├── cards/
│   ├── common/
│   ├── decks/
│   ├── inventory/
│   └── packs/
│
├── effects/                          # ✨ Efectos visuales
│
├── game/                             # 🎮 Escenas de juego principal
│   ├── components/
│   ├── GameBoard.tscn               # Tablero principal
│   └── (múltiples versiones)
│
├── match/                            # 🎯 Pantalla de partida
│
├── menus/                            # 📱 Menús de navegación
│
├── test/                             # 🧪 Escenas de prueba
│
└── ui/                               # 🖥️ Componentes UI
```

---

### 📂 SUBCARPETA: `scenes/components/cards/` - Componentes de Cartas

```
scenes/components/cards/
├── CardBack.tscn                     # 🎴 Dorso de carta (visual)
├── CardDetailView.tscn               # 📖 Vista de detalles de carta
├── CardDisplay.tscn                  # 🎨 Visualización de carta
└── CardDetailView.gd                 # Código para vista de detalles
```

**Uso**: Componentes reutilizables para mostrar cartas en cualquier contexto.

---

### 📂 SUBCARPETA: `scenes/components/common/` - Componentes Comunes

```
scenes/components/common/
├── AvatarDisplay.tscn                # 👤 Visualización de avatar
├── AvatarDisplay.gd                  # Código para avatar
├── CosmosParticles.tscn              # ✨ Partículas de cosmos
├── LanguageSelector.tscn             # 🌍 Selector de idioma
├── LanguageSelector.gd               # Código para selector
└── gold_ring.gd                      # 💍 Anillo dorado (efecto)
```

**Uso**: Componentes genéricos usados en múltiples pantallas.

---

### 📂 SUBCARPETA: `scenes/components/decks/` - Componentes de Mazos

```
scenes/components/decks/
├── DeckItem.tscn                     # 🎯 Elemento individual de mazo
├── DeckItem.gd                       # Código para elemento
├── DeckGridDropZone.gd               # Drop zone para grid
├── DeckPanelDropZone.gd              # Drop zone para panel
```

**Uso**: Gestión visual de mazos en el constructor de mazos.

---

### 📂 SUBCARPETA: `scenes/components/inventory/` - Inventario

```
scenes/components/inventory/
├── PacksInventory.tscn               # 📦 Visualización de packs
└── PacksInventory.gd                 # Código para packs
```

**Uso**: Gestión visual del inventario de sobres (packs).

---

### 📂 SUBCARPETA: `scenes/components/packs/` - Sobres y Aperturas

```
scenes/components/packs/
├── PackCard.tscn                     # 🎴 Carta dentro de un sobre
├── PackCard.gd                       # Código para carta de sobre
├── PackOpening.tscn                  # 🎁 Pantalla de apertura
├── PackOpening.gd                    # Código para apertura
├── PackOpeningResult.tscn            # 📊 Resultado de apertura
├── PackOpeningResult.gd              # Código para resultado
└── PackCard.tscn.uid                 # UUID del archivo
```

**Uso**: Sistema de sobres (booster packs) con animación de apertura.

---

### 📂 SUBCARPETA: `scenes/effects/` - Efectos Visuales

```
scenes/effects/
├── AttackFlash.tscn                  # ⚡ Destello de ataque
├── CombatAnimator.tscn               # 💥 Animador de combate
├── CosmosParticle.tscn               # ✨ Partícula de cosmos
└── DamageNumber.tscn                 # 💔 Número de daño flotante
```

**Uso**: Efectos visuales durante el combate.

---

### 📂 SUBCARPETA: `scenes/game/` - Escenas de Juego Principal

```
scenes/game/
├── GameBoard.tscn                    # 🎮 Tablero principal (versión actual)
├── GameBoard.gd                      # Controlador principal del tablero
├── GameBoard_BACKUP.tscn             # 💾 Backup del tablero
├── GameBoard_BACKUP.gd               # Código backup
├── GameBoard_fixed.gd                # Versión reparada
├── GameBoard_new.tscn                # Nueva versión experimental
├── GameBoard_v2.gd                   # Versión 2
├── GameBoard_v2_old.gd               # Versión 2 antigua
├── GameBoard_OLD2.gd.uid             # UUID archivo antiguo
│
├── components/                       # Subcomponentes del tablero
│   ├── CardZone.tscn                # Zona de cartas
│   ├── CardZone.gd
│   ├── KnightZone.tscn              # Zona de caballeros
│   ├── KnightZone.gd
│   ├── OpponentZone.tscn            # Zona del oponente
│   ├── PlayerStatusPanel.tscn       # Panel de estado del jugador
│   ├── PlayerStatusPanel.gd
│   ├── PlayerZone.tscn              # Zona del jugador
│   ├── RowZone.tscn                 # Zona de fila
│   ├── row_zone.gd
│   ├── TechniqueZone.tscn           # Zona de técnicas
│   ├── TechniqueZone.gd
│   ├── SingleCardSlot.tscn          # Slot para una sola carta
│   ├── SingleCardSlot.gd
│   ├── PilesPanel.tscn              # Panel de pilas (descarte, etc)
│   └── PilesPanel.gd
│
└── (múltiples .tscn temporales)      # Archivos temporales de Godot
```

**Descripción**: El corazón del juego. GameBoard.tscn es la escena principal donde ocurre toda la partida.

---

### 📂 SUBCARPETA: `scenes/match/` - Pantalla de Partida

```
scenes/match/
├── GameMatch.tscn                    # 🎯 Pantalla de emparejamiento
└── game_match.gd                     # Controlador de partida
```

**Uso**: Gestión del flujo de partida y emparejamiento con oponente.

---

### 📂 SUBCARPETA: `scenes/menus/` - Menús de Navegación

```
scenes/menus/
├── CardsCollection.tscn              # 📚 Colección de cartas (librería)
├── CardsCollection.gd                # Código para librería
│
├── DeckBuilder.tscn                  # 🛠️ Constructor de mazos (varias versiones)
├── DeckBuilder.gd
│
├── DecksList.tscn                    # 📋 Lista de mazos
├── DecksList.gd
│
├── LoginScreen.tscn                  # 🔐 Pantalla de login
├── LoginScreen.gd
│
├── MainLobby.tscn                    # 🏠 Lobby principal
├── MainLobby.gd
│
├── MatchSearch.tscn                  # 🔍 Búsqueda de partida (varias)
├── MatchSearch.gd
├── MatchSearch2.tscn
│
├── PacksShop.tscn                    # 🛍️ Tienda de sobres
├── PacksShop.gd
│
├── ProfileScene.tscn                 # 👤 Perfil del jugador
├── ProfileScene.gd
└── (archivos .uid para UUIDs)
```

**Descripción**: Todas las pantallas de menú: login, lobby, tiendas, perfiles, etc.

---

### 📂 SUBCARPETA: `scenes/test/` - Escenas de Prueba

```
scenes/test/
├── TestBoard.tscn                    # 🧪 Tablero de pruebas
├── TestBoard.gd
├── TestBoard copy.tscn               # Copia para modificaciones
└── .tscn.tmp files                   # Archivos temporales de Godot
```

**Uso**: Escenas para probar componentes y mecánicas durante desarrollo.

---

### 📂 SUBCARPETA: `scenes/ui/` - Componentes UI

```
scenes/ui/
└── LoadingScreen.tscn                # ⏳ Pantalla de carga
```

---

## 💻 CARPETA: `scripts/` - Código GDScript

### **📋 Estructura General**

```
scripts/
├── cards/                            # 🎴 Lógica de cartas
├── config/                           # ⚙️ Configuración
├── controllers/                      # 🎮 Controladores de flujo
├── core/                             # 🔧 Funcionalidad core
├── debug/                            # 🐛 Herramientas de debug
├── effects/                          # ✨ Efectos
├── examples/                         # 📖 Ejemplos de código
├── factories/                        # 🏭 Fábricas (creación de objetos)
├── game/                             # 🎮 Lógica de juego
├── managers/                         # 📊 Gestores (singletons)
├── models/                           # 📦 Modelos de datos
├── providers/                        # 📤 Proveedores de datos
├── rules/                            # 📜 Reglas del juego
├── services/                         # 🚀 Servicios
└── utils/                            # 🛠️ Utilidades
```

---

### 📂 SUBCARPETA: `scripts/cards/` - Lógica de Cartas

```
scripts/cards/
├── CardBack.gd                       # 🎴 Lógica del dorso de carta
│   └── Static cache para reutilizar textura
│
├── CardData.gd                       # 📊 Modelo de datos de carta
│   ├── id, name, type, rarity
│   ├── faction, element
│   └── image_url, description, cost
│
└── CardDisplay.gd                    # 🎨 Visualización de carta
    ├── Setup con CardData
    ├── Eventos de mouse/drag
    └── Signals: card_played, etc
```

---

### 📂 SUBCARPETA: `scripts/config/` - Configuración

```
scripts/config/
├── CardSizeConfig.gd                 # 📏 Tamaños de cartas
│   └── card_width, card_height, scale, etc
│
└── GameConfig.gd                     # ⚙️ URLs del servidor
    ├── API_BASE_URL
    ├── WS_URL
    └── Configuración global
```

---

### 📂 SUBCARPETA: `scripts/controllers/` - Controladores de Flujo

```
scripts/controllers/
├── MatchEventBridge.gd               # 🌉 Puente de eventos
│   └── Convierte eventos WebSocket en signals
│
├── MatchFlowController.gd            # 🔄 Flujo general de partida
│   └── Estados: setup → play → end
│
├── MatchInitializer.gd               # 🚀 Inicializador de partida
│   └── Setup inicial de partida
│
└── MatchPlayController.gd            # 🎮 Controlador de juego
    └── Acciones durante el juego
```

---

### 📂 SUBCARPETA: `scripts/core/` - Funcionalidad Core

```
scripts/core/
├── ApiClient.gd                      # 🌐 Cliente HTTP
│   ├── POST/GET/PUT/DELETE
│   └── Manejo de autenticación
│
├── DraggableObject.gd                # 🖱️ Sistema de drag & drop
│   ├── Drag detection
│   ├── Drop validation
│   └── Signals: drag_started, drag_ended
│
├── InstanceManager.gd                # 📦 Gestor de instancias
│   └── Carga/descarga de objetos
│
└── SessionManager.gd                 # 🔐 Gestor de sesión
    ├── Login/logout
    └── Token management
```

---

### 📂 SUBCARPETA: `scripts/debug/` - Herramientas de Debug

```
scripts/debug/
└── TestBoardDebugHelper.gd           # 🐛 Herramientas para TestBoard
    ├── Crear cartas de prueba
    ├── Simular acciones
    └── Mostrar estado
```

---

### 📂 SUBCARPETA: `scripts/effects/` - Efectos

```
scripts/effects/
├── AttackFlash.gd                    # ⚡ Destello de ataque
├── CombatAnimator.gd                 # 💥 Animador de combate
│   └── Coordina efectos visuales
│
└── DamageNumber.gd                   # 💔 Número de daño
    └── Anima número flotante
```

---

### 📂 SUBCARPETA: `scripts/examples/` - Ejemplos

```
scripts/examples/
└── GameBoard-Integration-Example.gd  # 📖 Ejemplo de uso de GameBoard
```

---

### 📂 SUBCARPETA: `scripts/factories/` - Fábricas

```
scripts/factories/
└── CardDisplayFactory.gd             # 🏭 Factory para CardDisplay
    ├── Crea CardDisplay desde CardData
    └── Maneja instanciación
```

---

### 📂 SUBCARPETA: `scripts/game/` - Lógica de Juego

```
scripts/game/
├── BoardRenderer.gd                  # 🎨 Renderiza el tablero
│   ├── Actualiza zonas visuales
│   └── Maneja eventos de tablero
│
├── CardCostValidator.gd              # ✅ Valida costos de cartas
│
├── CardDealAnimator.gd               # 🎴 Anima reparto de cartas
│
├── CardPlayManager.gd                # 🎮 Gestiona juego de cartas
│   ├── Jugar cartas
│   ├── Validar acciones
│   └── Comunicar con servidor
│
├── CardSlot.gd                       # 🎯 Slot individual para carta
│
├── DropZone.gd                       # 📍 Zona de soltar cartas
│
├── HandLayout.gd                     # 🖐️ Layout de mano de cartas
│   ├── Espaciado automático
│   ├── Efectos hover
│   └── Drag & drop support
│
├── MatchEffectsManager.gd            # ✨ Gestor de efectos de partida
│   └── Coordina todos los efectos
│
├── OpponentZone.gd                   # 👤 Zona del oponente
│
├── PlayerZone.gd                     # 🎮 Zona del jugador
│
├── TestBoard.gd                      # 🧪 Controlador TestBoard
│
└── components/                       # Componentes especializados
    ├── CardZone.gd
    ├── KnightZone.gd
    ├── PilesPanel.gd
    ├── PlayerStatusPanel.gd
    ├── SingleCardSlot.gd
    ├── TechniqueZone.gd
    └── row_zone.gd
```

---

### 📂 SUBCARPETA: `scripts/managers/` - Gestores (Singletons)

```
scripts/managers/
├── AudioManager.gd                   # 🔊 Gestor de audio
│   ├── Música de fondo
│   └── Efectos de sonido
│
├── AuthManager.gd                    # 🔐 Gestor de autenticación
│   ├── Login/logout
│   └── Token management
│
├── AuthManager_OLD.gd.uid            # Versión antigua
│
├── CardAnimationManager.gd           # 🎬 Animaciones de cartas
│
├── CardDatabase.gd                   # 📚 Base de datos de cartas
│   └── Caché de todas las cartas
│
├── CardDetailManager.gd              # 📖 Gestor de detalles
│
├── CardsManager.gd                   # 🎴 Gestor de cartas
│   ├── Carga imágenes
│   ├── Caché de datos
│   └── Signals: card_image_loaded
│
├── DeckLoadingManager.gd             # 📦 Carga de mazos
│
├── DecksManager.gd                   # 🎯 Gestor de mazos
│   ├── CRUD de mazos
│   └── Validación de mazos
│
├── LocalizationManager.gd            # 🌍 Gestor de idiomas
│   ├── Traducción de cartas
│   ├── Traducción de UI
│   └── Persistencia de idioma
│
├── MatchmakingManager.gd             # 🔍 Emparejamiento
│   ├── Buscar oponentes
│   └── Crear partidas
│
├── MatchManager.gd                   # 🎮 Gestor de partidas
│   ├── Estado actual de partida
│   ├── Sincronización con servidor
│   └── Signals: match_state_updated
│
├── PacksManager.gd                   # 📦 Gestor de sobres
│
├── Signals.gd                        # 📡 Signals globales
│   └── Declaraciones de signals compartidos
│
├── TurnPhaseManager.gd               # 🔄 Gestor de turnos
│   ├── Fases del turno
│   └── Control de turnos
│
├── UserManager.gd                    # 👤 Gestor de usuario
│   ├── Datos del usuario
│   └── Perfil
│
├── WebSocketManager.gd               # 🌐 WebSocket en tiempo real
│   ├── Conexión WebSocket
│   ├── Eventos de partida
│   └── Chat en tiempo real
│
├── NetworkManager.gd.uid             # UUID archivo deprecado
└── NetworkManager_DEPRECATED.gd.uid  # Archivo deprecado
```

---

### 📂 SUBCARPETA: `scripts/models/` - Modelos de Datos

```
scripts/models/
├── CardCollection.gd                 # 🧩 Base para colecciones
│   ├── Clase abstracta
│   ├── Template method: _update_layout()
│   └── Signals: card_added, card_removed
│
├── CardInstance.gd                   # 🎴 Instancia de carta en juego
│   ├── Referencia a CardData
│   ├── Estado: zona, modo, exhausto
│   └── Efectos de estado
│
├── DeckDisplay.gd                    # 📚 Visualización de mazo (pila)
│   ├── Muestra 2-3 cartas apiladas
│   ├── Contador de cartas
│   └── Métodos: set_count(), push/pop
│
├── GameState.gd                      # 🎮 Estado actual del juego
│   ├── Mano, campo, descarte
│   ├── Información del oponente
│   └── Factory: from_server_data()
│
├── PlayerState.gd                    # 👤 Estado del jugador
│   ├── Vida, cosmos, recursos
│   └── Cartas en cada zona
│
├── SlotGroup.gd                      # 🎯 Grupo de slots
│   └── Manejo de múltiples slots
│
└── UserProfile.gd                    # 👤 Perfil del usuario
    ├── Nombre, avatar
    ├── Estadísticas
    └── Colección de cartas
```

---

### 📂 SUBCARPETA: `scripts/providers/` - Proveedores de Datos

```
scripts/providers/
├── OpponentProvider.gd               # 👤 Proveedor de oponente real
├── PlayerDeckProvider.gd             # 🎯 Proveedor de mazo del jugador
├── TestDeckProvider.gd               # 🧪 Proveedor de mazo de prueba
└── TestOpponentProvider.gd           # 🧪 Proveedor de oponente de prueba
```

---

### 📂 SUBCARPETA: `scripts/rules/` - Reglas del Juego

```
scripts/rules/
├── GameController.gd                 # 🎮 Controlador de reglas
│   ├── Validar acciones
│   ├── Calcular daño
│   └── Gestionar fases
│
├── GameRules.gd.uid                  # UUID archivo de reglas
└── BattleCalculator.gd.uid           # Calculador de batalla
```

---

### 📂 SUBCARPETA: `scripts/services/` - Servicios

```
scripts/services/
└── PackService.gd                    # 📦 Servicio de sobres
    ├── Abrir packs
    └── Obtener recompensas
```

---

### 📂 SUBCARPETA: `scripts/ui/` - Componentes UI

```
scripts/ui/
├── ChatPanel.gd                      # 💬 Panel de chat
├── KnightActionsPanel.gd             # ⚔️ Panel de acciones de caballero
├── LoadingScreen.gd                  # ⏳ Pantalla de carga
├── OnlineUsersList.gd                # 👥 Lista de usuarios online
└── PlayerStatusDisplay.gd            # 📊 Visualización de estado del jugador
```

---

### 📂 SUBCARPETA: `scripts/utils/` - Utilidades

```
scripts/utils/
├── CardDropValidator.gd              # ✅ Valida solta de cartas
│   ├── Verifica zona válida
│   ├── Verifica costos
│   └── Verifica restricciones
│
├── CombatCalculator.gd               # ⚔️ Calcula daño/combate
│   ├── Daño = Ataque - Defensa
│   ├── Efectos de modo
│   └── Modificadores
│
└── SceneTransition.gd                # 🎬 Transiciones entre escenas
    ├── Efectos de transición
    └── Pre-carga de escenas
```

---

## 📚 CARPETA: `docs/` - Documentación

```
docs/
├── START-HERE.md                     # 🚀 Comienza aquí
├── ARCHITECTURE-SUMMARY.md           # 🏗️ Resumen de arquitectura
├── ARCHITECTURE-SERVER-AUTHORITATIVE.md
├── ARCHITECTURE-CORRECTIONS-SESSION-SUMMARY.md
│
├── CARD-COLLECTIONS-ARCHITECTURE.md  # 🧩 Arquitectura de colecciones
├── CARD-DETAIL-VIEW-*.md            # 📖 Vista de detalles
├── CARD-ANIMATION-SYSTEM.md         # 🎬 Sistema de animación
│
├── DECK-AND-OPPONENT-HAND-VISUAL-CHANGES.md
├── DECKBUILDER-SOLAPAS-COMPLETO.md  # 🛠️ Constructor de mazos
│
├── GAMEBOARD_V2_MODES.md            # 🎮 Modos del tablero
├── GAMEBOARD-STRUCTURE-GUIDE.md     # Guía de estructura
├── TESTBOARD-*.md                   # 🧪 Guías de testboard
│
├── DRAG-DROP-DEBUGGING.md           # 🖱️ Debug de drag & drop
├── IMPLEMENTATION-DRAG-DROP-COMPLETE.md
│
├── AUTH_SYSTEM.md                   # 🔐 Sistema de autenticación
├── NETWORK-ARCHITECTURE.md          # 🌐 Arquitectura de red
│
├── LANGUAGE-PERSISTENCE-EXPLAINED.md # 🌍 Persistencia de idioma
├── MATCH-VALIDATION.md              # ✅ Validación de partidas
│
└── (55+ archivos de documentación más)
```

**Nota**: La carpeta `docs/` contiene documentación detallada sobre cada aspecto del proyecto. Consulta los archivos relevantes para profundizar en temas específicos.

---

## 🎨 CARPETA: `themes/` - Temas Visuales

```
themes/
└── card_game.theme                   # 🎨 Tema principal del juego
    ├── Colores
    ├── Fuentes
    ├── Tamaños
    └── Estilos de componentes
```

---

## 💾 CARPETA: `user_data/` - Datos de Usuario

```
user_data/
└── auth_token.save                   # 🔐 Token de autenticación guardado
```

---

## ⚙️ CARPETA: `.godot/` - Caché del Editor (NO MODIFICAR)

```
.godot/
├── editor/                           # Configuración del editor
│   ├── *.cfg (folding, editstate)
│   └── (múltiples archivos de configuración)
│
├── exported/                         # Versiones compiladas
│
├── imported/                         # Importaciones de assets
│   └── (texturas y recursos importados)
│
├── shader_cache/                     # Caché de shaders compilados
│
├── .gdignore                         # Archivo de ignorado
└── (múltiples archivos de caché)
```

**⚠️ IMPORTANTE**: Esta carpeta es generada automáticamente por Godot. NO modifiques estos archivos directamente.

---

## 📋 ARCHIVO: `.github/` - Configuración GitHub

```
.github/
└── copilot-instructions.md           # 📖 Instrucciones para Copilot
    ├── Resumen del proyecto
    ├── Patrones de código
    └── Guías de desarrollo
```

---

## 📖 ARCHIVOS IMPORTANTES EN RAÍZ

```
project.godot                   # ⚙️ Configuración del proyecto Godot
export_presets.cfg              # 📤 Configuración de exportación
icon.svg                        # 🎯 Icono del proyecto
.gitignore                      # 🔄 Archivos a ignorar en Git
.gitattributes                  # 🔄 Atributos de Git
.editorconfig                   # ⚙️ Configuración del editor

START-HERE.md                   # 🚀 Punto de inicio para devs
FINAL-SUMMARY.md                # 📝 Resumen final del proyecto
INDEX.md                        # 📑 Índice de documentación
VERIFICATION-CHECKLIST.md       # ✅ Checklist de verificación
TESTBOARD-QUICK-START.md        # 🧪 Inicio rápido para TestBoard
TESTBOARD-CLEANUP-SUMMARY.md    # Resumen de limpieza
```

---

## 🎯 GUÍA RÁPIDA POR SECCIÓN

### 🎴 ¿Dónde encontrar... cartas?
- **Lógica**: `scripts/cards/`
- **Visual**: `scenes/components/cards/`
- **Imágenes**: `assets/cards/`

### 🎮 ¿Dónde encontrar... el juego?
- **Tablero principal**: `scenes/game/GameBoard.tscn`
- **Controlador**: `scenes/game/GameBoard.gd`
- **Lógica de juego**: `scripts/game/`

### 🛠️ ¿Dónde encontrar... el constructor de mazos?
- **Visual**: `scenes/menus/DeckBuilder.tscn`
- **Controlador**: `scenes/menus/DeckBuilder.gd`
- **Gestión**: `scripts/managers/DecksManager.gd`

### 👤 ¿Dónde encontrar... el perfil/login?
- **Login**: `scenes/menus/LoginScreen.tscn`
- **Perfil**: `scenes/menus/ProfileScene.tscn`
- **Autenticación**: `scripts/managers/AuthManager.gd`

### 📦 ¿Dónde encontrar... los sobres/tienda?
- **Tienda**: `scenes/menus/PacksShop.tscn`
- **Apertura**: `scenes/components/packs/PackOpening.tscn`
- **Gestión**: `scripts/managers/PacksManager.gd`

### 🌍 ¿Dónde encontrar... idiomas?
- **Gestión**: `scripts/managers/LocalizationManager.gd`
- **Selector**: `scenes/components/common/LanguageSelector.tscn`
- **Archivos de traducción**: Se cargan desde API

### 🌐 ¿Dónde encontrar... comunicación con servidor?
- **HTTP**: `scripts/core/ApiClient.gd`
- **WebSocket**: `scripts/managers/WebSocketManager.gd`
- **Config**: `scripts/config/GameConfig.gd`

### ✨ ¿Dónde encontrar... efectos visuales?
- **Efectos**: `scenes/effects/`
- **Código de efectos**: `scripts/effects/`
- **Animaciones**: `scripts/managers/CardAnimationManager.gd`

### 🎨 ¿Dónde encontrar... la interfaz?
- **Componentes**: `scenes/components/`
- **Menus**: `scenes/menus/`
- **Temas**: `themes/card_game.theme`

---

## 📊 ESTADÍSTICAS

| Categoría | Cantidad |
|-----------|----------|
| Archivos `.tscn` (Escenas) | ~40 |
| Archivos `.gd` (Scripts) | ~80 |
| Archivos de documentación | ~70 |
| Archivos de configuración | 10+ |
| Carpetas principales | 10 |
| Archivos de imagen | 15+ |
| Líneas de código aprox. | 50,000+ |

---

## 🚀 CONSEJOS PARA NAVEGACIÓN

1. **Usa Ctrl+P** en VS Code para búsqueda rápida de archivos
2. **Mira `START-HERE.md`** para entender la arquitectura
3. **Mantén abierto `INDEX.md`** como referencia rápida
4. **Los archivos `_OLD`, `_BACKUP`, `_deprecated`** son seguros de ignorar
5. **Usa `search` (Ctrl+Shift+F)** para encontrar clases/funciones
6. **Los archivos `.gd.uid`** son índices generados por Godot (ignorar)
7. **Revisa `docs/` regularmente** para documentación actualizada

---

## 🎯 PRÓXIMOS PASOS

1. **Estudio inicial**: Lee `START-HERE.md`
2. **Comprensión de la estructura**: Revisa este documento
3. **Exploración de código**: Abre `GameBoard.gd` para ver la lógica principal
4. **Desarrollo**: Empieza por `scripts/game/` para cambios de mecánica
5. **Testing**: Usa `TestBoard.tscn` para probar cambios

---

**Actualizado**: 29 de Enero, 2026  
**Proyecto**: Caballeros Cósmicos (CCG)  
**Versión Godot**: 4.x  
**Estado**: Activo en desarrollo
