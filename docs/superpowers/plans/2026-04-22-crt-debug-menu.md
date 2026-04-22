# CRT Debug Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Agregar un overlay de debug en-juego (tecla `N`) que permita ajustar todos los parámetros moonshine CRT en tiempo real y guardarlos a disco.

**Architecture:** Módulo standalone `CRTDebugMenu.lua` sin dependencias de escenas. Se integra en `main.lua` (draw sobre pantalla real, keypressed antes del scene routing). Lee/escribe directamente los globals `moonshinSettings` y `crtEnabled` y llama `applyCRTSettings()` en cada cambio.

**Tech Stack:** LÖVE 11.5 / LuaJIT, moonshine post-processing (ya integrado), `love.filesystem` para persistencia.

---

## File Map

| Acción | Archivo | Responsabilidad |
|---|---|---|
| CREATE | `source/entities/UI/CRTDebugMenu.lua` | Módulo completo: estado, draw, input, save/load |
| MODIFY | `source/main.lua` | require + 3 call sites (draw, keypressed, loadFromDisk) |

---

## Task 1: Skeleton + hooks en main.lua

**Files:**
- Create: `source/entities/UI/CRTDebugMenu.lua`
- Modify: `source/main.lua`

- [ ] **Step 1: Crear el archivo skeleton**

Crear `source/entities/UI/CRTDebugMenu.lua` con este contenido:

```lua
local CRTDebugMenu = {}

local visible = false

function CRTDebugMenu.draw()
    if not visible then return end
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.print("CRT DEBUG [N cerrar]", love.graphics.getWidth() - 200, 10)
    love.graphics.setColor(1, 1, 1, 1)
end

function CRTDebugMenu.keypressed(key)
    if key == "n" then visible = not visible; return true end
    if not visible then return false end
    if key == "escape" then visible = false end
    return true
end

function CRTDebugMenu.loadFromDisk() end

return CRTDebugMenu
```

- [ ] **Step 2: Hookear en main.lua — require**

En `source/main.lua`, en la línea 1 (después de `local moonshine = require "libraries/moonshine"`), agregar:

```lua
local CRTDebugMenu = require 'entities.UI.CRTDebugMenu'
```

- [ ] **Step 3: Hookear en main.lua — loadFromDisk en love.load**

En `love.load()`, inmediatamente después de la llamada a `applyCRTSettings()` (línea ~120), agregar:

```lua
CRTDebugMenu.loadFromDisk()
```

- [ ] **Step 4: Hookear en main.lua — draw al final de love.draw**

En `love.draw()`, al final del cuerpo de la función (después del bloque `if crtEnabled then ... end`), antes del cierre de `end`, agregar:

```lua
CRTDebugMenu.draw()
```

- [ ] **Step 5: Hookear en main.lua — keypressed al inicio de love.keypressed**

En `love.keypressed(key)`, como primera línea del cuerpo, agregar:

```lua
if CRTDebugMenu.keypressed(key) then return end
```

- [ ] **Step 6: Smoke test — tecla N**

Ejecutar el juego:
```bash
./run_game.sh
```
Esperado:
- Presionar `N` → aparece texto amarillo "CRT DEBUG [N cerrar]" en la esquina superior derecha de la pantalla
- Presionar `N` de nuevo → desaparece
- Presionar `Escape` mientras está abierto → desaparece
- El juego sigue corriendo normalmente debajo

---

## Task 2: ITEMS table, estado de navegación y draw() completo

**Files:**
- Modify: `source/entities/UI/CRTDebugMenu.lua` (reemplazar contenido completo)

- [ ] **Step 1: Reemplazar CRTDebugMenu.lua con implementación completa de datos + draw**

Reemplazar **todo** el contenido de `source/entities/UI/CRTDebugMenu.lua` con:

