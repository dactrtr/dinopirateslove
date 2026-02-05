# Props & Items Documentation

This document details the environment objects (Props) and collectibles (Items) that populate the game world.

---

## 📦 Items (Pickups)
Items are specialized sprites that grant the player new abilities or resources upon contact.

### 1. Item Types
- **`keycard`**: Grants access to doors with matching `keyNumber`.
- **`lamp`**: Enables visibility in dark rooms and triggers sanity regen logic.
- **`radio` / `notes`**: Story-relevant items.
- **`bag`**: Required to capture CrewMembers.
- **`boots`**: Prevents falling into holes if battery is available.
- **`plunger`**: Prevents sliding on slime.
- **`itemgift`**: A generic delivery item that can grant any boolean flag in `PlayerData.items` (e.g., `hasPlunger:true`).

### 2. Dynamic Grants (LDtk)
Items like `itemgift` and `notes` use a `grants` custom field in LDtk to dynamically update `PlayerData`.
- **Format**: `"key1:value1,key2:value2"` (e.g., `"hasPlunger:true"` or `"canFlash:true"`).
- **Processing**:
    - `itemgift` updates the `PlayerData.items` table.
    - `notes` updates the `PlayerData.skills` table.
- **Conditional Rendering**: In `MazeScene.lua`, items with a `grants` field are only spawned if the player **does not** already possess the granted item/skill. This ensures objects disappear from the world permanently once collected.

### 3. Interaction Flow
In `collisions.lua`:
- Hitting an item usually calls `other:removeAll()`.
- It then calls a corresponding "grab" function on the player (e.g., `self:grabItemGift(other.grants)` or `self:grabNotes(other.grants)`).
- Grabbing an item typically updates a boolean in `PlayerData.items`, `PlayerData.skills`, or `PlayerData.keys`.

---

## 🖼️ PropItem System
Props represent the interactive furniture and environmental details.

### 1. Visuals and States
Props share a single image sheet (`props.png`) and use animation states like `chair`, `table`, `microwave`, `fridge`, etc.
- **Debris**: When a prop is destroyed, its state changes to `debris`.
- **Z-Index**: Props dynamically update their Z-Index based on their Y position (`update()` loop) unless they are "flat" (like blood or holes) or special (like minifiers).
- **Configuration System**: `PropItem:init` uses a centralized `propConfigs` table to manage properties and colliders based on the prop `type`.
  - **Colliders**: Specific `collideRect` values are defined for unique shapes (e.g., trees, screens). Others use a default `(2, 10, 28, 18)`.
  - **Properties**: Flags like `isEdible`, `isHole`, and `isSlime` are derived from this configuration.
  - **Z-Index Overrides**: Certain props are set to a static `ZIndex.props` if they are non-collidable, destroyed, or environmental (holes/slime).

### 2. Environmental Hazards & Utility
- **Holes**: Defined by type (e.g., `holeCenter`, `holeLeft`).
    - **Falling**: In `collisions.lua`, hitting a hole without boots/battery triggers `self:fallBelow()`.
    - **Walking**: With boots, the player drains battery but remains in the room.
- **Minifiers**: Special pods used to change the player's size (`isTiny`) via a two-stage interaction:
    1.  **Locking**: Standing on a minifier displays "Press A". Pressing A centers the player and locks movement (`isGaming = false`).
    2.  **Transformation**: The player must manually rotate the physical **crank** to change size. Rotating counter-clockwise shrinks the player, while clockwise returns them to normal size. The `transformCycle` animation plays during this phase.
    3.  **Breakout**: If the player is locked in the minifier state (after pressing A), they can press **B** at any time to cancel the process, hide the HUD, and restore normal movement.
    4.  **Completion**: Once the target size is reached, movement is restored automatically and the player can walk away.
- **Slime (Tile 46)**: Environmental hazard that causes the player to slide.
    - **Sliding**: When stepped on, the player automatically moves in a straight line at a fixed speed (`slidingSpeed = 4`).
    - **Stopping**: The slide ends if the player hits a solid obstacle (wall, solid prop) or exits the slime patch.
    - **Antislip Protection**: If the player has **plunger**, they can walk over slime normally without consuming battery.
    - **Control**: Manual movement is disabled during a slide.

### 3. Destruction & Persistence
Props can be destroyed by certain enemies or effects.
- **`destroyProp(id)`**: Uses the unique LDtk IID to find and mark the prop as destroyed in the global level data.
- **Persistence**: `MazeScene.lua` checks the `destroyed` custom field when spawning props, ensuring they remain rubble if previously broken.

---

## 👥 Entity Interactions

