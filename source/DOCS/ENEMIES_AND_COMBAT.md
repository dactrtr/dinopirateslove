# Enemies and Combat Documentation

This document explains the enemy AI system and the rhythm-based "Dance Scene" combat system.

---

## 👾 Enemy AI & Global Data

Enemies (like the `Brocorat`) inherit from the base `Enemy` class and are influenced by global stats stored in `PlayerData`.

### 1. Global Enemy Data (`PlayerData.EnemiesData`)
Located in `source/assets/data/PlayerDataTables.lua`:
- **`powerLevel`**: (1–20) Increases enemy detection range and determines difficulty profiles in the Dance Scene.
- **`sightRadius`**: Base detection distance. Each enemy's effective radius = `sightRadius + powerLevel × 3`.
- **`isEvolved`**: Boolean flag indicating if enemies have reached a more dangerous state.

### 2. Detection & Movement
- **`search(player)`**: Checks if the player is within the enemy's calculated `sightRadius`. If detected, triggers `blindSearch`.
- **`blindSearch(player)`**: Moves the enemy directly toward the player's current X/Y.
- **`linealSearch(player)`**: Alternative AI — enemy only moves if player is aligned on the same X or Y axis within `viewRange`.
- **Sight radius formula** (set in `Brocorat:init`):
    ```lua
    self.sightRadius = PlayerData.EnemiesData.sightRadius + self.powerLevel * 3
    ```
    where `self.powerLevel = PlayerData.EnemiesData.powerLevel + PlayerData.sanityCounter`.
- **Speed Scaling**: `updateMoveSpeed()` adjusts enemy speed based on player battery and darkness.
- **Group Separation**: Enemies (group `enemy`) are distinct from Crew Members (`crewMember`).

### 3. AI Throttling (Performance)
Brocorat (and likely other enemy subclasses) **only execute AI every 3 frames**:
```lua
function Brocorat:update()
    self.updateFrameCounter = (self.updateFrameCounter + 1) % 3
    if self.movementFrames > 0 then
        self.movementFrames = self.movementFrames - 1
        if self.updateFrameCounter == 0 then
            self:search(self.player)  -- AI runs only 1 in 3 frames
        end
    end
end
```
Random initial offset (0–2) staggers enemies so they don't all update the same frame.

> [!IMPORTANT]
> When porting, preserve this 3-frame throttle. Running enemy AI every frame is a significant performance hit on constrained hardware.

### 4. Movement Token System
Enemies consume `movementFrames` each update. Two mechanisms feed these frames:
- **Per player step**: `distributeMovementFrames(3)` — adds 3 raw frames per player move.
- **On B press**: `distributeMovementTokens(5)` — adds 5 tokens × 30 frames/token = 150 frames.

A cap of 90 frames (3 seconds at 30fps) prevents budget accumulation.

### 5. Special Behaviors
- **Sonar**: `sonar()` makes enemies briefly "shine" when player is focused and in darkness.
- **Projectile Hit**: If hit by Plungerang, `blind(60)` stops movement for 60 frames.
- **Blinding (Lightburst)**: `blind(frames)` temporarily stops movement.
- **Edible Props**: Some enemies can "eat" certain `PropItem` objects if power is high enough, destroying the prop and gaining power.

---

## 💃 Dance Scene (Combat System)

The `DanceScene` is a rhythm mini-game triggered when the player's health drops critically low.

### 1. Trigger Condition
In `collisions.lua`, when an `Enemy` hits the player:
1. HP is reduced by `other.damage` (default: 1).
2. **If `healthPoints < danceThresholdHP`** (default: 1), `self:fight()` is called.
3. `fight()` increments `PlayerData.amountDances`, stores enemy info in `PlayerData.lastEnemyTouched`, and transitions to `DanceScene`.
4. If HP is still above the threshold, `startInvincibility(1000)` fires instead (1-second cooldown).

