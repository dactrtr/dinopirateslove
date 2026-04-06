# Input Bindings Centralization — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Centralizar todos los bindings de teclado en `source/assets/data/InputBindings.lua`, reemplazar acciones granulares con `AButton`/`BButton`, y añadir hold-to-open para el menú de equipo.

**Architecture:** Se crea un módulo `InputBindings.lua` que exporta la tabla `Input` global (bindings + helpers + danceKeys). `main.lua` lo require y lo expone como global. Un timer en `main.lua:update` detecta el hold de AButton y despacha un evento sintético `"__menuOpen__"` a través del sistema de escenas existente.

**Tech Stack:** LÖVE 11.5, Lua. Sin framework de tests — verificación manual corriendo el juego con `./run_game.sh`.

---

## File Map

| Archivo | Acción | Responsabilidad |
|---------|--------|-----------------|
| `source/assets/data/InputBindings.lua` | **CREAR** | Todos los bindings, helpers, danceKeys |
| `source/main.lua` | Modificar | Require InputBindings, eliminar definiciones viejas, hold timer |
| `source/scenes/DanceScene.lua` | Modificar | Usar `Input.danceKeys` en vez de `local keyMap` |
| `source/scenes/gameScene.lua` | Modificar | confirm→AButton, action/dash/flash→BButton, menu→menuOpen/BButton |
| `source/scenes/titleScene.lua` | Modificar | menuConfirm→AButton, menuBack→BButton |
| `source/PauseMenu.lua` | Modificar | confirm→AButton |
| `source/entities/UI/ComicPlayer.lua` | Modificar | menuConfirm/menuBack→AButton/BButton |

---

## Task 1: Crear InputBindings.lua

**Files:**
- Create: `source/assets/data/InputBindings.lua`

- [ ] **Step 1: Crear el archivo**

```lua
-- source/assets/data/InputBindings.lua
-- ─────────────────────────────────────────────────────────────
-- INPUT BINDINGS
-- Edita este archivo para remapear cualquier control del juego.
-- ─────────────────────────────────────────────────────────────

local Input = {}

-- ── GAMEPLAY ─────────────────────────────────────────────────
-- AButton: confirmar, avanzar diálogo. Hold 0.5s → abre menú equipo.
Input.AButton = {"z", "return", "space"}
-- BButton: activar item equipado en juego / cancelar en menús.
Input.BButton = {"x"}

-- ── NAVIGATION ───────────────────────────────────────────────
Input.up    = {"w", "up"}
Input.down  = {"s", "down"}
Input.left  = {"a", "left"}
Input.right = {"d", "right"}

-- ── SYSTEM ───────────────────────────────────────────────────
Input.pause  = {"escape"}
Input.resize = {"e"}   -- placeholder crank de Playdate

-- Evento sintético despachado por el hold timer de main.lua.
-- No asignes esta tecla manualmente.
Input.menuOpen = {"__menuOpen__"}

-- ── DEV / WINDOW ─────────────────────────────────────────────
Input.toggleCRT  = {"q"}
Input.fullscreen = {"f"}
Input.res1 = {"1"}
Input.res2 = {"2"}
Input.res3 = {"3"}

-- ── DANCE SCENE ──────────────────────────────────────────────
-- Mapeo de teclas físicas a botones de ritmo usados en DanceScene.
Input.danceKeys = {
    ["return"] = "aButton",  ["space"]  = "aButton",
    ["lshift"] = "bButton",  ["rshift"] = "bButton",
    ["left"]   = "leftButton", ["right"] = "rightButton",
    ["up"]     = "upButton",   ["down"]  = "downButton",
}

-- ── HELPERS ──────────────────────────────────────────────────

--- Devuelve true si `key` coincide con algún binding de Input[action].
function Input.is(key, action)
    local binds = Input[action]
    if not binds then return false end
    for _, k in ipairs(binds) do
        if key == k then return true end
    end
    return false
end

--- Devuelve true si alguna tecla de Input[action] está presionada.
function Input.isDown(action)
    local binds = Input[action]
    if not binds then return false end
    for _, k in ipairs(binds) do
        if love.keyboard.isDown(k) then return true end
    end
    return false
end

return Input
```

- [ ] **Step 2: Verificar que el archivo existe**

```bash
ls source/assets/data/InputBindings.lua
```
Esperado: el archivo aparece en la lista.

---

## Task 2: Conectar main.lua a InputBindings

**Files:**
- Modify: `source/main.lua`

