# Estructura del Proyecto CCG (Caballeros Cósmicos - Godot Client)

```
ccg/
├── .editorconfig
├── .gitattributes
├── .gitignore
├── export_presets.cfg
├── icon.svg
├── icon.svg.import
├── project.godot
│
├── .github/
│   └── copilot-instructions.md
│
├── .godot/
│   └── (archivos generados automáticamente por Godot)
│
├── assets/
│   ├── cards/
│   │   ├── card_back.png
│   │   ├── card_back.png.bak
│   │   ├── card_back.png.import
│   │   └── CARD_BACK_PROMPT.md
│   │
│   ├── fonts/
│   │   └── (vacío)
│   │
│   ├── images/
│   │   └── (vacío)
│   │
│   ├── sounds/
│   │   └── (vacío)
│   │
│   └── ui-icons/
│       ├── chat_icon.png
│       ├── chat_icon.png.import
│       ├── chat_icon_new.png
│       ├── chat_icon_new.png.import
│       ├── library_icon.png
│       ├── library_icon.png.import
│       ├── library_icon_new.png
│       ├── library_icon_new.png.import
│       ├── match_icon.png
│       ├── match_icon.png.import
│       ├── match_icon_new.png
│       ├── match_icon_new.png.import
│       ├── profile_icon.png
│       ├── profile_icon.png.import
│       ├── profile_icon_new.png
│       ├── profile_icon_new.png.import
│       ├── shop_icon.png
│       ├── shop_icon.png.import
│       ├── shop_icon_new.png
│       └── shop_icon_new.png.import
│
├── buids/
│   ├── CG.console.exe
│   ├── CG.exe
│   ├── CG.pck
│   ├── GalileoGPBalanzas.exe
│   └── GalileoGPBalanzas.ini
│
├── docs/
│   ├── AUTH_SYSTEM.md
│   ├── CARD-COLLECTIONS-ARCHITECTURE.md
│   ├── CARDDISPLAY-INTEGRATION.md
│   ├── DECK-AND-OPPONENT-HAND-VISUAL-CHANGES.md
│   ├── GameDesign.md
│   ├── GAME_ARCHITECTURE.md
│   ├── INTEGRATION_COMPLETED.md
│   └── INTEGRATION_PLAN.md
│
├── scenes/
│   ├── effects/
│   │   ├── AttackFlash.tscn
│   │   ├── CombatAnimator.tscn
│   │   ├── CosmosParticle.tscn
│   │   └── DamageNumber.tscn
│   │
│   ├── game/
│   │   ├── GameBoard.gd
│   │   ├── GameBoard.gd.uid
│   │   ├── GameBoard.tscn
│   │   └── GameBoard_OLD2.gd.uid
│   │
│   ├── main/
│   │   ├── main.gd
│   │   ├── main.gd.uid
│   │   ├── Main.tscn
│   │   ├── MainLobby.gd
│   │   ├── MainLobby.gd.uid
│   │   └── MainLobby.tscn
│   │
│   ├── menus/
│   │   ├── LoginScreen.gd
│   │   ├── LoginScreen.gd.uid
│   │   ├── LoginScreen.tscn
│   │   └── LoginScreen.tscn.uid
│   │
│   └── ui/
│       ├── AvatarDisplay.gd
│       ├── AvatarDisplay.gd.uid
│       ├── AvatarDisplay.tscn
│       ├── CardBack.tscn
│       ├── CardDetailView.gd
│       ├── CardDetailView.gd.uid
│       ├── CardDetailView.tscn
│       ├── CardDisplay.tscn
│       ├── CardsCollection.gd
│       ├── CardsCollection.gd.uid
│       ├── CardsCollection.tscn
│       ├── CosmosParticles.tscn
│       ├── DeckBuilder.gd
│       ├── DeckBuilder.gd.uid
│       ├── DeckBuilder.tscn
│       ├── DeckBuilder.tscn.uid
│       ├── DeckGridDropZone.gd
│       ├── DeckGridDropZone.gd.uid
│       ├── DeckItem.gd
│       ├── DeckItem.gd.uid
│       ├── DeckItem.tscn
│       ├── DeckPanelDropZone.gd
│       ├── DeckPanelDropZone.gd.uid
│       ├── DecksList.gd
│       ├── DecksList.gd.uid
│       ├── DecksList.tscn
│       ├── LanguageSelector.gd
│       ├── LanguageSelector.gd.uid
│       ├── LanguageSelector.tscn
│       ├── MatchSearch.gd
│       ├── MatchSearch.gd.uid
│       ├── MatchSearch.tscn
│       ├── PackCard.gd
│       ├── PackCard.gd.uid
│       ├── PackCard.tscn
│       ├── PackCard.tscn.uid
│       ├── PackOpening.gd
│       ├── PackOpening.gd.uid
│       ├── PackOpening.tscn
│       ├── PackOpeningResult.gd
│       ├── PackOpeningResult.gd.uid
│       ├── PackOpeningResult.tscn
│       ├── PacksInventory.gd
│       ├── PacksInventory.gd.uid
│       ├── PacksInventory.tscn
│       ├── PacksShop.gd
│       ├── PacksShop.gd.uid
│       ├── PacksShop.tscn
│       ├── ProfileScene.gd
│       ├── ProfileScene.gd.uid
│       └── ProfileScene.tscn
│
├── scripts/
│   ├── cards/
│   │   ├── CardBack.gd
│   │   ├── CardBack.gd.uid
│   │   ├── CardData.gd
│   │   ├── CardData.gd.uid
│   │   ├── CardDisplay.gd
│   │   └── CardDisplay.gd.uid
│   │
│   ├── config/
│   │   ├── GameConfig.gd
│   │   └── GameConfig.gd.uid
│   │
│   ├── effects/
│   │   ├── AttackFlash.gd
│   │   ├── AttackFlash.gd.uid
│   │   ├── CombatAnimator.gd
│   │   ├── CombatAnimator.gd.uid
│   │   ├── DamageNumber.gd
│   │   └── DamageNumber.gd.uid
│   │
│   ├── game/
│   │   ├── CardSlot.gd
│   │   ├── CardSlot.gd.uid
│   │   ├── HandLayout.gd
│   │   ├── HandLayout.gd.uid
│   │   ├── MatchEffectsManager.gd
│   │   └── MatchEffectsManager.gd.uid
│   │
│   ├── managers/
│   │   ├── AudioManager.gd
│   │   ├── AudioManager.gd.uid
│   │   ├── AuthManager.gd
│   │   ├── AuthManager.gd.uid
│   │   ├── CardDetailManager.gd
│   │   ├── CardDetailManager.gd.uid
│   │   ├── CardsManager.gd
│   │   ├── CardsManager.gd.uid
│   │   ├── DecksManager.gd
│   │   ├── DecksManager.gd.uid
│   │   ├── LocalizationManager.gd
│   │   ├── LocalizationManager.gd.uid
│   │   ├── MatchmakingManager.gd
│   │   ├── MatchmakingManager.gd.uid
│   │   ├── MatchManager.gd
│   │   ├── MatchManager.gd.uid
│   │   ├── NetworkManager.gd
│   │   ├── NetworkManager.gd.uid
│   │   ├── TurnPhaseManager.gd
│   │   ├── TurnPhaseManager.gd.uid
│   │   ├── WebSocketManager.gd
│   │   └── WebSocketManager.gd.uid
│   │
│   ├── models/
│   │   ├── CardCollection.gd
│   │   ├── CardCollection.gd.uid
│   │   ├── CardInstance.gd
│   │   ├── CardInstance.gd.uid
│   │   ├── DeckDisplay.gd
│   │   ├── DeckDisplay.gd.uid
│   │   ├── GameState.gd
│   │   └── GameState.gd.uid
│   │
│   ├── ui/
│   │   ├── ChatPanel.gd
│   │   ├── ChatPanel.gd.uid
│   │   ├── KnightActionsPanel.gd
│   │   ├── KnightActionsPanel.gd.uid
│   │   ├── OnlineUsersList.gd
│   │   └── OnlineUsersList.gd.uid
│   │
│   └── utils/
│       ├── CombatCalculator.gd
│       ├── CombatCalculator.gd.uid
│       ├── SceneTransition.gd
│       └── SceneTransition.gd.uid
│
└── themes/
    └── (vacío)
```

