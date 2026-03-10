# Player Spawn Documentation

This document explains the complete flow that determines where the player appears when entering a room — both when transitioning through a door and when reloading a saved game.

---

## 🎯 Single Source of Truth: `PlayerData.playerSpawn`

The player always spawns at the coordinates stored in `PlayerData.playerSpawn`:

```lua
-- In MazeScene:enter() (scenes/MazeScene.lua ~line 257)
spawnPoint = PlayerData.playerSpawn
player = Player(spawnPoint.x, spawnPoint.y, PlayerData.speed, ZIndex.player)
```

`playerSpawn` is a simple `{x, y}` table. **Every spawn path writes to this table before triggering a scene transition.** The scene that loads simply reads it back — there is no per-case branch in `MazeScene:enter()`.

---

## 🚪 Case 1: Exiting Through a Door

When the player steps into a door collider, `collisions.lua` calls `door:goTo()`, which fires `Noble.transition(self.nextRoom, ...)`. But **before** that transition is called, the player's position in the *destination* room is written by `Door:prevRoom()`.

### `Door:prevRoom(direction, playerX, playerY)`

Source: `entities/props/door.lua`

```lua
function Door:prevRoom(direction, playerX, playerY)
    PlayerData.lastRoom = direction
    local spawnCoordinates = {
        top   = {x = playerX or 196, y = 196},
        down  = {x = playerX or 196, y = 32},
        right = {x = 32,             y = playerY or 116},
        left  = {x = 364,            y = playerY or 116}
    }
    PlayerData.playerSpawn.x = spawnCoordinates[direction].x
    PlayerData.playerSpawn.y = spawnCoordinates[direction].y
end
```

### Spawn positions per direction

