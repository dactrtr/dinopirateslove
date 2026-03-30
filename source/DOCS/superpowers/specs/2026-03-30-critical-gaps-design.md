# Design: Critical Gaps Implementation
**Date:** 2026-03-30
**Scope:** Three critical missing systems — Lightburst skill, DanceScene Love2D port, fight() wiring

---

## Context

The Love2D port has movement, collisions, FXshadow, HUD, triggers, save system, and CrewMember fully working. Three critical systems are missing that break the core gameplay loop:

1. **Lightburst** (`canFlash`) — skill is granted when lamp is collected but the activation key binding and enemy-blinding logic don't exist.
2. **DanceScene** — the file on disk (`scenes/DanceScene.lua`) is Playdate SDK code (never committed). All battle UI sub-components (`ButtonPress`, `HitZone`, etc.) don't exist as Love2D Lua files. Only image assets are present.
3. **`fight()` stub** — `collisions.lua:416` only prints a debug line. The enemy collision never transitions to DanceScene.

---

## Piece 1: Lightburst Skill

### Activation
- Key binding: `"flash"` mapped to `Z` (keyboard) and left bumper / `X` button (gamepad). Configured via `Config.Keys.flash`.
- Guard conditions (all must pass):
  - `PlayerData.skills.canFlash == true`
  - `PlayerData.activeItem == 1` (lamp selected)
  - `PlayerData.battery >= 10`
  - cooldown elapsed (1000ms, tracked via `hump.timer`)
- On activation: drain 10 battery, set `PlayerData.showLightCone = true`, schedule `PlayerData.showLightCone = false` after 1000ms via `Timer.after`.
- FXshadow already renders the extended cone when `showLightCone == true` — no changes needed there.

### Enemy Blinding
- After setting `showLightCone`, query bump world for all entities within the cone's bounding box.
- Bounding box of the cone: player position ± (d=200, h=12) — roughly `(px-200, py-96, 400, 192)`.
- For each candidate entity, call `FXshadow.buildConeVertices(px, py, dir, 200, 12)` (already exported) and run a point-in-polygon check (ray casting) on the entity's center.
- If inside cone: call `entity:blind(60)` on enemies and crewMembers.
- Point-in-polygon helper lives in `utilities.lua` (new function `Utilities.pointInPolygon(pts, x, y)`).

### Files changed
- `scenes/gameScene.lua` — add `"flash"` key handler in `gameScene.keypressed` and `gameScene.gamepadInput`
- `utilities.lua` — add `Utilities.pointInPolygon(pts, x, y)`
- `entities/player/init.lua` — add `Player:lightBurst()` method that runs the activation guard + blinding logic

---

## Piece 2: DanceScene Love2D Port

### Architecture
DanceScene is a **Love2D scene table** (same pattern as `gameScene`): a module that exports `enter(data)`, `update(dt)`, `draw()`, `keypressed(key)`, `gamepadInput(input)`, `leave()`. Registered in `sceneManager` as `"dance"`.

All game logic from the existing Playdate file is reused as-is (difficulty profiles, pattern weights, balance mechanic, BPM/button counts). Only the class system, lifecycle methods, and rendering are replaced.

### Data passed on enter
`sceneManager.startTransition` signature is `(from, to, type, animationName)` — no data parameter. DanceScene reads enemy data directly from `PlayerData.lastEnemyTouched` (already set by `fight()` before the transition). No changes needed to sceneManager.

### Sub-modules (new files in `entities/UI/battle/`)
Each is a simple table module. All drawing uses the 400×240 virtual canvas (same as gameScene).

| File | Responsibility |
|---|---|
| `buttonPress.lua` | Moving sprite (right→left at BPM speed). State: `x`, `key`, `hit`, `missed`. Image: `button-table-32-32.png` |
| `hitZone.lua` | Static rect at x≈40. Detects AABB overlap with ButtonPress. Draws `hitzone-table-10-40.png` |
| `playerDance.lua` | anim8 animation. Responds to arrow key presses only. Image: `playerDance-table-246-214.png` |
| `enemyRatDance.lua` | anim8 animation. Responds to A/B presses. Image: `enemyDance-table-211-214.png` |
| `resultsScreen.lua` | "Ready" pre-battle screen + Win/Lose result overlay. Image: `resultsdance-table-400-240.png` |
| `backgroundDance.lua` | Static background. Image: `background-table-400-240.png` |
| `buttonCover.lua` | Covers hit zone area. Image: `buttoncover-table-78-58.png` |
| `winIndicator.lua` / `loseIndicator.lua` | Small indicators. Image: `playerIndicator/enemyIndicator-table-39-31.png` |

