# Config.lua — Complete Reference

`source/assets/data/Config.lua` is the **single source of truth** for all tunable
constants. No magic numbers should appear in gameplay code — every value that
controls behavior lives here.

Available globally as `Config`. Also aliased in `main.lua`:
- `ZIndex = Config.ZIndex`
- `CollideGroups = Config.CollideGroups`

See [ARCHITECTURE.md](ARCHITECTURE.md) for boot order and why aliases exist.

---

## Config.ZIndex

Controls rendering layer order. Higher = drawn on top. Used in every entity's `:setZIndex()` call.

| Field | Value | Used by |
|---|---|---|
| `player` | 4 | `Player:init` |
| `enemy` | 3 | `Brocorat:init`, `bosscolli:init` |
| `props` | 2 | `PropItem:init` |
| `items` | 4 | `Items:init` |
| `foreground` | 300 | `MazeScene:enter` foreground sprite |
| `fx` | 1999 | `FXshadow:init` |
| `ui` | 2000 | `UIHud` |
| `hud` | 2000 | `playerHud` |
| `menu` | 2100 | `inGameMenu`, `skillInfo` |
| `alert` | 2200 | Toast notifications |

**Love2D equivalent:** Sort your entity list by a numeric `zIndex` field before drawing in `love.draw()`.

---

## Config.CollideGroups

Numeric IDs for Playdate's sprite collision system. Every sprite that should interact with
other sprites must call `:setGroups(id)` and `:setCollidesWithGroups({ids})`.

| Field | Value | Entity |
|---|---|---|
| `player` | 1 | `Player` |
| `enemy` | 2 | `Brocorat`, `bosscolli` |
| `props` | 3 | `PropItem` (physical props) |
| `items` | 4 | `Items` (pickups) |
| `wall` | 5 | `Box` (tile wall colliders) |
| `noCollide` | 6 | Decorative/passthrough objects |
| `crewMember` | 7 | `CrewMember` |

**Love2D equivalent:** bump.lua collision filters — return `"cross"` (ghost), `"touch"`, `"slide"`,
or `"bounce"` based on the `other` entity type.

---

## Config.Tiles

Controls tilemap interpretation. See also [TILE_LOADING.md](TILE_LOADING.md).

| Field | Value | Used by |
|---|---|---|
| `size` | 16 | `GetTileUnderPlayer`, tile collider sizing |
| `IntGrid.wall` | 1 | `CreateTileColliders` — non-walkable tile |
| `IntGrid.slime` | 2 | `IsPlayerOnSlime()`, `checkSlimeTile()` |
| `IntGrid.hole` | 3 | `IsPlayerOnHole()` |
| `IntGrid.floor` | 4 | Walkable, no special effect |

**Critical:** Slime and holes are detected by reading IntGrid values from `tileMapData` at runtime.
They are NOT prop entities. Any IntGrid value NOT in `{2,3,4}` is treated as a wall.

---

## Config.Player

| Field | Value | Used by |
|---|---|---|
| `speed` | 1.5 | `Player:move` — px per frame at 50fps |
| `speedDarkNoLamp` | 0.7 | Speed multiplier in darkness without lamp |
| `speedLowBattery` | 0.8 | Speed multiplier when `battery < batteryThresholdLow` |
| `collideRect` | `{x=8,y=24,w=30,h=24}` | Normal player collision box |
| `collideRectTiny` | `{x=19,y=32,w=10,h=10}` | Tiny mode collision box |
| `collideRectHead` | `{x=8,y=8,w=16,h=16}` | Head collider for foreground depth check |
| `uiOffsetX` | 30 | HUD anchor offset from player |
| `uiOffsetY` | 30 | HUD anchor offset from player |
| `hudOffsetY` | -40 | `playerHud` Y offset (normal size) |
| `hudOffsetYTiny` | -17 | `playerHud` Y offset (tiny mode) |
| `triggerCheckDist` | 5 | px moved before re-checking trigger overlap |

**Love2D note:** `speed` of 1.5 px/frame at 50fps = 75 px/s. In Love2D multiply by `dt * 50`
or define as `75` px/s directly.

---

## Config.Battery

| Field | Value | Effect |
|---|---|---|
| `drainMovementDark` | 0.5 | Drained per frame moved in darkness |
| `drainHoleNormal` | 0.5 | Drained per frame while crossing a hole (normal size) |
| `drainHoleTiny` | 0.2 | Drained per frame while crossing a hole (tiny) |

**Love2D note:** Multiply drain values by `dt * targetFPS` to make drain frame-rate independent.

---

## Config.Sanity

