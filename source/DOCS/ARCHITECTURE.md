# Architecture — Boot Sequence and Global Connections

## Import order in `main.lua`

`main.lua` is the only entry point. Imports run top to bottom; order matters because
later files depend on globals set by earlier ones.

```
1.  Noble (scene framework)
2.  Panels (cutscene library)
3.  achievements/all
4.  assets/data/Config          → defines Config table
5.  utilities/Utilities         → defines Box class, helper functions
6.  utilities/SaveSystem        → defines SaveSystem table
7.  scenes/* (all scenes)
8.  assets/data/PlayerDataTables → defines PlayerData, ResetPlayerData()
9.  assets/data/levels          → defines levelsLDTK
10. assets/data/tilemap         → defines tileMapData
11. assets/data/script          → defines script table (dialog scripts)
```

## Globals set in `main.lua` after imports

These are available everywhere in the game (no `require` or `import` needed):

| Global | Source | Value |
|---|---|---|
| `Config` | `Config.lua` | All tunable constants |
| `ZIndex` | `main.lua` | `= Config.ZIndex` |
| `CollideGroups` | `main.lua` | `= Config.CollideGroups` |
| `ButtonTypes` | `main.lua` | `{A="aButton", B="bButton", ...}` |
| `Directions` | `main.lua` | `{LEFT="left", RIGHT="right", UP="up", DOWN="down", IDLE="idle", TOP="top", BOTTOM="down"}` |
| `PlayerData` | `PlayerDataTables.lua` | Mutable game state (deep copy of DefaultPlayerData) |
| `levelsLDTK` | `levels.lua` | All room/entity data from LDtk |
| `tileMapData` | `tilemap.lua` | IntGrid matrices for wall collision |
| `script` | `script.lua` | Array of dialog script entries |
| `roomsByIid` | `main.lua` | Hash built from `levelsLDTK` for O(1) room lookup |
| `debug` | `main.lua` | `false` — toggled via system menu or cheat code (up up up down) |
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

See [CONFIG_REFERENCE.md](CONFIG_REFERENCE.md) for every field in both tables.

## Noble scene lifecycle

```
Noble.new(TitleScene)
  └─ scene:init()    ← called when transitioning AWAY from previous scene
     scene:enter()   ← called when this scene needs to be visible
     scene:start()   ← called when transition animation is complete
     scene:update()  ← called every frame (~50fps in MazeScene)
     scene:pause()   ← called when system menu opens → triggers SaveSystem.save()
     scene:exit()    ← called when transitioning to next scene
     scene:finish()  ← called when transition animation completes → triggers SaveSystem.save()
```

**Important:** `PlayerData.isGaming` is set to `true` in `scene:start()`, not in
`scene:enter()`. Entities spawn during `enter()` but gameplay input is blocked until
`start()` completes.

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

---

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
      .visited           = true  (marks room as explored, via levelsLDTK)

2.  Load room background PNG:
      path = 'assets/images/rooms/floor{level}/{identifier}'
      floor sprite at ZIndex 1, centered at (200, 120)
      NOTE: rooms are pre-rendered PNGs, NOT rendered from tilemap at runtime

3.  Load foreground PNG (if customFields.hasForeground == true):
      path = 'assets/images/rooms/floor{level}/foreground_{roomNumber}'
      foreground sprite at ZIndex.foreground (300), same position

4.  Create inGameMenu instance

5.  CreateTileColliders(tileMapData[PlayerData.actualTilemap])
      Builds Box wall colliders from IntGrid matrix
      IntGrid values: wall=1, slime=2, hole=3, floor=4

6.  CreateDoorsFromLDTK(currentRoom)
      Iterates currentRoom.entities.Doors, creates Door sprites
      (Stair connections do NOT create Door sprites — they use fallBelow/riseAbove)

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

---

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

**Key differences for Love2D porter:**
- Noble's `scene:start()` maps to "after transition animation completes." If you use
  instant scene switches, call `scene:start()` immediately after `scene:enter()`.
- `playdate.timer` (aliased as `timers`) maps to `love.timer` — but Love2D uses
  `dt`-based timers rather than polling-based timers.
- `PlayerData.isGaming = true` must still be deferred until after any entry animation.

---

## Related documentation

| Doc | What it covers |
|---|---|
| [CONFIG_REFERENCE.md](CONFIG_REFERENCE.md) | Every Config field, value, and Love2D equivalent |
| [PLAYERDATA_REFERENCE.md](PLAYERDATA_REFERENCE.md) | Every PlayerData field, who reads/writes it |
| [CUTSCENE_SYSTEM.md](CUTSCENE_SYSTEM.md) | Room-entry and trigger cutscenes |
| [TRIGGER_SYSTEM.md](TRIGGER_SYSTEM.md) | Trigger entity types and collision handling |
| [DATA_FLOW.md](DATA_FLOW.md) | ASCII dependency graph, collision dispatch map |
| [INPUT_SYSTEM.md](INPUT_SYSTEM.md) | Button state machine and Love2D key mapping |
| [SAVE_SYSTEM.md](SAVE_SYSTEM.md) | Save/load/reset/backup lifecycle |
| [LEVEL_LOADING.md](LEVEL_LOADING.md) | Door navigation and vertical room transitions |