```lua
local CRTDebugMenu = {}

local visible = false
local cursor  = 1

local DEFAULTS = {
    crtEnabled = true,
    scanlines  = { opacity=0.4, thickness=0.5, frequency=240, phase=1,   width=0.5  },
    crt        = { distortionFactor=1.02, feather=0.02 },
    chromasep  = { radius=2.0, angle=0 },
    glow       = { strength=5, min_luma=0.7 }
}

local ITEMS = {
    { label="CRT Enabled",  type="toggle" },
    { section="SCANLINES" },
    { label="Opacity",    group="scanlines", key="opacity",         min=0,   max=1,    step=0.05, big=0.1  },
    { label="Thickness",  group="scanlines", key="thickness",       min=0,   max=5,    step=0.1,  big=0.5  },
    { label="Frequency",  group="scanlines", key="frequency",       min=60,  max=480,  step=10,   big=60   },
    { label="Phase",      group="scanlines", key="phase",           min=0,   max=6.28, step=0.1,  big=0.5  },
    { label="Width",      group="scanlines", key="width",           min=0,   max=1,    step=0.05, big=0.1  },
    { section="CRT" },
    { label="Distortion", group="crt",       key="distortionFactor",min=1.0, max=1.2,  step=0.01, big=0.05 },
    { label="Feather",    group="crt",       key="feather",         min=0,   max=0.1,  step=0.005,big=0.02 },
    { section="CHROMASEP" },
    { label="Radius",     group="chromasep", key="radius",          min=0,   max=10,   step=0.5,  big=2    },
    { label="Angle",      group="chromasep", key="angle",           min=0,   max=6.28, step=0.1,  big=0.5  },
    { section="GLOW" },
    { label="Strength",   group="glow",      key="strength",        min=0,   max=20,   step=0.5,  big=2    },
    { label="Min Luma",   group="glow",      key="min_luma",        min=0,   max=1,    step=0.05, big=0.1  },
}

-- flat list of navigable items (excludes section headers)
local nav = {}
for _, item in ipairs(ITEMS) do
    if not item.section then nav[#nav+1] = item end
end

local function getValue(item)
    if item.type == "toggle" then return crtEnabled end
    return moonshinSettings[item.group][item.key]
end

local function setValue(item, v)
    if item.type == "toggle" then crtEnabled = v
    else moonshinSettings[item.group][item.key] = v end
    applyCRTSettings()
end

local function roundTo(v, step)
    local f = 1 / step
    return math.floor(v * f + 0.5) / f
end

local function makeBar(value, mn, mx)
    local t = (mx > mn) and (value - mn) / (mx - mn) or 0
    t = math.max(0, math.min(1, t))
    local filled = math.floor(t * 10 + 0.5)
    local s = ""
    for i = 1, 10 do s = s .. (i <= filled and "█" or "░") end
    return s
end

local function fmtVal(item, val)
    if item.step >= 1        then return string.format("%d",   math.floor(val + 0.5))
    elseif item.step >= 0.01 then return string.format("%.2f", val)
    else                          return string.format("%.3f", val) end
end

local PANEL_W = 230
local PAD     = 8
local LINE_H  = 15

local function getFont()
    if not CRTDebugMenu._font then
        CRTDebugMenu._font = love.graphics.newFont(10)
    end
    return CRTDebugMenu._font
end

function CRTDebugMenu.draw()
    if not visible then return end

    local sw  = love.graphics.getWidth()
    local px  = sw - PANEL_W - 6
    local py  = 6

    local rowCount = 3  -- title row + separator + footer rows (2 lines)
    for _ in ipairs(ITEMS) do rowCount = rowCount + 1 end
    local panelH = rowCount * LINE_H + PAD * 2

    love.graphics.setFont(getFont())

    -- background + border
    love.graphics.setColor(0.05, 0.05, 0.12, 0.93)
    love.graphics.rectangle("fill", px, py, PANEL_W, panelH, 4)
    love.graphics.setColor(0.35, 0.7, 1, 0.7)
    love.graphics.rectangle("line", px, py, PANEL_W, panelH, 4)

    local y = py + PAD
    local x = px + PAD

    -- title
    love.graphics.setColor(0.4, 0.85, 1, 1)
    love.graphics.print("CRT DEBUG", x, y)
    love.graphics.setColor(0.45, 0.45, 0.55, 1)
    love.graphics.print("[N] cerrar", px + PANEL_W - PAD - 62, y)
    y = y + LINE_H

    -- title separator
    love.graphics.setColor(0.25, 0.35, 0.5, 1)
    love.graphics.line(px + 4, y, px + PANEL_W - 4, y)
    y = y + 6

    local navIdx = 0
    for _, item in ipairs(ITEMS) do
        if item.section then
            love.graphics.setColor(0.55, 0.55, 0.3, 1)
            love.graphics.print("─ " .. item.section .. " ─", x, y)
        else
            navIdx = navIdx + 1
            local active = (navIdx == cursor)

            if active then
                love.graphics.setColor(0.9, 0.85, 0.1, 0.18)
                love.graphics.rectangle("fill", px + 3, y - 1, PANEL_W - 6, LINE_H)
            end

            local cCol = active and {1, 1, 0.3, 1} or {0.75, 0.75, 0.75, 1}

            if item.type == "toggle" then
                local val    = getValue(item)
                local valCol = val and {0.3, 1, 0.4, 1} or {1, 0.35, 0.35, 1}
                love.graphics.setColor(unpack(cCol))
                love.graphics.print((active and "> " or "  ") .. item.label .. ":", x, y)
                love.graphics.setColor(unpack(valCol))
                love.graphics.print(val and "ON" or "OFF", x + 110, y)
            else
                local val  = getValue(item)
                local bar  = makeBar(val, item.min, item.max)
                local fval = fmtVal(item, val)
                love.graphics.setColor(unpack(cCol))
                love.graphics.print((active and "> " or "  ") .. string.format("%-11s", item.label), x, y)
                love.graphics.setColor(active and {0.3, 1, 0.55, 1} or {0.2, 0.7, 0.35, 0.85})
                love.graphics.print(bar, x + 92, y)
                love.graphics.setColor(unpack(cCol))
                love.graphics.print(fval, x + 164, y)
            end
        end
        y = y + LINE_H
    end

    -- footer
    y = y + 4
    love.graphics.setColor(0.25, 0.35, 0.5, 1)
    love.graphics.line(px + 4, y, px + PANEL_W - 4, y)
    y = y + 5
    love.graphics.setColor(0.5, 0.8, 0.5, 1)
    love.graphics.print("[←/→] ajustar  [Shift] paso grande", x, y)
    y = y + LINE_H
    love.graphics.print("[S] Guardar   [R] Reset", x, y)

    love.graphics.setColor(1, 1, 1, 1)
end

function CRTDebugMenu.keypressed(key)
    if key == "n" then visible = not visible; return true end
    if not visible then return false end
    -- stub — keypressed completo en Task 3
    if key == "escape" then visible = false end
    return true
end

function CRTDebugMenu.loadFromDisk() end

return CRTDebugMenu
```

