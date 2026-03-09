# Player Systems Documentation

This document explores the `PlayerData` structure and how its values influence the player's movement, survival, and interaction with the game world.

---

## 🔋 Core Resource: Battery

The Battery system is the primary driver of exploration and danger.

- **Consumption**:
    - Drains **0.5 units per `Player:move()` call** when `PlayerData.isInDarkness == true` (in `movement.lua`).
    - Additional drain via `drainBattery(amount)` from specific item interactions (e.g., walking over holes with boots).
- **Impacts**:
    - **Sanity**: Sanity drains faster when `battery < 20 AND isInDarkness` (see Sanity section below).
    - **Darkness/Light**: The FXshadow system scales battery internally by ×2 to determine light cone size and opacity.
- **Charging**:
    - The player can charge the battery using the crank (via `chargeBattery(amount)`).
    - Charging sets `isActive = true`, allowing enemies to move while the player stays in place.

---

## 🧠 Survival: Sanity & Calories

Sanity and Nutrition represent the player's mental and physical health.

- **Sanity** (timer-based, fires every 2 seconds via `playdate.timer.keyRepeatTimerWithDelay`):
    - **Drain (fast)**: −2×`sanityLoss` when `battery < 20 AND isInDarkness == true`.
    - **Drain (slow)**: −1×`sanityLoss` when `battery < 40 AND isInDarkness == true`.
    - **Regen**: +2×`sanityLoss` when `battery > 50` OR `isInDarkness == false`.
    - **Sanity Counter**: Every time sanity hits 0, `sanityCounter` increments. This increases the global **Enemy Power Level**, making encounters more difficult.
- **Health**:
    - **Representation**: Stored as `healthPoints` (default 10).
    - **HUD**: Represented by 5 hearts, where each heart is 2 points (total 10 hp).
    - **Dance Threshold**: When hit by an enemy and `healthPoints < danceThresholdHP` (default: 1), the game transitions to `DanceScene` instead of applying invincibility.
    - **Sync**: Updated in real-time in the HUD via the `HealthIndicator` class.
- **Calories & Steps**:
    - The `pedometer()` tracks steps. 200 steps = 10 calories burned.
    - **Calories** influence the difficulty roll of the `DanceScene`. Higher calories contribute to a higher probability of encountering "Badass" or "Boss" enemy profiles.

---

## 🏎️ State & Synchronization: `isActive`

The `isActive` flag is a critical internal value.

- **Turn-based Sync**: `isActive` is set to `true` whenever the player moves or charges.
- **NPC Movement**: Enemies and CrewMembers only process AI movement when they have movement budget (`movementFrames > 0`).
- **Movement Distribution** (two mechanisms):
    - `distributeMovementFrames(3)` — called per `Player:move()` call (each step gives all enemy sprites 3 raw frames of movement budget).
    - `distributeMovementTokens(5)` — called on **B button press** in `MazeScene.lua`. 1 token = 30 frames, so 5 tokens = 150 frames of enemy movement budget.

> [!NOTE]
> The difference: `distributeMovementFrames` distributes **raw frames** (small, per-step amounts). `distributeMovementTokens` distributes **tokens** (each worth ~30 frames), used for events like the B press that grant a larger burst of enemy action.

---

## 🌑 Darkness & Lighting: FXshadow

The `FXshadow` system controls the visibility mask in dark rooms.

### Internal Battery Scaling
Battery is scaled ×2 internally before lighting calculations:
```lua
local battery = PlayerData.battery * 2  -- Range 0–200 (from 0–100)
```

### Lighting Tiers (with Lamp)
When `PlayerData.items.hasLamp == true`, 5 tiers apply based on `battery * 2`:

| battery×2 range | lightAmount | Notes |
|---|---|---|
| > 160 | default | Near-full brightness |
| 120–160 | 0.2 | Light dimming begins |
| 80–120 | 0.5 | Moderate darkness |
| 40–80 | 0.7 | Heavy darkness |
| 0–40 | 0.9 | Nearly dark |
| ≤ 0 | 1.0 | Maximum darkness |

### Without Lamp
```lua
maskSize = 50       -- Very small circle of visibility
lightAmount = 1     -- Near-total darkness
```

### Light Cone Polygon
When `PlayerData.showLightCone == true` AND `hasLamp == true`, a **9-point polygon** is drawn in the player's facing direction (using `playdate.geometry.polygon.new(...)` with 9 vertex pairs). The cone is directional: left/right uses horizontal polygon, up/down uses vertical polygon.

### Dirty Flag Optimization
`FXshadow:refresh()` only redraws when any of these change:
- `battery` (scaled value)
- `direction`
- Player X/Y position
- `lightSizeMulti` (tiny mode = 0.5)
- `globalLightAmount`
- `showLightCone`

### Love2D Porting
```lua
-- Use a Canvas with multiply blend mode
local shadowCanvas = love.graphics.newCanvas(400, 240)
love.graphics.setBlendMode("multiply")

-- Draw the global dither background
love.graphics.setCanvas(shadowCanvas)
love.graphics.setColor(0, 0, 0, globalDither)
love.graphics.rectangle("fill", 0, 0, 400, 240)

-- Draw the light polygon
love.graphics.setColor(1, 1, 1, 1 - lightAmount)
love.graphics.polygon("fill", lightVertices)  -- 9-point table {x1,y1, x2,y2, ...}

love.graphics.setCanvas()
love.graphics.setBlendMode("alpha")
love.graphics.draw(shadowCanvas, 0, 0)
```