| Door direction used (in *destination* room) | Spawn X | Spawn Y | Notes |
|---|---|---|---|
| `top` | `playerX` (caller's X) | `196` | Near bottom of screen; preserves horizontal position |
| `down` | `playerX` (caller's X) | `32` | Near top of screen; preserves horizontal position |
| `right` | `32` | `playerY` (caller's Y) | Near left edge; preserves vertical position |
| `left` | `364` | `playerY` (caller's Y) | Near right edge; preserves vertical position |

**Direction semantics**: `direction` here is the exit direction of the *destination* room (i.e., the door the player just came through, from the perspective of the new room). Entering a room from the top means the player arrived via the top door and should appear near the bottom.

The `playerX` / `playerY` fallback values (`196`, `116`) are screen center estimates — they are only used if the caller does not pass coordinates.

`PlayerData.lastRoom` is also set here so the game knows which direction the player entered from.

---

## 🕳️ Case 2: Falling Through a Hole / Rising Through a Ladder

Source: `entities/player/state.lua`

```lua
function Player:fallBelow()
    -- ...
    PlayerData.playerSpawn.x = self.x
    PlayerData.playerSpawn.y = self.y
    Noble.transition(nextScene, 1.5, Noble.Transition.Imagetable, { ... })
end

function Player:riseAbove()
    -- ...
    PlayerData.playerSpawn.x = self.x
    PlayerData.playerSpawn.y = self.y
    Noble.transition(nextScene, 1.5, Noble.Transition.Default)
end
```

Both functions **preserve the exact player position** (X and Y). The player reappears in the same horizontal/vertical position in the room above or below. There is no screen-edge adjustment.

- `fallBelow()` uses a falling imagetable transition; failure (no lower room) → `DeadScene`.
- `riseAbove()` uses the default transition; failure (no upper room) → no transition (silent).

---

## 💾 Case 3: Loading a Save Game

Source: `utilities/SaveSystem.lua`

```lua
function SaveSystem.load()
    local data = playdate.datastore.read('gameState')
    if data then
        PlayerData = table.deepcopy(data.playerData)
        levelsLDTK = table.deepcopy(data.levelsLDTK)
        -- ...
    end
end
```

`PlayerData` is fully restored from the datastore, including `PlayerData.playerSpawn`. When `MazeScene:enter()` runs, it reads the same `playerSpawn` values that were saved, so the player appears at exactly the position they occupied when the game was saved.

Save is triggered in:
- `MazeScene:finish()` — on normal room exit.
- `MazeScene:pause()` — when the game is paused (system menu).
- `DanceScene:exit()` — after winning the dance battle.

The default value for `playerSpawn` in `PlayerDataTables.lua` is used only for a **New Game** start.

---

## 🔄 Case 4: Returning From DanceScene (Win)

When the player survives a dance battle, `DanceScene` transitions back to the room stored in `PlayerData.floor`. The return spawn position comes from `PlayerData.playerExit`, which `MazeScene:exit()` captures just before leaving:

```lua
-- MazeScene:exit()
PlayerData.playerExit.x = player.x
PlayerData.playerExit.y = player.y
```

`DanceScene:finish()` then writes `playerExit` back into `playerSpawn` before transitioning:

```lua
PlayerData.playerSpawn.x = PlayerData.playerExit.x
PlayerData.playerSpawn.y = PlayerData.playerExit.y
```

This returns the player to the exact tile they were standing on when `Player:fight()` was called.

> [!NOTE]
> `playerExit` is also used as the fallback for any scene that needs to know where the player "came from" in the current room.

---

## ⏱️ `isGaming` Gate

The player sprite is created in `MazeScene:enter()`, but **input and gameplay are locked** until `MazeScene:start()` runs (after the Noble Engine transition completes):

```lua
-- MazeScene:start()
PlayerData.isGaming = true
```

During the transition animation, `isGaming = false`, so the player sprite exists at the spawn coordinates but cannot move.

---

## 📊 Flow Summary

```
Player touches door
    └─ collisions.lua → door:goTo() called
         ├─ Door:prevRoom(direction, x, y) → writes PlayerData.playerSpawn
         └─ Noble.transition(nextRoom)
              └─ MazeScene:enter()
                   └─ Player(playerSpawn.x, playerSpawn.y, ...)
                        └─ MazeScene:start() → isGaming = true

Player falls into hole
    └─ player:fallBelow()
         ├─ playerSpawn.x = self.x, playerSpawn.y = self.y
         └─ Noble.transition(lowerRoom)
              └─ MazeScene:enter() → same flow

Load save game
    └─ SaveSystem.load() → PlayerData restored (includes playerSpawn)
         └─ Noble.transition(PlayerData.floor scene)
              └─ MazeScene:enter() → same flow
```

---

## 🛠️ Love2D Porting Guide

### 1. Scene Transition with Spawn Data

In Love2D there is no Noble Engine. Use a global transition request table:

```lua
-- Write spawn before changing scene:
PlayerData.playerSpawn = { x = spawnX, y = spawnY }
SceneManager.goto("MazeScene", { roomId = nextRoom })

-- In MazeScene:enter():
function MazeScene:enter(params)
    self.player = Player.new(PlayerData.playerSpawn.x, PlayerData.playerSpawn.y)
    PlayerData.isGaming = false  -- lock during transition
end

-- After transition animation completes:
function MazeScene:onTransitionDone()
    PlayerData.isGaming = true
end
```

### 2. Door Spawn Positions

Copy `Door:prevRoom` logic exactly. The spawn offsets are hardcoded art-based values for a 400×240 screen:

```lua
local DOOR_SPAWN = {
    top   = function(px, py) return px,  196 end,  -- bottom of screen
    down  = function(px, py) return px,  32  end,  -- top of screen
    right = function(px, py) return 32,  py  end,  -- left edge
    left  = function(px, py) return 364, py  end,  -- right edge
}

function setSpawnFromDoor(direction, playerX, playerY)
    local sx, sy = DOOR_SPAWN[direction](playerX, playerY)
    PlayerData.playerSpawn = { x = sx, y = sy }
    PlayerData.lastRoom = direction
end
```

### 3. Hole / Ladder Spawn

```lua
function Player:fallBelow()
    PlayerData.playerSpawn = { x = self.x, y = self.y }
    SceneManager.goto("MazeScene", { roomId = getLowerRoom(PlayerData.floor) })
end
```

### 4. Save/Load Spawn Persistence

```lua
-- Save (love.filesystem + json):
function SaveSystem.save()
    local data = { playerData = PlayerData, levelsLDTK = levelsLDTK }
    love.filesystem.write("gameState.json", json.encode(data))
end

-- Load:
function SaveSystem.load()
    local raw = love.filesystem.read("gameState.json")
    if raw then
        local data = json.decode(raw)
        PlayerData = deepcopy(data.playerData)  -- includes playerSpawn
        levelsLDTK = deepcopy(data.levelsLDTK)
    end
end
```

### 5. `deepcopy` (Playdate CoreLibs extension)

`table.deepcopy` is not part of standard Lua. Implement it in Love2D:

```lua
function deepcopy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for k, v in pairs(orig) do
            copy[deepcopy(k)] = deepcopy(v)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end
```

### 6. `playerExit` for DanceScene Return

Track the exit position explicitly:

```lua
-- MazeScene:exit():
PlayerData.playerExit = { x = self.player.x, y = self.player.y }

-- DanceScene win → before returning to maze:
PlayerData.playerSpawn = { x = PlayerData.playerExit.x, y = PlayerData.playerExit.y }
SceneManager.goto("MazeScene", { roomId = PlayerData.floor })
```
