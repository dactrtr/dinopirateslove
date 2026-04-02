# Save System Documentation

This document explains the game's persistence layer, handled by `utilities/SaveSystem.lua`. It manages the saving and loading of player progress and world state adjustments.

---

## 💾 Overview

The Save System enables persistence by:
1.  **Serializing** the current state of dynamic objects (Enemies, Props, Triggers, CrewMembers, Items) into a Lua table.
2.  **Writing** this table to the Playdate's data store under the key `'gameState'`.
3.  **Restoring** this state when the game loads, patching the live `levelsLDTK` table in memory.

---

## 🗃️ Data Structure

The save file (managed by `playdate.datastore`, key `'gameState'`) contains a root table with the following fields:

### Root Object
-   **`version`**: String (e.g., `"2.0-LDTK"`). Used for migration checks.
-   **`timestamp`**: Table. The result of `playdate.getTime()` — returns a Lua table with fields like `year`, `month`, `day`, `hour`, `minute`, `second`, **not** a plain number.
-   **`player`**: Table. A direct snapshot of the global `PlayerData` table (Health, Inventory, Skills, Battery, `saveLevel`, etc.).
-   **`levelState`**: Array. The core world state data.

### Level State Object
`levelState` is an indexed array matching the `levelsLDTK` structure. Each entry contains:
-   **`identifier`**: String (e.g., `"Room_101"`).
-   **`uniqueIdentifer`**: String. The LDtk unique ID for the level. Used to re-match rooms if the array order changes.
-   **`visited`**: Boolean. Stored from `level.customFields.visited`.
-   **`comic_wasPlayed`**: Boolean. Stored from `level.customFields.comic_wasPlayed`. Tracks if the intro comic for this room has been shown.
-   **`entities`**: Table. Grouped by Entity Type (`Brocorat`, `Bosscolli`, `CrewMember`, `PropItem`, `Triggers`, etc.).

### Entity State Object
Entities are identified by their LDtk **IID** (Instance Identifier). Only changed/relevant fields are saved:

| Entity Type | Saved Fields |
|---|---|
| `Brocorat`, `Bosscolli` | `iid`, `dead`, `speed`, `x`, `y` |
| `PropItem` (with `destroyed`) | `iid`, `destroyed` |
| `CrewMember` | `iid`, `isTaken`, `crewID` |
| Items (with `isItem == true`) | `iid`, `collected` |
| `Triggers` | `iid`, `usedTrigger`, `type`, `script` |

---

## 🔄 Logic Flow

### 1. Backup (`createOriginalBackup`)
Called at game startup (in `main.lua`). Deep-copies the live `levelsLDTK` into `levelsLDTKOriginal`. This allows `reset()` and `delete()` to restore the world without reloading files from disk.

### 2. Saving (`getLevelState` → `save`)
`SaveSystem.save()` calls `getLevelState()` which iterates through the live `levelsLDTK` table in memory:
-   Always saves `identifier`, `uniqueIdentifer`, `visited`, and `comic_wasPlayed` for every room.
-   For each entity, saves only the fields relevant to its type (see table above).
-   The result is written to `playdate.datastore` with `write(saveData, 'gameState', true)`.
-   Returns `true` on success, `false` on failure.

### 3. Loading (`load` → `restoreLevelState`)
`SaveSystem.load()` reads from `playdate.datastore`:
1.  Checks `saveData.version == "2.0-LDTK"`. If not, returns `false, nil` and logs a migration warning.
2.  Overwrites the global `PlayerData` with `saveData.player`.
3.  Calls `restoreLevelState(saveData.levelState)` which patches the **already-live** `levelsLDTK` table directly. **It never touches `levelsLDTKOriginal`.**
4.  **Returns**: `true, saveData.player.saveLevel` — the second return value is the room number the player was in when they saved, used by callers to transition to the correct room.

`restoreLevelState` uses `uniqueIdentifer` to re-match rooms if the array order has changed, then patches `customFields` and entity properties by matching `iid`.

### 4. Reset (`reset`)
Calls `ResetPlayerData()` and deep-copies `levelsLDTKOriginal` back into `levelsLDTK`. Does **not** delete the save file — the file still exists on disk.

### 5. Delete (`delete`)
Calls `playdate.datastore.delete('gameState')` to remove the save file, then calls `ResetPlayerData()` and restores `levelsLDTK` from `levelsLDTKOriginal`.

---

## 🛠️ Love2D Porting Notes

### 1. File I/O (`playdate.datastore` → `love.filesystem`)
Playdate's `datastore` automatically serializes Lua tables.

```lua
-- Love2D equivalent using dkjson
local json = require("dkjson")

-- Saving
local function save(data)
    local str = json.encode(data, { indent = true })
    love.filesystem.write("savegame.json", str)
end

-- Loading
local function load()
    if love.filesystem.getInfo("savegame.json") then
        local str = love.filesystem.read("savegame.json")
        return json.decode(str)
    end
    return nil
end
```

Set `t.identity = "DinoPirates"` in `conf.lua` so Love2D writes to a named sandbox folder (equivalent to Playdate's per-game sandbox).

### 2. Save Slots
To support multiple save slots, use numbered files:
```lua
love.filesystem.write("save_1.json", str)
love.filesystem.write("save_2.json", str)
```

### 3. `timestamp` — `playdate.getTime()` → `os.date`
`playdate.getTime()` returns a table `{year, month, day, hour, minute, second, millisecond}`. In Love2D use:
```lua
local timestamp = os.date("*t")  -- returns equivalent table
```

### 4. Deep Copy (`table.deepcopy`)
Playdate CoreLibs provides `table.deepcopy`. In Love2D you must provide your own:
```lua
local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == "table" then
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
Use this to implement the `createOriginalBackup` equivalent.

### 5. Auto-save on Room Exit
Hook into your scene/room transition system. In Love2D with a state manager like `hump.gamestate`:
```lua
function RoomState:leave()
    SaveSystem.save()
end
```
Or trigger from your room transition function before switching scenes.

### 6. Version Migration
Check `saveData.version` on load and handle old formats gracefully:
```lua
if saveData.version ~= "2.0-LDTK" then
    -- show "incompatible save" message or run migration
    return false, nil
end
```

### 7. IID Matching Requirement
The entire entity restoration system relies on LDtk `iid` fields being preserved by your level loader. If using STI (Simple-Tiled-Implementation) or a custom LDtk parser for Love2D, **verify that object instance `iid` fields are kept** — some parsers discard them. You may need to extend the parser or post-process the loaded data to keep IIDs.