Different entities have distinct rules for interacting with the environment:

- **CrewMember**: Now has its own dedicated collision group (`crewMember`).
    - **Solid Collisions**: Collide and slide against solid props (chairs, tables, cabinets), walls, and other **Enemies**. Colliding with enemies triggers their "bounce" logic.
    - **Pass-through**: Pass through non-solid props (Minifier pods, blood, debris), pickup items (Keycards, items), and triggers.
- **Enemies (Brocorat)**: Standard enemies may have different rules, such as being able to "eat" certain edible props depending on their power level.

> [!TIP]
> Items use a `FXsonar` instance to "ping" their location, helping the player find them in low-visibility or dark areas.

---

## 🛠️ Love2D Porting Guide

This section details specific implementation differences when porting the **PropItem** and **Item** systems from the Playdate SDK (Lua) to Love2D.

### 1. Sprite System (`NobleSprite` vs. Love2D)
The game uses `NobleSprite`, a wrapper around the Playdate SDK's `playdate.graphics.sprite`.
- **Playdate**: Sprites are objects managed by the system list (`gfx.sprite.update()`). They have built-in methods for drawing, collision, and dirty rect updates.
- **Love2D Implementation**:
    - **Base Object**: You will need a standard Class implementation (like `middleclass` or `classic`) for `PropItem`.
    - **Drawing**: Instead of automatic drawing, `PropItem` instances should be stored in a table (e.g., `self.props` in the Scene) and iterated over in `love.draw()`.
    - **Animation**: Use a library like `anim8`. The Playdate code uses `imagetables` (sequence of images). In Love2D, this translates to a **Sprite Atlas** (single large image) with **Quads**.
    - **Asset Path**: `assets/images/props/props` should be loaded as a single `Image` object, and the frames defined as `Quad`s based on a grid (32x32 mostly).

### 2. Collision System
Playdate's sprite system handles collisions internally with `moveWithCollisions`.
- **Logic**: `PropItem.lua` sets a collision rect using `setCollideRect(x, y, w, h)`.
- **Love2D Implementation**:
    - Use a physics/collision library like **Bump.lua** (AABB collisions).
    - **Initialization**: When creating a prop, add it to the Bump world: `world:add(prop, prop.x, prop.y, prop.w, prop.h)`.
    - **Update**: Sync the Bump world position if the prop moves (rare for static props, but relevant for "pushed" objects).
    - **Groups/Filters**: The `setGroups(3)` call in Playdate corresponds to collision layers or filters in Bump. Ensure Props are in a "Solid" or "Item" layer that the Player checks against.

### 3. Z-Indexing (Depth Sorting)
Playdate sprites have a `zIndex` property and the system automatically sorts draw order.
- **Logic**: Most props update their Z-Index every frame in `update()`: `self:setZIndex(self.y)`. This creates a pseudo-3D effect where objects lower on screen are drawn on top of objects higher up.
- **Love2D Implementation**:
    - Love2D does **not** sort automatically.
    - You must manually sort the table of entities before drawing:
    ```lua
    table.sort(scene.entities, function(a, b) return a.y + a.height < b.y + b.height end)
    ```
    - **Static Z-Index**: Props with `isStaticZIndex = true` (like holes or rugs) should be drawn first (background layer) or forced to a low index to ensure characters always walk *on top* of them.

### 4. Input & Mechanics (The Crank)
The **Minifier** prop relies on the physical Playdate Crank.
- **Playdate**: `playdate.getCrankPositions()` controls the shrinking/growing logic.
- **Love2D Implementation**:
    - Remap this mechanic since standard controllers lack a crank.
    - **Mouse**: Scroll wheel up/down.
    - **Keyboard/Gamepad**: Hold `L/R Triggers` or use `Up/Down` keys to simulate rotation.
    - **Visuals**: The UI usage of the crank indicator should be replaced with a relevant prompt (e.g., "Scroll" or "Hit Triggers").

### 5. Global Configuration
The `propConfigs` table in `PropItem.lua` is critical data that defines collision boxes and behaviors (isHole, isEdible).
- **Action**: **Copy this table exactly**. It is pure data and engine-agnostic.
- Ensure your `PropItem` constructor in Love2D reads from this table to set the `isHole`, `isSlime`, and collider values correctly.

### 6. Specific Prop Behaviors
- **Holes**: In Love2D, implement "Edges". If a player's center point is within a Hole's bounding box, trigger the fall logic.
- **Slime**: This is effectively a "Force Zone". If the player touches a Slime collider, disable input and apply a constant velocity vector until they exit the collider or hit a wall.
