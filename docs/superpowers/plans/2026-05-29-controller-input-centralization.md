# Controller Input Centralization — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Centralize all controller input in `InputBindings.lua` with edge-detection (`wasPressed`) and right-stick crank emulation so menus, dialogs, and the crank work correctly on any gamepad.

**Architecture:** `InputBindings.lua` gains `update(joystick)` / `wasPressed(action)` / `getCrankDelta()`. `main.lua` calls `Input.update` once per frame. All one-shot actions in `gameScene` and `InGameMenu` switch from polling `input.a` to `Input.wasPressed("AButton")`, fixing the continuous-fire bug.

**Tech Stack:** LÖVE 11.5, Lua 5.4, no test framework — verification is done by running the game with `./run_game.sh`.

**Spec:** `docs/superpowers/specs/2026-05-29-controller-input-centralization-design.md`

---

## File Map

| File | Change |
|---|---|
| `source/assets/data/ControllerConfig.lua` | Add `crankX`/`crankY` axes to all 5 profiles |
| `source/assets/data/InputBindings.lua` | Add state vars + `update`, `wasPressed`, `getCrankDelta` |
| `source/main.lua` | Call `Input.update(activeJoystick)` in `love.update` |
| `source/scenes/gameScene.lua` | Replace `input.a`/`input.b`/`input.menuOpen` one-shots with `Input.wasPressed`; add `getCrankDelta` |
| `source/entities/UI/InGameMenu.lua` | Menu navigation uses `Input.wasPressed` |

---

## Task 1: Add Right Stick Axes to ControllerConfig

**Files:**
- Modify: `source/assets/data/ControllerConfig.lua`

- [ ] **Step 1: Add `crankX`/`crankY` to the DualSense profile**

In `ControllerConfig.lua`, find the DualSense profile's `axes` line (around line 27) and replace:
```lua
        axes     = { horizontal = "leftx", vertical = "lefty" },
```
with:
```lua
        axes     = { horizontal = "leftx", vertical = "lefty", crankX = "rightx", crankY = "righty" },
```

- [ ] **Step 2: Same change for DualShock 4, Xbox, Pro Controller, and default**

Apply the identical `axes` replacement to the remaining four profiles (lines ~48, ~69, ~89, ~109). Each profile's `axes` line goes from:
```lua
        axes     = { horizontal = "leftx", vertical = "lefty" },
```
to:
```lua
        axes     = { horizontal = "leftx", vertical = "lefty", crankX = "rightx", crankY = "righty" },
```

- [ ] **Step 3: Verify no syntax errors**

Run:
```bash
cd /Users/dactrtr-mini/Documents/GitHub/DinopiratesLove/dinopirateslove
./run_game.sh
```
Expected: game loads normally to title screen with no errors in console.

- [ ] **Step 4: Commit**
```bash
git add source/assets/data/ControllerConfig.lua
git commit -m "feat: add right stick axes (crankX/crankY) to all controller profiles"
```

---

## Task 2: Enhance InputBindings with `update`, `wasPressed`, `getCrankDelta`

**Files:**
- Modify: `source/assets/data/InputBindings.lua`

- [ ] **Step 1: Add require and module-level state at the top of the file**

After the first line (`-- assets/data/InputBindings.lua`) and before `local Input = {}`, insert:
```lua
local ControllerConfig = require 'assets.data.ControllerConfig'
```

After the `local Input = {}` line, insert:
```lua
-- Frame state for edge detection
local prevState          = {}
local curState           = {}

-- Crank emulation state (right stick)
local pendingCrankDelta  = 0
local prevCrankAngle     = nil
local crankAccum         = 0
local CRANK_THRESHOLD    = math.rad(30)
```

- [ ] **Step 2: Add `Input.update(joystick)` before the `return Input` line**