---

## Descripción de Carpetas Principales

### **assets/**
Recursos del juego (imágenes, fuentes, sonidos, iconos)
- `cards/` - Dorso de carta y recursos relacionados
- `ui-icons/` - Iconos de interfaz (chat, tienda, partidas, etc.)
- `fonts/`, `images/`, `sounds/` - Vacíos actualmente

### **buids/**
Builds compilados del juego (ejecutables)
- `CG.exe` - Build de escritorio
- `CG.pck` - Archivo de recursos empaquetados

### **docs/**
Documentación técnica del proyecto
- Arquitecturas, planes de integración, diseño de juego

### **scenes/**
Archivos de escenas (.tscn) y sus scripts asociados
- `effects/` - Efectos visuales (ataques, daño, partículas)
- `game/` - Tablero principal del juego
- `main/` - Escena principal y lobby
- `menus/` - Pantalla de login
- `ui/` - Componentes de UI reutilizables (cartas, avatares, mazos, packs, etc.)

### **scripts/**
Scripts GDScript organizados por categoría
- `cards/` - Lógica de cartas (datos, display, dorsos)
- `config/` - Configuración del juego (URLs, constantes)
- `effects/` - Scripts de efectos visuales
- `game/` - Lógica de juego (slots, mano, efectos de partida)
- `managers/` - Managers singleton (autoloads) para networking, audio, localización, etc.
- `models/` - Modelos de datos (CardInstance, GameState, colecciones)
- `ui/` - Scripts de componentes UI
- `utils/` - Utilidades (cálculos de combate, transiciones)

### **themes/**
Temas visuales de Godot (vacío actualmente)

---

## Archivos Raíz Importantes

- `project.godot` - Configuración del proyecto Godot
- `export_presets.cfg` - Configuración de exportación/build
- `.github/copilot-instructions.md` - Instrucciones para GitHub Copilot
- `icon.svg` - Icono del proyecto

---

**Última actualización**: Diciembre 2, 2025
