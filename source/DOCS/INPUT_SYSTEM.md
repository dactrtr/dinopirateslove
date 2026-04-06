# Input System — Botones y Mapeo a Love2D

Este documento describe el sistema de input completo del juego en Playdate, cómo cambia el comportamiento de cada botón según el estado activo, y cómo mapear todo a Love2D manteniendo exactamente dos botones de acción.

---

## 🎮 Hardware de entrada del Playdate

| Control | Descripción |
|---|---|
| D-pad | 4 direcciones: `up`, `down`, `left`, `right` |
| **A** | Botón de acción primario (derecha) |
| **B** | Botón de acción secundario (izquierda) |
| Crank | Manivela analógica giratoria — sin equivalente en consolas estándar |

El juego usa exactamente **2 botones de acción + D-pad + Crank**. Esto lo hace ideal para portar a PC o gamepad sin rediseñar la jugabilidad.

---

## 🗺️ Mapa de estados del juego

El comportamiento de A y B cambia radicalmente según los flags activos en `PlayerData`. Los estados son **mutuamente excluyentes** por diseño:

```
isGaming = true   → gameplay normal
isGaming = false + isEquiping = true  → menú de equipo abierto
isGaming = false + readyToShrink = true → minificador activo
isTalking = true  → diálogo activo (puede solaparse con isGaming)
isDancing = false → pantalla "ready" del DanceScene
isDancing = true  → batalla rítmica activa
```

---

## 📋 MazeScene — Tabla completa de inputs

### D-pad

| Input | Estado requerido | Acción |
|---|---|---|
| `←↑→↓` (Down) | `isGaming == true`, sin dash/slide/plunge | `player:move(direction)` — mueve el jugador |
| `←↑→↓` (Hold) | `isGaming == true` | `player:move(direction)` — continúa moviendo |
| `←↑→↓` (Up) | Siempre | `player:idle()` — detiene y vuelve al estado idle |
| `←` (Down) | `isEquiping == true` | `inGameEquip:prevItem()` — skill anterior |
| `→` (Down) | `isEquiping == true` | `inGameEquip:nextItem()` — skill siguiente |

> D-pad `up` y `down` **no tienen función en el menú** — solo `←` y `→` ciclan items.

---

### Botón A — Multifunción por prioridad

El `AButtonDown` evalúa condiciones **en este orden** (la primera que se cumple ejecuta y a veces continúa):

```
1. isTalking == true
   → player:displayDialog()  (avanza/cierra el diálogo actual)

2. currentTrigger != nil  AND  isGaming == true
   → Activa el trigger Search/Call manualmente:
     - isGaming = false, isTalking = true
     - dialogUI:addScreen(trigger:returnScript(), trigger.sourceFeed)

3. isEquiping == true  (independiente, siempre se evalúa)
   → inGameEquip:selectItem()  (confirma el skill seleccionado)

4. readyToShrink == true  AND  isGaming == true
   → player:startMinifying()  (activa el minificador)
```

| Input | Condición | Acción |
|---|---|---|
| `A` (Down) | `isTalking` | Avanzar / cerrar diálogo |
| `A` (Down) | `currentTrigger` + `isGaming` | Activar trigger manual |
| `A` (Down) | `isEquiping` | Confirmar skill en menú |
| `A` (Down) | `readyToShrink` + `isGaming` | Iniciar minificación |
| `A` (Hold, cada frame) | — | Sin acción |
| **`A` (Held, 1 segundo)** | `isGaming` + `hasDWatch` | **Abrir menú de equipo** |
| `A` (Up) | — | Sin acción |

---

### Botón B — Multifunción por prioridad

```
1. isGaming == false  AND  isEquiping == true
   → Cerrar menú: isGaming = true, isEquiping = false
     inGameEquip:closeMenu()

2. isGaming == false  AND  readyToShrink == true
   → player:finishMinifying()  (cancela/completa la minificación)

3. isGaming == true  AND  player.isAlive
   → player:useAbility()  (usa el skill activo según activeItem)
     - activeItem == 1  → lightBurst()   (requiere canFlash)
     - activeItem == 2  → dash()         (requiere canDash)
     - activeItem == 3  → plunge()       (requiere canPlungerang)

4. SIEMPRE (al final)
   → player:distributeMovementTokens(5)
     (activa el turno de enemigos/NPCs)
```

