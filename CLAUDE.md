# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Proyecto

Cliente en **Godot 4.5** (GDScript, Forward Plus) de **Caballeros Cósmicos**, un juego de cartas coleccionables por turnos inspirado en Saint Seiya. El servidor (Node/TypeScript) está en `A:\Desarrollo\Server-SS` y tiene su propio CLAUDE.md. Comentarios, logs y documentación en español.

**Principio central: el servidor es autoritativo.** El cliente no calcula reglas. Cada `match_update` trae las `valid_actions` de cada carta del jugador activo, calculadas por el `ActionResolver` del servidor, y la interfaz solo ofrece lo que esas `valid_actions` permiten. Para cambiar reglas de combate hay que tocar el servidor, no el cliente.

## Ejecutar y verificar

No hay tests automatizados. Para comprobar cambios:

```powershell
$g = "A:\Desarrollo\Godot_v4.5.1-stable_win64_console.exe"
& $g --headless --path . --import    # reimporta y muestra errores de parseo/compilación de GDScript
& $g --path .                         # ejecuta el juego (escena principal: menus/login/LoginScreen.tscn)
& $g --path . -e                      # abre el editor
```

Para jugar hace falta el servidor en marcha (`npm run dev` en Server-SS). Las URLs se configuran en `shared/config/GameConfig.gd`: por defecto `http://localhost:3000/api` y `ws://localhost:3000/ws`, y se pueden sobrescribir con las variables de entorno `API_URL` y `WS_URL`. Para probar PvP en local hay que abrir dos instancias con usuarios distintos. El botón de partida TEST del lobby (`menus/lobby/match_test_button.gd`) crea una partida de prueba sin rival. El botón «CONTRA LA IA» (`menus/lobby/match_ai_button.gd` → `MatchmakingService.request_ai_match()`, evento `request_ai_match`) crea una partida contra la IA del servidor; ver `Server-SS/docs/JUGADOR-VS-IA.md`.

`export_presets.cfg` tiene un único preset, «Windows Desktop», que exporta a `buids/CG.exe` (la carpeta se llama así, con la errata incluida). `buids/` y `user_data/` están en `.gitignore`.

## Arquitectura

Las capas son UI (escenas en `menus/`, `game/`, `ui/`) → managers y servicios (autoloads) → núcleo (`shared/client/ApiClient.gd`, `SessionManager.gd`).

**Autoloads** (definidos en `project.godot`): `ApiClient`, `AuthManager`, `UserManager`, `CardsManager`, `CardDatabase` (`shared/database/`; al cambiar de idioma, `LocalizationManager` llama a su `reload_for_language()`), `DecksManager`, `PacksManager`, `WebSocketManager`, `MatchSessionService`, `MatchmakingService`, `TurnPhaseManager`, `LocalizationManager` (es/en/pt), `AudioManager`, `SceneTransition` y `CardSizeConfig`.

- **HTTP**: todas las peticiones pasan por `ApiClient` (reintentos, timeout y token de autenticación). El token JWT se guarda en `user://auth_token.save` mediante `SessionManager`. Al iniciar sesión, `AuthManager` llama a `WebSocketManager.connect_to_server(token)`.
- **WebSocket**: los mensajes tienen la forma `{ "event": ..., "data": ... }`. Las acciones de partida se envían con `WebSocketManager.send_match_event(name, data)`, que las empaqueta como el evento `match_action` con un `type` en mayúsculas (la traducción está en `_to_match_action_type`: `PLAY_CARD`, `ATTACK`, `END_TURN`, `CHARGE_COSMOS`…) y un `action_id` UUID. El servidor usa ese `action_id` para garantizar la idempotencia, así que un reintento debe reutilizar el mismo id. Si añades un evento nuevo, hay que tocar `WebSocketManager.gd` y el router y los handlers del servidor.
- **`MatchSessionService`** es el único punto por el que la escena de partida habla con el servidor. Escucha los eventos WS (`match_found`, `match_update`, `match_resumed`…) y emite `match_state_updated`, `phase_changed`, `match_error` y `match_ended`.

### Escena de partida

Navegación: `LoginScreen → MainLobby` (JUGAR, CONTRA LA IA o TEST) → `game/match/GameMatch.tscn`. La búsqueda de partida no es una escena aparte: `menus/matchsearch/MatchSearch.tscn` es una superposición dentro del lobby que escucha a `MatchmakingService` (buscando con cronómetro y consejos, oferta de jugar contra la IA a los 20 s, «¡RIVAL ENCONTRADO!»). Al reconectar con una partida PvP o contra la IA en curso, `match_resumed` trae `game_state` y se entra directo al tablero.

- El controlador de la partida es **`game/match/game_match.gd`**, que delega en los controladores de `game/match/` (`FieldRenderer`, `PlayerHandController`, `OpponentHandController`, `StatusPanelController`, `KnightActionController`, `TurnController`). Varios de estos son objetos GDScript, no nodos.
- Cargar Cosmo es la acción de un caballero: `MatchSessionService.send_charge_cosmos(knight_id)`.
- Al terminar `_ready()` se llama a `MatchSessionService.on_gamematch_ready()`, que hace que el servidor arranque el primer turno.
- Zonas (`zone`), que coinciden con las del servidor: `hand`, `field_knight` (0–4), `field_technique` (0–4), `field_helper`, `field_scenario`, `field_occasion`, `yomotsu` (cementerio) y `exiled`.
- `data/GameState.gd` y `data/CardInstance.gd` son instantáneas de solo lectura del estado que envía el servidor. La mano del rival llega oculta, solo como contador.