- [ ] **Step 2: Test visual del panel**

Ejecutar el juego, presionar `N`.
Esperado:
- Panel azul oscuro en el borde derecho de la pantalla
- Header "CRT DEBUG" en azul claro, "[N] cerrar" en gris
- Sección toggle "CRT Enabled: ON" en verde
- 4 secciones: SCANLINES, CRT, CHROMASEP, GLOW con sus parámetros
- Cada parámetro muestra nombre, barra de 10 bloques y valor numérico
- La fila seleccionada tiene highlight amarillo y cursor `>`
- Barra de footer: "[←/→] ajustar  [Shift] paso grande" y "[S] Guardar  [R] Reset"

---

## Task 3: keypressed() completo — navegación, ajuste y reset

**Files:**
- Modify: `source/entities/UI/CRTDebugMenu.lua`

- [ ] **Step 1: Reemplazar la función keypressed stub**

Localizar en `CRTDebugMenu.lua` el bloque:

```lua
function CRTDebugMenu.keypressed(key)
    if key == "n" then visible = not visible; return true end
    if not visible then return false end
    -- stub — keypressed completo en Task 3
    if key == "escape" then visible = false end
    return true
end
```

Reemplazarlo con:

```lua
function CRTDebugMenu.keypressed(key)
    if key == "n" then visible = not visible; return true end
    if not visible then return false end

    local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")

    if key == "escape" then
        visible = false
    elseif key == "up" then
        cursor = cursor - 1
        if cursor < 1 then cursor = #nav end
    elseif key == "down" then
        cursor = cursor + 1
        if cursor > #nav then cursor = 1 end
    elseif key == "left" or key == "right" then
        local item = nav[cursor]
        if item.type ~= "toggle" then
            local delta = (key == "right" and 1 or -1) * (shift and item.big or item.step)
            local val = roundTo(
                math.max(item.min, math.min(item.max, getValue(item) + delta)),
                item.step
            )
            setValue(item, val)
        end
    elseif key == "return" then
        local item = nav[cursor]
        if item.type == "toggle" then setValue(item, not getValue(item)) end
    elseif key == "r" then
        crtEnabled = DEFAULTS.crtEnabled
        for group, params in pairs(DEFAULTS) do
            if type(params) == "table" and moonshinSettings[group] then
                for k, v in pairs(params) do
                    moonshinSettings[group][k] = v
                end
            end
        end
        applyCRTSettings()
    elseif key == "s" then
        CRTDebugMenu.saveToDisk()
    end
    return true
end
```

