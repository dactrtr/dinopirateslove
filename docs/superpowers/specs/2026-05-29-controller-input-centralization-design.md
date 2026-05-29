# Controller Input Centralization — Design Spec

**Date:** 2026-05-29  
**Status:** Approved

---

## Problem

Three concrete issues stem from one root cause:

1. **Menu navigation broken on controller** — `handleGamepadInput` runs every frame in `love.update`, so `input.right = true` while held cycles menu items 60×/second.
2. **Dialogs/interactions broken on controller** — same cause: `input.a = true` each frame advances dialog/triggers every tick.
3. **Crank not mapped to right stick** — `player:handleCrankInput` is only called from `gameScene.wheelmoved` (mouse wheel). The right stick axes are not wired anywhere.

Secondary issue: button mappings are fragmented across `InputBindings.lua`, `ControllerConfig.lua`, and raw `input.a`/`input.b` checks scattered in `gameScene.lua` and `InGameMenu.lua`.

---

## Button Mapping (Canonical Reference)

SDL remaps all controllers to a standard layout. The following is already correct in `ControllerConfig.lua` and needs no changes — this table serves as documentation.

| Game action | Playdate | PlayStation | Nintendo Switch | Xbox | Keyboard |
|---|---|---|---|---|---|
| AButton | A | ✕ Cross | B | A | z / enter / space |
| BButton | B | ○ Circle | A | B | x / lshift |
| menuOpen | — | △ Triangle | X | Y | i |
| pause | Menu | Options / Start | + | Menu | escape / p |
| up/down/left/right | D-pad | D-pad / L-stick | D-pad / L-stick | D-pad / L-stick | arrow keys / wasd |

---

## Architecture

`InputBindings.lua` becomes the **single source of truth** for all input. Scenes call only `Input.*` methods — never raw `input.a` table fields for one-shot actions.

```
InputBindings.lua
├── keyBindings        action → [keyboard keys]
├── padBindings        action → [SDL button names]
├── isDown(action)     held on keyboard OR gamepad
├── update(joystick)   call once per love.update frame; snapshots cur/prev state
├── wasPressed(action) true only on the first frame a button goes down
└── getCrankDelta()    accumulated right-stick rotation in radians (0 when idle)
```

`ControllerConfig.lua` remains the hardware catalog (deadzone, raw indices, axis names per controller). `InputBindings` calls into it to read analog values.

---

## Right Stick → Crank

The Playdate crank tracks **accumulated angle** with clockwise/counterclockwise sign. The right stick emulates this via `atan2(ry, rx)`.

State lives in `InputBindings` (module-local):

```
prevCrankAngle  nil | number   — angle from last frame when stick was outside deadzone
crankAccum      number         — accumulated radians since last fire
CRANK_THRESHOLD math.rad(30)  — degrees before getCrankDelta() returns non-zero
```

**Each frame in `Input.update(joystick)`:**
1. Read `rightx`, `righty` via `ControllerConfig.getAxis`.
2. If magnitude `< deadzone²`: reset `prevCrankAngle` and `crankAccum` to 0.
3. Otherwise: compute `angle = atan2(ry, rx)`, delta = `angle - prevCrankAngle` normalized to `[-π, π]`, accumulate.
4. When `|crankAccum| >= CRANK_THRESHOLD`: store as pending crank delta, reset accumulator.

`Input.getCrankDelta()` returns the pending delta (with sign) and clears it. Sign convention: positive = clockwise, negative = counterclockwise — matches Playdate SDK `change` parameter.

---

## Files Changed

### 1. `source/assets/data/ControllerConfig.lua`

Add `crankX = "rightx"` and `crankY = "righty"` to the `axes` table in **all 5 profiles** (DualSense, DualShock 4, Xbox, Pro Controller, default).

```lua
axes = { horizontal = "leftx", vertical = "lefty", crankX = "rightx", crankY = "righty" },
```

No other changes to ControllerConfig.

### 2. `source/assets/data/InputBindings.lua`

Add internal state and three new public functions. `isDown` stays unchanged.

