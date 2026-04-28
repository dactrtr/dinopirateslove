# Level Loading & Room Translation

This document explains the technical flow of how rooms are loaded from data and how the game transitions between them.

---

## 🏗️ Floor Class Generation (`Floors.lua`)

`Floors.lua` creates a scene class for every valid room number using **hardcoded ranges**, not by iterating `levelsLDTK`.

```lua
local floorRanges = {
    { start = 166, stop = 180 },
    { start = 231, stop = 274 },
    { start = 316, stop = 330 },
    { start = 401, stop = 415 }
}
```

For each number `i` in those ranges, a class `FloorXXX` is created extending `MazeScene`. Its `init()`:
- Derives `level = math.floor(i / 100)` and `room = i % 100`
- Calls `self:setFloor(level, room)` to store the room index
- Sets `PlayerData.saveLevel = i` (used by the save system)

`RoomTranslate(i)` then retrieves the class via `_G["Floor" .. i]`.

---

## 🗺️ Data Source: `levels.lua`
The game uses a large table called `levelsLDTK` (exported from LDtk) as its world database. Each entry in this table contains:
- **`identifier`**: The room name (e.g., "Room_8").
- **`customFields`**: Critical metadata like `level`, `roomNumber`, `shadow` (darkness), and `tile` (tilemap ID).
- **`entities`**: A list of all objects to spawn (Doors, Props, Enemies, etc.) with their coordinates and custom fields.
- **`neighbourLevels`**: Structural data used to create doors and walls.

---

## 🔢 Room Numbering & Translation

The game uses a "Full Room Number" system to identify unique locations:
**`RoomNumber = (Level * 100) + InternalRoomID`**
*Example: Level 4, Room 8 becomes Room 408.*

### `RoomTranslate(roomNumber)`
Located in `utilities/Utilities.lua`, this function is the "bridge" between numeric IDs and the scene classes defined in the game:
```lua
function RoomTranslate(roomNumber)
    local floorClass = "Floor" .. roomNumber
    return _G[floorClass]
end
```
It looks up the string `"Floor408"` in the global Lua table `_G` and returns the class, which is then used by `Noble.transition`.

---

## 🏗️ The `MazeScene` Loading Flow

When a transition occurs, `MazeScene` goes through a specific lifecycle to build the room:

### 1. Finding the Room (`setFloor`)
Before Entering, the game searches `levelsLDTK` for the entry matching the desired `level` and `roomNumber` to get its index in the table.

### 2. Room Setup (`enter`)
- **Metadata**: Sets `PlayerData.actualLevel`, `PlayerData.actualRoom`, `PlayerData.actualTilemap`, `PlayerData.isInDarkness` from the room's `customFields`. Also marks `levelsLDTK[room].customFields.visited = true`.
- **Background**: Loads a static PNG from `assets/images/rooms/floor{level}/{identifier}` as the room background sprite (zIndex 1).
- **Foreground**: If `hasForeground == true`, loads `assets/images/rooms/floor{level}/foreground_{roomNumber}` at `ZIndex.foreground`.
- **Walls**: `CreateTileColliders(tileMapData[actualTilemap])` — generates wall collider sprites from the int-grid tile data.
- **Doors**: `CreateDoorsFromLDTK(currentRoom)` — creates door sprites from `neighbourLevels` + `DoorsConnection`.

### 3. Entity Spawning (in order)
The scene iterates `levelsLDTK[room].entities` in this order:

1. **Props** — Spawns `PropItem`. If `destroyed == false` or nil → normal prop; if `destroyed == true` → spawns `"debris"` variant.
2. **Items** — Spawns `Items` pickups only if the player doesn't already own them:
   - `keycard`: checks `PlayerData.keys[keyNum]`
   - entities with a `grants` field: parses `"key:value,key:value"` and checks `PlayerData.items[key]` / `PlayerData.skills[key]`
   - other known items: checks the corresponding `PlayerData.items[fieldName]`
3. **Player** — Spawned from `PlayerData.playerSpawn.x/y`. HUD (`playerHud`) and in-game menu created here.
4. **FX** — `FXshadow` created if `customFields.shadow == true`, using `customFields.light` as light radius.
5. **Cutscene** — If room has `comic_name` and `play == "Enter"` and `comic_wasPlayed == false`, Panels cutscene plays. Sets `PlayerData.isCutscene = true` until complete.
6. **Enemies** — `Brocorat` or `Bosscolli` spawned if `dead == false`. Dead enemies leave a `"blood2"` PropItem.
7. **CrewMembers** — `CrewMember` spawned if `isTaken == false`.
8. **NPCs** — `NPC` entities spawned unconditionally.
9. **Triggers** — `Trigger` entities spawned if `usedTrigger == false`. Drive dialogs, cutscenes, and counters.