| Input | Condición | Acción |
|---|---|---|
| `B` (Down) | `!isGaming` + `isEquiping` | Cerrar menú de equipo |
| `B` (Down) | `!isGaming` + `readyToShrink` | Finalizar minificación |
| `B` (Down) | `isGaming` + vivo | Usar habilidad activa |
| `B` (Held/Hold) | — | Sin acción |
| `B` (Up) | — | Sin acción |

---

### Crank (manivela)

| Input | Condición | Acción |
|---|---|---|
| Giro (cualquier dirección) | `isAlive` | `player:burnCalories(1)` por tick |
| Giro positivo | `isGaming` + `battery < 100` + no minificando/tiny | `player:chargeBattery(3)` por tick + refresca la sombra |
| Giro (cualquier) | `readyToShrink == true` | `player:transformCycle()` — cicla la animación de transformación |

> El crank usa `playdate.getCrankTicks(4)` — equivale a 4 "clicks" por vuelta completa.

---

## 🕺 DanceScene — Tabla de inputs

El DanceScene usa **todos los botones** como entrada rítmica. El D-pad y A/B son las notas a presionar.

### Pre-batalla (pantalla "Ready", `isDancing == false`)

| Input | Acción |
|---|---|
| `A` (Down) | `scene:startBattle()` — comienza la batalla rítmica |
| Cualquier otro | Sin efecto |

### Batalla activa (`isDancing == true`)

Cada botón corresponde a un tipo de nota. El juego genera patrones con pesos según la dificultad:

| Input | Acción | Peso en "basic" | Peso en "boss" |
|---|---|---|---|
| `←` (Down) | `danceStep("leftButton")` | 20% | 5% |
| `→` (Down) | `danceStep("rightButton")` | 20% | 5% |
| `↑` (Down) | `danceStep("upButton")` | 20% | 5% |
| `↓` (Down) | `danceStep("downButton")` | 20% | 5% |
| `A` (Down) | `danceStep("aButton")` + `checkDanceResults()` | 20% | 40% |
| `B` (Down) | `danceStep("bButton")` | 0% | 40% |
| Cualquier (Up) | `clearButton()` — libera la nota | — | — |

> El crank no tiene función en DanceScene.

---

## 💻 Mapeo a Love2D — Mantener 2 botones

### Filosofía
El Playdate ya está diseñado con exactamente 2 botones de acción. La traducción a PC/gamepad es 1:1. **No hay que rediseñar nada.**

### Tabla de equivalencias

| Playdate | Teclado PC | Gamepad (Love2D) | Código Love2D |
|---|---|---|---|
| D-pad ↑ | `W` / `↑` | Left Stick Up / D-pad Up | `love.keyboard.isDown("w")` |
| D-pad ↓ | `S` / `↓` | Left Stick Down / D-pad Down | `love.keyboard.isDown("s")` |
| D-pad ← | `A` / `←` | Left Stick Left / D-pad Left | `love.keyboard.isDown("a")` |
| D-pad → | `D` / `→` | Left Stick Right / D-pad Right | `love.keyboard.isDown("d")` |
| **A button** | `Space` / `Z` / `J` | Botón Sur (Cross/A) | `love.keyboard.isDown("space")` |
| **B button** | `LShift` / `X` / `K` | Botón Oeste (Square/X) | `love.keyboard.isDown("lshift")` |
| Crank (giro) | `Q` / `E` / Mouse Wheel | Right Stick Y / L2+R2 | `love.keyboard.isDown("q")` |
| A held 1 seg | `Space` hold | Botón Sur hold | Timer en `love.update` |

---

### Implementación en Love2D

#### 1. Estructura de input unificada

