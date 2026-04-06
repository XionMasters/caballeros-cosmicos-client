# Caballeros Cosmicos - Documento Principal de Diseno

## Objetivo del Documento
Este archivo define las reglas base del juego para diseno, implementacion y pruebas.
Es la fuente principal de verdad para mecanicas de partida 1v1.

## Resumen Rapido
- Formato base: 1v1, mazos de 40 cartas.
- Vida inicial del jugador (PLP): 12.
- Recurso principal: cosmos del jugador (PCP).
- Victoria base: bajar PLP rival a 0.

## Tipos de Cartas y Funcion

Valores internos de backend/cliente (en ingles):
- `knight` -> Caballero
- `technique` -> Tecnica
- `item` -> Objeto
- `stage` -> Escenario
- `helper` -> Ayudante
- `event` -> Ocasion

### Caballero (`knight`)
- Unidad principal de combate.
- Tiene estadisticas de combate y puede cambiar de postura.
- Puede atacar con BA o usar TA si tiene tecnica compatible.

### Tecnica (`technique`)
- Habilita ataques tecnicos (TA) y/o efectos.
- Requiere compatibilidad con el caballero que la use.
- Permanece en el area de soporte mientras este activa.

### Objeto (`item`)
- Modificador para una carta/unidad objetivo.
- Suele otorgar bonos o efectos persistentes.

### Escenario (`stage`)
- Regla global que afecta a ambos jugadores.
- Solo puede existir 1 escenario activo en la partida.

### Ayudante (`helper`)
- Soporte propio del jugador con efecto continuo o activable.
- Cada jugador puede tener solo 1 ayudante activo.

### Ocasion (`event`)
- Efecto instantaneo.
- Se resuelve al jugarse y luego va a Yomotsu, salvo que el texto diga exiliar.

## Sistema de Energia (Cosmos)

### Recurso del Jugador
- Nombre: PCP (Player Cosmos Points).
- Ganancia base: +1 PCP al inicio de tu turno.
- Maximo recomendado: 10 PCP.
- Persistencia: el PCP restante no se reinicia al cambiar turno.

### Gastos de Cosmos
- Jugar cartas desde mano (caballero, tecnica, objeto, ayudante, escenario, ocasion).
- Activar habilidades que indiquen costo de cosmos.

### Recurso del Caballero
- Algunas cartas tambien usan CP propio del caballero para habilidades especificas.
- Si una habilidad requiere CP del caballero, no consume PCP salvo que lo indique.

## Combate: Ataque, Defensa, Posturas y Danio

## Convenciones de Valores
- `Ce`: capacidad de ataque del caballero.
- `Ar`: armadura/defensa del caballero.
- `Lp`: vida de la unidad.
- `PLP`: vida del jugador.

### Tipos de Ataque
- BA (Basic Attack): ataque basico del caballero.
- TA (Technique Attack): ataque que usa una tecnica compatible.

### Posturas
- Normal: estado por defecto.
- Defensa (Block): reduce el ataque recibido usando media CE del atacante.
- Evasion (Evade): contra BA, tiene 50% de probabilidad de evitar el impacto completo.

Reglas clave:
- Evasion solo aplica a BA.
- Block aplica a BA y TA.
- Danio minimo por impacto exitoso: 1.

### Formula de Danio
Normal:
`danio = Ce_atacante - Ar_defensor`

Defensa (Block):
`danio = (Ce_atacante / 2) - Ar_defensor`

Aplicacion final:
- Si el resultado es menor o igual a 0 y el ataque conecto, el danio aplicado es 1.

### Ejemplo
Si un caballero con `Ce = 10` ataca a uno con `Ar = 8`:
- En normal: `10 - 8 = 2` danio.
- En defensa: `(10 / 2) - 8 = -3` -> danio final `1`.

## Yomotsu y Cositos

### Yomotsu (cementerio)
- Zona de descarte normal.
- Van aqui cartas usadas, destruidas o descartadas por reglas generales.

### Cositos (exilio)
- Zona de removido de partida.
- Se usa para efectos que dicen exiliar/remover.
- Por defecto, una carta en Cositos no vuelve al mazo/hand salvo efecto explicito.

## Limites de Campo y Zonas

Por jugador:
- Caballeros en campo: maximo 5.
- Ayudantes: maximo 1.
- Soporte (tecnicas/objetos): hasta 5 espacios de soporte.
- Mano: maximo 7.

Compartido:
- Escenario global: maximo 1 activo en toda la partida.

Notas:
- Si una regla de carta contradice estos limites, prevalece el texto de la carta.
- No se permiten caballeros duplicados en campo del mismo jugador (regla de diseno actual).

## Estructura del Turno (Fases)

1. Inicio
- Ganar +1 PCP.
- Robar 1 carta.
- Resolver efectos de inicio de turno.

2. Principal
- Jugar cartas pagando cosmos.
- Activar habilidades permitidas en fase principal.
- Cambiar posturas de unidades que puedan hacerlo.

3. Combate
- Declarar BA o TA con caballeros habilitados.
- Rival responde con efectos defensivos validos.
- Resolver impacto, postura, formula y efectos secundarios.

4. Cierre
- Resolver efectos de fin de turno.
- Limpiar efectos temporales.
- Verificar condicion de victoria.

## Condiciones de Victoria
- Un jugador gana cuando el PLP rival llega a 0.
- Pueden existir victorias alternativas por efecto de carta.

## Estado del Documento
Version: Abril 2026.
Este documento define la base jugable actual y puede refinarse con resultados de testing.

## Documentos Relacionados
- Guia UX rapida para cliente: docs/GAMEPLAY-UX-QUICK-GUIDE.md
- Guia tecnica de reglas para backend: ../../Server-SS/docs/GAMEPLAY-RULES-TECHNICAL.md

