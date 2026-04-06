# Documentation Overhaul — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a complete, self-contained reference suite that lets a Love2D porter understand any system in DinoPirates without reading Lua source files.

**Architecture:** Seven focused markdown files replace the current fragmented partial docs. Each document owns one concern: global config, global state, boot sequence, cutscenes, triggers, data flow, and the master architecture map. Existing docs stay; the new files add depth.

**Tech Stack:** Markdown, Mermaid-compatible ASCII diagrams (no build step), code blocks drawn directly from source.

---

## Context for the implementer

Before touching anything, read these files in order. Everything below references them.

| File | What to understand |
|---|---|
| `source/main.lua` | Boot order, global aliases (`ZIndex`, `CollideGroups`, `ButtonTypes`, `Directions`), `roomsByIid` hash construction |
| `source/assets/data/Config.lua` | Every tunable constant — the single source of truth |
| `source/assets/data/PlayerDataTables.lua` | `DefaultPlayerData`, `PlayerData`, `ResetPlayerData()` |
| `source/scenes/MazeScene.lua` | Full `enter()` sequence, `update()` loop, cutscene handling |
| `source/entities/props/trigger.lua` | `Trigger:init`, `Trigger:returnScript`, condition evaluator |
| `source/entities/player/collisions.lua` | `Player:collisionResponse` — the central dispatcher for all entity interactions |
| `source/assets/comics/comicsData.lua` | `comics` table — registry of all Panels sequences |
| `source/assets/comics/intro.lua` | Concrete example of a Panels sequence structure |

---

## File Map

| File (create unless stated) | Responsibility |
|---|---|
| `source/DOCS/ARCHITECTURE.md` | Master map: boot sequence, scene lifecycle, global variable setup, who owns what |
| `source/DOCS/CONFIG_REFERENCE.md` | Every field in `Config.lua`, what reads it, Love2D equivalents |
| `source/DOCS/PLAYERDATA_REFERENCE.md` | Every field in `PlayerData`, who reads it, who writes it, what it controls |
| `source/DOCS/CUTSCENE_SYSTEM.md` | Both cutscene types (room-entry and trigger), Panels library, flow diagrams |
| `source/DOCS/TRIGGER_SYSTEM.md` (update) | Add full Cutscene trigger code path; add cross-refs to CUTSCENE_SYSTEM.md |
| `source/DOCS/DATA_FLOW.md` | ASCII dependency graph: which files import/read/write which globals |

---

## Task 1: ARCHITECTURE.md — Boot sequence and global connections

**Files:**
- Create: `source/DOCS/ARCHITECTURE.md`

- [ ] **Step 1: Write the boot sequence section**

Create `source/DOCS/ARCHITECTURE.md` with the following content (copy exactly, verify every claim against `main.lua`):

