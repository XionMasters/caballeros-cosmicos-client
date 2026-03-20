# 🎯 Caballeros Cósmicos - Especificación del Juego

## 📖 Descripción General

**Caballeros Cósmicos** es un juego de cartas coleccionables digital inspirado en el universo de los Caballeros del Zodiaco, desarrollado como proyecto de hobby personal. Dos jugadores se enfrentan utilizando mazos de 40 cartas, desplegando caballeros, técnicas, objetos y ayudantes en un campo de batalla estratégico por turnos.

---

## 🃏 Tipos de Cartas

### 1. 🛡️ Caballeros
- **Atributos**: Ataque, Defensa, Vida, Cosmos
- **Características**:
  - Pueden tener 1-3 habilidades (activas o pasivas)
  - Pueden entrar en modo defensivo (reciben 50% menos daño, pero no pueden atacar)
  - No se permiten duplicados en el campo
- **Ejemplo**: Seiya de Pegaso, Shiryu de Dragón

### 2. ⚡ Técnicas
- **Función**: Efectos específicos para ciertos caballeros o grupos
- **Restricción**: Compatible solo con caballeros específicos
- **Ejemplo**: "Meteoros de Pegaso" (solo para caballeros de Pegaso)

### 3. 🏺 Objetos
- **Función**: Bonificaciones equipables a caballeros
- **Límite**: 1 objeto por caballero
- **Ejemplo**: "Armadura de Bronce" (+50 de defensa)

### 4. 🏛️ Escenarios
- **Función**: Efectos globales que afectan a ambos jugadores
- **Regla**: Solo un escenario activo a la vez
- **Ejemplo**: "Campo de Energía" (nadie puede entrar en modo defensivo)

### 5. 🤝 Ayudantes
- **Función**: Efectos unilaterales (solo para tu campo)
- **Regla**: Un ayudante activo por jugador
- **Ejemplo**: "Caballero Dorado de Leo" (+1 cosmos a tus caballeros de Athena)

### 6. ⭐ Ocasiones
- **Función**: Efectos instantáneos (como magias)
- **Uso**: Se resuelve inmediatamente y se descarta
- **Ejemplo**: "Refugio de Athena" (+2 defensa a todos tus caballeros este turno)

---

## 🎮 Reglas del Juego

### 🏟️ Estructura del Tablero

Cada jugador tiene:
- **5 espacios** para caballeros
- **1 espacio** para ayudante
- **5 espacios** para técnicas/objetos activos
- **1 espacio** de ocasión (se resuelve y descarta)
- **Mazo** (40 cartas)
- **Mano** (máximo 7 cartas)
- **Yomotsu** (descarte normal)
- **Cositos** (descarte especial/exilio)

### ⚡ Sistema de Energía Cósmica

- **Acumulación**: +1 por turno (máximo 10)
- **Persistencia**: No se reinicia automáticamente
- **Uso**: Pagar costos de cartas

### 🚫 Restricciones

- **Mano**: Máximo 7 cartas (descartar si se excede al inicio del turno)
- **Caballeros**: No puede haber duplicados en campo
- **Acciones por turno**: Cada caballero puede realizar una acción (atacar, usar técnica, o activar habilidad que consuma turno)

### 📚 Convenciones y abreviaturas
- `Ar` — Armadura / Defensa del caballero (reduce daño recibido).
- `Ce` — Combate / Capacidad de ataque del caballero (valor base de daño en ataques).
- `Cp` — Cosmos Points del caballero (recurso interno de la carta para técnicas u habilidades).
- `Lp` — Life Points del caballero (vida individual del caballero en tablero).
- `PLP` — Player Life Points (vida del jugador; si llega a 0, pierde la partida).
- `PCP` — Player Cosmos Points (recursos del jugador para jugar cartas o activar habilidades a nivel de jugador).

Usar estas abreviaturas en reglas y ejemplos para mantener consistencia en el documento y en el cliente.

### 🗡️ Ataques: BA (Basic Attack) vs TA (Technique Attack)
- `BA` (Basic Attack): ataque básico que realiza un caballero sin requerir cartas adicionales. Se calcula con la estadística `Ce` del atacante.
- `TA` (Technique Attack): requiere una carta de `Technique` compatible jugada; puede tener efectos adicionales. El caballero debe ser compatible con la técnica.

Reglas específicas:
- Evasión (`Evade`) afecta solo a `BA`. Cuando un caballero está en `Evasion`, los `BA` tienen un 50% de probabilidad de fallar (mecánica de moneda: cara = golpe, cruz = falla).
- Las `TA` no son afectadas por `Evasion`: si el ataque procede, impacta según cálculos normales (es decir, las técnicas conectan incluso contra evasión).
- El `Modo Defensivo` (Block) sí afecta tanto a `BA` como a `TA` (reduce el daño según la fórmula de defensa).

Fórmulas de daño (orden de cálculo):
- **Normal**: damage = Ce_atacante - Ar_defensor
- **Block (Modo Defensa)**: damage = (Ce_atacante / 2) - Ar_defensor
- **Daño mínimo**: si el resultado <= 0, se aplica daño mínimo = 1

Ejemplo:
```
Seiya (Ce: 10) BA ataca a Shiryu (Ar: 8) en modo normal:
- damage = 10 - 8 = 2 → Shiryu pierde 2 Lp

Si Shiryu está en Modo Defensa:
- damage = (10/2) -8 = 5 - 8 = -3 → aplica daño mínimo = 1 → Shiryu pierde 1 Lp
```