- [ ] **Step 1: Reemplazar la definición de Input en main.lua**

Busca el bloque que empieza en línea ~36:
```lua
-- ─────────────────────────────────────────────────────────────
-- INPUT BINDINGS  (edit here to remap controls globally)
-- ─────────────────────────────────────────────────────────────
Input = {
    ...
}

--- Returns true if `key` matches any binding in Input[action].
function Input.is(key, action)
    ...
end

--- Returns true if any key bound to Input[action] is currently held.
function Input.isDown(action)
    ...
end
```

Reemplázalo por:
```lua
-- Todos los bindings están en assets/data/InputBindings.lua
Input = require 'assets.data.InputBindings'
```

- [ ] **Step 2: Correr el juego y verificar que arranca**

```bash
./run_game.sh
```
Esperado: el juego abre normalmente, título visible, sin errores en consola.

- [ ] **Step 3: Commit**

```bash
git add source/assets/data/InputBindings.lua source/main.lua
git commit -m "refactor: extraer Input bindings a InputBindings.lua"
```

---

## Task 3: Añadir hold timer para AButton → menú equipo

**Files:**
- Modify: `source/main.lua`

El hold timer acumula tiempo mientras AButton está presionado. Al alcanzar 0.5s, despacha el evento sintético `"__menuOpen__"` al sistema de escenas y se resetea. Esto reemplaza la tecla Tab (`menu`).

- [ ] **Step 1: Añadir variable del timer**

Justo después de la línea `crtEnabled = true -- Made global...`, añade:
```lua
local aButtonHoldTimer = 0
local MENU_HOLD_THRESHOLD = 0.5  -- segundos para abrir menú
```

- [ ] **Step 2: Actualizar love.update para acumular el timer**

Reemplaza:
```lua
function love.update(dt)
    sceneManager.update(dt)

    if activeJoystick then
        handleGamepadInput(dt)
    end
end
```

Por:
```lua
function love.update(dt)
    sceneManager.update(dt)

    -- Hold AButton → abrir menú de equipo
    if Input.isDown("AButton") then
        aButtonHoldTimer = aButtonHoldTimer + dt
        if aButtonHoldTimer >= MENU_HOLD_THRESHOLD then
            aButtonHoldTimer = 0
            sceneManager.keypressed("__menuOpen__")
        end
    else
        aButtonHoldTimer = 0
    end

    if activeJoystick then
        handleGamepadInput(dt)
    end
end
```

- [ ] **Step 3: Correr el juego y verificar que arranca**

```bash
./run_game.sh
```
Esperado: el juego abre normalmente. Mantener Z/Enter/Space 0.5s no hace nada aún (gameScene todavía no escucha `menuOpen`).

- [ ] **Step 4: Commit**

```bash
git add source/main.lua
git commit -m "feat: añadir hold timer AButton para menú equipo"
```

---

## Task 4: Actualizar DanceScene

**Files:**
- Modify: `source/scenes/DanceScene.lua`

- [ ] **Step 1: Localizar y reemplazar el keyMap hardcodeado**

Busca en `danceScene.keypressed` (~línea 264):
```lua
    -- Mid-battle: map key → button name
    local keyMap = {
        ["return"] = "aButton",  ["space"]  = "aButton",
        ["lshift"] = "bButton",  ["rshift"] = "bButton",
        ["left"]   = "leftButton", ["right"] = "rightButton",
        ["up"]     = "upButton",   ["down"]  = "downButton",
    }
    local mapped = keyMap[key]
```

Reemplázalo por:
```lua
    -- Mid-battle: map key → button name (configurado en InputBindings.lua)
    local mapped = Input.danceKeys[key]
```

- [ ] **Step 2: Correr el juego y entrar a una batalla de baile**

```bash
./run_game.sh
```
Esperado: los botones de ritmo responden igual que antes (flechas, space/return, shift).

- [ ] **Step 3: Commit**

```bash
git add source/scenes/DanceScene.lua
git commit -m "refactor: DanceScene usa Input.danceKeys en vez de keyMap local"
```

---

## Task 5: Actualizar gameScene

**Files:**
- Modify: `source/scenes/gameScene.lua`

Cambios en `gameScene.keypressed` (~línea 1288):
- `confirm` → `AButton`
- `action` / `dash` / `flash` → `BButton` (único handler `handleActionButton`)
- `menu` al cerrar equipo → `BButton`
- `menu` al abrir equipo → `menuOpen` (evento sintético del hold timer)

- [ ] **Step 1: Reemplazar bloque de diálogo y acciones**

