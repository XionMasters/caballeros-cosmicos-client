# 🧪 TestBoard - Guía Rápida en Español

## ¿Qué Necesito Hacer?

### Paso 1: Abre el Juego
Ejecuta el cliente de Godot (Project → Run o F5)

### Paso 2: Abre la Consola
En Godot: **F8** para abrir Output Console

### Paso 3: Click en "🧪 Test"
En el menú principal, busca el botón con el emoji 🧪 en la barra de navegación y haz click

### Paso 4: Espera a que Carguen las Cartas
Deberías ver algo como:
```
[TEST] TestBoard._ready completado
[TEST] Solicitando mazos del usuario...
[TEST] Cargadas 7 cartas en la mano
```

Y en la pantalla verás 7 cartas en la zona central

### Paso 5: Haz Click en una Carta
Haz click con el mouse sobre cualquier carta

### Paso 6: Observa la Consola
¿Ves esto?
```
[TEST] CLICK: <nombre_de_la_carta>
```

- **SÍ**: ✅ El sistema funciona
- **NO**: ❌ Problema encontrado (reporta esto)

### Paso 7: Prueba Drag & Drop
Haz click y arrastra una carta hacia la zona roja a la derecha

### Paso 8: Observa la Consola Nuevamente
¿Ves esto?
```
[TEST] DRAG START
[TEST] DRAG END
```

- **SÍ**: ✅ El sistema funciona completamente
- **NO**: ❌ Drag no funciona (reporta esto)

---

## Qué Reportar

Copia y pega esto en tu reporte y complétalo:

```
RESULTADO DE TEST:

1. ¿Aparecen cartas al abrir TestBoard?
   [ ] Sí, 7 cartas cargadas
   [ ] Sí, pero con errores
   [ ] No, pantalla en blanco

2. ¿Funciona hacer click?
   [ ] Sí, veo [TEST] CLICK: ...
   [ ] No, nada sucede

3. ¿Funciona dragging?
   [ ] Sí, veo [TEST] DRAG START y [TEST] DRAG END
   [ ] No, nada sucede

4. Copia todos los logs de la consola aquí:
[LOGS AQUÍ]
```

---

## Botones Disponibles en TestBoard

| Botón | Qué Hace |
|-------|----------|
| **🔙 Back** | Vuelve al menú principal |
| **🗑️ Clear** | Borra todas las cartas de la mano |
| **🔄 Reload** | Recarga las cartas del servidor |

---

## Errores Comunes

### "No veo las cartas"
```
Intenta:
1. Click en "Reload"
2. Si sigue sin funcionar, revisa:
   - ¿Estás autenticado? (¿Viste el login?)
   - ¿Tienes decks? (¿Creaste un deck en la web?)
   - Click "Back" y vuelve al TestBoard
```

### "La consola está vacía"
```
Intenta:
1. F8 para asegurar que la consola está abierta
2. Click en "Reload" en TestBoard
3. Revisa si aparecen logs de carga
```

### "Veo logs pero no de clicks"
```
Esto es exactamente lo que queremos debuggear.
Reporta: "Los logs de carga aparecen pero [TEST] CLICK no aparece"
```

---

## En Resumen

1. ✅ Abre el juego
2. ✅ Abre la consola (F8)
3. ✅ Click en 🧪 Test
4. ✅ Haz click en una carta
5. ✅ Mira si ves `[TEST] CLICK:`
6. ✅ Reporta lo que ves

---

**¡Eso es todo! Los logs te dirán si el sistema funciona o no.**
