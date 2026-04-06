# PlayerData — Complete Reference

`PlayerData` is the **global mutable game state**. It is a Lua table accessible from
every file without `require` or `import`. It is the backbone of all game logic.

See [DATA_FLOW.md](DATA_FLOW.md) for which systems read and write it.

---

## Lifecycle

```lua
-- PlayerDataTables.lua
local DefaultPlayerData = { ... }        -- immutable template
PlayerData = deepcopy(DefaultPlayerData) -- live mutable copy (set at module load time)

-- SaveSystem.load()
PlayerData = saveData.player             -- replaces entirely from disk on continue

-- ResetPlayerData()
PlayerData = deepcopy(DefaultPlayerData) -- resets to defaults (no disk read)
```

`SaveSystem.createOriginalBackup()` (called in `main.lua` after all imports) deep-copies
`levelsLDTK` — it does NOT back up `PlayerData`. `PlayerData` defaults come from
`DefaultPlayerData`.

---

## Field Reference

### Survival resources

| Field | Default | Type | Read by | Written by |
|---|---|---|---|---|
| `healthPoints` | 3 | number | `collisions.lua` (fight threshold), `HealthIndicator` | `collisions.lua` (damage), `DanceScene` (win heal) |
| `danceThresholdHP` | 1 | number | `collisions.lua` — fights at this HP enter DanceScene | — (constant) |
| `healedHP` | 2 | number | `DanceScene` win — how much HP is restored | — (constant) |
| `battery` | 100 | number | `battery.lua`, `movement.lua`, `sanity.lua`, `MazeScene.update` | `movement.lua` (drain), `MazeScene.cranked` (charge) |
| `sanity` | 100 | number | `sanityHud`, `sanity.lua` | `sanity.lua` tick |
| `sanityCounter` | 0 | number | `DanceScene.determineDifficultyUpgrade` | `sanity.lua` (increments when sanity hits 0) |
| `calories` | 100 | number | `DanceScene.determineDifficultyUpgrade` | `pedometer()`, `burnCalories()`, DanceScene win |
| `steps` | 0 | number | `pedometer()` | `pedometer()` |
| `totalSteps` | 1000 | number | — (lifetime counter) | `pedometer()` |
| `mapPercent` | 0 | number | Trigger conditionalScripts conditions | — |

---

### Boolean game state flags

These flags form the core state machine. **Check them before any gameplay logic.**
The flags are mutually exclusive in practice — only one "mode" is active at a time.

| Field | Default | Meaning | Set `true` by | Set `false` by |
|---|---|---|---|---|
| `isGaming` | false | Normal gameplay active | `MazeScene:start()` | `MazeScene:finish()`, dialog open, menu open, cutscene start |
| `isTalking` | false | Dialog overlay open | `dialogScreen:addScreen()` | `dialogScreen:removeAll()` |
| `isCutscene` | false | Panels cutscene active | `collisions.lua` Cutscene trigger, `MazeScene:enter` room cutscene | Panels completion callback |
| `isEquiping` | false | Equipment menu open | `inGameMenu:displayMenu()` | B button in MazeScene input handler |
| `isDancing` | false | DanceScene battle active | `DanceScene:startBattle()` | DanceScene win/lose |
| `isActive` | false | Player took an action (NPC turn signal) | `player:move()`, `player:chargeBattery()` | NPCs consume it each frame |
| `isCharging` | false | Crank charging in progress | `chargeBattery()` | after charge tick completes |
| `readyToShrink` | false | Player overlapping minifier prop | `collisions.lua` PropItem "minifier" branch | `player:finishMinifying()` |
| `isTiny` | false | Player is in tiny state | `player:transformCycle()` completion | same (toggle) |
| `isBig` | false | Player is in big state | `player:transformCycle()` | same (toggle) |
| `isInDarkness` | false | Current room has shadow/darkness | `MazeScene:enter()` from `customFields.shadow` | next `MazeScene:enter()` |
| `isFocused` | false | Focus mode (legacy, unused) | — | — |
| `showLightCone` | false | Light cone polygon visible | `lightburst.lua` | `lightburst.lua` timer |
| `sonarActive` | false | Enemy sonar pulse triggered | `enemy:sonar()` | — |
| `canDance` | false | Player can enter DanceScene | — | — |

---

### Position and navigation

| Field | Default | Type | Description |
|---|---|---|---|
| `x`, `y` | 200, 200 | number | Player world position (updated each frame in `movement.lua`) |
| `speed` | 1.5 | number | Current movement speed in px/frame (may be modified by status effects) |
| `direction` | `"idle"` | string | `"left"`, `"right"`, `"up"`, `"down"`, `"idle"` |
| `floor` | 1 | number | **Index into `levelsLDTK` array** (NOT the level number) |
| `room` | 1 | number | Current room number (`customFields.roomNumber`) |
| `actualLevel` | nil | number | LDtk level number (e.g. 4) |
| `actualRoom` | nil | number | LDtk room number (e.g. 8) |
| `actualTilemap` | nil | number | Index into `tileMapData` array for wall collision |
| `saveLevel` | nil | number | Full room ID at last save (used by `SaveSystem.load()` second return value) |
| `lastRoom` | nil | number | Previous room (for back-navigation via doors) |
| `playerSpawn` | `{x=200,y=200}` | table | Where player spawns when entering the next room |
| `playerExit` | `{x=nil,y=nil}` | table | Position when exiting current room (set in `MazeScene:exit()`) |