- [ ] **Step 2: Test de navegación y ajuste**

Ejecutar el juego, presionar `N`.
Esperado:
- `↑`/`↓` mueve el cursor entre filas (el highlight amarillo se desplaza)
- En cualquier slider, `→` sube el valor un step, `←` lo baja
- `Shift+→` sube el valor un big step
- Los cambios se ven en el juego en tiempo real (barra actualiza, efecto CRT cambia)
- En "CRT Enabled", `Enter` alterna entre ON (verde) y OFF (rojo) y el efecto CRT se activa/desactiva
- `R` restaura todos los valores a los defaults del código
- `S` imprime en consola la ruta del archivo guardado (aún no hay saveToDisk implementado, se agregará en Task 4)
- `Escape` cierra el panel

---

## Task 4: saveToDisk + loadFromDisk + commit final

**Files:**
- Modify: `source/entities/UI/CRTDebugMenu.lua`

- [ ] **Step 1: Reemplazar el stub loadFromDisk y agregar saveToDisk**

Localizar en `CRTDebugMenu.lua` la línea:

```lua
function CRTDebugMenu.loadFromDisk() end
```

Reemplazarla con:

```lua
function CRTDebugMenu.saveToDisk()
    local s = moonshinSettings
    local lines = {
        "-- CRT Debug Settings",
        "-- Guardado: " .. os.date("%Y-%m-%d %H:%M:%S"),
        "return {",
        string.format("    crtEnabled = %s,",              tostring(crtEnabled)),
        "    scanlines = {",
        string.format("        opacity = %.4f,",            s.scanlines.opacity),
        string.format("        thickness = %.4f,",          s.scanlines.thickness),
        string.format("        frequency = %.4f,",          s.scanlines.frequency),
        string.format("        phase = %.4f,",              s.scanlines.phase),
        string.format("        width = %.4f",               s.scanlines.width),
        "    },",
        "    crt = {",
        string.format("        distortionFactor = %.4f,",   s.crt.distortionFactor),
        string.format("        feather = %.4f",             s.crt.feather),
        "    },",
        "    chromasep = {",
        string.format("        radius = %.4f,",             s.chromasep.radius),
        string.format("        angle = %.4f",               s.chromasep.angle),
        "    },",
        "    glow = {",
        string.format("        strength = %.4f,",           s.glow.strength),
        string.format("        min_luma = %.4f",            s.glow.min_luma),
        "    }",
        "}"
    }
    love.filesystem.write("crt_settings.lua", table.concat(lines, "\n"))
    printDebug("CRT settings guardado en: " .. love.filesystem.getSaveDirectory() .. "/crt_settings.lua")
end

function CRTDebugMenu.loadFromDisk()
    if not love.filesystem.getInfo("crt_settings.lua") then return end
    local chunk, err = love.filesystem.load("crt_settings.lua")
    if not chunk then
        printDebug("CRTDebugMenu load error: " .. tostring(err))
        return
    end
    local ok, data = pcall(chunk)
    if not ok or type(data) ~= "table" then return end
    if data.crtEnabled ~= nil then crtEnabled = data.crtEnabled end
    for group, params in pairs(data) do
        if type(params) == "table" and moonshinSettings[group] then
            for k, v in pairs(params) do
                if moonshinSettings[group][k] ~= nil then
                    moonshinSettings[group][k] = v
                end
            end
        end
    end
    applyCRTSettings()
    printDebug("CRT settings cargado desde disco")
end
```