**New state (module-local):**
```lua
local prevState = {}       -- action → bool, snapshot from previous frame
local curState  = {}       -- action → bool, current frame
local pendingCrankDelta = 0
local prevCrankAngle    = nil
local crankAccum        = 0
local CRANK_THRESHOLD   = math.rad(30)
```

**`Input.update(joystick)`** — call from `love.update` before scenes update:
- Snapshot `curState → prevState`
- For each action in `keyBindings`: check `love.keyboard.isDown` → `curState[action]`
- If joystick provided: for each action in `padBindings`: check `ControllerConfig.isDown(js, action)` → OR into `curState[action]`
- Analog movement (up/down/left/right) from left stick also OR'd into `curState`
- Right stick crank accumulation (see above) → sets `pendingCrankDelta`

**`Input.wasPressed(action)`:**
```lua
return curState[action] and not prevState[action]
```

**`Input.getCrankDelta()`:**
```lua
local d = pendingCrankDelta
pendingCrankDelta = 0
return d
```

### 3. `source/main.lua`

- In `love.update(dt)`: call `Input.update(activeJoystick)` **before** `sceneManager.update(dt)`.
- `handleGamepadInput(dt)`: keep for analog movement dispatch only. Remove one-shot button fields (`a`, `b`, `x`, `y`, `menuOpen`) from the `input` table — scenes will use `Input.wasPressed` instead. Keep `left/right/up/down` booleans for smooth movement.
- The existing AButton hold-timer for `__menuOpen__` remains — it fires a synthetic keypressed which gameScene already handles correctly.
- Crank accumulation is handled inside `Input.update`, so no crank-specific code needed in `main.lua`.

**`handleGamepadInput` output table (simplified):**
```lua
{ left, right, up, down, start, back }
```

### 4. `source/scenes/gameScene.lua`

Replace all one-shot `input.a` / `input.b` checks with `Input.wasPressed`:

| Location | Old | New |
|---|---|---|
| Dialog advance | `if input.a then player:displayDialog()` | `if Input.wasPressed("AButton") then` |
| Trigger interact | `if input.a then checkTriggerInteraction()` | `if Input.wasPressed("AButton") then` |
| Item use (BButton) | `if input.b then` (if present) | `if Input.wasPressed("BButton") then` |
| Open InGameMenu | `if input.menuOpen and ...` | `if Input.wasPressed("menuOpen") and ...` |
| Close InGameMenu | `if input.y or input.b then` | `if Input.wasPressed("menuOpen") or Input.wasPressed("BButton") then` |

Add crank check in `gameScene.gamepadInput` (or `gameScene.update`):
```lua
local cd = Input.getCrankDelta()
if cd ~= 0 and gameScene.player then
    gameScene.player:handleCrankInput(cd)
end
```

### 5. `source/entities/UI/InGameMenu.lua`

Replace polling navigation with edge-triggered:

```lua
function InGameMenu:gamepadInput(input)
    if not PlayerData.isEquiping then return false end
    if Input.wasPressed("right") then self:nextItem(); return true end
    if Input.wasPressed("left")  then self:prevItem(); return true end
    return false
end
```

The `input` parameter is kept for signature compatibility but one-shot decisions use `Input.wasPressed`.

---

## What Is Not Changing

- `PauseMenu.lua` — already has its own `lastInputs` edge detection; works correctly. Simplification is out of scope.
- `Player:handleCrankInput` — no changes; already accepts signed delta.
- `DanceScene` — out of scope for this spec.
- `InputBindings.danceKeys` — unchanged.
- All keyboard paths — unchanged; `Input.wasPressed` covers them automatically since `update` polls keyboard too.

---

## Edge Cases

- **Joystick disconnected mid-game**: `Input.update(nil)` — skip gamepad polling, keyboard still works.
- **Stick drift in crank zone**: deadzone check (`magnitude < deadzone²`) prevents false crank events when stick is released.
- **Menu opened and closed in same frame**: `wasPressed` is edge-triggered so rapid open/close is safe.
- **First frame after joystick connect**: `prevState` is empty → all `wasPressed` return false until next frame.
