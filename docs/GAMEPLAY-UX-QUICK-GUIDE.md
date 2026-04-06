# Caballeros Cosmicos - Guia UX Rapida de Partida

## Para quien es
Diseno UX, UI y QA manual del cliente Godot.

## Resumen en 30 segundos
- Partida 1v1.
- Vida inicial: 12.
- Recurso principal: cosmos.
- Objetivo: bajar la vida rival a 0.

## Tipos de carta (mostrar asi en UI)
- Caballero: unidad principal para combatir.
- Tecnica: habilita ataques tecnicos o efectos para caballeros compatibles.
- Objeto: mejora una unidad/carta objetivo.
- Escenario: efecto global para ambos jugadores.
- Ayudante: soporte propio del jugador (1 maximo).
- Ocasion: efecto instantaneo, se resuelve y sale del campo.

## Zonas que el jugador entiende
- Mazo
- Mano
- Campo de Caballeros (5 slots)
- Campo de Soporte/Tecnicas (5 slots)
- Ayudante (1 slot)
- Escenario global (1 activo total)
- Yomotsu (cementerio)
- Cositos (exilio)

## Cosmos en UI
- Mostrar cosmos actual y maximo visible.
- Al inicio de turno: +1 cosmos.
- Gastar cosmos al jugar cartas o activar habilidades.
- Si existe accion Cargar Cosmos, mostrar feedback claro de +3.

## Combate en UX

### Tipos de ataque
- BA: ataque basico.
- TA: ataque con tecnica compatible.

### Posturas visuales
- Normal
- Defensa
- Evasion

### Reglas que deben verse claras
- Defensa reduce dano.
- Evasion puede evitar impacto.
- Dano minimo por impacto exitoso: 1.

## Turno en UI (orden recomendado)
1. Inicio: ganar cosmos, robar carta, resolver efectos de inicio.
2. Principal: jugar cartas, activar habilidades, cambiar posturas.
3. Combate: declarar ataques y resolver dano.
4. Cierre: limpiar temporales y verificar victoria.

## Mensajes UX obligatorios
- No es tu turno.
- No hay cosmos suficiente.
- Slot ocupado o invalido.
- Objetivo invalido.
- Accion rechazada por servidor.
- Conexion perdida / reconectando.

## Recomendaciones de claridad
- Diferenciar visualmente Yomotsu vs Cositos.
- Etiquetar posturas en carta con icono + texto corto.
- Confirmacion ligera para acciones irreversibles (sacrificar, exiliar).
- Mostrar resultado de combate con: atacante, defensor, dano, evasion si aplica.

## QA manual rapido
- Verificar limites de campo (5/1/5).
- Verificar mano maxima de 7.
- Verificar +1 cosmos al inicio de turno.
- Verificar flujo completo de un ataque y refresco por match_update.
- Verificar que oponente vea dorso de mano y no contenido real.

## Estado del documento
Version UX: Abril 2026.
