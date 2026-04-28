# Enemies and Combat Documentation

This document explains the enemy AI system and the rhythm-based "Dance Scene" combat system.

---

## 👾 Enemy AI & Global Data

Enemies (like the `Brocorat`) inherit from the base `Enemy` class and are influenced by global stats stored in `PlayerData`.

### 1. Global Enemy Data (`PlayerData.EnemiesData`)
Located in `source/assets/data/PlayerDataTables.lua`, these values scale the difficulty of the game:
- **`powerLevel`**: (1-20) Increases enemy detection range and determines difficulty profiles in the Dance Scene.
- **`sightRadius`**: The base detection radius. Default value comes from `Config.Enemy.sightRadiusBase` (set in `Config.lua`), which `PlayerDataTables.lua` reads at startup. Each enemy's effective radius is `PlayerData.EnemiesData.sightRadius + self.powerLevel * 3` (see `brocorat.lua`).
- **`isEvolved`**: This field **does not exist**. Enemy evolution state is computed dynamically each encounter inside `DanceScene:determineEnemyType()`, not stored as a persistent flag.

### 2. Detection & Movement
- **`search(player)`**: Implemented in `Brocorat` (and `CrewMember`) as subclass overrides — **not** in the base `Enemy` class. `Brocorat:search()` checks if the player is within `sightRadius` and triggers `blindSearch` if detected. `CrewMember:search()` does the opposite — it calls `escape()` (flees away from the player) unless the player is out of vision or is tiny.
- **`blindSearch(player)`**: Moves the enemy directly toward the player's current X/Y.
- **`linealSearch(player)`**: An alternative AI where enemies only move if the player is aligned on the same X or Y axis.
- **Speed Scaling**: `updateMoveSpeed()` adjusts enemy speed based on the player's battery and darkness. They slow down significantly when the player is in darkness with low battery.
- **Group Separation**: Enemies (group `enemy`) are distinct from Crew Members (group `crewMember`). This separation prevents the player from unintentionally triggering combat-specific logic (like the Dance Scene) when interacting with crew members.
  > [!WARNING]
  > **Bug in `crewmember.lua:exitHiding()`**: When a CrewMember exits the hiding state, it incorrectly restores the `enemy` collision group instead of `crewMember` (`self:setGroups(CollideGroups.enemy)`). This causes post-hiding CrewMembers to be treated as enemies by the collision system.
- **Movement Tokens**: Like CrewMembers, enemies use `movementFrames` to throttle their updates for performance.

### 3. Special Behaviors
- **Sonar / Shine** ⚠️ *NOT IN USE — call is commented out in both `brocorat.lua:107` and `crewmember.lua:496`*: `sonar()` is defined in `enemy.lua` and intended as an off-screen visual indicator. Full intended behavior:
    1. **Trigger condition**: player is more than 60px away on the X axis — `(PlayerData.x - 60) > self.x` OR `(PlayerData.x + 60) < self.x`.
    2. **Shine conditions** (all three must be true): `PlayerData.isFocused == true`, `PlayerData.isInDarkness == true`, `PlayerData.sanity > 0`.
    3. **When shining**: randomizes `animation.shine.frameDuration` to a value between 1–16 (producing a flickering effect), switches animation state to `'shine'` (frames 9–14 in `brocorat`), and raises `ZIndex` to `10` to render the enemy above other sprites.
    4. **When conditions not met**: restores the enemy's original `ZIndex` and switches animation back to `'idle'`.
- **Projectile (Plungerang)**: Hit detection logic in `projectile.lua` includes `CollideGroups.enemy`. If hit, `hitEntity(other)` is called, which typically blinds/stuns the enemy for 60 frames.
- **Blinding**: `blind(frames)` temporarily stops enemy movement when hit by a light flash or projectile.
- **Edible Props**: Some enemies can "eat" certain `PropItem` objects if their `powerLevel > Config.Enemy.eatPropPowerThreshold` (default 25). Note: each Brocorat's local `powerLevel` is initialized as `PlayerData.EnemiesData.powerLevel + PlayerData.sanityCounter`, so this threshold can be reached even at low global power levels.

---

## 💃 Dance Scene (Combat System)

When a player collides with a `Brocorat` and their health drops below `PlayerData.danceThresholdHP`, the game transitions to the `DanceScene`. Collisions above that threshold only grant invincibility frames.

### 1. The Transition
In `collisions.lua`, when the player collides with a `Brocorat`:
1. `lastEnemyTouched` is updated with the enemy's ID, Type, and Position.
2. The collision type returned is **`'overlap'`** — the player and enemy pass through each other; no physics push occurs.
3. Damage is applied only if `self.isInvincible == false`: `PlayerData.healthPoints -= other.damage`.
4. If `healthPoints < PlayerData.danceThresholdHP` (default 5), `self:fight()` is called → increments `PlayerData.amountDances` and transitions to `DanceScene`.
5. If health is **at or above** `danceThresholdHP`, `startInvincibility(Config.Invincibility.duration)` is called instead — **no DanceScene is triggered**.