```lua
-- Call once per love.update frame, before sceneManager.update.
-- Snapshots current button state for wasPressed/wasReleased queries.
function Input.update(joystick)
    prevState = curState
    curState  = {}

    -- Keyboard polling
    for action, keys in pairs(keyBindings) do
        for _, k in ipairs(keys) do
            if love.keyboard.isDown(k) then
                curState[action] = true
                break
            end
        end
    end

    if joystick then
        local deadzone = ControllerConfig.getDeadzone(joystick)

        -- Gamepad button polling (uses SDL standard layout via padBindings)
        if joystick:isGamepad() then
            for action, buttons in pairs(padBindings) do
                for _, btn in ipairs(buttons) do
                    if joystick:isGamepadDown(btn) then
                        curState[action] = true
                        break
                    end
                end
            end
        end

        -- Left stick → directional actions (OR'd with d-pad above)
        local lx = ControllerConfig.getAxis(joystick, "horizontal")
        local ly = ControllerConfig.getAxis(joystick, "vertical")
        if lx < -deadzone then curState["left"]  = true end
        if lx >  deadzone then curState["right"] = true end
        if ly < -deadzone then curState["up"]    = true end
        if ly >  deadzone then curState["down"]  = true end

        -- Right stick → crank accumulation
        local rx = ControllerConfig.getAxis(joystick, "crankX")
        local ry = ControllerConfig.getAxis(joystick, "crankY")
        if rx * rx + ry * ry > deadzone * deadzone then
            local angle = math.atan2(ry, rx)
            if prevCrankAngle ~= nil then
                local delta = angle - prevCrankAngle
                if delta >  math.pi then delta = delta - 2 * math.pi end
                if delta < -math.pi then delta = delta + 2 * math.pi end
                crankAccum = crankAccum + delta
                if math.abs(crankAccum) >= CRANK_THRESHOLD then
                    pendingCrankDelta = crankAccum
                    crankAccum = 0
                end
            end
            prevCrankAngle = angle
        else
            prevCrankAngle = nil
            crankAccum     = 0
        end
    end
end
```

- [ ] **Step 3: Add `Input.wasPressed` and `Input.getCrankDelta` before `return Input`**

```lua
-- Returns true only on the first frame an action goes from not-held to held.
-- Works for both keyboard and gamepad.
function Input.wasPressed(action)
    return (curState[action] == true) and not (prevState[action] == true)
end

-- Returns accumulated right-stick crank rotation in radians (positive = clockwise).
-- Clears the pending value; call at most once per frame.
function Input.getCrankDelta()
    local d = pendingCrankDelta
    pendingCrankDelta = 0
    return d
end
```

- [ ] **Step 4: Run the game and confirm no require/syntax errors**

```bash
./run_game.sh
```
Expected: game loads normally. The new functions exist but nothing calls them yet, so behavior is unchanged.

- [ ] **Step 5: Commit**
```bash
git add source/assets/data/InputBindings.lua
git commit -m "feat: add Input.update, Input.wasPressed, Input.getCrankDelta to InputBindings"
```

---

## Task 3: Wire `Input.update` in `main.lua`

**Files:**
- Modify: `source/main.lua` (around line 194)

> **Note on input table:** The spec proposed removing `a`/`b`/`y`/`menuOpen` from the `handleGamepadInput` output table. We do NOT do this — `PauseMenu:gamepadInput` still uses `input.a`, `input.b`, and `input.start` with its own `lastInputs` edge detection and is explicitly out of scope. The full table stays intact; only `gameScene` switches to `Input.wasPressed`.

- [ ] **Step 1: Call `Input.update` at the top of `love.update`**

Find the `love.update(dt)` function (line 194). Add `Input.update(activeJoystick)` as the very first line inside it:

```lua
function love.update(dt)
	Input.update(activeJoystick)   -- ← ADD THIS LINE
	sceneManager.update(dt)

	-- Hold AButton → abrir menú de equipo (dispara una sola vez por hold)
	if Input.isDown("AButton") then
```

`Input` is already a global (set in `main.lua` line 37: `Input = require 'assets.data.InputBindings'`), so no new require needed.

- [ ] **Step 2: Run the game and play a few seconds**

```bash
./run_game.sh
```
Expected: game loads and plays normally. `Input.update` running each frame should have no visible effect yet because `gameScene` still uses the old `input.a` polling.

- [ ] **Step 3: Commit**
```bash
git add source/main.lua
git commit -m "feat: call Input.update each frame to track press/release state"
```

---

## Task 4: Fix One-Shot Actions and Crank in `gameScene.lua`

**Files:**
- Modify: `source/scenes/gameScene.lua` (function `gameScene.gamepadInput`, around line 1357)

- [ ] **Step 1: Add crank dispatch at the top of `gameScene.gamepadInput`**

Find `function gameScene.gamepadInput(input)` (line 1357). After the opening line and before the `pauseMenu:gamepadInput` call, insert:

```lua
function gameScene.gamepadInput(input)
	-- Crank via right stick
	local cd = Input.getCrankDelta()
	if cd ~= 0 and gameScene.player and gameScene.player.handleCrankInput then
		gameScene.player:handleCrankInput(cd)
	end

	-- Let pause menu handle gamepad input first
	local action = gameScene.pauseMenu:gamepadInput(input)
```

- [ ] **Step 2: Replace `input.menuOpen` open-check with `Input.wasPressed`**

Find (around line 1376):
```lua
		if input.menuOpen and PlayerData.isGaming and PlayerData.items.hasDWatch then
```
Replace with:
```lua
		if Input.wasPressed("menuOpen") and PlayerData.isGaming and PlayerData.items.hasDWatch then
```

