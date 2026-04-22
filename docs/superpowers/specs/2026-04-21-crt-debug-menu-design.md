# CRT Debug Menu — Design Spec
_Date: 2026-04-21_

## Overview

In-game overlay para ajustar en tiempo real todos los parámetros del efecto CRT (moonshine). Accesible con `N` durante el gameplay. Los valores se guardan en disco y se recargan automáticamente al arrancar el juego.

---

## Architecture

### New file
`source/entities/UI/CRTDebugMenu.lua` — módulo standalone, sin dependencias de gameScene.

### Integration points in `main.lua`
- `require 'entities.UI.CRTDebugMenu'` al inicio
- `CRTDebugMenu.draw()` al final de `love.draw()`, después del bloque CRT (dibuja sobre la pantalla real, no sobre el canvas virtual)
- `CRTDebugMenu.keypressed(key)` al inicio de `love.keypressed()`, retorna `true` si consumió el evento
- Al final de `love.load()`, llamar `CRTDebugMenu.loadFromDisk()` para aplicar settings guardados

### Data flow
- El módulo lee/escribe directamente `moonshinSettings` y `crtEnabled` (globals definidos en `main.lua`)
- Llama `applyCRTSettings()` en cada cambio de valor para aplicar en tiempo real
- No duplica estado: es una vista sobre los globals existentes

---

## UI Layout

Panel fijo en el borde derecho de la pantalla real (no del canvas 400×240). Ancho ~220px, altura dinámica según número de parámetros.

```
┌─────────────────────────────┐
│  CRT DEBUG              [N] │
├─────────────────────────────┤
│  [●] CRT Enabled: ON        │
├─ SCANLINES ─────────────────┤
│  > Opacity   [████████░░] 0.80 │
│    Thickness [████░░░░░░] 0.50 │
│    Frequency [███████░░░] 240  │
│    Phase     [█░░░░░░░░░] 1.00 │
│    Width     [█████░░░░░] 0.50 │
├─ CRT ───────────────────────┤
│    Distortion[██░░░░░░░░] 1.02 │
│    Feather   [█░░░░░░░░░] 0.02 │
├─ CHROMASEP ─────────────────┤
│    Radius    [██░░░░░░░░] 2.00 │
│    Angle     [░░░░░░░░░░] 0.00 │
├─ GLOW ──────────────────────┤
│    Strength  [█████░░░░░] 5.00 │
│    Min Luma  [███████░░░] 0.70 │
├─────────────────────────────┤
│  [S] Guardar   [R] Reset    │
└─────────────────────────────┘
```

- Cursor `>` indica el ítem activo
- Barra de 10 bloques unicode (█ / ░) proporcional al valor
- Valor numérico a la derecha de la barra

---

## Parameters

### Toggle
| Param | Global | Values |
|---|---|---|
| CRT Enabled | `crtEnabled` | true/false |

### Scanlines (`moonshinSettings.scanlines`)
| Param | Key | Min | Max | Step | Shift Step |
|---|---|---|---|---|---|
| Opacity | opacity | 0 | 1 | 0.05 | 0.1 |
| Thickness | thickness | 0 | 5 | 0.1 | 0.5 |
| Frequency | frequency | 60 | 480 | 10 | 60 |
| Phase | phase | 0 | 6.28 | 0.1 | 0.5 |
| Width | width | 0 | 1 | 0.05 | 0.1 |

### CRT (`moonshinSettings.crt`)
| Param | Key | Min | Max | Step | Shift Step |
|---|---|---|---|---|---|
| Distortion | distortionFactor | 1.0 | 1.2 | 0.01 | 0.05 |
| Feather | feather | 0 | 0.1 | 0.005 | 0.02 |

### Chromasep (`moonshinSettings.chromasep`)
| Param | Key | Min | Max | Step | Shift Step |
|---|---|---|---|---|---|
| Radius | radius | 0 | 10 | 0.5 | 2 |
| Angle | angle | 0 | 6.28 | 0.1 | 0.5 |

### Glow (`moonshinSettings.glow`)
| Param | Key | Min | Max | Step | Shift Step |
|---|---|---|---|---|---|
| Strength | strength | 0 | 20 | 0.5 | 2 |
| Min Luma | min_luma | 0 | 1 | 0.05 | 0.1 |

---

## Navigation

| Key | Action |
|---|---|
| `N` | Abrir / cerrar overlay |
| `Escape` | Cerrar overlay |
| `↑` / `↓` | Mover cursor entre parámetros |
| `←` / `→` | Ajustar valor (paso normal) |
| `Shift + ←/→` | Ajustar valor (paso grande) |
| `A` / `Enter` | Toggle en CRT Enabled |
| `S` | Guardar a disco |
| `R` | Resetear todos a defaults del código |

---

## Save Format

Archivo: `crt_settings.lua` en `love.filesystem.getSaveDirectory()`.

```lua
-- CRT Debug Settings
-- Guardado: 2026-04-21 14:32:05
return {
    crtEnabled = true,
    scanlines = {
        opacity = 0.80,
        thickness = 0.50,
        frequency = 240,
        phase = 1.00,
        width = 0.50
    },
    crt = {
        distortionFactor = 1.02,
        feather = 0.02
    },
    chromasep = {
        radius = 2.00,
        angle = 0.00
    },
    glow = {
        strength = 5.00,
        min_luma = 0.70
    }
}
```

### Load behavior (`CRTDebugMenu.loadFromDisk`)
- Si `crt_settings.lua` existe: sobreescribe `moonshinSettings` y `crtEnabled`, llama `applyCRTSettings()`
- Si no existe: no hace nada, usa defaults de `main.lua`

---

## Out of scope
- Presets guardados por nombre
- Animación del panel (slide-in/out)
- Soporte gamepad para el debug menu
