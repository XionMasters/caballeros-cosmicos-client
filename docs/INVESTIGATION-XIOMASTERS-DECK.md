# Investigación: Usuario XionMasters sin Mazo Activo

**Fecha**: 22 de Diciembre de 2025  
**Usuario**: XionMasters (ID: `9788e4d5-5d8a-4dad-b914-af0ce8b44c10`)  
**Problema Reportado**: El usuario no tiene un mazo activo asignado

## 🔍 Hallazgos

### Estado en la Base de Datos ✅

**Usuario EXISTS**: 
- ID: `9788e4d5-5d8a-4dad-b914-af0ce8b44c10`
- Username: `XionMasters`
- Email: `aebief@hotmail.com`
- Creado: 2025-11-17T14:18:54.266Z

**Mazos (Decks)**: ✅ 1 mazo existe
- ID: `94fc5bec-dbc4-43cc-a78a-6aebc0a991f0`
- Nombre: "Deck Inicial - Caballeros de Athena"
- `is_active`: **true** ✅
- Creado: 2025-11-17T17:18:57.594Z

**Cartas del Usuario**: ✅ 27 cartas
**Cartas en Mazos**: ✅ 18 cartas en el mazo activo

**CONCLUSIÓN**: El usuario está **completamente configurado** en la BD.

---

## 🐛 Problema Detectado: Race Condition en el Cliente

### El Flujo Actual (INCORRECTO)

```
TestBoard._ready()
  ↓
launch_test_match()
  ↓
_fetch_active_deck()
  ↓
DecksManager.get_active_deck()  ← ❌ FALLA AQUÍ
  ↓
Devuelve {} (diccionario vacío)  ← Porque _active_deck nunca fue inicializado
```

### ¿Por qué falla?

1. **DecksManager es un autoload** que se inicializa sin cargar datos
2. **`get_active_deck()` devuelve `_active_deck`** que está vacío por defecto
3. **Nunca se llamó a `fetch_user_decks()`** para llenar ese diccionario
4. **El cliente cree que no hay mazo**, aunque la BD tiene uno

### El Código Problemático

**Archivo**: `scripts/game/TestBoard.gd`, línea 188

```gdscript
func _fetch_active_deck() -> void:
	print("[TestBoard] 1️⃣ Obteniendo mazo activo...")
	
	if not DecksManager:
		_show_error("DecksManager no disponible")
		_is_loading = false
		return
	
	# ❌ PROBLEMA: get_active_deck() devuelve {} si no se llamó fetch_user_decks()
	var deck = DecksManager.get_active_deck()
	
	if not deck or deck.is_empty():
		print("[TestBoard] ⚠️ No hay mazo activo, creando starter deck automáticamente...")
		_create_starter_deck()  # ← Intenta crear uno nuevo (pero ya existe)
		return
	
	_validate_and_start_match(deck)
```

## ✅ La Solución

**En `_fetch_active_deck()`**, se debe:
1. Primero llamar a `DecksManager.fetch_user_decks()` para cargar desde el servidor
2. Esperar a que cargue (signal `decks_loaded`)
3. LUEGO llamar a `get_active_deck()`

O alternativa más eficiente:
- **Implementar `DecksManager.fetch_active_deck_only()`** que directamente obtiene el mazo activo del servidor sin cargar todos

---

## 🔧 Recomendaciones

### Corto Plazo (Hotfix)
Modificar `_fetch_active_deck()` en TestBoard.gd para:
```gdscript
func _fetch_active_deck() -> void:
	# Primero cargar todos los mazos del servidor
	await DecksManager.decks_loaded
	
	# Luego obtener el mazo activo
	var deck = DecksManager.get_active_deck()
	
	if not deck or deck.is_empty():
		_create_starter_deck()
		return
	
	_validate_and_start_match(deck)
```

### Mediano Plazo (Mejor Arquitectura)
1. Crear `DecksManager.fetch_active_deck_only()` que obtiene SOLO el mazo activo
2. Esto es más eficiente que cargar todos los mazos cada vez
3. Actualizar TestBoard para usar esa nueva función

### Largo Plazo (Robustez)
1. Implementar retry logic si el mazo no existe
2. Agregar timeout para detectar cuando el servidor no responde
3. Loguear claramente qué estado tiene el usuario en el cliente vs servidor

---

## Conclusión

**El usuario XionMasters tiene su starter deck correctamente en la BD.**

El problema es una **carrera de condiciones en el cliente Godot** donde se intenta obtener el mazo activo antes de que DecksManager lo haya cargado del servidor.

La solución es hacer que `_fetch_active_deck()` espere a que `DecksManager.fetch_user_decks()` complete antes de llamar a `get_active_deck()`.
