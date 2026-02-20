# 🎨 Instrucciones: Generar Imagen del Botón "End Turn"

## Opción Rápida (Recomendado)

### Usar Microsoft Designer (Gratis, DALL-E 3)

1. **Abre:** https://www.bing.com/images/create

2. **Copia el prompt:**
```
Saint Seiya style icon for end turn button, glowing golden arrow pointing forward with cosmos energy burst, metallic shine with bronze finish, transparent background, sacred geometry patterns, ancient Greek aesthetic, high quality, 128x128px, vibrant colors, cosmic particles around the arrow, professional game UI icon
```

3. **Pega en el cuadro** y presiona "Create"

4. **Espera** a que genere 4 imágenes

5. **Selecciona** la que te guste (preferiblemente con:
   - ✅ Flecha dorada clara
   - ✅ Fondo transparente o degradado oscuro
   - ✅ Partículas de energía alrededor
   - ✅ Aspecto "Saint Seiya"

6. **Descarga:** Botón derecho → "Save image"

7. **Coloca en:** `ccg/assets/ui-icons/end_turn_button.png`

8. **Reinicia Godot** - ¡La imagen debería aparecer!

---

## Opciones Alternativas

### Leonardo.ai (150 tokens gratis/día)
- **URL:** https://leonardo.ai
- **Ventaja:** Mejor control de estilos
- **Desventaja:** Requiere cuenta

### Ideogram (100 imágenes gratis/mes)
- **URL:** https://ideogram.ai
- **Ventaja:** Excelente para iconos
- **Desventaja:** Límite mensual

### Midjourney / DALL-E Plus (De Pago)
- **Mejor calidad** pero requiere suscripción ($10-20/mes)

---

## Si No Quieres Generar Ahora

El botón **funcionará igualmente** con fallback:
- Mostrará un símbolo "▶" (flecha de texto)
- El comportamiento será idéntico
- Simplemente no tan bonito 😊

Puedes generar la imagen más tarde y actualizarla.

---

## Checklist Final

- [ ] Imagen descargada en PNG
- [ ] Tamaño: 128x128 pixels (si no, no importa, Godot lo escalará)
- [ ] Fondo transparente (importante para verse bien)
- [ ] Colocada en: `ccg/assets/ui-icons/end_turn_button.png`
- [ ] Godot reiniciado
- [ ] Botón visible en GameMatch (esquina superior derecha)

---

**¿Problemas?**

Si la imagen no aparece:
1. Verifica la ruta exacta: `res://assets/ui-icons/end_turn_button.png`
2. Asegúrate que es PNG (no JPG)
3. En Godot, haz refresh: File → Reload Current Scene
4. Revisa los logs de Godot (debería mostrar si carga o no)

El comando de Godot para verificar será algo como:
```
[GameMatch] ✅ Imagen del botón End Turn cargada
```

Si ves esto, ¡está listo! ✨