### 🔄 Flujo del Turno

#### Fases del Turno:
1. **Inicio**: Ganar +1 energía, robar carta, aplicar efectos de inicio
2. **Principal**: Jugar cartas, activar habilidades, cambiar posturas
3. **Ataque**: Los caballeros en postura ofensiva pueden atacar
4. **Defensa**: El oponente puede activar defensas
5. **Fin**: Limpiar efectos temporales, verificar condiciones de victoria

### 🏆 Condiciones de Victoria

- Reducir los **12 puntos de vida** del oponente a 0
- Efectos especiales de cartas que establezcan victoria alternativa

---

## ⚔️ Mecánicas de Combate

### 🛡️ Modo Defensivo
- **Ventaja**: Reduce el daño recibido aplicando la fórmula de `Block` (ver arriba).
- **Desventaja**: El caballero en modo defensivo no puede atacar mientras mantiene la postura.
- **Activación**: Consumirá la acción del turno del caballero.

### 📝 Efectos Múltiples

Las cartas pueden tener múltiples efectos simultáneos:

```json
"efectos": [
  { "tipo": "bono_defensa", "valor": 50 },
  { "tipo": "mod_vida", "valor": -20 }
]
```

### 🔗 Compatibilidad de Técnicas
Las técnicas pueden ser usadas por varios caballeros compatibles:
- **Ejemplo**: "Meteoros de Pegaso" puede ser usada por Seiya y Tenma

---

## � Características de Diseño

### ⚖️ Balance
- Costos de energía proporcionales al poder de las cartas
- Límites estrictos en número de cartas en campo para evitar acumulaciones excesivas
- Sinergias entre facciones (Athena, Hades, etc.)

### 🧠 Estrategia
- **Gestión de recursos** (energía vs. poder de cartas)
- **Elección de posturas** (ofensiva vs. defensiva)
- **Construcción de mazos** temáticos o mixtos

---

*Este documento representa la visión base del juego, sujeta a ajustes durante el desarrollo y testing.*

---

## 💎 Sistema de Colección

### 🌟 Rarezas
```typescript
interface CardRarity {
  nivel: "común" | "rara" | "épica" | "legendaria";
  efectos_exclusivos: string[];
  arte_alternativo: boolean;
  brillo_animado: boolean;
}
```

### 🔓 Sistema de Desbloqueo
- **Logros**: "Gana 10 partidas con caballeros de Athena"
- **Misiones diarias**: "Juega 3 cartas de ocasión"
- **Progresión por experiencia**: Subir de nivel desbloquea cartas especiales

### 🎭 Estados Alterados
- **Veneno**: -1 de vida por turno durante x turnos
- **Congelado**: No puede atacar ni  utilizar habilidades por x turno 
- **Quemado**: -2 de vida al actuar
- **Bendito**: +1 en todas las estadísticas
- **Paralizado**: Igual que congelado por ahora

---

## 🏆 Modos de Juego

### 🎲 Modos Principales
- **Clásico**: Partidas estándar 1v1
- **Clasificatoria**: Sistema de ranking competitivo
- **Casual**: Partidas sin afectar ranking

### 🎪 Modos Especiales
- **Draft**: Construir mazo al azar con cartas random
- **Solo Caballeros**: Solo se permiten cartas de caballeros
- **Modo Historia**: Campaña con mazos predefinidos y narrativa
- **Desafíos semanales**: Reglas especiales rotativas

---

## ⚔️ Resolución de Combate Detallada

### 🎯 Orden de Resolución:
1. **Declarar ataques**
2. **Activar habilidades de defensa**
3. **Aplicar modificadores** (objetos, técnicas)
4. **Calcular daño final**
5. **Aplicar efectos secundarios**

### 📊 Ejemplo de Combate:
```
Seiya (ATK: 100) ataca a Shiryu (DEF: 80, Modo Defensivo)
- Daño base: 100 - 80 = 20
- Modo defensivo: 20 * 0.5 = 10
- Shiryu pierde 10 de vida
```

---

## 🎨 Interfaz de Usuario

### 📱 Pantallas Principales
- **Colección de cartas**: Filtros por tipo, rareza, facción
- **Constructor de mazos**: Drag & drop, validación de 40 cartas
- **Campo de batalla**: Zonas claramente marcadas
- **Tienda de sobres**: Con preview de probabilidades

### ✨ UX Crítico
- Tooltips detallados al hacer hover sobre cartas
- Animaciones suaves para transiciones
- Feedback visual para acciones válidas/inválidas
- Sistema de ayuda contextual

---

## 🛠️ Implementación Técnica

### 🎮 Cliente (Godot)
- **Escenas modulares** por pantalla
- **Sistema de estados** para el juego
- **Animaciones** con Tween
- **Audio dinámico** y efectos visuales

### 🖥️ Servidor (Node.js)
- **WebSockets** para tiempo real
- **Sistema de matchmaking**
- **Validación de movimientos** server-side
- **Logging de partidas** para balance

---

## 🔮 Futuras Expansiones

### 📦 Contenido Planificado
- **Santuario**: Base inicial
- **Saga de Poseidón**: Generales Marinos
- **Saga de Hades**: Espectros del Inframundo
- **Saga de Asgard**: Guerreros Divinos
- **Lost Canvas**: Caballeros alternativos

### 🆕 Mecánicas Futuras
- **Torneos Automatizados**: Brackets de eliminación