---

### 4. Scene start / exit

- **`start()`**: Calls `self:setDiagonalMovement(diagonalMovement)`, then sets `PlayerData.isGaming = true`.
- **`exit()`**: Removes HUD, floor sprite, foreground, shadow, tile colliders, and all remaining sprites. Stores `PlayerData.playerExit.x/y = player.x/y`.
- **`finish()`**: Sets `PlayerData.isGaming = false`, calls `SaveSystem.save()`.
- **`pause()`**: Calls `SaveSystem.save()` (triggered when the system menu opens).

---

## 🔄 Persistence
State changes are saved back into the `levelsLDTK` table (or mirrored in `PlayerData`):
- When an enemy is killed or a prop is broken, the `customFields` in the active `levelsLDTK` entry are updated.
- `MazeScene:finish()` and `MazeScene:pause()` both call `SaveSystem.save()`, ensuring changes persist when exiting a room or pausing (e.g., opening the system menu).
- `PlayerData.playerExit` records the player's last position when leaving a room (separate from `playerSpawn`, which is set before transitioning in).

> [!TIP]
> The dynamic wall system in `Utilities.lua` is what allows rooms to feel connected; it hides the 12px wall sprites only where a neighbor is detected in LDtk.

---

## 🪜 Vertical Level Navigation System

The game supports vertical navigation between floors using a **neighbor-based connection system**. This allows the player to fall down holes or climb up tubes to different levels.

### Level Connection Architecture

Each room in `levelsLDTK` contains two critical fields for vertical navigation:

#### 1. `neighbourLevels` Array
This array defines which rooms are adjacent to the current room. Each neighbor entry contains:
- **`levelIid`**: The unique identifier (`uniqueIdentifer`) of the neighboring room
- **`dir`**: The direction of the neighbor using LDtk notation:
  - `"<"` = Lower floor (fall down)
  - `">"` = Upper floor (climb up)
  - `"n"`, `"s"`, `"e"`, `"w"` = Cardinal directions (north, south, east, west)
  - `"nw"`, `"ne"`, `"sw"`, `"se"` = Diagonal directions

**Example from Room_8:**
```lua
neighbourLevels = {
  {
    levelIid = "3d752854-ac70-11f0-998c-5dddbfac239d",
    dir = "<"  -- Lower floor connection
  },
  {
    levelIid = "bf654080-ac70-11f0-997a-e578ba2da2ac",
    dir = "n"  -- North door
  },
  -- ... more neighbors
}
```

#### 2. `customFields.DoorsConnection` Array
This array acts as a **permission system** that determines which types of connections are allowed in this room. It contains string values like:
- `"Upper"` - Allows climbing to upper floor
- `"Lower"` - Allows falling to lower floor
- `"Top"`, `"Down"`, `"Left"`, `"Right"` - Allows cardinal direction doors

**Example from Room_8:**
```lua
customFields = {
  level = 4,
  roomNumber = 8,
  DoorsConnection = {
    "Top",    -- Can use north doors
    "Down",   -- Can use south doors
    "Lower"   -- Can fall to lower floor
  }
}
```

> [!IMPORTANT]
> A room can have a neighbor in the `neighbourLevels` array, but if the corresponding direction is NOT in `DoorsConnection`, the player **cannot** use that connection. This allows level designers to create one-way passages or locked vertical connections.

### How `fallBelow()` Works