| Field | Value | Effect |
|---|---|---|
| `tickInterval` | 2000 ms | How often sanity is recalculated |
| `lossLowBattery` | 2 pts/tick | When `battery < batteryThresholdLow` (20) |
| `lossMidBattery` | 1 pt/tick | When `battery < batteryThresholdMid` (40) |
| `gainHighBattery` | 2 pts/tick | When `battery > batteryThresholdHigh` (50) or not in darkness |
| `batteryThresholdLow` | 20 | Battery level that triggers fast sanity drain |
| `batteryThresholdMid` | 40 | Battery level that triggers slow sanity drain |
| `batteryThresholdHigh` | 50 | Battery level that triggers sanity recovery |
| `focusCost` | 20 | Sanity consumed by focus ability (unused/legacy) |

---

## Config.Dash

| Field | Value | Effect |
|---|---|---|
| `speed` | 6 | px per frame during dash |
| `totalDistance` | 56 | px traveled before stopping |
| `bounceDistance` | 16 | px remaining when bounce-back triggers |
| `batteryCost` | 10 | Battery drained on activation |
| `cooldown` | 500 ms | Minimum time between dashes |

---

## Config.Slide

| Field | Value | Effect |
|---|---|---|
| `speed` | 4 | px per frame while sliding on slime |

---

## Config.Invincibility

| Field | Value | Effect |
|---|---|---|
| `duration` | 1000 ms | How long player is invincible after being hit |
| `flickerRate` | 100 | Divides the timer for the blink visual effect |

---

## Config.LightBurst

| Field | Value | Effect |
|---|---|---|
| `batteryCost` | 10 | Battery drained on use |
| `cooldown` | 1000 ms | Minimum time between flashes |
| `displayTime` | 1000 ms | How long the cone stays visible |
| `coneDistance` | 200 px | Depth of the light cone polygon |
| `coneHeight` | 12 | Width scaling factor of the cone |
| `blindDuration` | 60 frames | How long hit entities stay blinded |

---

## Config.Projectile (Plungerang)

| Field | Value | Effect |
|---|---|---|
| `maxDistance` | 100 px | Distance before auto-returning |
| `speed` | 8 px/frame | Linear movement speed |
| `blindDuration` | 60 frames | How long hit enemies stay blinded |

See [PLUNGERANG.md](PLUNGERANG.md) for full mechanic details.

---

## Config.Doors

| Field | Value | Used by |
|---|---|---|
| `positions.right` | `{x=393, y=122}` | Door sprite placement on screen |
| `positions.left` | `{x=4, y=122}` | Door sprite placement |
| `positions.down` | `{x=203, y=228}` | Door sprite placement |
| `positions.top` | `{x=203, y=2}` | Door sprite placement |
| `spawnCoords.top` | `{x=196, y=196}` | Where player spawns entering from top door |
| `spawnCoords.down` | `{x=196, y=32}` | Where player spawns entering from bottom door |
| `spawnCoords.right` | `{x=32, y=116}` | Where player spawns entering from right door |
| `spawnCoords.left` | `{x=364, y=116}` | Where player spawns entering from left door |

See [DOORS_AND_KEYS.md](DOORS_AND_KEYS.md) for full navigation details.

---

## Config.CrewMember

| Field | Value | Effect |
|---|---|---|
| `bouncesRequiredToHide` | 2 | Consecutive bounces before hiding |
| `bounceFrames` | 20 | Frames spent in redirected bounce direction |
| `bounceCountDecayRate` | 30 frames | Frames before recent bounce count resets |
| `hidingVisionRange` | 80 px | Distance player must be before crew unhides |
| `hidingTokensRequired` | 3 | Movement tokens needed to exit hiding |
| `blindDuration` | 60 frames | Frames stunned by plungerang hit |
| `framesPerToken` | 30 | Frames of movement granted per token |
| `movementFramesCap` | 90 | Max queued movement frames |
| `batteryThresholdStop` | 10 | Battery level where crew stops moving |
| `batteryThresholdRestore` | 60 | Battery level where crew resumes speed |
| `collideRect` | `{x=12,y=24,w=24,h=24}` | Crew member collision box |

See [CREWMEMBER_AND_COLLISIONS.md](CREWMEMBER_AND_COLLISIONS.md) for full details.

---

## Config.Screen

| Field | Value | Effect |
|---|---|---|
| `width` | 400 | Canvas width (px) |
| `height` | 240 | Canvas height (px) |
| `randomBoundsX` | `{min=20, max=380}` | Safe random X range for entity spawning |
| `randomBoundsY` | `{min=20, max=220}` | Safe random Y range for entity spawning |

---

## Config.Pedometer

| Field | Value | Effect |
|---|---|---|
| `stepsPerMovement` | 0.5 | Steps added per `player:move()` call |
| `stepsToTrigger` | 200 | Steps accumulated before burning calories |
| `caloriesPerBurn` | 10 | Calories burned when threshold reached |