- [ ] **Step 2: Test save → restart → load**

1. Ejecutar el juego, presionar `N`
2. Ajustar algunos valores (ej. subir Opacity de Scanlines a 0.80)
3. Presionar `S` → en la consola debe aparecer:
   ```
   CRT settings guardado en: /Users/<user>/Library/Application Support/LOVE/<game>/crt_settings.lua
   ```
4. Cerrar el juego y volver a ejecutar
5. Esperado: los valores ajustados persisten (el efecto CRT se ve igual que al cerrar)
6. Presionar `N` para verificar que los sliders muestran los valores guardados

- [ ] **Step 3: Test reset después de cargar desde disco**

Con el juego corriendo y valores guardados, presionar `N` y luego `R`.
Esperado: todos los sliders vuelven a los defaults del código (opacity=0.40, thickness=0.50, etc.), el efecto CRT cambia visualmente a los defaults. Los valores en disco no se tocan — solo se restaura la sesión actual en memoria.

- [ ] **Step 4: Commit**

```bash
git add source/entities/UI/CRTDebugMenu.lua source/main.lua docs/superpowers/specs/2026-04-21-crt-debug-menu-design.md docs/superpowers/plans/2026-04-22-crt-debug-menu.md
git commit -m "feat: add in-game CRT debug overlay (N key) with save/load"
```

---

## Self-Review

### Spec coverage

| Req | Task |
|---|---|
| Overlay in-game tecla N | Task 1 |
| Parámetros agrupados por efecto | Task 2 ITEMS table |
| Barra visual + número | Task 2 draw() makeBar + fmtVal |
| Ajuste left/right, Shift paso grande | Task 3 keypressed |
| Toggle CRT Enabled con Enter | Task 3 keypressed |
| Reset con R | Task 3 keypressed |
| Guardar a disco con S | Task 4 saveToDisk |
| Cargar desde disco al arrancar | Task 4 loadFromDisk + love.load hook |
| Cerrar con Escape | Task 1 skeleton + Task 3 |

Todos los requisitos del spec están cubiertos. ✓

### Verificaciones adicionales
- `unpack` es global en LuaJIT (LÖVE 11.5) ✓
- `moonshinSettings` y `crtEnabled` son globals definidos en `main.lua` antes de que cualquier escena corra ✓
- `applyCRTSettings()` es global en `main.lua` ✓
- Tecla `n` no está mapeada en `InputBindings.lua` — sin conflictos ✓
- Tecla `s` está mapeada a `Input.down` pero CRTDebugMenu.keypressed retorna `true` cuando visible, consumiendo el evento antes de que llegue a la escena ✓
- loadFromDisk se llama después de `applyCRTSettings()` en love.load, garantizando que `crt_effect` ya existe ✓
