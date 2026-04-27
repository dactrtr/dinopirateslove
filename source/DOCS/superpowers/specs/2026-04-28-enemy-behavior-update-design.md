# Enemy Behavior Update — Design Spec

**Date:** 2026-04-28
**Branch:** dev
**Reference:** `DOCS/ENEMIES_AND_COMBAT.md`

---

## Overview

Three missing behaviors identified by audit against `ENEMIES_AND_COMBAT.md`. All are independent and can be implemented separately.

---

## Feature 1: Invincibility Blink

### What
When a player takes a hit but their HP is above `danceThresholdHP`, they become temporarily invincible. Currently `isInvincible = true` is set but there is **no visual feedback** — the player sprite stays fully visible. The doc specifies a blink effect using a ms-based countdown timer.

### Design

**`collisions.lua` — `startInvincibility(player, durationMs)`:**
- Remove the HUMP `Timer.after()` call
- Set `player.isInvincible = true` and `player.invincibilityTimer = durationMs`

**`player/init.lua` — initialization:**
- Add `self.invincibilityTimer = 0` and `self.visible = true` to Player constructor

**`player/state.lua` (or wherever `Player:update(dt)` lives) — update loop:**
```lua
if self.isInvincible then
    self.invincibilityTimer = self.invincibilityTimer - dt * 1000
    local flickerRate = Config.Invincibility.flickerRate or 100
    self.visible = math.floor(self.invincibilityTimer / flickerRate) % 2 ~= 0
    if self.invincibilityTimer <= 0 then
        self.isInvincible = false
        self.visible = true
    end
end
```

**`player/init.lua` — `Player:draw()`:**
```lua
if not self.visible then return end
-- ... existing draw logic
```

### Constraints
- `Config.Invincibility.flickerRate = 100` and `Config.Invincibility.duration = 1000` already exist in `Config.lua`
- `isInvincible` is already checked in `collisions.lua` before applying damage — no change needed there
- The HUMP Timer import in `startInvincibility` can be removed entirely

---

## Feature 2: Brocorat movementFrames

### What
Brocorat currently runs AI checks every frame based on `self.player.isMoving or self.player.hasMoved`. The doc specifies a **token-based throttle** (same as CrewMember): the player distributes movement tokens, enemies consume them to run AI. This aligns with the game's turn-based architecture.

### Design

**`entities/Brocorat.lua` — `initialize()`:**
Add:
```lua
self.movementFrames = 0
self.maxMovementFrames = 90
```

**`entities/Brocorat.lua` — new method:**
```lua
function Brocorat:addMovementFrames(frames)
    self.movementFrames = math.min(self.movementFrames + frames, self.maxMovementFrames)
end
```

**`entities/Brocorat.lua` — `update(dt)`:**
Replace the player-reactive check:
```lua
-- REMOVE:
if self.player and (self.player.isMoving or self.player.hasMoved) then
    self:updateMoveSpeed()
    self:search(self.player, dt)
else
    self.isMoving = false
end
```
With token consumption:
```lua
if self.movementFrames > 0 then
    self.movementFrames = self.movementFrames - 1
    self:updateMoveSpeed()
    self:search(self.player, dt)
else
    self.isMoving = false
end
```

### Integration
`Player:distributeMovementFrames(frames)` in `entities/player/init.lua` already iterates `gameScene.enemies[]` and calls `enemy:addMovementFrames(frames)`. Once Brocorat has the method, distribution works automatically with no changes to the player.

### Constraints
- Cap at 90 frames (same as CrewMember's `maxMovementFrames`)
- `self.player` reference remains in Brocorat — `search()` still needs it for positioning

---

## Feature 3: Sonar Flicker

### What
`Enemy:sonar()` was implemented in a previous task and correctly switches to the `shine` animation when the player is >60px off-screen in darkness/focus mode. However, the doc specifies a **flicker effect**: randomizing `animation.shine.frameDuration` each time shine is active, producing a stuttering/irregular flash.

Sonar is implemented but not guaranteed to be active in gameplay yet. The flicker logic belongs inside `sonar()` regardless — it fires when the method is called.

### Design

**`entities/Enemy.lua` — `sonar()`, inside the shine branch:**
```lua
if self.animations and self.animations.shine then
    self.animations.shine.frameDuration = math.random(1, 16) / 60
    self.currentAnimation = self.animations.shine
end
```

The `frameDuration` set on anim8 animation objects controls how long each frame is displayed. Values from `1/60` (very fast, near-strobe) to `16/60` (~4fps, slow pulse) produce the flickering described in the doc.

### Constraints
- ZIndex elevation (raise to 10 when shining) is **out of scope** — sonar is not currently active in gameplay
- `math.random(1, 16) / 60` matches the doc spec exactly: "1–16" frame counts at 60fps

---

## Files Changed

| File | Change |
|---|---|
| `entities/player/collisions.lua` | `startInvincibility` — remove HUMP Timer, set countdown fields |
| `entities/player/init.lua` | Add `invincibilityTimer`, `visible`; add blink logic to `update()`; gate `draw()` on `self.visible` |
| `entities/Brocorat.lua` | Add `movementFrames`, `maxMovementFrames`, `addMovementFrames()`; replace player-reactive AI check with token consumption |
| `entities/Enemy.lua` | `sonar()` — add `frameDuration` randomization in shine branch |

---

## Out of Scope

- Sonar ZIndex elevation (doc §3, item 3) — deferred until sonar is active in gameplay
- CrewMember `exitHiding()` collision group bug — bug does not exist in current BUMP implementation
- `amountDances` double-increment — documented as intentional behavior, no change
