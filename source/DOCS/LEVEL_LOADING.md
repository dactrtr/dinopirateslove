# Level Loading & Room Translation

This document explains the technical flow of how rooms are loaded from data and how the game transitions between them.

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
- **Metadata**: Sets `PlayerData.isInDarkness` and `PlayerData.actualTilemap` based on room fields.
- **Environment**: Renders the `tilemap` and creates the `FXshadow` if the room is dark.
- **Walls & Doors**: Calls `CreateTileColliders` (for walls) and `CreateDoorsFromLDTK`. Walls are automatically generated from non-walkable tiles in the tilemap.

### 3. Entity Spawning
The scene iterates through the room's `entities` table:
- **Props**: Spawns `PropItem` instances, checking if they were previously `destroyed`.
- **Items**: Spawns `Items` (pickups) only if the player doesn't already have them. For `itemgift` and `notes`, it checks the `grants` field to see if the player owns the specific items or skills listed.
- **Enemies**: Spawns `Brocorat`, `Bosscolli`, or `CrewMember` based on their `dead` or `isTaken` status.

---

## 🔄 Persistence
State changes are saved back into the `levelsLDTK` table (or mirrored in `PlayerData`):
- When an enemy is killed or a prop is broken, the `customFields` in the active `levelsLDTK` entry are updated.
- `MazeScene:finish()` calls `SaveSystem.save()`, ensuring these changes persist across game restarts.

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

Located in [`entities/player/collisions.lua`](file:///Users/dactrtr-mini/Documents/GitHub/DinopiratesLove/dinopirateslove/source/entities/player/collisions.lua#L338-L380), this function handles falling to a lower floor:

```lua
function collisions.fallBelow(player)
  -- 1. Validate levelsLDTK is available
  if not levelsLDTK then
    return
  end
  
  -- 2. Get current room data using PlayerData.floor index
  local currentRoomIndex = PlayerData.floor
  local currentRoom = levelsLDTK[currentRoomIndex]
  
  -- 3. Check permission: Does this room allow falling to lower floor?
  if not canMoveVertically(currentRoom, "<") then
    return  -- Room doesn't have "Lower" in DoorsConnection
  end
  
  -- 4. Find the lower neighbor using direction "<"
  local lowerNeighbor = findNeighborByDirection(currentRoom, "<")
  if not lowerNeighbor then
    return  -- No lower neighbor defined in neighbourLevels
  end
  
  -- 5. Get the levelIid of the lower room
  local nextLevelIid = lowerNeighbor.levelIid
  
  -- 6. Trigger level transition via gameScene
  local sceneManager = require 'sceneManager'
  local gameScene = sceneManager.getScene("game")
  if gameScene then
    gameScene.changeLevel(nextLevelIid, "down", player, 0.5)
  end
end
```

**Key Steps:**
1. **Validate Data**: Ensures `levelsLDTK` is available
2. **Get Current Room**: Retrieves the current room data from `levelsLDTK` using `PlayerData.floor` index
3. **Check Permission**: Calls `canMoveVertically()` to validate "Lower" permission in `DoorsConnection`
4. **Find Neighbor**: Uses `findNeighborByDirection()` to search for a neighbor with `dir = "<"`
5. **Get Level IID**: Extracts the `levelIid` from the neighbor data
6. **Transition**: Calls `gameScene.changeLevel()` with the IID and direction

### How `riseAbove()` Works

Located in [`entities/player/collisions.lua`](file:///Users/dactrtr-mini/Documents/GitHub/DinopiratesLove/dinopirateslove/source/entities/player/collisions.lua#L381-L421), this function handles climbing to an upper floor:

```lua
function collisions.riseAbove(player)
  -- 1. Validate levelsLDTK is available
  if not levelsLDTK then
    return
  end
  
  -- 2. Get current room data using PlayerData.floor index
  local currentRoomIndex = PlayerData.floor
  local currentRoom = levelsLDTK[currentRoomIndex]
  
  -- 3. Check permission: Does this room allow climbing to upper floor?
  if not canMoveVertically(currentRoom, ">") then
    return  -- Room doesn't have "Upper" in DoorsConnection
  end
  
  -- 4. Find the upper neighbor using direction ">"
  local upperNeighbor = findNeighborByDirection(currentRoom, ">")
  if not upperNeighbor then
    return  -- No upper neighbor defined in neighbourLevels
  end
  
  -- 5. Get the levelIid of the upper room
  local nextLevelIid = upperNeighbor.levelIid
  
  -- 6. Trigger level transition via gameScene
  local sceneManager = require 'sceneManager'
  local gameScene = sceneManager.getScene("game")
  if gameScene then
    gameScene.changeLevel(nextLevelIid, "top", player, 0.5)
  end
end
```

The logic is identical to `fallBelow()` but uses `canMoveVertically(currentRoom, ">")` to check for "Upper" permission and searches for a neighbor with `dir = ">"` instead.

### Helper Functions

Located in [`entities/player/collisions.lua`](file:///Users/dactrtr-mini/Documents/GitHub/DinopiratesLove/dinopirateslove/source/entities/player/collisions.lua#L294-L337), these local helper functions support the vertical navigation system:

#### `canMoveVertically(currentRoom, direction)`
Validates if vertical movement is allowed by checking `DoorsConnection`:
```lua
local function canMoveVertically(currentRoom, direction)
  if not currentRoom or not currentRoom.customFields then
    return false
  end
  
  local doorsConnection = currentRoom.customFields.DoorsConnection or {}
  
  -- Map direction symbols to permission strings
  local directionMap = {
    ["<"] = "lower",  -- Fall downwards
    [">"] = "upper"   -- Climb upwards
  }
  
  local requiredPermission = directionMap[direction]
  if not requiredPermission then
    return false
  end
  
  -- Check if permission exists in DoorsConnection array
  for _, allowed in ipairs(doorsConnection) do
    if allowed:lower() == requiredPermission then
      return true
    end
  end
  
  return false
end
```

**Parameters:**
- `currentRoom`: The room data from `levelsLDTK`
- `direction`: Either `"<"` (lower) or `">"` (upper)

**Returns:** `true` if the room has the required permission, `false` otherwise

#### `findNeighborByDirection(currentRoom, direction)`
Searches the `neighbourLevels` array for a specific direction:
```lua
local function findNeighborByDirection(currentRoom, direction)
  if not currentRoom or not currentRoom.neighbourLevels then
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

**Parameters:**
- `currentRoom`: The room data from `levelsLDTK`
- `direction`: The direction to search for (e.g., `"<"`, `">"`, `"n"`, `"s"`, etc.)

**Returns:** The neighbor object with `{levelIid, dir}` if found, `nil` otherwise

---

### Validation Flow

When a player attempts vertical navigation:

1. **Permission Check**: `canMoveVertically()` checks if `"Lower"` or `"Upper"` exists in `DoorsConnection`
2. **Neighbor Search**: `findNeighborByDirection()` looks for a neighbor with `dir = "<"` or `">"`
3. **Level Transition**: If both checks pass, `gameScene.changeLevel()` is called with the neighbor's `levelIid`
4. **Position Preservation**: The player's X/Y coordinates are maintained during the transition

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