Busca:
```lua
    -- If talking, any 'confirm' key advances dialog
    if PlayerData.isTalking then
        if Input.is(key, "confirm") then
            gameScene.player:displayDialog()
            return
        end
    else
        -- Check for interaction on confirm keys
        if Input.is(key, "confirm") then
            gameScene.checkTriggerInteraction()
        end

        -- Action button for Plungerang
        if Input.is(key, "action") then
            if gameScene.player and gameScene.player.handleActionButton then
                gameScene.player:handleActionButton()
            end
        end
    end
```

Reemplaza por:
```lua
    -- Si está hablando, AButton avanza el diálogo
    if PlayerData.isTalking then
        if Input.is(key, "AButton") then
            gameScene.player:displayDialog()
            return
        end
    else
        -- AButton interactúa con triggers
        if Input.is(key, "AButton") then
            gameScene.checkTriggerInteraction()
        end

        -- BButton activa el item equipado (plungerang, dash, flash, etc.)
        if Input.is(key, "BButton") then
            if gameScene.player and gameScene.player.handleActionButton then
                gameScene.player:handleActionButton()
            end
        end
    end
```

- [ ] **Step 2: Reemplazar bloque de menú equipo y acciones de juego**

Busca:
```lua
    -- Game input (when menu is not shown)
    if PlayerData.isEquiping then
        -- Handle In-Game Menu inputs
        if Input.is(key, "menu") or Input.is(key, "pause") then
            PlayerData.isGaming = true
            PlayerData.isEquiping = false
        else
            InGameMenu:keypressed(key)
        end
    elseif Input.is(key, "menu") and PlayerData.isGaming and PlayerData.items.hasDWatch then
        -- Open In-Game Menu for equipment (requires D-Watch, only while gaming)
        PlayerData.isGaming = false
        PlayerData.isEquiping = true
        if PlayerData.activeItem == 0 or PlayerData.activeItem == nil then
            InGameMenu:nextItem()
        end
    elseif Input.is(key, "pause") then
        gameScene.pauseMenu:show()
    elseif Input.is(key, "resize") then
        PlayerData.battery = 100
        FXshadow.markDirty()
        printDebug("🔋 DEBUG: Battery charged to 100")
    elseif Input.is(key, "dash") then
        if gameScene.player and PlayerData.skills.canDash then
            local dir = (PlayerData.direction ~= "idle") and PlayerData.direction or "right"
            gameScene.player:startDash(dir)
        end
    elseif Input.is(key, "flash") then
        if gameScene.player then
            gameScene.player:lightBurst()
        end
    end
```

Reemplaza por:
```lua
    -- Game input (when menu is not shown)
    if PlayerData.isEquiping then
        -- BButton o pause cierra el menú de equipo
        if Input.is(key, "BButton") or Input.is(key, "pause") then
            PlayerData.isGaming = true
            PlayerData.isEquiping = false
        else
            InGameMenu:keypressed(key)
        end
    elseif Input.is(key, "menuOpen") and PlayerData.isGaming and PlayerData.items.hasDWatch then
        -- Abre menú de equipo (evento sintético del hold timer de AButton)
        PlayerData.isGaming = false
        PlayerData.isEquiping = true
        if PlayerData.activeItem == 0 or PlayerData.activeItem == nil then
            InGameMenu:nextItem()
        end
    elseif Input.is(key, "pause") then
        gameScene.pauseMenu:show()
    elseif Input.is(key, "resize") then
        PlayerData.battery = 100
        FXshadow.markDirty()
        printDebug("🔋 DEBUG: Battery charged to 100")
    end
```

- [ ] **Step 3: Correr el juego y verificar gameplay básico**

```bash
./run_game.sh
```
Verificar:
- Z/Enter/Space avanza diálogos
- X activa item equipado
- Escape pausa el juego
- Hold Z/Enter/Space 0.5s abre menú de equipo (si tiene D-Watch)
- BButton o Escape cierra menú de equipo

- [ ] **Step 4: Commit**

```bash
git add source/scenes/gameScene.lua
git commit -m "refactor: gameScene usa AButton/BButton, hold para menú equipo"
```

---

## Task 6: Actualizar titleScene

**Files:**
- Modify: `source/scenes/titleScene.lua`

- [ ] **Step 1: Reemplazar menuConfirm y menuBack**

En `titleScene.keypressed` (~línea 304), reemplaza:
```lua
        elseif Input.is(key, "menuConfirm") then
```
Por:
```lua
        elseif Input.is(key, "AButton") then
```