---

### Items and skills

```lua
PlayerData.items = {
    hasLamp    = false,  -- enables lamp animations, sanity regen; grants canFlash
    hasRadio   = true,   -- story item; enables radio dialog video feed states
    hasDWatch  = false,  -- required to open equipment menu (inGameMenu)
    hasNotes   = true,   -- story item; enables notes dialog
    hasBoots   = false,  -- hole safety; grants canDash
    hasPlunger = false,  -- slime immunity; grants canPlungerang
    -- Dynamic (NOT in DefaultPlayerData — set by grabBag()/grabTools()):
    -- hasBag   -- required to capture CrewMembers
    -- hasTools -- story item
}

PlayerData.skills = {
    canFlash      = false,  -- B button → lightBurst() [costs 10 battery; directional cone]
    canDash       = false,  -- B button → dash() [costs 10 battery]
    canPlungerang = false,  -- B button → plunge() [no battery cost]
}
```

**Skill granting:** Skills are granted via the `grants` field on `itemgift`/`notes` items in LDtk.
Format: `"canFlash:true,hasLamp:true"`. Parsed by `grabItemGift()` in `player/items.lua`.

**Equipment menu:** `inGameMenu` cycles through `skills` (not `items`) to build the equipment list.
See [INGAME_MENU.md](INGAME_MENU.md).

---

### Active skill selection

| Field | Default | Values | Used by |
|---|---|---|---|
| `activeItem` | 0 | 0=none, 1=lamp/flash, 2=boots/dash, 3=plunger/plunge | `player:useAbility()`, `inGameMenu` |
| `storyCounter` | 0 | number | Counter triggers increment this |

---

### Keys (door locks)

```lua
PlayerData.keys = {}  -- sparse map: {[1]=true, [3]=true, ...}
-- Set by: player:grabKey(keyNumber)
-- Read by: player:collisionResponse Door branch
```

---

### Enemy encounter state

```lua
PlayerData.lastEnemyTouched = {
    type = nil,  -- "Brocorat" (enemy class name)
    id   = nil,  -- entity iid (LDtk instance ID)
    x    = nil,  -- position at time of contact
    y    = nil,
}
PlayerData.EnemiesData = {
    powerLevel  = 1,     -- 1-20; scales sight radius and DanceScene difficulty
    sightRadius = 150,   -- base detection distance (effective = sightRadius + powerLevel*3)
    isEvolved   = false  -- legacy field, not used in logic
}
PlayerData.amountDances = 0  -- total dance battles entered (lifetime)
```

See [ENEMIES_AND_COMBAT.md](ENEMIES_AND_COMBAT.md) for how `powerLevel` scales.

---

### CrewMember tracking

```lua
PlayerData.CrewMemberData = {
    amountTaken = 0,   -- total crew members captured
    idNumbers   = {}   -- sparse map: {["CM001"]=true, ["CM005"]=true, ...}
}
```

---

## The state machine in prose

The game is effectively a state machine driven by the boolean flags above. Here is how
they interact:

```
Normal gameplay:
  isGaming=true, isTalking=false, isCutscene=false, isEquiping=false

Player enters dialog trigger (Story auto, or Search/Call + A press):
  isGaming=false, isTalking=true
  → player:move() blocked (checks isTalking)
  → enemy AI continues (isActive still propagates)
  → A button → dialogScreen:nextDialog()
  → last dialog line → dialogScreen:removeAll() → isGaming=true, isTalking=false

Player opens equipment menu (A held 1 second, requires hasDWatch):
  isGaming=false, isEquiping=true
  → D-pad ←/→ cycles activeItem through available skills
  → B button closes menu → isGaming=true, isEquiping=false

Player hits Cutscene trigger:
  isGaming=false, isCutscene=true
  → Noble.Input disabled (MazeScene:update checks isCutscene)
  → Panels.update() drives the cutscene each frame
  → Panels callback → isGaming=true, isCutscene=false, Noble.Input re-enabled
  (See CUTSCENE_SYSTEM.md for full details)

Player overlaps minifier prop:
  readyToShrink=true (isGaming can still be true at this point)
  → playerHud shows "Press A" prompt
  → A pressed → player:startMinifying() → isGaming=false
  → Crank → player:transformCycle()
  → B pressed (or transformation complete) → player:finishMinifying() → isGaming=true, readyToShrink=false

Player touches enemy (fight):
  isGaming=false, isDancing=true
  → Noble.transition(DanceScene)
  → DanceScene win/lose → Noble.transition back → isGaming=true, isDancing=false
```

---

## Love2D porting notes

- `PlayerData` is a plain Lua table — no changes needed to the data structure itself.
- The boolean flag state machine is the core of input routing. In Love2D, check these
  flags in `love.keypressed` and `love.update` before dispatching any action:
  ```lua
  if PlayerData.isGaming and not PlayerData.isTalking then
      -- process movement
  end
  ```
- `isActive` drives the turn-based sync system. In Love2D, NPCs should check
  `PlayerData.isActive` each frame and consume it when they process a move.
  See [INPUT_SYSTEM.md](INPUT_SYSTEM.md) for the full input routing table.