---

## 🤏 Transformation: Size & Collisions

- **`isTiny`**:
    - Toggled via the **Minifier** prop (crank-based interaction).
    - Changes the player's collision rectangle to a smaller **14×14** size.
    - Enables access to "Hole" props and changes enemy behavior (smaller sight radius).
    - Changes animation states to `tiny` variants (`tinyLeft`, `tinyRight`, etc.).
    - Changes HUD Y-offset from −36 to −22.
- **`isBig`**: Managed via the transformation cycle, though less used in primary maze logic.

---

## ↕️ Level Transitions: Falling & Climbing

Vertical transitions allow the player to move between floors through holes, tubes, or ladders.

### `fallBelow()`
1. Gets current floor from `PlayerData.floor`.
2. Validates "Lower" connection in `DoorsConnection`.
3. Searches `neighbourLevels` for direction `<`.
4. Calculates target room number.
- **Positioning**: Preserves `x` and `y` coordinates for seamless verticality.
- **Visuals**: Uses `transitionFall` imagetable for a falling effect.

### `riseAbove()`
- Similar to `fallBelow()` but checks for "Upper" connection and direction `>`.
- Trigger: collision with tubes or ladders.

---

## 🎒 Inventory & Skills

- **Items**:
    - `hasLamp`: Enables vision and sanity regeneration. Grants **Lightburst** skill (`canFlash`).
    - `hasBoots`: Provides "Hole" safety; player drains battery to walk over holes. Grants **Dash** skill (`canDash`).
    - `hasPlunger`: Provides "Slime" safety; player walks over slime tiles (IDs 89–97) without sliding. Grants **Plungerang** skill (`canPlungerang`).
    - `hasBag`: Required to capture CrewMembers.
    - `hasDWatch`: Required for the HUD and In-Game Menu to be visible/functional.
    - `hasRadio` / `hasNotes`: Story-relevant items enabling specific dialogs/video feeds.
- **Skills**:
    - `canFlash` (Lightburst): Costs **10 battery**. Blinds enemies in a radius. Also distributes `distributeMovementTokens(1)` on activation.
    - `canDash`: Costs **10 battery**. Travels **56 pixels** at **speed 6** (pixels/frame). On collision, bounces back **16 pixels**. Granted by `hasBoots`.
    - `canPlungerang`: Boomerang skill. No battery cost. Requires **both** `hasPlunger` AND `canPlungerang`. Movement is **always** locked (`isPlunging = true`) while the projectile is in flight. See [PLUNGERANG.md](PLUNGERANG.md).

> [!TIP]
> Always check `PlayerData.isInDarkness`. Most survival mechanics (Sanity drain, Battery drain) are gated by this boolean. Also check `hasDWatch` for HUD and menu availability.

---

## 🛠️ Love2D Porting Guide

### 1. Movement & Collisions (`NobleSprite` vs. Bump.lua)
The Playdate SDK handles collisions internally via `sprite:moveWithCollisions(x, y)`.
- **Playdate**: returns `actualX, actualY, collisions, length`.
- **Love2D Implementation**:
    ```lua
    local actualX, actualY, cols, len = world:move(self, goalX, goalY, self.collisionFilter)
    self.x, self.y = actualX, actualY
    ```

### 2. Input Handling
- **Movement**: Map WASD or Arrow Keys to `Player:move(dir)`.
- **A Button (Action)**: Space/Enter for skills and dialogs.
- **B Button**: Distributes 5 movement tokens to all enemies (`distributeMovementTokens(5)`).
- **Crank (Minifier)**: Remap to scroll wheel (mouse), Q/E keys, or gamepad triggers.

### 3. Sprite System & Animation
- Use `anim8` for animations based on the player spritesheet.
- Z-Indexing: sort entities by Y position manually before drawing.

### 4. Turn-Based "Active" State
```lua
-- Per move: distribute 3 frames of budget
function Player:move(dir)
    PlayerData.isActive = true
    -- ... movement logic ...
    self:distributeMovementFrames(3)
end

-- On B press: distribute 5 tokens (= 150 frames)
function Player:onBPress()
    self:distributeMovementTokens(5)
end
```
Preserve this **exactly**. Do not switch enemies to continuous `dt`-based updates.

### 5. Scene Transitions
- Replace `Noble.transition` with a custom scene manager.
- Fall/climb transitions use imagetable animations — replace with shaders or sprite sequences.

### 6. Skills & Abilities
- **Lightburst**: Cone geometry uses `playdate.geometry.polygon`. In Love2D, use `love.graphics.polygon()` with a vertex table.
- **Dash**: During dash, move at `dashSpeed = 6` pixels/frame for up to `dashTotalDistance = 56` pixels. On collision, bounce back `dashBounceDistance = 16` pixels.
- **Plungerang**: Separate entity; use Bump.lua `cross` filter for player/items, `touch` for enemies/walls.

### 7. FXshadow (Darkness)
See dedicated FXshadow section above. Key points:
- Use `Canvas` with `love.graphics.setBlendMode('multiply')`.
- Light polygon via `love.graphics.polygon('fill', ...)`.
- Implement dirty-flag to avoid redrawing every frame.

### 8. Performance
- **Trigger Checks**: Only check overlapping if player moved significantly.
- **Invincibility**: Flicker effect by toggling visibility on a timer.
- **Sliding**: When `isSliding`, override directional input entirely.