**Invincibility & Blink**: `startInvincibility(duration)` sets `isInvincible = true` and starts a countdown timer (default `1000 ms`, from `Config.Invincibility.duration`). Each frame in `update()`, the timer decrements and the player sprite toggles between visible/invisible using `setVisible()`, driven by `math.floor(timer / Config.Invincibility.flickerRate) % 2` (default `flickerRate = 100`). When the timer reaches 0, `isInvincible` is reset and the sprite is forced visible.

> [!NOTE]
> `fight()` itself (in `player/state.lua`) only increments `amountDances` and calls `Noble.transition(DanceScene)`. It does not store `lastEnemyTouched` — that happens in `collisions.lua` before `fight()` is called.

> [!NOTE]
> `amountDances` is incremented **twice** per successful combat: once in `fight()` when the encounter starts, and again in `checkDanceResults()` when the player wins.

### 2. Difficulty Profiles
The `DanceScene` selects a pattern profile based on `PlayerData.EnemiesData.powerLevel`. However, the selection is **probabilistic** — `determineDifficultyUpgrade()` does a weighted random roll first using `PlayerData.sanityCounter` (normalized against 100), calories, and power. If the roll fails, the encounter defaults to `"basic"` regardless of power level.

- **Basic** (1-5): Slow BPM (16), 4 buttons, mostly arrows.
- **Evolve** (6-12): Faster BPM (24), 6 buttons, mixed input.
- **Badass** (13-19): Very fast BPM (28), 8 buttons, tough patterns.
- **Boss** (20): Max speed BPM (32), 12 buttons, high button spam.

### 3. Pre-Battle "Ready" Screen
Before the rhythm phase starts, `DanceScene` shows a `ResultsScreen` in a `'ready'` state with `PlayerData.isDancing = false`. The player must press **A** to trigger `startBattle()` and begin the button pattern. This pre-battle moment is separate from the rhythm mechanics.

### 4. Rhythm Mechanics
- **ButtonPress**: Sprites move from right to left across the screen.
- **HitZone**: The area on the left where the player must press the corresponding button.
- **Balance Bar**: A "tug-of-war" indicator.
    - **Correct Press**: Moves balance toward the **Win** side. `A/B` buttons deal damage to enemy HP; **Arrows** increase evade power/accuracy.
    - **Wrong Press/Miss**: Moves balance toward the **Lose** side.
- **Animations**: `EnemyRatDance` plays attack animations on A/B button presses. `PlayerDance:changeAnimation()` only responds to the **four directional arrow buttons** — A/B do not change the player sprite animation.

### 5. Outcomes
- **Win**: The enemy is removed from the world via `findAndKillEnemyById`, the player gains 60 calories **and** recovers `PlayerData.healedHP` health points, then transitions back to the maze.
- **Lose**: Transitions to the `TitleScene` (Game Over).

> [!IMPORTANT]
> The `determineDifficultyUpgrade()` function in `DanceScene` uses a weighted probability roll based on `PlayerData.sanityCounter` (not the raw `sanity` value), power level, and calories. The result is probabilistic — a high power level increases the *chance* of a hard profile, but a failed roll always defaults to `"basic"`.

---

## 🛠️ Love2D Porting Guide: Rhythm Combat

This section details implementation of the **DanceScene** mechanics in Love2D.

### 1. Input Handling (`Noble.Input` vs. `love.keypressed`)
Playdate uses a table-based `inputHandler` with callbacks like `AButtonDown`.
- **Love2D Implementation**:
    - Use the standard `love.keypressed(key)` callback in your Scene state.
    - **Mapping**:
        ```lua
        function DanceScene:keypressed(key)
            if key == "return" or key == "space" then
                self:input("aButton")
            elseif key == "escape" or key == "shift" then
                self:input("bButton")
            elseif key == "left" then self:input("leftButton")
            elseif key == "right" then self:input("rightButton")
            elseif key == "up" then self:input("upButton")
            elseif key == "down" then self:input("downButton")
            end
        end
        ```
    - The `DanceScene.lua` logic for `scene:danceStep(key)` can be reused almost exactly once the input is routed.

### 2. Visual Primitives & Drawing
The scene relies on `Graphics.drawRect`, `drawLine`, and `drawCentered` (Playdate SDK).
- **Love2D Implementation**:
    - **Primitives**: Use `love.graphics.rectangle('line', ...)` and `love.graphics.line(...)`.
    - **Images**: Playdate images have methods like `drawCentered(x, y)`. In Love2D, `love.graphics.draw(img, x, y)` draws from the top-left.
        - **Correction**: To draw centered: `love.graphics.draw(img, x - img:getWidth()/2, y - img:getHeight()/2)`.