```lua
-- input.lua — sistema de input centralizado
local Input = {}

-- Estado actual de botones
local state = {
    action1 = false,   -- A button
    action2 = false,   -- B button
    up = false, down = false, left = false, right = false,
    crankDelta = 0,
}

-- Estado del frame anterior (para detectar "just pressed")
local prev = {}

-- Timers para held
local holdTimers = { action1 = 0, action2 = 0 }
local HOLD_THRESHOLD = 1.0  -- 1 segundo, igual que Playdate

function Input.update(dt)
    -- Guardar estado previo
    for k, v in pairs(state) do prev[k] = v end

    -- Leer teclado
    state.action1 = love.keyboard.isDown("space", "z", "j")
    state.action2 = love.keyboard.isDown("lshift", "x", "k")
    state.up    = love.keyboard.isDown("w", "up")
    state.down  = love.keyboard.isDown("s", "down")
    state.left  = love.keyboard.isDown("a", "left")
    state.right = love.keyboard.isDown("d", "right")

    -- Crank: Q/E o mouse wheel o joystick eje
    local crankKey = 0
    if love.keyboard.isDown("e") then crankKey = 1 end
    if love.keyboard.isDown("q") then crankKey = -1 end
    state.crankDelta = crankKey  -- reemplazado por wheel en love.wheelmoved

    -- Gamepad (joystick 1 si hay)
    local gp = love.joystick.getJoysticks()[1]
    if gp then
        if gp:isGamepad() then
            if gp:isGamepadDown("a")  then state.action1 = true end
            if gp:isGamepadDown("x")  then state.action2 = true end
            if gp:isGamepadDown("dpup")    then state.up    = true end
            if gp:isGamepadDown("dpdown")  then state.down  = true end
            if gp:isGamepadDown("dpleft")  then state.left  = true end
            if gp:isGamepadDown("dpright") then state.right = true end
            -- Crank: usar gatillo derecho o eje Y del stick derecho
            state.crankDelta = gp:getGamepadAxis("righty") * -1
        end
    end

    -- Hold timers (equivalente a AButtonHeld / BButtonHeld)
    if state.action1 then
        holdTimers.action1 = holdTimers.action1 + dt
    else
        holdTimers.action1 = 0
    end
    if state.action2 then
        holdTimers.action2 = holdTimers.action2 + dt
    else
        holdTimers.action2 = 0
    end
end

-- Helpers: "just pressed" (Down), "held 1s" (Held), "just released" (Up)
function Input.justPressed(btn)  return state[btn] and not prev[btn] end
function Input.held(btn)         return state[btn] end
function Input.justReleased(btn) return not state[btn] and prev[btn] end
function Input.heldFor(btn)      return holdTimers[btn] end
function Input.justHeld(btn)     -- detecta el momento exacto que supera 1 segundo
    return holdTimers[btn] >= HOLD_THRESHOLD
       and (holdTimers[btn] - (love.timer.getDelta and love.timer.getDelta() or 0)) < HOLD_THRESHOLD
end

function Input.getCrankDelta() return state.crankDelta end

-- Mouse wheel → crank
function love.wheelmoved(x, y)
    state.crankDelta = y  -- positivo = cargar batería
end

return Input
```

#### 2. Manejador de MazeScene (equivalente al inputHandler)

```lua
-- En tu MazeScene update(dt):
function MazeScene:handleInput(dt)
    local I = Input  -- referencia al módulo de input

    -- ─── D-PAD: Movimiento ─────────────────────────────────────
    if PlayerData.isGaming then
        if I.justPressed("up")    or I.held("up")    then player:move("up")    end
        if I.justPressed("down")  or I.held("down")  then player:move("down")  end
        if I.justPressed("left")  or I.held("left")  then player:move("left")  end
        if I.justPressed("right") or I.held("right") then player:move("right") end
    end

    -- D-PAD en menú: ciclar skills
    if PlayerData.isEquiping then
        if I.justPressed("left")  then inGameEquip:prevItem() end
        if I.justPressed("right") then inGameEquip:nextItem() end
    end

    -- Idle al soltar
    if I.justReleased("up") or I.justReleased("down")
    or I.justReleased("left") or I.justReleased("right") then
        player:idle()
    end

    -- ─── BOTÓN A ───────────────────────────────────────────────
    if I.justPressed("action1") then
        -- 1. Diálogo activo
        if PlayerData.isTalking then
            player:displayDialog()
        -- 2. Trigger manual en juego
        elseif player.currentTrigger and PlayerData.isGaming then
            PlayerData.isGaming = false
            PlayerData.isTalking = true
            player.dialogUI:addScreen(player.currentTrigger:returnScript(),
                                      player.currentTrigger.sourceFeed)
        -- 3. Confirmar en menú (independiente)
        end
        if PlayerData.isEquiping then
            inGameEquip:selectItem()
        end
        -- 4. Activar minificador
        if PlayerData.readyToShrink and PlayerData.isGaming then
            player:startMinifying()
        end
    end

    -- A held 1 segundo → abrir menú (equivalente a AButtonHeld)
    if I.justHeld("action1") then
        if PlayerData.isGaming and PlayerData.items.hasDWatch then
            inGameEquip:displayMenu()
        end
    end

    -- ─── BOTÓN B ───────────────────────────────────────────────
    if I.justPressed("action2") then
        if not PlayerData.isGaming and PlayerData.isEquiping then
            -- Cerrar menú
            PlayerData.isGaming = true
            PlayerData.isEquiping = false
            inGameEquip:closeMenu()
        elseif not PlayerData.isGaming and PlayerData.readyToShrink then
            -- Finalizar minificación
            player:finishMinifying()
        elseif PlayerData.isGaming and player.isAlive then
            -- Usar habilidad activa
            player:useAbility()
        end
        -- Siempre activar turno de enemigos
        player:distributeMovementTokens(5)
    end

    -- ─── CRANK → batería y transformación ─────────────────────
    local crankDelta = I.getCrankDelta()
    if player.isAlive and crankDelta ~= 0 then
        player:burnCalories(1)
        if PlayerData.isGaming and PlayerData.battery < 100
        and not PlayerData.readyToShrink and not PlayerData.isTiny then
            if crankDelta > 0 then
                player:chargeBattery(3)
            end
        elseif PlayerData.readyToShrink then
            player:transformCycle()
        end
    end
end
```