> [!NOTE]
> `danceThresholdHP` defaults to 1 in `PlayerDataTables.lua`. The Dance Scene activates when `HP < 1` (i.e., at 0 or below after taking damage), not on the first collision.

### 2. Difficulty Profiles
`scene:determineEnemyType()` picks a profile based on `PlayerData.EnemiesData.powerLevel`:

| Type | Power Level | BPM | Buttons |
|---|---|---|---|
| `basic` | 1–5 | 16 | 4 |
| `evolve` | 6–12 | 24 | 6 |
| `badass` | 13–19 | 28 | 8 |
| `boss` | 20 | 32 | 12 |

`scene:determineDifficultyUpgrade()` uses weighted sanity, power, and calories to calculate a probability of upgrading from `basic`. If a random roll succeeds, the type is upgraded; otherwise it stays `basic`.

### 3. Rhythm Mechanics
- **ButtonPress**: Sprites move right-to-left across the screen.
- **HitZone**: Area on the left where the correct button must be pressed.
- **Balance Bar**: Tug-of-war indicator between Win (right) and Lose (left).
    - **Correct A/B press**: Deals 10 damage to enemy HP, shifts balance right (+5).
    - **Correct Arrow press**: Increases evade power/accuracy, shifts balance by `+accuracy`.
    - **Wrong/Miss**: Shifts balance left (−5), or passively drifts left (+accuracy per missed tick).

### 4. Outcomes
- **Win** (`balancePosition >= balanceMaxOffset`): Enemy is removed via `findAndKillEnemyById`. Player gains 60 calories and heals by `PlayerData.healedHP`. Transitions back to the room via `Noble.transition(returnRoom, ...)`.
- **Lose** (`balancePosition <= -balanceMaxOffset`): Transitions to **`TitleScene`** (Game Over), not `DeadScene`.

> [!IMPORTANT]
> `DanceScene:exit()` always calls `SaveSystem.save()`, whether the player wins or loses.

> [!NOTE]
> The `determineDifficultyUpgrade()` function uses a weighted calculation of `sanityCounter`, `EnemiesData.powerLevel`, and `calories` to decide if an encounter should be harder than the base `basic` level.

---

## 🛠️ Love2D Porting Guide: Rhythm Combat

### 1. Input Handling (`Noble.Input` vs. `love.keypressed`)
```lua
function DanceScene:keypressed(key)
    if key == "return" or key == "space" then
        self:danceStep("aButton")
    elseif key == "escape" or key == "shift" then
        self:danceStep("bButton")
    elseif key == "left" then self:danceStep("leftButton")
    elseif key == "right" then self:danceStep("rightButton")
    elseif key == "up" then self:danceStep("upButton")
    elseif key == "down" then self:danceStep("downButton")
    end
end
```
The `scene:danceStep(key)` logic is platform-agnostic and can be reused directly.

### 2. Visual Primitives & Drawing
- **Primitives**: `love.graphics.rectangle('line', ...)` and `love.graphics.line(...)`.
- **Centered Images**: `love.graphics.draw(img, x - img:getWidth()/2, y - img:getHeight()/2)`.

### 3. Scene Lifecycle
Use a library like **Hump Gamestate** — `enter`, `update`, `draw`, `leave` map closely to Noble's lifecycle.

### 4. Randomness (RNG)
- Replace `playdate.getCurrentTimeMilliseconds()` seed with `math.randomseed(os.time())` in `love.load()`.

### 5. Hit Detection
`HitZone` uses `overlappingSprites()`. In Love2D, use AABB intersection:
```lua
function checkOverlap(a, b)
    return a.x < b.x + b.w and a.x + a.w > b.x and
           a.y < b.y + b.h and a.y + a.h > b.y
end
```

### 6. AI Throttling (Porting Note)
`playdate.timer` is not available in Love2D. For the 3-frame throttle, use a frame counter:
```lua
-- Replace playdate.timer usage with a simple counter
self.frameCounter = (self.frameCounter + 1) % 3
if self.frameCounter == 0 then
    self:search(player)
end
```