### Sistema de animaciones (`game/animation/`)

Cada `match_update` pasa por `AnimationOrchestrator.render_state(gs, match_data)`:

1. **Lockstep**: si hay una reproducción en curso, espera a `playback_finished`. Así dos updates seguidos no se solapan.
2. Los `engine_events` del servidor se traducen con `EngineEventTranslator` (daño, muerte, invocación, curación…). `StateDiffer.compute(prev, next)` deduce del diff de estados el resto de cambios (robos y conteos) y **no duplica** lo que ya cubren los `engine_events`.
3. `_build_queue()` es el único sitio donde se decide el orden y el paralelismo: `UpdateStatus` → robos en paralelo → combate → `RenderField`.

Para añadir una animación, crea una subclase de `AnimationEvent` (`RefCounted`, sobrescribiendo `play(ctx)` y obteniendo los nodos desde `AnimationContext`, sin guardar referencias a ellos) en `game/animation/events/`, y añádela a `EngineEventTranslator` o a `StateDiffer` y a `_build_queue()`. Hay una explicación detallada en `docs/ANIMATION-ARCHITECTURE.md`.

### Otras pantallas

- **Apertura de sobres** (`menus/packs/PackOpeningResult.gd`, dentro de la tienda): `show_cards(pack_name, cards, pack_data = {})` y señal `closed`. El sobre estalla, las cartas caen boca abajo con un halo del color de su rareza y se revelan de la más común a la mejor. Usa `is_new`, `is_foil` y `from_guarantee` de cada carta (esta última marca la épica asegurada). La interfaz se construye en código.
- **Tienda de sobres** (`menus/shop/PacksShop.gd`, `menus/packs/PackCard.gd`): 6 rarezas (con `uncommon`, "Poco común", en `UIPalette.RARITY_ORDER`). Un sobre con `coming_soon` aparece bloqueado con "PRÓXIMAMENTE". El chip de cada sobre muestra `progress.packs_until_guarantee`, es decir, cuántos sobres faltan para la épica asegurada, que el servidor da cada 10 sobres seguidos sin épica o superior. El arte de cada sobre sale de su `code` (`PackArt.TIER_BY_CODE`).
- **Editor de mazos** (`menus/deckbuilder/DeckBuilder.gd`, interfaz construida en código): la colección y la lista del mazo van agrupadas por coste (cabecera por coste, filtro por coste y por tipo). Cada carta de la colección tiene «−» y «+» con el contador «en mazo / máximo». Clic en la carta añade una copia, clic derecho abre el detalle y se puede arrastrar al mazo (`DeckPanelDropZone` recibe un `CardData`). El panel del mazo muestra el total por tipo de carta (pulsar uno filtra la colección) y la curva de coste (pulsar una barra filtra por ese coste). Los cambios de cartas son locales hasta GUARDAR (`DecksManager.sync_deck_cards`); el nombre, el dorso y la portada se guardan al momento. Salir con cambios pide confirmación.

## Convenciones

- Los valores de los enums llegan del servidor en inglés (`knight`, `legendary`, `fire`…). En la interfaz se traducen con `LocalizationManager` (`translate_card_type`, `translate_rarity`, `get_card_name`). Las traducciones están en `assets/translations/{es,en,pt}.json`.
- Las imágenes de cartas se cargan de forma asíncrona y se guardan en la caché de `CardsManager`. Todas las instancias de `CardBack` comparten una sola textura estática.
- Cadena de `mouse_filter` en el tablero: los contenedores usan `IGNORE` o `PASS` y `CardDisplay` usa `STOP`. Si un slot no recibe clics, revisa primero esto.

## Archivos vacíos y código retirado

- `managers/MatchRepository.gd` está vacío (`extends Node`), no es un autoload y nadie lo usa.
- El código sin uso se movió (no se borró) a `A:\Desarrollo\ccc_codigo_muerto` (fuera del proyecto): `game/board/GameBoard`, `game/controllers/` (MatchFlowController, MatchPlayController, MatchEventBridge, MatchInitializer), `game/rules/GameController.gd`, `game/debug/`, las zonas `KnightZone`/`RowZone`, `data/PlayerState.gd`, `data/SlotGroup.gd`, `managers/DeckLoadingManager.gd`, `factories/`, `menus/packs/PackOpening` y una copia del editor de mazos anterior. No hay que restaurarlo.

## Documentación existente y su vigencia

- `docs/GAME_ARCHITECTURE.md` describe el flujo de partida y es el documento más fiel al código (actualizado el 2026-11-09). Las rutas del servidor que cita (`services/…`, `engine/…`, `models/…`) están desactualizadas: ahora son `src/app/matches/…`, `src/domain/game/…` y `src/infrastructure/database/models/…`.
- `.github/copilot-instructions.md` (diciembre de 2025) está **desactualizado**: menciona `NetworkManager` y `MatchManager` (ya no existen), rutas `scripts/models/…` y `scenes/…` que ya no existen, y dice que no hay animaciones. La información sobre `CardCollection`, `HandLayout`, `DeckDisplay` e i18n sigue siendo válida, aunque esos archivos ahora están en `data/` y `game/hand/`.
- `docs/NETWORK-ARCHITECTURE.md` sigue siendo válido en cuanto al diseño (ApiClient, managers y señales), pero las rutas `scripts/core|managers/…` han cambiado a `shared/client/` y `managers/`.
- Otros documentos: `docs/AUTH_SYSTEM.md`, `docs/GameDesign.md` y `docs/GAMEPLAY-UX-QUICK-GUIDE.md`.