### ButtonPress movement
Speed = `400 / (60 / bpm * 60)` pixels per second (crosses screen in one beat at 60fps). Each button starts at x=400+offset, moves left each `update(dt)`. Missed if x < 0 without being hit.

### Input routing
`main.lua` already routes `love.keypressed` to the active scene. DanceScene implements:
```lua
function DanceScene.keypressed(key)
    -- Map to internal button names, call DanceScene.danceStep(btnName)
end
```
Mapping matches `ENEMIES_AND_COMBAT.md`: space/return → aButton, escape/shift → bButton, arrows → directional.

### Balance bar
`balancePosition` in range `[-balanceMaxOffset, +balanceMaxOffset]`. Correct hit → moves toward +max (win side). Wrong/miss → moves toward -min (lose side). Win when `balancePosition >= balanceMaxOffset`. Lose when `balancePosition <= -balanceMaxOffset`.

Drawn as a horizontal bar centered at screen center (x=200, y=56), 8px wide bars, using `love.graphics.rectangle`.

### Pre-battle "ready" state
On `enter()`, `PlayerData.isDancing = false`. ResultsScreen shows a "ready" banner. Player must press A to call `DanceScene.startBattle()`, which sets `PlayerData.isDancing = true` and starts button movement delays.

---

## Piece 3: `fight()` Wiring + Result Callbacks

### `fight()` in `collisions.lua`
Replace the stub with:
```lua
function collisions.fight(player)
    PlayerData.amountDances = (PlayerData.amountDances or 0) + 1
    sceneManager.startTransition("game", "dance", "slide")
end
```

### sceneManager registration
`sceneManager` needs `"dance"` registered. Check how `"game"` and `"title"` are registered and follow the same pattern. `require "scenes.DanceScene"` at the top of `sceneManager.lua`.

### Win callback (in DanceScene)
```lua
function DanceScene.onWin()
    -- Kill the enemy that triggered the fight
    gameScene.findAndKillEnemyById(PlayerData.lastEnemyTouched.id)
    -- Heal player
    PlayerData.healthPoints = math.min(
        PlayerData.healthPoints + (PlayerData.healedHP or 1),
        Config.Player.maxHealth or 3
    )
    -- Add calories reward
    PlayerData.calories = (PlayerData.calories or 0) + 60
    sceneManager.startTransition("dance", "game", "slide")
end
```

### Lose callback (in DanceScene)
```lua
function DanceScene.onLose()
    sceneManager.startTransition("dance", "title", "slide")
end
```

### `findAndKillEnemyById` in `gameScene`
Already exists (referenced in the docs). Verify it's present and works with the `lastEnemyTouched.id` field. If missing, add it: iterate `gameScene.enemies`, find by `enemy.id`, call `enemy:remove()` and remove from table.

---

## Implementation Order

1. `Utilities.pointInPolygon` + `Player:lightBurst()` + gameScene key binding (Piece 1)
2. Battle sub-modules (`entities/UI/battle/*.lua`) (Piece 2 foundation)
3. `scenes/DanceScene.lua` rewrite using sub-modules (Piece 2 core)
4. Register DanceScene in sceneManager (Piece 2 wiring)
5. `fight()` stub replacement + verify `findAndKillEnemyById` (Piece 3)
6. Win/Lose callbacks (Piece 3)

---

## Constraints

- All drawing must target the 400×240 virtual canvas — never hardcode 800×480.
- DanceScene must not use any Playdate SDK calls (`Noble`, `import`, `Graphics.sprite`, etc.).
- `PlayerData` is the single source of truth — DanceScene reads `lastEnemyTouched` from it, not from function arguments.
- The balance mechanic uses integer steps, not dt-scaled — each button hit/miss moves `balancePosition` by a fixed amount.