Located in [`entities/player/state.lua`](../entities/player/state.lua#L1-L32), this function handles falling to a lower floor:

```lua
function Player:fallBelow()
  -- 1. Get current room index from PlayerData
  local currentRoomIndex = PlayerData.floor
  
  -- 2. Search for lower room using GetLowerRoom()
  local lowerRoomNumber, lowerRoomData = GetLowerRoom(currentRoomIndex)
  
  -- 3. Validate that a lower room exists
  if not lowerRoomNumber then
    return  -- Cannot fall from this room
  end
  
  -- 4. Translate room number to scene class
  local nextScene = RoomTranslate(lowerRoomNumber)
  
  -- 5. Preserve player position (X and Y)
  PlayerData.playerSpawn.x = self.x
  PlayerData.playerSpawn.y = self.y
  
  -- 6. Transition to the lower room with fall animation
  Noble.transition(nextScene, 1.5, Noble.Transition.Imagetable, {
    imagetableEnter = Graphics.imagetable.new('assets/images/screens/transitions/transitionFallEnter'),
    imagetableExit = Graphics.imagetable.new('assets/images/screens/transitions/transitionFallOut'),
  })
end
```

**Key Steps:**
1. **Get Current Room**: Retrieves the current room index from `PlayerData.floor`
2. **Find Lower Room**: Calls `GetLowerRoom()` which performs validation
3. **Validate Connection**: Returns `nil` if no valid lower room exists
4. **Translate to Scene**: Converts room number (e.g., `308`) to scene class (`Floor308`)
5. **Preserve Position**: Keeps player X/Y coordinates for seamless transition
6. **Transition**: Uses Noble framework with custom fall animations

### How `riseAbove()` Works

Located in [`entities/player/state.lua`](../entities/player/state.lua#L34-L59), this function handles climbing to an upper floor:

```lua
function Player:riseAbove()
  -- 1. Get current room index
  local currentRoomIndex = PlayerData.floor
  
  -- 2. Search for upper room using GetUpperRoom()
  local upperRoomNumber, upperRoomData = GetUpperRoom(currentRoomIndex)
  
  -- 3. Validate that an upper room exists
  if not upperRoomNumber then
    return  -- Cannot climb from this room
  end
  
  -- 4. Translate room number to scene class
  local nextScene = RoomTranslate(upperRoomNumber)
  
  -- 5. Preserve player position
  PlayerData.playerSpawn.x = self.x
  PlayerData.playerSpawn.y = self.y
  
  -- 6. Transition to the upper room
  Noble.transition(nextScene, 1.5, Noble.Transition.Default)
end
```

The logic is identical to `fallBelow()` but uses `GetUpperRoom()` instead.

### The `GetLowerRoom()` Function

Located in [`utilities/Utilities.lua`](../utilities/Utilities.lua#L213-L261), this function performs the actual neighbor search and validation:

```lua
function GetLowerRoom(currentRoomIndex)
  -- 1. Get current room data from levelsLDTK
  local currentRoom = levelsLDTK[currentRoomIndex]
  
  -- 2. Validate permission using CanMoveVertically()
  if not CanMoveVertically(currentRoom, "<") then
    return nil  -- Room doesn't have "Lower" in DoorsConnection
  end
  
  -- 3. Find neighbor with direction "<" (lower)
  local lowerNeighbor = FindNeighborByDirection(currentRoom, "<")
  if not lowerNeighbor then
    return nil  -- No lower neighbor defined
  end
  
  -- 4. Find the actual room data using the neighbor's iid
  local lowerRoom = FindRoomByIid(lowerNeighbor.levelIid)
  
  -- 5. Calculate full room number (level * 100 + roomNumber)
  if lowerRoom then
    local level = lowerRoom.customFields.level
    local roomNum = lowerRoom.customFields.roomNumber
    local roomNumber = level * 100 + roomNum
    return roomNumber, lowerRoom
  else
    -- Fallback: calculate expected room number
    local currentLevel = currentRoom.customFields.level
    local currentRoomNum = currentRoom.customFields.roomNumber
    local expectedRoom = (currentLevel - 1) * 100 + currentRoomNum
    return expectedRoom, nil
  end
end
```

**Validation Flow:**
1. **Permission Check**: `CanMoveVertically()` checks if `"Lower"` exists in `DoorsConnection`
2. **Neighbor Search**: `FindNeighborByDirection()` looks for a neighbor with `dir = "<"`
3. **Room Lookup**: `FindRoomByIid()` finds the actual room data using the `levelIid`
4. **Room Number Calculation**: Combines `level * 100 + roomNumber` to get full room ID

### The `GetUpperRoom()` Function

Located in [`utilities/Utilities.lua`](../utilities/Utilities.lua#L266-L314), this function is identical to `GetLowerRoom()` but:
- Uses `CanMoveVertically(currentRoom, ">")` to check for `"Upper"` permission
- Searches for neighbor with `dir = ">"`
- Calculates upper room as `(currentLevel + 1) * 100 + currentRoomNum`

### Helper Functions

#### `CanMoveVertically(currentRoom, direction)`
Validates if vertical movement is allowed by checking `DoorsConnection`:
```lua
function CanMoveVertically(currentRoom, direction)
  local doorsConnection = currentRoom.customFields.DoorsConnection or {}
  
  local directionMap = {
    ["<"] = "lower",  -- Fall downwards
    [">"] = "upper"   -- Climb upwards
  }
  
  local requiredConnection = directionMap[direction]
  
  for _, allowed in ipairs(doorsConnection) do
    if allowed:lower() == requiredConnection:lower() then
      return true
    end
  end
  
  return false
end
```

#### `FindNeighborByDirection(currentRoom, direction)`
Searches the `neighbourLevels` array for a specific direction:
```lua
function FindNeighborByDirection(currentRoom, direction)
  if not currentRoom.neighbourLevels then
    return nil
  end
  
  for _, neighbor in ipairs(currentRoom.neighbourLevels) do
    if neighbor.dir == direction then
      return neighbor
    end
  end
  
  return nil
end
```

#### `FindRoomByIid(iid)`
Finds a room by its unique identifier. Uses a hash index (`roomsByIid`) for O(1) lookup, with linear search fallback.

> [!NOTE]
> `FindRoomByIid` is defined in **`entities/props/door.lua`**, not in `utilities/Utilities.lua`. It is a local helper used by the door loading system to resolve neighbor rooms from LDtk `levelIid` references.

```lua
-- entities/props/door.lua
function FindRoomByIid(iid)
  -- Fast hash lookup
  if roomsByIid and roomsByIid[iid] then
    return roomsByIid[iid]
  end

  -- Fallback: linear search
  for i, room in ipairs(levelsLDTK) do
    if room and room.uniqueIdentifer == iid then
      return room
    end
  end

  return nil
end
```

---

## 💡 Love2D Porting Guide: Vertical Navigation

When porting this system to Love2D, consider the following implementation approach:

### 1. Data Structure (No Changes Needed)
The `levelsLDTK` table structure works perfectly in Love2D. You can use the same JSON export from LDtk.

```lua
-- Love2D: Load level data
local json = require("json")  -- or use a JSON library like dkjson
local file = love.filesystem.read("assets/data/levels.json")
levelsLDTK = json.decode(file)
```

### 2. Room Index Optimization
**Playdate Implementation**: Uses `PlayerData.floor` as a numeric index into the `levelsLDTK` array.

**Love2D Recommendation**: Create a hash table for faster lookups:
```lua
-- Build hash indices on game start
roomsByIid = {}
roomsByNumber = {}

for i, room in ipairs(levelsLDTK) do
  -- Index by unique ID
  roomsByIid[room.uniqueIdentifer] = room
  
  -- Index by room number
  local level = room.customFields.level
  local roomNum = room.customFields.roomNumber
  local fullNumber = level * 100 + roomNum
  roomsByNumber[fullNumber] = room
end
```

### 3. Scene Transition System
**Playdate Implementation**: Uses Noble framework's `Noble.transition()` with custom animations.

**Love2D Implementation**: You'll need to implement your own scene manager:
```lua
-- Love2D: Simple scene manager
SceneManager = {
  current = nil,
  next = nil,
  transition = {
    active = false,
    duration = 1.5,
    timer = 0,
    type = "fade"  -- or "fall", "slide", etc.
  }
}

function SceneManager:switchTo(sceneName, transitionType, duration)
  self.next = sceneName
  self.transition.active = true
  self.transition.type = transitionType or "fade"
  self.transition.duration = duration or 1.5
  self.transition.timer = 0
end

function SceneManager:update(dt)
  if self.transition.active then
    self.transition.timer = self.transition.timer + dt
    
    if self.transition.timer >= self.transition.duration then
      -- Complete transition
      self.current = self.next
      self.next = nil
      self.transition.active = false
      
      -- Initialize new scene
      if self.current.enter then
        self.current:enter()
      end
    end
  elseif self.current and self.current.update then
    self.current:update(dt)
  end
end
```

### 4. Player Position Preservation
**Playdate Implementation**: Stores position in `PlayerData.playerSpawn.x/y`.

**Love2D Implementation**: Same approach works perfectly:
```lua
-- Love2D: Preserve position during vertical transition
function Player:fallBelow()
  local currentRoomIndex = PlayerData.floor
  local lowerRoomNumber, lowerRoomData = GetLowerRoom(currentRoomIndex)
  
  if not lowerRoomNumber then
    return
  end
  
  -- Preserve position (same as Playdate)
  PlayerData.playerSpawn.x = self.x
  PlayerData.playerSpawn.y = self.y
  
  -- Transition to new scene
  local nextScene = RoomTranslate(lowerRoomNumber)
  SceneManager:switchTo(nextScene, "fall", 1.5)
end
```

### 5. Transition Animations
**Playdate Implementation**: Uses imagetable animations for fall transitions.

**Love2D Implementation**: Use shaders or sprite-based animations:
```lua
-- Love2D: Fall transition shader
local fallShader = love.graphics.newShader([[
  extern number progress;  // 0.0 to 1.0
  
  vec4 effect(vec4 color, Image texture, vec2 tc, vec2 pc) {
    // Vertical blur effect
    vec4 sum = vec4(0.0);
    float blur = progress * 0.05;
    
    for(float i = -4.0; i <= 4.0; i++) {
      sum += Texel(texture, vec2(tc.x, tc.y + i * blur));
    }
    
    return sum / 9.0 * color;
  }
]])

-- In transition update:
function TransitionManager:drawFall(progress)
  fallShader:send("progress", progress)
  love.graphics.setShader(fallShader)
  -- Draw current scene
  love.graphics.setShader()
end
```

### 6. Collision Detection for Holes/Tubes
**Playdate Implementation**: Uses sprite overlap detection with collision groups.

**Love2D Implementation**: Use a physics library like bump.lua or HC (HardonCollider):
```lua
-- Love2D with bump.lua
function Player:checkVerticalTriggers()
  local items, len = world:queryRect(self.x, self.y, self.width, self.height)
  
  for i = 1, len do
    local item = items[i]
    
    if item.type == "hole" then
      -- Trigger fall
      self:fallBelow()
    elseif item.type == "tube" then
      -- Trigger climb
      self:riseAbove()
    end
  end
end
```

### 7. Performance Considerations

**Playdate Constraints**: 
- Limited memory (16MB)
- Single-threaded
- Uses array indices for fast access

**Love2D Advantages**:
- More memory available
- Can use hash tables without performance penalty
- Can preload multiple rooms for faster transitions

**Recommended Love2D Optimization**:
```lua
-- Preload adjacent rooms for instant transitions
function RoomManager:preloadAdjacentRooms(currentRoomIndex)
  local currentRoom = levelsLDTK[currentRoomIndex]
  
  for _, neighbor in ipairs(currentRoom.neighbourLevels) do
    local neighborRoom = FindRoomByIid(neighbor.levelIid)
    
    if neighborRoom and not neighborRoom.loaded then
      -- Load tilemap, entities, etc.
      self:loadRoomAssets(neighborRoom)
      neighborRoom.loaded = true
    end
  end
end
```

### 8. Debug Visualization
**Love2D Advantage**: Easy to visualize connections for debugging:
```lua
-- Love2D: Draw neighbor connections (debug mode)
function DebugDraw:drawRoomConnections(room)
  love.graphics.setColor(1, 1, 0, 0.5)  -- Yellow
  
  for _, neighbor in ipairs(room.neighbourLevels) do
    local neighborRoom = FindRoomByIid(neighbor.levelIid)
    
    if neighborRoom then
      -- Draw arrow from current room to neighbor
      local dx = neighborRoom.x - room.x
      local dy = neighborRoom.y - room.y
      
      love.graphics.line(
        room.x + room.width/2,
        room.y + room.height/2,
        neighborRoom.x + neighborRoom.width/2,
        neighborRoom.y + neighborRoom.height/2
      )
      
      -- Draw direction label
      love.graphics.print(neighbor.dir, 
        room.x + room.width/2 + dx/2,
        room.y + room.height/2 + dy/2
      )
    end
  end
end
```

---

## 🎮 Triggering Vertical Navigation

The player triggers `fallBelow()` and `riseAbove()` through collision with special entities:

- **Holes**: Entities with `type = "hole*"` trigger `fallBelow()`
- **Tubes/Ladders**: Entities with `type = "tube"` or `type = "pneumaticTube"` trigger `riseAbove()`

These are typically detected in the player's collision response or overlap detection system.