En la misma función (~línea 311), reemplaza:
```lua
        elseif Input.is(key, "menuBack") then
            titleScene.inSettings = false
```
Por:
```lua
        elseif Input.is(key, "BButton") then
            titleScene.inSettings = false
```

Busca el segundo bloque (menú principal, ~línea 323):
```lua
        elseif Input.is(key, "menuConfirm") then
```
Reemplaza por:
```lua
        elseif Input.is(key, "AButton") then
```

Busca también cualquier `Input.is(key, "menuBack")` en titleScene y reemplaza por `Input.is(key, "BButton")`.

- [ ] **Step 2: Correr el juego y verificar el menú de título**

```bash
./run_game.sh
```
Verificar:
- Flechas navegan el menú
- Z/Enter/Space confirma la selección
- X/Escape vuelve desde settings

- [ ] **Step 3: Commit**

```bash
git add source/scenes/titleScene.lua
git commit -m "refactor: titleScene usa AButton/BButton"
```

---

## Task 7: Actualizar PauseMenu

**Files:**
- Modify: `source/PauseMenu.lua`

- [ ] **Step 1: Reemplazar confirm en PauseMenu:keypressed**

Busca (~línea 112):
```lua
    elseif Input.is(key, "confirm") then
        return self:selectButton()
```
Reemplaza por:
```lua
    elseif Input.is(key, "AButton") then
        return self:selectButton()
```

- [ ] **Step 2: Correr el juego y verificar el pause menu**

```bash
./run_game.sh
```
Verificar:
- Escape abre/cierra el pause menu
- Flechas navegan opciones
- Z/Enter/Space confirma la opción seleccionada

- [ ] **Step 3: Commit**

```bash
git add source/PauseMenu.lua
git commit -m "refactor: PauseMenu usa AButton"
```

---

## Task 8: Actualizar ComicPlayer

**Files:**
- Modify: `source/entities/UI/ComicPlayer.lua`

- [ ] **Step 1: Reemplazar menuConfirm y menuBack**

Busca (~línea 290):
```lua
    if Input.is(key, advBtn) or Input.is(key, "menuBack") or Input.is(key, "menuConfirm") then
```
Reemplaza por:
```lua
    if Input.is(key, advBtn) or Input.is(key, "BButton") or Input.is(key, "AButton") then
```

- [ ] **Step 2: Correr el juego y verificar comics/cutscenes**

```bash
./run_game.sh
```
Verificar: Z/Enter/Space y X avanzan los paneles de cómic.

- [ ] **Step 3: Commit**

```bash
git add source/entities/UI/ComicPlayer.lua
git commit -m "refactor: ComicPlayer usa AButton/BButton"
```

---

## Task 9: Limpieza — eliminar acciones obsoletas de InputBindings

Una vez todos los archivos actualizados, las acciones `confirm`, `action`, `flash`, `dash`, `menu`, `menuConfirm`, `menuBack` ya no existen en ningún archivo. Se eliminan del módulo para que el archivo central no tenga entradas muertas.

**Files:**
- Modify: `source/assets/data/InputBindings.lua`

- [ ] **Step 1: Verificar que ningún archivo usa las acciones viejas**

```bash
grep -r "Input\.is.*confirm\|Input\.is.*action\|Input\.is.*flash\|Input\.is.*dash\|Input\.is.*menuConfirm\|Input\.is.*menuBack\b\|Input\.is.*\"menu\"" source/ --include="*.lua"
```
Esperado: sin resultados (o solo comentarios).

- [ ] **Step 2: Correr el juego una última vez — verificación completa**

```bash
./run_game.sh
```
Checklist final:
- [ ] Título: navegar con flechas, confirmar con Z/Enter/Space, volver con X/Escape
- [ ] Settings: sliders con flechas, confirmar con Z, volver con X
- [ ] Juego: movimiento WASD/flechas, X activa item, Z/Enter interactúa, Escape pausa
- [ ] Hold Z/Enter/Space 0.5s abre menú equipo (con D-Watch)
- [ ] X o Escape cierra menú equipo
- [ ] DanceScene: flechas y space/return/shift responden correctamente
- [ ] Comics/cutscenes: Z y X avanzan paneles
- [ ] Dev: Q toggle CRT, F fullscreen, 1/2/3 resolución

- [ ] **Step 3: Commit final**

```bash
git add source/assets/data/InputBindings.lua
git commit -m "chore: eliminar acciones de input obsoletas de InputBindings"
```