- [ ] **Step 3: Replace `input.y or input.b` close-check with `Input.wasPressed`**

Find (around line 1368):
```lua
		if input.y or input.b then
```
Replace with:
```lua
		if Input.wasPressed("menuOpen") or Input.wasPressed("BButton") then
```

- [ ] **Step 4: Replace `input.a` dialog/interact check with `Input.wasPressed`**

Find (around line 1390):
```lua
		-- Also check for 'A' button to interact or advance dialog
		if input.a then
```
Replace with:
```lua
		-- Also check for 'A' button to interact or advance dialog
		if Input.wasPressed("AButton") then
```

- [ ] **Step 5: Run the game and verify dialog behavior**

```bash
./run_game.sh
```
Start a game, walk up to an NPC or trigger that opens a dialog. Hold the A button on the controller.
Expected: dialog advances **one step** per press, not continuously while held.

- [ ] **Step 6: Verify InGameMenu open/close**

With a D-Watch item available (`PlayerData.items.hasDWatch = true`), press the Triangle/X/Y button.
Expected: InGameMenu opens. Press the same button or Circle/A/B to close.
Expected: menu opens and closes with a single press, not rapidly cycling.

- [ ] **Step 7: Verify crank (if a minifier room is available)**

Walk the player onto a minifier tile (`PlayerData.readyToShrink` becomes true — the `crankClock` icon appears in the HUD). Rotate the right stick in a circular motion clockwise or counterclockwise past ~30°.
Expected: player toggles between tiny and normal size.

- [ ] **Step 8: Commit**
```bash
git add source/scenes/gameScene.lua
git commit -m "fix: use Input.wasPressed for one-shot gamepad actions in gameScene; wire right-stick crank"
```

---

## Task 5: Fix InGameMenu Navigation

**Files:**
- Modify: `source/entities/UI/InGameMenu.lua` (function `InGameMenu:gamepadInput`, around line 133)

- [ ] **Step 1: Replace polling navigation with edge-triggered navigation**

Find `InGameMenu:gamepadInput` (line 133):
```lua
function InGameMenu:gamepadInput(input)
    if not PlayerData.isEquiping then return false end
    if input.right or (input.leftx and input.leftx > 0.5) then
        self:nextItem(); return true
    elseif input.left or (input.leftx and input.leftx < -0.5) then
        self:prevItem(); return true
    end
    return false
end
```
Replace with:
```lua
function InGameMenu:gamepadInput(input)
    if not PlayerData.isEquiping then return false end
    if Input.wasPressed("right") then self:nextItem(); return true end
    if Input.wasPressed("left")  then self:prevItem(); return true end
    return false
end
```

`Input` is global, accessible here. `wasPressed("right")` fires when d-pad right OR left-stick right passes the deadzone for the first frame — so both input methods navigate the menu.

- [ ] **Step 2: Run the game and open the InGameMenu**

```bash
./run_game.sh
```
Open the InGameMenu (Triangle/X/Y button while `hasDWatch = true`). Press the d-pad right/left or push the left stick right/left.
Expected: menu items cycle **one step** per press, not continuously.

Expected: releasing and re-pressing moves exactly one item at a time.

- [ ] **Step 3: Verify keyboard navigation still works**

While InGameMenu is open, press the right/left arrow keys (or d/a).
Expected: items cycle one step per key press (unchanged from before).

- [ ] **Step 4: Commit**
```bash
git add source/entities/UI/InGameMenu.lua
git commit -m "fix: InGameMenu navigation uses Input.wasPressed for proper edge detection"
```

---

## Final Verification

- [ ] **Full controller play test**

```bash
./run_game.sh
```

With a controller connected, verify all of the following in one session:

| Action | Button | Expected |
|---|---|---|
| Move player | Left stick or D-pad | Smooth movement |
| Interact / advance dialog | A (PS ✕ / NSW B / Xbox A) | One step per press |
| Use equipped item | B (PS ○ / NSW A / Xbox B) | Fires once per press |
| Open InGameMenu + map | Y (PS △ / NSW X / Xbox Y) | Opens once |
| Navigate InGameMenu | Left/right d-pad or L-stick | One item per press |
| Close InGameMenu | Same Y or B button | Closes once |
| Open pause menu | Start / Options | Opens once |
| Navigate pause menu | Up/down d-pad | One item per press |
| Confirm pause menu | A button | Fires once |
| Close pause menu | B button | Closes once |
| Crank (on minifier) | Right stick circular | Toggles size at ~30° rotation |

- [ ] **Keyboard smoke test**

Disconnect the controller and verify keyboard controls unchanged: `z`/`enter`/`space` for A, `x`/`lshift` for B, `i` for menu, arrows for movement.
