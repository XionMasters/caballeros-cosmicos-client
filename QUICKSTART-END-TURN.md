# ⚡ QUICKSTART: Botón "Pasar Turno" - 3 Pasos

## Paso 1: Opcional - Generar Imagen (5 min)

Si quieres que el botón se vea bonito con imagen IA:

```
1. Ve a: https://www.bing.com/images/create
2. Pega este prompt:
   Saint Seiya style icon for end turn button, glowing golden arrow pointing forward with cosmos energy burst, metallic shine with bronze finish, transparent background, sacred geometry patterns, ancient Greek aesthetic, high quality, 128x128px, vibrant colors, cosmic particles around the arrow, professional game UI icon
3. Descarga imagen en PNG
4. Coloca en: ccg/assets/ui-icons/end_turn_button.png
5. Reinicia Godot
```

**O salta este paso** - funciona con fallback "▶"

## Paso 2: Verifica en Godot

```
1. Abre: ccg/game/match/GameMatch.tscn
2. El botón debe estar visible en TopRightPanel (esquina arriba-derecha)
3. Deberías ver en logs:
   [GameMatch] ✅ End Turn button configurado
```

## Paso 3: Prueba en Partida TEST

```
1. Crea una partida TEST
2. Tu turno → Botón está habilitado (blanco)
3. Haz clic en botón → Pasa el turno
4. Rival: Sus CARTAS se revelan (no dorsos) ✨
5. Rival juega su turno
6. Rival hace clic en botón → Vuelve a ti
```

---

## ✅ Listo!

**Comportamiento en partidas:**

- **TEST mode:** Cartas del rival se revelan cuando es su turno 🧪
- **PVP normal:** Solo esperas al rival 

**Con imagen:** Se ve profesional  
**Sin imagen:** Funciona con "▶" en texto

---

## Documentación Completa

Si necesitas más detalles:
- `END-TURN-BUTTON-IMPLEMENTATION.md` - Técnico
- `SUMMARY-END-TURN-IMPLEMENTATION.md` - Resumen
- `HOW-TO-GENERATE-END-TURN-BUTTON-IMAGE.md` - Generar imagen