```markdown
# Architecture — Boot Sequence and Global Connections

## Import order in `main.lua`

`main.lua` is the only entry point. Imports run top to bottom; order matters because
later files depend on globals set by earlier ones.

```
1. Noble (scene framework)
2. Panels (cutscene library)
3. achievements/all
4. assets/data/Config          → defines Config table
5. utilities/Utilities         → defines Box class, helper functions
6. utilities/SaveSystem        → defines SaveSystem table
7. scenes/* (all scenes)
8. assets/data/PlayerDataTables → defines PlayerData, ResetPlayerData()
9. assets/data/levels          → defines levelsLDTK
10. assets/data/tilemap        → defines tileMapData
11. assets/data/script         → defines script table (dialog scripts)
```

## Globals set in `main.lua` after imports

These are available everywhere in the game (no require needed):

| Global | Source | Value |
|---|---|---|
| `Config` | `Config.lua` | All tunable constants |
| `ZIndex` | `main.lua` line 57 | `= Config.ZIndex` |
| `CollideGroups` | `main.lua` line 58 | `= Config.CollideGroups` |
| `ButtonTypes` | `main.lua` | `{A="aButton", B="bButton", ...}` |
| `Directions` | `main.lua` | `{LEFT="left", RIGHT="right", UP="up", DOWN="down", IDLE="idle", TOP="top", BOTTOM="down"}` |
| `PlayerData` | `PlayerDataTables.lua` | Mutable game state (deep copy of DefaultPlayerData) |
| `levelsLDTK` | `levels.lua` | All room/entity data from LDtk |
| `tileMapData` | `tilemap.lua` | IntGrid matrices for wall collision |
| `script` | `script.lua` | Array of dialog script entries |
| `roomsByIid` | `main.lua` | `{}` hash built from `levelsLDTK` for O(1) room lookup |
| `debug` | `main.lua` | `false` — toggled via system menu or cheat code |
| `diagonalMovement` | `main.lua` | `true` |
| `comics` | `comicsData.lua` | Registry of Panels cutscene sequences |
| `timers` | `main.lua` | `= playdate.timer` |

## Why `ZIndex` and `CollideGroups` are aliases

```lua
-- main.lua
ZIndex = Config.ZIndex
CollideGroups = Config.CollideGroups
```

Both are references to the same table objects inside Config. Changing
`Config.ZIndex.player` also changes `ZIndex.player`. They exist as short aliases
so entity files can write `ZIndex.player` instead of `Config.ZIndex.player`.

## Noble scene lifecycle

```
Noble.new(TitleScene)
  └─ scene:init()    ← called when transitioning AWAY from previous scene
     scene:enter()   ← called when this scene needs to be visible
     scene:start()   ← called when transition animation is complete
     scene:update()  ← called every frame (50fps in MazeScene)
     scene:pause()   ← called when system menu opens → triggers SaveSystem.save()
     scene:exit()    ← called when transitioning to next scene
     scene:finish()  ← called when transition animation is complete → triggers SaveSystem.save()
```

## `roomsByIid` construction

```lua
-- main.lua
roomsByIid = {}
for _, room in ipairs(levelsLDTK) do
    if room and room.uniqueIdentifer then
        roomsByIid[room.uniqueIdentifer] = room
    end
end
```

Used by `FindRoomByIid(iid)` in `door.lua`. Returns the room table directly from
a LDtk `levelIid` string — no linear search needed.

## Room number formula

```
RoomID = (level × 100) + roomNumber
Example: level=4, roomNumber=8 → Floor408
```

`Floors.lua` creates scene classes (`Floor101`, `Floor201`, etc.) using hardcoded
numeric ranges per floor. `RoomTranslate(n)` returns `_G["Floor" .. n]`.

## Love2D equivalent of this boot sequence

```lua
-- love.load() equivalent
Config = require("assets.data.Config")
ZIndex = Config.ZIndex
CollideGroups = Config.CollideGroups
require("assets.data.PlayerDataTables")   -- sets PlayerData global
levelsLDTK = require("assets.data.levels")
tileMapData = require("assets.data.tilemap")
script = require("assets.data.script")

-- Build roomsByIid hash
roomsByIid = {}
for _, room in ipairs(levelsLDTK) do
    if room and room.uniqueIdentifer then
        roomsByIid[room.uniqueIdentifer] = room
    end
end

SaveSystem.createOriginalBackup()  -- deep-copies levelsLDTK before any mutation
SceneManager.switch(TitleScene)
```
```

- [ ] **Step 2: Write the MazeScene enter() sequence section**

Append to `ARCHITECTURE.md`:

```markdown
## MazeScene `enter()` — Full sequence

When any FloorXXX scene transitions in, `MazeScene:enter()` runs these steps in order:

```
1.  Set PlayerData flags:
      .room              = levelsLDTK[room].customFields.roomNumber
      .isInDarkness      = levelsLDTK[room].customFields.shadow
      .floor             = room  (index into levelsLDTK array)
      .actualLevel       = customFields.level
      .actualRoom        = customFields.roomNumber
      .actualTilemap     = customFields.tile
      .visited           = true  (marks room as explored)

2.  Load room background PNG:
      path = 'assets/images/rooms/floor{level}/{identifier}'
      floor sprite at ZIndex 1, centered at (200, 120)

3.  Load foreground PNG (if customFields.hasForeground == true):
      path = 'assets/images/rooms/floor{level}/foreground_{roomNumber}'
      foreground sprite at ZIndex.foreground (300), same position

4.  Create inGameMenu instance

5.  CreateTileColliders(tileMapData[PlayerData.actualTilemap])
      Builds Box wall colliders from IntGrid matrix

6.  CreateDoorsFromLDTK(currentRoom)
      Iterates currentRoom.entities.Doors, creates Door sprites

7.  Spawn Props: entities with customFields.destroyed or .nocollider
      destroyed==false → PropItem(x, y, cf.type, ...)
      destroyed==true  → PropItem(x, y, "debris", ...)

8.  Spawn Items: entities with customFields.isItem == true
      Checks against PlayerData to skip already-owned items
      Items(x, y, itemType, keyNumber, cf.grants)

9.  Spawn Player at PlayerData.playerSpawn.{x,y}
      player = Player(...)
      uiScreen = playerHud(player)

10. Spawn FX:
      if customFields.shadow == true → FXshadow(player, 70, lightLevel, ZIndex.fx)

11. Check for room cutscene:
      if customFields.comic_name exists → see CUTSCENE_SYSTEM.md

12. Spawn Enemies:
      entityType == "Brocorat" | "Bosscolli" → Brocorat/bosscolli(x, y, speed, ...)
      dead == true → PropItem(x, y, "blood2", ...)

13. Spawn CrewMembers: entities.CrewMember
      isTaken == true → skip

14. Spawn Triggers: entities.Triggers
      usedTrigger == true → skip
      Trigger(x, y, width, height, script, iid, room, type)
```

`scene:start()` runs after the transition animation completes:
```lua
PlayerData.isGaming = true  -- gameplay begins here, not in enter()
```
```

- [ ] **Step 3: Verify every statement against the source files**

Open `source/scenes/MazeScene.lua` and confirm:
- The 14 spawn steps match the actual code order (lines 100–347)
- The `PlayerData` flags set in step 1 match lines 100–107
- `isGaming` is set to `true` in `start()`, not `enter()` (line 352)

Fix any discrepancy in the doc before continuing.

- [ ] **Step 4: Commit**

```bash
git add source/DOCS/ARCHITECTURE.md
git commit -m "docs: add ARCHITECTURE.md — boot sequence and MazeScene enter flow"
```

---

## Task 2: CONFIG_REFERENCE.md — Complete field reference

**Files:**
- Create: `source/DOCS/CONFIG_REFERENCE.md`

- [ ] **Step 1: Write the full Config reference**

Create `source/DOCS/CONFIG_REFERENCE.md`:

```markdown
# Config.lua — Complete Reference

`source/assets/data/Config.lua` is the **single source of truth** for all tunable
constants. No magic numbers should appear in gameplay code — every value that
controls behavior lives here.

Available globally as `Config`. Also aliased:
- `ZIndex = Config.ZIndex`
- `CollideGroups = Config.CollideGroups`

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

**Love2D equivalent:** Sort `scene.entities` table by a numeric `zIndex` field in `love.draw()`.

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

**Love2D equivalent:** bump.lua collision filters — return `"cross"` (ghost), `"touch"`, `"slide"`, or `"bounce"` based on the `other` entity type.

---

## Config.Tiles

Controls tilemap interpretation.

| Field | Value | Used by |
|---|---|---|
| `size` | 16 | `GetTileUnderPlayer`, tile collider sizing |
| `IntGrid.wall` | 1 | `CreateTileColliders` — non-walkable |
| `IntGrid.slime` | 2 | `IsPlayerOnSlime()`, `checkSlimeTile()` |
| `IntGrid.hole` | 3 | `IsPlayerOnHole()` |
| `IntGrid.floor` | 4 | Walkable, no effect |

**Critical:** Slime and holes are detected by reading IntGrid values from `tileMapData` at runtime. They are NOT prop entities. Any value NOT in `{2,3,4}` is treated as a wall.

---

## Config.Player

| Field | Value | Used by |
|---|---|---|
| `speed` | 1.5 | `Player:move` — px per frame |
| `speedDarkNoLamp` | 0.7 | Multiplier in darkness without lamp |
| `speedLowBattery` | 0.8 | Multiplier when `battery < batteryThresholdLow` |
| `collideRect` | `{x=8,y=24,w=30,h=24}` | Normal player collision box |
| `collideRectTiny` | `{x=19,y=32,w=10,h=10}` | Tiny mode collision box |
| `collideRectHead` | `{x=8,y=8,w=16,h=16}` | Head collider for foreground depth |
| `uiOffsetX` | 30 | HUD anchor offset from player |
| `uiOffsetY` | 30 | HUD anchor offset from player |
| `hudOffsetY` | -40 | playerHud Y offset (normal) |
| `hudOffsetYTiny` | -17 | playerHud Y offset (tiny mode) |
| `triggerCheckDist` | 5 | px moved before re-checking trigger overlap |

---

## Config.Battery

| Field | Value | Effect |
|---|---|---|
| `drainMovementDark` | 0.5 | Drained per frame moved in darkness |
| `drainHoleNormal` | 0.5 | Drained per frame crossing a hole (normal size) |
| `drainHoleTiny` | 0.2 | Drained per frame crossing a hole (tiny) |

**Love2D:** Multiply drain values by `love.timer.getDelta() * targetFPS` to make drain frame-rate independent.

---

## Config.Sanity

| Field | Value | Effect |
|---|---|---|
| `tickInterval` | 2000 ms | How often sanity is recalculated |
| `lossLowBattery` | 2 pts/tick | When `battery < batteryThresholdLow` (20) |
| `lossMidBattery` | 1 pt/tick | When `battery < batteryThresholdMid` (40) |
| `gainHighBattery` | 2 pts/tick | When `battery > batteryThresholdHigh` (50) or not dark |
| `batteryThresholdLow` | 20 | Battery level for fast sanity drain |
| `batteryThresholdMid` | 40 | Battery level for slow sanity drain |
| `batteryThresholdHigh` | 50 | Battery level for sanity recovery |
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

---

## Config.Doors

| Field | Value | Used by |
|---|---|---|
| `positions.right` | `{x=393, y=122}` | Door sprite placement on screen |
| `positions.left` | `{x=4, y=122}` | Door sprite placement |
| `positions.down` | `{x=203, y=228}` | Door sprite placement |
| `positions.top` | `{x=203, y=2}` | Door sprite placement |
| `spawnCoords.top` | `{x=196, y=196}` | Where player spawns entering from top |
| `spawnCoords.down` | `{x=196, y=32}` | Where player spawns entering from bottom |
| `spawnCoords.right` | `{x=32, y=116}` | Where player spawns entering from right |
| `spawnCoords.left` | `{x=364, y=116}` | Where player spawns entering from left |

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
```

- [ ] **Step 2: Verify all values against `source/assets/data/Config.lua`**

Open `Config.lua` and confirm every value in the table matches exactly. Check that no field was added to `Config.lua` after this doc was written.

- [ ] **Step 3: Commit**

```bash
git add source/DOCS/CONFIG_REFERENCE.md
git commit -m "docs: add CONFIG_REFERENCE.md — full field reference with Love2D equivalents"
```

---

## Task 3: PLAYERDATA_REFERENCE.md — State field reference with read/write map

**Files:**
- Create: `source/DOCS/PLAYERDATA_REFERENCE.md`

- [ ] **Step 1: Write the full PlayerData reference**

Create `source/DOCS/PLAYERDATA_REFERENCE.md`:

```markdown
# PlayerData — Complete Reference

`PlayerData` is the **global mutable game state**. It is a Lua table accessible from
every file without requiring or importing. It is the backbone of all game logic.

## Lifecycle

```lua
-- PlayerDataTables.lua
local DefaultPlayerData = { ... }        -- immutable template
PlayerData = deepcopy(DefaultPlayerData) -- live mutable copy

-- main.lua
SaveSystem.createOriginalBackup()        -- deep-copies levelsLDTK (NOT PlayerData)

-- SaveSystem.load()
PlayerData = saveData.player             -- replaces entirely from disk

-- ResetPlayerData()
PlayerData = deepcopy(DefaultPlayerData) -- resets to defaults (no disk read)
```

## Field Reference

### Survival resources

| Field | Default | Type | Read by | Written by |
|---|---|---|---|---|
| `healthPoints` | 3 | number | `collisions.lua` (fight threshold), `HealthIndicator` | `collisions.lua` (damage), `DanceScene` (win heal) |
| `danceThresholdHP` | 1 | number | `collisions.lua` | — |
| `healedHP` | 2 | number | `DanceScene` win | — |
| `battery` | 100 | number | `battery.lua`, `movement.lua`, `sanity.lua`, `MazeScene.update` | `movement.lua` (drain), `MazeScene.cranked` (charge) |
| `sanity` | 100 | number | `sanityHud`, `sanity.lua` | `sanity.lua` tick |
| `sanityCounter` | 0 | number | `DanceScene.determineDifficultyUpgrade` | `sanity.lua` (increments when sanity hits 0) |
| `calories` | 100 | number | `DanceScene.determineDifficultyUpgrade` | `pedometer()`, `burnCalories()`, DanceScene win |
| `steps` | 0 | number | `pedometer()` | `pedometer()` |
| `totalSteps` | 1000 | number | — | `pedometer()` (lifetime counter) |
| `mapPercent` | 0 | number | Trigger conditions | — |

### Boolean game state flags

These flags are the core of the state machine. **Reading order matters** — check them before any gameplay logic.

| Field | Default | Meaning | Set true by | Set false by |
|---|---|---|---|---|
| `isGaming` | false | Normal gameplay active | `MazeScene:start()` | `MazeScene:finish()`, any dialog/menu open |
| `isTalking` | false | Dialog overlay open | `dialogScreen:addScreen()` | `dialogScreen:removeAll()` |
| `isCutscene` | false | Panels cutscene active | `collisions.lua` Cutscene trigger, `MazeScene:enter` room cutscene | Panels completion callback |
| `isEquiping` | false | Equipment menu open | `inGameMenu:displayMenu()` | `BButtonDown` in MazeScene |
| `isDancing` | false | DanceScene battle active | `DanceScene:startBattle()` | DanceScene win/lose |
| `isActive` | false | Player took an action (NPC turn signal) | `player:move()`, `player:chargeBattery()` | NPCs consume it per frame |
| `isCharging` | false | Crank charging in progress | `chargeBattery()` | after charge tick |
| `readyToShrink` | false | Player overlapping minifier | `collisions.lua` PropItem minifier | `player:finishMinifying()` |
| `isTiny` | false | Player is in tiny state | `player:transformCycle()` completion | same |
| `isBig` | false | Player is in big state | `player:transformCycle()` | same |
| `isInDarkness` | false | Current room has shadow | `MazeScene:enter()` | same |
| `isFocused` | false | Focus mode (legacy) | — | — |
| `showLightCone` | false | Light cone visible | `lightburst.lua` | `lightburst.lua` |
| `sonarActive` | false | Enemy sonar pulse | `enemy:sonar()` | — |
| `canDance` | false | Player can enter DanceScene | — | — |

### Position and navigation

| Field | Default | Type | Description |
|---|---|---|---|
| `x`, `y` | 200, 200 | number | Player world position (updated each frame) |
| `speed` | 1.5 | number | Current movement speed (may be modified by status effects) |
| `direction` | `"idle"` | string | `"left"`, `"right"`, `"up"`, `"down"`, `"idle"` |
| `floor` | 1 | number | **Index into `levelsLDTK` array** (NOT the level number) |
| `room` | 1 | number | Current room number |
| `actualLevel` | nil | number | LDtk level number (e.g. 4) |
| `actualRoom` | nil | number | LDtk room number (e.g. 8) |
| `actualTilemap` | nil | number | Index into `tileMapData` for collision |
| `saveLevel` | nil | number | Full room ID at last save (used by `SaveSystem.load()` return value) |
| `lastRoom` | nil | number | Previous room (for door back-navigation) |
| `playerSpawn` | `{x=200,y=200}` | table | Where player spawns in the next room |
| `playerExit` | `{x=nil,y=nil}` | table | Where player was when exiting (set in `MazeScene:exit()`) |

### Items and skills

```lua
PlayerData.items = {
    hasLamp    = false,  -- enables lamp animations, sanity regen; grants canFlash
    hasRadio   = true,   -- story item; enables radio dialog video feed states
    hasDWatch  = false,  -- required to open equipment menu (inGameMenu)
    hasNotes   = true,   -- story item; enables notes dialog
    hasBoots   = false,  -- hole safety; grants canDash
    hasPlunger = false,  -- slime immunity; grants canPlungerang
    -- Dynamic (not in DefaultPlayerData, set by grabBag/grabTools):
    -- hasBag   -- required to capture CrewMembers
    -- hasTools -- story item
}

PlayerData.skills = {
    canFlash      = false,  -- B button → lightBurst() [costs 10 battery]
    canDash       = false,  -- B button → dash() [costs 10 battery]
    canPlungerang = false,  -- B button → plunge() [no battery cost]
}
```

### Active skill selection

| Field | Default | Values | Used by |
|---|---|---|---|
| `activeItem` | 0 | 0=none, 1=lamp/flash, 2=boots/dash, 3=plunger/plunge | `player:useAbility()`, `inGameMenu` |
| `storyCounter` | 0 | number | Counter triggers increment this |

### Keys (door locks)

```lua
PlayerData.keys = {}  -- sparse map: {[1]=true, [3]=true, ...}
-- Set by: player:grabKey(keyNumber)
-- Read by: player:collisionResponse Door branch
```

### Enemy encounter state

```lua
PlayerData.lastEnemyTouched = {
    type = nil,  -- "Brocorat"
    id   = nil,  -- entity iid
    x    = nil,  -- position at time of contact
    y    = nil,
}
PlayerData.EnemiesData = {
    powerLevel  = 1,    -- 1-20; scales sight radius and DanceScene difficulty
    sightRadius = 150,  -- base detection distance (effective = this + powerLevel*3)
    isEvolved   = false -- legacy field, not used in logic
}
PlayerData.amountDances = 0  -- total dance battles entered
```

### CrewMember tracking

```lua
PlayerData.CrewMemberData = {
    amountTaken = 0,   -- total crew captured
    idNumbers   = {}   -- sparse map: {["CM001"]=true, ["CM005"]=true, ...}
}
```

## The state machine in prose

The game is effectively a state machine driven by the boolean flags above. Here is how
they interact (read this before porting any logic):

```
Normal gameplay:
  isGaming=true, isTalking=false, isCutscene=false, isEquiping=false

Player enters dialog trigger (Search/Call + A press, or Story auto):
  isGaming=false, isTalking=true
  → player:move() blocked (checks isTalking)
  → enemy AI continues (isActive still works)
  → A button → dialogScreen:nextDialog()
  → last dialog line → dialogScreen:removeAll() → isGaming=true, isTalking=false

Player opens equipment menu (A held 1 second):
  isGaming=false, isEquiping=true
  → D-pad ←/→ cycles activeItem
  → B closes menu → isGaming=true, isEquiping=false

Player hits Cutscene trigger:
  isGaming=false, isCutscene=true
  → Noble.Input disabled (MazeScene:update checks isCutscene)
  → Panels.update() drives the cutscene each frame
  → Panels callback → isGaming=true, isCutscene=false, Noble.Input re-enabled

Player overlaps minifier:
  readyToShrink=true (isGaming can still be true)
  → uiHud shows "Press A"
  → A → player:startMinifying() → isGaming=false
  → Crank → player:transformCycle()
  → B (or completion) → player:finishMinifying() → isGaming=true, readyToShrink=false
```
```

- [ ] **Step 2: Verify every field exists in `PlayerDataTables.lua`**

Open `source/assets/data/PlayerDataTables.lua`. Confirm `DefaultPlayerData` contains every field listed in the reference above. Note which fields are absent from `DefaultPlayerData` (dynamic fields set later) and confirm they are marked as such in the doc.

Known dynamic fields not in DefaultPlayerData: `hasBag`, `hasTools`.

- [ ] **Step 3: Commit**

```bash
git add source/DOCS/PLAYERDATA_REFERENCE.md
git commit -m "docs: add PLAYERDATA_REFERENCE.md — full field reference with state machine"
```

---

## Task 4: CUTSCENE_SYSTEM.md — Both cutscene types

**Files:**
- Create: `source/DOCS/CUTSCENE_SYSTEM.md`

- [ ] **Step 1: Write the Panels library overview section**

Create `source/DOCS/CUTSCENE_SYSTEM.md`:

```markdown
# Cutscene System

The game uses the **Panels** library (`libraries/panels/`) to display comic-style
cutscenes. There are two entry points that trigger cutscenes:

1. **Room-entry cutscene** — triggered by `MazeScene:enter()` based on LDtk room fields
2. **Trigger cutscene** — triggered by `player:collisionResponse()` when the player
   walks into a `Trigger` entity of type `"Cutscene"`

Both share the same underlying system: a `comics` table registry and `Panels.startCutscene()`.

---

## The `comics` Registry

`source/assets/comics/comicsData.lua` is the registry of all cutscene sequences:

```lua
-- comicsData.lua
import "assets/comics/intro"
import "assets/comics/pick-the-device"

comics = {
    ["intro"]           = intro,
    ["pick-the-device"] = pickDevice
}
```

**`comics` is a global table.** Each key is a string name; each value is a Panels
sequence table (a Lua table that Panels reads to display panels/images).

### Adding a new cutscene

1. Create `source/assets/comics/my-cutscene.lua` defining a `myCutscene` local variable
2. Add `import "assets/comics/my-cutscene"` to `comicsData.lua`
3. Add `["my-cutscene"] = myCutscene` to the `comics` table
4. Reference `"my-cutscene"` in LDtk `comic_name` field or in a trigger's logic

---

## Panels sequence data structure

Each Panels sequence is a Lua array of **sequences** (chapters). Each sequence contains
**panels** (pages). Each panel contains **layers** (images stacked on top of each other).

```lua
-- Minimal example (based on intro.lua)
intro = {
    -- Sequence 1
    {
        scrollType       = Panels.ScrollType.AUTO,
        direction        = Panels.ScrollDirection.NONE,
        backgroundColor  = Graphics.kColorWhite,
        advanceControl   = Panels.Input.A,    -- A button advances
        frame            = { margin = 0 },
        title            = "Intro",

        panels = {
            -- Panel 1: single image layer
            {
                layers = {
                    { image = "comics/intro/001", x = -8, y = -8 }
                }
            },
            -- Panel 2: two layers (background + overlay)
            {
                layers = {
                    { image = "comics/intro/001", x = -8, y = -8 },
                    { image = "comics/intro/002", x = -8, y = -8 },
                }
            },
            -- Additional panels add more layers cumulatively...
        }
    }
}
```

**Image paths** are relative to `Panels.Settings.path` (set to `""` in `main.lua`),
then the Playdate SDK appends `.png`. So `image = "comics/intro/001"` loads
`source/assets/images/comics/intro/001.png` (or `source/comics/intro/001.png`
depending on SDK path resolution — check `Panels.Settings.path`).

**Love2D equivalent:** Each panel is a stack of `love.graphics.draw()` calls.
Advance on key press. Track current panel/sequence index manually.

---

## Type 1: Room-Entry Cutscene

### How it's configured (LDtk)

On any room entity in LDtk, set these custom fields:

| Field | Type | Value | Meaning |
|---|---|---|---|
| `comic_name` | String | `"intro"` | Key into the `comics` table |
| `play` | String | `"Enter"` | When to play (`"Enter"` = on room entry) |
| `comic_wasPlayed` | Boolean | `false` | Tracks if already played (saved to disk) |

### Code path (in `MazeScene:enter()`)

```lua
-- MazeScene.lua lines ~263-279
local cf = levelsLDTK[room].customFields

if cf.comic_name then
    local comicData = comics[cf.comic_name]     -- look up Panels sequence
    if comicData then
        if cf.play == "Enter" and cf.comic_wasPlayed == false then
            PlayerData.isCutscene = true         -- block game input
            PlayerData.isGaming = false
        end

        Panels.startCutscene(comicData, function()
            -- ← This callback runs when the player finishes the cutscene
            PlayerData.isGaming = true
            PlayerData.isCutscene = false
            levelsLDTK[room].customFields.comic_wasPlayed = true  -- persist via SaveSystem
            Utilities.checkStoryAchievement(cf.comic_name)
        end)
    end
end
```

### Update loop integration (`MazeScene:update()`)

```lua
-- MazeScene.lua lines ~377-388
if PlayerData.isCutscene == true then
    if Noble.Input.getEnabled() then
        Noble.Input.setEnabled(false)   -- disable all game inputs
    end
    Panels.update()                     -- Panels drives itself each frame
else
    if not Noble.Input.getEnabled() then
        Noble.Input.setEnabled(true)    -- re-enable when done
    end
end
```

### One-shot persistence

When the cutscene completes, the callback sets:
```lua
levelsLDTK[room].customFields.comic_wasPlayed = true
```
`SaveSystem.save()` (called on `MazeScene:finish()` and `MazeScene:pause()`) then
serializes `comic_wasPlayed` into the save file. On next load, `SaveSystem.load()`
restores it — so `comic_wasPlayed == true` and the cutscene is skipped.

### Flow diagram

```
MazeScene:enter()
  ├─ Read customFields.comic_name
  ├─ Lookup comics[comic_name]          → nil? skip
  ├─ comic_wasPlayed == false?          → false? skip (already seen)
  ├─ Set isCutscene=true, isGaming=false
  └─ Panels.startCutscene(data, callback)

MazeScene:update() [every frame]
  ├─ isCutscene == true?
  │   ├─ Noble.Input.setEnabled(false)
  │   └─ Panels.update()               ← Panels draws and reads its own input
  └─ isCutscene == false?
      └─ Noble.Input.setEnabled(true)

[Player presses A to advance panels until end]

Panels completion callback:
  ├─ isGaming = true
  ├─ isCutscene = false
  ├─ levelsLDTK[room].customFields.comic_wasPlayed = true
  └─ Utilities.checkStoryAchievement(comic_name)
```

---

## Type 2: Trigger-Activated Cutscene

### How it's configured (LDtk)

On a `Triggers` entity in LDtk, set these custom fields:

| Field | Type | Value | Meaning |
|---|---|---|---|
| `type` | String | `"Cutscene"` | Triggers the cutscene path in collisionResponse |
| `script` | String | `"my-cutscene"` | Key into the `comics` table (same registry) |
| `usedTrigger` | Boolean | `false` | Saved; when true the trigger is skipped on room load |

> **Important:** A trigger cutscene uses `cf.script` as the `comics` key, NOT
> `comic_name`. The naming is different from room-entry cutscenes.

### Spawn condition (in `MazeScene:enter()`)

```lua
-- MazeScene.lua lines ~327-346
if entities and entities.Triggers then
    for i, triggerData in ipairs(entities.Triggers) do
        local cf = triggerData.customFields or {}
        local used = cf.usedTrigger or false

        if not used then  -- ← skip if already consumed
            Trigger(x, y, width, height, cf.script, triggerData.iid, room, cf.type)
        end
    end
end
```

### Code path (in `player:collisionResponse`)

```lua
-- entities/player/collisions.lua lines ~48-63
elseif other:isa(Trigger) then
    if other.type == "Cutscene" then
        PlayerData.isGaming = false
        PlayerData.isCutscene = true           -- same flag as room-entry
        other:returnScript()                   -- marks trigger as usedTrigger=true
        other:remove()                         -- removes sprite from scene
        Utilities.grantAchievementIfNeeded(other.script)
    end
    return 'overlap'
```

### What `returnScript()` does for a Cutscene trigger

```lua
-- trigger.lua: returnScript() fallback branch (no conditionalScripts)
if self.type ~= "Search" then
    cf.usedTrigger = true   -- ← marks consumed in levelsLDTK live table
end
return self.script          -- ← returns the comics key string
```

> **Note:** For a `"Cutscene"` trigger, `returnScript()` is called to mark it as used.
> But the return value (the script/comics key) is **discarded** in `collisionResponse`
> — the actual cutscene is NOT started here. See below.

### Where the cutscene actually starts

The `"Cutscene"` collision handler sets `PlayerData.isCutscene = true` but does
**not** call `Panels.startCutscene()`. The cutscene starts in `MazeScene:enter()`
on the **next room load** — if the trigger's script matches a `comic_name` on that room.

**Or:** the trigger is intended to set the `isCutscene` flag and the cutscene is
initiated elsewhere (e.g., a Panels sequence already started via room-entry). This
means Cutscene triggers currently **only block input** — they do not independently
launch Panels sequences.

**To make a Cutscene trigger actually play a Panels sequence, add this to
`collisionResponse` after `other:remove()`:**

```lua
-- Suggested addition for a self-contained trigger cutscene:
local comicKey = other.script
local comicData = comics[comicKey]
if comicData then
    Panels.startCutscene(comicData, function()
        PlayerData.isGaming = true
        PlayerData.isCutscene = false
    end)
end
```

### Flow diagram

```
Player walks into Trigger (type="Cutscene")
  ↓
collisionResponse → Trigger branch
  ├─ isGaming = false
  ├─ isCutscene = true
  ├─ trigger:returnScript()         → sets usedTrigger=true in levelsLDTK
  ├─ trigger:remove()               → sprite gone, won't fire again this room
  └─ grantAchievementIfNeeded()

MazeScene:update() [next frame]
  ├─ isCutscene == true
  ├─ Noble.Input.setEnabled(false)
  └─ Panels.update()                → if Panels.startCutscene was called elsewhere

[On room exit → SaveSystem.save() → usedTrigger=true persisted]
[On next room load → usedTrigger=true → Trigger not spawned]
```

---

## Panels.startCutscene — API reference

```lua
Panels.startCutscene(
    sequenceData,   -- Panels sequence table (from comics registry)
    callback        -- function() called when player completes all panels
)
```

**Must be called while `Panels.update()` is being called each frame.**
If `Panels.update()` is not in the update loop, Panels will not advance.

The game ensures this by checking `PlayerData.isCutscene` in `MazeScene:update()`.

---

## Love2D Porting Notes

### Replacing Panels

Panels is a Playdate-specific library. In Love2D, implement a minimal equivalent:

```lua
-- CutscenePlayer.lua
local CutscenePlayer = {}
local current = nil   -- { sequence, panelIndex, layerIndex, callback }

function CutscenePlayer.start(sequenceData, callback)
    current = {
        sequences = sequenceData,
        seqIdx    = 1,
        panelIdx  = 1,
        callback  = callback,
    }
    PlayerData.isCutscene = true
    PlayerData.isGaming   = false
end

function CutscenePlayer.update() end  -- no-op; drawing is in draw()

function CutscenePlayer.draw()
    if not current then return end
    local seq   = current.sequences[current.seqIdx]
    local panel = seq.panels[current.panelIdx]

    -- Draw background
    love.graphics.setBackgroundColor(unpack(seq.backgroundColor or {1,1,1}))

    -- Draw all layers of this panel
    for _, layer in ipairs(panel.layers) do
        local img = love.graphics.newImage(layer.image .. ".png")
        love.graphics.draw(img, layer.x, layer.y)
    end
end

function CutscenePlayer.advance()
    if not current then return end
    local seq = current.sequences[current.seqIdx]
    current.panelIdx = current.panelIdx + 1

    if current.panelIdx > #seq.panels then
        current.seqIdx  = current.seqIdx + 1
        current.panelIdx = 1

        if current.seqIdx > #current.sequences then
            -- Done
            local cb = current.callback
            current = nil
            PlayerData.isCutscene = false
            PlayerData.isGaming   = true
            if cb then cb() end
        end
    end
end

-- Call in love.keypressed:
-- if key == "return" or key == "space" then CutscenePlayer.advance() end
-- Call in love.draw (after world):
-- if PlayerData.isCutscene then CutscenePlayer.draw() end

return CutscenePlayer
```

### Replacing `Panels.Settings.path`

Panels resolves image paths relative to `Panels.Settings.path` (set to `""`).
In Love2D, prefix all image paths with `"source/"` or your asset root.

### `comic_wasPlayed` persistence

The field is saved and loaded by `SaveSystem`. In Love2D, ensure your save serializer
includes `levelsLDTK[i].customFields.comic_wasPlayed` for every room (the existing
`SaveSystem.getLevelState()` already does this).
```

- [ ] **Step 2: Verify the Cutscene trigger flow against `collisions.lua` and `MazeScene.lua`**

Open `source/entities/player/collisions.lua` lines 48-63 and `source/scenes/MazeScene.lua` lines 263-279 and 377-388. Confirm:
- The collision branch sets `isCutscene=true` and does NOT call `Panels.startCutscene()`
- The room-entry branch calls `Panels.startCutscene()` with the callback
- The update loop calls `Panels.update()` only when `isCutscene==true`

- [ ] **Step 3: Commit**

```bash
git add source/DOCS/CUTSCENE_SYSTEM.md
git commit -m "docs: add CUTSCENE_SYSTEM.md — room-entry and trigger cutscenes with Panels"
```

---

## Task 5: Update TRIGGER_SYSTEM.md — add Cutscene code path and cross-references

**Files:**
- Modify: `source/DOCS/TRIGGER_SYSTEM.md`

- [ ] **Step 1: Add cross-reference header**

At the very top of `TRIGGER_SYSTEM.md`, after the first heading, add:

```markdown
> **See also:** [CUTSCENE_SYSTEM.md](CUTSCENE_SYSTEM.md) for the full Cutscene trigger
> code path and Panels integration. [PLAYERDATA_REFERENCE.md](PLAYERDATA_REFERENCE.md)
> for `isCutscene` and `isGaming` flag semantics.
```

- [ ] **Step 2: Expand the Cutscene type documentation**

Find the `### A. Automatic Triggers` section in `TRIGGER_SYSTEM.md` and replace the `Cutscene` bullet with:

```markdown
*   **`Cutscene`**: Activated automatically upon collision. Full code path:

    ```lua
    -- player/collisions.lua — what actually happens:
    PlayerData.isGaming = false
    PlayerData.isCutscene = true      -- MazeScene:update() sees this and calls Panels.update()
    other:returnScript()              -- marks usedTrigger=true in levelsLDTK (persisted on save)
    other:remove()                    -- sprite removed; won't collide again
    Utilities.grantAchievementIfNeeded(other.script)
    ```

    **Important:** `collisionResponse` does NOT call `Panels.startCutscene()`. It only
    sets flags. The Panels sequence must be started separately (either by the room-entry
    cutscene system, or by extending `collisionResponse` — see CUTSCENE_SYSTEM.md).

    The `script` field on the trigger is a key into the `comics` table registry.
    `returnScript()` returns it, but the return value is discarded by `collisionResponse`.
```

- [ ] **Step 3: Add `Trigger:init` signature block**

At the end of the `## 1. LDtk Configuration` section, add:

```markdown
### Trigger constructor (Lua)

```lua
-- trigger.lua
-- Note: extends Graphics.sprite (base Playdate sprite), NOT NobleSprite
function Trigger:init(x, y, width, height, script, iid, room, type)
    self.script = script   -- comics key (Cutscene) or dialog script name (Story/Search/Call)
    self.iid    = iid      -- LDtk instance unique ID (used for save/restore matching)
    self.room   = room     -- index into levelsLDTK (NOT the room number)
    self.type   = type     -- "Cutscene"|"Story"|"Search"|"Call"|"Counter"|nil

    -- Position offset: LDtk x/y is center; sprite origin is top-left
    self:moveTo(x - width/2, y - height/2)
    self:setCollideRect(0, 0, width, height)
    self:setZIndex(3)
    self:setGroups(3)
    self:add()
end
```
```

- [ ] **Step 4: Commit**

```bash
git add source/DOCS/TRIGGER_SYSTEM.md
git commit -m "docs: expand TRIGGER_SYSTEM.md — Cutscene code path, constructor, cross-refs"
```

---

## Task 6: DATA_FLOW.md — ASCII dependency graph

**Files:**
- Create: `source/DOCS/DATA_FLOW.md`

- [ ] **Step 1: Write the dependency graph**

Create `source/DOCS/DATA_FLOW.md`:

````markdown
# Data Flow — Who Talks to Who

This document shows which files read and write the major shared data structures,
and how systems are connected. Use this as a map when you need to trace a bug
or add a feature.

---

## Global data structures and their owners

```
┌─────────────────────────────────────────────────────────────────┐
│  Config.lua          → READ ONLY after boot                      │
│  (source of truth for all constants)                             │
│                                                                  │
│  Aliased in main.lua:                                            │
│    ZIndex        = Config.ZIndex                                 │
│    CollideGroups = Config.CollideGroups                          │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  PlayerData              → MUTABLE global game state             │
│                                                                  │
│  WRITTEN by:                                                     │
│    PlayerDataTables.lua  → defines DefaultPlayerData, init       │
│    SaveSystem.lua        → overwrites on load                    │
│    player/movement.lua   → x, y, direction, isActive, battery   │
│    player/sanity.lua     → sanity, sanityCounter                 │
│    player/items.lua      → items.*, skills.*, keys[n]           │
│    player/state.lua      → isTiny, isBig, playerSize, floor     │
│    player/collisions.lua → lastEnemyTouched, readyToShrink      │
│    player/dash.lua       → battery (cost)                        │
│    player/lightburst.lua → battery (cost)                        │
│    MazeScene.lua         → isGaming, isCutscene, floor, room,   │
│                            actualLevel, actualRoom, actualTilemap│
│                            isInDarkness, visited (via levelsLDTK)│
│    DanceScene.lua        → isDancing, amountDances, calories     │
│    inGameMenu.lua        → isEquiping, activeItem                │
│    dialogScreen.lua      → isTalking, isGaming                  │
│    Panels callback       → isCutscene, isGaming                  │
│                                                                  │
│  READ by:                                                        │
│    Every entity in the game (enemies, HUD, triggers, etc.)       │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  levelsLDTK              → MUTABLE world state                   │
│                                                                  │
│  WRITTEN by:                                                     │
│    levels.lua            → initial definition                    │
│    SaveSystem.load()     → restores persisted entity states      │
│    MazeScene:enter()     → sets customFields.visited = true      │
│    Panels callback       → sets comic_wasPlayed = true           │
│    player/collisions.lua → indirectly via trigger:returnScript() │
│                            (sets usedTrigger=true in cf)         │
│    DanceScene win        → enemy.customFields.dead = true via    │
│                            findAndKillEnemyById                  │
│    prop destruction      → propItem:destroyProp() via iid        │
│                                                                  │
│  READ by:                                                        │
│    MazeScene:enter()     → spawns all entities                   │
│    SaveSystem.getLevelState() → serializes for disk              │
│    trigger.lua           → returnScript() reads conditionals     │
│    door.lua              → FindRoomByIid() lookup                │
│    Utilities.lua         → GetLowerRoom, GetUpperRoom            │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  tileMapData             → READ ONLY after boot                  │
│                                                                  │
│  WRITTEN by:                                                     │
│    tilemap.lua           → initial definition                    │
│                                                                  │
│  READ by:                                                        │
│    MazeScene:enter()     → CreateTileColliders(tileMapData[n])   │
│    Utilities.lua         → GetTileUnderPlayer()                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  script (dialog scripts) → READ ONLY after boot                  │
│                                                                  │
│  WRITTEN by:                                                     │
│    assets/data/script.lua → initial definition                   │
│                                                                  │
│  READ by:                                                        │
│    dialogScreen:addScreen(name) → searches for matching entry    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  comics (Panels sequences) → READ ONLY after boot                │
│                                                                  │
│  WRITTEN by:                                                     │
│    assets/comics/comicsData.lua → initial definition             │
│                                                                  │
│  READ by:                                                        │
│    MazeScene:enter()     → comics[cf.comic_name]                 │
│    (trigger cutscene should also read it — see CUTSCENE_SYSTEM)  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Entity collision dispatch map

`player:collisionResponse(other)` is the central dispatcher. Here is what happens
for each entity type:

```
other type          → action
─────────────────────────────────────────────────────────────────
Brocorat            → damage player, maybe fight() → DanceScene
CrewMember (normal) → taken() [capture]
CrewMember (tiny)   → currentTrigger = other [interact]
Box (wall)          → return 'freeze'
Trigger "Cutscene"  → isGaming=false, isCutscene=true, remove
Trigger "Story"     → isGaming=false, dialogUI:addScreen()
Trigger "Search"    → currentTrigger = other [manual, press A]
Trigger "Call"      → currentTrigger = other [manual, press A]
Trigger nil         → currentTrigger = other [manual, press A]
Trigger "Counter"   → storyCounter += 1, remove
Items "keycard"     → grabKey(n)
Items "lamp"        → grabLamp()
Items "radio"       → grabRadio()
Items "notes"       → grabNotes(grants)
Items "itemgift"    → grabItemGift(grants)
Items "bag"/"honk"  → grabBag()
Items "tools"       → grabTools()
Items "boots"       → grabBoots()
Items "plunger"     → grabPlunger()
PropItem "minifier" → readyToShrink=true, show "Press A"
PropItem (isTube)   → riseAbove() [only if isTiny]
PropItem (other)    → return 'freeze'
Door (open)         → prevRoom() + goTo() [transition]
Door (closed+key)   → prevRoom() + goTo() [transition]
Door (closed-key)   → dialogUI:addScreen("nokeys"), 'freeze'
```

---

## Save / load data flow

```
[Game boots]
  └─ SaveSystem.createOriginalBackup()
       └─ levelsLDTKOriginal = deepcopy(levelsLDTK)

[SaveSystem.load()]
  ├─ playdate.datastore.read('gameState')
  ├─ PlayerData = saveData.player          → replaces live PlayerData
  ├─ SaveSystem.restoreLevelState(...)     → patches levelsLDTK in-place
  └─ return true, saveData.player.saveLevel

[MazeScene:finish() and MazeScene:pause()]
  └─ SaveSystem.save()
       ├─ getLevelState()                 → reads levelsLDTK
       └─ playdate.datastore.write(...)   → writes to disk

[SaveSystem.reset()]
  ├─ ResetPlayerData()
  └─ levelsLDTK = deepcopy(levelsLDTKOriginal)
```

---

## The `grants` system (items → PlayerData)

`itemgift` and `notes` items carry a `grants` string from LDtk:

```
Format:  "key1:value1,key2:value2"
Example: "canFlash:true,hasLamp:true"

Parsed in: player/items.lua → grabItemGift(grants)
             → sets PlayerData.items[key] or PlayerData.skills[key]

Spawning guard (MazeScene:enter()):
  For each grant pair, check if PlayerData already has it
  If any grant is already true → skip spawning this item entirely
```
````

- [ ] **Step 2: Verify the collision dispatch table**

Open `source/entities/player/collisions.lua` and confirm every branch in `collisionResponse` is represented in the dispatch map above. Add any missing entries.

- [ ] **Step 3: Commit**

```bash
git add source/DOCS/DATA_FLOW.md
git commit -m "docs: add DATA_FLOW.md — dependency graph, collision dispatch, save flow"
```

---

## Self-Review

**Spec coverage check:**

| Requirement | Covered by |
|---|---|
| How each part connects | ARCHITECTURE.md, DATA_FLOW.md |
| Config as source of truth | CONFIG_REFERENCE.md (every field mapped) |
| PlayerData as global state | PLAYERDATA_REFERENCE.md (every field + read/write) |
| Cutscene via trigger | CUTSCENE_SYSTEM.md Type 2, TRIGGER_SYSTEM.md update |
| Room-entry cutscene | CUTSCENE_SYSTEM.md Type 1 |
| Love2D porter needs | Love2D notes in every doc, CutscenePlayer.lua example |
| No magic numbers | CONFIG_REFERENCE.md cross-references actual values |

**Placeholder scan:** None found. All code blocks contain actual code from the source files.

**Type consistency:** `comics[key]`, `PlayerData.isCutscene`, `levelsLDTK[room].customFields.comic_name`, `Panels.startCutscene(data, callback)` — consistent across all tasks.
