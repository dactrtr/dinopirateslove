# Save System Documentation

This document explains the game's persistence layer, handled by `utilities/SaveSystem.lua`. It manages the saving and loading of player progress and world state.

---

## 💾 Overview

The Save System enables persistence by:
1.  **Serializing** the current state of dynamic objects (Enemies, Props, Triggers) into a Lua table.
2.  **Writing** this table to the Playdate's datastore under the key **`'gameState'`** → creates `gameState.json` on disk.
3.  **Restoring** this state when the game loads, applying changes to the initial LDtk level data.

---

## 🗃️ Data Structure

The save file is written via `playdate.datastore.write(saveData, 'gameState', true)`.

### Root Object
-   **`version`**: String — `"2.0-LDTK"`. Used for migration checks.
-   **`timestamp`**: **Table** — result of `playdate.getTime()`, which returns `{year, month, day, hour, minute, second, millisecond}`. **Not a Unix timestamp integer.** In Love2D use `os.time()` for a Unix integer or `os.date("*t")` for a compatible table.
-   **`player`**: Table — direct snapshot of the global `PlayerData` table (Health, Inventory, Skills, Battery, etc.).
-   **`levelState`**: Array — the core world state data.

### Level State Object
`levelState` is an indexed array matching the `levelsLDTK` structure. Each entry contains:
-   **`identifier`**: String (e.g., `"Room_101"`).
-   **`uniqueIdentifer`**: String — LDtk IID, used to match rooms if order changes.
-   **`visited`**: Boolean.
-   **`comic_wasPlayed`**: Boolean.
-   **`entities`**: Table grouped by Entity Type (`Brocorat`, `CrewMember`, `PropItem`, etc.).

### Entity State Object
Entities are identified by LDtk **IID** (Instance Identifier):
-   **`iid`**: String — the unique ID from LDtk.
-   **`dead`** (Enemies): Boolean.
-   **`destroyed`** (Props): Boolean.
-   **`isTaken`** (CrewMembers): Boolean.
-   **`collected`** (Items): Boolean.
-   **`usedTrigger`** (Triggers): Boolean.

---

## 🔄 Logic Flow

### 1. Saving (`getLevelState`)
Iterates `levelsLDTK` and extracts only changed fields for each entity. Minimizes file size by skipping static data. Called by:
- `MazeScene:finish()` — saves on room exit (two call sites).
- `DanceScene:exit()` — saves after every dance (win or lose).

### 2. Loading (`restoreLevelState`)
When the game boots:
1.  Loads raw data via `playdate.datastore.read('gameState')`.
2.  Validates `version == "2.0-LDTK"`.
3.  Restores `PlayerData` directly: `PlayerData = saveData.player`.
4.  For each saved entity record, finds the matching entity in fresh `levelsLDTK` by `iid` and overwrites its fields.

### 3. Reset (`SaveSystem.reset`)
```lua
function SaveSystem.reset()
    ResetPlayerData()
    if levelsLDTKOriginal then
        levelsLDTK = table.deepcopy(levelsLDTKOriginal)
    end
end
```
Uses `table.deepcopy` — a **Playdate CoreLibs extension** that deep-clones a table. `levelsLDTKOriginal` is a backup created via `SaveSystem.createOriginalBackup()` at game start, before any runtime mutations. This allows full world reset without re-parsing the LDtk file.

### 4. Delete (`SaveSystem.delete`)
Calls `playdate.datastore.delete('gameState')` then calls `reset()`.

---

## 🛠️ Love2D Porting Guide

### 1. File I/O (`playdate.datastore` vs `love.filesystem`)
```lua
local json = require "dkjson"

-- Saving
local saveData = { player = PlayerData, levelState = getLevelState(), version = "2.0-LDTK", timestamp = os.time() }
local str = json.encode(saveData)
love.filesystem.write("savegame.json", str)

-- Loading
if love.filesystem.getInfo("savegame.json") then
    local str = love.filesystem.read("savegame.json")
    local data = json.decode(str)
    if data.version == "2.0-LDTK" then
        PlayerData = data.player
        restoreLevelState(data.levelState)
    end
end
```

### 2. Timestamp
- **Playdate**: `playdate.getTime()` → `{year=2025, month=3, day=10, hour=14, minute=30, second=0, millisecond=500}`
- **Love2D (Unix integer)**: `os.time()` → `1741613400`
- **Love2D (table)**: `os.date("*t")` → `{year=2025, month=3, day=10, hour=14, min=30, sec=0, wday=1, yday=69, isdst=false}`

### 3. Save Directory
- **Love2D**: `love.filesystem.getSaveDirectory()` (e.g., `%APPDATA%/Love/GameName` on Windows). Set `t.identity` in `conf.lua`.

### 4. Entity ID Matching
The `iid`-based matching is platform-agnostic. Ensure your LDtk loader preserves the `iid` field for every entity. If it discards IIDs, the save/restore system will not work.

### 5. Deep Copy (table.deepcopy Replacement)
```lua
-- Bring your own deepcopy for Love2D:
function table.deepcopy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for k, v in pairs(orig) do
            copy[table.deepcopy(k)] = table.deepcopy(v)
        end
        setmetatable(copy, table.deepcopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- Use to create the original level backup at game start:
levelsLDTKOriginal = table.deepcopy(levelsLDTK)
```