#### 3. Manejador de DanceScene

```lua
-- En tu DanceScene handleInput(dt):
function DanceScene:handleInput(dt)
    local I = Input

    -- Pre-batalla: A para empezar
    if not PlayerData.isDancing then
        if I.justPressed("action1") then
            self:startBattle()
        end
        return
    end

    -- Batalla activa: todos los botones son notas rítmicas
    if I.justPressed("action1") then
        self:danceStep("aButton")
        self:checkDanceResults()
    end
    if I.justPressed("action2")  then self:danceStep("bButton") end
    if I.justPressed("left")     then self:danceStep("leftButton") end
    if I.justPressed("right")    then self:danceStep("rightButton") end
    if I.justPressed("up")       then self:danceStep("upButton") end
    if I.justPressed("down")     then self:danceStep("downButton") end

    -- Clear al soltar (equivalente a *ButtonUp → clearButton)
    if I.justReleased("action1") or I.justReleased("action2")
    or I.justReleased("left")   or I.justReleased("right")
    or I.justReleased("up")     or I.justReleased("down") then
        self:clearButton()
    end
end
```

---

## 🎯 Árbol de decisión — A y B en gameplay

```
AButtonDown:
├── isTalking?          → Avanzar diálogo
├── currentTrigger + isGaming? → Activar trigger manual
├── isEquiping?         → Confirmar skill (puede acumularse con arriba)
└── readyToShrink + isGaming? → Iniciar minificación

AButtonHeld (1 seg):
└── isGaming + hasDWatch → Abrir menú de equipo

BButtonDown:
├── !isGaming + isEquiping   → Cerrar menú
├── !isGaming + readyToShrink → Finalizar minificación
├── isGaming + isAlive       → Usar habilidad activa
│     ├── activeItem=1 + canFlash    → lightBurst()
│     ├── activeItem=2 + canDash     → dash()
│     └── activeItem=3 + canPlungerang → plunge()
└── SIEMPRE → distributeMovementTokens(5)
```

---

## 🔑 Flujo de apertura del menú de equipo

```
Jugador mantiene A 1 segundo
  → displayMenu() (solo si hasDWatch)
    → isGaming = false, isEquiping = true
    → menú visible

  D-pad ← / →
    → prevItem() / nextItem()  [cicla entre skills activos: canFlash → canDash → canPlungerang]

  A (Down mientras isEquiping)
    → selectItem()  [confirma selección, actualiza activeItem]

  B (Down mientras isEquiping)
    → closeMenu()
    → isGaming = true, isEquiping = false
```

---

## 📝 Notas importantes para el port

1. **El crank es el único control sin equivalente directo.** Opciones en PC:
   - Mouse wheel (más natural para "cargar")
   - Teclas Q/E
   - Gatillos del gamepad (L2/R2 analógicos)
   - El eje Y del stick derecho

2. **"Held" (1 segundo) para el menú** — en PC con teclado es familiar. Si se usa gamepad, considera también asignarlo a `Start`/`Select` para mayor accesibilidad.

3. **DanceScene en PC** — todos los botones del Playdate ya existen en un gamepad estándar. En teclado: `Space=A`, `Shift=B`, `Flechas=D-pad`. Se puede añadir `WASD` como segundo D-pad alternativo sin romper nada.

4. **`distributeMovementTokens(5)` siempre corre al pulsar B** — incluso si no se usó habilidad. Esto es intencional: el sistema turn-based avanza con B aunque el jugador no tenga skills.

5. **No hay acciones en A-Hold (cada frame)** — solo A-Down y A-Held (1 seg). Esto simplifica el port: no hay lógica de "mientras se mantiene" para A.