### 3. Scene Lifecycle
The game uses `NobleScene` for management (`init`, `enter`, `update`, `exit`).
- **Love2D Implementation**:
    - Use a library like **Hump Gamestate**. The method names `enter`, `update`, `draw`, `leave` map very closely to Noble's lifecycle.
    - **Transitions**: Complex transitions (like `MetroNexus`) are specific to Noble. You will need to implement custom screen wipes (e.g., a simple fade-to-black or sliding rectangle) in Love2D.

### 4. Randomness (RNG)
The scene seeds RNG using `playdate.getCurrentTimeMilliseconds()` to ensure unique difficulty rolls.
- **Love2D Implementation**:
    - Use `math.randomseed(os.time())` in `love.load()`.
    - Lua's `math.random` works consistently across both platforms.

### 5. Hit Detection
The `HitZone` checks for overlapping sprites (`overlappingSprites()`).
- **Love2D Implementation**:
    - Since `ButtonPress` objects are simple moving entities (not full physics bodies), you can use simple AABB (Rectangle) intersection checks in `update()`:
    ```lua
    function checkOverlap(a, b)
        return a.x < b.x + b.w and a.x + a.w > b.x and
               a.y < b.y + b.h and a.y + a.h > b.y
    end
    ```

---

## 🛠️ Love2D Porting Guide: Enemy Collisions & Invincibility

This section covers porting the **player-enemy collision**, **damage**, and **invincibility blink** systems from Playdate to Love2D.

### 1. Collision Type (`'overlap'`)
On Playdate, `Player:collisionResponse()` returns `'overlap'` when touching a Brocorat — the Noble/Playdate collision system still fires the callback but applies no physics response (no push-back).
- **Love2D Implementation**:
    - Use `love.physics` (Box2D) sensors, or skip physics entirely and do manual AABB overlap checks each frame. Sensors fire `beginContact` callbacks without generating forces:
    ```lua
    -- In love.load(), mark the enemy fixture as a sensor:
    enemyFixture:setSensor(true)

    -- In the beginContact callback:
    function love.handlers.beginContact(a, b, coll)
        if a.userData == "player" and b.userData == "brocorat" then
            player:onHitByEnemy(b.userData)
        end
    end
    ```
    - If not using Box2D, a simple per-frame AABB check in `update()` is equivalent:
    ```lua
    if rectsOverlap(player.rect, enemy.rect) then
        player:onHitByEnemy(enemy)
    end
    ```

### 2. Damage & Dance Threshold
The Playdate logic in `collisions.lua`:
```lua
if not self.isInvincible then
    healthPoints -= enemy.damage
    if healthPoints < danceThresholdHP then
        self:fight()      -- → DanceScene
    else
        self:startInvincibility(duration)
    end
end
```
- **Love2D Implementation**: The logic is pure Lua with no SDK dependency — copy it directly into your `Player:onHitByEnemy(enemy)` method. Replace `Noble.transition(DanceScene)` with your gamestate transition (`Gamestate.switch(DanceScene)`).

### 3. Invincibility Blink
The Playdate blink uses a millisecond timer divided by `flickerRate` to toggle sprite visibility:
```lua
-- In Player:update() on Playdate (state.lua):
if isInvincible then
    invincibilityTimer -= 1000 / refreshRate   -- e.g. 1000/50 = 20ms per frame
    if math.floor(invincibilityTimer / flickerRate) % 2 == 0 then
        self:setVisible(false)
    else
        self:setVisible(true)
    end
    if invincibilityTimer <= 0 then
        isInvincible = false
        self:setVisible(true)
    end
end
```
- **Love2D Implementation**: Use `love.timer.getDelta()` to decrement the timer in seconds. Replace `setVisible()` with a boolean flag checked in `draw()`:
    ```lua
    -- In Player:update(dt):
    if self.isInvincible then
        self.invincibilityTimer = self.invincibilityTimer - dt * 1000  -- keep ms units
        local flickerRate = 100  -- same as Config.Invincibility.flickerRate
        self.visible = math.floor(self.invincibilityTimer / flickerRate) % 2 ~= 0
        if self.invincibilityTimer <= 0 then
            self.isInvincible = false
            self.visible = true
        end
    end

    -- In Player:draw():
    if self.visible then
        love.graphics.draw(self.sprite, self.x, self.y)
    end
    ```
    - `flickerRate = 100` (ms) at 50 fps produces ~5 blinks per second. Tune this value to match the feel.
