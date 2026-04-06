# Input Bindings — Design Spec
**Date:** 2026-04-04
**Status:** Approved

## Problem

Los bindings de input están dispersos en múltiples archivos:
- `main.lua` define la tabla `Input` y las funciones `Input.is()` / `Input.isDown()`
- `DanceScene.lua` tiene su propio `keyMap` hardcodeado que bypasea el sistema `Input`
- Las acciones de gameplay usan nombres semánticos granulares (`confirm`, `action`, `flash`, `dash`) en vez de un modelo de botones abstracto, lo que dificulta soportar gamepad y remapear controles

## Goal

Un único archivo editable donde estén definidos todos los controles del juego, usando un modelo de **dos botones de gameplay (AButton / BButton)** más navegación y teclas de dev. El resto del código usa la misma API `Input.is()` / `Input.isDown()`.

## Button Model

| Botón | Rol |
|-------|-----|
| **AButton** | Confirmar, avanzar diálogos. Hold ≥ 0.5s → abrir menú de equipo |
| **BButton** | Activar item equipado (dash/flash/plungerang/etc.) · Cancelar/cerrar en menús |
| **pause** | Pausar / abrir PauseMenu (Escape, sin cambio) |
| **resize** | Placeholder del crank de Playdate (tecla `e`, temporal) |
| **up/down/left/right** | Movimiento y navegación de menús (sin cambio) |

La lógica de qué hace BButton en juego la resuelve el sistema de items existente — el input solo dice "se presionó B".

## New File

**`source/assets/data/InputBindings.lua`**

```lua
-- ── GAMEPLAY ──────────────────────────────────────────────────
AButton = {"z", "return", "space"},
BButton = {"x"},

-- ── NAVIGATION ────────────────────────────────────────────────
up    = {"w", "up"},
down  = {"s", "down"},
left  = {"a", "left"},
right = {"d", "right"},

-- ── SYSTEM ────────────────────────────────────────────────────
pause  = {"escape"},
resize = {"e"},   -- crank placeholder

-- ── DEV / WINDOW ──────────────────────────────────────────────
toggleCRT  = {"q"},
fullscreen = {"f"},
res1 = {"1"}, res2 = {"2"}, res3 = {"3"},

-- ── DANCE SCENE ───────────────────────────────────────────────
danceKeys = {
    ["return"] = "aButton",  ["space"]  = "aButton",
    ["lshift"] = "bButton",  ["rshift"] = "bButton",
    ["left"]   = "leftButton", ["right"] = "rightButton",
    ["up"]     = "upButton",   ["down"]  = "downButton",
},
```

Más las funciones `Input.is(key, action)` e `Input.isDown(action)` (movidas desde `main.lua`).

## Hold Detection (AButton → menú)

En `main.lua:love.update(dt)`:
- Acumula `holdTimer` mientras `Input.isDown("AButton")` sea true
- Cuando `holdTimer >= 0.5`, dispara apertura del menú de equipo y resetea el timer
- Se resetea también en `love.keyreleased` cuando se suelta AButton
- Solo activo cuando el juego está en estado normal (no en diálogo, no en pausa)

## Action Mapping (antes → después)

| Código existente | Reemplazar por |
|-----------------|----------------|
| `Input.is(key, "confirm")` | `Input.is(key, "AButton")` |
| `Input.is(key, "menuConfirm")` | `Input.is(key, "AButton")` |
| `Input.is(key, "action")` | `Input.is(key, "BButton")` |
| `Input.is(key, "flash")` | `Input.is(key, "BButton")` |
| `Input.is(key, "dash")` | `Input.is(key, "BButton")` |
| `Input.is(key, "menuBack")` | `Input.is(key, "BButton")` |
| `Input.is(key, "menu")` | hold AButton (ver sección anterior) |
| `Input.is(key, "pause")` | sin cambio |
| `Input.is(key, "resize")` | sin cambio |
| `Input.isDown("up/down/left/right")` | sin cambio |

## Files Changed

| Archivo | Cambio |
|---------|--------|
| `source/assets/data/InputBindings.lua` | **NUEVO** — todo centralizado aquí |
| `source/main.lua` | Elimina tabla `Input` y helpers; `Input = require`; agrega hold timer en `update` y `keyreleased` |
| `source/scenes/DanceScene.lua` | Reemplaza `local keyMap` por `Input.danceKeys` |
| `source/scenes/gameScene.lua` | `confirm`/`action`/`flash`/`dash`/`menu`/`menuBack` → `AButton`/`BButton`/hold |
| `source/scenes/titleScene.lua` | `menuConfirm`/`menuBack` → `AButton`/`BButton` |
| `source/PauseMenu.lua` | `confirm`/`menuBack` → `AButton`/`BButton` |
| `source/entities/UI/InGameMenu.lua` | `left`/`right` → sin cambio (navegación) |
| `source/entities/UI/ComicPlayer.lua` | `menuConfirm`/`menuBack` → `AButton`/`BButton` |

## What Does NOT Change

- API `Input.is()` e `Input.isDown()` — idéntica
- Sistema de gamepad en `main.lua`
- Lógica de qué hace cada item cuando se presiona BButton
- Teclas de dev (`toggleCRT`, `fullscreen`, `res1/2/3`)

## Success Criteria

- Un solo archivo para editar cualquier binding de teclado
- `DanceScene` usa el mismo sistema `Input` que el resto
- Hold AButton abre el menú de equipo
- Cero cambios funcionales en el comportamiento del juego
